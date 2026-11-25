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
}
