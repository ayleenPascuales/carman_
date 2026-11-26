import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../data/models/driver_models.dart';
import '../../../providers.dart';
import '../../auth/application/auth_controller.dart';

class DriverState {
  const DriverState({
    this.data,
    this.isLoading = true,
    this.error,
    this.actionTripId,
    this.isLoadingMore = false,
    this.isChangingAvailability = false,
  });

  final DriverDashboardData? data;
  final bool isLoading;
  final String? error;
  final String? actionTripId;
  final bool isLoadingMore;
  final bool isChangingAvailability;

  DriverTrip? get currentTrip {
    final trips = data?.trips ?? const [];
    for (final trip in trips) {
      if (trip.isCurrent) return trip;
    }
    return null;
  }

  List<DriverTrip> get offeredTrips =>
      (data?.trips ?? const [])
          .where((trip) => trip.status == DriverTripStatus.offered)
          .toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  List<DriverTrip> get recentCompleted =>
      (data?.trips ?? const [])
          .where((trip) => trip.status == DriverTripStatus.completed)
          .toList()
        ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

  DriverState copyWith({
    DriverDashboardData? data,
    bool? isLoading,
    String? error,
    String? actionTripId,
    bool clearError = false,
    bool clearAction = false,
    bool? isLoadingMore,
    bool? isChangingAvailability,
  }) {
    return DriverState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      actionTripId: clearAction ? null : (actionTripId ?? this.actionTripId),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isChangingAvailability:
          isChangingAvailability ?? this.isChangingAvailability,
    );
  }
}

class DriverController extends Notifier<DriverState> {
  @override
  DriverState build() {
    final id = ref.watch(
      authControllerProvider.select((auth) => auth.user?.id),
    );
    if (id == null) return const DriverState(isLoading: false);
    Future.microtask(load);
    return const DriverState();
  }

  Future<void> load() async {
    final accountId = ref.read(authControllerProvider).user?.id;
    if (accountId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await ref.read(driverRepositoryProvider).fetchDashboard();
      if (!ref.mounted ||
          ref.read(authControllerProvider).user?.id != accountId) {
        return;
      }
      state = DriverState(data: data, isLoading: false);
    } on AppException catch (error) {
      if (!ref.mounted ||
          ref.read(authControllerProvider).user?.id != accountId) {
        return;
      }
      state = DriverState(data: null, isLoading: false, error: error.message);
    } catch (_) {
      if (!ref.mounted ||
          ref.read(authControllerProvider).user?.id != accountId) {
        return;
      }
      state = const DriverState(
        isLoading: false,
        error: 'No pudimos cargar tus servicios.',
      );
    }
  }

