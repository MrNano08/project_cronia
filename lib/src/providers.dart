import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';
import 'services/gemini_service.dart';
import 'services/local_repository.dart';
import 'services/notification_service.dart';
import 'services/secure_storage_service.dart';
import 'recurrence.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences no fue inicializado.');
});

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final localRepositoryProvider = Provider<LocalRepository>((ref) {
  return LocalRepository(ref.watch(sharedPreferencesProvider));
});

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService(ref.watch(secureStorageProvider));
});

final taskControllerProvider =
    StateNotifierProvider<TaskController, List<CroniaTask>>((ref) {
  return TaskController(ref.watch(localRepositoryProvider));
});

class TaskController extends StateNotifier<List<CroniaTask>> {
  final LocalRepository repository;
  final Future<void> Function(CroniaTask task, AppSettings settings)? scheduleTask;
  final Future<void> Function(String taskId)? cancelTask;

  TaskController(this.repository, {this.scheduleTask, this.cancelTask}) : super([]) {
    load();
  }

  Future<void> load() async {
    final tasks = await repository.getTasks();
    tasks.sort(_sortTasks);
    state = tasks;
  }

  Future<void> upsert(CroniaTask task) async {
    final updated = [
      ...state.where((t) => t.id != task.id),
      task,
    ]..sort(_sortTasks);

    await repository.saveTasks(updated);
    state = updated;
    final settings = await repository.getSettings();
    try {
      await _schedule(task, settings);
    } catch (_) {
      // Persistence remains successful if Android notification scheduling fails.
    }
  }

  Future<void> complete(String id) async {
    final task = state.firstWhere((t) => t.id == id);
    final settings = await repository.getSettings();
    if (task.recurrence != null) {
      final now = settings.userNow();
      final occurrences = RecurrenceEngine.next(task.recurrence!, count: 1, after: now.subtract(const Duration(days: 1)));
      if (occurrences.isNotEmpty) {
        final occurrence = occurrences.first;
        final key = '${occurrence.year.toString().padLeft(4, '0')}-${occurrence.month.toString().padLeft(2, '0')}-${occurrence.day.toString().padLeft(2, '0')}';
        final done = [...task.recurrence!.completedDates, key].toSet().toList();
        final overrides = Map<String, Map<String, dynamic>>.from(task.recurrence!.occurrenceOverrides);
        final prior = overrides[key] ?? <String, dynamic>{};
        overrides[key] = {...prior, 'status': TaskStatus.completed.name, 'completedAt': now.toIso8601String()};
        await upsert(task.copyWith(recurrence: task.recurrence!.copyWith(completedDates: done, occurrenceOverrides: overrides)));
        return;
      }
    }
    await upsert(
      task.copyWith(
        status: TaskStatus.completed,
        completedAt: settings.userNow(),
      ),
    );
  }

  Future<void> start(String id) async {
    final task = state.firstWhere((t) => t.id == id);
    final settings = await repository.getSettings();
    final now = settings.userNow();
    if (task.recurrence != null) {
      final occurrences = RecurrenceEngine.next(task.recurrence!, count: 1, after: now.subtract(const Duration(days: 1)));
      if (occurrences.isEmpty) return;
      final key = RecurrenceEngine.key(occurrences.first);
      final overrides = Map<String, Map<String, dynamic>>.from(task.recurrence!.occurrenceOverrides);
      overrides[key] = {...?overrides[key], 'status': TaskStatus.inProgress.name, 'startedAt': now.toIso8601String(), 'endAt': now.add(Duration(minutes: task.durationMinutes)).toIso8601String()};
      await upsert(task.copyWith(recurrence: task.recurrence!.copyWith(occurrenceOverrides: overrides)));
      return;
    }
    final expectedEnd = now.add(Duration(minutes: task.durationMinutes));

    await upsert(
      task.copyWith(
        status: TaskStatus.inProgress,
        startedAt: now,
        endAt: expectedEnd,
      ),
    );
  }

  Future<void> cancel(String id) async {
    final task = state.firstWhere((t) => t.id == id);
    await upsert(task.copyWith(status: TaskStatus.cancelled));
  }

