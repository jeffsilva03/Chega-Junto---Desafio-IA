import '../../core/services/ai_assistant_service.dart';
import '../models/organized_report.dart';
import '../models/report_clarification.dart';
import '../repositories/preparation_repository.dart';
import 'mock_ai_assistant_service.dart';

class MockConversationAssistant implements AiAssistantService {
  const MockConversationAssistant(
    this.preparation, {
    this.delay = const Duration(milliseconds: 1400),
  });
  final PreparationRepository preparation;
  final Duration delay;
  @override
  Future<OrganizedReport> organize(
    String originalText, {
    String? appointmentId,
  }) async {
    final base = await MockAiAssistantService(
      delay: delay,
    ).organize(originalText, appointmentId: appointmentId);
    final report = appointmentId == null
        ? null
        : await preparation.loadReport(appointmentId);
    final answers = report?.clarificationsCurrent == true
        ? report!.clarifications
              .where(
                (row) =>
                    row.answerKind == ClarificationAnswerKind.text ||
                    row.answerKind == ClarificationAnswerKind.option,
              )
              .map((row) => '${row.questionText}\n${row.answerText}')
              .join('\n\n')
        : '';
    return OrganizedReport(
      sourceHash: report?.currentSourceHash,
      sections: [
        for (final section in base.sections)
          section.id == 'context' ? section.withText(answers) : section,
      ],
      questions: [
        for (final question in base.questions)
          question.copyWith(selected: false),
      ],
    );
  }
}
