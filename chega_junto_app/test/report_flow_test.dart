import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:chega_junto_app/app/app.dart';
import 'package:chega_junto_app/app/demo_session.dart';
import 'package:chega_junto_app/app/router/app_routes.dart';
import 'package:chega_junto_app/app/theme/app_tokens.dart';
import 'package:chega_junto_app/core/widgets/app_bottom_navigation.dart';
import 'package:chega_junto_app/core/state/report_controller.dart';
import 'package:chega_junto_app/data/mock/mock_ai_assistant_service.dart';
import 'package:chega_junto_app/data/mock/mock_audio_draft_service.dart';
import 'package:chega_junto_app/data/mock/mock_profile_repository.dart';
import 'package:chega_junto_app/data/models/profile_preferences.dart';
import 'package:chega_junto_app/data/repositories/auth_repository.dart';
import 'package:chega_junto_app/features/pre_visit_report/presentation/pages/consultation_preparation_page.dart';
import 'package:chega_junto_app/core/state/consultation_preparation_controller.dart';
import 'package:chega_junto_app/data/models/report_clarification.dart';
import 'package:chega_junto_app/features/profile/presentation/pages/accessibility_page.dart';

class _Auth extends AuthRepository {
  @override
  Future<void> signInDemo() async {}
}

Future<void> _size(WidgetTester tester, Size size, [double scale = 1]) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.runAsync(() async {
    await (FontLoader(
      'NunitoSans',
    )..addFont(rootBundle.load('assets/fonts/NunitoSans.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
}

Future<void> _mount(
  WidgetTester tester, {
  MockProfileRepository? profile,
  GlobalKey? capture,
}) async {
  final session = DemoSession(_Auth());
  await session.signIn();
  addTearDown(session.dispose);
  final app = ChegaJuntoApp(
    key: UniqueKey(),
    session: session,
    initialLocation: AppRoutes.report,
    profileRepository: profile,
    aiAssistant: const MockAiAssistantService(
      delay: Duration(milliseconds: 800),
    ),
    audioDraftService: const MockAudioDraftService(
      delay: Duration(milliseconds: 400),
    ),
  );
  await tester.pumpWidget(
    capture == null ? app : RepaintBoundary(key: capture, child: app),
  );
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_QA')) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final shot = await boundary.toImage(pixelRatio: 2);
    final bytes = await shot.toByteData(format: ui.ImageByteFormat.png);
    Directory('.local/qa').createSync(recursive: true);
    File('.local/qa/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    shot.dispose();
  });
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(AppBottomNavigation)));
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.pump();
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

ConsultationPreparationPage _page(WidgetTester tester) =>
    tester.widget<ConsultationPreparationPage>(
      find.byType(ConsultationPreparationPage),
    );
Future<void> _step(
  WidgetTester tester,
  PreparationConversationStep step,
) async {
  _page(tester).conversation.go(step);
  await tester.pumpAndSettle();
}

Future<void> _organize(WidgetTester tester) async {
  await _tap(tester, find.text('Continuar'));
  expect(find.byKey(const ValueKey('v9-option-0')), findsOneWidget);
  await _tap(tester, find.text('Continuar sem complemento'));
  expect(find.byKey(const ValueKey('v9-summary')), findsOneWidget);
}

Future<void> _organizeController(
  WidgetTester tester,
  ReportController controller,
) async {
  final pending = controller.organize();
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
  await pending;
}

void main() {
  testWidgets('Entrada pela Home usa URL principal e largura desktop de 760', (
    tester,
  ) async {
    await _size(tester, const Size(1366, 900));
    await _mount(tester);
    final router = _router(tester);
    router.go(AppRoutes.home);
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Relato pré-consulta'));
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.report);
    expect(tester.getSize(find.byType(Scaffold).last).width, 760);
    for (final step in PreparationConversationStep.values) {
      await _step(tester, step);
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.report);
    }
  });
  for (final route in [
    AppRoutes.audio,
    AppRoutes.processing,
    AppRoutes.summary,
    AppRoutes.questions,
    AppRoutes.finalReview,
  ]) {
    testWidgets('Rota antiga $route retoma estado salvo na rota principal', (
      tester,
    ) async {
      await _size(tester, const Size(390, 844));
      await _mount(tester);
      final router = _router(tester);
      router.go(route);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.report);
      expect(_page(tester).conversation.step, PreparationConversationStep.text);
      expect(_page(tester).controller.processing, false);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Card preserva conteúdo longo e descarta rascunho ao fechar', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _size(tester, const Size(390, 844));
    final capture = GlobalKey();
    await _mount(tester, capture: capture);
    await _organize(tester);
    final controller = _page(tester).controller;
    final original = controller.text;
    await _tap(tester, find.byKey(const ValueKey('edit-reason')));
    expect(
      RegExp('Conteúdo informado')
          .allMatches(
            tester
                .getSemantics(find.byKey(const ValueKey('report-edit-field')))
                .label,
          )
          .length,
      1,
    );
    expect(tester, meetsGuideline(androidTapTargetGuideline));
    expect(tester, meetsGuideline(labeledTapTargetGuideline));
    await _capture(tester, capture, 'v9-writing-dialog-390');
    await tester.enterText(
      find.byKey(const ValueKey('report-edit-field')),
      'Rascunho descartado.',
    );
    await _tap(tester, find.byTooltip('Fechar janela'));
    expect(controller.sections.first.text, original);
    for (final section in controller.sections) {
      await _tap(tester, find.byKey(ValueKey('edit-${section.id}')));
      final long = List.filled(30, 'Informação fictícia.').join(' ');
      await tester.enterText(
        find.byKey(const ValueKey('report-edit-field')),
        long,
      );
      await _tap(tester, find.byKey(const ValueKey('report-edit-save')));
      expect(
        controller.sections.firstWhere((s) => s.id == section.id).text,
        long,
      );
    }
    expect(controller.text, original);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Card de escrita mantém ações nos temas e teclado pequeno', (
    tester,
  ) async {
    await _size(tester, const Size(320, 568), 2.1);
    await _mount(tester);
    final controller = _page(tester).controller;
    await _organizeController(tester, controller);
    final router = _router(tester);
    for (final dark in [false, true]) {
      for (final contrast in [false, true]) {
        router.go(AppRoutes.accessibility);
        await tester.pumpAndSettle();
        final profile = tester
            .widget<AccessibilityPage>(find.byType(AccessibilityPage))
            .controller;
        profile.setAccessibility(
          profile.accessibility.copyWith(
            appearance: dark ? AppAppearance.dark : AppAppearance.light,
            highContrast: contrast,
          ),
        );
        router.go(AppRoutes.report);
        await tester.pumpAndSettle();
        await _step(tester, PreparationConversationStep.summary);
        await _tap(tester, find.byKey(const ValueKey('edit-reason')));
        tester.view.viewInsets = const FakeViewPadding(bottom: 200);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('report-edit-field')),
          'Texto conferido.',
        );
        await _tap(tester, find.byKey(const ValueKey('report-edit-save')));
        expect(controller.sections.first.text, 'Texto conferido.');
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
      }
    }
  });

  testWidgets('Relato, abas, edição, remoção e perguntas preservam trabalho', (
    tester,
  ) async {
    await _size(tester, const Size(390, 844));
    await _mount(tester);
    final router = _router(tester);
    await tester.enterText(
      find.byKey(const ValueKey('report-text')),
      'Quero conversar sobre minhas anotações.',
    );
    router.go(AppRoutes.home);
    await tester.pumpAndSettle();
    router.go(AppRoutes.report);
    await tester.pumpAndSettle();
    expect(
      _page(tester).controller.text,
      'Quero conversar sobre minhas anotações.',
    );
    await _organize(tester);
    final controller = _page(tester).controller;
    await _tap(tester, find.byKey(const ValueKey('edit-reason')));
    await tester.enterText(
      find.byKey(const ValueKey('report-edit-field')),
      'Meu texto revisado.',
    );
    await _tap(tester, find.byKey(const ValueKey('report-edit-save')));
    await _tap(tester, find.byKey(const ValueKey('edit-points')));
    await _tap(tester, find.text('Remover conteúdo'));
    expect(controller.sections.firstWhere((s) => s.id == 'points').text, '');
    await _tap(tester, find.text('Sim, continuar'));
    expect(find.byKey(const ValueKey('v9-questions')), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('question-care')));
    await _tap(tester, find.byKey(const ValueKey('v9-question-add')));
    await tester.enterText(
      find.byKey(const ValueKey('report-edit-field')),
      'Como organizar minhas anotações?',
    );
    await _tap(tester, find.byKey(const ValueKey('report-edit-save')));
    await _tap(tester, find.byTooltip('Voltar'));
    expect(find.text('Meu texto revisado.'), findsOneWidget);
    await _tap(tester, find.text('Sim, continuar'));
    expect(controller.questions.last.text, 'Como organizar minhas anotações?');
    await _tap(tester, find.text('Continuar'));
    expect(_router(tester).state.uri.path, AppRoutes.report);
    expect(find.byKey(const ValueKey('v9-final-review')), findsOneWidget);
    await _step(tester, PreparationConversationStep.summary);
    await _tap(tester, find.byTooltip('Opções do resumo'));
    await _tap(tester, find.text('Remover conteúdo do resumo'));
    await _tap(tester, find.text('Remover'));
    expect(controller.hasContent, false);
    expect(controller.text, 'Quero conversar sobre minhas anotações.');
    expect(controller.clarificationsCompleted, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Áudio mantém relógio, pausa, retomada e revisão explícita', (
    tester,
  ) async {
    await _size(tester, const Size(390, 844));
    await _mount(tester);
    await tester.enterText(
      find.byKey(const ValueKey('report-text')),
      'Meu relato escrito.',
    );
    await _tap(tester, find.text('Prefiro gravar um áudio'));
    await _tap(tester, find.byTooltip('Iniciar gravação'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:02'), findsOneWidget);
    await _tap(tester, find.byTooltip('Pausar gravação'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:02'), findsOneWidget);
    await _tap(tester, find.byTooltip('Continuar gravação'));
    await _tap(tester, find.text('Parar gravação'));
    expect(_page(tester).controller.text, 'Meu relato escrito.');
    await tester.enterText(
      find.byKey(const ValueKey('audio-transcription')),
      'Transcrição que revisei.',
    );
    await _tap(tester, find.text('Usar esta transcrição'));
    expect(
      _page(tester).controller.text,
      'Meu relato escrito.\n\nTranscrição que revisei.',
    );
    expect(find.byKey(const ValueKey('v9-text-input')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancelar chamada e relato vazio permitem retomar sem perda', (
    tester,
  ) async {
    await _size(tester, const Size(390, 844));
    await _mount(tester);
    await tester.enterText(find.byKey(const ValueKey('report-text')), '');
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    expect(button.onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('report-text')),
      'Texto que continua salvo.',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(_page(tester).controller.text, 'Texto que continua salvo.');
    expect(_page(tester).conversation.busy, false);
    expect(find.byKey(const ValueKey('report-text')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rota de processamento vazia retoma introdução sem chamada', (
    tester,
  ) async {
    await _size(tester, const Size(390, 844));
    await _mount(tester);
    final report = _page(tester).controller;
    report.setText('');
    await report.saveDraft();
    _router(tester).go(AppRoutes.home);
    await tester.pumpAndSettle();
    _router(tester).go(AppRoutes.processing);
    await tester.pumpAndSettle();
    expect(_page(tester).conversation.step, PreparationConversationStep.intro);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Semântica e áreas de toque das etapas são acessíveis', (
    tester,
  ) async {
    await _size(tester, const Size(390, 844));
    final semantics = tester.ensureSemantics();
    await _mount(tester);
    await _organize(tester);
    for (final step in PreparationConversationStep.values) {
      await _step(tester, step);
      expect(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester, meetsGuideline(androidTapTargetGuideline));
      expect(tester.takeException(), isNull);
    }
    semantics.dispose();
  });

  testWidgets('Menu inferior funciona em todas etapas e cancela ao sair', (
    tester,
  ) async {
    await _size(tester, const Size(320, 568));
    await _mount(tester);
    final controller = _page(tester).controller;
    await _organizeController(tester, controller);
    final router = _router(tester);
    for (final step in PreparationConversationStep.values) {
      for (final destination in {
        'Início': AppRoutes.home,
        'Agenda': AppRoutes.agenda,
        'Preparo': AppRoutes.checklist,
        'Perfil': AppRoutes.profile,
      }.entries) {
        router.go(AppRoutes.report);
        await tester.pumpAndSettle();
        await _step(tester, step);
        await _tap(
          tester,
          find.descendant(
            of: find.byType(AppBottomNavigation),
            matching: find.text(destination.key),
          ),
        );
        expect(
          router.routeInformationProvider.value.uri.path,
          destination.value,
        );
        expect(tester.takeException(), isNull);
      }
    }
    expect(controller.processing, false);
  });

  testWidgets('Fonte ampliada e teclado preservam ações da edição', (
    tester,
  ) async {
    await _size(tester, const Size(320, 568), 1.5);
    await _mount(tester);
    await _organize(tester);
    await _tap(tester, find.byKey(const ValueKey('edit-reason')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(find.text('Salvar').hitTestable(), findsOneWidget);
    expect(find.text('Cancelar').hitTestable(), findsOneWidget);
    await _tap(tester, find.text('Cancelar'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Reorganização confirma substituição e preserva edições ao cancelar',
    (tester) async {
      await _size(tester, const Size(390, 844));
      await _mount(tester);
      await _organize(tester);
      final report = _page(tester).controller;
      report.editSection('reason', 'Minha revisão preservada.');
      await _step(tester, PreparationConversationStep.text);
      await tester.enterText(
        find.byKey(const ValueKey('report-text')),
        'Relato atualizado por mim.',
      );
      await _tap(tester, find.text('Continuar'));
      await tester.ensureVisible(find.text('Continuar sem complemento'));
      await tester.tap(find.text('Continuar sem complemento'));
      await tester.pumpAndSettle();
      expect(find.text('Organizar o relato atualizado?'), findsOneWidget);
      await _tap(tester, find.text('Continuar editando'));
      expect(report.sections.first.text, 'Minha revisão preservada.');
      await tester.ensureVisible(find.text('Organizar resumo'));
      await tester.tap(find.text('Organizar resumo'));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Organizar novamente'));
      expect(report.sections.first.text, 'Relato atualizado por mim.');
      expect(report.summaryOutdated, false);
    },
  );

  testWidgets('Textos longos permanecem integrais durante sessão', (
    tester,
  ) async {
    await _size(tester, const Size(320, 568));
    await _mount(tester);
    final text = List.filled(80, 'Minha anotação.').join(' ');
    await tester.enterText(find.byKey(const ValueKey('report-text')), text);
    final router = _router(tester);
    router.go(AppRoutes.agenda);
    await tester.pumpAndSettle();
    router.go(AppRoutes.report);
    await tester.pumpAndSettle();
    expect(_page(tester).controller.text, text);
  });

  testWidgets('Revisão, edição e conclusão atualizam Home de 75 para 100', (
    tester,
  ) async {
    await _size(tester, const Size(390, 844));
    final capture = GlobalKey();
    await _mount(tester, capture: capture);
    await _organize(tester);
    final report = _page(tester).controller;
    report.editSection('reason', 'Meu resumo revisado para esta consulta.');
    await _tap(tester, find.text('Sim, continuar'));
    await _tap(tester, find.byKey(const ValueKey('question-observe')));
    await _tap(tester, find.text('Continuar'));
    expect(
      find.text('Meu resumo revisado para esta consulta.'),
      findsOneWidget,
    );
    expect(report.preparation.overview!.progress.percentage, 75);
    await _capture(tester, capture, 'v9-revisao-final-390');
    await _tap(tester, find.text('Concluir preparação'));
    expect(find.text('Preparação concluída!'), findsOneWidget);
    expect(report.preparation.overview!.progress.percentage, 100);
    await _capture(tester, capture, 'v9-preparacao-concluida-390');
    await _tap(tester, find.text('Voltar para início'));
    expect(find.text('100%'), findsOneWidget);
    await _tap(tester, find.text('Revisão final'));
    expect(
      _page(tester).conversation.step,
      PreparationConversationStep.completed,
    );
    await _step(tester, PreparationConversationStep.summary);
    report.editSection('reason', 'Nova revisão após conclusão.');
    await tester.pumpAndSettle();
    _router(tester).go(AppRoutes.home);
    await tester.pumpAndSettle();
    expect(find.text('75%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Revisão aberta sem resumo retoma relato sem inventar conteúdo', (
    tester,
  ) async {
    await _size(tester, const Size(320, 568));
    await _mount(tester);
    final original = _page(tester).controller.text;
    _router(tester).go(AppRoutes.home);
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Revisão final'));
    expect(_page(tester).controller.hasSummary, false);
    expect(_page(tester).controller.text, original);
    expect(find.text('Concluir preparação'), findsNothing);
    expect(find.byKey(const ValueKey('report-text')), findsOneWidget);
  });

  testWidgets('Concluir sem perguntas preserva dados reais do atendimento', (
    tester,
  ) async {
    await _size(tester, const Size(390, 844));
    await _mount(tester);
    await _organize(tester);
    final report = _page(tester).controller;
    report.selectAll(false);
    await _tap(tester, find.text('Sim, continuar'));
    await _tap(tester, find.text('Continuar'));
    expect(find.textContaining('Nenhuma pergunta selecionada'), findsOneWidget);
    await _tap(tester, find.text('Concluir preparação'));
    expect(report.preparation.overview!.report.suggestedQuestions, isEmpty);
    expect(find.text('Dra. Ana Beatriz Souza'), findsOneWidget);
    expect(find.textContaining('UBS Centro'), findsOneWidget);
  });

  for (final kind in [
    ClarificationAnswerKind.text,
    ClarificationAnswerKind.dontKnow,
    ClarificationAnswerKind.dontRemember,
    ClarificationAnswerKind.preferNotToAnswer,
  ]) {
    testWidgets(
      'Complemento aceita ${kind.wire} e mantém próxima pergunta individual',
      (tester) async {
        await _size(tester, const Size(390, 844));
        await _mount(tester);
        await _tap(tester, find.text('Continuar'));
        if (kind == ClarificationAnswerKind.text) {
          await _tap(tester, find.text('Responder com minhas palavras'));
          await tester.enterText(
            find.byKey(const ValueKey('v9-answer-input')),
            'Resposta fictícia com dúvida.',
          );
          await _tap(
            tester,
            find.byKey(const ValueKey('v9-clarification-continue')),
          );
        } else {
          await _tap(tester, find.byTooltip('Outras respostas'));
          await _tap(tester, find.text(kind.label));
        }
        final report = _page(tester).controller;
        expect(report.clarifications.length, 2);
        expect(report.clarifications.first.answerKind, kind);
        expect(report.clarifications.last.answered, false);
        expect(report.text, isNot(contains('Resposta fictícia')));
        final pending = report.clarifications.last.id;
        final router = _router(tester);
        router.go(AppRoutes.home);
        await tester.pumpAndSettle();
        router.go(AppRoutes.report);
        await tester.pumpAndSettle();
        expect(_page(tester).conversation.pending!.id, pending);
        expect(
          _page(tester).conversation.step,
          PreparationConversationStep.clarification,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final dimensions in [
    (const Size(320, 568), 1.5),
    (const Size(320, 568), 2.1),
    (const Size(390, 844), 1.0),
    (const Size(1366, 900), 1.0),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'Etapas sem cortes ${dimensions.$1} escala ${dimensions.$2} escuro $dark e contraste',
        (tester) async {
          await _size(tester, dimensions.$1, dimensions.$2);
          await _mount(tester);
          await _organize(tester);
          final router = _router(tester);
          for (final contrast in [false, true]) {
            router.go(AppRoutes.accessibility);
            await tester.pumpAndSettle();
            final profile = tester
                .widget<AccessibilityPage>(find.byType(AccessibilityPage))
                .controller;
            profile.setAccessibility(
              profile.accessibility.copyWith(
                appearance: dark ? AppAppearance.dark : AppAppearance.light,
                highContrast: contrast,
              ),
            );
            router.go(AppRoutes.report);
            await tester.pumpAndSettle();
            for (final step in PreparationConversationStep.values) {
              await _step(tester, step);
              final context = tester.element(find.byType(AppBottomNavigation));
              expect(
                Theme.of(context).brightness,
                dark ? Brightness.dark : Brightness.light,
              );
              expect(context.appColors.highContrast, contrast);
              await tester.drag(
                find.byType(SingleChildScrollView).first,
                const Offset(0, -1800),
              );
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: '$step / $dark / $contrast / $dimensions',
              );
            }
          }
        },
      );
    }
  }
}
