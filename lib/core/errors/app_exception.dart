class AppException implements Exception {
  final String message;
  final dynamic originalError;

  AppException({
    required this.message,
    this.originalError,
  });

  @override
  String toString() => message;
}
