import '../models/preparation_overview.dart';
import '../models/appointment.dart';
import '../models/appointment_reminder.dart';
import '../models/pre_visit_report.dart';

abstract interface class PreparationRepository {
  Future<PreVisitReport> setReportFinalReview(
    String appointmentId,
    String expectedRevision,
    bool completed,
  );
  Future<PreparationOverview> setFinalReview(
    String appointmentId,
    bool completed,
  );
  Future<PreparationOverview> saveReport(PreVisitReport report);
  Future<PreVisitReport?> loadReport(String appointmentId);
  Future<PreVisitReport> writeReport(
    PreVisitReport report, {
    String intent = 'edit',
    String? organizationSourceText,
  });
  Future<PreVisitReport> reviewReport(
    String appointmentId,
    String expectedRevision,
  );
  Future<PreVisitReport> clearReportSummary(
    String appointmentId,
    String expectedRevision,
  );
  Future<Appointment> loadAppointment(String id);
  Future<PreparationOverview> loadOverview();
  Future<List<Appointment>> loadAppointments();
  Future<List<AppointmentReminder>> loadReminders();
  Future<PreparationOverview> setChecklistItem(
    String appointmentId,
    String itemId,
    bool completed,
  );
  Future<AppointmentReminder> addReminder(AppointmentReminder reminder);
  Future<PreparationOverview> setAttendance(
    String appointmentId,
    ConfirmationStatus status,
  );
}
