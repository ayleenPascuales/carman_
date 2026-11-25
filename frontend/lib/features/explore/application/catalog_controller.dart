import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/models/vehicle_query.dart';
import '../../../providers.dart';

class CatalogState {
  const CatalogState({
    required this.query,
    this.vehicles = const [],
    this.isLoading = true,
    this.error,
  });

  final VehicleQuery query;
  final List<Vehicle> vehicles;
  final bool isLoading;
  final String? error;

  int get count => vehicles.length;

  CatalogState copyWith({
    VehicleQuery? query,
    List<Vehicle>? vehicles,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return CatalogState(
      query: query ?? this.query,
      vehicles: vehicles ?? this.vehicles,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CatalogController extends Notifier<CatalogState> {
  int _requestId = 0;

  @override
  CatalogState build() {
    final store = ref.watch(sessionStoreProvider);
    final query = VehicleQuery(city: store.city ?? 'Cartagena');
    Future.microtask(() => _fetch(query, showLoading: true));
    return CatalogState(query: query);
  }

  Future<void> refresh() => _fetch(state.query);

  Future<void> updateQuery(VehicleQuery query) async {
    if (query.city != state.query.city) {
      await ref.read(sessionStoreProvider).saveCity(query.city);
    }
    state = state.copyWith(query: query, isLoading: true, clearError: true);
    await _fetch(query, showLoading: false);
  }

  Future<void> setCategory(VehicleCategory category) async {
    await updateQuery(state.query.copyWith(category: category));
  }

  Future<void> setCity(String city) async {
    await updateQuery(state.query.copyWith(city: city));
  }

  Future<void> setSort(SortOption sort) async {
    // Sorting is local, so cards reorder instantly.
    state = state.copyWith(
      query: state.query.copyWith(sort: sort),
      vehicles: state.query.copyWith(sort: sort).sortVehicles(state.vehicles),
    );
  }

  Future<void> setSearchText(String text) async {
    await updateQuery(state.query.copyWith(text: text));
  }

  Future<void> _fetch(VehicleQuery query, {bool showLoading = true}) async {
    final requestId = ++_requestId;
    if (showLoading) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final vehicles = await ref
          .read(vehicleRepositoryProvider)
          .fetchCatalog(query);
      if (!ref.mounted || requestId != _requestId) return;
      state = state.copyWith(
        vehicles: query.sortVehicles(vehicles),
        isLoading: false,
        clearError: true,
      );
    } on AppException catch (error) {
      if (!ref.mounted || requestId != _requestId) return;
      state = state.copyWith(isLoading: false, error: error.message);
    } catch (_) {
      if (!ref.mounted || requestId != _requestId) return;
      state = state.copyWith(
        isLoading: false,
        error: 'No pudimos cargar los vehículos. Inténtalo de nuevo.',
      );
    }
  }
}

final catalogControllerProvider =
    NotifierProvider<CatalogController, CatalogState>(CatalogController.new);
