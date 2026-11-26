import '../../core/errors/app_exception.dart';
import '../local/session_store.dart';
import '../remote/api_client.dart';
import '../remote/api_endpoints.dart';

class ApiFavoritesRepository {
  const ApiFavoritesRepository(this._api, this._store);

  final ApiClient _api;
  final SessionStore _store;

  String _token() {
    final token = _store.loadToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('La sesión expiró. Inicia sesión de nuevo.');
    }
    return token;
  }

  String _id(String value) {
    final id = int.tryParse(value);
    if (id == null || id < 1 || '$id' != value) {
      throw const ValidationException('El vehículo no es válido.');
    }
    return '$id';
  }

  Future<Set<String>> fetchIds() async {
    final token = _token();
    final ids = <String>{};
    var pagina = 1;
    while (true) {
      final response = await _api.get(
        ApiEndpoints.favorites,
        token: token,
        query: {'pagina': '$pagina'},
      );
      if (response['pagina'] != pagina ||
          response['hayMas'] is! bool ||
          response['ids'] is! List) {
        throw const AppException(
          'La lista de favoritos no es válida.',
          code: 'invalid_favorites',
        );
      }
      final page = response['ids'] as List;
      if (page.length > 20) {
        throw const AppException(
          'La página de favoritos es demasiado grande.',
          code: 'invalid_favorites',
        );
      }
      for (final value in page) {
        final id = int.tryParse('$value');
        if (id == null || id < 1) {
          throw const AppException(
            'La lista de favoritos no es válida.',
            code: 'invalid_favorites',
          );
        }
        ids.add('$id');
      }
      if (response['hayMas'] != true) return ids;
      if (page.isEmpty || ++pagina > 9999) {
        throw const AppException(
          'La paginación de favoritos no es válida.',
          code: 'invalid_favorites',
        );
      }
    }
  }

  Future<void> add(String vehicleId) async {
    await _api.post(
      '${ApiEndpoints.favorites}/${_id(vehicleId)}',
      token: _token(),
    );
  }

  Future<void> remove(String vehicleId) async {
    await _api.delete(
      '${ApiEndpoints.favorites}/${_id(vehicleId)}',
      token: _token(),
    );
  }
}
