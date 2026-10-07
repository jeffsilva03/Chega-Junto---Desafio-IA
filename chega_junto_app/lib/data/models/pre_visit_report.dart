class PreVisitReport {
  const PreVisitReport({
    required this.appointmentId,
    required this.originalText,
    required this.updatedAt,
    this.organizedSummary,
    this.suggestedQuestions = const [],
  });
  final String appointmentId;
  final String originalText;
  final DateTime updatedAt;
  final String? organizedSummary;
  final List<String> suggestedQuestions;
}
