import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/models/vehicle_query.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../providers.dart';

class CatalogState {
  const CatalogState({
    required this.query,
    this.vehicles = const [],
    this.isLoading = true,
    this.error,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.page = 1,
  });

  final VehicleQuery query;
  final List<Vehicle> vehicles;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final bool isLoadingMore;
  final int page;

  int get count => vehicles.length;

  CatalogState copyWith({
    VehicleQuery? query,
    List<Vehicle>? vehicles,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? hasMore,
    bool? isLoadingMore,
    int? page,
  }) {
    return CatalogState(
      query: query ?? this.query,
      vehicles: vehicles ?? this.vehicles,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      page: page ?? this.page,
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
    state = state.copyWith(query: query, vehicles: const [], isLoading: true,
        hasMore: false, page: 1, clearError: true);
    await _fetch(query, showLoading: false);
  }

  Future<void> setCategory(VehicleCategory category) async {
    await updateQuery(state.query.copyWith(category: category));
  }

  Future<void> setCity(String city) async {
    await updateQuery(state.query.copyWith(city: city));
  }

  Future<void> setSort(SortOption sort) async {
    await updateQuery(state.query.copyWith(sort: sort));
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
      final CatalogPage result = await ref
          .read(vehicleRepositoryProvider)
          .fetchCatalogPage(query, 1);
      if (!ref.mounted || requestId != _requestId) return;
      state = state.copyWith(
        vehicles: result.vehicles,
        hasMore: result.hasMore,
        page: 1,
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

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    final requestId = _requestId;
    final query = state.query;
    final page = state.page + 1;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final result = await ref.read(vehicleRepositoryProvider)
          .fetchCatalogPage(query, page);
      if (!ref.mounted || requestId != _requestId) return;
      state = state.copyWith(
        vehicles: [...state.vehicles, ...result.vehicles],
        hasMore: result.hasMore,
        page: page,
        isLoadingMore: false,
      );
    } on AppException catch (error) {
      if (!ref.mounted || requestId != _requestId) return;
      state = state.copyWith(isLoadingMore: false, error: error.message);
    } catch (_) {
      if (!ref.mounted || requestId != _requestId) return;
      state = state.copyWith(isLoadingMore: false,
          error: 'No pudimos cargar más vehículos.');
    }
  }
}

final catalogControllerProvider =
    NotifierProvider<CatalogController, CatalogState>(CatalogController.new);
