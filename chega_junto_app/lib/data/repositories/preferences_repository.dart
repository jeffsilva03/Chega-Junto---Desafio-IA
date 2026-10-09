import '../models/profile_preferences.dart';

abstract interface class PreferencesRepository {
  Future<AccessibilityPreferences> loadAccessibility();
  Future<AccessibilityPreferences> saveAccessibility(
    AccessibilityPreferences value,
  );
  Future<NotificationPreferences> loadNotifications();
  Future<NotificationPreferences> saveNotifications(
    NotificationPreferences value,
  );
}
