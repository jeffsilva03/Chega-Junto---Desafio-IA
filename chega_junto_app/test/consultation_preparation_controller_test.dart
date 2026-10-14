import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:chega_junto_app/core/state/consultation_preparation_controller.dart';
import 'package:chega_junto_app/core/state/preparation_controller.dart';
import 'package:chega_junto_app/core/state/report_controller.dart';
import 'package:chega_junto_app/core/network/api_exception.dart';
import 'package:chega_junto_app/data/mock/mock_audio_draft_service.dart';
import 'package:chega_junto_app/data/mock/mock_clarification_repository.dart';
import 'package:chega_junto_app/data/mock/mock_conversation_assistant.dart';
import 'package:chega_junto_app/data/mock/mock_preparation_repository.dart';
import 'package:chega_junto_app/data/models/pre_visit_report.dart';
import 'package:chega_junto_app/data/models/report_clarification.dart';
import 'package:chega_junto_app/data/repositories/clarification_repository.dart';

class _Deferred implements ClarificationRepository {
  _Deferred(this.delegate);
  final ClarificationRepository delegate;
  final result = Completer<PreVisitReport>();
  int calls = 0;
  @override
  Future<PreVisitReport> next(String appointmentId) {
    calls++;
    return result.future;
  }

  @override
  Future<PreVisitReport> answer(
    String appointmentId,
    String id,
    ClarificationAnswerKind kind,
    String? text,
    String revision,
  ) => delegate.answer(appointmentId, id, kind, text, revision);
  @override
  Future<PreVisitReport> skip(String appointmentId) =>
      delegate.skip(appointmentId);
}

