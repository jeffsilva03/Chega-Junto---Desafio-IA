import 'organized_report.dart';
import 'report_clarification.dart';

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
    this.currentSourceHash,
    this.organizationSourceHash,
    this.clarifications = const [],
    this.clarificationsCurrent = false,
    this.clarificationsCompleted = false,
    this.clarificationsSourceText,
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
  final String? currentSourceHash,
      organizationSourceHash,
      clarificationsSourceText;
  final List<ReportClarification> clarifications;
  final bool clarificationsCurrent, clarificationsCompleted;

  PreVisitReport copyWith({
    bool? reviewed,
    bool? finalDone,
    bool? organizationCurrent,
    String? contentRevision,
    String? currentSourceHash,
    String? clarificationsSourceText,
    bool? clarificationsCurrent,
    bool? clarificationsCompleted,
    List<ReportClarification>? clarifications,
    List<ReportSection>? sections,
    List<ConsultationQuestion>? questions,
  }) => PreVisitReport(
    appointmentId: appointmentId,
    originalText: originalText,
    updatedAt: updatedAt,
    organizedSummary: organizedSummary,
    suggestedQuestions: suggestedQuestions,
    sections: sections ?? this.sections,
    questions: questions ?? this.questions,
    contentRevision: contentRevision ?? this.contentRevision,
    organizationCurrent: organizationCurrent ?? this.organizationCurrent,
    reviewed: reviewed ?? this.reviewed,
    finalDone: finalDone ?? this.finalDone,
    reviewedRevision: reviewedRevision,
    reviewedAt: reviewedAt,
    finalReviewRevision: finalReviewRevision,
    finalReviewAt: finalReviewAt,
    currentSourceHash: currentSourceHash ?? this.currentSourceHash,
    organizationSourceHash: organizationSourceHash,
    clarifications: clarifications ?? this.clarifications,
    clarificationsCurrent: clarificationsCurrent ?? this.clarificationsCurrent,
    clarificationsCompleted:
        clarificationsCompleted ?? this.clarificationsCompleted,
    clarificationsSourceText:
        clarificationsSourceText ?? this.clarificationsSourceText,
  );
}
