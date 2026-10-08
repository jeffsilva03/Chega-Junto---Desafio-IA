import 'package:flutter/foundation.dart';
import '../../data/models/appointment.dart';
import '../../data/models/appointment_reminder.dart';
import '../../data/models/checklist_item.dart';
import '../../data/models/organized_report.dart';
import '../../data/models/pre_visit_report.dart';
import '../../data/models/preparation_overview.dart';
import '../../data/repositories/preparation_repository.dart';

class PreparationController extends ChangeNotifier {
  PreparationController(this.repository);
  final PreparationRepository repository;
  PreparationOverview? overview;
  List<Appointment> appointments = const [];
  List<AppointmentReminder> reminders = const [];
  bool loading = true;
  bool failed = false;
  bool saving = false;
  bool _disposed = false;
  Future<void> _pendingFinalReview = Future<void>.value();
  bool _finalReviewInvalidated = false;

  bool get finalReviewCompleted =>
      overview?.progress.completed.contains(PreparationStage.finalReview) ??
      false;

  void invalidateFinalReview() {
    if (!finalReviewCompleted) return;
    final appointmentId = overview!.nextAppointment.id;
    _finalReviewInvalidated = true;
    overview = overview!.withFinalReview(false);
    notifyListeners();
    // Keep local invalidation immediate; serialize it before another conclusion.
    _pendingFinalReview = _pendingFinalReview.then((_) async {
      try {
        await repository.setFinalReview(appointmentId, false);
      } catch (_) {
        // The session stays pending even if a future repository cannot persist.
        // A deliberate new conclusion will retry saving its current state.
      }
    });
  }

  Future<void> completeFinalReview() async {
    await _pendingFinalReview;
    if (_disposed || overview == null) {
      throw StateError('Preparo indisponível.');
    }
    final updated = await repository.setFinalReview(
      overview!.nextAppointment.id,
      true,
    );
    if (_disposed) return;
    _finalReviewInvalidated = false;
    overview = updated;
    notifyListeners();
  }

  Future<void> saveReportReview(
    String text,
    List<ReportSection> sections,
    List<ConsultationQuestion> questions,
  ) async {
    await _pendingFinalReview;
    if (overview == null) throw StateError('Preparo indisponível.');
    final updated = await repository.saveReport(
      PreVisitReport(
        appointmentId: overview!.nextAppointment.id,
        originalText: text,
        updatedAt: DateTime.now(),
        organizedSummary: sections
            .where((s) => s.text.trim().isNotEmpty)
            .map((s) => '${s.title}\n${s.text}')
            .join('\n\n'),
        suggestedQuestions: questions
            .where((q) => q.selected)
            .map((q) => q.text)
            .toList(),
      ),
    );
    if (_disposed) return;
    overview = _finalReviewInvalidated
        ? updated.withFinalReview(false)
        : updated;
    notifyListeners();
  }

  Future<void> load() async {
    loading = true;
    failed = false;
    notifyListeners();
    try {
      await _pendingFinalReview;
      final overviewFuture = repository.loadOverview();
      final appointmentsFuture = repository.loadAppointments();
      final remindersFuture = repository.loadReminders();
      final results = await Future.wait<Object>([
        overviewFuture,
        appointmentsFuture,
        remindersFuture,
      ]);
      if (_disposed) return;
      overview = results[0] as PreparationOverview;
      if (_finalReviewInvalidated) overview = overview!.withFinalReview(false);
      appointments = results[1] as List<Appointment>;
      reminders = results[2] as List<AppointmentReminder>;
    } catch (_) {
      if (_disposed) return;
      failed = true;
    }
    loading = false;
    notifyListeners();
  }

  Appointment? appointmentById(String id) {
    for (final appointment in appointments) {
      if (appointment.id == id) return appointment;
    }
    return null;
  }

  Future<void> setChecklistItem(String itemId, bool completed) async {
    if (saving || overview == null) return;
    saving = true;
    notifyListeners();
    try {
      final updated = await repository.setChecklistItem(
        overview!.nextAppointment.id,
        itemId,
        completed,
      );
      if (!_disposed) overview = updated;
    } finally {
      if (!_disposed) {
        saving = false;
        notifyListeners();
      }
    }
  }

  Future<void> addReminder(AppointmentReminder reminder) async {
    await repository.addReminder(reminder);
    final updated = await repository.loadReminders();
    if (_disposed) return;
    reminders = updated;
    notifyListeners();
  }

  Future<void> setAttendance(ConfirmationStatus status) async {
    if (saving || overview == null) return;
    saving = true;
    notifyListeners();
    try {
      final updated = await repository.setAttendance(
        overview!.nextAppointment.id,
        status,
      );
      if (_disposed) return;
      overview = updated;
      appointments = List.unmodifiable([
        for (final appointment in appointments)
          if (appointment.id == updated.nextAppointment.id)
            updated.nextAppointment
          else
            appointment,
      ]);
    } finally {
      if (!_disposed) {
        saving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
