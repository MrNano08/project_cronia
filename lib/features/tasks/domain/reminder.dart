class Reminder {
  final String id;
  final String taskId;
  final DateTime reminderTime;
  final bool isNotified;

  Reminder({
    required this.id,
    required this.taskId,
    required this.reminderTime,
    this.isNotified = false,
  });
}
