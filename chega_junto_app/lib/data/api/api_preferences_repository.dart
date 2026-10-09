import '../../core/network/api_client.dart';
import '../models/profile_preferences.dart';
import '../repositories/preferences_repository.dart';

class ApiPreferencesRepository implements PreferencesRepository {
  ApiPreferencesRepository(this.client);
  final ApiClient client;
  AccessibilityPreferences _accessibility(Json j) => AccessibilityPreferences(
    textSize: j['text_size'] == 'extra_large'
        ? AppTextSize.extraLarge
        : AppTextSize.values.byName(j['text_size']),
    appearance: AppAppearance.values.byName(j['appearance']),
    highContrast: j['high_contrast'],
    speech: j['speech'],
    descriptions: j['descriptions'],
    simpleLanguage: j['simple_language'],
    haptics: j['haptics'],
    reduceMotion: j['reduce_motion'],
  );
  Json _accessibilityBody(AccessibilityPreferences p) => {
    'text_size': p.textSize == AppTextSize.extraLarge
        ? 'extra_large'
        : p.textSize.name,
    'appearance': p.appearance.name,
    'high_contrast': p.highContrast,
    'speech': p.speech,
    'descriptions': p.descriptions,
    'simple_language': p.simpleLanguage,
    'haptics': p.haptics,
    'reduce_motion': p.reduceMotion,
  };
  String _key(NotificationOption option) =>
      option == NotificationOption.inApp ? 'in_app' : option.name;
  NotificationPreferences _notifications(Json j) => NotificationPreferences({
    for (final o in NotificationOption.values) o: j[_key(o)] as bool,
  });
  @override
  Future<AccessibilityPreferences> loadAccessibility() async => _accessibility(
    await client.request('GET', '/api/v1/me/accessibility-preferences'),
  );
  @override
  Future<AccessibilityPreferences> saveAccessibility(
    AccessibilityPreferences value,
  ) async => _accessibility(
    await client.request(
      'PUT',
      '/api/v1/me/accessibility-preferences',
      body: _accessibilityBody(value),
    ),
  );
  @override
  Future<NotificationPreferences> loadNotifications() async => _notifications(
    await client.request('GET', '/api/v1/me/notification-preferences'),
  );
  @override
  Future<NotificationPreferences> saveNotifications(
    NotificationPreferences value,
  ) async => _notifications(
    await client.request(
      'PUT',
      '/api/v1/me/notification-preferences',
      body: {
        for (final o in NotificationOption.values) _key(o): value.enabled(o),
      },
    ),
  );
}
