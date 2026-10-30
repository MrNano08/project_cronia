import 'package:flutter_test/flutter_test.dart';
import 'package:project_cronia/src/models.dart';
import 'package:project_cronia/src/recurrence.dart';

void main() {
  group('RecurrenceEngine', () {
    test('mantiene compatible una tarea histórica sin regla recurrente', () {
      final task = CroniaTask.fromJson({'id': 'old-1', 'title': 'Tarea antigua', 'date': '2026-10-30T00:00:00', 'durationMinutes': 30, 'priority': 'medium', 'status': 'pending', 'createdAt': '2026-10-29T10:00:00', 'updatedAt': '2026-10-29T10:00:00'});
      expect(task.recurrence, isNull);
      expect(task.title, 'Tarea antigua');
    });
    test('genera días laborables excluyendo sábados y domingos', () {
      final rule = RecurrenceRule(frequency: RecurrenceFrequency.weekdays, startDate: DateTime(2026, 10, 30));
      expect(RecurrenceEngine.between(rule, DateTime(2026, 10, 30), DateTime(2026, 11, 4)), [DateTime(2026, 10, 30), DateTime(2026, 11, 2), DateTime(2026, 11, 3), DateTime(2026, 11, 4)]);
    });
    test('repite semanas con selección de varios días e intervalo', () {
      final rule = RecurrenceRule(frequency: RecurrenceFrequency.weekly, interval: 2, weekdays: const [DateTime.monday, DateTime.friday], startDate: DateTime(2026, 10, 26));
      expect(RecurrenceEngine.between(rule, DateTime(2026, 10, 26), DateTime(2026, 11, 10)), [DateTime(2026, 10, 26), DateTime(2026, 10, 30), DateTime(2026, 11, 9)]);
    });
    test('clampa día 31 al último día de meses cortos y respeta count', () {
      final rule = RecurrenceRule(frequency: RecurrenceFrequency.monthly, dayOfMonth: 31, startDate: DateTime(2026, 1, 31), end: RecurrenceEnd.afterCount, occurrenceCount: 3);
      expect(RecurrenceEngine.between(rule, DateTime(2026, 1, 1), DateTime(2026, 5, 1)), [DateTime(2026, 1, 31), DateTime(2026, 2, 28), DateTime(2026, 3, 31)]);
    });
    test('maneja año bisiesto y serialización compatible', () {
      final rule = RecurrenceRule(frequency: RecurrenceFrequency.yearly, startDate: DateTime(2024, 2, 29));
      final restored = RecurrenceRule.fromJson(rule.toJson());
      expect(RecurrenceEngine.between(restored, DateTime(2024, 1, 1), DateTime(2026, 12, 31)), [DateTime(2024, 2, 29), DateTime(2025, 2, 28), DateTime(2026, 2, 28)]);
    });
    test('completar una fecha excepción no afecta próximas ocurrencias', () {
      final rule = RecurrenceRule(frequency: RecurrenceFrequency.daily, startDate: DateTime(2026, 10, 30), completedDates: const ['2026-10-30']);
      final restored = RecurrenceRule.fromJson(rule.toJson());
      expect(RecurrenceEngine.between(restored, DateTime(2026, 10, 30), DateTime(2026, 11, 2)), [DateTime(2026, 10, 31), DateTime(2026, 11, 1), DateTime(2026, 11, 2)]);
    });
    test('calcula la última ocurrencia mensual por día de semana', () {
      final rule = RecurrenceRule(frequency: RecurrenceFrequency.monthly, monthlyPattern: MonthlyPattern.weekdayPosition, monthlyWeekday: DateTime.friday, weekdayPosition: -1, startDate: DateTime(2026, 10, 1));
      expect(RecurrenceEngine.between(rule, DateTime(2026, 10, 1), DateTime(2026, 11, 30)), [DateTime(2026, 10, 30), DateTime(2026, 11, 27)]);
    });
  });
}
