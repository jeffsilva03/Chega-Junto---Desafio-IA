import 'package:flutter/foundation.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/health_record.dart';
import '../../data/models/app_notification.dart';
import '../../data/models/profile_preferences.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/preferences_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/mock/mock_preferences_repository.dart';

class ProfileController extends ChangeNotifier {
  ProfileController(
    this.repository, {
    PreferencesRepository? preferences,
    this.notificationRepository,
  }) : preferences = preferences ?? MockPreferencesRepository();
  final ProfileRepository repository;
  final PreferencesRepository preferences;
  final NotificationRepository? notificationRepository;
  UserProfile? profile;
  HealthOverview? health;
  bool loading = true,
      failed = false,
      notificationsLoading = false,
      preferencesSaving = false;
  Object? error, notificationError, preferenceError;
  bool _disposed = false;
  AccessibilityPreferences accessibility = const AccessibilityPreferences();
  NotificationPreferences notifications = NotificationPreferences();
  NotificationInbox inbox = NotificationInbox([], 0);
  final Set<String> _readNotifications = {};
  final Map<String, Future<HealthRecord>> _details = {};
  Future<void> _preferenceWrites = Future.value();
  Future<void> Function()? _retryPreference;
  int _preferenceGeneration = 0, _notificationGeneration = 0;
  bool isRead(String id) => _readNotifications.contains(id);
  Future<void> markRead(String id) async {
    if (notificationRepository == null) {
      _readNotifications.add(id);
      _notify();
      return;
    }
    final saved = await notificationRepository?.markRead(id);
    if (_disposed) return;
    _readNotifications.add(id);
    if (saved != null) {
      final wasUnread = inbox.items.any((n) => n.id == id && n.unread);
      inbox = NotificationInbox(
        [for (final n in inbox.items) n.id == id ? saved : n],
        wasUnread && inbox.unreadCount > 0
            ? inbox.unreadCount - 1
            : inbox.unreadCount,
      );
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    loading = true;
    failed = false;
    error = null;
    _notify();
    try {
      await _preferenceWrites;
      final preferenceGeneration = _preferenceGeneration;
      final results = await Future.wait<Object>([
        repository.loadProfile(),
        repository.loadHealth(),
        preferences.loadAccessibility(),
        preferences.loadNotifications(),
      ]);
      if (_disposed) return;
      profile = results[0] as UserProfile;
      health = results[1] as HealthOverview;
      if (preferenceGeneration == _preferenceGeneration) {
        accessibility = results[2] as AccessibilityPreferences;
        notifications = results[3] as NotificationPreferences;
      }
      await reloadNotifications();
    } catch (e) {
      if (!_disposed) {
        failed = true;
        error = e;
      }
    }
    if (_disposed) return;
    loading = false;
    _notify();
  }

  Future<void> reloadNotifications() async {
    if (notificationRepository == null) return;
    final generation = ++_notificationGeneration;
    notificationsLoading = true;
    notificationError = null;
    _notify();
    try {
      final updated = await notificationRepository!.load();
      if (_disposed || generation != _notificationGeneration) return;
      inbox = updated;
      _readNotifications
        ..clear()
        ..addAll(updated.items.where((n) => !n.unread).map((n) => n.id));
    } catch (e) {
      if (!_disposed && generation == _notificationGeneration) {
        notificationError = e;
      }
    }
    if (_disposed || generation != _notificationGeneration) return;
    notificationsLoading = false;
    _notify();
  }

  Future<HealthRecord> loadHealthRecord(String id, {bool retry = false}) {
    if (retry) _details.remove(id);
    return _details.putIfAbsent(id, () => repository.loadHealthRecord(id));
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

  Future<void> _savePreference(
    Future<void> Function() save,
    void Function() rollback,
    Future<void> Function() retry,
  ) {
    final generation = ++_preferenceGeneration;
    preferencesSaving = true;
    preferenceError = null;
    _notify();
    final next = _preferenceWrites.then((_) async {
      try {
        await save();
      } catch (e) {
        if (!_disposed && generation == _preferenceGeneration) {
          rollback();
          preferenceError = e;
          _retryPreference = retry;
        }
      }
      if (!_disposed && generation == _preferenceGeneration) {
        preferencesSaving = false;
        _notify();
      }
    });
    _preferenceWrites = next;
    return next;
  }

  Future<void> setAccessibility(AccessibilityPreferences value) {
    final previous = accessibility;
    accessibility = value;
    return _savePreference(
      () async {
        final canonical = await preferences.saveAccessibility(value);
        if (!_disposed) accessibility = canonical;
      },
      () => accessibility = previous,
      () => setAccessibility(value),
    );
  }

  Future<void> setNotification(NotificationOption option, bool value) {
    final previous = notifications;
    final updated = previous.change(option, value);
    notifications = updated;
    return _savePreference(
      () async {
        final canonical = await preferences.saveNotifications(updated);
        if (!_disposed) notifications = canonical;
        await reloadNotifications();
      },
      () => notifications = previous,
      () => setNotification(option, value),
    );
  }

  Future<void> retryPreferences() async {
    await _retryPreference?.call();
  }

  @override
  void dispose() {
    _disposed = true;
    profile = null;
    health = null;
    accessibility = const AccessibilityPreferences();
    notifications = NotificationPreferences();
    inbox = NotificationInbox([], 0);
    _readNotifications.clear();
    _details.clear();
    _retryPreference = null;
    error = notificationError = preferenceError = null;
    super.dispose();
  }
}
