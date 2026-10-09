import '../models/profile_preferences.dart';
import '../repositories/preferences_repository.dart';

class MockPreferencesRepository implements PreferencesRepository {
  AccessibilityPreferences _accessibility = const AccessibilityPreferences();
  NotificationPreferences _notifications = NotificationPreferences();
  @override
  Future<AccessibilityPreferences> loadAccessibility() async => _accessibility;
  @override
  Future<AccessibilityPreferences> saveAccessibility(
    AccessibilityPreferences value,
  ) async => _accessibility = value;
  @override
  Future<NotificationPreferences> loadNotifications() async => _notifications;
  @override
  Future<NotificationPreferences> saveNotifications(
    NotificationPreferences value,
  ) async => _notifications = value;
}
