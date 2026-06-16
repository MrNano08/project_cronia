class MealBlocksTable {
  static const String tableName = 'meal_blocks';

  static const String columnId = 'id';
  static const String columnName = 'name';
  static const String columnTime = 'time';

  static final schema = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $columnId TEXT PRIMARY KEY,
      $columnName TEXT,
      $columnTime TEXT
    )
  ''';
}
