import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/vehicle.dart';
import '../../../providers.dart';
import '../../auth/application/auth_controller.dart';

class FavoritesController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final id = ref.watch(authControllerProvider.select((auth) => auth.user?.id));
    if (id == null) return {};
    return ref.watch(sessionStoreProvider).loadFavorites(accountId: id);
  }

  Future<void> toggle(String vehicleId) async {
    final accountId = ref.read(authControllerProvider).user?.id;
    if (accountId == null) return;
    final next = {...state};
    if (!next.add(vehicleId)) next.remove(vehicleId);
    state = next;
    await ref.read(sessionStoreProvider).saveFavorites(next, accountId: accountId);
  }

  bool contains(String vehicleId) => state.contains(vehicleId);

  Future<void> clear() async {
    final accountId = ref.read(authControllerProvider).user?.id;
    if (accountId == null) return;
    state = {};
    await ref.read(sessionStoreProvider).saveFavorites({}, accountId: accountId);
  }
}

final favoritesControllerProvider =
    NotifierProvider<FavoritesController, Set<String>>(FavoritesController.new);

final favoriteVehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final ids = ref.watch(favoritesControllerProvider);
  if (ids.isEmpty) return const [];
  return ref.watch(profileRepositoryProvider).fetchFavorites(ids);
});
