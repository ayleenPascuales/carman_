import '../../core/errors/app_exception.dart';
import '../local/session_store.dart';
import '../mock/mock_data.dart';
import '../models/owner_models.dart';
import '../remote/api_client.dart';
import '../remote/api_endpoints.dart';
import '../remote/api_mappers.dart';

abstract interface class OwnerRepository {
  Future<OwnerDashboardData> fetchDashboard();
}

class DemoOwnerRepository implements OwnerRepository {
  @override
  Future<OwnerDashboardData> fetchDashboard() async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    final listings = <OwnerListing>[];
    for (final meta in MockData.ownerVehicles) {
      for (final vehicle in MockData.vehicles) {
        if (vehicle.id == meta.vehicleId) {
          listings.add(OwnerListing(meta: meta, vehicle: vehicle));
          break;
        }
      }
    }
    return OwnerDashboardData(stats: MockData.ownerStats, listings: listings);
  }
}

class ApiOwnerRepository implements OwnerRepository {
  ApiOwnerRepository(this._api, this._store);

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
  Future<OwnerDashboardData> fetchDashboard() async {
    try {
      final payload = await _api.get(
        ApiEndpoints.ownerSummary,
        token: _token(),
      );
      return ApiMappers.ownerDashboard(payload);
    } on AppException {
      // The summary endpoint is optional while the backend is being built.
      // Fall back to the already available vehicle listing.
      final payload = await _api.get(ApiEndpoints.myVehicles, token: _token());
      final raw = payload['vehiculos'] ?? payload['data'];
      if (raw is! List) {
        throw const AppException(
          'No se pudo cargar el panel de propietario.',
          code: 'invalid_owner_dashboard',
        );
      }
      return ApiMappers.ownerDashboard({'vehiculos': raw});
    }
  }
}
