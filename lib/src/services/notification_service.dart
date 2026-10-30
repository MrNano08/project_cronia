import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models.dart';
import '../recurrence.dart';

class NotificationService with WidgetsBindingObserver {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<void> Function()? onResume;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    tz_data.initializeTimeZones();

    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('America/Costa_Rica'));
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshOnResume();
  }

  Future<void> _refreshOnResume() async {
    try {
      await onResume?.call();
    } catch (_) {
      // Keep lifecycle restoration from interrupting the visible application.
    }
  }

  Future<void> scheduleForTask(
    CroniaTask task, {
    required AppSettings settings,
  }) async {
    await cancelForTask(task.id);

    if (task.status == TaskStatus.cancelled ||
        task.status == TaskStatus.completed) {
      return;
    }

    final pending = await _plugin.pendingNotificationRequests();
    var scheduledCount = pending.length;
    if (task.recurrence != null && task.startAt != null) {
      final now = settings.userNow();
      final occurrences = RecurrenceEngine.between(task.recurrence!, now, now.add(const Duration(days: 30)), limit: 30).toList();
      for (final entry in task.recurrence!.occurrenceOverrides.entries) {
        final movedDate = entry.value['date'] == null ? null : DateTime.tryParse(entry.value['date'] as String);
        final identityDate = DateTime.tryParse(entry.key);
        if (movedDate != null && identityDate != null && !movedDate.isBefore(now) && !movedDate.isAfter(now.add(const Duration(days: 30))) && !occurrences.any((d) => RecurrenceEngine.key(d) == entry.key)) {
          occurrences.add(identityDate);
        }
      }
      occurrences.sort();
      for (final day in occurrences) {
        final key = RecurrenceEngine.key(day);
        final override = task.recurrence!.occurrenceOverrides[key];
        final actualDate = override?['date'] == null ? day : DateTime.tryParse(override!['date'] as String) ?? day;
        final overrideStart = override?['startAt'] == null ? null : DateTime.tryParse(override!['startAt'] as String);
        final occurrenceStart = overrideStart ?? DateTime(actualDate.year, actualDate.month, actualDate.day, task.startAt!.hour, task.startAt!.minute);
        final storedReminders = override?['reminders'] as List?;
        final reminders = storedReminders == null ? task.reminders : storedReminders.map((raw) => ReminderConfig.fromJson(Map<String, dynamic>.from(raw as Map))).toList();
        final duration = (override?['durationMinutes'] as num?)?.toInt() ?? task.durationMinutes;
        if (occurrenceStart.isAfter(now.add(const Duration(days: 30)))) continue;
        for (var i = 0; i < reminders.length && scheduledCount < 450; i++) {
          final reminder = reminders[i];
          if (!reminder.enabled) continue;
          final scheduledAt = _scheduledForOccurrence(task, reminder, occurrenceStart, duration);
          if (scheduledAt.isBefore(now)) continue;
          await _schedule(id: _notificationId('${task.id}@$key', i), title: _titleForReminder(task, reminder), body: _bodyForReminder(task, reminder), scheduledAt: scheduledAt, timeZoneId: settings.timeZoneId, payload: 'cronia:${task.id}:$key');
          scheduledCount++;
        }
      }
      return;
    }

    for (int i = 0; i < task.reminders.length && scheduledCount < 450; i++) {
      final reminder = task.reminders[i];

      if (!reminder.enabled) continue;
      if (reminder.scheduledAt.isBefore(settings.userNow())) continue;

      await _schedule(
        id: _notificationId(task.id, i),
        title: _titleForReminder(task, reminder),
        body: _bodyForReminder(task, reminder),
        scheduledAt: reminder.scheduledAt,
        timeZoneId: settings.timeZoneId,
        payload: 'cronia:${task.id}:single',
      );
      scheduledCount++;
    }
  }

  Future<void> cancelForTask(String taskId) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.payload?.startsWith('cronia:$taskId:') ?? false) {
        await _plugin.cancel(request.id);
      }
    }
    for (int i = 0; i < 12; i++) {
      await _plugin.cancel(_notificationId(taskId, i));
    }
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required String timeZoneId,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'cronia_tasks',
      'Recordatorios de tareas',
      channelDescription: 'Notificaciones de Project-Cronia',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final location = _safeLocation(timeZoneId);
    final scheduled = tz.TZDateTime(
      location,
      scheduledAt.year,
      scheduledAt.month,
      scheduledAt.day,
      scheduledAt.hour,
      scheduledAt.minute,
      scheduledAt.second,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  tz.Location _safeLocation(String timeZoneId) {
    try {
      return tz.getLocation(timeZoneId);
    } catch (_) {
      return tz.getLocation('America/Costa_Rica');
    }
  }

  int _notificationId(String taskId, int index) {
    // Stable FNV-1a; Dart String.hashCode is intentionally process-randomized.
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode('$taskId#$index')) {
      hash = ((hash ^ byte) * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  DateTime _scheduledForOccurrence(CroniaTask task, ReminderConfig reminder, DateTime start, int duration) {
    switch (reminder.type) {
      case ReminderType.daysBefore:
        final days = reminder.daysBefore ?? 0;
        return DateTime(start.year, start.month, start.day - days, start.hour, start.minute);
      case ReminderType.hoursBefore:
        return start.subtract(Duration(hours: reminder.hoursBefore ?? 0));
      case ReminderType.minutesBefore:
      case ReminderType.beforeStart:
        return start.subtract(Duration(minutes: reminder.minutesBefore ?? 15));
      case ReminderType.atStart:
        return start;
      case ReminderType.atEnd:
        return start.add(Duration(minutes: duration));
      case ReminderType.followUpAfterEnd:
        final oldEnd = task.endAt ?? task.startAt!.add(Duration(minutes: task.durationMinutes));
        return start.add(Duration(minutes: duration)).add(reminder.scheduledAt.difference(oldEnd));
    }
  }

  String _titleForReminder(CroniaTask task, ReminderConfig reminder) {
    switch (reminder.type) {
      case ReminderType.daysBefore:
        return 'Faltan ${reminder.daysBefore ?? ''} días';
      case ReminderType.hoursBefore:
        return 'Recordatorio de actividad';
      case ReminderType.minutesBefore:
      case ReminderType.beforeStart:
        return 'Actividad próxima';
      case ReminderType.atStart:
        return 'Ya deberías empezar';
      case ReminderType.atEnd:
      case ReminderType.followUpAfterEnd:
        return '¿Terminaste la actividad?';
    }
  }

  String _bodyForReminder(CroniaTask task, ReminderConfig reminder) {
    switch (reminder.type) {
      case ReminderType.daysBefore:
        return 'Se acerca: ${task.title}.';
      case ReminderType.hoursBefore:
        return 'Recuerda preparar: ${task.title}.';
      case ReminderType.minutesBefore:
      case ReminderType.beforeStart:
        return 'En poco tiempo inicia: ${task.title}.';
      case ReminderType.atStart:
        return 'Empieza ahora: ${task.title}.';
      case ReminderType.atEnd:
      case ReminderType.followUpAfterEnd:
        return 'La actividad "${task.title}" debería haber terminado.';
    }
  }
}
