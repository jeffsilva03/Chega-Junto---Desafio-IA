import '../../core/network/api_client.dart';
import '../models/pre_visit_report.dart';
import '../models/report_clarification.dart';
import '../repositories/clarification_repository.dart';
import 'api_mapping.dart';

class ApiClarificationRepository implements ClarificationRepository {
  const ApiClarificationRepository(this.client);
  final ApiClient client;
  String _path(String id) => '/api/v1/appointments/${decimalId(id)}/report';
  @override
  Future<PreVisitReport> next(String appointmentId) async {
    await client.request(
      'POST',
      '${_path(appointmentId)}/clarifications/next',
      timeout: const Duration(seconds: 140),
    );
    return reportFromJson(await client.request('GET', _path(appointmentId)));
  }

  @override
  Future<PreVisitReport> answer(
    String appointmentId,
    String clarificationId,
    ClarificationAnswerKind kind,
    String? text,
    String expectedRevision,
  ) async => reportFromJson(
    await client.request(
      'PUT',
      '${_path(appointmentId)}/clarifications/${decimalId(clarificationId)}',
      body: {
        'answer_kind': kind.wire,
        'answer_text': text,
        'expected_revision': expectedRevision,
      },
    ),
  );
  @override
  Future<PreVisitReport> skip(String appointmentId) async => reportFromJson(
    await client.request('POST', '${_path(appointmentId)}/clarifications/skip'),
  );
}
