import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'src/providers.dart';
import 'src/services/notification_service.dart';
import 'src/services/local_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await NotificationService.instance.init();
  final repository = LocalRepository(prefs);
  Future<void> refreshNotifications() async {
    final settings = await repository.getSettings();
    final tasks = await repository.getTasks();
    for (final task in tasks) {
      await NotificationService.instance.scheduleForTask(task, settings: settings);
    }
  }
  NotificationService.instance.onResume = refreshNotifications;
  await refreshNotifications();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const CroniaApp(),
    ),
  );
}
