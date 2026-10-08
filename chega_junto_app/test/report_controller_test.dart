import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:chega_junto_app/core/services/ai_assistant_service.dart';
import 'package:chega_junto_app/core/services/audio_draft_service.dart';
import 'package:chega_junto_app/core/state/preparation_controller.dart';
import 'package:chega_junto_app/core/state/report_controller.dart';
import 'package:chega_junto_app/data/mock/mock_ai_assistant_service.dart';
import 'package:chega_junto_app/data/mock/mock_audio_draft_service.dart';
import 'package:chega_junto_app/data/mock/mock_preparation_repository.dart';
import 'package:chega_junto_app/data/models/organized_report.dart';

class _DeferredAssistant implements AiAssistantService {
  final result = Completer<OrganizedReport>();
  @override
  Future<OrganizedReport> organize(String text) => result.future;
}

class _FailedAudio implements AudioDraftService {
  @override
  Future<String> transcribeDemo(String text) async =>
      throw StateError('offline');
}

class _FailedAssistant implements AiAssistantService {
  @override
  Future<OrganizedReport> organize(String text) async =>
      throw StateError('offline');
}

void main() {
  const assistant = MockAiAssistantService(delay: Duration.zero);
  const audio = MockAudioDraftService(delay: Duration.zero);
  late MockPreparationRepository repository;
  late PreparationController preparation;
  late ReportController controller;
  setUp(() async {
    repository = MockPreparationRepository();
    preparation = PreparationController(repository);
    controller = ReportController(preparation, assistant, audio);
    await preparation.load();
  });
  tearDown(() {
    controller.dispose();
    preparation.dispose();
  });

  test(
    'Mock conserva literalmente as informações e nunca insere fatos clínicos',
    () async {
      for (final source in [
        'Quero tirar minhas dúvidas.',
        'Meu exame está comigo. Não uso medicamento.',
        'Minha anotação é esta.\n\nOutra informação fornecida por mim.',
      ]) {
        final result = await assistant.organize(source);
        expect(
          result.sections
              .where((s) => s.text.isNotEmpty)
              .map((s) => s.text)
              .join('\n\n'),
          source,
        );
        expect(result.questions.map((q) => q.text), [
          'O que devo observar até o próximo atendimento?',
          'Existe algum cuidado que eu deva seguir?',
          'Quando devo retornar?',
        ]);
        expect(result.sections[2].text, isEmpty);
        expect(result.sections[3].text, isEmpty);
      }
      await expectLater(assistant.organize('  '), throwsArgumentError);
    },
  );
  test('Rascunho não é reinicializado ao recarregar o preparo', () async {
    controller.setText('Meu novo relato.');
    await preparation.load();
    expect(controller.text, 'Meu novo relato.');
    expect(await controller.organize(), isTrue);
    controller.editSection('reason', 'Versão revisada por mim.');
    controller.editSection('context', 'Contexto adicionado por mim.');
    controller.editSection('context', '');
    expect(controller.sections.first.text, 'Versão revisada por mim.');
    expect(controller.text, 'Meu novo relato.');
    controller.selectQuestion('care', false);
    controller.saveQuestion('Minha dúvida pessoal?');
    final custom = controller.questions.last.id;
    controller.moveQuestion(custom, -1);
    controller.saveQuestion('Minha pergunta editada?', id: custom);
    await controller.finishReview();
    final saved = (await repository.loadOverview()).report;
    expect(saved.originalText, 'Meu novo relato.');
    expect(saved.organizedSummary, contains('Versão revisada por mim.'));
    expect(
      saved.suggestedQuestions,
      isNot(contains('Existe algum cuidado que eu deva seguir?')),
    );
    expect(saved.suggestedQuestions, contains('Minha pergunta editada?'));
    expect(controller.reviewed, isTrue);
    controller.removeQuestion(custom);
    controller.selectAll(false);
    expect(controller.questions.every((q) => !q.selected), isTrue);
    controller.selectAll(true);
    expect(controller.questions.every((q) => q.selected), isTrue);
    controller.clearSummary();
    expect(controller.hasContent, isFalse);
    expect(controller.questions, isEmpty);
    expect(controller.text, 'Meu novo relato.');
    await expectLater(controller.finishReview(), throwsStateError);
  });
  test(
    'Processamento é cancelável e uma resposta atrasada não substitui o rascunho',
    () async {
      final deferred = _DeferredAssistant();
      final draft = ReportController(preparation, deferred, audio);
      final future = draft.organize();
      expect(draft.processing, isTrue);
      draft.cancelProcessing();
      draft.setText('Relato atualizado enquanto aguardava.');
      deferred.result.complete(await assistant.organize('Versão anterior.'));
      expect(await future, isFalse);
      expect(draft.hasSummary, isFalse);
      expect(draft.text, 'Relato atualizado enquanto aguardava.');
      draft.dispose();
    },
  );
  test('Falha do serviço não apaga texto e encerra processamento', () async {
    final draft = ReportController(preparation, _FailedAssistant(), audio);
    draft.setText('Texto mantido.');
    expect(await draft.organize(), isFalse);
    expect(draft.processing, isFalse);
    expect(draft.failed, isTrue);
    expect(draft.text, 'Texto mantido.');
    draft.dispose();
  });
  test(
    'Edição original sinaliza resumo desatualizado sem perder edições',
    () async {
      await controller.organize();
      controller.editSection('reason', 'Resumo que editei.');
      controller.setText('Atualização do relato original.');
      expect(controller.summaryOutdated, isTrue);
      expect(controller.sections.first.text, 'Resumo que editei.');
      await expectLater(controller.finishReview(), throwsStateError);
    },
  );
  test(
    'Áudio simulado pausa, retoma, transcreve e exige uso explícito sem duplicar texto',
    () async {
      controller.setText('Eu informei apenas este conteúdo.');
      controller.startAudio();
      expect(controller.audioStatus, AudioDraftStatus.recording);
      controller.toggleAudio();
      expect(controller.audioStatus, AudioDraftStatus.paused);
      controller.toggleAudio();
      expect(controller.audioStatus, AudioDraftStatus.recording);
      await controller.finishAudio();
      expect(controller.audioStatus, AudioDraftStatus.review);
      expect(controller.transcription, controller.text);
      controller.useTranscription();
      expect(controller.text, 'Eu informei apenas este conteúdo.');
      controller.startAudio();
      await controller.finishAudio();
      controller.setTranscription('Minha transcrição revisada.');
      controller.useTranscription();
      expect(
        controller.text,
        'Eu informei apenas este conteúdo.\n\nMinha transcrição revisada.',
      );
    },
  );
  test(
    'Áudio vazio oferece exemplo fictício e falha preserva rascunho',
    () async {
      controller.setText('');
      controller.startAudio();
      await controller.finishAudio();
      expect(controller.text, isEmpty);
      expect(
        controller.transcription,
        'Quero organizar minhas dúvidas para conversar na consulta.',
      );
      final draft = ReportController(preparation, assistant, _FailedAudio());
      final original = draft.text;
      draft.startAudio();
      await expectLater(draft.finishAudio(), throwsStateError);
      expect(draft.audioStatus, AudioDraftStatus.paused);
      expect(draft.text, original);
      draft.dispose();
    },
  );
}
