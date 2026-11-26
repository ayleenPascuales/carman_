import 'vehicle.dart';

enum RentalMode {
  hourly('Por horas', 'Tarifa flexible'),
  daily('Por días', 'Mejor tarifa');

  const RentalMode(this.label, this.subtitle);

  final String label;
  final String subtitle;
}

enum SortOption {
  relevance('Relevancia'),
  priceAsc('Precio: menor a mayor'),
  priceDesc('Precio: mayor a menor'),
  rating('Mejor valorados'),
  distance('Más cercanos');

  const SortOption(this.label);

  final String label;
}

class VehicleQuery {
  const VehicleQuery({
    this.text = '',
    this.city = 'Cartagena',
    this.category = VehicleCategory.all,
    this.mode = RentalMode.daily,
    this.startAt,
    this.endAt,
    this.maxPrice,
    this.transmission,
    this.fuel,
    this.minSeats,
    this.instantBookOnly = false,
    this.freeCancellationOnly = false,
    this.sort = SortOption.relevance,
    this.pickupPointName = 'Cartagena · Centro',
  });

  final String text;
  final String city;
  final VehicleCategory category;
  final RentalMode mode;
  final DateTime? startAt;
  final DateTime? endAt;
  final double? maxPrice;
  final TransmissionType? transmission;
  final FuelType? fuel;
  final int? minSeats;
  final bool instantBookOnly;
  final bool freeCancellationOnly;
  final SortOption sort;
  final String pickupPointName;

  int get activeFilterCount {
    var count = 0;
    if (category != VehicleCategory.all) count++;
    if (maxPrice != null) count++;
    if (transmission != null) count++;
    if (fuel != null) count++;
    if (minSeats != null) count++;
    if (instantBookOnly) count++;
    if (freeCancellationOnly) count++;
    return count;
  }

  String get priceUnit => mode == RentalMode.hourly ? 'hora' : 'día';

  VehicleQuery copyWith({
    String? text,
    String? city,
    VehicleCategory? category,
    RentalMode? mode,
    DateTime? startAt,
    DateTime? endAt,
    double? maxPrice,
    TransmissionType? transmission,
    FuelType? fuel,
    int? minSeats,
    bool? instantBookOnly,
    bool? freeCancellationOnly,
    SortOption? sort,
    String? pickupPointName,
    bool clearMaxPrice = false,
    bool clearTransmission = false,
    bool clearFuel = false,
    bool clearSeats = false,
    bool clearDates = false,
  }) {
    return VehicleQuery(
      text: text ?? this.text,
      city: city ?? this.city,
      category: category ?? this.category,
      mode: mode ?? this.mode,
      startAt: clearDates ? null : (startAt ?? this.startAt),
      endAt: clearDates ? null : (endAt ?? this.endAt),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      transmission: clearTransmission
          ? null
          : (transmission ?? this.transmission),
      fuel: clearFuel ? null : (fuel ?? this.fuel),
      minSeats: clearSeats ? null : (minSeats ?? this.minSeats),
      instantBookOnly: instantBookOnly ?? this.instantBookOnly,
      freeCancellationOnly: freeCancellationOnly ?? this.freeCancellationOnly,
      sort: sort ?? this.sort,
      pickupPointName: pickupPointName ?? this.pickupPointName,
    );
  }

  bool matches(Vehicle vehicle) {
    if (city.isNotEmpty && vehicle.city != city) return false;
    if (text.trim().isNotEmpty) {
      final needle = text.toLowerCase();
      final haystack =
          '${vehicle.brand} ${vehicle.model} ${vehicle.categoryLabel} '
                  '${vehicle.fuel.label} ${vehicle.locationName}'
              .toLowerCase();
      if (!haystack.contains(needle)) return false;
    }
    if (category != VehicleCategory.all && vehicle.category != category) {
      return false;
    }
    if (maxPrice != null) {
      final rate = mode == RentalMode.hourly
          ? vehicle.pricePerHour
          : vehicle.pricePerDay;
      if (rate > maxPrice!) return false;
    }
    if (transmission != null && vehicle.transmission != transmission) {
      return false;
    }
    if (fuel != null && vehicle.fuel != fuel) return false;
    if (minSeats != null && vehicle.seats < minSeats!) return false;
    if (instantBookOnly && !vehicle.instantBook) return false;
    if (freeCancellationOnly && !vehicle.freeCancellation) return false;
    return true;
  }

  List<Vehicle> sortVehicles(List<Vehicle> vehicles) {
    final sorted = [...vehicles];
    switch (sort) {
      case SortOption.relevance:
        sorted.sort((a, b) {
          if (a.isAvailable != b.isAvailable) return a.isAvailable ? -1 : 1;
          return b.rating.compareTo(a.rating);
        });
      case SortOption.priceAsc:
        sorted.sort((a, b) => _price(a).compareTo(_price(b)));
      case SortOption.priceDesc:
        sorted.sort((a, b) => _price(b).compareTo(_price(a)));
      case SortOption.rating:
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
      case SortOption.distance:
        sorted.sort((a, b) => _distance(a).compareTo(_distance(b)));
    }
    return sorted;
  }

  double _price(Vehicle vehicle) =>
      mode == RentalMode.hourly ? vehicle.pricePerHour : vehicle.pricePerDay;

  double _distance(Vehicle vehicle) => vehicle.pickupPoint?.distance ?? 9;

  int get hoursOrDays {
    if (startAt == null || endAt == null) return 0;
    final difference = endAt!.difference(startAt!);
    if (mode == RentalMode.hourly) {
      final hours = (difference.inMinutes / 60).ceil();
      return hours < 2 ? 2 : hours;
    }
    final days = (difference.inHours / 24).ceil();
    return days < 1 ? 1 : days;
  }

  Map<String, dynamic> toApiJson() => {
    'ciudad': city,
    'categoria': category.name,
    'fechaInicio': startAt == null ? null : _apiDate(startAt!),
    'fechaFin': endAt == null ? null : _apiDate(endAt!),
    'precioMaximo': maxPrice,
    'plazasMinimas': minSeats,
    'orden': switch (sort) {
      SortOption.priceAsc => 'priceAsc',
      SortOption.priceDesc => 'priceDesc',
      _ => 'relevance',
    },
    'texto': text,
  };

  String _apiDate(DateTime value) {
    final date = '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    final time = '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:00';
    return '${date}T$time';
  }
}
