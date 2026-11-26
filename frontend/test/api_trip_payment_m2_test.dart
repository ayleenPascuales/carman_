import 'dart:convert';

import 'package:carman_app/core/errors/app_exception.dart';
import 'package:carman_app/data/local/session_store.dart';
import 'package:carman_app/data/mock/mock_data.dart';
import 'package:carman_app/data/models/booking.dart';
import 'package:carman_app/data/models/payment_method.dart';
import 'package:carman_app/data/models/vehicle_query.dart';
import 'package:carman_app/data/remote/api_client.dart';
import 'package:carman_app/data/repositories/api_booking_repository.dart';
import 'package:carman_app/data/repositories/api_trip_payment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('consulta el saldo autenticado sin inferir aprobación del checkout', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionStore(await SharedPreferences.getInstance());
    await store.saveToken('test-token', persistent: false);
    final client = MockClient((request) async {
      expect(request.url.path, '/pagos/reservas/5/orden');
      expect(request.headers['Authorization'], 'Bearer test-token');
      return http.Response(jsonEncode({
        'idOrdenPago': 34, 'idReserva': 5, 'total': 100000,
        'totalAprobado': 50000, 'anticipoAprobado': 50000,
        'saldoPendiente': 50000, 'pagosEnProceso': 1,
        'estado': 'Activa', 'estadoReserva': 'EnCurso',
      }), 200);
    });
    final repo = ApiTripPaymentRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'), store);
    final order = await repo.fetchOrder('5');
    expect(order.balance, 50000);
    expect(order.inProgress, 1);
    expect(order.advanceApproved, 50000);
    client.close();
  });

  test('rechaza una URL de checkout ajena a Wompi', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionStore(await SharedPreferences.getInstance());
    await store.saveToken('test-token', persistent: false);
    final client = MockClient((request) async {
      expect(request.url.path, '/pagos/ordenes/34/checkout');
      return http.Response('{"checkoutUrl":"https://evil.example/pay"}', 201);
    });
    final repo = ApiTripPaymentRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'), store);
    await expectLater(repo.startCheckout(34), throwsA(isA<AppException>()));
    client.close();
  });

  test('acepta solo el checkout Sandbox configurado por el backend', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionStore(await SharedPreferences.getInstance());
    await store.saveToken('test-token', persistent: false);
    final client = MockClient((_) async => http.Response(
      '{"checkoutUrl":"https://checkout.wompi.co/p/?public-key=pub_test_example"}',
      201,
    ));
    final repo = ApiTripPaymentRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'), store);
    final url = await repo.startCheckout(34);
    expect(url.host, 'checkout.wompi.co');
    client.close();
  });

  test('envía la solicitud de conductor al crear reserva sin iniciar cobro', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionStore(await SharedPreferences.getInstance());
    await store.saveToken('test-token', persistent: false);
    var posts = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        posts++;
        expect(request.url.path, startsWith('/reservas/vehiculo/'));
        expect(jsonDecode(request.body)['solicitarConductor'], isTrue);
        return http.Response('{"idReserva":5,"estado":"Pendiente"}', 201);
      }
      return http.Response('{"reservas":[]}', 200);
    });
    final vehicle = MockData.vehicles.first;
    final draft = BookingDraft(
      vehicle: vehicle, startAt: DateTime(2027, 2, 10, 10),
      endAt: DateTime(2027, 2, 11, 10),
      mode: RentalMode.daily,
      pickupPoint: vehicle.pickupPoint!,
      insurance: InsurancePlan.basic,
    );
    final repo = ApiBookingRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'), store);
    final reservation = await repo.createReservation(
      draft: draft, paymentMethod: PaymentMethodsSeed.applePay,
      requestDriver: true,
    );
    expect(reservation.id, '5');
    expect(posts, 1);
    client.close();
  });
}
