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
    await _api.patch(
      ApiEndpoints.profile,
      token: _token(),
      body: {
        'nombre': update.firstName.trim(),
        'apellido': update.lastName.trim(),
        'telefono': update.phone.trim(),
        'ciudad': update.city,
      },
    );
    return current.copyWith(
      firstName: update.firstName.trim(),
      lastName: update.lastName.trim(),
      phone: update.phone.trim(),
      city: update.city,
    );
  }

  @override
  Future<UserProfile> submitLicense(
    UserProfile current,
    LicenseSubmission submission,
  ) async {
    await _api.post(
      ApiEndpoints.license,
      token: _token(),
      body: {
        'numeroDocumento': submission.number,
        'fechaExpiracion': submission.expiry.toIso8601String().substring(0, 10),
        'tipoLicencia': submission.type,
        'fotoLicencia': submission.frontImageReference,
        if (submission.backImageReference != null)
          'fotoReverso': submission.backImageReference,
      },
    );
    return current.copyWith(licenseStatus: LicenseStatus.pendingReview);
  }

  @override
  Future<UserProfile> addRole(UserProfile current, UserRole role) async {
    await _api.post(
      ApiEndpoints.roles,
      token: _token(),
      body: {'roles': role.label},
    );
    return current.copyWith(roles: {...current.roles, role});
  }

  @override
  Future<List<Vehicle>> fetchFavorites(Set<String> ids) async {
    if (ids.isEmpty) return const [];
    final vehicles = await Future.wait(
      ids.map((id) async {
        try {
          final payload = await _api.get(
            ApiEndpoints.vehicle(id),
            token: _token(),
          );
          final raw = payload['vehiculo'] ?? payload['data'];
          if (raw is Map<String, dynamic>) return Vehicle.fromJson(raw);
        } on AppException {
          // A favorite that no longer exists should simply disappear.
        }
        return null;
      }),
    );
    return vehicles.whereType<Vehicle>().toList();
  }
}