  Future<void> deleteSeries(String id) async {
    final task = state.firstWhere((t) => t.id == id);
    if (task.recurrence == null) throw StateError('La tarea no pertenece a una serie.');
    final updated = state.where((t) => t.id != id).toList();
    await repository.saveTasks(updated);
    state = updated;
    try {
      await _cancel(id);
    } catch (_) {
      // Series data is removed even if Android cannot clear a pending alert.
    }
  }

  Future<void> editOccurrence({required String seriesId, required DateTime occurrenceDate, required CroniaTask editedTask, required RecurrenceEditScope scope}) async {
    final index = state.indexWhere((task) => task.id == seriesId);
    if (index < 0) throw StateError('La serie ya no existe.');
    final master = state[index];
    final rule = master.recurrence;
    if (rule == null) throw StateError('La tarea no es recurrente.');
    final key = RecurrenceEngine.key(occurrenceDate);
    final now = (await repository.getSettings()).userNow();
    var next = [...state];
    final changed = <CroniaTask>[];

    if (scope == RecurrenceEditScope.occurrence) {
      final overrides = Map<String, Map<String, dynamic>>.from(rule.occurrenceOverrides);
      var completed = rule.completedDates.where((d) => d != key).toList();
      var cancelled = rule.cancelledDates.where((d) => d != key).toList();
      var exceptions = rule.exceptions.where((d) => d != key).toList();
      if (editedTask.status == TaskStatus.cancelled) {
        overrides.remove(key);
        cancelled = [...cancelled, key];
      } else if (editedTask.status == TaskStatus.completed) {
        overrides.remove(key);
        completed = [...completed, key];
      } else {
        overrides[key] = {
          'title': editedTask.title,
          'description': editedTask.description,
          'date': editedTask.date.toIso8601String(),
          'startAt': editedTask.startAt?.toIso8601String(),
          'endAt': editedTask.endAt?.toIso8601String(),
          'durationMinutes': editedTask.durationMinutes,
          'priority': editedTask.priority.name,
          'status': editedTask.status.name,
          'reminders': editedTask.reminders.map((r) => r.toJson()).toList(),
        };
      }
      final updatedRule = rule.copyWith(occurrenceOverrides: overrides, exceptions: exceptions, completedDates: completed.toSet().toList(), cancelledDates: cancelled.toSet().toList());
      final updated = master.copyWith(recurrence: updatedRule, updatedAt: now);
      next[index] = updated;
      changed.add(updated);
    } else if (scope == RecurrenceEditScope.series) {
      final requestedRule = editedTask.recurrence;
      final updatedRule = requestedRule == null ? null : _rebuildRule(requestedRule, startDate: occurrenceDate == editedTask.date ? rule.startDate : editedTask.date, replacedDate: occurrenceDate, exceptions: rule.exceptions, completed: rule.completedDates, cancelled: rule.cancelledDates, overrides: rule.occurrenceOverrides);
      final updated = editedTask.copyWith(date: requestedRule == null || occurrenceDate != editedTask.date ? editedTask.date : master.date, recurrence: updatedRule, clearRecurrence: requestedRule == null, updatedAt: now);
      next[index] = updated;
      changed.add(updated);
    } else {
      final previousDay = DateTime(occurrenceDate.year, occurrenceDate.month, occurrenceDate.day - 1);
      final pastCount = RecurrenceEngine.countThrough(rule, previousDay);
      if (rule.end == RecurrenceEnd.afterCount && pastCount >= (rule.occurrenceCount ?? 0)) throw StateError('No quedan ocurrencias futuras para dividir.');
      final newRule = editedTask.recurrence == null ? null : _rebuildRule(editedTask.recurrence!, startDate: editedTask.date, replacedDate: occurrenceDate, end: rule.end, endDate: rule.endDate, count: rule.end == RecurrenceEnd.afterCount ? (rule.occurrenceCount ?? 0) - pastCount : rule.occurrenceCount, exceptions: rule.exceptions.where((d) => d.compareTo(key) >= 0).toList(), completed: rule.completedDates.where((d) => d.compareTo(key) >= 0).toList(), cancelled: rule.cancelledDates.where((d) => d.compareTo(key) >= 0).toList(), overrides: Map.fromEntries(rule.occurrenceOverrides.entries.where((e) => e.key.compareTo(key) >= 0)));
      if (pastCount == 0) {
        next.removeAt(index);
      } else {
        final oldRule = rule.end == RecurrenceEnd.afterCount
            ? rule.copyWith(occurrenceCount: pastCount, occurrenceOverrides: Map.fromEntries(rule.occurrenceOverrides.entries.where((e) => e.key.compareTo(key) < 0)), exceptions: rule.exceptions.where((d) => d.compareTo(key) < 0).toList(), completedDates: rule.completedDates.where((d) => d.compareTo(key) < 0).toList(), cancelledDates: rule.cancelledDates.where((d) => d.compareTo(key) < 0).toList())
            : rule.copyWith(end: RecurrenceEnd.onDate, endDate: previousDay, occurrenceOverrides: Map.fromEntries(rule.occurrenceOverrides.entries.where((e) => e.key.compareTo(key) < 0)), exceptions: rule.exceptions.where((d) => d.compareTo(key) < 0).toList(), completedDates: rule.completedDates.where((d) => d.compareTo(key) < 0).toList(), cancelledDates: rule.cancelledDates.where((d) => d.compareTo(key) < 0).toList());
        next[index] = master.copyWith(recurrence: oldRule, updatedAt: now);
        changed.add(next[index]);
      }
      final newSeries = CroniaTask(id: const Uuid().v4(), title: editedTask.title, description: editedTask.description, date: editedTask.date, startAt: editedTask.startAt, endAt: editedTask.endAt, durationMinutes: editedTask.durationMinutes, priority: editedTask.priority, status: editedTask.status, isFlexible: editedTask.isFlexible, canBeMoved: editedTask.canBeMoved, deadline: editedTask.deadline, reminders: editedTask.reminders.map((r) => ReminderConfig(id: const Uuid().v4(), taskId: 'pending', type: r.type, scheduledAt: r.scheduledAt, daysBefore: r.daysBefore, hoursBefore: r.hoursBefore, minutesBefore: r.minutesBefore, enabled: r.enabled, triggered: false)).toList(), createdAt: now, updatedAt: now, recurrence: newRule);
      final withIdReminders = newSeries.copyWith(reminders: newSeries.reminders.map((r) => ReminderConfig(id: const Uuid().v4(), taskId: newSeries.id, type: r.type, scheduledAt: r.scheduledAt, daysBefore: r.daysBefore, hoursBefore: r.hoursBefore, minutesBefore: r.minutesBefore, enabled: r.enabled, triggered: false)).toList());
      next.add(withIdReminders);
      changed.add(withIdReminders);
    }

    next.sort(_sortTasks);
    await repository.saveTasks(next);
    state = next;
    final settings = await repository.getSettings();
    if (scope == RecurrenceEditScope.thisAndFollowing) {
      try { await _cancel(seriesId); } catch (_) { /* Rebuild below remains best effort. */ }
    }
    for (final task in changed) {
      try { await _schedule(task, settings); } catch (_) { /* Keep the saved edit. */ }
    }
  }

