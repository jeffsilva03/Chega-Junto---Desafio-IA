import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:go_router/go_router.dart';
import 'package:chega_junto_app/app/app.dart';
import 'package:chega_junto_app/app/demo_session.dart';
import 'package:chega_junto_app/app/router/app_routes.dart';
import 'package:chega_junto_app/core/auth/auth_token_store.dart';
import 'package:chega_junto_app/core/config/data_config.dart';
import 'package:chega_junto_app/core/network/api_client.dart';
import 'package:chega_junto_app/core/network/api_exception.dart';
import 'package:chega_junto_app/core/state/report_controller.dart';
import 'package:chega_junto_app/core/services/speech_engine.dart';
import 'package:chega_junto_app/data/api/api_auth_repository.dart';
import 'package:chega_junto_app/data/api/api_profile_repository.dart';
import 'package:chega_junto_app/features/home/presentation/pages/home_page.dart';
import 'package:chega_junto_app/features/auth/presentation/pages/login_page.dart';
import 'package:chega_junto_app/features/auth/presentation/pages/registration_page.dart';
import 'package:chega_junto_app/features/pre_visit_report/presentation/pages/consultation_preparation_page.dart';
import 'support/fake_api.dart';

class _Speech implements SpeechEngine {
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
}

/// Tokens here are opaque HTTP fixtures, never signed tokens or real credentials.
class AuthApi {
  final store = MemoryAuthTokenStore();
  late final FakeApi api = FakeApi(tokenStore: store);
  late final repo = ApiAuthRepository(api.client);
  late final session = DemoSession(repo, tokenStore: store);
  final calls = <http.Request>[];
  Completer<void>? gate;
  int? failure;
  bool expire = false;
  String identity = 'a';
  AuthApi() {
    api.intercept = handle;
  }
  Json user(String key) => {
    'id': key == 'a' ? largeId : '2',
    'full_name': 'Pessoa fictícia $key',
    'email': '$key@example.test',
  };
  Future<http.Response?> handle(http.Request r) async {
    calls.add(r);
    if (r.url.path.startsWith('/api/v1/auth/')) {
      if (r.method == 'POST') {
        await gate?.future;
        if (failure != null) {
          return response({
            'error': {
              'code': failure == 409
                  ? 'email_already_registered'
                  : 'invalid_credentials',
              'message': 'Private payload must not be shown',
            },
          }, failure!);
        }
        final body = jsonDecode(r.body) as Json;
        identity = (body['email'] as String).startsWith('b') ? 'b' : 'a';
        if (identity == 'b') {
          api.profile = {
            for (final key in profileFixture().keys) key: null,
            ...user('b'),
            'created_at': stamp,
            'updated_at': stamp,
          };
          api.emptyOverview = true;
          api.health = {'medications': [], 'allergies': []};
          api.accessibility = accessibilityFixture();
          api.preferences = preferencesFixture();
          api.reminders.clear();
        }
        return response({
          'access_token': 'opaque-fixture-$identity',
          'token_type': 'bearer',
          'user': user(identity),
        });
      }
      if (r.headers['Authorization'] == 'Bearer opaque-fixture-$identity') {
        return response(user(identity));
      }
    }
    if (expire ||
        r.headers['Authorization'] != 'Bearer opaque-fixture-$identity') {
      return response({
        'error': {'code': 'invalid_token'},
      }, 401);
    }
    if (identity == 'b' && r.url.path == '/api/v1/me/notifications') {
      return response({...page([]), 'unread_count': 0});
    }
    if (identity == 'b' &&
        (r.url.path == '/api/v1/appointments' ||
            r.url.path == '/api/v1/me/health-records')) {
      return response(page([]));
    }
    return null;
  }

  void close() {
    session.dispose();
    api.close();
  }
}

