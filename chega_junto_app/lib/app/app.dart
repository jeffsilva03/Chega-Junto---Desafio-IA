import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../core/widgets/mobile_frame.dart';
import '../core/state/preparation_controller.dart';
import '../core/state/profile_controller.dart';
import '../core/state/speech_controller.dart';
import '../core/services/speech_engine.dart';
import '../core/widgets/app_reading_tools.dart';
import '../data/mock/mock_profile_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/models/profile_preferences.dart';
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
    this.profileRepository,
    this.speechEngine,
  });
  final DemoSession? session;
  final PreparationRepository? repository;
  final String? initialLocation;
  final ProfileRepository? profileRepository;
  final SpeechEngine? speechEngine;
  @override
  State<ChegaJuntoApp> createState() => _ChegaJuntoAppState();
}

class _ChegaJuntoAppState extends State<ChegaJuntoApp> {
  late final DemoSession _session;
  late final GoRouter _router;
  late final PreparationController _preparation;
  late final ProfileController _profile;
  late final SpeechController _speech;
  @override
  void initState() {
    super.initState();
    _session = widget.session ?? DemoSession(MockAuthRepository());
    _preparation = PreparationController(
      widget.repository ?? MockPreparationRepository(),
    )..load();
    _profile = ProfileController(
      widget.profileRepository ?? MockProfileRepository(),
    )..load();
    _speech = SpeechController(widget.speechEngine);
    _router = createAppRouter(
      session: _session,
      preparation: _preparation,
      profile: _profile,
      speech: _speech,
      initialLocation: widget.initialLocation,
    );
    _router.routeInformationProvider.addListener(_stopReading);
  }

  void _stopReading() {
    _speech.stop();
  }

  @override
  void dispose() {
    _router.routeInformationProvider.removeListener(_stopReading);
    _router.dispose();
    _preparation.dispose();
    _profile.dispose();
    _speech.dispose();
    if (widget.session == null) _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _profile,
    builder: (context, _) => MaterialApp.router(
      title: 'Chega Junto',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.create(
        highContrast: _profile.accessibility.highContrast,
        reduceMotion: _profile.accessibility.reduceMotion,
      ),
      darkTheme: AppTheme.create(
        dark: true,
        highContrast: _profile.accessibility.highContrast,
        reduceMotion: _profile.accessibility.reduceMotion,
      ),
      themeMode: switch (_profile.accessibility.appearance) {
        AppAppearance.light => ThemeMode.light,
        AppAppearance.dark => ThemeMode.dark,
        AppAppearance.system => ThemeMode.system,
      },
      themeAnimationDuration: _profile.accessibility.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: _router,
      builder: (context, child) {
        final data = MediaQuery.of(context);
        return MediaQuery(
          data: data.copyWith(
            textScaler: TextScaler.linear(
              data.textScaler.scale(1) * _profile.accessibility.textSize.factor,
            ),
            disableAnimations:
                data.disableAnimations || _profile.accessibility.reduceMotion,
          ),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: Theme.of(context).brightness == Brightness.dark
                ? SystemUiOverlayStyle.light.copyWith(
                    systemNavigationBarColor: Theme.of(
                      context,
                    ).scaffoldBackgroundColor,
                  )
                : SystemUiOverlayStyle.dark.copyWith(
                    systemNavigationBarColor: Theme.of(
                      context,
                    ).scaffoldBackgroundColor,
                  ),
            child: Listener(
              onPointerUp: (_) {
                if (_profile.accessibility.haptics) {
                  HapticFeedback.selectionClick();
                }
              },
              child: MobileFrame(
                child: AppReadingTools(
                  profile: _profile,
                  speech: _speech,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
