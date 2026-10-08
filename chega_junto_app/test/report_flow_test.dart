import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:chega_junto_app/app/app.dart';
import 'package:chega_junto_app/app/demo_session.dart';
import 'package:chega_junto_app/app/router/app_routes.dart';
import 'package:chega_junto_app/app/theme/app_tokens.dart';
import 'package:chega_junto_app/core/widgets/app_bottom_navigation.dart';
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

class _Auth implements AuthRepository {
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
  });
}

Future<void> _mount(
  WidgetTester tester, {
  MockProfileRepository? profile,
}) async {
  final session = DemoSession(_Auth());
  await session.signIn();
  addTearDown(session.dispose);
  await tester.pumpWidget(
    ChegaJuntoApp(
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
    ),
  );
  await tester.pumpAndSettle();
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

void main() {
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
      expect(
        _router(tester).routeInformationProvider.value.uri.path,
        AppRoutes.checklist,
      );
      expect(controller.reviewed, isTrue);
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
      await tester.runAsync(() => controller.organize());
      for (final route in [
        AppRoutes.report,
        AppRoutes.audio,
        AppRoutes.summary,
        AppRoutes.questions,
      ]) {
        _router(tester).go(route);
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      }
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
      await tester.runAsync(() => controller.organize());
      for (final route in [
        AppRoutes.report,
        AppRoutes.audio,
        AppRoutes.summary,
        AppRoutes.questions,
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
    await tester.runAsync(() => controller.organize());
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
          await tester.runAsync(() => controller.organize());
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
            ]) {
              _router(tester).go(route);
              await tester.pumpAndSettle();
              expect(find.byType(AppBottomNavigation), findsOneWidget);
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
