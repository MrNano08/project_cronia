import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../models.dart';
import '../providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (name.isEmpty || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre y API key son obligatorios.')),
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

    await repo.saveProfile(profile);
    await secure.saveGeminiApiKey(apiKey);

    if (!mounted) return;

    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        minimum: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Project-Cronia',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configura tu asistente de planificación.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tu nombre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'API key de Gemini',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'La API key se guarda localmente en almacenamiento seguro y no se exporta en los respaldos.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Guardando...' : 'Entrar'),
            ),
          ],
        ),
      ),
    );
  }
}
