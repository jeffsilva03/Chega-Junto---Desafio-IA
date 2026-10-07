import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/mobile_frame.dart';
import '../core/state/preparation_controller.dart';
import '../data/mock/mock_auth_repository.dart';
import '../data/mock/mock_preparation_repository.dart';
import '../data/repositories/preparation_repository.dart';
import 'demo_session.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class ChegaJuntoApp extends StatefulWidget {
  const ChegaJuntoApp({
    super.key,
    this.session,
    this.repository,
    this.initialLocation,
  });
  final DemoSession? session;
  final PreparationRepository? repository;
  final String? initialLocation;
  @override
  State<ChegaJuntoApp> createState() => _ChegaJuntoAppState();
}

class _ChegaJuntoAppState extends State<ChegaJuntoApp> {
  late final DemoSession _session;
  late final GoRouter _router;
  late final PreparationController _preparation;
  @override
  void initState() {
    super.initState();
    _session = widget.session ?? DemoSession(MockAuthRepository());
    _preparation = PreparationController(
      widget.repository ?? MockPreparationRepository(),
    )..load();
    _router = createAppRouter(
      session: _session,
      preparation: _preparation,
      initialLocation: widget.initialLocation,
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _preparation.dispose();
    if (widget.session == null) _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Chega Junto',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: _router,
    builder: (context, child) =>
        MobileFrame(child: child ?? const SizedBox.shrink()),
  );
}
