import 'package:flutter_test/flutter_test.dart';
import 'package:chega_junto_app/core/state/preparation_controller.dart';
import 'package:chega_junto_app/core/state/report_controller.dart';
import 'package:chega_junto_app/data/mock/mock_ai_assistant_service.dart';
import 'package:chega_junto_app/data/mock/mock_audio_draft_service.dart';
import 'package:chega_junto_app/data/mock/mock_preparation_repository.dart';
import 'package:chega_junto_app/data/models/checklist_item.dart';
import 'package:chega_junto_app/data/models/preparation_overview.dart';

class _FinalReviewFailureRepository extends MockPreparationRepository {
  bool fail = true;
  @override
  Future<PreparationOverview> setFinalReview(
    String appointmentId,
    bool completed,
  ) {
    if (completed && fail) throw StateError('Falha simulada');
    return super.setFinalReview(appointmentId, completed);
  }
}

void main() {
  late MockPreparationRepository repository;
  late PreparationController preparation;
  late ReportController report;
  setUp(() async {
    repository = MockPreparationRepository();
    preparation = PreparationController(repository);
    await preparation.load();
    report = ReportController(
      preparation,
      const MockAiAssistantService(delay: Duration.zero),
      const MockAudioDraftService(delay: Duration.zero),
    );
  });
  tearDown(() {
    report.dispose();
    preparation.dispose();
  });

  test(
    'Revisão conclui somente a quarta etapa e preserva original e seleção',
    () async {
      final original = report.text;
      await report.organize();
      report.editSection('reason', 'Texto revisado pelo usuário.');
      report.selectQuestion('care', false);
      await report.finishReview();
      expect(preparation.overview!.progress.percentage, 75);
      await report.completePreparation();
      expect(preparation.overview!.progress.completedCount, 4);
      expect(preparation.overview!.progress.percentage, 100);
      await preparation.load();
      expect(preparation.finalReviewCompleted, isTrue);
      expect(preparation.overview!.report.originalText, original);
      expect(
        preparation.overview!.report.organizedSummary,
        contains('Texto revisado pelo usuário.'),
      );
      expect(
        preparation.overview!.report.suggestedQuestions,
        report.selectedQuestions.map((q) => q.text).toList(),
      );
      expect(
        preparation.overview!.report.suggestedQuestions,
        isNot(contains('Existe algum cuidado que eu deva seguir?')),
      );
    },
  );

  test('Sem resumo ou com original desatualizado não há conclusão', () async {
    await expectLater(report.completePreparation(), throwsStateError);
    await report.organize();
    report.setText('Nova informação fornecida por mim.');
    await expectLater(report.completePreparation(), throwsStateError);
    expect(preparation.finalReviewCompleted, isFalse);
    expect(report.text, 'Nova informação fornecida por mim.');
    expect(preparation.overview!.progress.percentage, 75);
  });

  test(
    'Alterar relato resumo ou perguntas reabre revisão sem perder conteúdo',
    () async {
      final mutations = <void Function()>[
        () => report.editSection('reason', 'Minha edição do resumo.'),
        () => report.selectQuestion('care', false),
        () => report.selectAll(false),
        () => report.saveQuestion('Minha pergunta adicional?'),
        () => report.saveQuestion('Minha pergunta revisada?', id: 'observe'),
        () => report.removeQuestion('return'),
        () => report.moveQuestion('return', -1),
        () => report.setText('Meu relato original atualizado.'),
        report.clearSummary,
      ];
      for (final mutate in mutations) {
        await report.organize();
        await report.completePreparation();
        expect(preparation.overview!.progress.percentage, 100);
        mutate();
        expect(preparation.finalReviewCompleted, isFalse);
        expect(preparation.overview!.progress.percentage, 75);
        final text = report.text;
        final sections = report.sections;
        final questions = report.questions;
        await preparation.load();
        expect(preparation.finalReviewCompleted, isFalse);
        expect(report.text, text);
        expect(report.sections, same(sections));
        expect(report.questions, same(questions));
      }
    },
  );

  test(
    'Reabrir ou salvar sem mudar conteúdo não invalida a conclusão',
    () async {
      await report.organize();
      await report.completePreparation();
      report.setText(report.text);
      report.editSection('reason', report.sections.first.text);
      report.selectQuestion('care', true);
      report.selectAll(true);
      report.saveQuestion(
        report.questions.first.text,
        id: report.questions.first.id,
      );
      await report.finishReview();
      expect(preparation.finalReviewCompleted, isTrue);
    },
  );

  test(
    'Pode concluir sem perguntas e não marca documentos pendentes',
    () async {
      await preparation.setChecklistItem('documento', false);
      await report.organize();
      report.selectAll(false);
      await report.completePreparation();
      expect(preparation.overview!.report.suggestedQuestions, isEmpty);
      expect(
        preparation.overview!.progress.completed,
        contains(PreparationStage.finalReview),
      );
      expect(
        preparation.overview!.progress.completed,
        isNot(contains(PreparationStage.documents)),
      );
      expect(preparation.overview!.progress.percentage, 75);
      expect(requiredChecklistProgress(preparation.overview!.checklist), .5);
    },
  );

  test(
    'Falha na conclusão mantém rascunho e permite tentar novamente',
    () async {
      final failing = _FinalReviewFailureRepository();
      final state = PreparationController(failing);
      await state.load();
      final draft = ReportController(
        state,
        const MockAiAssistantService(delay: Duration.zero),
        const MockAudioDraftService(delay: Duration.zero),
      );
      await draft.organize();
      draft.editSection('reason', 'Revisão preservada.');
      await expectLater(draft.completePreparation(), throwsStateError);
      expect(state.overview!.progress.percentage, 75);
      expect(draft.sections.first.text, 'Revisão preservada.');
      failing.fail = false;
      await draft.completePreparation();
      expect(state.overview!.progress.percentage, 100);
      draft.dispose();
      state.dispose();
    },
  );
}
