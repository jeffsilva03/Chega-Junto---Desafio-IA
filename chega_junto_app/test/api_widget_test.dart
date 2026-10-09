import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:chega_junto_app/app/app.dart';
import 'package:chega_junto_app/app/demo_session.dart';
import 'package:chega_junto_app/app/router/app_routes.dart';
import 'package:chega_junto_app/core/config/data_config.dart';
import 'package:chega_junto_app/core/services/speech_engine.dart';
import 'package:chega_junto_app/core/widgets/app_bottom_navigation.dart';
import 'package:chega_junto_app/data/api/api_profile_repository.dart';
import 'package:chega_junto_app/data/api/api_preparation_repository.dart';
import 'package:chega_junto_app/data/api/api_notification_repository.dart';
import 'package:chega_junto_app/data/api/api_preferences_repository.dart';
import 'package:chega_junto_app/data/repositories/auth_repository.dart';
import 'support/fake_api.dart';

class _Auth extends AuthRepository {
  @override
  Future<void> signInDemo() async {}
}

class _Speech implements SpeechEngine {
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
}

void main() {
  late FakeApi api;
  setUp(() => api = FakeApi());
  tearDown(() => api.close());
  Future<void> mount(WidgetTester tester, String route) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final session = DemoSession(_Auth());
    await session.signIn();
    addTearDown(session.dispose);
    await tester.pumpWidget(
      ChegaJuntoApp(
        session: session,
        initialLocation: route,
        dataConfig: const DataConfig(
          mode: DataSourceMode.api,
          baseUrl: 'http://api.example.test',
        ),
        apiClient: api.client,
        repository: ApiPreparationRepository(api.client),
        profileRepository: ApiProfileRepository(api.client),
        preferencesRepository: ApiPreferencesRepository(api.client),
        notificationRepository: ApiNotificationRepository(api.client),
        speechEngine: _Speech(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'API mode opens real repository Profile and saves through the unchanged form',
    (tester) async {
      await mount(tester, AppRoutes.profile);
      expect(find.text('Pessoa fictícia da API'), findsOneWidget);
      expect(api.mutations, isEmpty);
      await tester.ensureVisible(find.text('Dados pessoais'));
      await tester.tap(find.text('Dados pessoais'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('personal-name')),
        'Edição fictícia via tela',
      );
      await tester.ensureVisible(find.text('Salvar alterações'));
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();
      expect(api.profile['full_name'], 'Edição fictícia via tela');
      expect(find.text('Edição fictícia via tela'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'API empty Home retains navigation and supports empty preparation',
    (tester) async {
      api.emptyOverview = true;
      await mount(tester, AppRoutes.home);
      expect(find.text('Nenhum próximo atendimento agendado.'), findsOneWidget);
      final router = GoRouter.of(
        tester.element(find.byType(AppBottomNavigation)),
      );
      router.go(AppRoutes.agenda);
      await tester.pumpAndSettle();
      expect(find.text('Agenda'), findsWidgets);
      expect(tester.takeException(), isNull);
      router.go(AppRoutes.checklist);
      await tester.pumpAndSettle();
      expect(
        find.text('Nenhum próximo atendimento para preparar.'),
        findsOneWidget,
      );
      expect(api.mutations, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('API error screen offers retry without falling back to mock', (
    tester,
  ) async {
    api.intercept = (r) async =>
        r.url.path == '/api/v1/preparation/overview' ? failure(503) : null;
    await mount(tester, AppRoutes.home);
    expect(find.textContaining('temporariamente indisponível'), findsOneWidget);
    expect(find.text('Consulta fictícia API'), findsNothing);
    api.intercept = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Unidade fictícia API'), findsOneWidget);
    expect(api.mutations, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets('uncertain reminder offers a read before another POST', (
    tester,
  ) async {
    await mount(tester, AppRoutes.agenda);
    api.intercept = (r) async {
      if (r.method == 'POST' && r.url.path == '/api/v1/reminders') {
        throw http.ClientException('Simulated disconnection');
      }
      return null;
    };
    await tester.ensureVisible(find.text('Adicionar lembrete'));
    await tester.tap(find.text('Adicionar lembrete'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('reminder-title')),
      'Lembrete fictício',
    );
    await tester.tap(find.byKey(const Key('reminder-save')));
    await tester.pumpAndSettle();
    expect(find.text('Conferir Agenda'), findsOneWidget);
    expect(api.requests.where((r) => r.method == 'POST'), hasLength(1));
    await tester.tap(find.text('Conferir Agenda'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('new-reminder-card')), findsNothing);
    expect(api.requests.where((r) => r.method == 'POST'), hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
