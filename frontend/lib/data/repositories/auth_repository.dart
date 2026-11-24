import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';
import '../local/session_store.dart';
import '../mock/mock_data.dart';
import '../models/user_profile.dart';
import '../remote/api_client.dart';
import '../remote/api_endpoints.dart';

class AuthSession {
  const AuthSession({
    required this.user,
    required this.token,
    required this.remember,
  });

  final UserProfile user;
  final String token;
  final bool remember;
}

class RegistrationRequest {
  const RegistrationRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.password,
    required this.city,
    required this.document,
    required this.birthDate,
    required this.role,
    this.licenseNumber,
    this.licenseExpiry,
    this.licenseType = 'B',
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String password;
  final String city;
  final String document;
  final DateTime birthDate;
  final UserRole role;
  final String? licenseNumber;
  final DateTime? licenseExpiry;
  final String licenseType;
}

abstract interface class AuthRepository {
  Future<AuthSession> login({
    required String email,
    required String password,
    required bool remember,
  });

  Future<AuthSession> register(RegistrationRequest request);

  Future<void> requestPasswordReset(String email);

  Future<void> resendOtp(String phone);

  Future<void> verifyOtp(String code);

  Future<void> resetPassword({required String email, required String password});

  Future<void> logout();
}

/// Default data source for the presentation build. It behaves like a backend:
/// validates credentials, persists accounts and applies realistic latency.
class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository(this._store);

  final SessionStore _store;

  static const _latency = Duration(milliseconds: 750);

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    required bool remember,
  }) async {
    await Future<void>.delayed(_latency);
    final normalized = email.trim().toLowerCase();

    if (normalized == AppConfig.demoEmail &&
        password == AppConfig.demoPassword) {
      final user = MockData.demoUser;
      if (remember) await _store.saveUser(user);
      await _store.setRememberSession(remember);
      await _store.saveToken('demo-token');
      return AuthSession(user: user, token: 'demo-token', remember: remember);
    }

    final account = _store.findDemoAccount(normalized);
    if (account != null && account['password'] == password) {
      final rawProfile = account['profile'];
      if (rawProfile is Map<String, dynamic>) {
        final user = UserProfile.fromJson(rawProfile);
        if (remember) await _store.saveUser(user);
        await _store.setRememberSession(remember);
        return AuthSession(
          user: user,
          token: 'demo-token-${user.id}',
          remember: remember,
        );
      }
    }

    throw const AuthException(
      'Correo o contraseña incorrectos. Revisa tus datos e inténtalo de nuevo.',
    );
  }

  @override
  Future<AuthSession> register(RegistrationRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (_store.findDemoAccount(request.email) != null ||
        request.email.toLowerCase() == AppConfig.demoEmail) {
      throw const AuthException(
        'Ya existe una cuenta con este correo electrónico.',
        code: 'email_in_use',
      );
    }
    if (request.role != UserRole.client &&
        (request.licenseNumber == null || request.licenseExpiry == null)) {
      throw const AuthException(
        'Los conductores y propietarios necesitan una licencia vigente.',
        code: 'license_required',
      );
    }

    final licenseStatus = request.role == UserRole.client
        ? LicenseStatus.notSubmitted
        : LicenseStatus.pendingReview;

    final user = UserProfile(
      id: 'person-${DateTime.now().millisecondsSinceEpoch}',
      firstName: request.firstName.trim(),
      lastName: request.lastName.trim(),
      email: request.email.trim(),
      phone: request.phone.trim(),
      city: request.city,
      document: request.document.trim(),
      roles: {request.role},
      licenseStatus: licenseStatus,
      memberSince: DateTime.now(),
      tripCount: 0,
    );

    await _store.saveDemoAccount(
      email: request.email,
      password: request.password,
      profile: user,
    );
    return AuthSession(
      user: user,
      token: 'demo-token-${user.id}',
      remember: true,
    );
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await Future<void>.delayed(_latency);
    if (email.trim().isEmpty) {
      throw const AuthException('Introduce tu correo electrónico.');
    }
  }

  @override
  Future<void> resendOtp(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> verifyOtp(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (code != AppConfig.demoOtp) {
      throw const AuthException(
        'El código no es válido o ha expirado. Inténtalo de nuevo.',
        code: 'invalid_otp',
      );
    }
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(_latency);
    final account = _store.findDemoAccount(email);
    if (account == null) {
      // Demo recovery still reports success to avoid account enumeration.
      return;
    }
    final raw = account['profile'];
    if (raw is Map<String, dynamic>) {
      await _store.saveDemoAccount(
        email: email,
        password: password,
        profile: UserProfile.fromJson(raw),
      );
    }
  }

  @override
  Future<void> logout() async {
    await _store.clearSession();
  }
}

