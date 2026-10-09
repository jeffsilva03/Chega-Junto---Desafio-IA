import 'organized_report.dart';

class PreVisitReport {
  const PreVisitReport({
    required this.appointmentId,
    required this.originalText,
    required this.updatedAt,
    this.organizedSummary,
    this.suggestedQuestions = const [],
    this.sections = const [],
    this.questions = const [],
    this.contentRevision = '0',
    this.organizationCurrent = false,
    this.reviewed = false,
    this.finalDone = false,
    this.reviewedRevision,
    this.reviewedAt,
    this.finalReviewRevision,
    this.finalReviewAt,
  });
  final String appointmentId;
  final String originalText;
  final DateTime updatedAt;
  final String? organizedSummary;
  final List<String> suggestedQuestions;
  final List<ReportSection> sections;
  final List<ConsultationQuestion> questions;
  final String contentRevision;
  final bool organizationCurrent, reviewed, finalDone;
  final String? reviewedRevision, finalReviewRevision;
  final DateTime? reviewedAt, finalReviewAt;

  PreVisitReport copyWith({bool? reviewed, bool? finalDone}) => PreVisitReport(
    appointmentId: appointmentId,
    originalText: originalText,
    updatedAt: updatedAt,
    organizedSummary: organizedSummary,
    suggestedQuestions: suggestedQuestions,
    sections: sections,
    questions: questions,
    contentRevision: contentRevision,
    organizationCurrent: organizationCurrent,
    reviewed: reviewed ?? this.reviewed,
    finalDone: finalDone ?? this.finalDone,
    reviewedRevision: reviewedRevision,
    reviewedAt: reviewedAt,
    finalReviewRevision: finalReviewRevision,
    finalReviewAt: finalReviewAt,
  );
}
