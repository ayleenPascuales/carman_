import 'dart:convert';

import 'package:carman_app/core/config/app_config.dart';
import 'package:carman_app/core/errors/app_exception.dart';
import 'package:carman_app/data/local/session_store.dart';
import 'package:carman_app/data/models/driver_models.dart';
import 'package:carman_app/data/remote/api_client.dart';
import 'package:carman_app/data/remote/api_mappers.dart';
import 'package:carman_app/data/repositories/driver_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const service = {
  'idReserva': 42,
  'estado': 'Pendiente',
  'estadoRespuestaConductor': 'Pendiente',
  'fechaInicioServicio': '2027-04-02',
  'horaInicioServicio': '09:30:00',
  'fechaFinServicio': '2027-04-03',
  'horaFinServicio': '10:30:00',
  'cliente': {'nombre': 'Ana López'},
  'vehiculo': {
    'idVehiculo': 8,
    'marca': 'Toyota',
    'modelo': 'Corolla',
    'anio': 2023,
    'tipoVehiculo': 'Sedan',
    'capacidad': 4,
    'precioPorDia': '90000.00',
    'fotos': <String>[],
  },
  'origen': 'Punto A',
  'destino': 'Punto B',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lista reservas asignadas, no servicios con IDs sintéticos', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionStore(await SharedPreferences.getInstance());
    await store.saveToken('token-test');
    final client = MockClient((request) async {
      expect(request.url.path, '/reservas/conductor/servicios');
      expect(request.url.queryParameters, {'pagina': '2'});
      expect(request.headers['Authorization'], 'Bearer token-test');
      return http.Response(
        jsonEncode({
          'disponibilidad': false,
          'licenciaVigente': false,
          'pagina': 2,
          'hayMas': true,
          'servicios': [service],
        }),
        200,
      );
    });
    final repo = ApiDriverRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'),
      store,
    );
    final dashboard = await repo.fetchDashboard(page: 2);
    expect(dashboard.trips.single.id, '42');
    expect(dashboard.trips.single.status, DriverTripStatus.offered);
    expect(dashboard.trips.single.scheduledAt.hour, 9);
    expect(dashboard.trips.single.endsAt?.hour, 10);
    expect(dashboard.licenseValid, false);
    expect(dashboard.availability, DriverAvailability.offline);
    expect(dashboard.hasMore, true);
    client.close();
  }, skip: !AppConfig.useLiveApi);

  test(
    'no convierte respuestas incompletas ni 403 en ausencia de trabajo',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SessionStore(await SharedPreferences.getInstance());
      await store.saveToken('token-test');
      final broken = MockClient(
        (_) async =>
            http.Response('{"disponibilidad":true,"servicios":[{}]}', 200),
      );
      final repo = ApiDriverRepository(
        ApiClient(client: broken, baseUrl: 'https://example.test'),
        store,
      );
      await expectLater(repo.fetchDashboard(), throwsA(isA<AppException>()));
      broken.close();
      final denied = MockClient(
        (_) async => http.Response('{"message":"No autorizado"}', 403),
      );
      final deniedRepo = ApiDriverRepository(
        ApiClient(client: denied, baseUrl: 'https://example.test'),
        store,
      );
      await expectLater(
        deniedRepo.fetchDashboard(),
        throwsA(isA<AuthException>()),
      );
      denied.close();
    },
    skip: !AppConfig.useLiveApi,
  );

  test('no trata estados desconocidos como nuevas solicitudes', () {
    final dashboard = ApiMappers.driverDashboard({
      'disponibilidad': true,
      'licenciaVigente': true,
      'pagina': 1,
      'hayMas': false,
      'servicios': [
        {...service, 'estado': 'Estado_nuevo'},
        {
          ...service,
          'idReserva': 43,
          'estado': 'Confirmada',
          'estadoRespuestaConductor': 'Aceptada',
        },
        {...service, 'idReserva': 44, 'estado': 'EnCurso'},
      ],
    });
    expect(dashboard.trips.map((trip) => trip.status), [
      DriverTripStatus.unknown,
      DriverTripStatus.accepted,
      DriverTripStatus.inProgress,
    ]);
    expect(dashboard.availability, DriverAvailability.onTrip);
  }, skip: !AppConfig.useLiveApi);
}
