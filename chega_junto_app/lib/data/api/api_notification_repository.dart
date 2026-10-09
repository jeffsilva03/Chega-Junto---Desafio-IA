import '../../core/network/api_client.dart';
import '../models/app_notification.dart';
import '../repositories/notification_repository.dart';
import 'api_mapping.dart';

class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository(this.client);
  final ApiClient client;
  AppNotification _notification(Json j) => AppNotification(
    id: decimalId(j['id']),
    title: j['title'],
    message: j['message'],
    dateTime: instant(j['published_at']),
    category: NotificationCategory.values.byName(j['category']),
    destination: NotificationDestination.values.byName(j['destination']),
    destinationId: j['appointment_id'] == null
        ? j['health_record_id'] == null
              ? null
              : decimalId(j['health_record_id'])
        : decimalId(j['appointment_id']),
    unread: !j['is_read'],
  );
  @override
  Future<NotificationInbox> load() async {
    var unread = 0;
    final items = await client.pages(
      '/api/v1/me/notifications',
      onPage: (p) => unread = p['unread_count'],
    );
    return NotificationInbox(items.map(_notification).toList(), unread);
  }

  @override
  Future<AppNotification> markRead(String id) async => _notification(
    await client.request(
      'PATCH',
      '/api/v1/me/notifications/${decimalId(id)}',
      body: {'is_read': true},
    ),
  );
}
