import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models.dart';
import '../recurrence.dart';
import '../providers.dart';
import '../theme/cronia_theme.dart';
import '../widgets/cronia_ui.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  final String? taskId;
  final String? initialTitle;
  final DateTime? occurrenceDate;

  const TaskFormScreen({
    super.key,
    this.taskId,
    this.initialTitle,
    this.occurrenceDate,
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
  RecurrenceFrequency? _frequency;
  int _repeatInterval = 1;
  final Set<int> _repeatDays = {};
  RecurrenceEnd _repeatEnd = RecurrenceEnd.never;
  DateTime? _repeatUntil;
  int _repeatCount = 10;
  MonthlyPattern _monthlyPattern = MonthlyPattern.dayOfMonth;
  int _monthlyWeekday = DateTime.monday;
  int _weekdayPosition = 1;
  bool _recurrenceEdited = false;

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
      _occurrenceDate = widget.occurrenceDate;
      if (_occurrenceDate == null && task.recurrence != null) {
        final next = RecurrenceEngine.next(task.recurrence!, count: 1, after: now.subtract(const Duration(days: 1)));
        if (next.isNotEmpty) _occurrenceDate = next.first;
      }
      _selectedDate = _occurrenceDate ?? task.date;
      final start = task.startAt ?? task.date;
      _selectedTime = TimeOfDay(hour: start.hour, minute: start.minute);
      _priority = task.priority;
      _status = task.status;
      _isFlexible = task.isFlexible;
      _canBeMoved = task.canBeMoved;
      List<ReminderConfig>? loadedOverrideReminders;
      final rule = task.recurrence;
      if (rule != null) {
        _frequency = rule.frequency;
        _repeatInterval = rule.interval;
        _repeatDays.addAll(rule.weekdays);
        _repeatEnd = rule.end;
        _repeatUntil = rule.endDate;
        _repeatCount = rule.occurrenceCount ?? 10;
        _monthlyPattern = rule.monthlyPattern;
        _monthlyWeekday = rule.monthlyWeekday;
        _weekdayPosition = rule.weekdayPosition;
        final override = rule.occurrenceOverrides[RecurrenceEngine.key(_selectedDate)];
        if (override != null) {
          _titleController.text = override['title'] as String? ?? task.title;
          _descriptionController.text = override['description'] as String? ?? task.description ?? '';
          _durationController.text = (override['durationMinutes'] as int? ?? task.durationMinutes).toString();
          final overrideStart = override['startAt'] == null ? null : DateTime.tryParse(override['startAt'] as String);
          if (overrideStart != null) _selectedTime = TimeOfDay.fromDateTime(overrideStart);
          _priority = taskPriorityFromString(override['priority'] as String? ?? task.priority.name);
          _status = taskStatusFromString(override['status'] as String? ?? task.status.name);
          final overrideDate = override['date'] == null ? null : DateTime.tryParse(override['date'] as String);
          if (overrideDate != null) _selectedDate = overrideDate;
          final storedReminders = override['reminders'] as List?;
          if (storedReminders != null) {
            loadedOverrideReminders = storedReminders.map((r) => ReminderConfig.fromJson(Map<String, dynamic>.from(r as Map))).toList();
          }
        }
      }
      _loadReminderValues(task.copyWith(reminders: loadedOverrideReminders ?? task.reminders));
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
        recurrence: _frequency == null ? null : existing?.recurrence != null && !_recurrenceEdited ? existing!.recurrence : RecurrenceRule(
          frequency: _frequency!, interval: _repeatInterval,
          weekdays: _frequency == RecurrenceFrequency.weekly ? (_repeatDays.isEmpty ? [_selectedDate.weekday] : _repeatDays.toList()..sort()) : const [],
          dayOfMonth: _selectedDate.day,
          monthlyPattern: _monthlyPattern,
          monthlyWeekday: _monthlyWeekday,
          weekdayPosition: _weekdayPosition,
          startDate: _selectedDate, end: _repeatEnd,
          endDate: _repeatEnd == RecurrenceEnd.onDate ? _repeatUntil : null,
          occurrenceCount: _repeatEnd == RecurrenceEnd.afterCount ? _repeatCount : null,
          exceptions: existing?.recurrence?.exceptions ?? const [],
          completedDates: existing?.recurrence?.completedDates ?? const [],
          cancelledDates: existing?.recurrence?.cancelledDates ?? const [],
          occurrenceOverrides: existing?.recurrence?.occurrenceOverrides ?? const {},
        ),
      );

      if (_occurrenceDate != null && existing?.recurrence != null) {
        final scope = await _chooseRecurrenceScope();
        if (scope == null) return;
        await ref.read(taskControllerProvider.notifier).editOccurrence(seriesId: existing!.id, occurrenceDate: _occurrenceDate!, editedTask: task, scope: scope);
      } else {
        await ref.read(taskControllerProvider.notifier).upsert(task);
      }

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
    try {
      if (task.recurrence != null && _occurrenceDate != null) {
        final scope = await _chooseRecurrenceScope();
        if (scope == null || !mounted) return;
        await ref.read(taskControllerProvider.notifier).cancelOccurrence(seriesId: task.id, occurrenceDate: _occurrenceDate!, scope: scope);
      } else {
        await ref.read(taskControllerProvider.notifier).cancel(task.id);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo cancelar: $e')));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Actividad cancelada.')),
    );
    context.pop();
  }

  DateTime? _occurrenceDate;

  Future<RecurrenceEditScope?> _chooseRecurrenceScope() => showDialog<RecurrenceEditScope>(context: context, builder: (context) => SimpleDialog(
    title: const Text('Aplicar cambios a'),
    children: [
      SimpleDialogOption(onPressed: () => Navigator.pop(context, RecurrenceEditScope.occurrence), child: const Text('Solo esta ocurrencia')),
      SimpleDialogOption(onPressed: () => Navigator.pop(context, RecurrenceEditScope.thisAndFollowing), child: const Text('Esta y las siguientes')),
      SimpleDialogOption(onPressed: () => Navigator.pop(context, RecurrenceEditScope.series), child: const Text('Toda la serie')),
      SimpleDialogOption(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
    ],
  ));

  Future<void> _deleteSeries() async {
    final task = _editingTask;
    if (task?.recurrence == null) return;
    final scope = await _chooseRecurrenceScope();
    if (scope == null || !mounted) return;
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Confirmar eliminación'),
      content: Text(switch (scope) {
        RecurrenceEditScope.occurrence => 'Se eliminará solo la ocurrencia seleccionada.',
        RecurrenceEditScope.thisAndFollowing => 'Se eliminará esta ocurrencia y todas las posteriores.',
        RecurrenceEditScope.series => 'Se eliminará toda la serie y sus recordatorios pendientes.',
      }),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Conservar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar'))],
    ));
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(taskControllerProvider.notifier).deleteOccurrence(seriesId: task!.id, occurrenceDate: _occurrenceDate ?? task.date, scope: scope);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    }
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
                title: 'Repetir',
                subtitle: _editingTask?.recurrence == null
                    ? 'La regla se guarda una sola vez y las fechas se calculan en el dispositivo.'
                    : 'Guardar cambios actualiza la serie completa; editar solo una ocurrencia todavía no está disponible.',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  DropdownButtonFormField<RecurrenceFrequency?>(
                    value: _frequency,
                    decoration: const InputDecoration(labelText: 'Frecuencia', prefixIcon: Icon(Icons.repeat_rounded)),
                    items: [const DropdownMenuItem(value: null, child: Text('Sin repetición')), ...RecurrenceFrequency.values.map((f) => DropdownMenuItem(value: f, child: Text(switch (f) { RecurrenceFrequency.daily => 'Todos los días', RecurrenceFrequency.weekdays => 'Días laborables', RecurrenceFrequency.weekly => 'Semanal', RecurrenceFrequency.monthly => 'Mensual', RecurrenceFrequency.yearly => 'Anual' })))],
                    onChanged: (value) => setState(() { _frequency = value; _recurrenceEdited = true; }),
                  ),
                  if (_frequency != null) ...[
                    const SizedBox(height: 10),
                    if (_frequency != RecurrenceFrequency.weekdays && _frequency != RecurrenceFrequency.yearly)
                      Row(children: [const Text('Cada'), const SizedBox(width: 12), SizedBox(width: 74, child: TextFormField(initialValue: '$_repeatInterval', keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(suffixText: 'veces'), onChanged: (v) { _repeatInterval = (int.tryParse(v) ?? 1).clamp(1, 365).toInt(); _recurrenceEdited = true; })), const SizedBox(width: 8), Text(_frequency == RecurrenceFrequency.daily ? 'días' : _frequency == RecurrenceFrequency.weekly ? 'semanas' : 'meses')]),
                    if (_frequency == RecurrenceFrequency.weekly) Wrap(spacing: 4, children: List.generate(7, (i) { final day = i + 1; const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D']; return FilterChip(label: Text(labels[i]), selected: _repeatDays.contains(day), onSelected: (on) => setState(() { on ? _repeatDays.add(day) : _repeatDays.remove(day); _recurrenceEdited = true; })); })),
                    if (_frequency == RecurrenceFrequency.monthly) ...[
                      DropdownButtonFormField<MonthlyPattern>(value: _monthlyPattern, decoration: const InputDecoration(labelText: 'Patrón mensual'), items: const [DropdownMenuItem(value: MonthlyPattern.dayOfMonth, child: Text('Día del mes')), DropdownMenuItem(value: MonthlyPattern.weekdayPosition, child: Text('Posición del día de la semana'))], onChanged: (v) => setState(() { _monthlyPattern = v ?? MonthlyPattern.dayOfMonth; _recurrenceEdited = true; })),
                      if (_monthlyPattern == MonthlyPattern.weekdayPosition) Row(children: [Expanded(child: DropdownButtonFormField<int>(value: _weekdayPosition, decoration: const InputDecoration(labelText: 'Posición'), items: const [DropdownMenuItem(value: 1, child: Text('Primero')), DropdownMenuItem(value: 2, child: Text('Segundo')), DropdownMenuItem(value: 3, child: Text('Tercero')), DropdownMenuItem(value: 4, child: Text('Cuarto')), DropdownMenuItem(value: -1, child: Text('Último'))], onChanged: (v) => setState(() { _weekdayPosition = v ?? 1; _recurrenceEdited = true; }))), const SizedBox(width: 10), Expanded(child: DropdownButtonFormField<int>(value: _monthlyWeekday, decoration: const InputDecoration(labelText: 'Día'), items: const [DropdownMenuItem(value: DateTime.monday, child: Text('Lunes')), DropdownMenuItem(value: DateTime.tuesday, child: Text('Martes')), DropdownMenuItem(value: DateTime.wednesday, child: Text('Miércoles')), DropdownMenuItem(value: DateTime.thursday, child: Text('Jueves')), DropdownMenuItem(value: DateTime.friday, child: Text('Viernes')), DropdownMenuItem(value: DateTime.saturday, child: Text('Sábado')), DropdownMenuItem(value: DateTime.sunday, child: Text('Domingo'))], onChanged: (v) => setState(() { _monthlyWeekday = v ?? DateTime.monday; _recurrenceEdited = true; })))])
                    ],
                    DropdownButtonFormField<RecurrenceEnd>(value: _repeatEnd, decoration: const InputDecoration(labelText: 'Finalizar'), items: const [DropdownMenuItem(value: RecurrenceEnd.never, child: Text('Nunca')), DropdownMenuItem(value: RecurrenceEnd.onDate, child: Text('En una fecha')), DropdownMenuItem(value: RecurrenceEnd.afterCount, child: Text('Después de ocurrencias'))], onChanged: (value) => setState(() { _repeatEnd = value ?? RecurrenceEnd.never; _recurrenceEdited = true; })),
                    if (_repeatEnd == RecurrenceEnd.afterCount) TextFormField(initialValue: '$_repeatCount', keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cantidad de ocurrencias'), onChanged: (v) { _repeatCount = (int.tryParse(v) ?? 1).clamp(1, 10000).toInt(); _recurrenceEdited = true; }),
                    if (_repeatEnd == RecurrenceEnd.onDate) ListTile(title: Text(_repeatUntil == null ? 'Seleccionar fecha final' : DateFormat('dd/MM/yyyy').format(_repeatUntil!)), trailing: const Icon(Icons.calendar_month), onTap: () async { final picked = await showDatePicker(context: context, initialDate: _repeatUntil ?? _selectedDate.add(const Duration(days: 30)), firstDate: _selectedDate, lastDate: DateTime(2100)); if (picked != null) setState(() { _repeatUntil = picked; _recurrenceEdited = true; }); }),
                    if (_frequency != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Próximas fechas: ${RecurrenceEngine.next(RecurrenceRule(frequency: _frequency!, interval: _repeatInterval, weekdays: _repeatDays.toList(), startDate: _selectedDate, end: _repeatEnd, endDate: _repeatUntil, occurrenceCount: _repeatCount, dayOfMonth: _selectedDate.day, monthlyPattern: _monthlyPattern, monthlyWeekday: _monthlyWeekday, weekdayPosition: _weekdayPosition), count: 5, after: _selectedDate.subtract(const Duration(days: 1))).map((d) => DateFormat('dd/MM').format(d)).join(', ')}', style: const TextStyle(color: CroniaColors.muted, fontWeight: FontWeight.w600))),
                  ],
                ]),
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
                if (_editingTask?.recurrence != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(onPressed: _saving ? null : _deleteSeries, icon: const Icon(Icons.delete_outline), label: const Text('Eliminar repetición…')),
                ],
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
