enum NotificationCategory {
  reminder('Lembretes'),
  consultation('Consultas'),
  exam('Exames'),
  system('Sistema');

  const NotificationCategory(this.label);
  final String label;
}

enum NotificationDestination { appointment, history, medications, documents }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.dateTime,
    required this.category,
    required this.destination,
    this.destinationId,
    this.unread = false,
  });
  final String id, title, message;
  final DateTime dateTime;
  final NotificationCategory category;
  final NotificationDestination destination;
  final String? destinationId;
  final bool unread;
}