void main() {
  late AuthApi f;
  setUp(() => f = AuthApi());
  tearDown(() => f.close());
  Future<void> mount(
    WidgetTester tester, {
    String route = AppRoutes.login,
    double scale = 1,
    Size size = const Size(390, 844),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ChegaJuntoApp(
        session: f.session,
        tokenStore: f.store,
        apiClient: f.api.client,
        dataConfig: const DataConfig(
          mode: DataSourceMode.api,
          baseUrl: 'http://api.example.test',
        ),
        initialLocation: route,
        speechEngine: _Speech(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(
    WidgetTester t, {
    bool register = false,
    String account = 'a',
    String? confirmation,
  }) async {
    if (register) {
      await t.enterText(
        find.byKey(const Key('register-name')),
        'Pessoa fictícia',
      );
    }
    await t.enterText(
      find.byKey(Key(register ? 'register-email' : 'login-identity')),
      '$account@example.test',
    );
    await t.enterText(
      find.byKey(Key(register ? 'register-password' : 'login-password')),
      'ficticio-para-teste',
    );
    if (register) {
      await t.enterText(
        find.byKey(const Key('register-confirmation')),
        confirmation ?? 'ficticio-para-teste',
      );
    }
  }

  Future<void> submit(WidgetTester t, {bool register = false}) async {
    final button = find.byKey(
      Key(register ? 'register-submit' : 'login-submit'),
    );
    await t.ensureVisible(button);
    await t.tap(button);
    await t.pumpAndSettle();
  }

  test(
    'register/login payloads, string BIGINT, bearer me and public calls',
    () async {
      final registered = await f.repo.register(
        ' Pessoa fictícia ',
        ' A@EXAMPLE.TEST ',
        'ficticio-para-teste',
      );
      expect(registered.user.id, largeId);
      expect(registered.accessToken, isNotNull);
      expect(jsonDecode(f.calls.single.body), {
        'full_name': 'Pessoa fictícia',
        'email': 'a@example.test',
        'password': 'ficticio-para-teste',
      });
      expect(f.calls.single.headers.containsKey('Authorization'), false);
      await f.store.write(registered.accessToken!);
      expect((await f.repo.me()).email, 'a@example.test');
      expect(f.calls.last.headers['Authorization'], 'Bearer opaque-fixture-a');
      await f.repo.login(' A@EXAMPLE.TEST ', 'ficticio-para-teste');
      expect(jsonDecode(f.calls.last.body), {
        'email': 'a@example.test',
        'password': 'ficticio-para-teste',
      });
      expect(f.calls.last.headers.containsKey('Authorization'), false);
    },
  );

  for (final (status, type) in <(int, Type)>[
    (401, UnauthorizedException),
    (409, EmailAlreadyRegisteredException),
    (422, ValidationException),
    (503, DependencyUnavailableException),
  ]) {
    test('auth error $status is typed and session stays empty', () async {
      f.failure = status;
      await expectLater(
        f.session.register('Nome', 'a@example.test', 'ficticio-para-teste'),
        throwsA(predicate((e) => e.runtimeType == type)),
      );
      expect(f.session.signedIn, false);
      expect(f.session.busy, false);
      expect(await f.store.read(), isNull);
      expect(f.session.user, isNull);
    });
  }
  test('network failure remains human and never persists token', () async {
    final client = ApiClient(
      'http://api.example.test',
      transport: MockClient(
        (_) => throw http.ClientException('private technical text'),
      ),
    );
    addTearDown(client.close);
    await expectLater(
      ApiAuthRepository(client).login('a@example.test', 'ficticio-para-teste'),
      throwsA(isA<NetworkException>()),
    );
  });

  test('password boundaries and normalization do not trim passwords', () {
    expect(f.repo.validateLoginPassword('short'), isNotNull);
    expect(f.repo.validateLoginPassword('x' * 129), isNotNull);
    expect(f.repo.validateLoginPassword('x' * 8), isNull);
    expect(f.repo.validateLoginPassword('x' * 128), isNull);
  });
  test(
    'session initializing restores identity via me, logout clears memory',
    () async {
      await f.store.write('opaque-fixture-a');
      final pending = f.session.initialize();
      expect(f.session.initializing, true);
      await pending;
      expect(f.session.signedIn, true);
      expect(f.session.user!.id, largeId);
      await f.session.signOut();
      expect(f.session.status, SessionStatus.unauthenticated);
      expect(f.session.user, isNull);
      expect(await f.store.read(), isNull);
      expect(await MemoryAuthTokenStore().read(), isNull);
    },
  );
  test('restore invalid token clears it and never selects demo', () async {
    await f.store.write('expired-opaque-fixture');
    await f.session.initialize();
    expect(f.session.signedIn, false);
    expect(await f.store.read(), isNull);
    expect(f.session.message, contains('expirou'));
  });
  test(
    'scoped token refuses subsequent account and stale 401 does not expire it',
    () async {
      var epoch = 1;
      await f.store.write('opaque-fixture-a');
      final gate = Completer<http.Response>();
      var expired = 0;
      final client = ApiClient(
        'http://api.example.test',
        tokenStore: ScopedAuthTokenStore(f.store, () => epoch == 1),
        onUnauthorized: () async {
          expired++;
        },
        transport: MockClient((_) => gate.future),
      );
      addTearDown(client.close);
      final pending = client.request('GET', '/api/v1/me/profile');
      final expectation = expectLater(
        pending,
        throwsA(isA<UnauthorizedException>()),
      );
      await Future<void>.delayed(Duration.zero);
      epoch = 2;
      await f.store.write('opaque-fixture-b');
      gate.complete(
        response({
          'error': {'code': 'invalid_token'},
        }, 401),
      );
      await expectation;
      expect(expired, 0);
      expect(await f.store.read(), 'opaque-fixture-b');
    },
  );
  test('logout during login ignores its late response', () async {
    f.gate = Completer<void>();
    final pending = f.session.login('a@example.test', 'ficticio-para-teste');
    expect(f.session.busy, true);
    await f.session.signOut();
    f.gate!.complete();
    await pending;
    expect(f.session.signedIn, false);
    expect(await f.store.read(), isNull);
  });
  test('late auth me 401 from A cannot clear a subsequent login B', () async {
    final entered = Completer<void>();
    final delayed = Completer<http.Response>();
    final original = f.api.intercept!;
    f.api.intercept = (request) async {
      if (request.url.path == '/api/v1/auth/me' &&
          request.headers['Authorization'] == 'Bearer opaque-fixture-a') {
        entered.complete();
        return delayed.future;
      }
      return original(request);
    };
    final first = f.session.login('a@example.test', 'ficticio-para-teste');
    await entered.future;
    await f.session.signOut();
    await f.session.login('b@example.test', 'ficticio-para-teste');
    delayed.complete(
      response({
        'error': {'code': 'invalid_token'},
      }, 401),
    );
    await first;
    expect(f.session.signedIn, true);
    expect(f.session.user!.email, 'b@example.test');
    expect(await f.store.read(), 'opaque-fixture-b');
  });
  test(
    'incomplete profile round trips without invented values or prohibited fields',
    () async {
      await f.session.login('b@example.test', 'ficticio-para-teste');
      final repository = ApiProfileRepository(f.api.client);
      final p = await repository.loadProfile();
      expect(p.phone, '');
      expect(p.birthDate, '');
      expect(p.city, '');
      expect(p.susCardNumber, '');
      final saved = await repository.saveProfile(p);
      expect(saved.email, 'b@example.test');
      final body = jsonDecode(f.calls.last.body) as Json;
      expect(body['birth_date'], isNull);
      expect(body['cpf'], isNull);
      expect(body['city'], isNull);
      for (final name in [
        'id',
        'user_id',
        'sus_card_number',
        'password',
        'password_hash',
        'created_at',
        'updated_at',
      ]) {
        expect(body.containsKey(name), false);
      }
    },
  );

  testWidgets(
    'login validates, blocks Google and explains unavailable recovery',
    (t) async {
      await mount(t);
      await submit(t);
      expect(f.calls, isEmpty);
      expect(find.text('Informe um e-mail válido.'), findsOneWidget);
      final google = t.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Entrar com Google'),
      );
      expect(google.onPressed, isNull);
      await t.ensureVisible(find.text('Esqueci minha senha?'));
      await t.tap(find.text('Esqueci minha senha?'));
      await t.pumpAndSettle();
      expect(
        find.text(
          'A recuperação de senha ainda não está disponível nesta versão.',
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets('login links to real registration and back to Login', (t) async {
    await mount(t);
    await t.ensureVisible(find.text('Criar conta'));
    await t.tap(find.text('Criar conta'));
    await t.pumpAndSettle();
    expect(find.byType(RegistrationPage), findsOneWidget);
    await t.ensureVisible(find.text('Entrar'));
    await t.tap(find.text('Entrar'));
    await t.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });
  for (final status in [401, 503]) {
    testWidgets('login $status stays unauthenticated and can retry', (t) async {
      f.failure = status;
      await mount(t);
      await fill(t);
      await submit(t);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(f.session.signedIn, false);
      expect(find.textContaining('Private payload'), findsNothing);
      expect(
        find.text(
          status == 401
              ? 'E-mail ou senha inválidos.'
              : 'O serviço está temporariamente indisponível. Tente novamente em instantes.',
        ),
        findsOneWidget,
      );
      f.failure = null;
      await submit(t);
      expect(find.byType(HomePage), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('registration validates confirmation locally without POST', (
    t,
  ) async {
    await mount(t, route: AppRoutes.register);
    await fill(t, register: true, confirmation: 'different-fictional');
    await submit(t, register: true);
    expect(find.text('As senhas não coincidem.'), findsOneWidget);
    expect(f.calls, isEmpty);
  });
  for (final register in [false, true]) {
    testWidgets(
      '${register ? 'register' : 'login'} loading prevents duplicate submission and opens Home',
      (t) async {
        f.gate = Completer<void>();
        await mount(t, route: register ? AppRoutes.register : AppRoutes.login);
        await fill(t, register: register);
        final button = find.byKey(
          Key(register ? 'register-submit' : 'login-submit'),
        );
        await t.ensureVisible(button);
        await t.tap(button);
        await t.pump(const Duration(milliseconds: 100));
        expect(
          find.text(register ? 'Criando conta...' : 'Entrando...'),
          findsOneWidget,
        );
        await t.tap(button);
        await t.pump(const Duration(milliseconds: 100));
        expect(f.calls.where((r) => r.method == 'POST').length, 1);
        f.gate!.complete();
        await t.pumpAndSettle();
        expect(find.byType(HomePage), findsOneWidget);
        expect(await f.store.read(), isNotNull);
        expect(f.calls.any((r) => r.url.path == '/api/v1/auth/me'), true);
        expect(t.takeException(), isNull);
      },
    );
  }
  for (final status in [401, 409, 422, 503]) {
    testWidgets('register $status shows safe error and permits retry', (
      t,
    ) async {
      f.failure = status;
      await mount(t, route: AppRoutes.register);
      await fill(t, register: true);
      await submit(t, register: true);
      expect(find.textContaining('Private payload'), findsNothing);
      expect(find.byType(RegistrationPage), findsOneWidget);
      expect(f.session.signedIn, false);
      f.failure = null;
      await submit(t, register: true);
      expect(find.byType(HomePage), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
    '401 clears authenticated product state and redirects once to Login',
    (t) async {
      await f.session.login('a@example.test', 'ficticio-para-teste');
      await mount(t, route: AppRoutes.home);
      final home = t.widget<HomePage>(find.byType(HomePage));
      f.expire = true;
      await home.profile.reloadNotifications();
      await t.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Sua sessão expirou. Entre novamente.'), findsOneWidget);
      expect(home.profile.profile, isNull);
      expect(home.controller.overview, isNull);
      expect(await f.store.read(), isNull);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'A logout B recreates controllers, discards drafts/caches/preferences and supports empty account',
    (t) async {
      await f.session.login('a@example.test', 'ficticio-para-teste');
      await mount(t, route: AppRoutes.home);
      final homeA = t.widget<HomePage>(find.byType(HomePage));
      final router = GoRouter.of(t.element(find.byType(HomePage)));
      router.go(AppRoutes.report);
      await t.pumpAndSettle();
      final page = t.widget<ConsultationPreparationPage>(
        find.byType(ConsultationPreparationPage),
      );
      final ReportController reportA = page.controller;
      reportA.setText('Texto privado fictício da conta A');
      await f.session.signOut();
      await t.pumpAndSettle();
      expect(reportA.text, '');
      expect(reportA.questions, isEmpty);
      expect(reportA.preservedDraft, isNull);
      expect(homeA.profile.profile, isNull);
      expect(homeA.profile.health, isNull);
      expect(homeA.profile.inbox.unreadCount, 0);
      expect(homeA.controller.overview, isNull);
      expect(homeA.controller.appointments, isEmpty);
      expect(homeA.controller.reminders, isEmpty);
      await fill(t, account: 'b');
      await submit(t);
      final homeB = t.widget<HomePage>(find.byType(HomePage));
      expect(identical(homeA.profile, homeB.profile), false);
      expect(identical(homeA.controller, homeB.controller), false);
      expect(homeB.profile.profile!.email, 'b@example.test');
      expect(homeB.profile.health!.medications, isEmpty);
      expect(find.text('Nenhum próximo atendimento agendado.'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Notificações, nenhuma não lida'),
        findsOneWidget,
      );
      expect(find.textContaining('conta A'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  for (final (size, scale, keyboard) in [
    (const Size(320, 568), 1.0, false),
    (const Size(320, 568), 1.5, true),
    (const Size(390, 844), 2.0, false),
    (const Size(1366, 900), 1.0, false),
  ]) {
    testWidgets('registration fits $size scale $scale keyboard $keyboard', (
      t,
    ) async {
      await mount(t, route: AppRoutes.register, size: size, scale: scale);
      if (keyboard) {
        t.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(t.view.resetViewInsets);
        await t.pumpAndSettle();
      }
      await fill(t, register: true);
      await t.ensureVisible(find.byKey(const Key('register-submit')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
}
