import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _importController = TextEditingController();

  @override
  void dispose() {
    _apiKeyController.dispose();
    _importController.dispose();
    super.dispose();
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

  Future<void> _exportJson() async {
    final raw = await ref.read(localRepositoryProvider).exportJson();

    await Clipboard.setData(ClipboardData(text: raw));

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Gemini',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKeyController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Nueva API key de Gemini',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saveApiKey,
            child: const Text('Guardar API key'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Exportar datos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _exportJson,
            icon: const Icon(Icons.copy),
            label: const Text('Copiar JSON de respaldo'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Importar datos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _importController,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Pega aquí el JSON exportado',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _importJson,
            child: const Text('Importar JSON'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Módulos ya preparados para próxima fase: edición completa de actividades, comidas, cocina, recordatorios personalizados y migración a Drift/SQLite.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 3,
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
