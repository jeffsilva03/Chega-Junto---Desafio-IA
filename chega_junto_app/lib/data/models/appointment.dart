enum ConfirmationStatus { confirmed, undecided, unable }

extension ConfirmationStatusText on ConfirmationStatus {
  String get responseLabel => switch (this) {
    ConfirmationStatus.confirmed => 'Vou comparecer',
    ConfirmationStatus.undecided => 'Ainda não sei',
    ConfirmationStatus.unable => 'Não poderei comparecer',
  };
}

enum AppointmentType { consultation, exam, followUp }

enum AppointmentStatus { scheduled, cancelled, completed }

extension AppointmentStatusText on AppointmentStatus {
  String get label => switch (this) {
    AppointmentStatus.scheduled => 'Agendada',
    AppointmentStatus.cancelled => 'Cancelada',
    AppointmentStatus.completed => 'Concluída',
  };
}

class Appointment {
  const Appointment({
    required this.id,
    required this.title,
    required this.specialty,
    required this.professionalName,
    required this.dateTime,
    required this.facilityName,
    required this.address,
    required this.instructions,
    required this.confirmationStatus,
    this.type = AppointmentType.consultation,
    this.status = AppointmentStatus.scheduled,
  });
  final String id;
  final String title;
  final String specialty;
  final String professionalName;
  final DateTime dateTime;
  final String facilityName;
  final String address;
  final List<String> instructions;
  final ConfirmationStatus confirmationStatus;
  final AppointmentType type;
  final AppointmentStatus status;

  Appointment withConfirmation(ConfirmationStatus status) => Appointment(
    id: id,
    title: title,
    specialty: specialty,
    professionalName: professionalName,
    dateTime: dateTime,
    facilityName: facilityName,
    address: address,
    instructions: instructions,
    confirmationStatus: status,
    type: type,
    status: this.status,
  );
}
