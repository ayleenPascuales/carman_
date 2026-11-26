import 'dart:convert';

import 'package:carman_app/data/local/session_store.dart';
import 'package:carman_app/data/mock/mock_data.dart';
import 'package:carman_app/data/models/booking.dart';
import 'package:carman_app/data/models/payment_method.dart';
import 'package:carman_app/data/models/trip_route.dart';
import 'package:carman_app/data/models/vehicle_query.dart';
import 'package:carman_app/data/remote/api_client.dart';
import 'package:carman_app/data/repositories/api_booking_repository.dart';
import 'package:carman_app/data/repositories/api_trip_map_repository.dart';
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
    await store.saveToken('token-de-prueba');
  });

  test('envía el horario permitido sin método de pago ni ubicación GPS', () async {
    final vehicle = MockData.vehicles.first;
    final draft = BookingDraft(
      vehicle: vehicle,
      startAt: DateTime(2027, 3, 12, 10),
      endAt: DateTime(2027, 3, 14, 14),
      mode: RentalMode.daily,
      pickupPoint: MockData.pickupPoints.first,
      insurance: InsurancePlan.basic,
    );
    var created = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        created++;
        expect(request.url.path, '/reservas/vehiculo/${vehicle.id}');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body, {
          'fechaInicioServicio': '2027-03-12',
          'horaInicioServicio': '10:00 AM',
          'fechaFinServicio': '2027-03-14',
          'horaFinServicio': '2:00 PM',
          'solicitarConductor': false,
        });
        return http.Response('{"idReserva":12,"estado":"Confirmada"}', 201);
      }
      expect(request.url.path, '/reservas/mis-reservas');
      return http.Response('{"reservas":[]}', 200);
    });
    final repository = ApiBookingRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'), store,
    );
    final reservation = await repository.createReservation(
      draft: draft, paymentMethod: PaymentMethodsSeed.applePay,
    );
    expect(created, 1);
    expect(reservation.id, '12');
    client.close();
  });

  test('consulta ruta vial de una reserva sin enviar ubicación del teléfono', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/rutas/reservas/12');
      expect(request.url.queryParameters, isEmpty);
      return http.Response(jsonEncode({
        'origen': {
          'idPunto': 1, 'nombre': 'A', 'direccion': 'Punto A',
          'latitud': 10.4, 'longitud': -75.5,
        },
        'destino': {
          'idPunto': 2, 'nombre': 'B', 'direccion': 'Punto B',
          'latitud': 10.5, 'longitud': -75.4,
        },
        'distanciaKm': 2.3,
        'duracionMinutos': 5,
        'trayectoria': [[-75.5, 10.4], [-75.4, 10.5]],
        'tarifa': {'precioEstimado': 100000, 'recargoPorDistancia': 0},
      }), 200);
    });
    final repository = ApiTripMapRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'), store,
    );
    final route = await repository.getRoute('12');
    expect(route.trace.last.longitude, -75.4);
    expect(route.distanceKm, 2.3);
    expect(route.estimatedPrice, 100000);
    client.close();
  });

  test('la cercanía solo envía GPS tras llamarla explícitamente', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/rutas/vehiculos/3/punto-cercano');
      expect(request.method, 'POST');
      expect(request.url.queryParameters, isEmpty);
      expect(jsonDecode(request.body), {
        'latitud': 10.4, 'longitud': -75.5,
      });
      return http.Response('{"punto":{"idPunto":1}}', 200);
    });
    final repository = ApiTripMapRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'), store,
    );
    final result = await repository.nearestPickup('3', const RoutePosition(10.4, -75.5));
    expect((result['punto'] as Map<String, dynamic>)['idPunto'], 1);
    client.close();
  });
}