  Future<void> deleteOccurrence({required String seriesId, required DateTime occurrenceDate, required RecurrenceEditScope scope}) async {
    final index = state.indexWhere((task) => task.id == seriesId);
    if (index < 0 || state[index].recurrence == null) throw StateError('La serie ya no existe.');
    if (scope == RecurrenceEditScope.series) return deleteSeries(seriesId);
    final master = state[index];
    final rule = master.recurrence!;
    final key = RecurrenceEngine.key(occurrenceDate);
    final next = [...state];
    if (scope == RecurrenceEditScope.occurrence) {
      final overrides = Map<String, Map<String, dynamic>>.from(rule.occurrenceOverrides)..remove(key);
      final updated = master.copyWith(recurrence: rule.copyWith(exceptions: [...rule.exceptions, key].toSet().toList(), occurrenceOverrides: overrides));
      next[index] = updated;
    } else {
      final previousDay = DateTime(occurrenceDate.year, occurrenceDate.month, occurrenceDate.day - 1);
      final count = RecurrenceEngine.countThrough(rule, previousDay);
      if (count == 0) {
        next.removeAt(index);
      } else {
        final historyOverrides = Map.fromEntries(rule.occurrenceOverrides.entries.where((e) => e.key.compareTo(key) < 0));
        final historyExceptions = rule.exceptions.where((d) => d.compareTo(key) < 0).toList();
        final historyCompleted = rule.completedDates.where((d) => d.compareTo(key) < 0).toList();
        final historyCancelled = rule.cancelledDates.where((d) => d.compareTo(key) < 0).toList();
        final updatedRule = rule.end == RecurrenceEnd.afterCount
            ? rule.copyWith(occurrenceCount: count, exceptions: historyExceptions, completedDates: historyCompleted, cancelledDates: historyCancelled, occurrenceOverrides: historyOverrides)
            : rule.copyWith(end: RecurrenceEnd.onDate, endDate: previousDay, exceptions: historyExceptions, completedDates: historyCompleted, cancelledDates: historyCancelled, occurrenceOverrides: historyOverrides);
        next[index] = master.copyWith(recurrence: updatedRule);
      }
    }
    await repository.saveTasks(next);
    state = next;
    try { await _schedule(next.firstWhere((t) => t.id == seriesId), await repository.getSettings()); } catch (_) {
      try { await _cancel(seriesId); } catch (_) { /* OS cleanup is best effort. */ }
    }
  }

