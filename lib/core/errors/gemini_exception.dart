class GeminiException implements Exception {
  final String message;
  final dynamic originalError;

  GeminiException({
    required this.message,
    this.originalError,
  });

  @override
  String toString() => message;
}