/// Firebase-backed authentication handled by the NestJS API.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api, this._store);

  final ApiClient _api;
  final SessionStore _store;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    required bool remember,
  }) async {
    final payload = await _api.post(
      ApiEndpoints.login,
      body: {'identificador': email.trim(), 'contrasena': password},
    );
    final token = '${payload['idToken'] ?? payload['token'] ?? ''}';
    if (token.isEmpty) {
      throw const AuthException('El servidor no devolvió una sesión válida.');
    }
    final profile = await _api.get(ApiEndpoints.profile, token: token);
    final user = _mapProfile(profile, email);
    if (remember) await _store.saveUser(user);
    await _store.saveToken(token);
    await _store.setRememberSession(remember);
    return AuthSession(user: user, token: token, remember: remember);
  }

  @override
  Future<AuthSession> register(RegistrationRequest request) async {
    final payload = {
      'persona': {
        'documento': request.document,
        'nombre': request.firstName,
        'apellido': request.lastName,
        'email': request.email,
        'usuario': request.email.split('@').first,
        'contrasena': request.password,
        'telefono': request.phone,
        'fechaNacimiento': request.birthDate.toIso8601String().substring(0, 10),
        'ciudad': request.city,
        'direccion': 'Por completar',
        'fotoPerfil': 'https://carman.app/avatar/default.png',
      },
      'roles': request.role.label,
      if (request.licenseNumber != null && request.licenseExpiry != null)
        'licencia': {
          'numeroDocumento': request.licenseNumber,
          'fechaExpiracion': request.licenseExpiry!.toIso8601String().substring(
            0,
            10,
          ),
          'tipoLicencia': request.licenseType,
          'fotoLicencia': 'https://carman.app/licencias/pendiente.jpg',
        },
    };
    await _api.post(ApiEndpoints.register, body: payload);
    return login(
      email: request.email,
      password: request.password,
      remember: true,
    );
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    // Firebase handles the email delivery from the dashboard / future endpoint.
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> resendOtp(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> verifyOtp(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> logout() async {
    await _store.clearSession();
  }

  UserProfile _mapProfile(Map<String, dynamic> json, String email) {
    final roles = <UserRole>{};
    final rawRoles = json['roles'];
    if (rawRoles is Map<String, dynamic>) {
      if (rawRoles['cliente'] == true) roles.add(UserRole.client);
      if (rawRoles['propietario'] == true) roles.add(UserRole.owner);
      if (rawRoles['conductor'] == true) roles.add(UserRole.driver);
      if (rawRoles['admin'] == true || rawRoles['administrador'] == true) {
        roles.add(UserRole.admin);
      }
    }
    if (roles.isEmpty) roles.add(UserRole.client);

    final rawName = '${json['nombre'] ?? json['firstName'] ?? 'Usuario'}';
    final rawLast = '${json['apellido'] ?? json['lastName'] ?? ''}';
    return UserProfile(
      id: '${json['idPersona'] ?? json['id'] ?? 'live-user'}',
      firstName: rawName,
      lastName: rawLast,
      email: '${json['email'] ?? email}',
      phone: '${json['telefono'] ?? json['phone'] ?? ''}',
      city: '${json['ciudad'] ?? json['city'] ?? 'Cartagena'}',
      document: '${json['documento'] ?? json['document'] ?? ''}',
      avatarUrl: json['fotoPerfil'] as String?,
      roles: roles,
      // The profile endpoint does not expose licence state yet; treat existing
      // driver/owner accounts as verified and clients as not submitted.
      licenseStatus:
          roles.contains(UserRole.driver) || roles.contains(UserRole.owner)
          ? LicenseStatus.approved
          : LicenseStatus.notSubmitted,
      memberSince: DateTime.tryParse('${json['fechaHoraRegistro'] ?? ''}'),
      tripCount: 0,
    );
  }
}
