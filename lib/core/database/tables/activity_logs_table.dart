class ActivityLogsTable {
  static const String tableName = 'activity_logs';

  static const String columnId = 'id';
  static const String columnActivityName = 'activity_name';
  static const String columnStartTime = 'start_time';
  static const String columnEndTime = 'end_time';

  static final schema = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $columnId TEXT PRIMARY KEY,
      $columnActivityName TEXT,
      $columnStartTime TEXT,
      $columnEndTime TEXT
    )
  ''';
}
