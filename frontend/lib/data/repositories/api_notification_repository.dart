import '../../core/errors/app_exception.dart';
import '../local/session_store.dart';
import '../models/app_notification.dart';
import '../remote/api_client.dart';
import '../remote/api_endpoints.dart';
import '../remote/api_mappers.dart';
import 'notification_repository.dart';

class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository(this._api, this._store);

  final ApiClient _api;
  final SessionStore _store;

  String _token() {
    final token = _store.loadToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('La sesión expiró. Inicia sesión de nuevo.');
    }
    return token;
  }

  @override
  Future<List<AppNotification>> fetchNotifications() async {
    final payload = await _api.get(ApiEndpoints.notifications, token: _token());
    final raw =
        payload['notificaciones'] ?? payload['data'] ?? payload['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ApiMappers.notification)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> markAllRead() async {
    await _api.patch(ApiEndpoints.notificationsRead, token: _token());
  }

  @override
  Future<void> markRead(String id) async {
    await _api.patch(ApiEndpoints.notificationRead(id), token: _token());
  }
}
