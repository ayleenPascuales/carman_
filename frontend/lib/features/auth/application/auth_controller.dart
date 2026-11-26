import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
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
    this.pendingVerification = false,
    this.emailVerified = true,
    this.phoneVerified = true,
    this.smsSent = true,
    this.emailSent = true,
  });

  final AuthStatus status;
  final UserProfile? user;
  final bool isSubmitting;
  final String? error;
  final bool remember;
  final bool pendingVerification;
  final bool emailVerified;
  final bool phoneVerified;
  final bool smsSent;
  final bool emailSent;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? user,
    bool? isSubmitting,
    String? error,
    bool? remember,
    bool? pendingVerification,
    bool? emailVerified,
    bool? phoneVerified,
    bool? smsSent,
    bool? emailSent,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      remember: remember ?? this.remember,
      pendingVerification: pendingVerification ?? this.pendingVerification,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      smsSent: smsSent ?? this.smsSent,
      emailSent: emailSent ?? this.emailSent,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  AuthSession? _pendingSession;

  @override
  AuthState build() {
    final store = ref.watch(sessionStoreProvider);
    final user = store.loadUser();
    if (AppConfig.useLiveApi) {
      if (store.loadToken() != null && store.rememberSession) {
        unawaited(_restoreLiveSession());
      }
      return AuthState(
        status: AuthStatus.unauthenticated,
        remember: store.rememberSession,
      );
    }
    return AuthState(
      status: user != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
      user: user,
      remember: store.rememberSession,
    );
  }

  Future<void> _restoreLiveSession() async {
    try {
      final repository = ref.read(authRepositoryProvider);
      if (repository is! ApiAuthRepository) return;
      final session = await repository.restoreSession();
      if (!ref.mounted || state.isAuthenticated || state.isSubmitting ||
          state.pendingVerification || session == null) {
        return;
      }
      state = AuthState(
        status: AuthStatus.authenticated,
        user: session.user,
        remember: session.remember,
      );
    } catch (_) {
      // Fallo de red: nunca abrir paneles privados con perfil local sin validar.
    }
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
      if (!session.activated) {
        _pendingSession = session;
        state = AuthState(
          status: AuthStatus.unauthenticated,
          pendingVerification: true,
          emailVerified: session.emailVerified,
          phoneVerified: session.phoneVerified,
          smsSent: session.smsSent,
          emailSent: session.emailSent,
          remember: session.remember,
        );
      } else {
        _pendingSession = null;
        state = AuthState(
          status: AuthStatus.authenticated,
          user: session.user,
          remember: session.remember,
        );
      }
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
      final pending = _pendingSession!;
      state = state.copyWith(
        isSubmitting: false,
        pendingVerification: !pending.activated,
        emailVerified: pending.emailVerified,
        phoneVerified: pending.phoneVerified,
        smsSent: pending.smsSent,
        emailSent: pending.emailSent,
      );
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
      await _refreshVerificationStatus();
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
    state = state.copyWith(smsSent: true, clearError: true);
  }

  Future<void> resendEmailVerification() async {
    await ref.read(authRepositoryProvider).resendEmailVerification();
    state = state.copyWith(emailSent: true, clearError: true);
  }

  Future<bool> refreshVerification() async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _refreshVerificationStatus();
      return state.isAuthenticated;
    } on AppException catch (error) {
      state = state.copyWith(isSubmitting: false, error: error.message);
      return false;
    }
  }

  Future<void> _refreshVerificationStatus() async {
    final status = await ref.read(authRepositoryProvider).verificationStatus();
    final pending = _pendingSession;
    if (status.activated && pending != null) {
      final store = ref.read(sessionStoreProvider);
      await store.saveUser(pending.user);
      await store.saveToken(pending.token, persistent: pending.remember);
      await store.setRememberSession(pending.remember);
      _pendingSession = null;
      state = AuthState(
        status: AuthStatus.authenticated,
        user: pending.user,
        remember: pending.remember,
      );
    } else {
      state = state.copyWith(
        isSubmitting: false,
        pendingVerification: pending != null,
        emailVerified: status.emailVerified,
        phoneVerified: status.phoneVerified,
        smsSent: status.phoneVerified || state.smsSent,
        emailSent: status.emailVerified || state.emailSent,
      );
    }
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
