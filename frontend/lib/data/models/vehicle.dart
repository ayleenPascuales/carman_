import 'dart:convert';

import 'package:material_ui/material_ui.dart';

enum VehicleCategory {
  all('Todas', Icons.apps_rounded),
  electric('Eléctricos', Icons.bolt_rounded),
  suv('SUVs', Icons.directions_car_filled_rounded),
  sport('Deportivos', Icons.sports_score_rounded),
  family('Familiares', Icons.airport_shuttle_rounded),
  premium('Gama alta', Icons.workspace_premium_rounded);

  const VehicleCategory(this.label, this.icon);

  final String label;
  final IconData icon;

  static VehicleCategory fromApi(Object? value) {
    final normalized = '$value'.toLowerCase();
    for (final category in values) {
      if (category.name == normalized) return category;
    }
    if (normalized.contains('eléctr') || normalized.contains('electric')) {
      return electric;
    }
    if (normalized.contains('suv') || normalized.contains('camioneta')) {
      return suv;
    }
    if (normalized.contains('deport') || normalized.contains('sport')) {
      return sport;
    }
    if (normalized.contains('famil')) return family;
    if (normalized.contains('premium') || normalized.contains('lujo')) {
      return premium;
    }
    return all;
  }
}

enum FuelType {
  electric('Eléctrico', Icons.bolt_rounded),
  hybrid('Híbrido', Icons.eco_rounded),
  gasoline('Gasolina', Icons.local_gas_station_rounded),
  diesel('Diésel', Icons.local_gas_station_outlined);

  const FuelType(this.label, this.icon);

  final String label;
  final IconData icon;
}

enum TransmissionType {
  automatic('Automático', Icons.settings_rounded),
  manual('Manual', Icons.tune_rounded);

  const TransmissionType(this.label, this.icon);

  final String label;
  final IconData icon;
}

enum OwnerBadge { superhost, verified, newHost, unknown }

class PickupPoint {
  const PickupPoint({
    required this.id,
    required this.name,
    required this.city,
    required this.address,
    required this.distance,
    this.isFree = true,
    this.hasDeliveryDetails = true,
    this.latitude = 10.3910,
    this.longitude = -75.4794,
    this.type = 'hub',
  });

  final String id;
  final String name;
  final String city;
  final String address;
  final double distance;
  final bool isFree;
  final bool hasDeliveryDetails;
  final double latitude;
  final double longitude;
  final String type;

  String get distanceLabel => distance < 1
      ? '${(distance * 1000).round()} m'
      : '${distance.toStringAsFixed(1)} km';
}

