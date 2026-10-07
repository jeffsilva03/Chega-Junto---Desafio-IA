class AppointmentReminder {
  const AppointmentReminder({
    required this.id,
    required this.title,
    required this.dateTime,
    this.appointmentId,
  });
  final String id;
  final String title;
  final DateTime dateTime;
  final String? appointmentId;
}

enum ReminderTiming {
  dayBefore('1 dia antes', Duration(days: 1)),
  twoHoursBefore('2 horas antes', Duration(hours: 2)),
  atAppointment('No horário', Duration.zero);

  const ReminderTiming(this.label, this.offset);
  final String label;
  final Duration offset;
  DateTime dateFor(DateTime appointmentDate) =>
      appointmentDate.subtract(offset);
}
