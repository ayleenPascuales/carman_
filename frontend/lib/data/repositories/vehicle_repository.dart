import 'package:material_ui/material_ui.dart';

import '../../core/errors/app_exception.dart';
import '../local/session_store.dart';
import '../mock/mock_data.dart';
import '../models/vehicle.dart';
import '../models/vehicle_query.dart';
import '../remote/api_client.dart';
import '../remote/api_endpoints.dart';

class VehicleDraft {
  const VehicleDraft({
    required this.brand,
    required this.model,
    required this.year,
    required this.plate,
    required this.seats,
    required this.category,
    required this.fuel,
    required this.transmission,
    required this.pricePerDay,
    required this.pricePerHour,
    required this.city,
    required this.location,
    required this.description,
  });

  final String brand;
  final String model;
  final int year;
  final String plate;
  final int seats;
  final VehicleCategory category;
  final FuelType fuel;
  final TransmissionType transmission;
  final double pricePerDay;
  final double pricePerHour;
  final String city;
  final String location;
  final String description;

  Map<String, dynamic> toApiJson() => {
    'marca': brand,
    'modelo': model,
    'anio': year,
    'placa': plate,
    'capacidad': seats,
    'tipoVehiculo': category.label,
    'combustible': fuel.label,
    'transmision': transmission.label,
    'precioDia': pricePerDay,
    'precioHora': pricePerHour,
    'ciudad': city,
    'ubicacion': location,
    'descripcion': description,
    'fotos': <String>[],
  };
}

abstract interface class VehicleRepository {
  Future<List<Vehicle>> fetchCatalog(VehicleQuery query);

  Future<Vehicle?> fetchById(String id);

  Future<List<PickupPoint>> fetchPickupPoints(String city);

  Future<List<Vehicle>> fetchOwnerVehicles(String ownerId);

  Future<Vehicle> publishVehicle(VehicleDraft draft);
}

class DemoVehicleRepository implements VehicleRepository {
  final List<Vehicle> _vehicles = [...MockData.vehicles];

  @override
  Future<List<Vehicle>> fetchCatalog(VehicleQuery query) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final matches = _vehicles.where(query.matches).toList();
    return query.sortVehicles(matches);
  }

  @override
  Future<Vehicle?> fetchById(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    for (final vehicle in _vehicles) {
      if (vehicle.id == id) return vehicle;
    }
    return null;
  }

  @override
  Future<List<PickupPoint>> fetchPickupPoints(String city) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return MockData.pickupPoints.where((point) => point.city == city).toList();
  }

  @override
  Future<List<Vehicle>> fetchOwnerVehicles(String ownerId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _vehicles.where((vehicle) => vehicle.ownerId == ownerId).toList();
  }

  @override
  Future<Vehicle> publishVehicle(VehicleDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (_vehicles.any((vehicle) => vehicle.plate == draft.plate)) {
      throw const ValidationException('Ya existe un vehículo con esa placa.');
    }
    final vehicle = Vehicle(
      id: 'veh-${DateTime.now().millisecondsSinceEpoch}',
      brand: draft.brand,
      model: draft.model,
      year: draft.year,
      category: draft.category,
      fuel: draft.fuel,
      transmission: draft.transmission,
      seats: draft.seats,
      pricePerDay: draft.pricePerDay,
      pricePerHour: draft.pricePerHour,
      rating: 5,
      tripCount: 0,
      ownerName: MockData.demoUser.fullName,
      ownerAvatarAsset: MockData.demoUser.avatarAsset,
      ownerBadge: OwnerBadge.newHost,
      locationName: draft.location,
      city: draft.city,
      photos: [MockData.vehicles[0].primaryPhoto],
      description: draft.description,
      plate: draft.plate,
      ownerId: MockData.demoUser.id,
      pickupPoint: MockData.pickupPoints.firstWhere(
        (point) => point.city == draft.city,
        orElse: () => MockData.pickupPoints.first,
      ),
      features: const [
        VehicleFeature(
          icon: Icons.key_rounded,
          title: 'Apertura con app',
          description: 'Llave digital activada desde Carman.',
        ),
        VehicleFeature(
          icon: Icons.verified_user_rounded,
          title: 'Seguro incluido',
          description: 'Cobertura Allianz para cada reserva.',
        ),
      ],
    );
    _vehicles.insert(0, vehicle);
    MockData.vehicles.insert(0, vehicle);
    return vehicle;
  }
}

class ApiVehicleRepository implements VehicleRepository {
  ApiVehicleRepository(this._api, this._store);

  final ApiClient _api;
  final SessionStore _store;

  String? get _token => _store.loadToken();

  String _requireToken() {
    final token = _token;
    if (token == null || token.isEmpty) {
      throw const AuthException('La sesión expiró. Inicia sesión de nuevo.');
    }
    return token;
  }

  @override
  Future<List<Vehicle>> fetchCatalog(VehicleQuery query) async {
    final queryParameters = <String, String>{};
    query.toApiJson().forEach((key, value) {
      if (value != null) queryParameters[key] = '$value';
    });
    final payload = await _api.get(
      ApiEndpoints.vehicleCatalog,
      token: _token,
      query: queryParameters,
    );
    final raw = payload['vehiculos'] ?? payload['data'] ?? payload['items'];
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(Vehicle.fromJson)
          .toList();
    }
    throw const AppException(
      'El catálogo no devolvió datos válidos.',
      code: 'invalid_catalog',
    );
  }

  @override
  Future<Vehicle?> fetchById(String id) async {
    try {
      final payload = await _api.get(
        ApiEndpoints.vehicle(id),
        token: _requireToken(),
      );
      final raw = payload['vehiculo'] ?? payload;
      if (raw is Map<String, dynamic>) return Vehicle.fromJson(raw);
      return null;
    } on AppException {
      return null;
    }
  }

  @override
  Future<List<PickupPoint>> fetchPickupPoints(String city) async {
    await Future<void>.delayed(Duration.zero);
    return MockData.pickupPoints.where((point) => point.city == city).toList();
  }

  @override
  Future<List<Vehicle>> fetchOwnerVehicles(String ownerId) async {
    final payload = await _api.get(
      ApiEndpoints.myVehicles,
      token: _requireToken(),
    );
    final raw = payload['vehiculos'] ?? payload['data'];
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(Vehicle.fromJson)
          .toList();
    }
    return const [];
  }

  @override
  Future<Vehicle> publishVehicle(VehicleDraft draft) async {
    final payload = await _api.post(
      ApiEndpoints.vehicles,
      token: _requireToken(),
      body: {
        ...draft.toApiJson(),
        'idPuntoRecogida': 1,
        'idPuntoEntrega': 1,
        'fotos': ['https://carman.app/vehiculos/pendiente.jpg'],
        'tarjetaPropiedad': 'https://carman.app/documentos/pendiente.pdf',
      },
    );
    final raw = payload['vehiculo'] ?? payload;
    if (raw is Map<String, dynamic>) return Vehicle.fromJson(raw);
    throw const AppException(
      'El vehículo se creó, pero la respuesta no pudo interpretarse.',
      code: 'invalid_vehicle',
    );
  }
}