class VehicleFeature {
  const VehicleFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class Vehicle {
  const Vehicle({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.category,
    required this.fuel,
    required this.transmission,
    required this.seats,
    required this.pricePerHour,
    required this.pricePerDay,
    required this.rating,
    required this.tripCount,
    required this.ownerName,
    required this.locationName,
    required this.city,
    required this.photos,
    this.ownerAvatarAsset,
    this.ownerBadge = OwnerBadge.verified,
    this.autonomyKm = 0,
    this.acceleration,
    this.luggageLiters,
    this.doors = 5,
    this.traction = 'Delantera',
    this.ecoLabel = 'Etiqueta 0',
    this.pickupPoint,
    this.description = '',
    this.features = const [],
    this.instantBook = true,
    this.freeCancellation = true,
    this.isAvailable = true,
    this.plate = '',
    this.ownerId = 'owner-1',
  });

  final String id;
  final String brand;
  final String model;
  final int year;
  final VehicleCategory category;
  final FuelType fuel;
  final TransmissionType transmission;
  final int seats;
  final double pricePerHour;
  final double pricePerDay;
  final double rating;
  final int tripCount;
  final String ownerName;
  final String? ownerAvatarAsset;
  final OwnerBadge ownerBadge;
  final String locationName;
  final String city;
  final List<String> photos;
  final int autonomyKm;
  final double? acceleration;
  final int? luggageLiters;
  final int doors;
  final String traction;
  final String ecoLabel;
  final PickupPoint? pickupPoint;
  final String description;
  final List<VehicleFeature> features;
  final bool instantBook;
  final bool freeCancellation;
  final bool isAvailable;
  final String plate;
  final String ownerId;

  String get title => '$brand $model';

  String get fullTitle => '$brand $model $year';

  String get shortTitle {
    final parts = model.split(RegExp(r'\s+'));
    final shortModel = parts.take(2).join(' ');
    return '$brand $shortModel';
  }

  String get compactTitle => '$shortTitle $year';

  // Si TiDB no tiene fotos, mostrar el icono neutro del widget; nunca la foto
  // de un automóvil de demostración como si fuera el vehículo real.
  String get primaryPhoto => photos.isNotEmpty ? photos.first : '';

  String get ownerBadgeLabel => switch (ownerBadge) {
    OwnerBadge.superhost => 'Super Anfitrión',
    OwnerBadge.verified => 'Anfitrión Verificado',
    OwnerBadge.newHost => 'Anfitrión Nuevo',
    OwnerBadge.unknown => 'Anfitrión',
  };

  String get ownerFirstName {
    final parts = ownerName.split(' ');
    return parts.length > 1 ? '${parts.first} ${parts[1][0]}.' : ownerName;
  }

  String get categoryLabel =>
      category == VehicleCategory.all ? 'Vehículo' : category.label;

  double priceForHourly(int hours) => hours * pricePerHour;

  double priceForDaily(int days) => days * pricePerDay;

  Vehicle copyWith({
    String? id,
    String? brand,
    String? model,
    int? year,
    VehicleCategory? category,
    FuelType? fuel,
    TransmissionType? transmission,
    int? seats,
    double? pricePerHour,
    double? pricePerDay,
    double? rating,
    int? tripCount,
    String? ownerName,
    String? ownerAvatarAsset,
    OwnerBadge? ownerBadge,
    String? locationName,
    String? city,
    List<String>? photos,
    int? autonomyKm,
    double? acceleration,
    int? luggageLiters,
    int? doors,
    String? traction,
    String? ecoLabel,
    PickupPoint? pickupPoint,
    String? description,
    List<VehicleFeature>? features,
    bool? instantBook,
    bool? freeCancellation,
    bool? isAvailable,
    String? plate,
    String? ownerId,
  }) {
    return Vehicle(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      category: category ?? this.category,
      fuel: fuel ?? this.fuel,
      transmission: transmission ?? this.transmission,
      seats: seats ?? this.seats,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      pricePerDay: pricePerDay ?? this.pricePerDay,
      rating: rating ?? this.rating,
      tripCount: tripCount ?? this.tripCount,
      ownerName: ownerName ?? this.ownerName,
      ownerAvatarAsset: ownerAvatarAsset ?? this.ownerAvatarAsset,
      ownerBadge: ownerBadge ?? this.ownerBadge,
      locationName: locationName ?? this.locationName,
      city: city ?? this.city,
      photos: photos ?? this.photos,
      autonomyKm: autonomyKm ?? this.autonomyKm,
      acceleration: acceleration ?? this.acceleration,
      luggageLiters: luggageLiters ?? this.luggageLiters,
      doors: doors ?? this.doors,
      traction: traction ?? this.traction,
      ecoLabel: ecoLabel ?? this.ecoLabel,
      pickupPoint: pickupPoint ?? this.pickupPoint,
      description: description ?? this.description,
      features: features ?? this.features,
      instantBook: instantBook ?? this.instantBook,
      freeCancellation: freeCancellation ?? this.freeCancellation,
      isAvailable: isAvailable ?? this.isAvailable,
      plate: plate ?? this.plate,
      ownerId: ownerId ?? this.ownerId,
    );
  }

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    final photos = _photosFromApi(json['photos'] ?? json['fotos']);
    final pointJson = json['pickupPoint'] ?? json['puntoRecogida'];
    final fromTiDb = json.containsKey('precioPorDia');
    final dailyPrice =
        _decimal(json['pricePerDay']) ??
        _decimal(json['precioDia']) ??
        _decimal(json['precioPorDia']);
    return Vehicle(
      id: '${json['id'] ?? json['idVehiculo'] ?? ''}',
      brand: '${json['brand'] ?? json['marca'] ?? 'Carman'}',
      model: '${json['model'] ?? json['modelo'] ?? ''}',
      year:
          (json['year'] as num?)?.toInt() ??
          (json['anio'] as num?)?.toInt() ??
          DateTime.now().year,
      category: VehicleCategory.fromApi(
        json['category'] ?? json['tipoVehiculo'],
      ),
      fuel: _fuelFromJson(json['fuel'] ?? json['combustible']),
      transmission: _transmissionFromJson(
        json['transmission'] ?? json['transmision'],
      ),
      seats:
          (json['seats'] as num?)?.toInt() ??
          (json['capacidad'] as num?)?.toInt() ??
          5,
      pricePerHour:
          _decimal(json['pricePerHour']) ??
          _decimal(json['precioHora']) ??
          (fromTiDb ? 0 : 18),
      pricePerDay: dailyPrice ?? (fromTiDb ? 0 : 75),
      rating: (json['rating'] as num?)?.toDouble() ?? (fromTiDb ? 0 : 4.9),
      tripCount:
          (json['tripCount'] as num?)?.toInt() ??
          (json['viajes'] as num?)?.toInt() ??
          0,
      ownerName: '${json['ownerName'] ?? json['anfitrion'] ?? 'Anfitrión'}',
      ownerBadge: fromTiDb ? OwnerBadge.unknown : OwnerBadge.verified,
      locationName:
          '${json['locationName'] ?? json['ubicacion_actual'] ?? json['ubicacion'] ?? ''}',
      // El esquema exportado de vehiculo no guarda ciudad: no atribuirle
      // una ubicación inventada hasta que la API proporcione una.
      city: '${json['city'] ?? json['ciudad'] ?? ''}',
      photos: photos,
      autonomyKm:
          (json['autonomyKm'] as num?)?.toInt() ??
          (json['autonomiaKm'] as num?)?.toInt() ??
          (json['autonomia'] as num?)?.toInt() ??
          0,
      acceleration:
          (json['acceleration'] as num?)?.toDouble() ??
          (json['aceleracion'] as num?)?.toDouble(),
      luggageLiters:
          (json['luggageLiters'] as num?)?.toInt() ??
          (json['maletero'] as num?)?.toInt(),
      traction: '${json['traction'] ?? json['traccion'] ?? 'Delantera'}',
      ecoLabel: '${json['ecoLabel'] ?? json['etiqueta'] ?? 'Etiqueta 0'}',
      instantBook:
          json['instantBook'] as bool? ??
          json['aperturaMovil'] as bool? ??
          !fromTiDb,
      freeCancellation:
          json['freeCancellation'] as bool? ??
          json['cancelacionGratis'] as bool? ??
          !fromTiDb,
      isAvailable:
          json['isAvailable'] as bool? ??
          (!fromTiDb || (json['estado'] == 'Activo' && (dailyPrice ?? 0) > 0)),
      plate: '${json['plate'] ?? json['placa'] ?? ''}',
      description: '${json['description'] ?? json['descripcion'] ?? ''}',
      pickupPoint: pointJson is Map<String, dynamic>
          ? PickupPoint(
              id: '${pointJson['id'] ?? pointJson['idPuntoRecogida'] ?? ''}',
              name: '${pointJson['name'] ?? pointJson['nombre'] ?? ''}',
              city: '${pointJson['city'] ?? pointJson['ciudad'] ?? ''}',
              address:
                  '${pointJson['address'] ?? pointJson['direccion'] ?? ''}',
              distance:
                  (pointJson['distance'] as num?)?.toDouble() ??
                  (pointJson['distancia'] as num?)?.toDouble() ??
                  0.35,
              isFree: pointJson['gratis'] as bool? ?? true,
            )
          : null,
    );
  }

