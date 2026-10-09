import '../models/app_notification.dart';

abstract interface class NotificationRepository {
  Future<NotificationInbox> load();
  Future<AppNotification> markRead(String id);
}
