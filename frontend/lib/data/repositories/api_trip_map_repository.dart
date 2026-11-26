import '../../core/errors/app_exception.dart';
import '../local/session_store.dart';
import '../models/trip_route.dart';
import '../remote/api_client.dart';
import '../remote/api_endpoints.dart';

class ApiTripMapRepository {
  ApiTripMapRepository(this._api, this._store);

  final ApiClient _api;
  final SessionStore _store;

  String _token() {
    final token = _store.loadToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('Inicia sesión para consultar el viaje.');
    }
    return token;
  }

  Future<TripRoute> getRoute(String id) async {
    final payload = await _api.get(ApiEndpoints.tripRoute(id), token: _token());
    return TripRoute.fromJson(payload);
  }

  Future<Map<String, dynamic>> nearestPickup(
      String vehicleId, [RoutePosition? position]) =>
      position == null
          ? _api.get(ApiEndpoints.nearestPickup(vehicleId), token: _token())
          : _api.post(
        ApiEndpoints.nearestPickup(vehicleId),
        token: _token(),
        body: {
          'latitud': position.latitude,
          'longitud': position.longitude,
        },
      );

  Future<LocationSnapshot> getLocation(String id) async {
    final payload = await _api.get(ApiEndpoints.tripLocation(id), token: _token());
    return LocationSnapshot.fromJson(payload);
  }

  Future<void> shareLocation(String id, RoutePosition position) async {
    await _api.post(
      ApiEndpoints.tripLocation(id),
      token: _token(),
      body: {
        'latitud': position.latitude,
        'longitud': position.longitude,
        'consentimiento': true,
      },
    );
  }

  Future<void> stopSharing(String id) async {
    await _api.delete(ApiEndpoints.tripLocation(id), token: _token());
  }
}
