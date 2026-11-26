import 'dart:convert';

import 'package:carman_app/core/errors/app_exception.dart';
import 'package:carman_app/data/local/session_store.dart';
import 'package:carman_app/data/models/user_profile.dart';
import 'package:carman_app/data/models/vehicle.dart';
import 'package:carman_app/data/models/vehicle_query.dart';
import 'package:carman_app/data/remote/api_client.dart';
import 'package:carman_app/data/repositories/auth_repository.dart';
import 'package:carman_app/data/repositories/vehicle_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el catálogo live envía solo filtros soportados y fechas locales', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionStore(await SharedPreferences.getInstance());
    final client = MockClient((request) async {
      expect(request.url.path, '/vehiculos/catalogo');
      expect(request.url.queryParameters, {
        'ciudad': 'Cartagena',
        'categoria': 'suv',
        'fechaInicio': '2027-02-10T10:00:00',
        'fechaFin': '2027-02-12T14:00:00',
        'precioMaximo': '100000.0',
        'plazasMinimas': '5',
        'orden': 'priceAsc',
        'texto': 'Marca',
        'pagina': '1',
      });
      return http.Response('{"vehiculos":[]}', 200);
    });
    final repo = ApiVehicleRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'), store,
    );
    expect(await repo.fetchCatalog(VehicleQuery(
      text: 'Marca', category: VehicleCategory.suv, minSeats: 5,
      startAt: DateTime(2027, 2, 10, 10),
      endAt: DateTime(2027, 2, 12, 14),
      maxPrice: 100000, sort: SortOption.priceAsc,
    )), isEmpty);
    client.close();
  });

  test('los filtros sin dato real se rechazan antes de pedir el catálogo', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionStore(await SharedPreferences.getInstance());
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('{"vehiculos":[]}', 200);
    });
    final repo = ApiVehicleRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'), store,
    );
    await expectLater(repo.fetchCatalog(const VehicleQuery(fuel: FuelType.diesel)),
      throwsA(isA<AppException>().having(
        (error) => error.code, 'code', 'unsupported_catalog_filter',
      )));
    expect(requests, 0);
    client.close();
  });

  test('pide la siguiente página y conserva el indicador de más resultados', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionStore(await SharedPreferences.getInstance());
    final pages = <String>[];
    final client = MockClient((request) async {
      pages.add(request.url.queryParameters['pagina']!);
      return http.Response(jsonEncode({
        'vehiculos': <Object>[],
        'pagina': int.parse(pages.last),
        'hayMas': pages.last == '1',
      }), 200);
    });
    final repo = ApiVehicleRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'), store,
    );
    expect((await repo.fetchCatalogPage(const VehicleQuery(), 1)).hasMore, isTrue);
    expect((await repo.fetchCatalogPage(const VehicleQuery(), 2)).hasMore, isFalse);
    expect(pages, ['1', '2']);
    client.close();
  });

  test('recuperar contraseña live solicita un enlace y no simula cambio', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionStore(await SharedPreferences.getInstance());
    final client = MockClient((request) async {
      expect(request.url.path, '/auth/password/solicitar-recuperacion');
      expect(jsonDecode(request.body), {'email': 'test@example.com'});
      return http.Response('{"mensaje":"Solicitud recibida"}', 201);
    });
    final repo = ApiAuthRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'), store,
    );
    await repo.requestPasswordReset(' test@example.com ');
    await expectLater(
      repo.resetPassword(email: 'test@example.com', password: 'test-password'),
      throwsA(isA<AppException>().having(
        (error) => error.code, 'code', 'password_reset_link_required',
      )),
    );
    client.close();
  });

  test('distingue licencia vigente, vencida y suspendida del perfil', () {
    expect(LicenseStatus.fromApi('Vigente'), LicenseStatus.approved);
    expect(LicenseStatus.fromApi('Vencida'), LicenseStatus.expired);
    expect(LicenseStatus.fromApi('Suspendida'), LicenseStatus.suspended);
    expect(LicenseStatus.fromApi(null), LicenseStatus.notSubmitted);
  });
}
