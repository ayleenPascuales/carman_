import '../mock/mock_data.dart';
import '../models/app_notification.dart';

abstract interface class NotificationRepository {
  Future<List<AppNotification>> fetchNotifications();

  Future<void> markAllRead();

  Future<void> markRead(String id);
}

class DemoNotificationRepository implements NotificationRepository {
  @override
  Future<List<AppNotification>> fetchNotifications() async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    return [...MockData.notifications]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> markAllRead() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<void> markRead(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }
}
