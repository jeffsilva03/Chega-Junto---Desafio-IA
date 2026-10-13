import '../core/config/data_config.dart';
import '../core/network/api_client.dart';
import '../core/auth/auth_token_store.dart';
import '../data/api/api_preparation_repository.dart';
import '../data/api/api_profile_repository.dart';
import '../data/api/api_notification_repository.dart';
import '../data/api/api_preferences_repository.dart';
import '../data/mock/mock_preparation_repository.dart';
import '../data/mock/mock_profile_repository.dart';
import '../data/mock/mock_notification_repository.dart';
import '../data/mock/mock_preferences_repository.dart';
import '../data/repositories/preparation_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/preferences_repository.dart';
import '../core/services/ai_assistant_service.dart';
import '../core/services/audio_draft_service.dart';
import '../core/services/audio_capture_service.dart';
import '../core/services/record_audio_capture_service.dart';
import '../data/api/api_ai_assistant_service.dart';
import '../data/api/api_audio_draft_service.dart';
import '../data/mock/mock_ai_assistant_service.dart';
import '../data/mock/mock_audio_draft_service.dart';

/// The source is chosen once. Features never choose or fall back to mocks.
class AppDependencies {
  AppDependencies(
    DataConfig config, {
    ApiClient? client,
    PreparationRepository? preparationOverride,
    PreferencesRepository? preferencesOverride,
    AuthTokenStore? tokenStore,
    Future<void> Function()? onUnauthorized,
  }) {
    if (config.mode == DataSourceMode.api) {
      _ownsClient = client == null;
      _client =
          client ??
          ApiClient(
            config.baseUrl,
            tokenStore: tokenStore,
            onUnauthorized: onUnauthorized,
          );
      preparation = preparationOverride ?? ApiPreparationRepository(_client!);
      profile = ApiProfileRepository(_client!);
      notifications = ApiNotificationRepository(_client!);
      preferences = preferencesOverride ?? ApiPreferencesRepository(_client!);
      reportAutosaveDelay = const Duration(milliseconds: 600);
      persistDraftInvalidation = false;
      assistant = ApiAiAssistantService(_client!);
      audioDraft = ApiAudioDraftService(_client!);
      audioCapture = RecordAudioCaptureService();
    } else {
      preparation = preparationOverride ?? MockPreparationRepository();
      profile = MockProfileRepository();
      preferences = preferencesOverride ?? MockPreferencesRepository();
      notifications = MockNotificationRepository(preparation, preferences);
      reportAutosaveDelay = null;
      persistDraftInvalidation = true;
      assistant = const MockAiAssistantService();
      audioDraft = const MockAudioDraftService();
      audioCapture = null;
    }
  }
  ApiClient? _client;
  bool _ownsClient = false;
  late final PreparationRepository preparation;
  late final ProfileRepository profile;
  late final NotificationRepository notifications;
  late final PreferencesRepository preferences;
  late final Duration? reportAutosaveDelay;
  late final bool persistDraftInvalidation;
  late final AiAssistantService assistant;
  late final AudioDraftService audioDraft;
  late final AudioCaptureService? audioCapture;
  void dispose() {
    if (_ownsClient) _client?.close();
  }
}
