import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';
import 'services/gemini_service.dart';
import 'services/local_repository.dart';
import 'services/notification_service.dart';
import 'services/secure_storage_service.dart';

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

  TaskController(this.repository) : super([]) {
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

    state = updated;
    await repository.saveTasks(updated);
    await NotificationService.instance.scheduleForTask(task);
  }

  Future<void> complete(String id) async {
    final task = state.firstWhere((t) => t.id == id);
    await upsert(
      task.copyWith(
        status: TaskStatus.completed,
        completedAt: DateTime.now(),
      ),
    );
  }

  Future<void> start(String id) async {
    final task = state.firstWhere((t) => t.id == id);
    final now = DateTime.now();
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

  Future<void> createManual({
    required String title,
    required DateTime date,
    required int durationMinutes,
    required TaskPriority priority,
  }) async {
    final now = DateTime.now();
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

    final now = DateTime.now();
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
    );

    await upsert(task);
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
}

extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