  Future<void> loadMore() async {
    final data = state.data;
    if (data == null ||
        !data.hasMore ||
        state.isLoadingMore ||
        state.isLoading ||
        state.actionTripId != null) {
      return;
    }
    final accountId = ref.read(authControllerProvider).user?.id;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final next = await ref
          .read(driverRepositoryProvider)
          .fetchDashboard(page: data.page + 1);
      if (!ref.mounted ||
          ref.read(authControllerProvider).user?.id != accountId) {
        return;
      }
      if (next.page != data.page + 1) {
        throw const AppException('La página de servicios no coincide.');
      }
      state = state.copyWith(
        data: next.copyWith(
          trips: [
            ...data.trips.where(
              (trip) => !next.trips.any((other) => other.id == trip.id),
            ),
            ...next.trips,
          ],
        ),
        isLoadingMore: false,
      );
    } on AppException catch (error) {
      if (ref.mounted) {
        state = state.copyWith(isLoadingMore: false, error: error.message);
      }
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          isLoadingMore: false,
          error: 'No se pudo cargar más historial.',
        );
      }
    }
  }

  Future<void> setAvailable(bool available) async {
    final data = state.data;
    if (data == null ||
        state.isChangingAvailability ||
        state.actionTripId != null ||
        (available && !data.licenseValid)) {
      if (available && data != null && !data.licenseValid) {
        state = state.copyWith(
          error: 'Necesitas una licencia vigente para estar disponible.',
        );
      }
      return;
    }
    state = state.copyWith(isChangingAvailability: true, clearError: true);
    try {
      await ref.read(driverRepositoryProvider).setAvailability(available);
      if (!ref.mounted) return;
      if (AppConfig.useLiveApi) {
        await load();
        return;
      }
      state = state.copyWith(
        data: data.copyWith(
          availability: available
              ? DriverAvailability.online
              : DriverAvailability.offline,
        ),
        clearError: true,
        isChangingAvailability: false,
      );
    } on AppException catch (error) {
      if (ref.mounted) {
        state = state.copyWith(
          error: error.message,
          isChangingAvailability: false,
        );
      }
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          error: 'No se pudo confirmar la disponibilidad. Actualiza el panel.',
          isChangingAvailability: false,
        );
      }
    }
  }

  Future<bool> accept(String id) async {
    final active = state.currentTrip;
    if (active != null && active.id != id) return false;
    return _runAction(
      id,
      () => ref.read(driverRepositoryProvider).acceptTrip(id),
      (trip) => trip.copyWith(status: DriverTripStatus.accepted),
      availability: DriverAvailability.online,
    );
  }

  Future<bool> start(String id) async {
    return _runAction(
      id,
      () => ref.read(driverRepositoryProvider).startTrip(id),
      (trip) => trip.copyWith(status: DriverTripStatus.inProgress),
      availability: DriverAvailability.onTrip,
    );
  }

  Future<bool> complete(String id) async {
    if (AppConfig.useLiveApi) {
      return _runAction(
        id,
        () => ref.read(driverRepositoryProvider).completeTrip(id),
        (trip) => trip.copyWith(status: DriverTripStatus.completed),
      );
    }
    final data = state.data;
    if (data == null) return false;
    state = state.copyWith(actionTripId: id, clearError: true);
    try {
      await ref.read(driverRepositoryProvider).completeTrip(id);
      final trip = data.trips.firstWhere((item) => item.id == id);
      final updatedTrips = data.trips
          .map(
            (item) => item.id == id
                ? item.copyWith(status: DriverTripStatus.completed)
                : item,
          )
          .toList();
      final stats = data.stats.copyWith(
        tripsToday: data.stats.tripsToday + 1,
        earningsToday: data.stats.earningsToday + trip.earnings,
        earningsWeek: data.stats.earningsWeek + trip.earnings,
        completedTotal: data.stats.completedTotal + 1,
      );
      if (!ref.mounted) return true;
      state = state.copyWith(
        data: data.copyWith(
          stats: stats,
          trips: updatedTrips,
          availability: DriverAvailability.online,
        ),
        clearAction: true,
      );
      return true;
    } on AppException catch (error) {
      state = state.copyWith(error: error.message, clearAction: true);
      return false;
    }
  }

  Future<bool> decline(String id) async {
    return _runAction(
      id,
      () => ref.read(driverRepositoryProvider).declineTrip(id),
      (trip) => trip.copyWith(status: DriverTripStatus.cancelled),
    );
  }

  Future<bool> _runAction(
    String id,
    Future<void> Function() action,
    DriverTrip Function(DriverTrip trip) update, {
    DriverAvailability? availability,
  }) async {
    final data = state.data;
    if (data == null ||
        state.actionTripId != null ||
        state.isLoading ||
        state.isChangingAvailability ||
        state.isLoadingMore) {
      return false;
    }
    final trip = data.trips.where((item) => item.id == id).firstOrNull;
    if (trip == null ||
        (AppConfig.useLiveApi &&
            ((update(trip).status == DriverTripStatus.accepted ||
                        update(trip).status == DriverTripStatus.cancelled) &&
                    trip.status != DriverTripStatus.offered ||
                update(trip).status == DriverTripStatus.inProgress &&
                    trip.status != DriverTripStatus.accepted ||
                update(trip).status == DriverTripStatus.completed &&
                    trip.status != DriverTripStatus.inProgress))) {
      return false;
    }
    final accountId = ref.read(authControllerProvider).user?.id;
    state = state.copyWith(actionTripId: id, clearError: true);
    try {
      await action();
      if (AppConfig.useLiveApi) {
        if (!ref.mounted ||
            ref.read(authControllerProvider).user?.id != accountId) {
          return false;
        }
        await load();
        if (state.error != null || state.data == null) {
          if (ref.mounted) {
            state = state.copyWith(
              error: 'La operación pudo guardarse; no repitas la acción sin consultar el servicio.',
              clearAction: true,
            );
          }
          return false;
        }
        final refreshed = state.data!.trips
            .where((item) => item.id == id)
            .firstOrNull;
        final expected = update(trip).status;
        final confirmed = expected == DriverTripStatus.cancelled
            ? refreshed == null
            : refreshed?.status == expected;
        if (!confirmed) {
          state = state.copyWith(
            error: 'La operación pudo guardarse; comprueba el estado antes de repetirla.',
            clearAction: true,
          );
        }
        return confirmed;
      }
      final updatedTrips = data.trips
          .map((trip) => trip.id == id ? update(trip) : trip)
          .toList();
      if (!ref.mounted) return true;
      state = state.copyWith(
        data: data.copyWith(
          trips: updatedTrips,
          availability: availability ?? data.availability,
        ),
        clearAction: true,
      );
      return true;
    } on AppException catch (error) {
      if (!ref.mounted) return false;
      if (AppConfig.useLiveApi) {
        await load();
        if (!ref.mounted) return false;
      }
      state = state.copyWith(
        error: AppConfig.useLiveApi
            ? '${error.message} Comprueba el estado antes de reintentar.'
            : error.message,
        clearAction: true,
      );
      return false;
    } catch (_) {
      if (AppConfig.useLiveApi && ref.mounted) {
        await load();
      }
      if (ref.mounted) {
        state = state.copyWith(
          error: 'No se pudo confirmar el resultado. Actualiza antes de repetir la acción.',
          clearAction: true,
        );
      }
      return false;
    }
  }
}

final driverControllerProvider =
    NotifierProvider<DriverController, DriverState>(DriverController.new);
