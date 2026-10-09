import 'appointment.dart';
import 'checklist_item.dart';
import 'pre_visit_report.dart';

class PreparationOverview {
  const PreparationOverview({
    required this.firstName,
    required Appointment? nextAppointment,
    required this.progress,
    required this.checklist,
    required this.report,
    required this.reminder,
    required this.referenceDate,
    this.checklistFraction,
  }) : _nextAppointment = nextAppointment;
  final String firstName;
  final Appointment? _nextAppointment;
  bool get hasNextAppointment => _nextAppointment != null;
  Appointment get nextAppointment => _nextAppointment!;
  final double? checklistFraction;
  final PreparationProgress progress;
  final List<ChecklistItem> checklist;
  final PreVisitReport report;
  final String reminder;
  final DateTime referenceDate;

  PreparationOverview withFinalReview(bool completed) => PreparationOverview(
    firstName: firstName,
    nextAppointment: _nextAppointment,
    progress: PreparationProgress({
      ...progress.completed.where(
        (stage) => stage != PreparationStage.finalReview,
      ),
      if (completed) PreparationStage.finalReview,
    }),
    checklist: checklist,
    report: report.copyWith(finalDone: completed),
    reminder: reminder,
    referenceDate: referenceDate,
    checklistFraction: checklistFraction,
  );

  PreparationOverview withReport(PreVisitReport value) => PreparationOverview(
    firstName: firstName,
    nextAppointment: _nextAppointment,
    progress: progress,
    checklist: checklist,
    report: value,
    reminder: reminder,
    referenceDate: referenceDate,
    checklistFraction: checklistFraction,
  );

  PreparationOverview withAttendance(ConfirmationStatus status) {
    final stages = {...progress.completed};
    if (status == ConfirmationStatus.confirmed) {
      stages.add(PreparationStage.attendance);
    } else {
      stages.remove(PreparationStage.attendance);
    }
    return PreparationOverview(
      firstName: firstName,
      nextAppointment: nextAppointment.withConfirmation(status),
      progress: PreparationProgress(stages),
      checklist: checklist,
      report: report,
      reminder: reminder,
      referenceDate: referenceDate,
    );
  }

  PreparationOverview withChecklist(List<ChecklistItem> items) {
    final stages = {...progress.completed};
    if (requiredChecklistProgress(items) == 1) {
      stages.add(PreparationStage.documents);
    } else {
      stages.remove(PreparationStage.documents);
    }
    return PreparationOverview(
      firstName: firstName,
      nextAppointment: nextAppointment,
      progress: PreparationProgress(stages),
      checklist: List.unmodifiable(items),
      report: report,
      reminder: reminder,
      referenceDate: referenceDate,
    );
  }
}
