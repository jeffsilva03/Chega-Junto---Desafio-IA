import '../models/appointment.dart';
import '../models/appointment_reminder.dart';
import '../models/checklist_item.dart';
import '../models/preparation_overview.dart';
import '../models/pre_visit_report.dart';
import '../repositories/preparation_repository.dart';

class MockPreparationRepository implements PreparationRepository {
  static final demoToday = DateTime(2026, 10, 7);
  static final _next = Appointment(
    id: 'consulta-demo-01',
    title: 'Consulta clínica',
    specialty: 'Clínica geral',
    professionalName: 'Dra. Ana Beatriz Souza',
    dateTime: DateTime(2026, 10, 9, 8),
    facilityName: 'UBS Centro',
    address: 'Av. das Flores, 123 – Centro, São Paulo – SP, 01000-000',
    instructions: const [
      'Chegue com 15 minutos de antecedência.',
      'Jejum não é necessário para esta consulta.',
    ],
    confirmationStatus: ConfirmationStatus.confirmed,
  );
  PreparationOverview _overview = PreparationOverview(
    firstName: 'Maria',
    nextAppointment: _next,
    referenceDate: demoToday,
    progress: PreparationProgress({
      PreparationStage.documents,
      PreparationStage.attendance,
      PreparationStage.report,
    }),
    checklist: const [
      ChecklistItem(
        id: 'documento',
        title: 'Documento com foto',
        isRequired: true,
        isCompleted: true,
      ),
      ChecklistItem(
        id: 'sus',
        title: 'Cartão do SUS',
        isRequired: true,
        isCompleted: true,
      ),
      ChecklistItem(
        id: 'exames',
        title: 'Comprovantes ou exames anteriores',
        isRequired: false,
        isCompleted: true,
      ),
      ChecklistItem(
        id: 'antecedencia',
        title: 'Chegar 15 minutos antes',
        isRequired: false,
        section: ChecklistSection.reminders,
      ),
      ChecklistItem(
        id: 'duvidas',
        title: 'Separar dúvidas e sintomas',
        isRequired: false,
        isCompleted: true,
        section: ChecklistSection.reminders,
      ),
      ChecklistItem(
        id: 'medicamentos',
        title: 'Levar lista de medicamentos, se usar',
        isRequired: false,
        section: ChecklistSection.conversation,
      ),
      ChecklistItem(
        id: 'sintomas',
        title: 'Contar o que deseja conversar',
        isRequired: false,
        section: ChecklistSection.conversation,
      ),
    ],
    report: PreVisitReport(
      appointmentId: _next.id,
      originalText:
          'Quero lembrar de conversar sobre como tenho dormido e tirar minhas dúvidas durante a consulta.',
      updatedAt: DateTime(2026, 10, 7, 10),
    ),
    reminder: 'Leve cartão do SUS e documento com foto.',
  );
  final _reminders = [
    AppointmentReminder(
      id: 'lembrete-demo-01',
      title: 'Levar documento com foto',
      dateTime: DateTime(2026, 10, 9, 7, 30),
    ),
  ];

  @override
  Future<PreparationOverview> loadOverview() async => _overview;

  @override
  Future<PreparationOverview> saveReport(PreVisitReport report) async {
    if (report.appointmentId != _next.id) {
      throw StateError('Atendimento não encontrado.');
    }
    _overview = _overview.withReport(report);
    return _overview;
  }

  @override
  Future<List<Appointment>> loadAppointments() async => List.unmodifiable([
    _overview.nextAppointment,
    Appointment(
      id: 'exame-demo-01',
      title: 'Exame de sangue',
      specialty: 'Exame de sangue',
      professionalName: 'Equipe do laboratório',
      dateTime: DateTime(2026, 10, 13, 10),
      facilityName: 'Laboratório Municipal',
      address: 'Rua do Cuidado, 45 – Centro, São Paulo – SP',
      instructions: const [
        'Jejum de 8 horas.',
        'Beba apenas água e evite atividade física intensa.',
      ],
      confirmationStatus: ConfirmationStatus.undecided,
      type: AppointmentType.exam,
    ),
    Appointment(
      id: 'retorno-demo-01',
      title: 'Retorno',
      specialty: 'Clínica geral',
      professionalName: 'Dra. Ana Beatriz Souza',
      dateTime: DateTime(2026, 10, 25, 14),
      facilityName: 'UBS Centro',
      address: _next.address,
      instructions: const ['Leve suas anotações e dúvidas.'],
      confirmationStatus: ConfirmationStatus.undecided,
    ),
  ]);

  @override
  Future<List<AppointmentReminder>> loadReminders() async =>
      List.unmodifiable(_reminders);

  @override
  Future<PreparationOverview> setChecklistItem(
    String appointmentId,
    String itemId,
    bool completed,
  ) async {
    if (appointmentId != _next.id ||
        !_overview.checklist.any((item) => item.id == itemId)) {
      throw StateError('Item de preparo não encontrado.');
    }
    _overview = _overview.withChecklist(
      _overview.checklist
          .map(
            (item) => item.id == itemId ? item.withCompleted(completed) : item,
          )
          .toList(),
    );
    return _overview;
  }

  @override
  Future<void> addReminder(AppointmentReminder reminder) async {
    _reminders.add(reminder);
  }

  @override
  Future<PreparationOverview> setAttendance(
    String appointmentId,
    ConfirmationStatus status,
  ) async {
    if (appointmentId != _overview.nextAppointment.id) {
      throw StateError('Atendimento não encontrado.');
    }
    _overview = _overview.withAttendance(status);
    return _overview;
  }
}
