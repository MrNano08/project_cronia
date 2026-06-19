import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models.dart';
import '../providers.dart';
import '../theme/cronia_theme.dart';
import '../widgets/cronia_ui.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _importController = TextEditingController();
  final _countryController = TextEditingController();
  final _stateController = TextEditingController();
  final _wakeUpController = TextEditingController();
  final _sleepController = TextEditingController();
  final _mealNameController = TextEditingController();
  final _mealTimeController = TextEditingController();
  final _mealDurationController = TextEditingController(text: '45');
  final _cookingDurationController = TextEditingController(text: '30');

  bool _loading = true;
  bool _needsCooking = false;
  String _timeZoneId = 'America/Costa_Rica';
  int _utcOffsetMinutes = -360;
  List<MealBlock> _meals = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _importController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    _wakeUpController.dispose();
    _sleepController.dispose();
    _mealNameController.dispose();
    _mealTimeController.dispose();
    _mealDurationController.dispose();
    _cookingDurationController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final repo = ref.read(localRepositoryProvider);
    final settings = await repo.getSettings();
    final meals = await repo.getMealBlocks();

    if (!mounted) return;

    setState(() {
      _countryController.text = settings.country;
      _stateController.text = settings.state;
      _wakeUpController.text = settings.wakeUpTime;
      _sleepController.text = settings.sleepTime;
      _timeZoneId = settings.timeZoneId;
      _utcOffsetMinutes = settings.utcOffsetMinutes;
      _meals = meals;
      _loading = false;
    });
  }

  Future<void> _saveApiKey() async {
    final value = _apiKeyController.text.trim();

    if (value.isEmpty) return;

    await ref.read(secureStorageProvider).saveGeminiApiKey(value);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API key actualizada.')),
    );

    _apiKeyController.clear();
  }

  Future<void> _saveSettings() async {
    final wakeUpTime = _wakeUpController.text.trim();
    final sleepTime = _sleepController.text.trim();

    if (!_isValidTime(wakeUpTime) || !_isValidTime(sleepTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usa formato HH:mm para levantarse y dormir.')),
      );
      return;
    }

    final settings = AppSettings(
      country: _countryController.text.trim().isEmpty
          ? 'No indicado'
          : _countryController.text.trim(),
      state: _stateController.text.trim(),
      timeZoneId: _timeZoneId,
      utcOffsetMinutes: _utcOffsetMinutes,
      wakeUpTime: wakeUpTime,
      sleepTime: sleepTime,
    );

    await ref.read(localRepositoryProvider).saveSettings(settings);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuración guardada.')),
    );
  }

  Future<void> _addMeal() async {
    final name = _mealNameController.text.trim();
    final time = _mealTimeController.text.trim();
    final duration = int.tryParse(_mealDurationController.text.trim());
    final cookingDuration = int.tryParse(_cookingDurationController.text.trim());

    if (name.isEmpty || !_isValidTime(time) || duration == null || duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa nombre, hora y duración de la comida.')),
      );
      return;
    }

    if (_needsCooking && (cookingDuration == null || cookingDuration <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indica cuánto tardas cocinando.')),
      );
      return;
    }

    final meal = MealBlock(
      id: const Uuid().v4(),
      name: name,
      time: time,
      durationMinutes: duration,
      needsCooking: _needsCooking,
      cookingDurationMinutes: _needsCooking ? cookingDuration : null,
    );

    final updated = [..._meals, meal];
    await ref.read(localRepositoryProvider).saveMealBlocks(updated);

    if (!mounted) return;

    setState(() {
      _meals = updated;
      _mealNameController.clear();
      _mealTimeController.clear();
      _mealDurationController.text = '45';
      _cookingDurationController.text = '30';
      _needsCooking = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hora de comida agregada.')),
    );
  }

  Future<void> _deleteMeal(String id) async {
    final updated = _meals.where((meal) => meal.id != id).toList();
    await ref.read(localRepositoryProvider).saveMealBlocks(updated);

    if (!mounted) return;

    setState(() => _meals = updated);
  }

  Future<void> _exportJson() async {
    final raw = await ref.read(localRepositoryProvider).exportJson();

    await Clipboard.setData(ClipboardData(text: raw));

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('JSON exportado'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(child: SelectableText(raw)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importJson() async {
    final raw = _importController.text.trim();

    if (raw.isEmpty) return;

    try {
      await ref.read(localRepositoryProvider).importJson(raw, replace: true);
      await ref.read(taskControllerProvider.notifier).load();
      await _loadSettings();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos importados.')),
      );

      _importController.clear();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importando JSON: $e')),
      );
    }
  }

  bool _isValidTime(String value) {
    final match = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value);
    return match;
  }

  void _applyTimeZoneOption(String? timeZoneId) {
    if (timeZoneId == null) return;

    final selected = croniaTimeZones.firstWhere(
      (option) => option.timeZoneId == timeZoneId,
      orElse: () => croniaTimeZones.first,
    );

    setState(() {
      _timeZoneId = selected.timeZoneId;
      _utcOffsetMinutes = selected.utcOffsetMinutes;
      _countryController.text = selected.country;
      _stateController.text = selected.state;
    });
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

    return CroniaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppBar(title: const Text('Configuración')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 112),
        children: [
          _SectionCard(
            title: 'Ubicación y zona horaria',
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: croniaTimeZones.any((z) => z.timeZoneId == _timeZoneId)
                      ? _timeZoneId
                      : croniaTimeZones.first.timeZoneId,
                  decoration: const InputDecoration(
                    labelText: 'Zona horaria',
                    prefixIcon: Icon(Icons.public),
                  ),
                  selectedItemBuilder: (context) {
                    return croniaTimeZones.map((option) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          option.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList();
                  },
                  items: croniaTimeZones.map((option) {
                    return DropdownMenuItem(
                      value: option.timeZoneId,
                      child: Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _applyTimeZoneOption,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _countryController,
                  decoration: const InputDecoration(
                    labelText: 'País',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _stateController,
                  decoration: const InputDecoration(
                    labelText: 'Estado, provincia o región opcional',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Configurado: ${AppSettings(country: _countryController.text, state: _stateController.text, timeZoneId: _timeZoneId, utcOffsetMinutes: _utcOffsetMinutes, wakeUpTime: _wakeUpController.text, sleepTime: _sleepController.text).utcOffsetLabel}',
                    style: const TextStyle(color: CroniaColors.muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Sueño y rutina diaria',
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useVerticalLayout = constraints.maxWidth < 360;

                    final wakeField = TextField(
                      controller: _wakeUpController,
                      decoration: const InputDecoration(
                        labelText: 'Me levanto',
                        hintText: '07:00',
                        prefixIcon: Icon(Icons.wb_sunny_outlined),
                      ),
                    );

                    final sleepField = TextField(
                      controller: _sleepController,
                      decoration: const InputDecoration(
                        labelText: 'Duermo',
                        hintText: '23:00',
                        prefixIcon: Icon(Icons.nightlight_outlined),
                      ),
                    );

                    if (useVerticalLayout) {
                      return Column(
                        children: [
                          wakeField,
                          const SizedBox(height: 12),
                          sleepField,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: wakeField),
                        const SizedBox(width: 12),
                        Expanded(child: sleepField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar ubicación y rutina'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Horas de comida',
            child: Column(
              children: [
                TextField(
                  controller: _mealNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Almuerzo',
                    prefixIcon: Icon(Icons.restaurant_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useVerticalLayout = constraints.maxWidth < 360;

                    final timeField = TextField(
                      controller: _mealTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Hora',
                        hintText: '12:00',
                      ),
                    );

                    final durationField = TextField(
                      controller: _mealDurationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duración min',
                        hintText: '45',
                      ),
                    );

                    if (useVerticalLayout) {
                      return Column(
                        children: [
                          timeField,
                          const SizedBox(height: 12),
                          durationField,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: timeField),
                        const SizedBox(width: 12),
                        Expanded(child: durationField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _needsCooking,
                  title: const Text('Necesito cocinar antes'),
                  onChanged: (value) => setState(() => _needsCooking = value),
                ),
                if (_needsCooking) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _cookingDurationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tiempo de cocina en minutos',
                      hintText: '30',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _addMeal,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar comida'),
                  ),
                ),
                if (_meals.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ..._meals.map(
                    (meal) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CroniaCard(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                        title: Text('${meal.name} · ${meal.time}'),
                        subtitle: Text(
                          '${meal.durationMinutes} min${meal.needsCooking ? ' · cocina ${meal.cookingDurationMinutes} min antes' : ''}',
                        ),
                        trailing: IconButton(
                          onPressed: () => _deleteMeal(meal.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    ),
                  ),
                ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Gemini',
            child: Column(
              children: [
                TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nueva API key de Gemini',
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saveApiKey,
                    child: const Text('Guardar API key'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Exportar e importar datos',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _exportJson,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar JSON de respaldo'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _importController,
                  minLines: 5,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Pega aquí el JSON exportado',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _importJson,
                  child: const Text('Importar JSON'),
                ),
              ],
            ),
          ),
        ],
      ),
        bottomNavigationBar: const CroniaNavigationBar(selectedIndex: 3),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return CroniaAnimatedItem(
      child: CroniaSectionCard(
        title: title,
        child: child,
      ),
    );
  }
}
