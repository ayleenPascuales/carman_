import 'dart:convert';

import 'package:carman_app/core/errors/app_exception.dart';
import 'package:carman_app/data/local/session_store.dart';
import 'package:carman_app/data/remote/api_client.dart';
import 'package:carman_app/data/repositories/api_favorites_repository.dart';
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
    await store.saveToken('test-token');
  });

  test('lista páginas propias y escribe/borrar sin mandar idPersona', () async {
    final requests = <String>[];
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer test-token');
      requests.add('${request.method} ${request.url}');
      if (request.method == 'GET') {
        final page = request.url.queryParameters['pagina'];
        if (page == '1') {
          return http.Response(
            jsonEncode({
              'pagina': 1,
              'hayMas': true,
              'ids': [7, 9],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'pagina': 2,
            'hayMas': false,
            'ids': [11],
          }),
          200,
        );
      }
      expect(request.body, request.method == 'POST' ? '{}' : '');
      return http.Response('{}', request.method == 'POST' ? 201 : 200);
    });
    final repository = ApiFavoritesRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'),
      store,
    );
    expect(await repository.fetchIds(), {'7', '9', '11'});
    await repository.add('7');
    await repository.remove('9');
    expect(requests, [
      'GET https://example.test/vehiculos/favoritos?pagina=1',
      'GET https://example.test/vehiculos/favoritos?pagina=2',
      'POST https://example.test/vehiculos/favoritos/7',
      'DELETE https://example.test/vehiculos/favoritos/9',
    ]);
    client.close();
  });

  test('sin token no envía ninguna petición', () async {
    await store.clearSession();
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('{}', 200);
    });
    final repository = ApiFavoritesRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'),
      store,
    );
    await expectLater(repository.fetchIds(), throwsA(isA<AuthException>()));
    expect(requests, 0);
    client.close();
  });

  test('un 503 por tabla ausente no se convierte en una lista vacía', () async {
    final client = MockClient(
      (_) async => http.Response(
        '{"message":"Los favoritos sincronizados todavía no están habilitados."}',
        503,
        headers: {'content-type': 'application/json'},
      ),
    );
    final repository = ApiFavoritesRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'),
      store,
    );
    await expectLater(
      repository.fetchIds(),
      throwsA(
        isA<AppException>().having((error) => error.code, 'code', 'http_503'),
      ),
    );
    client.close();
  });

  test('IDs inválidos nunca entran en la URL', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('{}', 200);
    });
    final repository = ApiFavoritesRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'),
      store,
    );
    await expectLater(
      repository.add('../7'),
      throwsA(isA<ValidationException>()),
    );
    expect(requests, 0);
    client.close();
  });
}
