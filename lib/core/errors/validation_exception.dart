class ValidationException implements Exception {
  final String message;
  final List<String> errors;

  ValidationException({
    required this.message,
    this.errors = const [],
  });

  @override
  String toString() => message;
}
