class RemindersTable {
  static const String tableName = 'reminders';

  static const String columnId = 'id';
  static const String columnTaskId = 'task_id';
  static const String columnDateTime = 'date_time';

  static final schema = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $columnId TEXT PRIMARY KEY,
      $columnTaskId TEXT,
      $columnDateTime TEXT
    )
  ''';
}
