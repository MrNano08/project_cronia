import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'src/screens/calendar_screen.dart';
import 'src/screens/home_screen.dart';
import 'src/screens/onboarding_screen.dart';
import 'src/screens/planner_screen.dart';
import 'src/screens/settings_screen.dart';
import 'src/screens/task_form_screen.dart';
import 'src/screens/splash_screen.dart';
import 'src/theme/cronia_theme.dart';

class CroniaApp extends StatelessWidget {
  const CroniaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/planner',
          builder: (context, state) => const PlannerScreen(),
        ),
        GoRoute(
          path: '/calendar',
          builder: (context, state) => const CalendarScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/task/new',
          builder: (context, state) {
            final initialTitle = state.extra is String ? state.extra as String : null;
            return TaskFormScreen(initialTitle: initialTitle);
          },
        ),
        GoRoute(
          path: '/task/:id/edit',
          builder: (context, state) {
            return TaskFormScreen(taskId: state.pathParameters['id']);
          },
        ),
      ],
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Project-Cronia',
      theme: buildCroniaTheme(),
      routerConfig: router,
    );
  }
}
