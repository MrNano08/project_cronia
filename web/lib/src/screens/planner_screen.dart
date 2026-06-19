import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models.dart';
import '../providers.dart';
import '../theme/cronia_theme.dart';
import '../widgets/cronia_ui.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  PlanningResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendToGemini() async {
    final input = _controller.text.trim();

    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe una actividad o instrucción.')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final gemini = ref.read(geminiServiceProvider);
      final repo = ref.read(localRepositoryProvider);
      final tasks = ref.read(taskControllerProvider);
      final meals = await repo.getMealBlocks();
      final settings = await repo.getSettings();

      final result = await gemini.plan(
        userInput: input,
        existingTasks: tasks,
        mealBlocks: meals,
        settings: settings,
      );

      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _applyPlan() async {
    final result = _result;
    if (result == null) return;

    final controller = ref.read(taskControllerProvider.notifier);

    for (final task in result.tasks) {
      if (task.action == 'delete_request') continue;
      await controller.applyPlannedTask(task);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Plan aplicado.')),
    );

    setState(() {
      _result = null;
      _controller.clear();
    });
  }

  void _openManualForm() {
    final input = _controller.text.trim();
    context.push('/task/new', extra: input.isEmpty ? null : input);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return CroniaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppBar(title: const Text('Planificar con IA')),
        body: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 98),
          child: Column(
            children: [
              CroniaAnimatedItem(
                child: CroniaHeroHeader(
                  title: 'Organiza sin fricción',
                  subtitle: 'Describe tu día y revisa la propuesta antes de aplicarla.',
                  icon: Icons.auto_awesome_rounded,
                ),
              ),
              const SizedBox(height: 14),
              CroniaAnimatedItem(
                index: 1,
                child: CroniaCard(
                  padding: const EdgeInsets.all(14),
                  child: TextField(
                    controller: _controller,
                    minLines: 5,
                    maxLines: 9,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(left: 12, right: 4, bottom: 92),
                        child: Icon(Icons.edit_calendar_rounded),
                      ),
                      labelText: 'Escribe lo que quieres organizar',
                      hintText:
                          'Ejemplo: hoy a las 12 p. m. almuerzo una hora, prioridad media.',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              CroniaAnimatedItem(
                index: 2,
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _sendToGemini,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.auto_awesome_rounded),
                        label: Text(_loading ? 'Procesando...' : 'Enviar a Gemini'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.outlined(
                      onPressed: _loading ? null : _openManualForm,
                      icon: const Icon(Icons.add_rounded),
                      tooltip: 'Agregar tarea a mano',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: result != null
                      ? _PlanningPreview(result: result, onApply: _applyPlan)
                      : const CroniaEmptyState(
                          icon: Icons.tips_and_updates_rounded,
                          title: 'Esperando instrucciones',
                          subtitle: 'Aquí aparecerá la propuesta de planificación generada por Gemini.',
                        ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const CroniaNavigationBar(selectedIndex: 2),
      ),
    );
  }
}

class _PlanningPreview extends StatelessWidget {
  final PlanningResult result;
  final VoidCallback onApply;

  const _PlanningPreview({required this.result, required this.onApply});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CroniaCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: CroniaColors.heroGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.route_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result.summary,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (result.warnings.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CroniaColors.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: CroniaColors.warning.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: result.warnings.map((w) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $w',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: result.tasks.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final task = result.tasks[index];

              return CroniaAnimatedItem(
                index: index,
                child: CroniaCard(
                  padding: const EdgeInsets.all(14),
                  borderColor: task.priority.color.withValues(alpha: 0.2),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: task.priority.color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(Icons.task_alt_rounded, color: task.priority.color),
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
                              '${task.action} · ${task.durationMinutes} min · ${task.priority.label}',
                              style: const TextStyle(
                                color: CroniaColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onApply,
          icon: const Icon(Icons.check_circle_rounded),
          label: const Text('Aplicar propuesta'),
        ),
      ],
    );
  }
}
