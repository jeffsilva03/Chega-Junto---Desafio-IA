import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/appointment.dart';
import '../models/appointment_reminder.dart';
import '../models/checklist_item.dart';
import '../models/pre_visit_report.dart';
import '../models/preparation_overview.dart';
import '../repositories/preparation_repository.dart';
import 'api_mapping.dart';

class ApiPreparationRepository implements PreparationRepository {
  @override
  Future<PreVisitReport> setReportFinalReview(
    String appointmentId,
    String expectedRevision,
    bool completed,
  ) async => _remember(
    await client.request(
      'PUT',
      '${_path(appointmentId)}/final-review',
      body: {'expected_revision': expectedRevision, 'completed': completed},
    ),
  );
  ApiPreparationRepository(this.client);
  final ApiClient client;
  final Map<String, PreVisitReport> _reports = {};
  String _path(String id) => '/api/v1/appointments/${decimalId(id)}';
  @override
  Future<List<Appointment>> loadAppointments() async => (await client.pages(
    '/api/v1/appointments',
  )).map(appointmentFromJson).toList();
  @override
  Future<Appointment> loadAppointment(String id) async =>
      appointmentFromJson(await client.request('GET', _path(id)));
  @override
  Future<List<AppointmentReminder>> loadReminders() async =>
      (await client.pages('/api/v1/reminders')).map(reminderFromJson).toList();
  @override
  Future<AppointmentReminder> addReminder(AppointmentReminder reminder) async {
    // No retries: a transport failure cannot prove that the POST was not committed.
    final created = reminderFromJson(
      await client.request(
        'POST',
        '/api/v1/reminders',
        body: {
          'title': reminder.title,
          'remind_at': reminder.dateTime.toUtc().toIso8601String(),
          if (reminder.appointmentId != null)
            'appointment_id': decimalId(reminder.appointmentId),
        },
      ),
    );
    lastCreatedReminder = created;
    return created;
  }

  AppointmentReminder? lastCreatedReminder;

  @override
  Future<PreparationOverview> loadOverview() async {
    final j = await client.request('GET', '/api/v1/preparation/overview');
    final firstName = j['user']['first_name'] as String;
    final reference = civilDate(j['reference_date']);
    if (j['next_appointment'] == null) {
      return PreparationOverview(
        firstName: firstName,
        nextAppointment: null,
        progress: PreparationProgress({}),
        checklist: const [],
        report: PreVisitReport(
          appointmentId: '',
          originalText: '',
          updatedAt: reference,
        ),
        reminder: '',
        referenceDate: reference,
      );
    }
    final id = decimalId(j['next_appointment']['id']);
    final results = await Future.wait<Object?>([
      loadAppointment(id),
      client.request('GET', '${_path(id)}/checklist'),
      loadReport(id),
    ]);
    final checklist = results[1] as Json;
    return PreparationOverview(
      firstName: firstName,
      nextAppointment: results[0] as Appointment,
      progress: progressFromJson(j['preparation']['progress']),
      checklist: objects(checklist['items']).map(checklistFromJson).toList(),
      checklistFraction: (checklist['fraction'] as num).toDouble(),
      report:
          results[2] as PreVisitReport? ??
          PreVisitReport(
            appointmentId: id,
            originalText: '',
            updatedAt: reference,
          ),
      reminder: 'Confira os documentos e orientações para o atendimento.',
      referenceDate: reference,
    );
  }

  Future<Json> loadPreparation(String id) =>
      client.request('GET', '${_path(id)}/preparation');
  Future<ConfirmationStatus> loadAttendance(String id) async =>
      ConfirmationStatus.values.byName(
        (await client.request(
          'GET',
          '${_path(id)}/attendance',
        ))['attendance_status'],
      );
  @override
  Future<PreparationOverview> setChecklistItem(
    String appointmentId,
    String itemId,
    bool completed,
  ) async {
    await client.request(
      'PATCH',
      '${_path(appointmentId)}/checklist/${decimalId(itemId)}',
      body: {'is_completed': completed},
    );
    return loadOverview();
  }

  @override
  Future<PreparationOverview> setAttendance(
    String appointmentId,
    ConfirmationStatus status,
  ) async {
    await client.request(
      'PUT',
      '${_path(appointmentId)}/attendance',
      body: {'attendance_status': status.name},
    );
    return loadOverview();
  }

  @override
  Future<PreVisitReport?> loadReport(String appointmentId) async {
    try {
      return _remember(
        await client.request('GET', '${_path(appointmentId)}/report'),
      );
    } on NotFoundException {
      _reports.remove(appointmentId);
      return null;
    }
  }

  PreVisitReport _remember(Json j) {
    final report = reportFromJson(j);
    _reports[report.appointmentId] = report;
    return report;
  }

  @override
  Future<PreVisitReport> writeReport(
    PreVisitReport report, {
    String intent = 'edit',
    String? organizationSourceText,
  }) async => _remember(
    await client.request(
      'PUT',
      '${_path(report.appointmentId)}/report',
      body: reportToJson(
        report,
        intent: intent,
        organizationSourceText: organizationSourceText,
      ),
    ),
  );
  @override
  Future<PreVisitReport> reviewReport(
    String appointmentId,
    String expectedRevision,
  ) async => _remember(
    await client.request(
      'POST',
      '${_path(appointmentId)}/report/review',
      body: {'expected_revision': expectedRevision},
    ),
  );
  @override
  Future<PreVisitReport> clearReportSummary(
    String appointmentId,
    String expectedRevision,
  ) async => _remember(
    await client.request(
      'DELETE',
      '${_path(appointmentId)}/report/summary',
      query: {'expected_revision': expectedRevision},
    ),
  );
  @override
  Future<PreparationOverview> saveReport(PreVisitReport report) async {
    await writeReport(report);
    return loadOverview();
  }

  @override
  Future<PreparationOverview> setFinalReview(
    String appointmentId,
    bool completed,
  ) async {
    final report = _reports[appointmentId] ?? await loadReport(appointmentId);
    if (report == null) throw const NotFoundException();
    _remember(
      await client.request(
        'PUT',
        '${_path(appointmentId)}/final-review',
        body: {
          'expected_revision': report.contentRevision,
          'completed': completed,
        },
      ),
    );
    return loadOverview();
  }
}
