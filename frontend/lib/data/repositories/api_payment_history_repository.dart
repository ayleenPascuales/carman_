import '../../core/errors/app_exception.dart';
import '../local/session_store.dart';
import '../models/payment_history_entry.dart';
import '../remote/api_client.dart';
import '../remote/api_endpoints.dart';

class ApiPaymentHistoryRepository {
  ApiPaymentHistoryRepository(this._api, this._store);

  final ApiClient _api;
  final SessionStore _store;

  Future<List<PaymentHistoryEntry>> fetch() async {
    final token = _store.loadToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('La sesión expiró. Inicia sesión de nuevo.');
    }
    final payload = await _api.get(ApiEndpoints.paymentHistory, token: token);
    final raw = payload['pagos'];
    if (raw is! List) {
      throw const AppException(
        'El historial de pagos no tiene el formato esperado.',
        code: 'invalid_payment_history',
      );
    }
    try {
      return raw
          .map((item) => PaymentHistoryEntry.fromJson(item as Map<String, dynamic>))
          .toList();
    } on FormatException {
      throw const AppException(
        'Hay un movimiento con un importe inválido.',
        code: 'invalid_payment_history',
      );
    } on TypeError {
      throw const AppException(
        'El historial de pagos no tiene el formato esperado.',
        code: 'invalid_payment_history',
      );
    }
  }
}
