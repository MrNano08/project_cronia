class UserProfileTable {
  static const String tableName = 'user_profiles';

  static const String columnId = 'id';
  static const String columnName = 'name';
  static const String columnEmail = 'email';

  static final schema = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $columnId TEXT PRIMARY KEY,
      $columnName TEXT,
      $columnEmail TEXT
    )
  ''';
}
