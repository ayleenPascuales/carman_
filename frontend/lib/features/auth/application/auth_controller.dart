import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../providers.dart';

enum AuthStatus { authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.isSubmitting = false,
    this.error,
    this.remember = true,
  });

  final AuthStatus status;
  final UserProfile? user;
  final bool isSubmitting;
  final String? error;
  final bool remember;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? user,
    bool? isSubmitting,
    String? error,
    bool? remember,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      remember: remember ?? this.remember,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  AuthSession? _pendingSession;

  @override
  AuthState build() {
    final store = ref.watch(sessionStoreProvider);
    final user = store.loadUser();
    return AuthState(
      status: user != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
      user: user,
      remember: store.rememberSession,
    );
  }

  void setRemember(bool value) {
    state = state.copyWith(remember: value);
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }

  Future<bool> login({
    required String email,
    required String password,
    bool? remember,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final session = await ref
          .read(authRepositoryProvider)
          .login(
            email: email,
            password: password,
            remember: remember ?? state.remember,
          );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: session.user,
        remember: session.remember,
      );
      return true;
    } on AppException catch (error) {
      state = state.copyWith(isSubmitting: false, error: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'No pudimos iniciar sesión. Inténtalo de nuevo.',
      );
      return false;
    }
  }

  Future<bool> register(RegistrationRequest request) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      _pendingSession = await ref
          .read(authRepositoryProvider)
          .register(request);
      state = state.copyWith(isSubmitting: false);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(isSubmitting: false, error: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'No pudimos crear tu cuenta. Inténtalo de nuevo.',
      );
      return false;
    }
  }

  String? get pendingPhone => _pendingSession?.user.phone;

  String? get pendingEmail => _pendingSession?.user.email;

  Future<bool> verifyOtp(String code) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await ref.read(authRepositoryProvider).verifyOtp(code);
      final pending = _pendingSession;
      if (pending != null) {
        final store = ref.read(sessionStoreProvider);
        await store.saveUser(pending.user);
        await store.saveToken(pending.token);
        await store.setRememberSession(true);
        _pendingSession = null;
        state = AuthState(
          status: AuthStatus.authenticated,
          user: pending.user,
          remember: true,
        );
      } else {
        state = state.copyWith(isSubmitting: false);
      }
      return true;
    } on AppException catch (error) {
      state = state.copyWith(isSubmitting: false, error: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'El código no es válido o ha expirado.',
      );
      return false;
    }
  }

  Future<void> resendOtp() async {
    await ref.read(authRepositoryProvider).resendOtp(pendingPhone ?? '');
  }

  Future<bool> requestPasswordReset(String email) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(email);
      state = state.copyWith(isSubmitting: false);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(isSubmitting: false, error: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'No pudimos enviar el enlace. Inténtalo de nuevo.',
      );
      return false;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(email: email, password: password);
      state = state.copyWith(isSubmitting: false);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(isSubmitting: false, error: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'No pudimos actualizar la contraseña.',
      );
      return false;
    }
  }

  Future<void> loginWithDemoAccount() async {
    await login(email: 'alex.rivera@carman.es', password: 'Carman123');
  }

  Future<void> updateUser(UserProfile user) async {
    final store = ref.read(sessionStoreProvider);
    await store.saveUser(user);
    state = state.copyWith(user: user);
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    _pendingSession = null;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
