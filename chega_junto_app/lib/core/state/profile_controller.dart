import 'package:flutter/foundation.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/health_record.dart';
import '../../data/models/profile_preferences.dart';
import '../../data/repositories/profile_repository.dart';

class ProfileController extends ChangeNotifier {
  ProfileController(this.repository);
  final ProfileRepository repository;
  UserProfile? profile;
  HealthOverview? health;
  bool loading = true, failed = false;
  bool _disposed = false;
  AccessibilityPreferences accessibility = const AccessibilityPreferences();
  NotificationPreferences notifications = NotificationPreferences();
  final Set<String> _readNotifications = {};
  bool isRead(String id) => _readNotifications.contains(id);
  void markRead(String id) {
    if (_readNotifications.add(id)) _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    loading = true;
    failed = false;
    _notify();
    try {
      final results = await Future.wait<Object>([
        repository.loadProfile(),
        repository.loadHealth(),
      ]);
      if (_disposed) return;
      profile = results[0] as UserProfile;
      health = results[1] as HealthOverview;
    } catch (_) {
      failed = true;
    }
    loading = false;
    _notify();
  }

  Future<void> saveProfile(UserProfile value) async {
    final saved = await repository.saveProfile(value);
    if (!_disposed) {
      profile = saved;
      _notify();
    }
  }

  Future<void> saveHealth(
    List<HealthItem> medications,
    List<HealthItem> allergies,
  ) async {
    final saved = await repository.saveHealth(medications, allergies);
    if (!_disposed) {
      health = saved;
      _notify();
    }
  }

  void setAccessibility(AccessibilityPreferences value) {
    accessibility = value;
    _notify();
  }

  void setNotification(NotificationOption option, bool value) {
    notifications = notifications.change(option, value);
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