  static double? _decimal(Object? value) => switch (value) {
    num() => value.toDouble(),
    String() => double.tryParse(value),
    _ => null,
  };

  static List<String> _photosFromApi(Object? value) {
    if (value is List) return value.whereType<String>().toList();
    if (value is! String || value.isEmpty) return [];
    // mysql2 serializa las columnas JSON como texto en algunas conexiones.
    if (value.trimLeft().startsWith('[')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded.whereType<String>().toList();
      } on FormatException {
        // Compatibilidad con listas antiguas separadas por comas.
      }
    }
    return value.split(',');
  }

  static FuelType _fuelFromJson(Object? value) {
    final normalized = '${value ?? ''}'.toLowerCase();
    if (normalized.contains('híbrid') || normalized.contains('hybrid')) {
      return FuelType.hybrid;
    }
    if (normalized.contains('gasolina') || normalized.contains('gas')) {
      return FuelType.gasoline;
    }
    if (normalized.contains('diésel') || normalized.contains('diesel')) {
      return FuelType.diesel;
    }
    if (normalized.contains('eléct') || normalized.contains('electric')) {
      return FuelType.electric;
    }
    return FuelType.values.firstWhere(
      (fuel) => fuel.name == normalized,
      orElse: () => FuelType.electric,
    );
  }

  static TransmissionType _transmissionFromJson(Object? value) {
    final normalized = '${value ?? ''}'.toLowerCase();
    if (normalized.contains('manual')) return TransmissionType.manual;
    if (normalized.contains('autom') ||
        normalized.contains('dsg') ||
        normalized.contains('s-tronic')) {
      return TransmissionType.automatic;
    }
    return TransmissionType.automatic;
  }
}