  Future<void> cancelOccurrence({required String seriesId, required DateTime occurrenceDate, required RecurrenceEditScope scope}) async {
    if (scope == RecurrenceEditScope.series) return cancel(seriesId);
    if (scope == RecurrenceEditScope.occurrence) {
      final index = state.indexWhere((task) => task.id == seriesId);
      if (index < 0 || state[index].recurrence == null) throw StateError('La serie ya no existe.');
      final master = state[index];
      final key = RecurrenceEngine.key(occurrenceDate);
      final rule = master.recurrence!;
      final updated = master.copyWith(recurrence: rule.copyWith(cancelledDates: [...rule.cancelledDates, key].toSet().toList(), occurrenceOverrides: Map.from(rule.occurrenceOverrides)..remove(key)));
      await upsert(updated);
      return;
    }
    final master = state.firstWhere((task) => task.id == seriesId);
    await editOccurrence(seriesId: seriesId, occurrenceDate: occurrenceDate, editedTask: master.copyWith(date: occurrenceDate, status: TaskStatus.cancelled), scope: RecurrenceEditScope.thisAndFollowing);
  }

  RecurrenceRule _rebuildRule(RecurrenceRule source, {required DateTime startDate, DateTime? replacedDate, RecurrenceEnd? end, DateTime? endDate, int? count, required List<String> exceptions, required List<String> completed, required List<String> cancelled, required Map<String, Map<String, dynamic>> overrides}) {
    var weekdays = source.weekdays;
    var dayOfMonth = source.dayOfMonth;
    var monthlyWeekday = source.monthlyWeekday;
    var weekdayPosition = source.weekdayPosition;
    if (replacedDate != null && replacedDate != startDate) {
      if (source.frequency == RecurrenceFrequency.weekly) {
        weekdays = source.weekdays.map((day) => day == replacedDate.weekday ? startDate.weekday : day).toSet().toList()..sort();
        if (weekdays.isEmpty) weekdays = [startDate.weekday];
      }
      if (source.frequency == RecurrenceFrequency.monthly) {
        if (source.monthlyPattern == MonthlyPattern.dayOfMonth) dayOfMonth = startDate.day;
        if (source.monthlyPattern == MonthlyPattern.weekdayPosition) {
          monthlyWeekday = startDate.weekday;
          weekdayPosition = DateTime(startDate.year, startDate.month, startDate.day + 7).month == startDate.month ? ((startDate.day - 1) ~/ 7) + 1 : -1;
        }
      }
    }
    return RecurrenceRule(frequency: source.frequency, interval: source.interval, weekdays: weekdays, monthlyPattern: source.monthlyPattern, dayOfMonth: dayOfMonth, weekdayPosition: weekdayPosition, monthlyWeekday: monthlyWeekday, startDate: startDate, end: end ?? source.end, endDate: endDate ?? source.endDate, occurrenceCount: count ?? source.occurrenceCount, exceptions: exceptions, completedDates: completed, cancelledDates: cancelled, occurrenceOverrides: overrides);
  }

