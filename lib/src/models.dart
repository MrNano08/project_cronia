import 'package:flutter/material.dart';

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
        return const Color(0xFF22C55E);
      case TaskPriority.medium:
        return const Color(0xFF3B82F6);
      case TaskPriority.high:
        return const Color(0xFFF97316);
      case TaskPriority.urgent:
        return const Color(0xFFEF4444);
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
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
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
      date: DateTime.parse(json['date'] as String),
      startAt: json['startAt'] == null
          ? null
          : DateTime.parse(json['startAt'] as String),
      endAt: json['endAt'] == null
          ? null
          : DateTime.parse(json['endAt'] as String),
      durationMinutes: json['durationMinutes'] as int? ?? 30,
      priority: taskPriorityFromString(json['priority'] as String?),
      status: taskStatusFromString(json['status'] as String?),
      isFlexible: json['isFlexible'] as bool? ?? true,
      canBeMoved: json['canBeMoved'] as bool? ?? true,
      deadline: json['deadline'] == null
          ? null
          : DateTime.parse(json['deadline'] as String),
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      reminders: remindersJson
          .map((e) => ReminderConfig.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
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
      date: DateTime.parse(json['date'] as String),
      startAt: json['startAt'] == null
          ? null
          : DateTime.parse(json['startAt'] as String),
      endAt: json['endAt'] == null
          ? null
          : DateTime.parse(json['endAt'] as String),
      durationMinutes: json['durationMinutes'] as int? ?? 30,
      priority: taskPriorityFromString(json['priority'] as String?),
      status: taskStatusFromString(json['status'] as String?),
      isFlexible: json['isFlexible'] as bool? ?? true,
      canBeMoved: json['canBeMoved'] as bool? ?? true,
      deadline: json['deadline'] == null
          ? null
          : DateTime.parse(json['deadline'] as String),
      reason: json['reason'] as String?,
    );
  }
}
