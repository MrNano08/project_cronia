import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models.dart';
import '../providers.dart';
import '../theme/cronia_theme.dart';
import '../widgets/cronia_ui.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  final String? taskId;
  final String? initialTitle;

  const TaskFormScreen({
    super.key,
    this.taskId,
    this.initialTitle,
  });

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  final _daysBeforeController = TextEditingController();
  final _hoursBeforeController = TextEditingController();
  final _minutesBeforeController = TextEditingController(text: '15');

  bool _loading = true;
  bool _saving = false;
  CroniaTask? _editingTask;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  TaskPriority _priority = TaskPriority.medium;
  TaskStatus _status = TaskStatus.pending;
  bool _isFlexible = true;
  bool _canBeMoved = true;

  bool get _isEditing => widget.taskId != null;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.initialTitle?.trim() ?? '';
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final repo = ref.read(localRepositoryProvider);
    final settings = await repo.getSettings();
    final now = settings.userNow();

    CroniaTask? task;
    if (widget.taskId != null) {
      final tasks = await repo.getTasks();
      task = tasks.firstWhereOrNull((item) => item.id == widget.taskId);
    }

    if (!mounted) return;

    if (task != null) {
      _editingTask = task;
      _titleController.text = task.title;
      _descriptionController.text = task.description ?? '';
      _durationController.text = task.durationMinutes.toString();
      _selectedDate = task.date;
      final start = task.startAt ?? task.date;
      _selectedTime = TimeOfDay(hour: start.hour, minute: start.minute);
      _priority = task.priority;
      _status = task.status;
      _isFlexible = task.isFlexible;
      _canBeMoved = task.canBeMoved;
      _loadReminderValues(task);
    } else {
      _selectedDate = DateTime(now.year, now.month, now.day);
      _selectedTime = TimeOfDay(hour: now.hour, minute: now.minute);
    }

    setState(() => _loading = false);
  }

  void _loadReminderValues(CroniaTask task) {
    for (final reminder in task.reminders) {
      if (reminder.daysBefore != null && reminder.daysBefore! > 0) {
        _daysBeforeController.text = reminder.daysBefore.toString();
      }
      if (reminder.hoursBefore != null && reminder.hoursBefore! > 0) {
        _hoursBeforeController.text = reminder.hoursBefore.toString();
      }
      if (reminder.minutesBefore != null && reminder.minutesBefore! > 0) {
        _minutesBeforeController.text = reminder.minutesBefore.toString();
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _daysBeforeController.dispose();
    _hoursBeforeController.dispose();
    _minutesBeforeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2035, 12, 31),
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (picked == null) return;

    setState(() => _selectedTime = picked);
  }

  int? _parseOptionalPositiveInt(TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isEmpty) return null;

    final number = int.tryParse(value);
    if (number == null || number <= 0) return null;

    return number;
  }

  DateTime _selectedStartDateTime() {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  List<ReminderConfig> _buildReminders({
    required String taskId,
    required DateTime startAt,
    required DateTime endAt,
  }) {
    final reminders = <ReminderConfig>[];
    final daysBefore = _parseOptionalPositiveInt(_daysBeforeController);
    final hoursBefore = _parseOptionalPositiveInt(_hoursBeforeController);
    final minutesBefore = _parseOptionalPositiveInt(_minutesBeforeController);

    if (daysBefore != null) {
      reminders.add(
        ReminderConfig(
          id: const Uuid().v4(),
          taskId: taskId,
          type: ReminderType.daysBefore,
          scheduledAt: startAt.subtract(Duration(days: daysBefore)),
          daysBefore: daysBefore,
        ),
      );
    }

    if (hoursBefore != null) {
      reminders.add(
        ReminderConfig(
          id: const Uuid().v4(),
          taskId: taskId,
          type: ReminderType.hoursBefore,
          scheduledAt: startAt.subtract(Duration(hours: hoursBefore)),
          hoursBefore: hoursBefore,
        ),
      );
    }

    if (minutesBefore != null) {
      reminders.add(
        ReminderConfig(
          id: const Uuid().v4(),
          taskId: taskId,
          type: ReminderType.beforeStart,
          scheduledAt: startAt.subtract(Duration(minutes: minutesBefore)),
          minutesBefore: minutesBefore,
        ),
      );
    }

    reminders.addAll([
      ReminderConfig(
        id: const Uuid().v4(),
        taskId: taskId,
        type: ReminderType.atStart,
        scheduledAt: startAt,
      ),
      ReminderConfig(
        id: const Uuid().v4(),
        taskId: taskId,
        type: ReminderType.atEnd,
        scheduledAt: endAt,
      ),
    ]);

    return reminders;
  }

  Future<void> _save() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() => _saving = true);

    try {
      final repo = ref.read(localRepositoryProvider);
      final settings = await repo.getSettings();
      final now = settings.userNow();
      final startAt = _selectedStartDateTime();
      final duration = int.parse(_durationController.text.trim());
      final endAt = startAt.add(Duration(minutes: duration));
      final existing = _editingTask;
      final id = existing?.id ?? const Uuid().v4();

      final task = CroniaTask(
        id: id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        date: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
        startAt: startAt,
        endAt: endAt,
        durationMinutes: duration,
        priority: _priority,
        status: _status,
        isFlexible: _isFlexible,
        canBeMoved: _canBeMoved,
        deadline: existing?.deadline,
        startedAt: existing?.startedAt,
        completedAt: existing?.completedAt,
        reminders: _buildReminders(taskId: id, startAt: startAt, endAt: endAt),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      await ref.read(taskControllerProvider.notifier).upsert(task);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Actividad actualizada.' : 'Actividad agregada.'),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _markCancelled() async {
    final task = _editingTask;
    if (task == null) return;

    await ref.read(taskControllerProvider.notifier).cancel(task.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Actividad cancelada.')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const CroniaBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final dateLabel = DateFormat('dd/MM/yyyy').format(_selectedDate);
    final timeLabel = _selectedTime.format(context);

    return CroniaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(_isEditing ? 'Editar actividad' : 'Agregar actividad'),
        ),
        body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              _SectionCard(
                title: 'Datos principales',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Título',
                        prefixIcon: Icon(Icons.task_alt_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El título es obligatorio.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Descripción opcional',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Duración en minutos',
                        prefixIcon: Icon(Icons.timer_outlined),
                      ),
                      validator: (value) {
                        final number = int.tryParse(value?.trim() ?? '');
                        if (number == null || number <= 0) {
                          return 'Indica una duración mayor a cero.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Fecha y hora',
                child: Column(
                  children: [
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      tileColor: CroniaColors.surfaceSoft,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: const Icon(Icons.calendar_month_outlined),
                      title: const Text('Fecha'),
                      subtitle: Text(dateLabel),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      tileColor: CroniaColors.surfaceSoft,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: const Icon(Icons.schedule_outlined),
                      title: const Text('Hora de inicio'),
                      subtitle: Text(timeLabel),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickTime,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Prioridad y estado',
                child: Column(
                  children: [
                    DropdownButtonFormField<TaskPriority>(
                      value: _priority,
                      decoration: const InputDecoration(
                        labelText: 'Prioridad',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      items: TaskPriority.values.map((priority) {
                        return DropdownMenuItem(
                          value: priority,
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: priority.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(priority.label),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _priority = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<TaskStatus>(
                      value: _status,
                      decoration: const InputDecoration(
                        labelText: 'Estado',
                        prefixIcon: Icon(Icons.fact_check_outlined),
                      ),
                      items: TaskStatus.values.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _status = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('La IA puede mover esta actividad'),
                      value: _canBeMoved,
                      onChanged: (value) => setState(() => _canBeMoved = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Actividad flexible'),
                      value: _isFlexible,
                      onChanged: (value) => setState(() => _isFlexible = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Recordatorios',
                subtitle: 'Puedes dejar campos vacíos si no los necesitas.',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _daysBeforeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Días antes',
                        prefixIcon: Icon(Icons.event_available_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _hoursBeforeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Horas antes',
                        prefixIcon: Icon(Icons.more_time_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _minutesBeforeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Minutos antes',
                        prefixIcon: Icon(Icons.notifications_active_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Guardando...' : 'Guardar actividad'),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _markCancelled,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Marcar como cancelada'),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CroniaAnimatedItem(
      child: CroniaSectionCard(
        title: title,
        subtitle: subtitle,
        child: child,
      ),
    );
  }
}