  Future<void> createManual({
    required String title,
    required DateTime date,
    required int durationMinutes,
    required TaskPriority priority,
  }) async {
    final settings = await repository.getSettings();
    final now = settings.userNow();
    final id = const Uuid().v4();
    final startAt = DateTime(
      date.year,
      date.month,
      date.day,
      now.hour,
      now.minute,
    );
    final endAt = startAt.add(Duration(minutes: durationMinutes));

    final task = CroniaTask(
      id: id,
      title: title,
      date: DateTime(date.year, date.month, date.day),
      startAt: startAt,
      endAt: endAt,
      durationMinutes: durationMinutes,
      priority: priority,
      status: TaskStatus.pending,
      reminders: [
        ReminderConfig(
          id: const Uuid().v4(),
          taskId: id,
          type: ReminderType.beforeStart,
          scheduledAt: startAt.subtract(const Duration(minutes: 15)),
          minutesBefore: 15,
        ),
        ReminderConfig(
          id: const Uuid().v4(),
          taskId: id,
          type: ReminderType.atStart,
          scheduledAt: startAt,
        ),
        ReminderConfig(
          id: const Uuid().v4(),
          taskId: id,
          type: ReminderType.atEnd,
          scheduledAt: endAt,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );

    await upsert(task);
  }

  Future<void> applyPlannedTask(PlannedTask planned) async {
    if (planned.action == 'delete_request') {
      return;
    }

    CroniaTask? existing;

    if (planned.existingTaskId != null) {
      existing = state.firstWhereOrNull((t) => t.id == planned.existingTaskId);
    }

    final settings = await repository.getSettings();
    final now = settings.userNow();
    final id = existing?.id ?? const Uuid().v4();

    final task = CroniaTask(
      id: id,
      title: planned.title,
      description: planned.description,
      date: DateTime(planned.date.year, planned.date.month, planned.date.day),
      startAt: planned.startAt,
      endAt: planned.endAt,
      durationMinutes: planned.durationMinutes,
      priority: planned.priority,
      status: planned.status,
      isFlexible: planned.isFlexible,
      canBeMoved: planned.canBeMoved,
      deadline: planned.deadline,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      reminders: _defaultRemindersFor(id, planned),
      recurrence: planned.recurrence,
    );

    await upsert(task);
  }

  Future<void> applyPlannedTasks(List<PlannedTask> plannedTasks) async {
    final now = (await repository.getSettings()).userNow();
    final next = [...state];
    final touched = <CroniaTask>[];
    final seenIds = <String>{};
    for (final planned in plannedTasks) {
      if (planned.action == 'delete_request') continue;
      final existingId = planned.existingTaskId;
      if (existingId != null && !seenIds.add(existingId)) {
        throw StateError('La propuesta intenta cambiar la misma tarea más de una vez.');
      }
      final index = existingId == null ? -1 : next.indexWhere((t) => t.id == existingId);
      if (existingId != null && index < 0) throw StateError('Una tarea de la propuesta ya no existe.');
      final existing = index < 0 ? null : next[index];
      if (existing != null && existing.status == TaskStatus.completed) {
        throw StateError('No se puede sobrescribir una actividad completada sin confirmación.');
      }
      if (existing != null && planned.action == 'cancel') {
        final cancelled = existing.copyWith(status: TaskStatus.cancelled, updatedAt: now);
        next[index] = cancelled;
        touched.add(cancelled);
        continue;
      }
      if (existing != null && !existing.canBeMoved && planned.action != 'create') {
        final moved = planned.date != existing.date || planned.startAt != existing.startAt || planned.durationMinutes != existing.durationMinutes;
        if (moved) throw StateError('La actividad "${existing.title}" está marcada como inmovible.');
      }
      if (existing?.startedAt != null && (planned.date != existing!.date || planned.startAt != existing.startAt || planned.durationMinutes != existing.durationMinutes)) {
        throw StateError('No se puede cambiar el horario de una actividad que ya inició.');
      }
      final id = existing?.id ?? const Uuid().v4();
      final shiftedReminders = existing == null ? _defaultRemindersFor(id, planned) : _shiftReminders(existing, id, planned);
      final task = CroniaTask(id: id, title: planned.title, description: planned.description ?? existing?.description, date: DateTime(planned.date.year, planned.date.month, planned.date.day), startAt: planned.startAt, endAt: planned.endAt, durationMinutes: planned.durationMinutes, priority: existing?.priority ?? planned.priority, status: planned.action == 'postpone' ? TaskStatus.postponed : existing?.status ?? planned.status, isFlexible: existing?.isFlexible ?? planned.isFlexible, canBeMoved: existing?.canBeMoved ?? planned.canBeMoved, deadline: planned.deadline ?? existing?.deadline, startedAt: existing?.startedAt, completedAt: existing?.completedAt, createdAt: existing?.createdAt ?? now, updatedAt: now, reminders: shiftedReminders, recurrence: planned.recurrence ?? existing?.recurrence);
      if (index < 0) { next.add(task); } else { next[index] = task; }
      touched.add(task);
    }
    next.sort(_sortTasks);
    await repository.saveTasks(next);
    state = next;
    for (final task in touched) {
      try {
        await _schedule(task, await repository.getSettings());
      } catch (_) {
        // A notification plugin failure must not undo an already saved plan.
      }
    }
  }

  static List<ReminderConfig> _shiftReminders(CroniaTask existing, String id, PlannedTask planned) {
    if (existing.startAt == null || planned.startAt == null) return existing.reminders;
    final end = planned.endAt ?? planned.startAt!.add(Duration(minutes: planned.durationMinutes));
    return existing.reminders.map((reminder) {
      final scheduled = reminder.type == ReminderType.atEnd
          ? end
          : planned.startAt!.add(reminder.scheduledAt.difference(existing.startAt!));
      return ReminderConfig(id: reminder.id, taskId: id, type: reminder.type, scheduledAt: scheduled, daysBefore: reminder.daysBefore, hoursBefore: reminder.hoursBefore, minutesBefore: reminder.minutesBefore, enabled: reminder.enabled, triggered: reminder.triggered);
    }).toList();
  }

  static List<ReminderConfig> _defaultRemindersFor(
    String taskId,
    PlannedTask planned,
  ) {
    final start = planned.startAt;
    if (start == null) return [];

    final reminders = <ReminderConfig>[
      ReminderConfig(
        id: const Uuid().v4(),
        taskId: taskId,
        type: ReminderType.beforeStart,
        scheduledAt: start.subtract(const Duration(minutes: 15)),
        minutesBefore: 15,
      ),
      ReminderConfig(
        id: const Uuid().v4(),
        taskId: taskId,
        type: ReminderType.atStart,
        scheduledAt: start,
      ),
    ];

    if (planned.deadline != null) {
      reminders.add(
        ReminderConfig(
          id: const Uuid().v4(),
          taskId: taskId,
          type: ReminderType.daysBefore,
          scheduledAt: planned.deadline!.subtract(const Duration(days: 1)),
          daysBefore: 1,
        ),
      );
    }

    if (planned.endAt != null) {
      reminders.add(
        ReminderConfig(
          id: const Uuid().v4(),
          taskId: taskId,
          type: ReminderType.atEnd,
          scheduledAt: planned.endAt!,
        ),
      );
    }

    return reminders;
  }

  static int _sortTasks(CroniaTask a, CroniaTask b) {
    final aTime = a.startAt ?? a.date;
    final bTime = b.startAt ?? b.date;
    return aTime.compareTo(bTime);
  }

  Future<void> _schedule(CroniaTask task, AppSettings settings) async {
    if (scheduleTask != null) {
      await scheduleTask!(task, settings);
    } else {
      await NotificationService.instance.scheduleForTask(task, settings: settings);
    }
  }

  Future<void> _cancel(String id) async {
    if (cancelTask != null) {
      await cancelTask!(id);
    } else {
      await NotificationService.instance.cancelForTask(id);
    }
  }
}

extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