void main() {
  late MockPreparationRepository repository;
  late PreparationController preparation;
  late ReportController report;
  late MockClarificationRepository clarifications;
  late ConsultationPreparationController conversation;
  setUp(() async {
    repository = MockPreparationRepository();
    preparation = PreparationController(repository);
    report = ReportController(
      preparation,
      MockConversationAssistant(repository, delay: Duration.zero),
      const MockAudioDraftService(delay: Duration.zero),
    );
    clarifications = MockClarificationRepository(
      repository,
      delay: Duration.zero,
    );
    conversation = ConsultationPreparationController(report, clarifications);
    await preparation.load();
    await conversation.enter();
  });
  tearDown(() {
    conversation.dispose();
    report.dispose();
    preparation.dispose();
  });

  test('Entrada não gera IA e deriva relato persistido', () {
    expect(conversation.step, PreparationConversationStep.text);
    expect(report.clarifications, isEmpty);
    expect(report.processing, false);
  });
  test('Relato vazio permanece introdução e não gera pergunta', () async {
    report.setText('');
    await conversation.enter();
    expect(conversation.step, PreparationConversationStep.intro);
    await conversation.startComplement();
    expect(report.clarifications, isEmpty);
  });
  test(
    'Salva original antes da primeira pergunta e retomada não duplica',
    () async {
      report.setText('Conteúdo novo fictício.');
      await conversation.startComplement();
      expect(
        (await repository.loadReport(report.appointmentId!))!.originalText,
        report.text,
      );
      final id = conversation.pending!.id;
      await conversation.retryComplement();
      expect(conversation.pending!.id, id);
      expect(report.clarifications.length, 1);
    },
  );
  test('Opção e texto persistem separados sem alterar original', () async {
    final original = report.text;
    await conversation.startComplement();
    await conversation.submitAnswer(
      ClarificationAnswerKind.option,
      conversation.pending!.options.first,
    );
    expect(report.clarifications.length, 2);
    await conversation.submitAnswer(
      ClarificationAnswerKind.text,
      'Não tenho certeza de quando começou.',
    );
    expect(report.text, original);
    expect(report.clarificationsCompleted, true);
    expect(conversation.step, PreparationConversationStep.summary);
    expect(
      report.sections.firstWhere((s) => s.id == 'context').text,
      contains('Não tenho certeza'),
    );
    expect(report.questions.every((q) => !q.selected), true);
    expect(report.summaryOutdated, false);
  });
  for (final kind in [
    ClarificationAnswerKind.dontKnow,
    ClarificationAnswerKind.dontRemember,
    ClarificationAnswerKind.preferNotToAnswer,
  ]) {
    test(
      '${kind.wire} nunca vira fato no resumo ou impede continuidade',
      () async {
        await conversation.startComplement();
        await conversation.submitAnswer(kind, null);
        await conversation.submitAnswer(kind, null);
        expect(report.clarifications.every((q) => q.answerKind == kind), true);
        expect(report.sections.firstWhere((s) => s.id == 'context').text, '');
        expect(conversation.step, PreparationConversationStep.summary);
      },
    );
  }
  test('Pular conclui sem nova pergunta e preserva relato', () async {
    final original = report.text;
    await conversation.startComplement();
    await conversation.skipComplement();
    expect(report.text, original);
    expect(
      report.clarifications.single.answerKind,
      ClarificationAnswerKind.preferNotToAnswer,
    );
    expect(report.hasContent, true);
  });
  test(
    'Editar resposta mantém resumo anterior mas exige nova organização',
    () async {
      await conversation.startComplement();
      await conversation.submitAnswer(ClarificationAnswerKind.text, 'Antes.');
      await conversation.skipComplement();
      final old = report.sections;
      await conversation.submitAnswer(
        ClarificationAnswerKind.text,
        'Resposta revisada.',
        question: report.clarifications.first,
      );
      expect(report.sections, old);
      expect(report.summaryOutdated, true);
      expect(report.clarificationsCompleted, true);
      expect(report.reviewed, false);
      expect(conversation.step, PreparationConversationStep.clarification);
      await conversation.organize();
      expect(report.summaryOutdated, false);
      expect(
        report.sections.firstWhere((s) => s.id == 'context').text,
        contains('Resposta revisada'),
      );
    },
  );
  test('Editar original oculta complemento stale sem apagar resumo', () async {
    await conversation.startComplement();
    await conversation.skipComplement();
    final old = report.sections;
    report.setText('Outro relato fictício.');
    expect(report.clarifications, isEmpty);
    expect(report.clarificationsCurrent, false);
    expect(report.sections, old);
    expect(report.summaryOutdated, true);
    await conversation.startComplement();
    expect(report.clarifications.length, 1);
    expect(report.clarifications.single.answered, false);
  });
  test(
    'Cancelar confirmação não substitui edição nem consome organização',
    () async {
      await conversation.startComplement();
      await conversation.skipComplement();
      report.editSection('reason', 'Minha edição.');
      report.setText('Novo relato.');
      conversation.confirmReplacement = () async => false;
      await conversation.skipComplement();
      expect(report.sections.first.text, 'Minha edição.');
      expect(report.summaryOutdated, true);
    },
  );
  test('Revisão e conclusão podem retomar sem novas chamadas', () async {
    await conversation.startComplement();
    await conversation.skipComplement();
    await conversation.reviewSummary();
    expect(conversation.step, PreparationConversationStep.questions);
    await conversation.reviewQuestions();
    expect(conversation.step, PreparationConversationStep.finalReview);
    await conversation.complete();
    expect(conversation.step, PreparationConversationStep.completed);
    conversation.leave();
    await conversation.enter();
    expect(conversation.step, PreparationConversationStep.completed);
    expect(report.preparation.overview!.progress.percentage, 100);
  });
  test('Falha de geração preserva original e permite pular', () async {
    conversation.dispose();
    final deferred = _Deferred(clarifications);
    conversation = ConsultationPreparationController(report, deferred);
    await conversation.enter();
    final source = report.text;
    final pending = conversation.startComplement();
    await Future<void>.delayed(Duration.zero);
    deferred.result.completeError(const ApiException('Indisponível'));
    await pending;
    expect(conversation.error, isA<ApiException>());
    expect(report.text, source);
    expect(conversation.busy, false);
    await conversation.skipComplement();
    expect(report.hasContent, true);
  });
  test('Duplo clique faz uma única chamada', () async {
    conversation.dispose();
    final deferred = _Deferred(clarifications);
    conversation = ConsultationPreparationController(report, deferred);
    await conversation.enter();
    final pending = conversation.startComplement();
    await conversation.startComplement();
    await Future<void>.delayed(Duration.zero);
    expect(deferred.calls, 1);
    deferred.result.complete(await clarifications.next(report.appointmentId!));
    await pending;
    expect(report.clarifications.length, 1);
  });
  test(
    'Edição durante resposta remota preserva rascunho e mostra conflito',
    () async {
      conversation.dispose();
      final deferred = _Deferred(clarifications);
      conversation = ConsultationPreparationController(report, deferred);
      await conversation.enter();
      final pending = conversation.startComplement();
      await Future<void>.delayed(Duration.zero);
      final remote = await clarifications.next(report.appointmentId!);
      report.setText('Texto digitado durante a chamada.');
      deferred.result.complete(remote);
      await pending;
      expect(report.text, 'Texto digitado durante a chamada.');
      expect(report.preservedDraft!.originalText, report.text);
      expect(report.conflict, true);
      expect(conversation.error, isA<ConflictException>());
    },
  );
  test(
    'Sair invalida resposta tardia e reentrada recupera pergunta salva',
    () async {
      conversation.dispose();
      final deferred = _Deferred(clarifications);
      conversation = ConsultationPreparationController(report, deferred);
      await conversation.enter();
      final pending = conversation.startComplement();
      await Future<void>.delayed(Duration.zero);
      conversation.leave();
      deferred.result.complete(
        await clarifications.next(report.appointmentId!),
      );
      await pending;
      expect(report.clarifications, isEmpty);
      await conversation.enter();
      expect(report.clarifications.length, 1);
      expect(conversation.step, PreparationConversationStep.clarification);
    },
  );
}
