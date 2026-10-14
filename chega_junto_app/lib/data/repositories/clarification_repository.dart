import '../models/pre_visit_report.dart';
import '../models/report_clarification.dart';

abstract interface class ClarificationRepository {
  Future<PreVisitReport> next(String appointmentId);
  Future<PreVisitReport> answer(
    String appointmentId,
    String clarificationId,
    ClarificationAnswerKind kind,
    String? text,
    String expectedRevision,
  );
  Future<PreVisitReport> skip(String appointmentId);
}
