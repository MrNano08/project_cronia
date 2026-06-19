import 'package:flutter/material.dart';

import 'theme/cronia_theme.dart';

enum TaskPriority { low, medium, high, urgent }

enum TaskStatus { pending, inProgress, completed, postponed, cancelled }

enum ReminderType {
  daysBefore,
  hoursBefore,
  minutesBefore,
  beforeStart,
  atStart,
  atEnd,
  followUpAfterEnd,
}

DateTime parseCroniaDateTime(String value) {
  final trimmed = value.trim();
  final timezoneSuffix = RegExp(r'(Z|[+-]\d{2}:\d{2})$');
  final normalized = trimmed.replaceFirst(timezoneSuffix, '');
  return DateTime.parse(normalized);
}

String dateTimeForGemini(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');

  return '${value.year.toString().padLeft(4, '0')}-'
      '${two(value.month)}-'
      '${two(value.day)}T'
      '${two(value.hour)}:'
      '${two(value.minute)}:'
      '${two(value.second)}';
}

TaskPriority taskPriorityFromString(String? value) {
  return TaskPriority.values.firstWhere(
    (e) => e.name == value,
    orElse: () => TaskPriority.medium,
  );
}

TaskStatus taskStatusFromString(String? value) {
  return TaskStatus.values.firstWhere(
    (e) => e.name == value,
    orElse: () => TaskStatus.pending,
  );
}

ReminderType reminderTypeFromString(String? value) {
  return ReminderType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => ReminderType.beforeStart,
  );
}

extension TaskPriorityUi on TaskPriority {
  Color get color {
    switch (this) {
      case TaskPriority.low:
        return CroniaColors.success;
      case TaskPriority.medium:
        return CroniaColors.secondary;
      case TaskPriority.high:
        return CroniaColors.warning;
      case TaskPriority.urgent:
        return CroniaColors.danger;
    }
  }

  String get label {
    switch (this) {
      case TaskPriority.low:
        return 'Baja';
      case TaskPriority.medium:
        return 'Media';
      case TaskPriority.high:
        return 'Alta';
      case TaskPriority.urgent:
        return 'Urgente';
    }
  }
}

extension TaskStatusUi on TaskStatus {
  String get label {
    switch (this) {
      case TaskStatus.pending:
        return 'Pendiente';
      case TaskStatus.inProgress:
        return 'En progreso';
      case TaskStatus.completed:
        return 'Completada';
      case TaskStatus.postponed:
        return 'Aplazada';
      case TaskStatus.cancelled:
        return 'Cancelada';
    }
  }
}

class TimeZoneOption {
  final String label;
  final String country;
  final String state;
  final String timeZoneId;
  final int utcOffsetMinutes;

  const TimeZoneOption({
    required this.label,
    required this.country,
    required this.state,
    required this.timeZoneId,
    required this.utcOffsetMinutes,
  });
}

const List<TimeZoneOption> croniaTimeZones = [
  TimeZoneOption(
    label: 'Costa Rica - UTC-06',
    country: 'Costa Rica',
    state: '',
    timeZoneId: 'America/Costa_Rica',
    utcOffsetMinutes: -360,
  ),
  TimeZoneOption(
    label: 'México, Ciudad de México - UTC-06',
    country: 'México',
    state: 'Ciudad de México',
    timeZoneId: 'America/Mexico_City',
    utcOffsetMinutes: -360,
  ),
  TimeZoneOption(
    label: 'Colombia - UTC-05',
    country: 'Colombia',
    state: '',
    timeZoneId: 'America/Bogota',
    utcOffsetMinutes: -300,
  ),
  TimeZoneOption(
    label: 'Panamá - UTC-05',
    country: 'Panamá',
    state: '',
    timeZoneId: 'America/Panama',
    utcOffsetMinutes: -300,
  ),
  TimeZoneOption(
    label: 'EE. UU. Eastern - UTC-05',
    country: 'Estados Unidos',
    state: 'Eastern',
    timeZoneId: 'America/New_York',
    utcOffsetMinutes: -300,
  ),
  TimeZoneOption(
    label: 'EE. UU. Central - UTC-06',
    country: 'Estados Unidos',
    state: 'Central',
    timeZoneId: 'America/Chicago',
    utcOffsetMinutes: -360,
  ),
  TimeZoneOption(
    label: 'EE. UU. Mountain - UTC-07',
    country: 'Estados Unidos',
    state: 'Mountain',
    timeZoneId: 'America/Denver',
    utcOffsetMinutes: -420,
  ),
  TimeZoneOption(
    label: 'EE. UU. Pacific - UTC-08',
    country: 'Estados Unidos',
    state: 'Pacific',
    timeZoneId: 'America/Los_Angeles',
    utcOffsetMinutes: -480,
  ),
];

class UserProfile {
  final String id;
  final String name;
  final String? photoPath;
  final bool onboardingCompleted;

  const UserProfile({
    required this.id,
    required this.name,
    this.photoPath,
    required this.onboardingCompleted,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'photoPath': photoPath,
      'onboardingCompleted': onboardingCompleted,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      photoPath: json['photoPath'] as String?,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
    );
  }
}

