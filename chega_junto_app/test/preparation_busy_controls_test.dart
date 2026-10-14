import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chega_junto_app/app/theme/app_theme.dart';
import 'package:chega_junto_app/core/state/preparation_controller.dart';
import 'package:chega_junto_app/core/state/report_controller.dart';
import 'package:chega_junto_app/core/state/consultation_preparation_controller.dart';
import 'package:chega_junto_app/data/mock/mock_preparation_repository.dart';
import 'package:chega_junto_app/data/mock/mock_ai_assistant_service.dart';
import 'package:chega_junto_app/data/mock/mock_audio_draft_service.dart';
import 'package:chega_junto_app/data/mock/mock_clarification_repository.dart';
import 'package:chega_junto_app/data/models/report_clarification.dart';
import 'package:chega_junto_app/features/pre_visit_report/presentation/widgets/preparation_clarification_view.dart';
import 'package:chega_junto_app/features/pre_visit_report/presentation/widgets/preparation_review_cards.dart';

void main() {
  testWidgets(
    'Salvamento bloqueia edição de resposta/resumo/perguntas e conserva rascunho',
    (tester) async {
      final repository = MockPreparationRepository();
      final preparation = PreparationController(repository);
      final report = ReportController(
        preparation,
        const MockAiAssistantService(delay: Duration.zero),
        const MockAudioDraftService(delay: Duration.zero),
      );
      final conversation = ConsultationPreparationController(
        report,
        MockClarificationRepository(repository, delay: Duration.zero),
      );
      await preparation.load();
      final organization = report.organize();
      await tester.pump(const Duration(milliseconds: 1));
      await organization;
      conversation.busy = true;
      var submitted = 0;
      Widget view() => MaterialApp(
        theme: AppTheme.create(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                ClarificationComposer(
                  question: const ReportClarification(
                    id: '1',
                    questionText: 'Qual informação deseja preservar?',
                    position: 0,
                    answerKind: ClarificationAnswerKind.text,
                    answerText: 'Resposta revisada.',
                  ),
                  conversation: conversation,
                  editing: true,
                  onSubmit: (_, _) async {
                    submitted++;
                  },
                ),
                ClarificationComposer(
                  question: const ReportClarification(
                    id: '2',
                    questionText: 'Quando percebeu?',
                    position: 1,
                    options: ['Hoje', 'Antes'],
                    answerKind: ClarificationAnswerKind.option,
                    answerText: 'Antes',
                  ),
                  conversation: conversation,
                  editing: true,
                  onSubmit: (_, _) async {
                    submitted++;
                  },
                ),
                OrganizedReportCard(
                  controller: report,
                  enabled: !conversation.busy,
                ),
                ConsultationQuestionsCard(
                  controller: report,
                  enabled: !conversation.busy,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('v9-answer-input'));
      expect(tester.widget<TextField>(field).enabled, false);
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Resposta revisada.',
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('edit-reason')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('question-care')),
            )
            .onChanged,
        isNull,
      );
      expect(
        tester
            .widget<RadioListTile<String>>(
              find.byKey(const ValueKey('v9-option-0')),
            )
            .enabled,
        false,
      );
      await tester.tap(
        find.byKey(const ValueKey('v9-option-0')),
        warnIfMissed: false,
      );
      expect(submitted, 0);
      conversation.busy = false;
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).enabled, true);
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Resposta revisada.',
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('edit-reason')))
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('question-care')),
            )
            .onChanged,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      conversation.dispose();
      report.dispose();
      preparation.dispose();
    },
  );
}
