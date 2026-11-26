import 'dart:convert';

import 'package:carman_app/core/errors/app_exception.dart';
import 'package:carman_app/data/local/session_store.dart';
import 'package:carman_app/data/models/vehicle.dart';
import 'package:carman_app/data/remote/api_client.dart';
import 'package:carman_app/data/repositories/vehicle_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SessionStore(await SharedPreferences.getInstance());
  });

  VehicleDraft draft({
    int? pickup,
    int? delivery,
    List<String> photos = const [],
    String? document,
  }) => VehicleDraft(
    brand: 'Marca de prueba',
    model: 'Modelo de prueba',
    year: 2024,
    plate: 'PRB123',
    seats: 4,
    category: VehicleCategory.suv,
    fuel: FuelType.gasoline,
    transmission: TransmissionType.manual,
    pricePerDay: 120.5,
    pricePerHour: 0,
    city: 'Ciudad de prueba',
    location: 'Centro',
    description: 'Vehículo de prueba',
    idPuntoRecogida: pickup,
    idPuntoEntrega: delivery,
    fotos: photos,
    tarjetaPropiedad: document,
  );

  test(
    'lee puntos reales y sus DECIMAL sin fabricar distancia o tarifa',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/puntos-autorizados');
        expect(request.url.queryParameters, {'ciudad': 'Ciudad de prueba'});
        return http.Response(
          jsonEncode([
            {
              'idPunto': 7,
              'nombre': 'Punto de prueba',
              'ciudad': 'Ciudad de prueba',
              'direccion': 'Dirección de prueba',
              'latitud': '4.600000',
              'longitud': '-74.100000',
            },
          ]),
          200,
        );
      });
      final repository = ApiVehicleRepository(
        ApiClient(client: client, baseUrl: 'https://example.test'),
        store,
      );
      final points = await repository.fetchPickupPoints('Ciudad de prueba');
      expect(points.single.id, '7');
      expect(points.single.latitude, 4.6);
      expect(points.single.longitude, -74.1);
      expect(points.single.hasDeliveryDetails, isFalse);
      client.close();
    },
  );

  test('no publica IDs, fotos ni documentos ficticios', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('{}', 200);
    });
    final repository = ApiVehicleRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'),
      store,
    );
    await expectLater(
      repository.publishVehicle(draft()),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'vehicle_documents_required',
        ),
      ),
    );
    expect(requests, 0);
    client.close();
  });

  test(
    'no transforma un fallo de red o sesión en un vehículo inexistente',
    () async {
      await store.saveToken('firebase-test-token');
      final client = MockClient((request) async {
         expect(request.url.path, '/vehiculos/catalogo/19');
        return http.Response('{"message":"No autorizado"}', 403);
      });
      final repository = ApiVehicleRepository(
        ApiClient(client: client, baseUrl: 'https://example.test'),
        store,
      );
      await expectLater(
        repository.fetchById('19'),
        throwsA(isA<AuthException>()),
      );
      client.close();
    },
  );

  test('envía solo campos del esquema y consulta el vehículo creado', () async {
    await store.saveToken('firebase-test-token');
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        expect(request.url.path, '/vehiculos');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['idPuntoRecogida'], 7);
        expect(body['idPuntoEntrega'], 8);
        expect(body['precioPorDia'], 120.5);
        expect(body['fotos'], ['https://example.com/foto.jpg']);
        expect(body['tarjetaPropiedad'], 'https://example.com/tarjeta.jpg');
        expect(body.containsKey('precioHora'), isFalse);
        expect(body.containsKey('ciudad'), isFalse);
        return http.Response('{"idVehiculo":19}', 201);
      }
      expect(request.url.path, '/vehiculos/19');
      return http.Response(
        jsonEncode({
          'idVehiculo': 19,
          'marca': 'Marca de prueba',
          'modelo': 'Modelo de prueba',
          'precioPorDia': '120.50',
          'estado': 'Activo',
          'fotos': '["https://example.com/foto.jpg"]',
          'ciudad': 'Ciudad de prueba',
        }),
        200,
      );
    });
    final repository = ApiVehicleRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'),
      store,
    );
    final vehicle = await repository.publishVehicle(
      draft(
        pickup: 7,
        delivery: 8,
        photos: ['https://example.com/foto.jpg'],
        document: 'https://example.com/tarjeta.jpg',
      ),
    );
    expect(vehicle.id, '19');
    expect(vehicle.pricePerDay, 120.5);
    client.close();
  });
}
