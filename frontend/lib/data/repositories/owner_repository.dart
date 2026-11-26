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
    final payload = await _api.get(ApiEndpoints.myVehicles, token: _token());
    final raw = payload['vehiculos'] ?? payload['data'];
    if (raw is! List || raw.any((item) => item is! Map<String, dynamic>)) {
      throw const AppException(
        'No se pudo cargar el inventario del propietario.',
        code: 'invalid_owner_dashboard',
      );
    }
    return ApiMappers.ownerDashboard({'vehiculos': raw});
  }

  Future<Map<String, dynamic>> fetchVehicleDetail(String id) async {
    final payload = await _api.get(ApiEndpoints.vehicle(id), token: _token());
    final detail = payload['vehiculo'] ?? payload;
    if (detail is! Map<String, dynamic> || '${detail['idVehiculo']}' != id) {
      throw const AppException('El detalle del vehículo no es válido.',
          code: 'invalid_owner_vehicle');
    }
    return detail;
  }

  Future<Map<String, dynamic>> updateVehicle(String id,
      {String? description, double? pricePerDay}) async {
    if (description == null && pricePerDay == null) {
      throw const ValidationException('No hay cambios para guardar.');
    }
    if (pricePerDay != null && (!pricePerDay.isFinite || pricePerDay <= 0 ||
        pricePerDay > 99999999.99)) {
      throw const ValidationException('La tarifa diaria no es válida.');
    }
    final changes = <String, dynamic>{};
    if (description != null) changes['descripcion'] = description;
    if (pricePerDay != null) changes['precioPorDia'] = pricePerDay;
    await _api.patch(ApiEndpoints.vehicle(id), token: _token(), body: changes);
    final detail = await _readAfterMutation(id);
    if (description != null && detail['descripcion'] != description ||
        pricePerDay != null &&
            double.tryParse('${detail['precioPorDia']}') != pricePerDay) {
      throw const AppException(
          'El cambio pudo guardarse, pero aún no se refleja. '
          'Actualiza el inventario antes de reintentar.',
          code: 'owner_mutation_unconfirmed');
    }
    return detail;
  }

  Future<Map<String, dynamic>> changeVehicleState(String id, bool active) async {
    await _api.patch('${ApiEndpoints.vehicle(id)}/estado', token: _token(),
        body: {'estado': active ? 'Activo' : 'inactivo'});
    final detail = await _readAfterMutation(id);
    if (detail['estado'] != (active ? 'Activo' : 'inactivo')) {
      throw const AppException(
          'El estado pudo cambiar, pero aún no se refleja. '
          'Actualiza el inventario antes de reintentar.',
          code: 'owner_mutation_unconfirmed');
    }
    return detail;
  }

  Future<Map<String, dynamic>> requestReview(String id, String reason) async {
    final trimmed = reason.trim();
    if (trimmed.isEmpty || trimmed.length > 500) {
      throw const ValidationException('Indica un motivo de hasta 500 caracteres.');
    }
    await _api.post('${ApiEndpoints.vehicle(id)}/solicitar-revision',
        token: _token(), body: {'motivoSolicitud': trimmed});
    final detail = await _readAfterMutation(id);
    if (detail['estado_solicitud_revision'] != 'Pendiente') {
      throw const AppException(
          'La solicitud pudo guardarse, pero aún no se refleja. '
          'Consulta el detalle antes de repetirla.',
          code: 'owner_mutation_unconfirmed');
    }
    return detail;
  }

  Future<Map<String, dynamic>> _readAfterMutation(String id) async {
    try {
      return await fetchVehicleDetail(id);
    } on AuthException {
      rethrow;
    } on AppException {
      throw const AppException(
          'La operación pudo guardarse, pero no se pudo consultar el resultado. '
          'Actualiza el inventario antes de repetirla.',
          code: 'owner_mutation_unconfirmed');
    }
  }
}
