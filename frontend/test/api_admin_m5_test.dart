import 'dart:convert';

import 'package:carman_app/core/config/app_config.dart';
import 'package:carman_app/core/errors/app_exception.dart';
import 'package:carman_app/data/local/session_store.dart';
import 'package:carman_app/data/models/admin_models.dart';
import 'package:carman_app/data/models/user_profile.dart';
import 'package:carman_app/data/remote/api_client.dart';
import 'package:carman_app/data/repositories/admin_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'resumen, usuarios y revisiones usan rutas reales con rol/estado y páginas',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SessionStore(await SharedPreferences.getInstance());
      await store.saveToken('token-prueba');
      final paths = <String>[];
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token-prueba');
        paths.add(request.url.path);
        if (request.url.path == '/admin/resumen') {
          return http.Response(
            jsonEncode({
              'usuarios': 81,
              'conductores': 6,
              'vehiculos': 2,
              'pendientes': 1,
              'reservasHoy': 3,
            }),
            200,
          );
        }
        if (request.url.path == '/admin/usuarios') {
          expect(request.url.queryParameters, {
            'pagina': '1',
            'buscar': 'Ana',
            'rol': 'Propietario',
            'estado': 'Activo',
          });
          return http.Response(
            jsonEncode({
              'pagina': 1,
              'hayMas': true,
              'total': 81,
              'usuarios': [
                {
                  'idPersona': 5,
                  'nombre': 'Ana',
                  'apellido': 'López',
                  'email': 'ana@example.test',
                  'estado': 'Activo',
                  'fechaHoraRegistro': '2026-11-24T12:00:00',
                  'cliente': 0,
                  'conductor': 0,
                  'propietario': 1,
                  'administrador': 0,
                },
              ],
            }),
            200,
          );
        }
        expect(request.url.path, '/admin/revisiones');
        expect(request.url.queryParameters, {
          'pagina': '1',
          'estado': 'Aprobada',
        });
        return http.Response(
          jsonEncode({
            'pagina': 1,
            'hayMas': false,
            'total': 1,
            'solicitudes': [
              {
                'idVehiculo': 12,
                'marca': 'Toyota',
                'modelo': 'Corolla',
                'estado_solicitud_revision': 'Aprobada',
                'motivo_solicitud_revision': 'Revisar frenos',
                'nombrePropietario': 'Ana',
                'apellidoPropietario': 'López',
              },
            ],
          }),
          200,
        );
      });
      final repo = ApiAdminRepository(
        ApiClient(client: client, baseUrl: 'https://example.test'),
        store,
      );
      final data = await repo.fetchDashboard(
        search: 'Ana',
        role: 'Propietario',
        status: 'Activo',
        revisionStatus: 'Aprobada',
      );
      expect(paths, ['/admin/resumen', '/admin/usuarios', '/admin/revisiones']);
      expect(data.stats.totalUsers, 81);
      expect(data.usersHasMore, true);
      expect(data.users.single.roles, {UserRole.owner});
      expect(data.approvals.single.type, AdminApprovalType.vehicle);
      expect(data.approvals.single.status, AdminApprovalStatus.approved);
      expect(data.approvals.single.submittedAt, null);
      client.close();
    },
    skip: !AppConfig.useLiveApi,
  );

  test(
    'rechazo exige motivo y no cambia licencias ni llama rutas ficticias',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SessionStore(await SharedPreferences.getInstance());
      await store.saveToken('token-prueba');
      final client = MockClient((request) async {
        expect(request.url.path, '/admin/revisiones/12/rechazar');
        expect(jsonDecode(request.body), {
          'motivoRechazo': 'Frenos sin inspeccionar',
        });
        return http.Response('{}', 200);
      });
      final repo = ApiAdminRepository(
        ApiClient(client: client, baseUrl: 'https://example.test'),
        store,
      );
      await expectLater(
        repo.reviewApproval('12', false),
        throwsA(isA<ValidationException>()),
      );
      await repo.reviewApproval(
        '12',
        false,
        reason: ' Frenos sin inspeccionar ',
      );
      client.close();
    },
    skip: !AppConfig.useLiveApi,
  );

  test('403 no se convierte en panel administrativo vacío', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionStore(await SharedPreferences.getInstance());
    await store.saveToken('token-prueba');
    final client = MockClient(
      (request) async => http.Response('{"message":"Prohibido"}', 403),
    );
    final repo = ApiAdminRepository(
      ApiClient(client: client, baseUrl: 'https://example.test'),
      store,
    );
    await expectLater(repo.fetchDashboard(), throwsA(isA<AuthException>()));
    client.close();
  }, skip: !AppConfig.useLiveApi);
}
