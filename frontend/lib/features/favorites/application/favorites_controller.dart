import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../data/models/vehicle.dart';
import '../../../providers.dart';
import '../../auth/application/auth_controller.dart';

class FavoritesState {
  const FavoritesState({
    this.ids = const <String>{},
    this.isLoading = false,
    this.error,
    this.actionId,
  });

  final Set<String> ids;
  final bool isLoading;
  final String? error;
  final String? actionId;

  FavoritesState copyWith({
    Set<String>? ids,
    bool? isLoading,
    String? error,
    String? actionId,
    bool clearError = false,
    bool clearAction = false,
  }) => FavoritesState(
    ids: ids ?? this.ids,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
    actionId: clearAction ? null : (actionId ?? this.actionId),
  );
}

class FavoritesController extends Notifier<FavoritesState> {
  int _requestVersion = 0;

  @override
  FavoritesState build() {
    ++_requestVersion;
    final id = ref.watch(
      authControllerProvider.select((auth) => auth.user?.id),
    );
    if (id == null) return const FavoritesState();
    if (AppConfig.useLiveApi) {
      Future.microtask(load);
      return const FavoritesState(isLoading: true);
    }
    return FavoritesState(
      ids: ref.watch(sessionStoreProvider).loadFavorites(accountId: id),
    );
  }

  Future<void> load() async {
    if (!ref.mounted) return;
    final accountId = ref.read(authControllerProvider).user?.id;
    if (accountId == null) return;
    if (state.actionId != null) return;
    if (!AppConfig.useLiveApi) {
      state = state.copyWith(
        ids: ref.read(sessionStoreProvider).loadFavorites(accountId: accountId),
        clearError: true,
      );
      return;
    }
    final version = ++_requestVersion;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final ids = await ref.read(favoritesRepositoryProvider).fetchIds();
      if (!ref.mounted ||
          version != _requestVersion ||
          ref.read(authControllerProvider).user?.id != accountId) {
        return;
      }
      state = state.copyWith(
        ids: Set.unmodifiable(ids),
        isLoading: false,
        clearError: true,
      );
    } on AppException catch (error) {
      if (!ref.mounted ||
          version != _requestVersion ||
          ref.read(authControllerProvider).user?.id != accountId) {
        return;
      }
      state = state.copyWith(isLoading: false, error: error.message);
    } catch (_) {
      if (!ref.mounted ||
          version != _requestVersion ||
          ref.read(authControllerProvider).user?.id != accountId) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: 'No se pudieron consultar tus favoritos.',
      );
    }
  }

  Future<bool> toggle(String vehicleId) async {
    final accountId = ref.read(authControllerProvider).user?.id;
    if (accountId == null || state.isLoading || state.actionId != null) {
      return false;
    }
    final next = {...state.ids};
    final saving = next.add(vehicleId);
    if (!saving) next.remove(vehicleId);
    if (!AppConfig.useLiveApi) {
      state = state.copyWith(ids: next);
      await ref
          .read(sessionStoreProvider)
          .saveFavorites(next, accountId: accountId);
      return true;
    }
    final version = _requestVersion;
    state = state.copyWith(actionId: vehicleId, clearError: true);
    try {
      final repository = ref.read(favoritesRepositoryProvider);
      if (saving) {
        await repository.add(vehicleId);
      } else {
        await repository.remove(vehicleId);
      }
      if (!ref.mounted ||
          version != _requestVersion ||
          ref.read(authControllerProvider).user?.id != accountId) {
        return false;
      }
      state = state.copyWith(
        ids: Set.unmodifiable(next),
        clearAction: true,
        clearError: true,
      );
      return true;
    } on AppException catch (error) {
      if (ref.mounted &&
          version == _requestVersion &&
          ref.read(authControllerProvider).user?.id == accountId) {
        state = state.copyWith(clearAction: true, error: error.message);
      }
      return false;
    } catch (_) {
      if (ref.mounted &&
          version == _requestVersion &&
          ref.read(authControllerProvider).user?.id == accountId) {
        state = state.copyWith(
          clearAction: true,
          error: 'No se pudo confirmar el favorito. Reintenta.',
        );
      }
      return false;
    }
  }

  bool contains(String vehicleId) => state.ids.contains(vehicleId);

  Future<void> clear() async {
    final accountId = ref.read(authControllerProvider).user?.id;
    if (accountId == null) return;
    if (AppConfig.useLiveApi) {
      if (state.isLoading || state.actionId != null) return;
      final version = _requestVersion;
      state = state.copyWith(isLoading: true, clearError: true);
      try {
        for (final id in state.ids) {
          if (!ref.mounted ||
              version != _requestVersion ||
              ref.read(authControllerProvider).user?.id != accountId) {
            return;
          }
          await ref.read(favoritesRepositoryProvider).remove(id);
        }
        if (!ref.mounted ||
            version != _requestVersion ||
            ref.read(authControllerProvider).user?.id != accountId) {
          return;
        }
        await load();
      } on AppException catch (error) {
        if (ref.mounted &&
            version == _requestVersion &&
            ref.read(authControllerProvider).user?.id == accountId) {
          state = state.copyWith(isLoading: false, error: error.message);
        }
      }
      return;
    }
    state = state.copyWith(ids: {});
    await ref
        .read(sessionStoreProvider)
        .saveFavorites({}, accountId: accountId);
  }
}

final favoritesControllerProvider =
    NotifierProvider<FavoritesController, FavoritesState>(
      FavoritesController.new,
    );

final favoriteVehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final favorites = ref.watch(favoritesControllerProvider);
  if (favorites.isLoading) {
    return const [];
  }
  if (favorites.error != null) {
    throw AppException(favorites.error!);
  }
  final ids = favorites.ids;
  if (ids.isEmpty) return const [];
  return ref.watch(profileRepositoryProvider).fetchFavorites(ids);
});
