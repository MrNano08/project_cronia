import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
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
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  Future<void> scheduleForTask(CroniaTask task) async {
    if (task.status == TaskStatus.cancelled ||
        task.status == TaskStatus.completed) {
      return;
    }

    for (int i = 0; i < task.reminders.length; i++) {
      final reminder = task.reminders[i];

      if (!reminder.enabled) continue;
      if (reminder.scheduledAt.isBefore(DateTime.now())) continue;

      await _schedule(
        id: _notificationId(task.id, i),
        title: _titleForReminder(task, reminder),
        body: _bodyForReminder(task, reminder),
        scheduledAt: reminder.scheduledAt,
      );
    }
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
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

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledAt, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  int _notificationId(String taskId, int index) {
    return (taskId.hashCode + index).abs() % 2147483647;
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
