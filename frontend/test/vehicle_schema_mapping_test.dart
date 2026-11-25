import 'package:carman_app/data/models/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mapea JSON y DECIMAL del esquema TiDB sin atribuir una ciudad', () {
    final vehicle = Vehicle.fromJson({
      'idVehiculo': 12,
      'marca': 'Marca de prueba',
      'modelo': 'Modelo de prueba',
      'anio': 2024,
      'capacidad': 4,
      'precioPorDia': '89.50',
      'fotos': '["https://example.com/uno.jpg","https://example.com/dos.jpg"]',
    });

    expect(vehicle.pricePerDay, 89.5);
    expect(vehicle.pricePerHour, 0);
    expect(vehicle.rating, 0);
    expect(vehicle.ownerBadgeLabel, 'Anfitrión');
    expect(vehicle.photos, [
      'https://example.com/uno.jpg',
      'https://example.com/dos.jpg',
    ]);
    expect(vehicle.city, isEmpty);
  });

  test('no inventa precio ni disponibilidad si el precio de TiDB es NULL', () {
    final vehicle = Vehicle.fromJson({
      'idVehiculo': 13,
      'precioPorDia': null,
      'estado': 'Activo',
      'fotos': null,
    });
    expect(vehicle.pricePerDay, 0);
    expect(vehicle.isAvailable, isFalse);
    expect(vehicle.primaryPhoto, isEmpty);
    expect(vehicle.instantBook, isFalse);
    expect(vehicle.freeCancellation, isFalse);
  });

  test('conserva el formato de fotos y precios del contrato existente', () {
    final vehicle = Vehicle.fromJson({
      'precioDia': 70,
      'fotos': ['https://example.com/car.jpg'],
      'ciudad': 'Ciudad de prueba',
    });

    expect(vehicle.pricePerDay, 70);
    expect(vehicle.photos, ['https://example.com/car.jpg']);
    expect(vehicle.city, 'Ciudad de prueba');
  });
}
