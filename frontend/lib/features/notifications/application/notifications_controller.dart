import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/models/app_notification.dart';
import '../../../data/models/booking.dart';
import '../../../providers.dart';
import '../../auth/application/auth_controller.dart';

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
    final id = ref.watch(authControllerProvider.select((auth) => auth.user?.id));
    if (id == null) return const NotificationsState(items: [], isLoading: false);
    Future.microtask(refresh);
    return const NotificationsState();
  }

  Future<void> refresh() async {
    final accountId = ref.read(authControllerProvider).user?.id;
    if (accountId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await ref
          .read(notificationRepositoryProvider)
          .fetchNotifications();
      if (!ref.mounted || ref.read(authControllerProvider).user?.id != accountId) return;
      final readIds = ref.read(sessionStoreProvider)
          .loadReadNotifications(accountId: accountId);
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
      if (!ref.mounted || ref.read(authControllerProvider).user?.id != accountId) return;
      state = state.copyWith(isLoading: false, error: error.message);
    } catch (_) {
      if (!ref.mounted || ref.read(authControllerProvider).user?.id != accountId) return;
      state = state.copyWith(
        isLoading: false,
        error: 'No pudimos cargar tus notificaciones.',
      );
    }
  }

  Future<void> markAllRead() async {
    final accountId = ref.read(authControllerProvider).user?.id;
    if (accountId == null) return;
    final previous = state.items;
    final updated = state.items
        .map((item) => item.copyWith(isRead: true))
        .toList();
    state = state.copyWith(items: updated);
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
      if (ref.read(authControllerProvider).user?.id != accountId) return;
      await ref.read(sessionStoreProvider).saveReadNotifications(
        updated.map((item) => item.id).toSet(), accountId: accountId,
      );
    } catch (_) {
      if (ref.mounted && ref.read(authControllerProvider).user?.id == accountId) {
        state = state.copyWith(items: previous);
      }
      rethrow;
    }
  }

  Future<void> markRead(String id) async {
    final accountId = ref.read(authControllerProvider).user?.id;
    if (accountId == null) return;
    final previous = state.items;
    final updated = state.items
        .map((item) => item.id == id ? item.copyWith(isRead: true) : item)
        .toList();
    state = state.copyWith(items: updated);
    try {
      await ref.read(notificationRepositoryProvider).markRead(id);
      if (ref.read(authControllerProvider).user?.id != accountId) return;
      final readIds = ref.read(sessionStoreProvider)
          .loadReadNotifications(accountId: accountId)..add(id);
      await ref.read(sessionStoreProvider)
          .saveReadNotifications(readIds, accountId: accountId);
    } catch (_) {
      if (ref.mounted && ref.read(authControllerProvider).user?.id == accountId) {
        state = state.copyWith(items: previous);
      }
      rethrow;
    }
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
