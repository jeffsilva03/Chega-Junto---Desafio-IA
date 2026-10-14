import '../../core/network/api_client.dart';
import '../../core/services/ai_assistant_service.dart';
import '../models/organized_report.dart';

class ApiAiAssistantService implements AiAssistantService {
  const ApiAiAssistantService(this.client);
  final ApiClient client;
  @override
  Future<OrganizedReport> organize(
    String originalText, {
    String? appointmentId,
  }) async {
    if (appointmentId == null) throw ArgumentError('Atendimento necessário.');
    final json = await client.request(
      'POST',
      '/api/v1/appointments/$appointmentId/report/organization',
      body: {'original_text': originalText},
      timeout: const Duration(seconds: 140),
    );
    return OrganizedReport(
      sourceHash: json['source_hash'] as String?,
      sections: [
        for (final s in json['sections'] as List)
          ReportSection(
            id: s['section_key'] as String,
            sectionKey: s['section_key'] as String,
            title: s['title'] as String,
            text: s['text'] as String,
          ),
      ],
      questions: [
        for (final (i, q) in (json['questions'] as List).indexed)
          ConsultationQuestion(
            id: 'ai-$i',
            text: q['text'] as String,
            selected: false,
          ),
      ],
    );
  }
}
