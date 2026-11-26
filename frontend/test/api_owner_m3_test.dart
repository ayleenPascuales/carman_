import 'dart:convert';

import 'package:carman_app/core/errors/app_exception.dart';
import 'package:carman_app/data/local/session_store.dart';
import 'package:carman_app/data/models/owner_models.dart';
import 'package:carman_app/data/remote/api_client.dart';
import 'package:carman_app/data/repositories/owner_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const vehicle = {
  'idVehiculo': 42,
  'marca': 'Toyota',
  'modelo': 'Corolla',
  'anio': 2023,
  'capacidad': 4,
  'tipoVehiculo': 'Sedan',
  'precioPorDia': '95000.00',
  'estado': 'inactivo',
  'estado_solicitud_revision': 'Rechazada',
  'motivo_rechazo_revision': 'Falta comprobación técnica',
  'fotos': <String>[],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('inventario real usa solo mis vehículos y no inventa estados', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionStore(await SharedPreferences.getInstance());
    await store.saveToken('token-test', persistent: false);
    final client = MockClient((request) async {
      expect(request.url.path, '/vehiculos/mis-vehiculos');
      expect(request.headers['Authorization'], 'Bearer token-test');
      return http.Response(jsonEncode([vehicle]), 200);
    });
    final repo = ApiOwnerRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'), store);
    final data = await repo.fetchDashboard();
    expect(data.listings.single.meta.status, OwnerVehicleStatus.inactive);
    expect(data.listings.single.meta.reviewStatus, 'Rechazada');
    expect(data.stats.activeVehicles, 0);
    expect(OwnerVehicleStatus.fromApi('estado-desconocido'),
        OwnerVehicleStatus.unknown);
    client.close();
  });

  test('pausa y revisión se escriben con sesión y se releen desde el servidor',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionStore(await SharedPreferences.getInstance());
    await store.saveToken('token-test', persistent: false);
    final posts = <String>[];
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer token-test');
      if (request.method != 'GET') {
        posts.add(request.url.path);
        if (request.url.path.endsWith('/estado')) {
          expect(jsonDecode(request.body)['estado'], 'inactivo');
        } else {
          expect(jsonDecode(request.body)['motivoSolicitud'], 'Revisar frenos');
        }
        return http.Response('{"mensaje":"Aceptado"}', 200);
      }
      expect(request.url.path, '/vehiculos/42');
      return http.Response(jsonEncode({
        ...vehicle,
        if (posts.length > 1) 'estado_solicitud_revision': 'Pendiente',
      }), 200);
    });
    final repo = ApiOwnerRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'), store);
    expect((await repo.changeVehicleState('42', false))['estado'], 'inactivo');
    expect((await repo.requestReview('42', ' Revisar frenos '))['idVehiculo'], 42);
    expect(posts, [
      '/vehiculos/42/estado', '/vehiculos/42/solicitar-revision',
    ]);
    client.close();
  });

  test('no presenta un 403 de vehículo ajeno como inventario vacío', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionStore(await SharedPreferences.getInstance());
    await store.saveToken('token-test', persistent: false);
    final client = MockClient((_) async => http.Response(
        '{"message":"Sin permiso"}', 403));
    final repo = ApiOwnerRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'), store);
    await expectLater(repo.fetchDashboard(), throwsA(isA<AuthException>()));
    client.close();
  });

  test('edita solo tarifa diaria y descripción, sin enviar placa ni documentos',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionStore(await SharedPreferences.getInstance());
    await store.saveToken('token-test', persistent: false);
    final client = MockClient((request) async {
      if (request.method == 'PATCH') {
        expect(request.url.path, '/vehiculos/42');
        expect(jsonDecode(request.body), {
          'precioPorDia': 100000.0, 'descripcion': 'Revisión al día',
        });
        return http.Response('{"mensaje":"Actualizado"}', 200);
      }
      return http.Response(jsonEncode({
        ...vehicle, 'precioPorDia': '100000.00',
        'descripcion': 'Revisión al día',
      }), 200);
    });
    final repo = ApiOwnerRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'), store);
    final detail = await repo.updateVehicle('42',
        description: 'Revisión al día', pricePerDay: 100000);
    expect(detail['precioPorDia'], '100000.00');
    client.close();
  });
}
