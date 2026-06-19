import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/cronia_ui.dart';

import '../providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final repo = ref.read(localRepositoryProvider);
    final profile = await repo.getProfile();

    if (!mounted) return;

    if (profile == null || !profile.onboardingCompleted) {
      context.go('/onboarding');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const CroniaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CroniaAnimatedItem(
            child: CroniaCard(
              padding: EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: CircularProgressIndicator(strokeWidth: 4),
                  ),
                  SizedBox(height: 18),
                  Text(
                    'Project-Cronia',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
