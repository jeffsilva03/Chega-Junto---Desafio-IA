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
import 'package:chega_junto_app/features/pre_visit_report/presentation/pages/pre_visit_report_page.dart';
import 'package:chega_junto_app/features/pre_visit_report/presentation/pages/audio_report_page.dart';
import 'package:chega_junto_app/features/ai_summary/presentation/pages/ai_summary_page.dart';
import 'package:chega_junto_app/features/questions/presentation/pages/consultation_questions_page.dart';
import 'package:chega_junto_app/features/profile/presentation/pages/accessibility_page.dart';
import 'package:chega_junto_app/features/final_review/presentation/pages/final_review_page.dart';

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
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _organize(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Salvar e continuar'));
  await tester.tap(find.text('Salvar e continuar'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  expect(find.text('Organizando seu relato...'), findsOneWidget);
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
  expect(find.byType(AiSummaryPage), findsOneWidget);
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
  testWidgets(
    'Novo card preserva conteúdo longo e descarta o rascunho ao fechar',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _size(tester, const Size(390, 844));
      final capture = GlobalKey();
      await _mount(tester, capture: capture);
      await tester.enterText(
        find.byKey(const ValueKey('report-text')),
        'Quero lembrar de conversar sobre como tenho dormido e tirar minhas dúvidas durante a consulta.',
      );
      await _organize(tester);
      final controller = tester
          .widget<AiSummaryPage>(find.byType(AiSummaryPage))
          .controller;
      final original = controller.text;
      await _tap(tester, find.byKey(const ValueKey('edit-reason')));
      final inputSemantics = tester.getSemantics(
        find.byKey(const ValueKey('report-edit-field')),
      );
      expect(
        RegExp('Conteúdo informado').allMatches(inputSemantics.label).length,
        1,
      );
      expect(tester, meetsGuideline(androidTapTargetGuideline));
      expect(tester, meetsGuideline(labeledTapTargetGuideline));
      await _capture(tester, capture, 'writing-dialog-390');
      await tester.enterText(
        find.byKey(const ValueKey('report-edit-field')),
        'Rascunho descartado.',
      );
      await _tap(tester, find.byTooltip('Fechar janela'));
      expect(controller.sections.first.text, original);
      for (final section in controller.sections) {
        await _tap(tester, find.byKey(ValueKey('edit-${section.id}')));
        final longText = List.filled(30, 'Informação do usuário.').join(' ');
        await tester.enterText(
          find.byKey(const ValueKey('report-edit-field')),
          longText,
        );
        await _tap(tester, find.byKey(const ValueKey('report-edit-save')));
        expect(
          controller.sections.firstWhere((s) => s.id == section.id).text,
          longText,
        );
      }
      expect(controller.text, original);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'Card de escrita mantém ações acessíveis nos temas e no teclado pequeno',
    (tester) async {
      await _size(tester, const Size(320, 568), 2.1);
      await _mount(tester);
      final controller = tester
          .widget<PreVisitReportPage>(find.byType(PreVisitReportPage))
          .controller;
      await _organizeController(tester, controller);
      _router(tester).go(AppRoutes.accessibility);
      await tester.pumpAndSettle();
      final profile = tester
          .widget<AccessibilityPage>(find.byType(AccessibilityPage))
          .controller;
      for (final dark in [false, true]) {
        for (final contrast in [false, true]) {
          profile.setAccessibility(
            profile.accessibility.copyWith(
              appearance: dark ? AppAppearance.dark : AppAppearance.light,
              highContrast: contrast,
            ),
          );
          _router(tester).go(AppRoutes.summary);
          await tester.pumpAndSettle();
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
          await tester.pumpAndSettle();
        }
      }
    },
  );

  testWidgets(
    'Relato, abas, processamento, edição, remoção e perguntas preservam o trabalho',
    (tester) async {
      await _size(tester, const Size(390, 844));
      await _mount(tester);
      await tester.enterText(
        find.byKey(const ValueKey('report-text')),
        'Quero conversar sobre minhas anotações.',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      _router(tester).go(AppRoutes.home);
      await tester.pumpAndSettle();
      _router(tester).go(AppRoutes.report);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('report-text')))
            .controller!
            .text,
        'Quero conversar sobre minhas anotações.',
      );
      await _organize(tester);
      await _tap(tester, find.byKey(const ValueKey('edit-reason')));
      await tester.enterText(
        find.byKey(const ValueKey('report-edit-field')),
        'Meu texto revisado.',
      );
      await _tap(tester, find.byKey(const ValueKey('report-edit-save')));
      expect(find.text('Meu texto revisado.'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('edit-points')));
      await tester.enterText(
        find.byKey(const ValueKey('report-edit-field')),
        'Ponto que vou remover.',
      );
      await _tap(tester, find.byKey(const ValueKey('report-edit-save')));
      await _tap(tester, find.byKey(const ValueKey('edit-points')));
      await _tap(tester, find.text('Remover conteúdo'));
      expect(find.text('Ponto que vou remover.'), findsNothing);
      await _tap(tester, find.text('Continuar para a consulta'));
      expect(find.byType(ConsultationQuestionsPage), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('question-care')));
      await _tap(tester, find.text('Adicionar minha própria pergunta'));
      await tester.enterText(
        find.byKey(const ValueKey('report-edit-field')),
        'Como organizar minhas anotações?',
      );
      await _tap(tester, find.byKey(const ValueKey('report-edit-save')));
      _router(tester).pop();
      await tester.pumpAndSettle();
      expect(find.text('Meu texto revisado.'), findsOneWidget);
      await _tap(tester, find.text('Continuar para a consulta'));
      final controller = tester
          .widget<ConsultationQuestionsPage>(
            find.byType(ConsultationQuestionsPage),
          )
          .controller;
      expect(
        controller.questions.firstWhere((q) => q.id == 'care').selected,
        isFalse,
      );
      expect(
        controller.questions.last.text,
        'Como organizar minhas anotações?',
      );
      await _tap(tester, find.text('Continuar'));
      expect(_router(tester).state.uri.path, AppRoutes.finalReview);
      expect(controller.reviewed, isTrue);
      expect(controller.preparation.overview!.progress.percentage, 75);
      expect(
        controller.preparation.overview!.report.organizedSummary,
        contains('Meu texto revisado.'),
      );
      _router(tester).go(AppRoutes.summary);
      await tester.pumpAndSettle();
      expect(find.text('Meu texto revisado.'), findsOneWidget);
      await _tap(tester, find.byTooltip('Opções do resumo'));
      await _tap(tester, find.text('Remover conteúdo do resumo'));
      await _tap(tester, find.text('Remover'));
      expect(controller.hasContent, isFalse);
      expect(controller.text, 'Quero conversar sobre minhas anotações.');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Áudio demonstra início, relógio, pausa, retomada e transcrição editável',
    (tester) async {
      await _size(tester, const Size(390, 844));
      await _mount(tester);
      await tester.enterText(
        find.byKey(const ValueKey('report-text')),
        'Meu relato escrito.',
      );
      await _tap(tester, find.text('Gravar áudio'));
      expect(find.byType(AudioReportPage), findsOneWidget);
      await _tap(tester, find.byTooltip('Iniciar gravação simulada'));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('00:02'), findsOneWidget);
      await _tap(tester, find.byTooltip('Pausar gravação'));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('00:02'), findsOneWidget);
      await _tap(tester, find.byTooltip('Continuar gravação'));
      await _tap(tester, find.text('Concluir gravação'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('audio-transcription')),
        'Transcrição que revisei.',
      );
      await _tap(tester, find.text('Usar transcrição no relato'));
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('report-text')))
            .controller!
            .text,
        'Meu relato escrito.\n\nTranscrição que revisei.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Cancelar processamento e relato vazio permitem retomar sem perda',
    (tester) async {
      await _size(tester, const Size(390, 844));
      await _mount(tester);
      await tester.enterText(find.byKey(const ValueKey('report-text')), '');
      await _tap(tester, find.text('Salvar e continuar'));
      expect(
        find.textContaining('Escreva seu relato ou utilize'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('report-text')),
        'Texto que continua salvo.',
      );
      await tester.ensureVisible(find.text('Salvar e continuar'));
      await tester.tap(find.text('Salvar e continuar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await _tap(tester, find.text('Voltar ao relato'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(PreVisitReportPage), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('report-text')))
            .controller!
            .text,
        'Texto que continua salvo.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Relato removido não deixa o processamento aguardando sem conteúdo',
    (tester) async {
      await _size(tester, const Size(390, 844));
      await _mount(tester);
      await tester.enterText(find.byKey(const ValueKey('report-text')), '');
      _router(tester).go(AppRoutes.processing);
      await tester.pumpAndSettle();
      expect(find.byType(PreVisitReportPage), findsOneWidget);
      expect(
        find.text('Escreva seu relato antes de organizar.'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('Semântica e áreas de toque das novas telas são acessíveis', (
    tester,
  ) async {
    await _size(tester, const Size(390, 844));
    final semantics = tester.ensureSemantics();
    try {
      await _mount(tester);
      final controller = tester
          .widget<PreVisitReportPage>(find.byType(PreVisitReportPage))
          .controller;
      await _organizeController(tester, controller);
      for (final route in [
        AppRoutes.report,
        AppRoutes.audio,
        AppRoutes.summary,
        AppRoutes.questions,
        AppRoutes.finalReview,
      ]) {
        _router(tester).go(route);
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      }
      _router(tester).go(AppRoutes.questions);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byKey(const ValueKey('question-care'))),
        isSemantics(
          label: 'Existe algum cuidado que eu deva seguir?',
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(
          find.descendant(
            of: find.byKey(const ValueKey('question-care')),
            matching: find.byType(Checkbox),
          ),
        ),
        isSemantics(
          hasCheckedState: true,
          isChecked: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'Menu inferior funciona nas novas telas e cancela processamento ao sair',
    (tester) async {
      await _size(tester, const Size(320, 568));
      await _mount(tester);
      final controller = tester
          .widget<PreVisitReportPage>(find.byType(PreVisitReportPage))
          .controller;
      await _organizeController(tester, controller);
      for (final route in [
        AppRoutes.report,
        AppRoutes.audio,
        AppRoutes.summary,
        AppRoutes.questions,
        AppRoutes.finalReview,
        AppRoutes.processing,
      ]) {
        for (final destination in {
          'Início': AppRoutes.home,
          'Agenda': AppRoutes.agenda,
          'Preparo': AppRoutes.checklist,
          'Perfil': AppRoutes.profile,
        }.entries) {
          _router(tester).go(route);
          if (route == AppRoutes.processing) {
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          } else {
            await tester.pumpAndSettle();
          }
          await _tap(
            tester,
            find.descendant(
              of: find.byType(AppBottomNavigation),
              matching: find.text(destination.key),
            ),
          );
          expect(
            _router(tester).routeInformationProvider.value.uri.path,
            destination.value,
          );
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pump(const Duration(seconds: 2));
      expect(controller.processing, isFalse);
    },
  );

  testWidgets('Fonte ampliada e teclado não escondem ações da edição', (
    tester,
  ) async {
    await _size(tester, const Size(320, 568), 1.5);
    await _mount(tester);
    final controller = tester
        .widget<PreVisitReportPage>(find.byType(PreVisitReportPage))
        .controller;
    await _organizeController(tester, controller);
    _router(tester).go(AppRoutes.summary);
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('edit-reason')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(find.text('Salvar').hitTestable(), findsOneWidget);
    expect(find.text('Cancelar').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('Cancelar'));
  });

  testWidgets('Reorganização pede confirmação e preserva edições ao cancelar', (
    tester,
  ) async {
    await _size(tester, const Size(390, 844));
    await _mount(tester);
    await _organize(tester);
    final controller = tester
        .widget<AiSummaryPage>(find.byType(AiSummaryPage))
        .controller;
    controller.editSection('reason', 'Minha revisão preservada.');
    _router(tester).go(AppRoutes.report);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('report-text')),
      'Relato atualizado por mim.',
    );
    await _tap(tester, find.text('Salvar e continuar'));
    expect(find.text('Organizar o relato atualizado?'), findsOneWidget);
    await _tap(tester, find.text('Continuar editando'));
    expect(controller.sections.first.text, 'Minha revisão preservada.');
    await _tap(tester, find.text('Salvar e continuar'));
    await _tap(tester, find.text('Organizar novamente'));
    expect(controller.sections.first.text, 'Relato atualizado por mim.');
    expect(controller.summaryOutdated, isFalse);
  });

  testWidgets('Textos longos permanecem integrais durante a sessão', (
    tester,
  ) async {
    await _size(tester, const Size(320, 568));
    await _mount(tester);
    final text = List.filled(80, 'Minha anotação.').join(' ');
    await tester.enterText(find.byKey(const ValueKey('report-text')), text);
    _router(tester).go(AppRoutes.agenda);
    await tester.pumpAndSettle();
    _router(tester).go(AppRoutes.report);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('report-text')))
          .controller!
          .text,
      text,
    );
  });

  testWidgets(
    'Revisão reúne conteúdo escolhido permite editar e atualiza Home de 75 para 100',
    (tester) async {
      await _size(tester, const Size(390, 844));
      final capture = GlobalKey();
      await _mount(tester, capture: capture);
      final controller = tester
          .widget<PreVisitReportPage>(find.byType(PreVisitReportPage))
          .controller;
      final original = controller.text;
      await _organizeController(tester, controller);
      controller.editSection(
        'reason',
        'Meu resumo revisado para esta consulta.',
      );
      controller.selectQuestion('care', false);
      _router(tester).go(AppRoutes.questions);
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Continuar'));
      expect(find.byType(FinalReviewPage), findsOneWidget);
      expect(find.text('Preparar para a consulta'), findsOneWidget);
      expect(find.text('3 de 4 etapas • 75%'), findsOneWidget);
      expect(
        find.text('Meu resumo revisado para esta consulta.'),
        findsOneWidget,
      );
      expect(
        find.text('Existe algum cuidado que eu deva seguir?'),
        findsNothing,
      );
      expect(
        find.text('O que devo observar até o próximo atendimento?'),
        findsOneWidget,
      );
      expect(controller.text, original);
      await _capture(tester, capture, 'revisao-final-390');
      await _tap(tester, find.byKey(const ValueKey('review-edit-summary')));
      await _tap(tester, find.byKey(const ValueKey('edit-reason')));
      await tester.enterText(
        find.byKey(const ValueKey('report-edit-field')),
        'Resumo ajustado por mim.',
      );
      await _tap(tester, find.byKey(const ValueKey('report-edit-save')));
      _router(tester).pop();
      await tester.pumpAndSettle();
      expect(find.text('Resumo ajustado por mim.'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('review-edit-questions')));
      await _tap(tester, find.byKey(const ValueKey('question-observe')));
      await _tap(tester, find.text('Adicionar minha própria pergunta'));
      await tester.enterText(
        find.byKey(const ValueKey('report-edit-field')),
        'Minha pergunta para levar?',
      );
      await _tap(tester, find.byKey(const ValueKey('report-edit-save')));
      await _tap(tester, find.text('Continuar'));
      expect(find.byType(FinalReviewPage), findsOneWidget);
      expect(find.text('Minha pergunta para levar?'), findsOneWidget);
      expect(
        find.text('O que devo observar até o próximo atendimento?'),
        findsNothing,
      );
      expect(controller.preparation.overview!.progress.percentage, 75);
      await _tap(tester, find.text('Concluir preparação'));
      expect(find.text('Preparação concluída'), findsOneWidget);
      expect(find.text('4 de 4 etapas • 100%'), findsOneWidget);
      await _capture(tester, capture, 'preparacao-concluida-390');
      expect(controller.text, original);
      await _tap(tester, find.text('Voltar ao início'));
      expect(find.text('4 de 4 etapas'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      await _capture(tester, capture, 'home-preparacao-100-390');
      await _tap(tester, find.text('Revisão final'));
      expect(find.text('Preparação concluída'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('review-edit-summary')));
      await _tap(tester, find.byKey(const ValueKey('edit-reason')));
      await tester.enterText(
        find.byKey(const ValueKey('report-edit-field')),
        'Nova revisão após a conclusão.',
      );
      await _tap(tester, find.byKey(const ValueKey('report-edit-save')));
      _router(tester).pop();
      await tester.pumpAndSettle();
      expect(find.text('Preparar para a consulta'), findsOneWidget);
      expect(find.text('3 de 4 etapas • 75%'), findsOneWidget);
      _router(tester).go(AppRoutes.home);
      await tester.pumpAndSettle();
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('3 de 4 etapas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Revisão aberta pela Home sem resumo não inventa conteúdo', (
    tester,
  ) async {
    await _size(tester, const Size(320, 568));
    await _mount(tester);
    final controller = tester
        .widget<PreVisitReportPage>(find.byType(PreVisitReportPage))
        .controller;
    final original = controller.text;
    _router(tester).go(AppRoutes.home);
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Revisão final'));
    expect(controller.hasSummary, isFalse);
    expect(
      find.text(
        'Você ainda não tem um resumo revisado. Organize seu relato para continuar.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Nenhuma pergunta selecionada. Você pode concluir sem perguntas.',
      ),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Concluir preparação'),
    );
    expect(button.onPressed, isNull);
    await _tap(tester, find.byKey(const ValueKey('review-edit-summary')));
    expect(find.byType(PreVisitReportPage), findsOneWidget);
    expect(controller.text, original);
  });

  testWidgets(
    'Revisão permite nenhuma pergunta e mantém os dados da consulta',
    (tester) async {
      await _size(tester, const Size(390, 844));
      await _mount(tester);
      final controller = tester
          .widget<PreVisitReportPage>(find.byType(PreVisitReportPage))
          .controller;
      await _organizeController(tester, controller);
      controller.selectAll(false);
      _router(tester).go(AppRoutes.finalReview);
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('review-appointment')));
      expect(find.text('Dra. Ana Beatriz Souza'), findsOneWidget);
      expect(
        find.textContaining('9 de outubro de 2026 • 08:00'),
        findsOneWidget,
      );
      expect(find.textContaining('UBS Centro'), findsOneWidget);
      await _tap(tester, find.text('Concluir preparação'));
      expect(
        controller.preparation.overview!.report.suggestedQuestions,
        isEmpty,
      );
      expect(controller.preparation.overview!.progress.percentage, 100);
      expect(
        find.textContaining('Você decide o que compartilhar.'),
        findsWidgets,
      );
    },
  );

  for (final dimensions in [
    (const Size(320, 568), 1.5),
    (const Size(320, 568), 2.1),
    (const Size(390, 844), 1.0),
    (const Size(1366, 900), 1.0),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'Novas telas sem cortes ${dimensions.$1} escala ${dimensions.$2} escuro $dark e contraste',
        (tester) async {
          await _size(tester, dimensions.$1, dimensions.$2);
          await _mount(tester);
          final controller = tester
              .widget<PreVisitReportPage>(find.byType(PreVisitReportPage))
              .controller;
          await _organizeController(tester, controller);
          for (final contrast in [false, true]) {
            _router(tester).go(AppRoutes.accessibility);
            await tester.pumpAndSettle();
            final context = tester.element(find.byType(AppBottomNavigation));
            // Use the settings page to access the app's shared preference controller.
            final page =
                tester.widget(find.byType(AccessibilityPage))
                    as AccessibilityPage;
            page.controller.setAccessibility(
              page.controller.accessibility.copyWith(
                appearance: dark ? AppAppearance.dark : AppAppearance.light,
                highContrast: contrast,
              ),
            );
            await tester.pumpAndSettle();
            expect(context.mounted, isTrue);
            for (final route in [
              AppRoutes.report,
              AppRoutes.audio,
              AppRoutes.summary,
              AppRoutes.questions,
              AppRoutes.finalReview,
            ]) {
              _router(tester).go(route);
              await tester.pumpAndSettle();
              expect(find.byType(AppBottomNavigation), findsOneWidget);
              if (route == AppRoutes.finalReview) {
                if (!controller.preparation.finalReviewCompleted) {
                  await _tap(tester, find.text('Concluir preparação'));
                }
                expect(find.text('Preparação concluída'), findsOneWidget);
              }
              final routeContext = tester.element(
                find.byType(AppBottomNavigation),
              );
              expect(
                Theme.of(routeContext).brightness,
                dark ? Brightness.dark : Brightness.light,
              );
              expect(routeContext.appColors.highContrast, contrast);
              for (final label in ['Início', 'Agenda', 'Preparo', 'Perfil']) {
                expect(find.text(label), findsOneWidget);
              }
              await tester.drag(
                find.byType(SingleChildScrollView).first,
                const Offset(0, -1800),
              );
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: '$route / $dark / $contrast / $dimensions',
              );
            }
          }
        },
      );
    }
  }
}
