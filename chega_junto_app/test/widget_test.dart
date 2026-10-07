import 'dart:io';
import 'dart:ui' as ui;
import 'package:chega_junto_app/app/app.dart';
import 'package:chega_junto_app/app/demo_session.dart';
import 'package:chega_junto_app/app/router/app_routes.dart';
import 'package:chega_junto_app/core/widgets/app_bottom_navigation.dart';
import 'package:chega_junto_app/core/widgets/reference_artwork.dart';
import 'package:chega_junto_app/core/widgets/appointment_card.dart';
import 'package:chega_junto_app/data/models/appointment.dart';
import 'package:chega_junto_app/data/models/appointment_reminder.dart';
import 'package:chega_junto_app/features/attendance/presentation/widgets/attendance_option_tile.dart';
import 'package:chega_junto_app/data/mock/mock_preparation_repository.dart';
import 'package:chega_junto_app/data/repositories/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _InstantAuth implements AuthRepository {
  @override
  Future<void> signInDemo() async {}
}

Future<void> _prepare(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.runAsync(() async {
    await ReferenceArtwork.preload();
    final font = FontLoader('NunitoSans')
      ..addFont(rootBundle.load('assets/fonts/NunitoSans.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_QA')) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('.local/qa')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets('Boas-vindas, validação, login e destinos da home', (
    tester,
  ) async {
    await _prepare(tester, const Size(390, 844));
    final session = DemoSession(_InstantAuth());
    final capture = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: ChegaJuntoApp(session: session),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Começar'), findsOneWidget);
    await _capture(tester, capture, 'welcome-390');
    await tester.ensureVisible(find.text('Começar'));
    await tester.tap(find.text('Começar'));
    await tester.pumpAndSettle();
    expect(find.text('Entrar na sua conta'), findsOneWidget);
    await _capture(tester, capture, 'login-390');
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Informe um e-mail ou CPF fictício.'), findsOneWidget);
    expect(session.signedIn, false);
    await tester.enterText(
      find.byKey(const Key('login-identity')),
      'maria@example.test',
    );
    await tester.enterText(find.byKey(const Key('login-password')), 'demo');
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Olá, Maria'), findsOneWidget);
    expect(find.text('3 de 4 etapas'), findsOneWidget);
    expect(find.text('9 de out.'), findsOneWidget);
    await _capture(tester, capture, 'home-390');
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNavigation),
        matching: find.text('Preparo'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Checklist de preparo'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNavigation),
        matching: find.text('Perfil'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Configurações do perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair da demonstração'));
    await tester.pumpAndSettle();
    expect(find.text('Entrar na sua conta'), findsOneWidget);
    expect(session.signedIn, false);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets('Login Google é local e recuperação não envia e-mail', (
    tester,
  ) async {
    await _prepare(tester, const Size(390, 844));
    final session = DemoSession(_InstantAuth());
    await tester.pumpWidget(
      ChegaJuntoApp(session: session, initialLocation: AppRoutes.login),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Esqueci minha senha?'));
    await tester.tap(find.text('Esqueci minha senha?'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail fictício'),
      'maria@example.test',
    );
    await tester.tap(find.text('Ver demonstração'));
    await tester.pumpAndSettle();
    expect(find.textContaining('nenhum e-mail foi enviado'), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Entrar com Google'));
    await tester.tap(find.text('Entrar com Google'));
    await tester.pumpAndSettle();
    expect(find.text('Olá, Maria'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets('Boas-vindas e login cabem em aparelho pequeno, com teclado', (
    tester,
  ) async {
    await _prepare(tester, const Size(320, 568));
    await tester.pumpWidget(const ChegaJuntoApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Começar'));
    await tester.tap(find.text('Começar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('login-password')));
    await tester.tap(find.byKey(const Key('login-password')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('login-password')));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('login-password'))).bottom,
      lessThanOrEqualTo(368),
    );
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Entrar com Google'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('Entrar com Google')).bottom,
      lessThanOrEqualTo(568),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Consulta e checklist permanecem consistentes com a Home', (
    tester,
  ) async {
    await _prepare(tester, const Size(390, 844));
    final session = DemoSession(_InstantAuth());
    await session.signIn();
    final capture = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: ChegaJuntoApp(
          session: session,
          initialLocation: AppRoutes.details,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dra. Ana Beatriz Souza'), findsOneWidget);
    expect(find.text('9 de outubro de 2026'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('UBS Centro'), findsOneWidget);
    await _capture(tester, capture, 'details-390');
    await tester.ensureVisible(find.text('Ver checklist completo'));
    await tester.tap(find.text('Ver checklist completo'));
    await tester.pumpAndSettle();
    expect(find.text('100% concluído'), findsOneWidget);
    await _capture(tester, capture, 'checklist-390');
    await tester.ensureVisible(find.byKey(const Key('checklist-documento')));
    await tester.tap(find.byKey(const Key('checklist-documento')));
    await tester.pumpAndSettle();
    expect(find.text('50% concluído'), findsOneWidget);
    await tester.tap(find.byKey(const Key('checklist-exames')));
    await tester.pumpAndSettle();
    expect(find.text('50% concluído'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsNWidgets(2));
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    // Initial details route has no preceding page; its back action opens Home.
    expect(find.text('2 de 4 etapas'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNavigation),
        matching: find.text('Preparo'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('checklist-documento')));
    await tester.pumpAndSettle();
    expect(find.text('100% concluído'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('3 de 4 etapas'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets('Agenda filtra, busca e adiciona lembretes na sessão', (
    tester,
  ) async {
    await _prepare(tester, const Size(390, 844));
    final session = DemoSession(_InstantAuth());
    await session.signIn();
    final capture = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: ChegaJuntoApp(
          session: session,
          initialLocation: AppRoutes.agenda,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Consultas (2)'), findsOneWidget);
    expect(find.text('Exames (1)'), findsOneWidget);
    await _capture(tester, capture, 'agenda-390');
    await tester.tap(find.text('Exames (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Exame de sangue'), findsOneWidget);
    expect(find.text('Retorno'), findsNothing);
    await tester.enterText(
      find.byKey(const Key('agenda-search')),
      'inexistente',
    );
    await tester.pumpAndSettle();
    expect(find.text('Nenhum resultado para essa busca.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('agenda-search')), 'Municipal');
    await tester.pumpAndSettle();
    expect(find.text('Exame de sangue'), findsOneWidget);
    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todos (4)'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Adicionar lembrete'));
    await tester.tap(find.text('Adicionar lembrete'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('reminder-title')),
      'Separar anotações',
    );
    await tester.tap(find.byKey(const Key('reminder-save')));
    await tester.pumpAndSettle();
    expect(find.text('Lembretes (2)'), findsOneWidget);
    expect(find.text('Separar anotações'), findsOneWidget);
    await tester.ensureVisible(find.text('Hoje'));
    await tester.tap(find.text('Hoje'));
    await tester.pumpAndSettle();
    expect(
      find.text('Nenhum atendimento ou lembrete para hoje.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets(
    'Presença salva localmente, adiamento e menu em todas as etapas',
    (tester) async {
      await _prepare(tester, const Size(390, 844));
      final session = DemoSession(_InstantAuth());
      await session.signIn();
      final repository = MockPreparationRepository();
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: ChegaJuntoApp(
            session: session,
            repository: repository,
            initialLocation: AppRoutes.attendance,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppBottomNavigation), findsOneWidget);
      expect(find.text('Etapa 2 de 4'), findsOneWidget);
      expect(find.text('Dra. Ana Beatriz Souza'), findsOneWidget);
      expect(find.text('9 de outubro de 2026'), findsOneWidget);
      await _capture(tester, capture, 'attendance-390');
      await tester.ensureVisible(find.text('Ver como remarcar'));
      await tester.tap(find.text('Ver como remarcar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('não altera nem cancela'), findsOneWidget);
      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text('Orientações para avisar a unidade'),
      );
      await tester.tap(find.text('Orientações para avisar a unidade'));
      await tester.pumpAndSettle();
      expect(find.textContaining('nenhum aviso é enviado'), findsOneWidget);
      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('attendance-unable')));
      await tester.tap(find.byKey(const Key('attendance-unable')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Responder depois'));
      await tester.tap(find.text('Responder depois'));
      await tester.pumpAndSettle();
      expect(find.text('3 de 4 etapas'), findsOneWidget);
      expect(
        (await repository.loadOverview()).nextAppointment.confirmationStatus,
        ConfirmationStatus.confirmed,
      );

      for (final status in [
        ConfirmationStatus.unable,
        ConfirmationStatus.undecided,
        ConfirmationStatus.confirmed,
      ]) {
        await tester.ensureVisible(find.text('Confirmação de presença'));
        await tester.tap(find.text('Confirmação de presença'));
        await tester.pumpAndSettle();
        final option = find.byKey(Key('attendance-${status.name}'));
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('attendance-save')));
        await tester.tap(find.byKey(const Key('attendance-save')));
        await tester.pumpAndSettle();
        expect(find.text('Resposta salva'), findsOneWidget);
        expect(
          find.textContaining('Nenhuma informação foi enviada'),
          findsOneWidget,
        );
        await tester.tap(find.text('Ver minha preparação'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            status == ConfirmationStatus.confirmed
                ? '3 de 4 etapas'
                : '2 de 4 etapas',
          ),
          findsOneWidget,
        );
      }

      await tester.tap(
        find.descendant(
          of: find.byType(AppBottomNavigation),
          matching: find.text('Agenda'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppointmentCard));
      await tester.pumpAndSettle();
      expect(find.byType(AppBottomNavigation), findsOneWidget);
      expect(find.text('Confirmada'), findsOneWidget);
      await tester.ensureVisible(find.text('Confirmar presença'));
      await tester.tap(find.text('Confirmar presença'));
      await tester.pumpAndSettle();
      final selected = tester
          .widgetList<AttendanceOptionTile>(find.byType(AttendanceOptionTile))
          .where((tile) => tile.selected)
          .single;
      expect(selected.status, ConfirmationStatus.confirmed);
      await tester.tap(
        find.descendant(
          of: find.byType(AppBottomNavigation),
          matching: find.text('Preparo'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Checklist de preparo'), findsOneWidget);
      expect(find.byType(AppBottomNavigation), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets('Perfil reproduz grupos e aguarda protótipos dos destinos', (
    tester,
  ) async {
    await _prepare(tester, const Size(390, 844));
    final session = DemoSession(_InstantAuth());
    await session.signIn();
    final capture = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: ChegaJuntoApp(
          session: session,
          initialLocation: AppRoutes.profile,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Maria da Silva'), findsOneWidget);
    expect(find.text('maria@example.test'), findsOneWidget);
    expect(find.text('Cadastro atualizado'), findsOneWidget);
    expect(find.text('700 1234 5678 9012'), findsOneWidget);
    expect(find.text('UBS Centro'), findsOneWidget);
    expect(find.byType(AppBottomNavigation), findsOneWidget);
    await _capture(tester, capture, 'profile-390');
    expect(find.text('Endereço'), findsNothing);
    expect(find.text('Contato de emergência'), findsNothing);
    expect(find.text('Medicamentos e alergias'), findsOneWidget);
    expect(find.text('Histórico'), findsOneWidget);
    for (final title in [
      'Dados pessoais',
      'Medicamentos e alergias',
      'Acessibilidade',
    ]) {
      await tester.ensureVisible(find.text(title));
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(
        find.text('$title ainda não está disponível nesta versão.'),
        findsOneWidget,
      );
      expect(find.text('Maria da Silva'), findsOneWidget);
    }
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();
    await _capture(tester, capture, 'profile-bottom-390');
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNavigation),
        matching: find.text('Início'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Olá, Maria'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets(
    'Novo lembrete usa três horários relativos e cancelar não grava',
    (tester) async {
      await _prepare(tester, const Size(390, 844));
      final session = DemoSession(_InstantAuth());
      await session.signIn();
      final repository = MockPreparationRepository();
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: ChegaJuntoApp(
            session: session,
            repository: repository,
            initialLocation: AppRoutes.agenda,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final timing in ReminderTiming.values) {
        final before = (await repository.loadReminders()).length;
        await Scrollable.ensureVisible(
          tester.element(find.text('Adicionar lembrete')),
          alignment: .9,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Adicionar lembrete'));
        await tester.pumpAndSettle();
        expect(find.text('Novo lembrete'), findsOneWidget);
        expect(find.text('Quando lembrar?'), findsOneWidget);
        if (timing == ReminderTiming.dayBefore) {
          await _capture(tester, capture, 'new-reminder-390');
        }
        await tester.enterText(
          find.byKey(const Key('reminder-title')),
          'Anotações ${timing.label}',
        );
        await tester.tap(find.byKey(Key('reminder-timing-${timing.name}')));
        await tester.ensureVisible(find.byKey(const Key('reminder-save')));
        await tester.tap(find.byKey(const Key('reminder-save')));
        await tester.pumpAndSettle();
        final reminders = await repository.loadReminders();
        expect(reminders.length, before + 1);
        expect(
          reminders.last.dateTime,
          timing.dateFor(DateTime(2026, 10, 9, 8)),
        );
        expect(reminders.last.appointmentId, 'consulta-demo-01');
        expect(find.text('Lembretes (${before + 1})'), findsOneWidget);
      }
      final beforeCancel = (await repository.loadReminders()).length;
      await tester.ensureVisible(find.text('Adicionar lembrete'));
      await tester.tap(find.text('Adicionar lembrete'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Limpar título'));
      await tester.tap(find.byKey(const Key('reminder-save')));
      await tester.pumpAndSettle();
      expect(find.text('Escreva seu lembrete.'), findsOneWidget);
      await tester.ensureVisible(find.text('Cancelar'));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect((await repository.loadReminders()).length, beforeCancel);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  for (final size in [const Size(320, 568), const Size(1366, 900)]) {
    testWidgets('Card de lembrete cabe com teclado em $size', (tester) async {
      await _prepare(tester, size);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final session = DemoSession(_InstantAuth());
      await session.signIn();
      final keyboardCapture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: keyboardCapture,
          child: ChegaJuntoApp(
            session: session,
            initialLocation: AppRoutes.agenda,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Adicionar lembrete'));
      await tester.tap(find.text('Adicionar lembrete'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('reminder-title')));
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('reminder-title')));
      await tester.enterText(
        find.byKey(const Key('reminder-title')),
        'Anotações',
      );
      await tester.ensureVisible(find.byKey(const Key('reminder-save')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('reminder-save')).hitTestable(),
        findsOneWidget,
      );
      await _capture(
        tester,
        keyboardCapture,
        'reminder-keyboard-${size.width.toInt()}',
      );
      expect(
        tester.getRect(find.byKey(const Key('reminder-save'))).bottom,
        lessThanOrEqualTo(size.height - 200),
      );
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    });
  }

  testWidgets('Status de presença cabem com fonte ampliada em tela pequena', (
    tester,
  ) async {
    await _prepare(tester, const Size(320, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final session = DemoSession(_InstantAuth());
    await session.signIn();
    for (final status in ConfirmationStatus.values) {
      final repository = MockPreparationRepository();
      await repository.setAttendance('consulta-demo-01', status);
      for (final route in [
        AppRoutes.home,
        AppRoutes.agenda,
        AppRoutes.details,
        AppRoutes.attendance,
      ]) {
        await tester.pumpWidget(
          ChegaJuntoApp(
            key: UniqueKey(),
            session: session,
            repository: repository,
            initialLocation: route,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${status.name} em $route',
        );
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -2000),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Rolagem: ${status.name} em $route',
        );
        await tester.pumpWidget(const SizedBox());
      }
    }
    session.dispose();
  });

  for (final layout in [
    (const Size(320, 640), 1.0),
    (const Size(390, 844), 1.5),
    (const Size(1366, 900), 1.0),
  ]) {
    testWidgets('Telas sem overflow em ${layout.$1}, fonte ${layout.$2}', (
      tester,
    ) async {
      await _prepare(tester, layout.$1);
      tester.platformDispatcher.textScaleFactorTestValue = layout.$2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final route in [
        AppRoutes.welcome,
        AppRoutes.login,
        AppRoutes.home,
        AppRoutes.agenda,
        AppRoutes.details,
        AppRoutes.checklist,
        AppRoutes.attendance,
        AppRoutes.profile,
      ]) {
        final session = DemoSession(_InstantAuth());
        if (route != AppRoutes.welcome && route != AppRoutes.login) {
          await session.signIn();
        }
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ChegaJuntoApp(
              key: UniqueKey(),
              session: session,
              initialLocation: route,
              repository: MockPreparationRepository(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
        if (route != AppRoutes.welcome && route != AppRoutes.login) {
          expect(
            find.byType(AppBottomNavigation),
            findsOneWidget,
            reason: route,
          );
        }
        final scroll = find.byType(SingleChildScrollView);
        await tester.drag(scroll.first, const Offset(0, -1400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Rolagem em $route');
        if (route == AppRoutes.attendance) {
          expect(find.text('Responder depois').hitTestable(), findsOneWidget);
          await _capture(
            tester,
            key,
            'attendance-bottom-${layout.$1.width.toInt()}-${layout.$2}',
          );
        }
        if (route == AppRoutes.home) {
          expect(find.text('Organize seus exames e anotações'), findsOneWidget);
          await _capture(
            tester,
            key,
            'home-bottom-${layout.$1.width.toInt()}-${layout.$2}',
          );
        }
        await tester.pumpWidget(const SizedBox());
        session.dispose();
      }
    });
  }

  testWidgets('Rota privada exige sessão demonstrativa', (tester) async {
    await _prepare(tester, const Size(390, 844));
    await tester.pumpWidget(
      const ChegaJuntoApp(initialLocation: AppRoutes.home),
    );
    await tester.pumpAndSettle();
    expect(find.text('Entrar na sua conta'), findsOneWidget);
  });
}
