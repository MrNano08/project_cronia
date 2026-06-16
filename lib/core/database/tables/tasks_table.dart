class TasksTable {
  static const String tableName = 'tasks';

  static const String columnId = 'id';
  static const String columnTitle = 'title';
  static const String columnDescription = 'description';
  static const String columnPriority = 'priority';
  static const String columnStatus = 'status';

  static final schema = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $columnId TEXT PRIMARY KEY,
      $columnTitle TEXT,
      $columnDescription TEXT,
      $columnPriority TEXT,
      $columnStatus TEXT
    )
  ''';
}
