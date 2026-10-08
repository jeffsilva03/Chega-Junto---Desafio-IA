import '../models/preparation_overview.dart';
import '../models/appointment.dart';
import '../models/appointment_reminder.dart';
import '../models/pre_visit_report.dart';

abstract interface class PreparationRepository {
  Future<PreparationOverview> saveReport(PreVisitReport report);
  Future<PreparationOverview> loadOverview();
  Future<List<Appointment>> loadAppointments();
  Future<List<AppointmentReminder>> loadReminders();
  Future<PreparationOverview> setChecklistItem(
    String appointmentId,
    String itemId,
    bool completed,
  );
  Future<void> addReminder(AppointmentReminder reminder);
  Future<PreparationOverview> setAttendance(
    String appointmentId,
    ConfirmationStatus status,
  );
}
