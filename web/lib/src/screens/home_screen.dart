import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../providers.dart';
import '../theme/cronia_theme.dart';
import '../widgets/cronia_ui.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskControllerProvider);
    final pending = tasks.where((task) => task.status != TaskStatus.completed).length;

    return CroniaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppBar(
          title: const Text('Project-Cronia'),
          actions: [
            IconButton.filledTonal(
              onPressed: () => context.go('/planner'),
              icon: const Icon(Icons.auto_awesome_rounded),
              tooltip: 'Planificar con IA',
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: () => context.go('/settings'),
              icon: const Icon(Icons.settings_rounded),
              tooltip: 'Ajustes',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: tasks.isEmpty
            ? CroniaEmptyState(
                icon: Icons.bolt_rounded,
                title: 'Todavía no tienes actividades',
                subtitle: 'Agrega tu primera tarea o pídele a Gemini que organice tu día.',
                action: FilledButton.icon(
                  onPressed: () => context.push('/task/new'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar tarea'),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 136),
                itemCount: tasks.length + 1,
                separatorBuilder: (context, index) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return CroniaAnimatedItem(
                      child: CroniaHeroHeader(
                        title: 'Tu día, más claro',
                        subtitle: '$pending pendientes · ${tasks.length} actividades en total',
                        icon: Icons.dashboard_customize_rounded,
                        trailing: _TaskCounter(count: tasks.length),
                      ),
                    );
                  }

                  return CroniaAnimatedItem(
                    index: index,
                    child: _TaskCard(task: tasks[index - 1]),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.push('/task/new'),
          tooltip: 'Agregar tarea',
          child: const Icon(Icons.add_rounded),
        ),
        bottomNavigationBar: const CroniaNavigationBar(selectedIndex: 0),
      ),
    );
  }
}

class _TaskCounter extends StatelessWidget {
  final int count;

  const _TaskCounter({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
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
    final dateText = task.startAt == null
        ? DateFormat('dd/MM/yyyy').format(task.date)
        : formatter.format(task.startAt!);

    return CroniaCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/task/${task.id}/edit'),
      borderColor: CroniaColors.line,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                color: task.priority.color,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: task.priority.color.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: task.priority.color.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Icon(
                              Icons.task_alt_rounded,
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
                                    color: CroniaColors.ink,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.schedule_rounded,
                                      size: 16,
                                      color: CroniaColors.muted,
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        dateText,
                                        style: const TextStyle(
                                          color: CroniaColors.muted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => context.push('/task/${task.id}/edit'),
                            icon: const Icon(Icons.edit_rounded, size: 19),
                            tooltip: 'Editar actividad',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoChip(
                            label: task.priority.label,
                            color: task.priority.color,
                            leading: Icons.flag_rounded,
                          ),
                          _InfoChip(
                            label: task.status.label,
                            color: CroniaColors.primary,
                            leading: Icons.circle_rounded,
                          ),
                          _InfoChip(
                            label: '${task.durationMinutes} min',
                            color: CroniaColors.muted,
                            leading: Icons.timer_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          TextButton.icon(
                            onPressed: task.status == TaskStatus.inProgress
                                ? null
                                : () => ref
                                    .read(taskControllerProvider.notifier)
                                    .start(task.id),
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('Iniciar'),
                          ),
                          TextButton.icon(
                            onPressed: () => ref
                                .read(taskControllerProvider.notifier)
                                .complete(task.id),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('Completar'),
                          ),
                          TextButton.icon(
                            onPressed: () => ref
                                .read(taskControllerProvider.notifier)
                                .cancel(task.id),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('Cancelar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData leading;

  const _InfoChip({
    required this.label,
    required this.color,
    required this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(leading, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: CroniaColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
