import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_router/go_router.dart';
import 'package:chega_junto_app/app/app.dart';
import 'package:chega_junto_app/app/demo_session.dart';
import 'package:chega_junto_app/app/router/app_routes.dart';
import 'package:chega_junto_app/core/widgets/app_bottom_navigation.dart';
import 'package:chega_junto_app/data/mock/mock_ai_assistant_service.dart';
import 'package:chega_junto_app/data/mock/mock_auth_repository.dart';
import 'package:chega_junto_app/features/profile/presentation/pages/accessibility_page.dart';
import 'package:chega_junto_app/data/models/profile_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Fluxo completo no Android com capturas reais', (tester) async {
    final session = DemoSession(MockAuthRepository());
    await session.signIn();
    await tester.pumpWidget(
      ChegaJuntoApp(
        session: session,
        initialLocation: AppRoutes.report,
        aiAssistant: const MockAiAssistantService(delay: Duration(seconds: 5)),
      ),
    );
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    Future<void> shot(String name) async {
      ScaffoldMessenger.of(
        tester.element(find.byType(AppBottomNavigation)),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await binding.takeScreenshot(name);
    }

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await tester.enterText(
      find.byKey(const ValueKey('report-text')),
      'Quero conversar sobre como tenho dormido.\n\nGostaria de lembrar das minhas dúvidas durante a consulta.',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 1600),
    );
    await shot('01-relato-android');
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -1600),
    );
    await shot('01b-relato-acoes-android');
    await tap(find.text('Gravar áudio'));
    await tap(find.byTooltip('Iniciar gravação simulada'));
    await tester.pump(const Duration(seconds: 2));
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 1600),
    );
    await shot('02-audio-android');
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -1600),
    );
    await shot('02b-audio-acoes-android');
    await tap(find.byTooltip('Pausar gravação'));
    await tap(find.byTooltip('Continuar gravação'));
    await tap(find.text('Concluir gravação'));
    await tap(find.text('Usar transcrição no relato'));
    ScaffoldMessenger.of(
      tester.element(find.byType(AppBottomNavigation)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Salvar e continuar'));
    await tester.tap(find.text('Salvar e continuar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    // Do not settle an indeterminate progress indicator while capturing it.
    await binding.takeScreenshot('03-processamento-android');
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Resumo gerado pela IA'), findsOneWidget);
    await shot('04-resumo-android');
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -1600),
    );
    await shot('04b-resumo-acoes-android');
    await tap(find.byKey(const ValueKey('edit-reason')));
    await tester.enterText(
      find.byKey(const ValueKey('report-edit-field')),
      'Quero conversar sobre como tenho dormido e revisar minhas anotações.',
    );
    await tap(find.byKey(const ValueKey('report-edit-save')));
    await tap(find.text('Continuar para a consulta'));
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 1600),
    );
    await shot('05-perguntas-android');
    await tap(find.byKey(const ValueKey('question-care')));
    await tap(find.text('Continuar'));
    final router = GoRouter.of(
      tester.element(find.byType(AppBottomNavigation)),
    );
    expect(router.state.uri.path, AppRoutes.finalReview);
    await shot('07-revisao-final-android');
    await tap(find.text('Concluir preparação'));
    expect(find.text('Preparação concluída'), findsOneWidget);
    expect(find.text('4 de 4 etapas • 100%'), findsOneWidget);
    await shot('08-preparacao-concluida-android');
    router.go(AppRoutes.accessibility);
    await tester.pumpAndSettle();
    final profile = tester
        .widget<AccessibilityPage>(find.byType(AccessibilityPage))
        .controller;
    profile.setAccessibility(
      profile.accessibility.copyWith(
        appearance: AppAppearance.dark,
        highContrast: true,
      ),
    );
    await tester.pumpAndSettle();
    router.go(AppRoutes.summary);
    await shot('06-resumo-escuro-contraste-android');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
}
