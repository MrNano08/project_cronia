import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models.dart';
import '../providers.dart';

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

    final selectedTasks = tasks.where((task) {
      return isSameDay(task.date, _selectedDay);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      body: Column(
        children: [
          TableCalendar<CroniaTask>(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2035, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            eventLoader: (day) {
              return tasks.where((task) => isSameDay(task.date, day)).toList();
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return null;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: events.take(3).map((task) {
                    return Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: task.priority.color,
                        shape: BoxShape.circle,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: selectedTasks.isEmpty
                ? const Center(child: Text('No hay actividades este día.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: selectedTasks.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final task = selectedTasks[index];

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: task.priority.color),
                          title: Text(task.title),
                          subtitle: Text(
                            '${task.priority.label} · ${task.status.label}',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        onDestinationSelected: (index) {
          if (index == 0) context.go('/home');
          if (index == 1) context.go('/calendar');
          if (index == 2) context.go('/planner');
          if (index == 3) context.go('/settings');
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Calendario'),
          NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'IA'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}
