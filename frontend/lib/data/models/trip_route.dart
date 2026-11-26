import 'vehicle.dart';

class RoutePosition {
  const RoutePosition(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class TripRoute {
  const TripRoute({
    required this.origin,
    required this.destination,
    required this.trace,
    required this.distanceKm,
    required this.durationMinutes,
    required this.estimatedPrice,
    required this.provider,
  });

  final PickupPoint origin;
  final PickupPoint destination;
  final List<RoutePosition> trace;
  final double distanceKm;
  final int durationMinutes;
  final double estimatedPrice;
  final String provider;

  static double _number(Object? value) => double.tryParse('$value') ?? 0;

  static PickupPoint _point(Map<String, dynamic> raw) => PickupPoint(
    id: '${raw['idPunto']}',
    name: '${raw['nombre'] ?? 'Punto autorizado'}',
    city: '',
    address: '${raw['direccion'] ?? ''}',
    distance: 0,
    latitude: _number(raw['latitud']),
    longitude: _number(raw['longitud']),
  );

  factory TripRoute.fromJson(Map<String, dynamic> raw) {
    final trace = raw['trayectoria'];
    return TripRoute(
      origin: _point(raw['origen'] as Map<String, dynamic>),
      destination: _point(raw['destino'] as Map<String, dynamic>),
      trace: trace is List
          ? trace.whereType<List>().where((point) => point.length == 2)
              .map((point) => RoutePosition(
                    _number(point[1]), _number(point[0]),
                  )).toList()
          : const [],
      distanceKm: raw['distanciaKm'] == null ? -1 : _number(raw['distanciaKm']),
      durationMinutes: raw['duracionMinutos'] == null ? -1 : _number(raw['duracionMinutos']).toInt(),
      estimatedPrice: raw['tarifa'] is Map<String, dynamic>
          ? _number((raw['tarifa'] as Map<String, dynamic>)['precioEstimado'])
          : 0,
      provider: '${raw['proveedor'] ?? ''}',
    );
  }
}

class SharedLocation {
  const SharedLocation({
    required this.role,
    required this.position,
    required this.updatedAt,
  });

  final String role;
  final RoutePosition position;
  final DateTime? updatedAt;
}

class LocationSnapshot {
  const LocationSnapshot({
    required this.available,
    required this.sharing,
    required this.positions,
  });

  final bool available;
  final bool sharing;
  final List<SharedLocation> positions;

  factory LocationSnapshot.fromJson(Map<String, dynamic> raw) {
    final positions = raw['posiciones'];
    return LocationSnapshot(
      available: raw['disponible'] == true,
      sharing: raw['compartiendo'] == true,
      positions: positions is List
          ? positions.whereType<Map<String, dynamic>>()
              .map((point) => SharedLocation(
                    role: '${point['rol'] ?? ''}',
                    position: RoutePosition(
                      double.tryParse('${point['latitud']}') ?? 0,
                      double.tryParse('${point['longitud']}') ?? 0,
                    ),
                    updatedAt: DateTime.tryParse('${point['compartidaEn']}'),
                  )).toList()
          : const [],
    );
  }
}
