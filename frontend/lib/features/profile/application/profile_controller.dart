import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../providers.dart';
import '../../auth/application/auth_controller.dart';

class ProfileState {
  const ProfileState({
    this.user,
    this.isSaving = false,
    this.error,
    this.lastSavedMessage,
  });

  final UserProfile? user;
  final bool isSaving;
  final String? error;
  final String? lastSavedMessage;

  ProfileState copyWith({
    UserProfile? user,
    bool? isSaving,
    String? error,
    String? lastSavedMessage,
    bool clearError = false,
  }) {
    return ProfileState(
      user: user ?? this.user,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
      lastSavedMessage: lastSavedMessage ?? this.lastSavedMessage,
    );
  }
}

class ProfileController extends Notifier<ProfileState> {
  @override
  ProfileState build() {
    final auth = ref.watch(authControllerProvider);
    return ProfileState(user: auth.user);
  }

  Future<bool> save(ProfileUpdate update) async {
    final current = state.user;
    if (current == null) return false;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final updated = await ref
          .read(profileRepositoryProvider)
          .updateProfile(current, update);
      await ref.read(authControllerProvider.notifier).updateUser(updated);
      state = state.copyWith(
        user: updated,
        isSaving: false,
        lastSavedMessage: 'Perfil actualizado',
      );
      return true;
    } on AppException catch (error) {
      state = state.copyWith(isSaving: false, error: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        error: 'No pudimos guardar tus cambios.',
      );
      return false;
    }
  }

  Future<bool> addRole(UserRole role) async {
    final current = state.user;
    if (current == null) return false;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final updated = await ref
          .read(profileRepositoryProvider)
          .addRole(current, role);
      await ref.read(authControllerProvider.notifier).updateUser(updated);
      state = state.copyWith(user: updated, isSaving: false);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(isSaving: false, error: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        error: 'No pudimos actualizar tu perfil.',
      );
      return false;
    }
  }
}

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileState>(ProfileController.new);
