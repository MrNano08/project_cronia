import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models.dart';
import '../providers.dart';

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

      final result = await gemini.plan(
        userInput: input,
        existingTasks: tasks,
        mealBlocks: meals,
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

  Future<void> _createManualFallback() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    await ref.read(taskControllerProvider.notifier).createManual(
          title: input,
          date: DateTime.now(),
          durationMinutes: 30,
          priority: TaskPriority.medium,
        );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Actividad creada manualmente.')),
    );

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('Planificar con IA')),
      body: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Escribe lo que quieres organizar',
                hintText:
                    'Ejemplo: mañana estudiar 2 horas, cocinar antes del almuerzo y entregar tarea el viernes.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _sendToGemini,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(_loading ? 'Procesando...' : 'Enviar a Gemini'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: _loading ? null : _createManualFallback,
                  icon: const Icon(Icons.add),
                  tooltip: 'Crear rápido sin IA',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (result != null)
              Expanded(
                child: _PlanningPreview(result: result, onApply: _applyPlan),
              )
            else
              const Expanded(
                child: Center(
                  child: Text('Aquí aparecerá la propuesta de planificación.'),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 2,
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

class _PlanningPreview extends StatelessWidget {
  final PlanningResult result;
  final VoidCallback onApply;

  const _PlanningPreview({required this.result, required this.onApply});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(result.summary, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (result.warnings.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: result.warnings.map((w) => Text('• $w')).toList(),
            ),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: result.tasks.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final task = result.tasks[index];

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: task.priority.color,
                    child: const Icon(Icons.task_alt, color: Colors.white),
                  ),
                  title: Text(task.title),
                  subtitle: Text(
                    '${task.action} · ${task.durationMinutes} min · ${task.priority.label}',
                  ),
                ),
              );
            },
          ),
        ),
        FilledButton(
          onPressed: onApply,
          child: const Text('Aplicar propuesta'),
        ),
      ],
    );
  }
}
