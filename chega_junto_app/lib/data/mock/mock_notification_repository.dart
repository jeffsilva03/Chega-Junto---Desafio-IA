import '../models/app_notification.dart';
import '../repositories/notification_repository.dart';
import '../repositories/preferences_repository.dart';
import '../repositories/preparation_repository.dart';
import 'mock_notifications.dart';

class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository(this.preparation, this.preferences);
  final PreparationRepository preparation;
  final PreferencesRepository preferences;
  final Set<String> _read = {};
  @override
  Future<NotificationInbox> load() async {
    final overview = await preparation.loadOverview();
    final appointments = await preparation.loadAppointments();
    final reminders = await preparation.loadReminders();
    final prefs = await preferences.loadNotifications();
    final items = demoNotifications(overview, appointments, reminders)
        .where((n) => notificationVisible(n, prefs))
        .map((n) => _read.contains(n.id) ? n.withRead(true) : n)
        .toList();
    return NotificationInbox(items, items.where((n) => n.unread).length);
  }

  @override
  Future<AppNotification> markRead(String id) async {
    final value = (await load()).items.firstWhere((n) => n.id == id);
    _read.add(id);
    return value.withRead(true);
  }
}
