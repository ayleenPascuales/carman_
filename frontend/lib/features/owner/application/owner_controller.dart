import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/models/owner_models.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../providers.dart';
import '../../explore/application/catalog_controller.dart';

class OwnerState {
  const OwnerState({
    required this.stats,
    this.listings = const [],
    this.isPublishing = false,
    this.isLoading = true,
    this.error,
    this.lastPublished,
  });

  final OwnerStats stats;
  final List<OwnerListing> listings;
  final bool isPublishing;
  final bool isLoading;
  final String? error;
  final Vehicle? lastPublished;

  OwnerState copyWith({
    OwnerStats? stats,
    List<OwnerListing>? listings,
    bool? isPublishing,
    bool? isLoading,
    String? error,
    Vehicle? lastPublished,
    bool clearError = false,
  }) {
    return OwnerState(
      stats: stats ?? this.stats,
      listings: listings ?? this.listings,
      isPublishing: isPublishing ?? this.isPublishing,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastPublished: lastPublished ?? this.lastPublished,
    );
  }
}

class OwnerController extends Notifier<OwnerState> {
  static const _emptyStats = OwnerStats(
    vehicles: 0,
    activeVehicles: 0,
    monthlyRevenue: 0,
    pendingReservations: 0,
    occupancyRate: 0,
    previousMonthRevenue: 0,
  );

  @override
  OwnerState build() {
    Future.microtask(load);
    return const OwnerState(stats: _emptyStats);
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await ref.read(ownerRepositoryProvider).fetchDashboard();
      if (!ref.mounted) return;
      state = state.copyWith(
        stats: data.stats,
        listings: data.listings,
        isLoading: false,
      );
    } on AppException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, error: error.message);
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'No pudimos cargar el panel.',
      );
    }
  }

  Future<bool> publish(VehicleDraft draft) async {
    state = state.copyWith(isPublishing: true, clearError: true);
    try {
      final vehicle = await ref
          .read(vehicleRepositoryProvider)
          .publishVehicle(draft);
      final meta = OwnerVehicle(
        id: 'ov-${DateTime.now().millisecondsSinceEpoch}',
        vehicleId: vehicle.id,
        status: OwnerVehicleStatus.review,
        nextService: DateTime.now().add(const Duration(days: 90)),
        monthlyRevenue: 0,
        tripsThisMonth: 0,
      );
      final stats = OwnerStats(
        vehicles: state.stats.vehicles + 1,
        activeVehicles: state.stats.activeVehicles,
        monthlyRevenue: state.stats.monthlyRevenue,
        pendingReservations: state.stats.pendingReservations + 1,
        occupancyRate: state.stats.occupancyRate,
        previousMonthRevenue: state.stats.previousMonthRevenue,
      );
      state = state.copyWith(
        listings: [
          OwnerListing(meta: meta, vehicle: vehicle),
          ...state.listings,
        ],
        stats: stats,
        isPublishing: false,
        isLoading: false,
        lastPublished: vehicle,
      );
      ref.invalidate(catalogControllerProvider);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(isPublishing: false, error: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isPublishing: false,
        error: 'No pudimos publicar el vehículo.',
      );
      return false;
    }
  }

  void setStatus(String vehicleId, OwnerVehicleStatus status) {
    final updated = state.listings.map((listing) {
      if (listing.vehicle.id != vehicleId) return listing;
      return OwnerListing(
        meta: OwnerVehicle(
          id: listing.meta.id,
          vehicleId: listing.meta.vehicleId,
          status: status,
          nextService: listing.meta.nextService,
          monthlyRevenue: listing.meta.monthlyRevenue,
          tripsThisMonth: listing.meta.tripsThisMonth,
          documentsInOrder: listing.meta.documentsInOrder,
        ),
        vehicle: listing.vehicle,
      );
    }).toList();
    final active = updated
        .where((listing) => listing.meta.status == OwnerVehicleStatus.available)
        .length;
    state = state.copyWith(
      listings: updated,
      stats: OwnerStats(
        vehicles: state.stats.vehicles,
        activeVehicles: active,
        monthlyRevenue: state.stats.monthlyRevenue,
        pendingReservations: state.stats.pendingReservations,
        occupancyRate: state.stats.occupancyRate,
        previousMonthRevenue: state.stats.previousMonthRevenue,
      ),
    );
  }
}

final ownerControllerProvider = NotifierProvider<OwnerController, OwnerState>(
  OwnerController.new,
);
