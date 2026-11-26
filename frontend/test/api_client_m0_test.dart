import 'dart:convert';

import 'package:carman_app/core/errors/app_exception.dart';
import 'package:carman_app/data/local/session_store.dart';
import 'package:carman_app/data/remote/api_client.dart';
import 'package:carman_app/data/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('separa sesión expirada de falta de permiso', () async {
    final client = ApiClient(
      client: MockClient((_) async => http.Response('{"message":"Denegado"}', 403)),
      baseUrl: 'https://example.test',
    );
    await expectLater(client.get('/privado'), throwsA(
      isA<AuthException>().having((error) => error.code, 'code', 'http_403'),
    ));
    client.dispose();
  });

  test('PUT y PDF protegido conservan método, token y bytes binarios', () async {
    final client = ApiClient(
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-token');
        if (request.method == 'PUT') {
          expect(jsonDecode(request.body), {'estado': 'Vigente'});
          return http.Response('{"ok":true}', 200);
        }
        expect(request.headers['Accept'], 'application/pdf');
        return http.Response.bytes(
          [37, 80, 68, 70], 200,
          headers: {'content-type': 'application/pdf'},
        );
      }),
      baseUrl: 'https://example.test',
    );
    expect(await client.put('/licencia', token: 'test-token', body: {'estado': 'Vigente'}),
        {'ok': true});
    expect(await client.getBytes('/archivo/8', token: 'test-token'), [37, 80, 68, 70]);
    client.dispose();
  });

  test('la sesión guardada sin token válido no autentica ni conserva el perfil', () async {
    SharedPreferences.setMockInitialValues({
      'carman.session.token': 'expired-token',
      'carman.session.remember': true,
      'carman.session.user': '{}',
    });
    final store = SessionStore(await SharedPreferences.getInstance());
    final client = ApiClient(
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer expired-token');
        return http.Response('{"message":"Sesión expirada"}', 401);
      }),
      baseUrl: 'https://example.test',
    );
    final repository = ApiAuthRepository(client, store);
    expect(await repository.restoreSession(), isNull);
    expect(store.loadToken(), isNull);
    expect(store.loadUser(), isNull);
    client.dispose();
  });

  test('no persiste el token si el usuario no eligió recordar sesión', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SessionStore(prefs);
    await store.saveToken('solo-en-memoria', persistent: false);
    expect(store.loadToken(), 'solo-en-memoria');
    expect(SessionStore(prefs).loadToken(), isNull);
    await store.clearSession();
    expect(store.loadToken(), isNull);
  });

  test('favoritos y notificaciones leídas no se comparten entre cuentas', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionStore(await SharedPreferences.getInstance());
    await store.saveFavorites({'vehiculo-1'}, accountId: 'persona-1');
    await store.saveReadNotifications({'aviso-1'}, accountId: 'persona-1');
    expect(store.loadFavorites(accountId: 'persona-1'), {'vehiculo-1'});
    expect(store.loadFavorites(accountId: 'persona-2'), isEmpty);
    expect(store.loadReadNotifications(accountId: 'persona-2'), isEmpty);
    expect(store.loadReadNotifications(accountId: 'persona-1'), {'aviso-1'});
  });
}
