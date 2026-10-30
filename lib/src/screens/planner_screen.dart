import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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

    final current = ref.read(taskControllerProvider);
    final affectedIds = result.tasks.map((t) => t.existingTaskId).whereType<String>().toSet();
    final proposed = result.tasks.where((t) => t.action != 'delete_request' && t.action != 'cancel' && t.startAt != null && t.endAt != null).toList();
    final conflicts = <String>{};
    for (var i = 0; i < proposed.length; i++) {
      final p = proposed[i];
      final existing = current.where((task) => !affectedIds.contains(task.id) && task.status != TaskStatus.cancelled && task.status != TaskStatus.completed && task.startAt != null && task.endAt != null);
      for (final task in existing) {
        if (p.startAt!.isBefore(task.endAt!) && p.endAt!.isAfter(task.startAt!)) conflicts.add('${p.title} coincide con ${task.title}.');
      }
      for (var j = i + 1; j < proposed.length; j++) {
        final other = proposed[j];
        if (p.startAt!.isBefore(other.endAt!) && p.endAt!.isAfter(other.startAt!)) conflicts.add('${p.title} coincide con ${other.title}.');
      }
    }
    if (conflicts.isNotEmpty) {
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('Revisa los horarios'), content: Text(conflicts.join('\n')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))]));
      return;
    }

    try {
      await ref.read(taskControllerProvider.notifier).applyPlannedTasks(result.tasks);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))));
      return;
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

  Future<void> _editProposal(int index) async {
    final current = _result;
    if (current == null || index < 0 || index >= current.tasks.length) return;
    final task = current.tasks[index];
    final title = TextEditingController(text: task.title);
    var date = task.date;
    var time = task.startAt == null ? const TimeOfDay(hour: 9, minute: 0) : TimeOfDay.fromDateTime(task.startAt!);
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, refresh) => AlertDialog(
      title: const Text('Editar propuesta'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Título')),
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('Fecha'), subtitle: Text(DateFormat('dd/MM/yyyy').format(date)), onTap: () async { final picked = await showDatePicker(context: dialogContext, initialDate: date, firstDate: DateTime(2024), lastDate: DateTime(2100)); if (picked != null) refresh(() => date = picked); }),
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('Hora'), subtitle: Text(time.format(dialogContext)), onTap: () async { final picked = await showTimePicker(context: dialogContext, initialTime: time); if (picked != null) refresh(() => time = picked); }),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Guardar'))],
    )));
    final editedTitle = title.text.trim();
    title.dispose();
    if (saved != true || !mounted) return;
    final start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final updated = task.copyWith(title: editedTitle.isEmpty ? task.title : editedTitle, date: DateTime(date.year, date.month, date.day), startAt: start, endAt: start.add(Duration(minutes: task.durationMinutes)));
    final tasks = List<PlannedTask>.from(current.tasks);
    tasks[index] = updated;
    setState(() => _result = PlanningResult(version: current.version, summary: current.summary, requiresUserConfirmation: current.requiresUserConfirmation, tasks: tasks, warnings: current.warnings, diagnostics: current.diagnostics));
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
                      ? _PlanningPreview(result: result, onApply: _applyPlan, onEdit: _editProposal)
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
  final ValueChanged<int> onEdit;

  const _PlanningPreview({required this.result, required this.onApply, required this.onEdit});

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
                              '${task.startAt == null ? DateFormat('dd/MM/yyyy').format(task.date) : DateFormat('EEE dd/MM · HH:mm').format(task.startAt!)} · ${task.durationMinutes} min · ${task.priority.label}${task.recurrence == null ? '' : ' · Repite: ${task.recurrence!.frequency.name}'}',
                              style: const TextStyle(
                                color: CroniaColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () => onEdit(index), icon: const Icon(Icons.edit_outlined), tooltip: 'Editar propuesta'),
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
