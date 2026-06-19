import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../models.dart';
import '../providers.dart';
import '../theme/cronia_theme.dart';
import '../widgets/cronia_ui.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _countryController = TextEditingController(text: 'Costa Rica');
  final _stateController = TextEditingController();
  final _wakeUpController = TextEditingController(text: '07:00');
  final _sleepController = TextEditingController(text: '23:00');

  bool _saving = false;
  String _timeZoneId = 'America/Costa_Rica';
  int _utcOffsetMinutes = -360;

  @override
  void dispose() {
    _nameController.dispose();
    _apiKeyController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    _wakeUpController.dispose();
    _sleepController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    final wakeUpTime = _wakeUpController.text.trim();
    final sleepTime = _sleepController.text.trim();

    if (name.isEmpty || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre y API key son obligatorios.')),
      );
      return;
    }

    if (!_isValidTime(wakeUpTime) || !_isValidTime(sleepTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usa formato HH:mm para levantarse y dormir.')),
      );
      return;
    }

    setState(() => _saving = true);

    final repo = ref.read(localRepositoryProvider);
    final secure = ref.read(secureStorageProvider);

    final profile = UserProfile(
      id: const Uuid().v4(),
      name: name,
      onboardingCompleted: true,
    );

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

    await repo.saveProfile(profile);
    await repo.saveSettings(settings);
    await secure.saveGeminiApiKey(apiKey);

    if (!mounted) return;

    context.go('/home');
  }

  bool _isValidTime(String value) {
    return RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value);
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
    return CroniaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            children: [
              const CroniaAnimatedItem(
                child: CroniaHeroHeader(
                  title: 'Project-Cronia',
                  subtitle: 'Tu asistente de planificación con IA, horarios y recordatorios.',
                  icon: Icons.bolt_rounded,
                ),
              ),
              const SizedBox(height: 18),
              CroniaAnimatedItem(
                index: 1,
                child: CroniaSectionCard(
                  title: 'Perfil',
                  subtitle: 'Datos básicos para personalizar tu planificación.',
                  icon: Icons.person_rounded,
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Tu nombre',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _apiKeyController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'API key de Gemini',
                          prefixIcon: Icon(Icons.key_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(
                            Icons.lock_rounded,
                            size: 16,
                            color: CroniaColors.muted,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'La API key se guarda localmente en almacenamiento seguro y no se exporta en los respaldos.',
                              style: TextStyle(fontSize: 12, color: CroniaColors.muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CroniaAnimatedItem(
                index: 2,
                child: CroniaSectionCard(
                  title: 'Ubicación y rutina',
                  subtitle: 'Esto ayuda a calcular fechas y horas sin desfases.',
                  icon: Icons.public_rounded,
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _timeZoneId,
                        decoration: const InputDecoration(
                          labelText: 'Zona horaria',
                          prefixIcon: Icon(Icons.public_rounded),
                        ),
                        items: croniaTimeZones.map((option) {
                          return DropdownMenuItem(
                            value: option.timeZoneId,
                            child: Text(option.label),
                          );
                        }).toList(),
                        onChanged: _applyTimeZoneOption,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _countryController,
                        decoration: const InputDecoration(
                          labelText: 'País',
                          prefixIcon: Icon(Icons.flag_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _stateController,
                        decoration: const InputDecoration(
                          labelText: 'Estado, provincia o región opcional',
                          prefixIcon: Icon(Icons.location_on_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final useVerticalLayout = constraints.maxWidth < 360;
                          final wakeField = TextField(
                            controller: _wakeUpController,
                            decoration: const InputDecoration(
                              labelText: 'Me levanto',
                              hintText: '07:00',
                              prefixIcon: Icon(Icons.wb_sunny_rounded),
                            ),
                          );
                          final sleepField = TextField(
                            controller: _sleepController,
                            decoration: const InputDecoration(
                              labelText: 'Duermo',
                              hintText: '23:00',
                              prefixIcon: Icon(Icons.nightlight_rounded),
                            ),
                          );

                          if (useVerticalLayout) {
                            return Column(
                              children: [
                                wakeField,
                                const SizedBox(height: 14),
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              CroniaAnimatedItem(
                index: 3,
                child: FilledButton.icon(
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
                      : const Icon(Icons.arrow_forward_rounded),
                  label: Text(_saving ? 'Guardando...' : 'Entrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
