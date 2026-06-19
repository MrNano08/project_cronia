import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

class LocalRepository {
  final SharedPreferences prefs;

  static const String _profileKey = 'profile';
  static const String _settingsKey = 'app_settings';
  static const String _tasksKey = 'tasks';
  static const String _mealsKey = 'meal_blocks';

  LocalRepository(this.prefs);

  Future<UserProfile?> getProfile() async {
    final raw = prefs.getString(_profileKey);
    if (raw == null) return null;

    return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveProfile(UserProfile profile) async {
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  Future<AppSettings> getSettings() async {
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return AppSettings.defaults();

    return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSettings(AppSettings settings) async {
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<List<CroniaTask>> getTasks() async {
    final raw = prefs.getString(_tasksKey);
    if (raw == null) return [];

    final list = jsonDecode(raw) as List<dynamic>;

    return list
        .map((e) => CroniaTask.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveTasks(List<CroniaTask> tasks) async {
    final raw = jsonEncode(tasks.map((e) => e.toJson()).toList());
    await prefs.setString(_tasksKey, raw);
  }

  Future<List<MealBlock>> getMealBlocks() async {
    final raw = prefs.getString(_mealsKey);
    if (raw == null) return [];

    final list = jsonDecode(raw) as List<dynamic>;

    return list
        .map((e) => MealBlock.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveMealBlocks(List<MealBlock> meals) async {
    final raw = jsonEncode(meals.map((e) => e.toJson()).toList());
    await prefs.setString(_mealsKey, raw);
  }

  Future<String> exportJson() async {
    final profile = await getProfile();
    final settings = await getSettings();
    final tasks = await getTasks();
    final meals = await getMealBlocks();

    final backup = {
      'app': 'Project-Cronia',
      'schemaVersion': '1.1',
      'exportedAt': DateTime.now().toIso8601String(),
      'userProfile': profile?.toJson(),
      'settings': settings.toJson(),
      'tasks': tasks.map((e) => e.toJson()).toList(),
      'mealBlocks': meals.map((e) => e.toJson()).toList(),
      'note': 'La API key de Gemini no se exporta por seguridad.',
    };

    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  Future<void> importJson(String raw, {bool replace = true}) async {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    if (decoded['app'] != 'Project-Cronia') {
      throw Exception('El archivo no pertenece a Project-Cronia.');
    }

    final tasksJson = decoded['tasks'] as List<dynamic>? ?? [];
    final mealsJson = decoded['mealBlocks'] as List<dynamic>? ?? [];

    final importedTasks = tasksJson
        .map((e) => CroniaTask.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final importedMeals = mealsJson
        .map((e) => MealBlock.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    if (replace) {
      await saveTasks(importedTasks);
      await saveMealBlocks(importedMeals);
    } else {
      final currentTasks = await getTasks();
      final mergedTasks = [
        ...currentTasks,
        ...importedTasks.where((newTask) {
          return !currentTasks.any((oldTask) => oldTask.id == newTask.id);
        }),
      ];

      await saveTasks(mergedTasks);
      await saveMealBlocks(importedMeals);
    }

    final profileJson = decoded['userProfile'];
    if (profileJson != null) {
      await saveProfile(
        UserProfile.fromJson(Map<String, dynamic>.from(profileJson)),
      );
    }

    final settingsJson = decoded['settings'];
    if (settingsJson != null) {
      await saveSettings(
        AppSettings.fromJson(Map<String, dynamic>.from(settingsJson)),
      );
    }
  }
}
