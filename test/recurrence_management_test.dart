import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_cronia/src/models.dart';
import 'package:project_cronia/src/providers.dart';
import 'package:project_cronia/src/recurrence.dart';
import 'package:project_cronia/src/services/local_repository.dart';

Future<TaskController> _controllerFor(CroniaTask task) async {
  SharedPreferences.setMockInitialValues({'tasks': '[${_json(task)}]'});
  final prefs = await SharedPreferences.getInstance();
  final controller = TaskController(
    LocalRepository(prefs),
    scheduleTask: (_, __) async {},
    cancelTask: (_) async {},
  );
  await controller.load();
  return controller;
}

String _json(CroniaTask task) => jsonEncode(task.toJson());

CroniaTask _weeklyTask({int count = 5}) {
  final start = DateTime(2026, 10, 26, 19);
  return CroniaTask(
    id: 'series-1', title: 'Inglés', date: DateTime(2026, 10, 26),
    startAt: start, endAt: start.add(const Duration(minutes: 45)),
    durationMinutes: 45, priority: TaskPriority.medium, status: TaskStatus.pending,
    createdAt: DateTime(2026, 10, 1), updatedAt: DateTime(2026, 10, 1),
    recurrence: RecurrenceRule(frequency: RecurrenceFrequency.weekly,
      weekdays: const [DateTime.monday], startDate: DateTime(2026, 10, 26),
      end: RecurrenceEnd.afterCount, occurrenceCount: count),
  );
}

void main() {
  test('edita una ocurrencia sin alterar el resto de la serie', () async {
    final root = _weeklyTask();
    final controller = await _controllerFor(root);
    final moved = DateTime(2026, 11, 2, 20);
    await controller.editOccurrence(
      seriesId: root.id,
      occurrenceDate: DateTime(2026, 11, 2),
      editedTask: root.copyWith(title: 'Inglés avanzado', date: DateTime(2026, 11, 2), startAt: moved, durationMinutes: 60),
      scope: RecurrenceEditScope.occurrence,
    );
    final stored = await controller.repository.getTasks();
    expect(stored, hasLength(1));
    expect(stored.single.title, 'Inglés');
    expect(stored.single.recurrence!.occurrenceOverrides['2026-11-02']!['title'], 'Inglés avanzado');
    expect(RecurrenceEngine.between(stored.single.recurrence!, DateTime(2026, 10, 26), DateTime(2026, 11, 16)), [DateTime(2026, 10, 26), DateTime(2026, 11, 2), DateTime(2026, 11, 9), DateTime(2026, 11, 16)]);
    final backup = await controller.repository.exportJson();
    await controller.repository.importJson(backup);
    expect((await controller.repository.getTasks()).single.recurrence!.occurrenceOverrides['2026-11-02']!['startAt'], moved.toIso8601String());
  });

  test('esta y las siguientes divide serie y conserva el historial', () async {
    final root = _weeklyTask();
    final controller = await _controllerFor(root);
    await controller.editOccurrence(
      seriesId: root.id,
      occurrenceDate: DateTime(2026, 11, 9),
      editedTask: root.copyWith(title: 'Inglés intensivo', date: DateTime(2026, 11, 9)),
      scope: RecurrenceEditScope.thisAndFollowing,
    );
    final stored = await controller.repository.getTasks();
    expect(stored, hasLength(2));
    final previous = stored.singleWhere((task) => task.id == root.id).recurrence!;
    final future = stored.singleWhere((task) => task.id != root.id).recurrence!;
    expect(previous.occurrenceCount, 2);
    expect(future.startDate, DateTime(2026, 11, 9));
    expect(future.occurrenceCount, 3);
  });

  test('eliminar una ocurrencia crea una excepción persistente', () async {
    final root = _weeklyTask();
    final controller = await _controllerFor(root);
    await controller.deleteOccurrence(seriesId: root.id, occurrenceDate: DateTime(2026, 11, 2), scope: RecurrenceEditScope.occurrence);
    final stored = (await controller.repository.getTasks()).single;
    expect(stored.recurrence!.exceptions, contains('2026-11-02'));
    expect(RecurrenceEngine.between(stored.recurrence!, DateTime(2026, 10, 26), DateTime(2026, 11, 9)), [DateTime(2026, 10, 26), DateTime(2026, 11, 9)]);
  });

  test('cancelar una ocurrencia no cancela las demás', () async {
    final root = _weeklyTask();
    final controller = await _controllerFor(root);
    await controller.cancelOccurrence(seriesId: root.id, occurrenceDate: DateTime(2026, 11, 2), scope: RecurrenceEditScope.occurrence);
    final stored = (await controller.repository.getTasks()).single;
    expect(stored.status, TaskStatus.pending);
    expect(stored.recurrence!.cancelledDates, contains('2026-11-02'));
    expect(RecurrenceEngine.between(stored.recurrence!, DateTime(2026, 10, 26), DateTime(2026, 11, 9)), [DateTime(2026, 10, 26), DateTime(2026, 11, 9)]);
  });

  test('eliminar esta y las siguientes conserva solo el historial', () async {
    final root = _weeklyTask();
    final controller = await _controllerFor(root);
    await controller.deleteOccurrence(seriesId: root.id, occurrenceDate: DateTime(2026, 11, 9), scope: RecurrenceEditScope.thisAndFollowing);
    final stored = (await controller.repository.getTasks()).single;
    expect(stored.recurrence!.occurrenceCount, 2);
    expect(RecurrenceEngine.between(stored.recurrence!, DateTime(2026, 10, 26), DateTime(2026, 11, 30)), [DateTime(2026, 10, 26), DateTime(2026, 11, 2)]);
  });

  test('completar una tarea recurrente solo marca una fecha y conserva la serie', () async {
    final today = AppSettings.defaults().userNow();
    final start = DateTime(today.year, today.month, today.day);
    final root = _weeklyTask(count: 100).copyWith(date: start, startAt: DateTime(start.year, start.month, start.day, 19), recurrence: RecurrenceRule(frequency: RecurrenceFrequency.daily, startDate: start));
    final controller = await _controllerFor(root);
    await controller.complete(root.id);
    final stored = (await controller.repository.getTasks()).single;
    expect(stored.status, TaskStatus.pending);
    expect(stored.recurrence!.completedDates, contains(RecurrenceEngine.key(start)));
    expect(RecurrenceEngine.next(stored.recurrence!, count: 1, after: start.subtract(const Duration(days: 1))).single, start.add(const Duration(days: 1)));
  });
}
