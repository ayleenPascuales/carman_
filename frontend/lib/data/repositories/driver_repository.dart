import '../../core/errors/app_exception.dart';
import '../local/session_store.dart';
import '../mock/driver_mock_data.dart';
import '../models/driver_models.dart';
import '../remote/api_client.dart';
import '../remote/api_endpoints.dart';
import '../remote/api_mappers.dart';

abstract interface class DriverRepository {
  Future<DriverDashboardData> fetchDashboard({int page = 1});

  Future<void> setAvailability(bool available);

  Future<void> acceptTrip(String id);

  Future<void> startTrip(String id);

  Future<void> completeTrip(String id);

  Future<void> declineTrip(String id);
}

class DemoDriverRepository implements DriverRepository {
  DemoDriverRepository() : _trips = DriverMockData.trips();

  final List<DriverTrip> _trips;
  DriverAvailability _availability = DriverAvailability.online;
  DriverStats _stats = DriverMockData.stats;

  @override
  Future<DriverDashboardData> fetchDashboard({int page = 1}) async {
    await Future<void>.delayed(const Duration(milliseconds: 380));
    return DriverDashboardData(
      stats: _stats,
      availability: _availability,
      trips: [..._trips],
    );
  }

  @override
  Future<void> setAvailability(bool available) async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    _availability = available
        ? DriverAvailability.online
        : DriverAvailability.offline;
  }

  @override
  Future<void> acceptTrip(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    _update(id, DriverTripStatus.accepted);
    _availability = DriverAvailability.online;
  }

  @override
  Future<void> startTrip(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    _update(id, DriverTripStatus.inProgress);
    _availability = DriverAvailability.onTrip;
  }

  @override
  Future<void> completeTrip(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    final trip = _trips.firstWhere((trip) => trip.id == id);
    _update(id, DriverTripStatus.completed);
    _stats = _stats.copyWith(
      tripsToday: _stats.tripsToday + 1,
      earningsToday: _stats.earningsToday + trip.earnings,
      earningsWeek: _stats.earningsWeek + trip.earnings,
      completedTotal: _stats.completedTotal + 1,
    );
    _availability = DriverAvailability.online;
  }

  @override
  Future<void> declineTrip(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _update(id, DriverTripStatus.cancelled);
  }

  void _update(String id, DriverTripStatus status) {
    final index = _trips.indexWhere((trip) => trip.id == id);
    if (index == -1) {
      throw const ValidationException('No encontramos este servicio.');
    }
    _trips[index] = _trips[index].copyWith(status: status);
  }
}

class ApiDriverRepository implements DriverRepository {
  ApiDriverRepository(this._api, this._store);

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
  Future<DriverDashboardData> fetchDashboard({int page = 1}) async {
    if (page < 1 || page > 9999) {
      throw const ValidationException('La página no es válida.');
    }
    final payload = await _api.get(
      ApiEndpoints.driverTrips,
      token: _token(),
      query: {'pagina': '$page'},
    );
    return ApiMappers.driverDashboard(payload);
  }

  @override
  Future<void> setAvailability(bool available) async {
    await _api.patch(
      ApiEndpoints.driverAvailability,
      token: _token(),
      body: {'disponibilidad': available},
    );
  }

  @override
  Future<void> acceptTrip(String id) async {
    await _api.patch(
      ApiEndpoints.driverAccept(id),
      token: _token(),
      body: {'aceptar': true},
    );
  }

  @override
  Future<void> startTrip(String id) async {
    await _api.patch(ApiEndpoints.driverStart(id), token: _token());
  }

  @override
  Future<void> completeTrip(String id) async {
    await _api.patch(ApiEndpoints.driverComplete(id), token: _token());
  }

  @override
  Future<void> declineTrip(String id) async {
    await _api.patch(
      ApiEndpoints.driverDecline(id),
      token: _token(),
      body: {'aceptar': false},
    );
  }
}