class AppSettings {
  final String country;
  final String state;
  final String timeZoneId;
  final int utcOffsetMinutes;
  final String wakeUpTime;
  final String sleepTime;

  const AppSettings({
    required this.country,
    required this.state,
    required this.timeZoneId,
    required this.utcOffsetMinutes,
    required this.wakeUpTime,
    required this.sleepTime,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      country: 'Costa Rica',
      state: '',
      timeZoneId: 'America/Costa_Rica',
      utcOffsetMinutes: -360,
      wakeUpTime: '07:00',
      sleepTime: '23:00',
    );
  }

  DateTime userNow() {
    final shifted = DateTime.now().toUtc().add(
          Duration(minutes: utcOffsetMinutes),
        );

    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
      shifted.millisecond,
      shifted.microsecond,
    );
  }

  String get utcOffsetLabel {
    final sign = utcOffsetMinutes >= 0 ? '+' : '-';
    final absMinutes = utcOffsetMinutes.abs();
    final hours = (absMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (absMinutes % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hours:$minutes';
  }

  AppSettings copyWith({
    String? country,
    String? state,
    String? timeZoneId,
    int? utcOffsetMinutes,
    String? wakeUpTime,
    String? sleepTime,
  }) {
    return AppSettings(
      country: country ?? this.country,
      state: state ?? this.state,
      timeZoneId: timeZoneId ?? this.timeZoneId,
      utcOffsetMinutes: utcOffsetMinutes ?? this.utcOffsetMinutes,
      wakeUpTime: wakeUpTime ?? this.wakeUpTime,
      sleepTime: sleepTime ?? this.sleepTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'country': country,
      'state': state,
      'timeZoneId': timeZoneId,
      'utcOffsetMinutes': utcOffsetMinutes,
      'wakeUpTime': wakeUpTime,
      'sleepTime': sleepTime,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      country: json['country'] as String? ?? 'Costa Rica',
      state: json['state'] as String? ?? '',
      timeZoneId: json['timeZoneId'] as String? ?? 'America/Costa_Rica',
      utcOffsetMinutes: json['utcOffsetMinutes'] as int? ?? -360,
      wakeUpTime: json['wakeUpTime'] as String? ?? '07:00',
      sleepTime: json['sleepTime'] as String? ?? '23:00',
    );
  }
}

class ReminderConfig {
  final String id;
  final String taskId;
  final ReminderType type;
  final DateTime scheduledAt;
  final int? daysBefore;
  final int? hoursBefore;
  final int? minutesBefore;
  final bool enabled;
  final bool triggered;

  const ReminderConfig({
    required this.id,
    required this.taskId,
    required this.type,
    required this.scheduledAt,
    this.daysBefore,
    this.hoursBefore,
    this.minutesBefore,
    this.enabled = true,
    this.triggered = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'type': type.name,
      'scheduledAt': scheduledAt.toIso8601String(),
      'daysBefore': daysBefore,
      'hoursBefore': hoursBefore,
      'minutesBefore': minutesBefore,
      'enabled': enabled,
      'triggered': triggered,
    };
  }

  factory ReminderConfig.fromJson(Map<String, dynamic> json) {
    return ReminderConfig(
      id: json['id'] as String,
      taskId: json['taskId'] as String,
      type: reminderTypeFromString(json['type'] as String?),
      scheduledAt: parseCroniaDateTime(json['scheduledAt'] as String),
      daysBefore: json['daysBefore'] as int?,
      hoursBefore: json['hoursBefore'] as int?,
      minutesBefore: json['minutesBefore'] as int?,
      enabled: json['enabled'] as bool? ?? true,
      triggered: json['triggered'] as bool? ?? false,
    );
  }
}

class CroniaTask {
  final String id;
  final String title;
  final String? description;
  final DateTime date;
  final DateTime? startAt;
  final DateTime? endAt;
  final int durationMinutes;
  final TaskPriority priority;
  final TaskStatus status;
  final bool isFlexible;
  final bool canBeMoved;
  final DateTime? deadline;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<ReminderConfig> reminders;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CroniaTask({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    this.startAt,
    this.endAt,
    required this.durationMinutes,
    required this.priority,
    required this.status,
    this.isFlexible = true,
    this.canBeMoved = true,
    this.deadline,
    this.startedAt,
    this.completedAt,
    this.reminders = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  CroniaTask copyWith({
    String? title,
    String? description,
    DateTime? date,
    DateTime? startAt,
    DateTime? endAt,
    int? durationMinutes,
    TaskPriority? priority,
    TaskStatus? status,
    bool? isFlexible,
    bool? canBeMoved,
    DateTime? deadline,
    DateTime? startedAt,
    DateTime? completedAt,
    List<ReminderConfig>? reminders,
    DateTime? updatedAt,
  }) {
    return CroniaTask(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      isFlexible: isFlexible ?? this.isFlexible,
      canBeMoved: canBeMoved ?? this.canBeMoved,
      deadline: deadline ?? this.deadline,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      reminders: reminders ?? this.reminders,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'startAt': startAt?.toIso8601String(),
      'endAt': endAt?.toIso8601String(),
      'durationMinutes': durationMinutes,
      'priority': priority.name,
      'status': status.name,
      'isFlexible': isFlexible,
      'canBeMoved': canBeMoved,
      'deadline': deadline?.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'reminders': reminders.map((r) => r.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CroniaTask.fromJson(Map<String, dynamic> json) {
    final remindersJson = json['reminders'] as List<dynamic>? ?? [];

    return CroniaTask(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      date: parseCroniaDateTime(json['date'] as String),
      startAt: json['startAt'] == null
          ? null
          : parseCroniaDateTime(json['startAt'] as String),
      endAt: json['endAt'] == null
          ? null
          : parseCroniaDateTime(json['endAt'] as String),
      durationMinutes: json['durationMinutes'] as int? ?? 30,
      priority: taskPriorityFromString(json['priority'] as String?),
      status: taskStatusFromString(json['status'] as String?),
      isFlexible: json['isFlexible'] as bool? ?? true,
      canBeMoved: json['canBeMoved'] as bool? ?? true,
      deadline: json['deadline'] == null
          ? null
          : parseCroniaDateTime(json['deadline'] as String),
      startedAt: json['startedAt'] == null
          ? null
          : parseCroniaDateTime(json['startedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : parseCroniaDateTime(json['completedAt'] as String),
      reminders: remindersJson
          .map((e) => ReminderConfig.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: parseCroniaDateTime(json['createdAt'] as String),
      updatedAt: parseCroniaDateTime(json['updatedAt'] as String),
    );
  }
}

class MealBlock {
  final String id;
  final String name;
  final String time;
  final int durationMinutes;
  final bool needsCooking;
  final int? cookingDurationMinutes;
  final bool enabled;

  const MealBlock({
    required this.id,
    required this.name,
    required this.time,
    required this.durationMinutes,
    required this.needsCooking,
    this.cookingDurationMinutes,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'time': time,
      'durationMinutes': durationMinutes,
      'needsCooking': needsCooking,
      'cookingDurationMinutes': cookingDurationMinutes,
      'enabled': enabled,
    };
  }

  factory MealBlock.fromJson(Map<String, dynamic> json) {
    return MealBlock(
      id: json['id'] as String,
      name: json['name'] as String,
      time: json['time'] as String,
      durationMinutes: json['durationMinutes'] as int? ?? 45,
      needsCooking: json['needsCooking'] as bool? ?? false,
      cookingDurationMinutes: json['cookingDurationMinutes'] as int?,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

class PlanningResult {
  final String version;
  final String summary;
  final bool requiresUserConfirmation;
  final List<PlannedTask> tasks;
  final List<String> warnings;

  const PlanningResult({
    required this.version,
    required this.summary,
    required this.requiresUserConfirmation,
    required this.tasks,
    required this.warnings,
  });

  factory PlanningResult.fromJson(Map<String, dynamic> json) {
    final taskList = json['tasks'] as List<dynamic>? ?? [];
    final warningList = json['warnings'] as List<dynamic>? ?? [];

    return PlanningResult(
      version: json['version'] as String? ?? '1.0',
      summary: json['summary'] as String? ?? 'Plan generado.',
      requiresUserConfirmation:
          json['requiresUserConfirmation'] as bool? ?? true,
      tasks: taskList
          .map((e) => PlannedTask.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      warnings: warningList.map((e) => e.toString()).toList(),
    );
  }
}

class PlannedTask {
  final String action;
  final String? existingTaskId;
  final String title;
  final String? description;
  final DateTime date;
  final DateTime? startAt;
  final DateTime? endAt;
  final int durationMinutes;
  final TaskPriority priority;
  final TaskStatus status;
  final bool isFlexible;
  final bool canBeMoved;
  final DateTime? deadline;
  final String? reason;

  const PlannedTask({
    required this.action,
    this.existingTaskId,
    required this.title,
    this.description,
    required this.date,
    this.startAt,
    this.endAt,
    required this.durationMinutes,
    required this.priority,
    required this.status,
    required this.isFlexible,
    required this.canBeMoved,
    this.deadline,
    this.reason,
  });

  factory PlannedTask.fromJson(Map<String, dynamic> json) {
    return PlannedTask(
      action: json['action'] as String? ?? 'create',
      existingTaskId: json['existingTaskId'] as String?,
      title: json['title'] as String? ?? 'Actividad sin título',
      description: json['description'] as String?,
      date: parseCroniaDateTime(json['date'] as String),
      startAt: json['startAt'] == null
          ? null
          : parseCroniaDateTime(json['startAt'] as String),
      endAt: json['endAt'] == null
          ? null
          : parseCroniaDateTime(json['endAt'] as String),
      durationMinutes: json['durationMinutes'] as int? ?? 30,
      priority: taskPriorityFromString(json['priority'] as String?),
      status: taskStatusFromString(json['status'] as String?),
      isFlexible: json['isFlexible'] as bool? ?? true,
      canBeMoved: json['canBeMoved'] as bool? ?? true,
      deadline: json['deadline'] == null
          ? null
          : parseCroniaDateTime(json['deadline'] as String),
      reason: json['reason'] as String?,
    );
  }
}
