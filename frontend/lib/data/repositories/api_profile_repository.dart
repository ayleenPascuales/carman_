import '../../core/errors/app_exception.dart';
import '../local/session_store.dart';
import '../models/user_profile.dart';
import '../models/vehicle.dart';
import '../remote/api_client.dart';
import '../remote/api_endpoints.dart';
import 'profile_repository.dart';

class ApiProfileRepository implements ProfileRepository {
  ApiProfileRepository(this._api, this._store);

  final ApiClient _api;
  final SessionStore _store;

  String _token() {
    final token = _store.loadToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('La sesión expiró. Inicia sesión de nuevo.');
    }
    return token;
  }

  @override
  Future<UserProfile> updateProfile(
    UserProfile current,
    ProfileUpdate update,
  ) async {
    if (update.phone.trim() != current.phone) {
      throw const AppException(
        'El cambio de teléfono necesita una verificación adicional que aún no está disponible.',
        code: 'phone_verification_required',
      );
    }
    await _api.patch(
      ApiEndpoints.profile,
      token: _token(),
      body: {
        'nombre': update.firstName.trim(),
        'apellido': update.lastName.trim(),
        'ciudad': update.city,
      },
    );
    return current.copyWith(
      firstName: update.firstName.trim(),
      lastName: update.lastName.trim(),
      city: update.city,
    );
  }

  @override
  Future<UserProfile> submitLicense(
    UserProfile current,
    LicenseSubmission submission,
  ) async {
    // La UI solo entrega bytes locales o un asset de demostración. No enviar
    // referencias local:// ni imágenes de ejemplo como documentos auténticos.
    throw const AppException(
      'La subida segura de licencias aún no está disponible en el modo API.',
      code: 'license_upload_unavailable',
    );
  }

  @override
  Future<UserProfile> addRole(UserProfile current, UserRole role) async {
    if (role == UserRole.owner) {
      throw const AppException(
        'Para activar el rol de propietario se requiere registrar un vehículo real en la misma solicitud. Este formulario aún no lo permite.',
        code: 'owner_registration_unavailable',
      );
    }
    if (role == UserRole.driver &&
        current.licenseStatus != LicenseStatus.approved) {
      throw const AppException(
        'Para activar el rol de conductor se necesita una licencia vigente registrada.',
        code: 'driver_license_required',
      );
    }
    if (role != UserRole.driver) {
      throw const AppException('Este rol no puede activarse desde esta operación.',
          code: 'unsupported_role');
    }
    await _api.post(
      ApiEndpoints.roles,
      token: _token(),
      body: const <String, dynamic>{},
    );
    final profile = await _api.get(ApiEndpoints.profile, token: _token());
    final roles = profile['roles'];
    if (roles is! Map<String, dynamic> || roles['conductor'] != true) {
      throw const AppException('El rol aún no aparece en tu perfil. Actualiza la sesión.',
          code: 'role_not_confirmed');
    }
    return current.copyWith(roles: {...current.roles, UserRole.driver});
  }

  @override
  Future<List<Vehicle>> fetchFavorites(Set<String> ids) async {
    if (ids.isEmpty) return const [];
    final vehicles = await Future.wait(
      ids.map((id) async {
        try {
          final payload = await _api.get(
            ApiEndpoints.publicVehicle(id),
          );
          final raw = payload['vehiculo'] ?? payload['data'] ?? payload;
          if (raw is Map<String, dynamic>) return Vehicle.fromJson(raw);
        } on AppException catch (error) {
          if (error.code != 'http_404') rethrow;
        }
        return null;
      }),
    );
    return vehicles.whereType<Vehicle>().toList();
  }
}
