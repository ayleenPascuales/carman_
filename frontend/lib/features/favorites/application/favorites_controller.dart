import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/vehicle.dart';
import '../../../providers.dart';

class FavoritesController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    return ref.watch(sessionStoreProvider).loadFavorites();
  }

  Future<void> toggle(String vehicleId) async {
    final next = {...state};
    if (!next.add(vehicleId)) next.remove(vehicleId);
    state = next;
    await ref.read(sessionStoreProvider).saveFavorites(next);
  }

  bool contains(String vehicleId) => state.contains(vehicleId);

  Future<void> clear() async {
    state = {};
    await ref.read(sessionStoreProvider).saveFavorites({});
  }
}

final favoritesControllerProvider =
    NotifierProvider<FavoritesController, Set<String>>(FavoritesController.new);

final favoriteVehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final ids = ref.watch(favoritesControllerProvider);
  if (ids.isEmpty) return const [];
  return ref.watch(profileRepositoryProvider).fetchFavorites(ids);
});
