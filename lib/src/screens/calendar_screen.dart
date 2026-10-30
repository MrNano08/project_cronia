import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models.dart';
import '../providers.dart';
import '../recurrence.dart';
import '../theme/cronia_theme.dart';
import '../widgets/cronia_ui.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskControllerProvider);

    final selectedTasks = _tasksOnDay(tasks, _selectedDay);

    return CroniaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppBar(
          title: const Text('Calendario'),
          actions: [
            IconButton.filledTonal(
              onPressed: () => context.push('/task/new'),
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Agregar tarea',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: CroniaAnimatedItem(
                child: CroniaCard(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                  child: TableCalendar<CroniaTask>(
                    firstDay: DateTime.utc(2024, 1, 1),
                    lastDay: DateTime.utc(2035, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                    eventLoader: (day) {
                      return _tasksOnDay(tasks, day);
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    rowHeight: 48,
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(
                        color: CroniaColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                      leftChevronIcon: Icon(
                        Icons.chevron_left_rounded,
                        color: CroniaColors.primaryDark,
                      ),
                      rightChevronIcon: Icon(
                        Icons.chevron_right_rounded,
                        color: CroniaColors.primaryDark,
                      ),
                    ),
                    daysOfWeekStyle: const DaysOfWeekStyle(
                      weekdayStyle: TextStyle(
                        color: CroniaColors.muted,
                        fontWeight: FontWeight.w800,
                      ),
                      weekendStyle: TextStyle(
                        color: CroniaColors.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    calendarStyle: CalendarStyle(
                      outsideTextStyle: TextStyle(
                        color: CroniaColors.muted.withValues(alpha: 0.38),
                      ),
                      weekendTextStyle: const TextStyle(color: CroniaColors.accent),
                      todayDecoration: BoxDecoration(
                        color: CroniaColors.secondary.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: const TextStyle(
                        color: CroniaColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                      selectedDecoration: const BoxDecoration(
                        gradient: CroniaColors.heroGradient,
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, day, events) {
                        if (events.isEmpty) return null;

                        return Padding(
                          padding: const EdgeInsets.only(top: 34),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: events.take(3).map((task) {
                              return Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                decoration: BoxDecoration(
                                  color: task.priority.color,
                                  shape: BoxShape.circle,
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: selectedTasks.isEmpty
                    ? const CroniaEmptyState(
                        icon: Icons.event_available_rounded,
                        title: 'Día despejado',
                        subtitle: 'No hay actividades registradas para esta fecha.',
                      )
                    : ListView.separated(
                        key: ValueKey(_selectedDay.toIso8601String()),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
                        itemCount: selectedTasks.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final task = selectedTasks[index];

                          return CroniaAnimatedItem(
                            index: index,
                            child: CroniaCard(
                              padding: const EdgeInsets.all(14),
                              onTap: () => context.push('/task/${task.occurrenceSeriesId ?? task.id}/edit', extra: task.occurrenceSeriesId == null ? null : task.occurrenceDate),
                              borderColor: task.priority.color.withValues(alpha: 0.18),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: task.priority.color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(17),
                                    ),
                                    child: Icon(
                                      task.recurrence == null ? Icons.task_alt_rounded : Icons.repeat_rounded,
                                      color: task.priority.color,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          task.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${task.priority.label} · ${task.status.label}${task.recurrence == null ? '' : ' · Recurrente'}',
                                          style: const TextStyle(
                                            color: CroniaColors.muted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.edit_rounded,
                                    color: CroniaColors.primaryDark,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: const CroniaNavigationBar(selectedIndex: 1),
      ),
    );
  }

  List<CroniaTask> _tasksOnDay(List<CroniaTask> tasks, DateTime day) {
    final matches = <CroniaTask>[];
    for (final task in tasks) {
      final rule = task.recurrence;
      if (rule == null) {
        if (isSameDay(task.date, day)) matches.add(task);
        continue;
      }
      final dates = RecurrenceEngine.between(rule, day, day, limit: 1);
      if (dates.isNotEmpty) {
        final key = RecurrenceEngine.key(dates.first);
        final override = rule.occurrenceOverrides[key];
        final overrideDate = override?['date'] == null ? dates.first : DateTime.tryParse(override!['date'] as String) ?? dates.first;
        if (isSameDay(overrideDate, day)) matches.add(_occurrenceTask(task, dates.first, override));
      }
      for (final entry in rule.occurrenceOverrides.entries) {
        if (dates.isNotEmpty && entry.key == RecurrenceEngine.key(dates.first)) continue;
        final movedDate = entry.value['date'] == null ? DateTime.tryParse(entry.key) : DateTime.tryParse(entry.value['date'] as String);
        if (movedDate != null && isSameDay(movedDate, day)) matches.add(_occurrenceTask(task, DateTime.tryParse(entry.key) ?? movedDate, entry.value));
      }
    }
    matches.sort((a, b) => (a.startAt ?? a.date).compareTo(b.startAt ?? b.date));
    return matches;
  }

  CroniaTask _occurrenceTask(CroniaTask master, DateTime identityDate, Map<String, dynamic>? override) {
    final date = override?['date'] == null ? identityDate : DateTime.tryParse(override!['date'] as String) ?? identityDate;
    final start = override?['startAt'] == null
        ? (master.startAt == null ? null : DateTime(date.year, date.month, date.day, master.startAt!.hour, master.startAt!.minute))
        : DateTime.tryParse(override!['startAt'] as String);
    final duration = (override?['durationMinutes'] as num?)?.toInt() ?? master.durationMinutes;
    final remindersJson = override?['reminders'] as List?;
    final reminders = remindersJson == null
        ? master.reminders
        : remindersJson.map((item) => ReminderConfig.fromJson(Map<String, dynamic>.from(item as Map))).toList();
    return master.copyWith(id: RecurrenceEngine.occurrenceId(master.id, identityDate), occurrenceSeriesId: master.id, occurrenceDate: identityDate, title: override?['title'] as String? ?? master.title, description: override?['description'] as String? ?? master.description, date: DateTime(date.year, date.month, date.day), startAt: start, endAt: start == null ? null : start.add(Duration(minutes: duration)), durationMinutes: duration, priority: taskPriorityFromString(override?['priority'] as String? ?? master.priority.name), status: taskStatusFromString(override?['status'] as String? ?? master.status.name), reminders: reminders);
  }

}
