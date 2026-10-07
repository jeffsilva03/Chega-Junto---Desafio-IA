import 'package:flutter/foundation.dart';
import '../../data/models/appointment.dart';
import '../../data/models/appointment_reminder.dart';
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

  Future<void> load() async {
    loading = true;
    failed = false;
    notifyListeners();
    try {
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
