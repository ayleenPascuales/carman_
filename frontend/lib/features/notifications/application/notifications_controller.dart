import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/models/app_notification.dart';
import '../../../data/models/booking.dart';
import '../../../providers.dart';

class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.isLoading = true,
    this.error,
  });

  final List<AppNotification> items;
  final bool isLoading;
  final String? error;

  int get unreadCount => items.where((item) => !item.isRead).length;

  NotificationsState copyWith({
    List<AppNotification>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class NotificationsController extends Notifier<NotificationsState> {
  @override
  NotificationsState build() {
    Future.microtask(refresh);
    return const NotificationsState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await ref
          .read(notificationRepositoryProvider)
          .fetchNotifications();
      if (!ref.mounted) return;
      final readIds = ref.read(sessionStoreProvider).loadReadNotifications();
      state = state.copyWith(
        items: items
            .map(
              (item) => readIds.contains(item.id) && !item.isRead
                  ? item.copyWith(isRead: true)
                  : item,
            )
            .toList(),
        isLoading: false,
      );
    } on AppException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, error: error.message);
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'No pudimos cargar tus notificaciones.',
      );
    }
  }

  Future<void> markAllRead() async {
    final updated = state.items
        .map((item) => item.copyWith(isRead: true))
        .toList();
    state = state.copyWith(items: updated);
    await ref
        .read(sessionStoreProvider)
        .saveReadNotifications(updated.map((item) => item.id).toSet());
    await ref.read(notificationRepositoryProvider).markAllRead();
  }

  Future<void> markRead(String id) async {
    final updated = state.items
        .map((item) => item.id == id ? item.copyWith(isRead: true) : item)
        .toList();
    state = state.copyWith(items: updated);
    final readIds = ref.read(sessionStoreProvider).loadReadNotifications()
      ..add(id);
    await ref.read(sessionStoreProvider).saveReadNotifications(readIds);
    await ref.read(notificationRepositoryProvider).markRead(id);
  }

  void add(AppNotification notification) {
    state = state.copyWith(items: [notification, ...state.items]);
  }

  void addReservation({required Reservation reservation}) {
    add(
      AppNotification(
        id: 'not-${DateTime.now().millisecondsSinceEpoch}',
        kind: NotificationKind.reservation,
        title: 'Reserva confirmada · ${reservation.code}',
        body:
            '${reservation.vehicle.title} · ${reservation.datesLabel}. Tu llave digital estará lista antes de la entrega.',
        createdAt: DateTime.now(),
      ),
    );
  }

  void addLicenseUpdate({required bool approved}) {
    add(
      AppNotification(
        id: 'not-${DateTime.now().millisecondsSinceEpoch}',
        kind: NotificationKind.license,
        title: approved ? 'Licencia verificada' : 'Licencia en revisión',
        body: approved
            ? 'Tu permiso de conducir fue aprobado. Ya puedes reservar sin límites.'
            : 'Estamos validando tu permiso. Te avisaremos en menos de 15 minutos.',
        createdAt: DateTime.now(),
      ),
    );
  }
}

final notificationsControllerProvider =
    NotifierProvider<NotificationsController, NotificationsState>(
      NotificationsController.new,
    );
