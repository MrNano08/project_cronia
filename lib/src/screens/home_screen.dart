import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project-Cronia'),
        actions: [
          IconButton(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: tasks.isEmpty
          ? const Center(child: Text('Todavía no tienes actividades.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _TaskCard(task: tasks[index]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/planner'),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Planificar'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 0) context.go('/home');
          if (index == 1) context.go('/calendar');
          if (index == 2) context.go('/planner');
          if (index == 3) context.go('/settings');
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: 'Calendario',
          ),
          NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'IA'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  final CroniaTask task;

  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: task.priority.color, width: 6)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                task.startAt == null
                    ? DateFormat('dd/MM/yyyy').format(task.date)
                    : formatter.format(task.startAt!),
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text(task.priority.label),
                    backgroundColor: task.priority.color.withValues(alpha: 0.15),
                  ),
                  Chip(label: Text(task.status.label)),
                  Chip(label: Text('${task.durationMinutes} min')),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: task.status == TaskStatus.inProgress
                        ? null
                        : () => ref
                            .read(taskControllerProvider.notifier)
                            .start(task.id),
                    child: const Text('Iniciar'),
                  ),
                  TextButton(
                    onPressed: () => ref
                        .read(taskControllerProvider.notifier)
                        .complete(task.id),
                    child: const Text('Completar'),
                  ),
                  TextButton(
                    onPressed: () => ref
                        .read(taskControllerProvider.notifier)
                        .cancel(task.id),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
