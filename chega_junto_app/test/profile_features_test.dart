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
import 'package:chega_junto_app/core/services/speech_engine.dart';
import 'package:chega_junto_app/core/widgets/app_bottom_navigation.dart';
import 'package:chega_junto_app/core/widgets/reference_artwork.dart';
import 'package:chega_junto_app/data/mock/mock_profile_repository.dart';
import 'package:chega_junto_app/data/repositories/auth_repository.dart';
import 'package:chega_junto_app/data/models/profile_preferences.dart';
import 'package:chega_junto_app/features/profile/presentation/pages/accessibility_page.dart';
import 'package:chega_junto_app/features/notifications/presentation/pages/notifications_page.dart';

class _Auth implements AuthRepository {
  @override
  Future<void> signInDemo() async {}
}

class _Speech implements SpeechEngine {
  final spoken = <String>[];
  bool fail = false;
  @override
  Future<void> speak(String text) async {
    if (fail) throw StateError('no-voice');
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}
}

Future<void> _prepare(
  WidgetTester tester,
  Size size, {
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.runAsync(() async {
    await ReferenceArtwork.preload();
    await (FontLoader(
      'NunitoSans',
    )..addFont(rootBundle.load('assets/fonts/NunitoSans.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
}

Future<void> _mount(
  WidgetTester tester,
  String route, {
  GlobalKey? capture,
  MockProfileRepository? repository,
  _Speech? speech,
}) async {
  final session = DemoSession(_Auth());
  await session.signIn();
  addTearDown(session.dispose);
  final app = ChegaJuntoApp(
    key: UniqueKey(),
    session: session,
    initialLocation: route,
    profileRepository: repository,
    speechEngine: speech,
  );
  await tester.pumpWidget(
    capture == null ? app : RepaintBoundary(key: capture, child: app),
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

void main() {
  testWidgets(
    'Dados pessoais edita, valida e mantém Perfil e Home consistentes',
    (tester) async {
      await _prepare(tester, const Size(390, 844));
      final repo = MockProfileRepository();
      await _mount(tester, AppRoutes.personalData, repository: repo);
      expect(find.text('Endereço'), findsOneWidget);
      expect(find.text('Contato de emergência'), findsOneWidget);
      await _tap(tester, find.text('Editar'));
      await tester.enterText(
        find.byKey(const ValueKey('personal-name')),
        'Mariana da Silva',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('personal-email')));
      await tester.enterText(
        find.byKey(const ValueKey('personal-email')),
        'email-invalido',
      );
      await _tap(tester, find.text('Salvar alterações'));
      expect(find.text('Confira o e-mail.'), findsOneWidget);
      expect((await repo.loadProfile()).fullName, 'Maria da Silva');
      await tester.ensureVisible(find.byKey(const ValueKey('personal-email')));
      await tester.enterText(
        find.byKey(const ValueKey('personal-email')),
        'mariana@example.test',
      );
      await _tap(tester, find.text('Salvar alterações'));
      expect((await repo.loadProfile()).fullName, 'Mariana da Silva');
      expect(find.text('Dados salvos nesta sessão.'), findsOneWidget);
      _router(tester).go(AppRoutes.profile);
      await tester.pumpAndSettle();
      expect(find.text('Mariana da Silva'), findsOneWidget);
      expect(find.text('mariana@example.test'), findsOneWidget);
      _router(tester).go(AppRoutes.home);
      await tester.pumpAndSettle();
      expect(find.text('Olá, Mariana'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Medicamentos e alergias adiciona, cancela, edita e salva apenas o formulário concluído',
    (tester) async {
      await _prepare(tester, const Size(390, 844));
      final repo = MockProfileRepository();
      await _mount(tester, AppRoutes.medications, repository: repo);
      await _tap(tester, find.text('Adicionar medicamento'));
      await _tap(tester, find.byKey(const ValueKey('health-item-save')));
      expect(find.text('Informe o nome.'), findsOneWidget);
      await _tap(tester, find.text('Cancelar'));
      expect((await repo.loadHealth()).medications.length, 4);
      await _tap(tester, find.text('Adicionar medicamento'));
      await tester.enterText(
        find.byKey(const ValueKey('health-item-name')),
        'Medicamento fictício',
      );
      await tester.enterText(
        find.byKey(const ValueKey('health-item-details')),
        'Informação já fornecida.',
      );
      await _tap(tester, find.byKey(const ValueKey('health-item-save')));
      expect((await repo.loadHealth()).medications.length, 4);
      expect(find.text('5 medicamentos cadastrados'), findsOneWidget);
      await _tap(tester, find.text('Salvar alterações'));
      expect((await repo.loadHealth()).medications.length, 5);
      expect(
        find.text('Medicamentos e alergias salvos nesta sessão.'),
        findsOneWidget,
      );
      await _tap(tester, find.text('Losartana'));
      await tester.enterText(
        find.byKey(const ValueKey('health-item-details')),
        'Informação revisada pelo usuário.',
      );
      await _tap(tester, find.byKey(const ValueKey('health-item-save')));
      await _tap(tester, find.text('Salvar alterações'));
      expect(
        (await repo.loadHealth()).medications.first.details,
        'Informação revisada pelo usuário.',
      );
      await _tap(tester, find.text('Editar'));
      await _tap(tester, find.byTooltip('Remover Medicamento fictício'));
      await _tap(tester, find.text('Salvar alterações'));
      expect((await repo.loadHealth()).medications.length, 4);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Histórico filtra e abre detalhes corretos e documentos de exemplo',
    (tester) async {
      await _prepare(tester, const Size(390, 844));
      await _mount(tester, AppRoutes.healthHistory);
      await _tap(tester, find.text('Exames'));
      expect(find.text('Clínica geral'), findsNothing);
      expect(find.text('Raio-X de tórax'), findsOneWidget);
      await _tap(tester, find.text('Exame de sangue (hemograma)'));
      expect(find.text('Detalhes do histórico'), findsOneWidget);
      expect(
        find.textContaining('Nenhum resultado é interpretado'),
        findsOneWidget,
      );
      _router(tester).pop();
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Todos'));
      await _tap(tester, find.text('Clínica geral'));
      expect(find.textContaining('6 de outubro de 2026'), findsOneWidget);
      await _tap(tester, find.text('Anotações do atendimento'));
      expect(find.textContaining('Exemplo fictício:'), findsOneWidget);
      await _tap(tester, find.text('Fechar'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Diagnóstico do histórico é apresentado como informação já registrada',
    (tester) async {
      await _prepare(tester, const Size(320, 568), scale: 1.5);
      await _mount(tester, AppRoutes.healthHistory);
      await _tap(tester, find.text('Diagnósticos registrados'));
      expect(find.text('Diagnóstico registrado'), findsOneWidget);
      expect(find.text('Informação histórica já registrada'), findsOneWidget);
      expect(find.text('Clínica geral'), findsNothing);
      await _tap(tester, find.text('Hipertensão arterial'));
      expect(find.text('Detalhes do histórico'), findsOneWidget);
      expect(find.text('Diagnóstico registrado'), findsOneWidget);
      expect(
        find.textContaining('O Chega Junto e a IA não produzem diagnósticos'),
        findsOneWidget,
      );
      expect(find.byType(AppBottomNavigation), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Notificações filtra, marca leitura e aplica preferências na central',
    (tester) async {
      await _prepare(tester, const Size(390, 844));
      await _mount(tester, AppRoutes.notifications);
      expect(find.text('Todas (6)'), findsOneWidget);
      await _tap(tester, find.text('Exames (2)'));
      expect(find.text('Lembrete de consulta'), findsNothing);
      await _tap(tester, find.text('Todas (6)'));
      final controller = tester
          .widget<NotificationsPage>(find.byType(NotificationsPage))
          .profile;
      await _tap(tester, find.text('Lembrete de consulta'));
      expect(controller.isRead('notification-consultation'), true);
      expect(find.text('Clínica geral'), findsWidgets);
      _router(tester).pop();
      await tester.pumpAndSettle();
      await _tap(tester, find.byTooltip('Configurações de notificações'));
      await _tap(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('notification-exams')),
          matching: find.byType(Switch),
        ),
      );
      _router(tester).pop();
      await tester.pumpAndSettle();
      expect(find.text('Exames (0)'), findsOneWidget);
      expect(find.text('Todas (4)'), findsOneWidget);
      await _tap(tester, find.byTooltip('Configurações de notificações'));
      await _tap(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('notification-active')),
          matching: find.byType(Switch),
        ),
      );
      _router(tester).pop();
      await tester.pumpAndSettle();
      expect(find.text('Todas (0)'), findsOneWidget);
      expect(find.textContaining('Avisos pausados'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Ajuda busca tópicos, explica limites e não envia mensagens', (
    tester,
  ) async {
    await _prepare(tester, const Size(390, 844));
    await _mount(tester, AppRoutes.help);
    await tester.enterText(find.byType(TextField), 'lembretes');
    await tester.pumpAndSettle();
    expect(find.text('Como configurar lembretes'), findsOneWidget);
    expect(find.text('Como acompanhar uma consulta'), findsNothing);
    await _tap(tester, find.text('Como configurar lembretes'));
    expect(find.textContaining('não dispara alarmes'), findsOneWidget);
    await _tap(tester, find.text('Fechar'));
    await _tap(tester, find.byTooltip('Limpar busca'));
    await _tap(tester, find.text('Falar com o suporte'));
    expect(find.textContaining('ainda não está disponível'), findsOneWidget);
    await _tap(tester, find.text('Fechar'));
    await _tap(tester, find.text('Perguntas frequentes (FAQ)'));
    expect(
      find.textContaining('A organização do relato é simulada'),
      findsOneWidget,
    );
    expect(
      find.textContaining('o fluxo de IA ainda não está disponível'),
      findsNothing,
    );
    await _tap(tester, find.text('Fechar'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rota desconhecida permite retornar à Home', (tester) async {
    await _prepare(tester, const Size(390, 844));
    await _mount(tester, '/rota-inexistente');
    expect(find.text('Página não encontrada'), findsOneWidget);
    expect(find.textContaining('Não encontramos esta página.'), findsOneWidget);
    await _tap(tester, find.text('Voltar ao início'));
    expect(find.text('Olá, Maria'), findsOneWidget);
    expect(find.byType(AppBottomNavigation), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Acessibilidade aplica tema, fonte e contraste globalmente e permite ler a tela',
    (tester) async {
      await _prepare(tester, const Size(390, 844));
      final speech = _Speech();
      await _mount(tester, AppRoutes.accessibility, speech: speech);
      await _tap(tester, find.text('Tema do aplicativo'));
      await _tap(tester, find.text('Escuro'));
      expect(
        Theme.of(tester.element(find.byType(AppBottomNavigation))).brightness,
        Brightness.dark,
      );
      await _tap(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('accessibility-contrast')),
          matching: find.byType(Switch),
        ),
      );
      expect(
        tester.element(find.byType(AppBottomNavigation)).appColors.highContrast,
        true,
      );
      await _tap(tester, find.text('Tamanho do texto'));
      await _tap(tester, find.text('Grande'));
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.byType(AppBottomNavigation)),
        ).scale(10),
        12,
      );
      await _tap(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('accessibility-reduceMotion')),
          matching: find.byType(Switch),
        ),
      );
      expect(
        MediaQuery.disableAnimationsOf(
          tester.element(find.byType(AppBottomNavigation)),
        ),
        true,
      );
      await _tap(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('accessibility-speech')),
          matching: find.byType(Switch),
        ),
      );
      await _tap(tester, find.text('Ouvir exemplo'));
      expect(speech.spoken.last, contains('Chega Junto'));
      _router(tester).go(AppRoutes.healthHistory);
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(AppBottomNavigation))).brightness,
        Brightness.dark,
      );
      await _tap(tester, find.bySemanticsLabel('Ouvir esta tela'));
      expect(speech.spoken.last, contains('Histórico de saúde'));
      expect(speech.spoken.last, contains('Clínica geral'));
      speech.fail = true;
      await _tap(tester, find.bySemanticsLabel('Ouvir esta tela'));
      expect(find.textContaining('voz em português instalada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  final routes = {
    AppRoutes.personalData: 'personal-data',
    AppRoutes.medications: 'medications-allergies',
    AppRoutes.healthHistory: 'health-history',
    AppRoutes.historyDetails('hist-consulta-01'): 'history-details',
    AppRoutes.notifications: 'notifications',
    AppRoutes.notificationSettings: 'notification-settings',
    AppRoutes.accessibility: 'accessibility',
    AppRoutes.help: 'help',
  };
  for (final layout in [
    (const Size(320, 568), 1.5),
    (const Size(320, 568), 2.1),
    (const Size(390, 844), 1.0),
    (const Size(1366, 900), 1.0),
  ]) {
    testWidgets('Novos destinos cabem em ${layout.$1} com fonte ${layout.$2}', (
      tester,
    ) async {
      await _prepare(tester, layout.$1, scale: layout.$2);
      final capture = GlobalKey();
      await _mount(tester, AppRoutes.profile, capture: capture);
      for (final route in routes.entries) {
        _router(tester).go(route.key);
        await tester.pumpAndSettle();
        expect(find.byType(AppBottomNavigation), findsOneWidget);
        expect(tester.takeException(), isNull, reason: route.key);
        if (layout.$1.width == 390) {
          await _capture(tester, capture, '${route.value}-390');
        }
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -2400),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Rolagem ${route.key}');
        if (layout.$1.width == 390) {
          await _capture(tester, capture, '${route.value}-bottom-390');
        }
      }
    });
  }

  testWidgets(
    'Temas claro e escuro com e sem alto contraste preservam as telas e o menu',
    (tester) async {
      await _prepare(tester, const Size(390, 844));
      final capture = GlobalKey();
      await _mount(tester, AppRoutes.accessibility, capture: capture);
      final profile = tester
          .widget<AccessibilityPage>(find.byType(AccessibilityPage))
          .controller;
      final destinations = [
        AppRoutes.home,
        AppRoutes.agenda,
        AppRoutes.details,
        AppRoutes.checklist,
        AppRoutes.attendance,
        AppRoutes.profile,
        ...routes.keys,
      ];
      for (final dark in [false, true]) {
        for (final contrast in [false, true]) {
          profile.setAccessibility(
            profile.accessibility.copyWith(
              appearance: dark ? AppAppearance.dark : AppAppearance.light,
              highContrast: contrast,
            ),
          );
          await tester.pumpAndSettle();
          for (final route in destinations) {
            _router(tester).go(route);
            await tester.pumpAndSettle();
            final nav = find.byType(AppBottomNavigation);
            final context = tester.element(nav);
            expect(tester.takeException(), isNull, reason: route);
            expect(
              Theme.of(context).brightness,
              dark ? Brightness.dark : Brightness.light,
            );
            expect(context.appColors.highContrast, contrast);
            expect(
              tester
                  .widgetList<Text>(
                    find.descendant(of: nav, matching: find.byType(Text)),
                  )
                  .map((t) => t.data),
              ['Início', 'Agenda', 'Preparo', 'Perfil'],
            );
            if (routes.containsKey(route)) {
              await _capture(
                tester,
                capture,
                '${routes[route]}-${dark ? 'dark' : 'light'}${contrast ? '-contrast' : ''}-390',
              );
            }
          }
        }
      }
    },
  );

  testWidgets('Menu inferior navega a partir de todos os novos destinos', (
    tester,
  ) async {
    await _prepare(tester, const Size(320, 568));
    await _mount(tester, AppRoutes.profile);
    for (final route in routes.keys) {
      for (final destination in {
        'Início': AppRoutes.home,
        'Agenda': AppRoutes.agenda,
        'Preparo': AppRoutes.checklist,
        'Perfil': AppRoutes.profile,
      }.entries) {
        _router(tester).go(route);
        await tester.pumpAndSettle();
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
        expect(find.byType(AppBottomNavigation), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: '$route → ${destination.key}',
        );
      }
    }
  });

  testWidgets(
    'Edição de saúde cabe com teclado e fonte ampliada no aparelho pequeno',
    (tester) async {
      await _prepare(tester, const Size(320, 568), scale: 1.5);
      await _mount(tester, AppRoutes.medications);
      await _tap(tester, find.text('Adicionar medicamento'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.text('Concluir').hitTestable(), findsOneWidget);
      expect(find.text('Cancelar').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _tap(tester, find.text('Cancelar'));
    },
  );
}
