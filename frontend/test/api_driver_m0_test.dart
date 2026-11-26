import 'dart:convert';

import 'package:carman_app/data/local/session_store.dart';
import 'package:carman_app/data/remote/api_client.dart';
import 'package:carman_app/data/repositories/driver_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('acciones de conductor usan reservas propias y DTOs del backend', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionStore(await SharedPreferences.getInstance());
    await store.saveToken('token-de-prueba');
    final calls = <String, Object?>{};
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer token-de-prueba');
      calls['${request.method} ${request.url.path}'] =
          jsonDecode(request.body);
      return http.Response('{}', 200);
    });
    final repository = ApiDriverRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'), store,
    );

    await repository.setAvailability(true);
    await repository.acceptTrip('12');
    await repository.startTrip('12');
    await repository.completeTrip('12');
    await repository.declineTrip('13');

    expect(calls, {
      'PATCH /personas/conductor/disponibilidad': {'disponibilidad': true},
      'PATCH /reservas/12/respuesta-conductor': {'aceptar': true},
      'PATCH /reservas/12/iniciar': <String, dynamic>{},
      'PATCH /reservas/12/finalizar': <String, dynamic>{},
      'PATCH /reservas/13/respuesta-conductor': {'aceptar': false},
    });
    client.close();
  });
}
