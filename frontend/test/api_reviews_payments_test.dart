import 'dart:convert';

import 'package:carman_app/core/errors/app_exception.dart';
import 'package:carman_app/data/local/session_store.dart';
import 'package:carman_app/data/remote/api_client.dart';
import 'package:carman_app/data/repositories/api_booking_repository.dart';
import 'package:carman_app/data/repositories/api_payment_history_repository.dart';
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

  test('envía la reseña del vehículo al endpoint nuevo, sin ID de cliente', () async {
    await store.saveToken('token-de-prueba');
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      expect(request.url.path, '/calificaciones/reservas/12');
      expect(request.headers['Authorization'], 'Bearer token-de-prueba');
      expect(jsonDecode(request.body), {
        'tipoObjetivo': 'Vehiculo',
        'puntuacion': 4,
        'comentario': 'Buen viaje',
      });
      return http.Response('{"idCalificacion":8}', 201);
    });
    final repository = ApiBookingRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'), store,
    );
    await repository.submitReview(
      id: '12', rating: 4, comment: ' Buen viaje ',
    );
    expect(requests, 1); // No reintenta el POST si falla una lectura posterior.
    client.close();
  });

  test('consulta calificaciones públicas antes de atribuir nota al vehículo', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/vehiculos/catalogo/3') {
        return http.Response(jsonEncode({
          'idVehiculo': 3, 'marca': 'Demo', 'modelo': 'Prueba',
          'precioPorDia': '100.00',
        }), 200);
      }
      expect(request.url.path, '/calificaciones/vehiculo/3');
      return http.Response(
        '{"promedio":4.5,"totalCalificaciones":2,"calificaciones":[]}',
        200,
      );
    });
    final repository = ApiVehicleRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'), store,
    );
    final vehicle = await repository.fetchById('3');
    expect(vehicle?.rating, 4.5);
    expect(vehicle?.reviewCount, 2);
    expect(vehicle?.tripCount, 0);
    client.close();
  });

  test('bloquea la consulta del historial sin sesión', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('{}', 200);
    });
    final repository = ApiPaymentHistoryRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'), store,
    );
    await expectLater(repository.fetch(), throwsA(isA<AuthException>()));
    expect(requests, 0);
    client.close();
  });

  test('consulta historial protegido y descarta campos ajenos al contrato', () async {
    await store.saveToken('token-de-prueba');
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/pagos/historial');
      expect(request.headers['Authorization'], 'Bearer token-de-prueba');
      return http.Response(jsonEncode({
        'pagos': [{
          'idPago': 4, 'idReserva': 12, 'monto': '102.50',
          'estadoPago': 'Pendiente', 'tipoPago': 'Anticipo',
          'fechaHoraPago': '2026-11-25T12:00:00Z',
          'referenciaWompi': 'privada-de-prueba',
          'nombrePropietario': 'no mostrar',
        }],
      }), 200);
    });
    final repository = ApiPaymentHistoryRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'), store,
    );
    final entry = (await repository.fetch()).single;
    expect(entry.amount, 102.50);
    expect(entry.status, 'Pendiente');
    expect(entry.toString(), isNot(contains('privada-de-prueba')));
    client.close();
  });
}
