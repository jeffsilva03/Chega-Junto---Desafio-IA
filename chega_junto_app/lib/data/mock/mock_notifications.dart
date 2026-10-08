import '../../core/utils/appointment_date.dart';
import '../models/app_notification.dart';
import '../models/preparation_overview.dart';
import '../models/appointment.dart';
import '../models/appointment_reminder.dart';
import '../models/profile_preferences.dart';

bool notificationVisible(
  AppNotification notification,
  NotificationPreferences preferences,
) {
  if (!preferences.enabled(NotificationOption.active) ||
      !preferences.enabled(NotificationOption.inApp)) {
    return false;
  }
  final option = switch (notification.category) {
    NotificationCategory.consultation => NotificationOption.confirmations,
    NotificationCategory.exam => NotificationOption.exams,
    NotificationCategory.system =>
      notification.id == 'notification-documents'
          ? NotificationOption.documents
          : NotificationOption.system,
    NotificationCategory.reminder =>
      notification.id == 'notification-medications'
          ? NotificationOption.medications
          : NotificationOption.appointments,
  };
  return preferences.enabled(option);
}

List<AppNotification> demoNotifications(
  PreparationOverview overview,
  List<Appointment> appointments,
  List<AppointmentReminder> reminders,
) {
  final today = overview.referenceDate;
  final next = overview.nextAppointment;
  final exams = appointments.where((a) => a.type == AppointmentType.exam);
  final exam = exams.isEmpty ? next : exams.first;
  DateTime at(int offset, int hour, int minute) =>
      DateTime(today.year, today.month, today.day + offset, hour, minute);
  return [
    for (final reminder in reminders.where((r) => r.appointmentId != null))
      AppNotification(
        id: reminder.id,
        title: 'Lembrete salvo',
        message:
            '${reminder.title}. ${AppointmentDate.shortDate(reminder.dateTime)}, às ${AppointmentDate.time(reminder.dateTime)}.',
        dateTime: at(0, 9, 0),
        category: NotificationCategory.reminder,
        destination: NotificationDestination.appointment,
        destinationId: reminder.appointmentId,
      ),
    AppNotification(
      id: 'notification-consultation',
      title: 'Lembrete de consulta',
      message:
          'Sua consulta de ${next.specialty} é em ${AppointmentDate.shortDate(next.dateTime)}, às ${AppointmentDate.time(next.dateTime)}, na ${next.facilityName}.',
      dateTime: at(0, 7, 0),
      category: NotificationCategory.reminder,
      destination: NotificationDestination.appointment,
      destinationId: next.id,
      unread: true,
    ),
    AppNotification(
      id: 'notification-exam',
      title: 'Lembrete de exame',
      message:
          '${exam.specialty} em ${AppointmentDate.shortDate(exam.dateTime)}. Confira as orientações de preparo.',
      dateTime: at(0, 6, 30),
      category: NotificationCategory.exam,
      destination: NotificationDestination.appointment,
      destinationId: exam.id,
      unread: true,
    ),
    AppNotification(
      id: 'notification-confirmation',
      title: 'Presença registrada',
      message:
          'Sua resposta para ${next.specialty}: ${next.confirmationStatus.responseLabel}. Registro somente nesta sessão.',
      dateTime: at(-1, 15, 20),
      category: NotificationCategory.consultation,
      destination: NotificationDestination.appointment,
      destinationId: next.id,
    ),
    AppNotification(
      id: 'notification-medications',
      title: 'Seus medicamentos',
      message: 'Confira as informações de medicamentos que você cadastrou.',
      dateTime: at(-1, 12, 0),
      category: NotificationCategory.reminder,
      destination: NotificationDestination.medications,
    ),
    AppNotification(
      id: 'notification-documents',
      title: 'Documentos do histórico',
      message: 'Veja os exemplos de documentos associados aos seus registros.',
      dateTime: at(-1, 10, 15),
      category: NotificationCategory.system,
      destination: NotificationDestination.history,
      destinationId: 'hist-consulta-01',
    ),
    AppNotification(
      id: 'notification-earlier',
      title: 'Exame na Agenda',
      message:
          '${exam.specialty} está na sua Agenda. Confira data, horário e local.',
      dateTime: at(-2, 9, 0),
      category: NotificationCategory.exam,
      destination: NotificationDestination.appointment,
      destinationId: exam.id,
    ),
  ];
}
