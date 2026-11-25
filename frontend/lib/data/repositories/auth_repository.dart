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
    this.activated = true,
    this.emailVerified = true,
    this.phoneVerified = true,
    this.smsSent = true,
    this.emailSent = true,
  });

  final UserProfile user;
  final String token;
  final bool remember;
  final bool activated;
  final bool emailVerified;
  final bool phoneVerified;
  final bool smsSent;
  final bool emailSent;
}

class VerificationStatus {
  const VerificationStatus({
    required this.activated,
    required this.emailVerified,
    required this.phoneVerified,
  });

  final bool activated;
  final bool emailVerified;
  final bool phoneVerified;

  factory VerificationStatus.fromJson(Map<String, dynamic> json) =>
      VerificationStatus(
        activated: json['activada'] == true,
        emailVerified: json['correoVerificado'] == true,
        phoneVerified: json['telefonoVerificado'] == true,
      );
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
    this.licensePhotoUrl,
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
  final String? licensePhotoUrl;
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
  Future<VerificationStatus> verificationStatus();
  Future<void> resendEmailVerification();

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
  Future<VerificationStatus> verificationStatus() async =>
      const VerificationStatus(
        activated: true,
        emailVerified: true,
        phoneVerified: true,
      );

  @override
  Future<void> resendEmailVerification() async {
    await Future<void>.delayed(_latency);
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
  String? _pendingToken;

  String _verificationToken() {
    final token = _pendingToken ?? _store.loadToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('Inicia sesión para verificar tu cuenta.');
    }
    return token;
  }

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
    final status = VerificationStatus.fromJson(
      await _api.get(ApiEndpoints.verification, token: token),
    );
    final profile = await _api.get(ApiEndpoints.profile, token: token);
    final user = _mapProfile(profile, email, status);
    if (status.activated) {
      if (remember) await _store.saveUser(user);
      await _store.saveToken(token);
      await _store.setRememberSession(remember);
      _pendingToken = null;
    } else {
      _pendingToken = token;
    }
    return AuthSession(
      user: user,
      token: token,
      remember: remember,
      activated: status.activated,
      emailVerified: status.emailVerified,
      phoneVerified: status.phoneVerified,
      smsSent: status.activated,
    );
  }

  @override
  Future<AuthSession> register(RegistrationRequest request) async {
    if (request.role == UserRole.owner) {
      throw const AppException(
        'Para registrarte como propietario necesitas añadir un vehículo con puntos y documentos reales. Este formulario aún no lo permite.',
        code: 'owner_registration_unavailable',
      );
    }
    if (request.role == UserRole.driver &&
        (request.licenseNumber == null || request.licenseExpiry == null)) {
      throw const AppException(
        'Para registrarte como conductor necesitas una licencia vigente.',
        code: 'license_required',
      );
    }
    if ((request.licenseNumber != null || request.licenseExpiry != null) &&
        (request.licenseNumber == null ||
            request.licenseExpiry == null ||
            request.licensePhotoUrl == null ||
            request.licensePhotoUrl!.isEmpty)) {
      throw const AppException(
        'La licencia necesita una foto real alojada de forma segura antes de registrarla.',
        code: 'license_document_required',
      );
    }
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
          'fotoLicencia': request.licensePhotoUrl,
        },
    };
    final delivery = await _api.post(
      ApiEndpoints.register,
      body: payload,
      timeout: const Duration(seconds: 45),
    );
    // El POST de registro ya confirmó la cuenta: un fallo de login/perfil
    // posterior NO debe invitar a repetirlo y crear un duplicado.
    late final AuthSession session;
    try {
      session = await login(
        email: request.email,
        password: request.password,
        remember: true,
      );
    } catch (_) {
      throw const AuthException(
        'Tu cuenta ya se creó, pero no pudimos abrir la sesión. No repitas el registro: inicia sesión y comprueba el enlace en tu correo.',
      );
    }
    return AuthSession(
      user: session.user,
      token: session.token,
      remember: session.remember,
      activated: session.activated,
      emailVerified: session.emailVerified,
      phoneVerified: session.phoneVerified,
      smsSent: delivery['smsEnviado'] == true,
      emailSent: delivery['correoEnviado'] == true,
    );
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    // Firebase handles the email delivery from the dashboard / future endpoint.
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> resendOtp(String phone) async {
    await _api.post(ApiEndpoints.resendPhone, token: _verificationToken());
  }

  @override
  Future<void> verifyOtp(String code) async {
    await _api.post(
      ApiEndpoints.confirmPhone,
      token: _verificationToken(),
      body: {'codigo': code},
    );
  }

  @override
  Future<VerificationStatus> verificationStatus() async {
    return VerificationStatus.fromJson(
      await _api.get(ApiEndpoints.verification, token: _verificationToken()),
    );
  }

  @override
  Future<void> resendEmailVerification() async {
    await _api.post(ApiEndpoints.resendEmail, token: _verificationToken());
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

  UserProfile _mapProfile(
    Map<String, dynamic> json,
    String email,
    VerificationStatus status,
  ) {
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
    final rawName = '${json['nombre'] ?? json['firstName'] ?? 'Usuario'}';
    final rawLast = '${json['apellido'] ?? json['lastName'] ?? ''}';
    return UserProfile(
      id: '${json['idPersona'] ?? json['id'] ?? 'live-user'}',
      firstName: rawName,
      lastName: rawLast,
      email: '${json['email'] ?? email}',
      phone: '${json['telefono'] ?? json['phone'] ?? ''}',
      city: '${json['ciudad'] ?? json['city'] ?? ''}',
      document: '${json['documento'] ?? json['document'] ?? ''}',
      avatarUrl: (json['fotoPerfil'] as String?)?.isNotEmpty == true
          ? json['fotoPerfil'] as String
          : null,
      roles: roles,
      licenseStatus: LicenseStatus.fromApi(json['licenciaEstado']),
      isEmailVerified: status.emailVerified,
      isPhoneVerified: status.phoneVerified,
      memberSince: DateTime.tryParse('${json['fechaHoraRegistro'] ?? ''}'),
      rating: 0, // persona no expone puntuación; no usar la nota del modo demo.
      tripCount: 0,
    );
  }
}
