import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/models/driver_models.dart';
import '../../../providers.dart';

class DriverState {
  const DriverState({
    this.data,
    this.isLoading = true,
    this.error,
    this.actionTripId,
  });

  final DriverDashboardData? data;
  final bool isLoading;
  final String? error;
  final String? actionTripId;

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
  }) {
    return DriverState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      actionTripId: clearAction ? null : (actionTripId ?? this.actionTripId),
    );
  }
}

class DriverController extends Notifier<DriverState> {
  @override
  DriverState build() {
    Future.microtask(load);
    return const DriverState();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await ref.read(driverRepositoryProvider).fetchDashboard();
      if (!ref.mounted) return;
      state = DriverState(data: data, isLoading: false);
    } on AppException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, error: error.message);
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'No pudimos cargar tus servicios.',
      );
    }
  }

  Future<void> setAvailable(bool available) async {
    final data = state.data;
    if (data == null) return;
    try {
      await ref.read(driverRepositoryProvider).setAvailability(available);
      if (!ref.mounted) return;
      state = state.copyWith(
        data: data.copyWith(
          availability: available
              ? DriverAvailability.online
              : DriverAvailability.offline,
        ),
        clearError: true,
      );
    } on AppException catch (error) {
      state = state.copyWith(error: error.message);
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
    if (data == null) return false;
    state = state.copyWith(actionTripId: id, clearError: true);
    try {
      await action();
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
      state = state.copyWith(error: error.message, clearAction: true);
      return false;
    }
  }
}

final driverControllerProvider =
    NotifierProvider<DriverController, DriverState>(DriverController.new);
