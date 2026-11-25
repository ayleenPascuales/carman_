import 'dart:convert';

import 'package:carman_app/core/errors/app_exception.dart';
import 'package:carman_app/data/local/session_store.dart';
import 'package:carman_app/data/models/user_profile.dart';
import 'package:carman_app/data/remote/api_client.dart';
import 'package:carman_app/data/repositories/auth_repository.dart';
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

  RegistrationRequest request(UserRole role) => RegistrationRequest(
    firstName: 'Nombre de prueba',
    lastName: 'Apellido de prueba',
    email: 'test@example.com',
    phone: '+573001234567',
    password: 'password-for-tests',
    city: 'Ciudad de prueba',
    document: 'DOC-TEST',
    birthDate: DateTime(1995),
    role: role,
  );

  test('no envía una foto de licencia inventada para un conductor', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('{}', 200);
    });
    final repository = ApiAuthRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'),
      store,
    );
    final driver = RegistrationRequest(
      firstName: 'Nombre de prueba',
      lastName: 'Apellido de prueba',
      email: 'test@example.com',
      phone: '+573001234567',
      password: 'password-for-tests',
      city: 'Ciudad de prueba',
      document: 'DOC-TEST',
      birthDate: DateTime(1995),
      role: UserRole.driver,
      licenseNumber: 'LIC-TEST',
      licenseExpiry: DateTime(2035),
    );
    await expectLater(
      repository.register(driver),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'license_document_required',
        ),
      ),
    );
    expect(requests, 0);
    client.close();
  });

  test('no crea un propietario sin vehículo, puntos ni documentos', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('{}', 200);
    });
    final repository = ApiAuthRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'),
      store,
    );
    await expectLater(
      repository.register(request(UserRole.owner)),
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
  });

  test('registra cliente sin direcciones ni imágenes ficticias', () async {
    final client = MockClient((http.Request httpRequest) async {
      switch (httpRequest.url.path) {
        case '/personas/registro':
          final body = jsonDecode(httpRequest.body) as Map<String, dynamic>;
          final persona = body['persona'] as Map<String, dynamic>;
          expect(persona.containsKey('direccion'), isFalse);
          expect(persona.containsKey('fotoPerfil'), isFalse);
          return http.Response('{"smsEnviado":false}', 201);
        case '/auth/login':
          return http.Response('{"idToken":"test-token"}', 201);
        case '/auth/verificacion':
          return http.Response('{"activada":true}', 200);
        case '/personas/perfil':
          return http.Response(
            jsonEncode({
              'idPersona': 4,
              'nombre': 'Nombre de prueba',
              'apellido': 'Apellido de prueba',
              'email': 'test@example.com',
              'roles': {'cliente': true},
              'fotoPerfil': '',
              'licenciaEstado': null,
            }),
            200,
          );
      }
      return http.Response('{}', 404);
    });
    final repository = ApiAuthRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'),
      store,
    );
    final session = await repository.register(request(UserRole.client));
    expect(session.user.avatarUrl, isNull);
    expect(session.user.licenseStatus, LicenseStatus.notSubmitted);
    expect(session.user.rating, 0);
    expect(session.user.isEmailVerified, isFalse);
    expect(session.user.isPhoneVerified, isFalse);
    client.close();
  });

  test('el rol propietario no supone licencia aprobada', () async {
    final client = MockClient((http.Request httpRequest) async {
      if (httpRequest.url.path == '/auth/login') {
        return http.Response('{"idToken":"test-token"}', 201);
      }
      if (httpRequest.url.path == '/auth/verificacion') {
        return http.Response('{"activada":true}', 200);
      }
      return http.Response(
        jsonEncode({
          'idPersona': 4,
          'nombre': 'Nombre de prueba',
          'email': 'test@example.com',
          'roles': {'propietario': true},
          'licenciaEstado': null,
        }),
        200,
      );
    });
    final repository = ApiAuthRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'),
      store,
    );
    final session = await repository.login(
      email: 'test@example.com',
      password: 'password-for-tests',
      remember: false,
    );
    expect(session.user.licenseStatus, LicenseStatus.notSubmitted);
    client.close();
  });

  test('no inventa el rol cliente en una sesión API sin roles', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/auth/login') {
        return http.Response('{"idToken":"test-token"}', 201);
      }
      if (request.url.path == '/auth/verificacion') {
        return http.Response('{"activada":true}', 200);
      }
      return http.Response(
        jsonEncode({
          'idPersona': 4,
          'nombre': 'Nombre de prueba',
          'email': 'test@example.com',
          'roles': <String, bool>{},
          'licenciaEstado': 'Suspendida',
        }),
        200,
      );
    });
    final repository = ApiAuthRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'),
      store,
    );
    final session = await repository.login(
      email: 'test@example.com',
      password: 'password-for-tests',
      remember: true,
    );
    expect(session.user.roles, isEmpty);
    expect(store.loadUser()?.roles, isEmpty);
    expect(session.user.canBook, isFalse);
    client.close();
  });
}
