class SuggestedChange {
  final String id;
  final String description;
  final String reason;
  final bool isApplied;

  SuggestedChange({
    required this.id,
    required this.description,
    required this.reason,
    this.isApplied = false,
  });
}
