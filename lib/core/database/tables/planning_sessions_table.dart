class PlanningSessionsTable {
  static const String tableName = 'planning_sessions';

  static const String columnId = 'id';
  static const String columnStartTime = 'start_time';
  static const String columnEndTime = 'end_time';
  static const String columnNotes = 'notes';

  static final schema = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $columnId TEXT PRIMARY KEY,
      $columnStartTime TEXT,
      $columnEndTime TEXT,
      $columnNotes TEXT
    )
  ''';
}
