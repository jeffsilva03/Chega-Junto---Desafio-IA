import '../../core/services/ai_assistant_service.dart';
import '../models/organized_report.dart';

/// Literal organization avoids inferring clinical categories or inventing facts.
class MockAiAssistantService implements AiAssistantService {
  const MockAiAssistantService({
    this.delay = const Duration(milliseconds: 1400),
  });
  final Duration delay;
  @override
  Future<OrganizedReport> organize(
    String originalText, {
    String? appointmentId,
  }) async {
    if (originalText.trim().isEmpty) throw ArgumentError('Relato vazio.');
    await Future<void>.delayed(delay);
    final paragraphs = originalText.trim().split(RegExp(r'\n\s*\n'));
    return OrganizedReport(
      sections: [
        ReportSection(
          id: 'reason',
          title: 'Motivo da consulta',
          text: paragraphs.first,
        ),
        ReportSection(
          id: 'points',
          title: 'Pontos relatados',
          text: paragraphs.skip(1).join('\n\n'),
        ),
        const ReportSection(
          id: 'context',
          title: 'Contexto informado',
          text: '',
        ),
        const ReportSection(
          id: 'other',
          title: 'Outros pontos importantes',
          text: '',
        ),
      ],
      questions: const [
        ConsultationQuestion(
          id: 'observe',
          text: 'O que devo observar até o próximo atendimento?',
        ),
        ConsultationQuestion(
          id: 'care',
          text: 'Existe algum cuidado que eu deva seguir?',
        ),
        ConsultationQuestion(id: 'return', text: 'Quando devo retornar?'),
      ],
    );
  }
}
