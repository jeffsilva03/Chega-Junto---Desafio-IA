import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../core/widgets/mobile_frame.dart';
import '../core/state/preparation_controller.dart';
import '../core/state/report_controller.dart';
import '../core/state/consultation_preparation_controller.dart';
import '../data/repositories/clarification_repository.dart';
import 'theme/app_tokens.dart';
import '../core/services/ai_assistant_service.dart';
import '../core/services/audio_draft_service.dart';
import '../core/state/profile_controller.dart';
import '../core/state/speech_controller.dart';
import '../core/services/speech_engine.dart';
import '../core/widgets/app_reading_tools.dart';
import '../core/config/data_config.dart';
import '../core/network/api_client.dart';
import 'app_dependencies.dart';
import '../data/repositories/preferences_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/models/profile_preferences.dart';
import '../data/mock/mock_auth_repository.dart';
import '../data/api/api_auth_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../core/auth/auth_token_store.dart';
import 'router/app_routes.dart';
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
    this.aiAssistant,
    this.audioDraftService,
    this.dataConfig,
    this.preferencesRepository,
    this.notificationRepository,
    this.apiClient,
    this.tokenStore,
    this.authRepository,
    this.clarificationRepository,
  });
  final DemoSession? session;
  final PreparationRepository? repository;
  final String? initialLocation;
  final ProfileRepository? profileRepository;
  final SpeechEngine? speechEngine;
  final AiAssistantService? aiAssistant;
  final AudioDraftService? audioDraftService;
  final DataConfig? dataConfig;
  final PreferencesRepository? preferencesRepository;
  final NotificationRepository? notificationRepository;
  final ApiClient? apiClient;
  final AuthTokenStore? tokenStore;
  final AuthRepository? authRepository;
  final ClarificationRepository? clarificationRepository;
  @override
  State<ChegaJuntoApp> createState() => _ChegaJuntoAppState();
}

class _ChegaJuntoAppState extends State<ChegaJuntoApp> {
  late final DemoSession _session;
  late final AuthTokenStore _tokenStore;
  ApiClient? _authClient;
  @override
  void initState() {
    super.initState();
    final config = widget.dataConfig ?? DataConfig.environment();
    _tokenStore =
        widget.tokenStore ??
        widget.session?.tokenStore ??
        MemoryAuthTokenStore();
    AuthRepository repository;
    if (config.mode == DataSourceMode.api) {
      _authClient =
          widget.apiClient ??
          ApiClient(config.baseUrl, tokenStore: _tokenStore);
      repository = widget.authRepository ?? ApiAuthRepository(_authClient!);
    } else {
      repository = widget.authRepository ?? MockAuthRepository();
    }
    _session =
        widget.session ?? DemoSession(repository, tokenStore: _tokenStore);
    _authClient?.onUnauthorized = _session.expire;
    if (widget.session == null) _session.initialize();
  }

  @override
  void dispose() {
    if (widget.session == null) _session.dispose();
    if (widget.apiClient == null) _authClient?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _session,
    builder: (context, _) => _AccountApp(
      key: ValueKey(_session.epoch),
      options: widget,
      session: _session,
      tokenStore: _tokenStore,
    ),
  );
}

/// Every identity change disposes the entire product state and its HTTP client.
class _AccountApp extends StatefulWidget {
  const _AccountApp({
    super.key,
    required this.options,
    required this.session,
    required this.tokenStore,
  });
  final ChegaJuntoApp options;
  final DemoSession session;
  final AuthTokenStore tokenStore;
  @override
  State<_AccountApp> createState() => _AccountAppState();
}

class _AccountAppState extends State<_AccountApp> {
  late final DemoSession _session;
  late final GoRouter _router;
  late final PreparationController _preparation;
  late final ReportController _report;
  late final ConsultationPreparationController _conversation;
  late final ProfileController _profile;
  late final SpeechController _speech;
  late final AppDependencies _dependencies;
  @override
  void initState() {
    super.initState();
    _session = widget.session;
    final epoch = _session.epoch;
    _dependencies = AppDependencies(
      widget.options.dataConfig ?? DataConfig.environment(),
      client: widget.options.apiClient,
      tokenStore: ScopedAuthTokenStore(
        widget.tokenStore,
        () => _session.signedIn && _session.epoch == epoch,
      ),
      onUnauthorized: _session.expire,
      preparationOverride: widget.options.repository,
      preferencesOverride: widget.options.preferencesRepository,
    );
    _preparation = PreparationController(
      widget.options.repository ?? _dependencies.preparation,
      persistDraftInvalidation: _dependencies.persistDraftInvalidation,
    );
    _report = ReportController(
      _preparation,
      widget.options.aiAssistant ?? _dependencies.assistant,
      widget.options.audioDraftService ?? _dependencies.audioDraft,
      capture: widget.options.audioDraftService == null
          ? _dependencies.audioCapture
          : null,
      autosaveDelay: _dependencies.reportAutosaveDelay,
    );
    _conversation = ConsultationPreparationController(
      _report,
      widget.options.clarificationRepository ?? _dependencies.clarifications,
    );
    _profile = ProfileController(
      widget.options.profileRepository ?? _dependencies.profile,
      preferences:
          widget.options.preferencesRepository ?? _dependencies.preferences,
      notificationRepository:
          widget.options.notificationRepository ?? _dependencies.notifications,
    );
    _preparation.onChanged = _profile.reloadNotifications;
    if (_session.signedIn) {
      _preparation.load();
      _profile.load();
    }
    _speech = SpeechController(widget.options.speechEngine);
    _router = createAppRouter(
      session: _session,
      preparation: _preparation,
      profile: _profile,
      speech: _speech,
      report: _report,
      conversation: _conversation,
      initialLocation: _session.signedIn
          ? (widget.options.initialLocation == null ||
                    widget.options.initialLocation == AppRoutes.welcome ||
                    widget.options.initialLocation == AppRoutes.login ||
                    widget.options.initialLocation == AppRoutes.register
                ? AppRoutes.home
                : widget.options.initialLocation)
          : _session.epoch > 0
          ? AppRoutes.login
          : widget.options.initialLocation,
    );
    _router.routeInformationProvider.addListener(_stopReading);
  }

  String get _activePath => _router.routeInformationProvider.value.uri.path;

  void _stopReading() {
    if (_activePath != AppRoutes.report) {
      _conversation.leave();
    }
    _speech.stop();
    _report.leaveAudio();
    _report.flushPendingEdits();
  }

  @override
  void dispose() {
    _router.routeInformationProvider.removeListener(_stopReading);
    _router.dispose();
    _conversation.dispose();
    _report.dispose();
    _preparation.dispose();
    _profile.dispose();
    _speech.dispose();
    _dependencies.dispose();

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
              child: ListenableBuilder(
                listenable: _router.routeInformationProvider,
                builder: (context, _) => MobileFrame(
                  maxWidth: _activePath == AppRoutes.report
                      ? 760
                      : AppLayout.maxWidth,
                  child: AppReadingTools(
                    profile: _profile,
                    speech: _speech,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
