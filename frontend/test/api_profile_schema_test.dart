import 'dart:convert';

import 'package:carman_app/core/errors/app_exception.dart';
import 'package:carman_app/data/local/session_store.dart';
import 'package:carman_app/data/models/user_profile.dart';
import 'package:carman_app/data/remote/api_client.dart';
import 'package:carman_app/data/repositories/api_profile_repository.dart';
import 'package:carman_app/data/repositories/profile_repository.dart';
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

  const profile = UserProfile(
    id: '4',
    firstName: 'Prueba',
    lastName: 'Usuario',
    email: 'test@example.com',
    phone: '+573001234567',
    city: 'Ciudad de prueba',
    roles: {UserRole.client},
  );

  test(
    'no envía referencias locales ni simula la revisión de licencias',
    () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      });
      final repository = ApiProfileRepository(
        ApiClient(client: client, baseUrl: 'https://example.test'),
        store,
      );
      await expectLater(
        repository.submitLicense(
          profile,
          LicenseSubmission(
            number: 'LIC-TEST',
            expiry: DateTime(2035),
            type: 'B',
            frontImageReference: 'local://licencia/frontal',
          ),
        ),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            'license_upload_unavailable',
          ),
        ),
      );
      await expectLater(
        repository.addRole(profile, UserRole.owner),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            'owner_registration_unavailable',
          ),
        ),
      );
      expect(requests, 0);
      client.close();
    },
  );

  test('alta de conductor usa el DTO real y relee el rol confirmado', () async {
    await store.saveToken('test-token');
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add('${request.method} ${request.url.path}');
      if (request.method == 'POST') {
        expect(jsonDecode(request.body), isEmpty);
        return http.Response('{"idConductor":7}', 201);
      }
      return http.Response('{"roles":{"conductor":true}}', 200);
    });
    final repository = ApiProfileRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'), store,
    );
    final driver = profile.copyWith(licenseStatus: LicenseStatus.approved);
    expect((await repository.addRole(driver, UserRole.driver)).isDriver, isTrue);
    expect(paths, ['POST /personas/roles', 'GET /personas/perfil']);
    client.close();
  });

  test('no publica cambios de teléfono sin reverificación', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('{}', 200);
    });
    final repository = ApiProfileRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'), store,
    );
    await expectLater(
      repository.updateProfile(profile, const ProfileUpdate(
        firstName: 'Prueba', lastName: 'Usuario', phone: '+573009999999',
        city: 'Ciudad de prueba',
      )),
      throwsA(isA<AppException>().having(
        (error) => error.code, 'code', 'phone_verification_required',
      )),
    );
    expect(requests, 0);
    client.close();
  });

  test('favoritos usan detalle público y no el detalle privado del dueño', () async {
    await store.saveToken('test-token');
    final client = MockClient((request) async {
      expect(request.url.path, '/vehiculos/catalogo/7');
      expect(request.headers.containsKey('Authorization'), isFalse);
      return http.Response('{}', 404);
    });
    final repository = ApiProfileRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'), store,
    );
    expect(await repository.fetchFavorites({'7'}), isEmpty);
    client.close();
  });
}
