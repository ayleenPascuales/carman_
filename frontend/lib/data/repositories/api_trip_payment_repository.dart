import '../../core/errors/app_exception.dart';
import '../local/session_store.dart';
import '../remote/api_client.dart';
import '../remote/api_endpoints.dart';

class TripOrder {
  const TripOrder({
    required this.id,
    required this.reservationId,
    required this.total,
    required this.approved,
    required this.advanceApproved,
    required this.balance,
    required this.inProgress,
    required this.status,
    required this.reservationStatus,
  });

  final int id;
  final int reservationId;
  final double total;
  final double approved;
  final double advanceApproved;
  final double balance;
  final int inProgress;
  final String status;
  final String reservationStatus;

  factory TripOrder.fromJson(Map<String, dynamic> json) {
    final order = int.tryParse('${json['idOrdenPago']}');
    final reservation = int.tryParse('${json['idReserva']}');
    final total = double.tryParse('${json['total']}');
    final approved = double.tryParse('${json['totalAprobado']}');
    final advance = double.tryParse('${json['anticipoAprobado']}');
    final balance = double.tryParse('${json['saldoPendiente']}');
    final pending = int.tryParse('${json['pagosEnProceso']}');
    if (order == null || order < 1 || reservation == null || reservation < 1 ||
        total == null || !total.isFinite || approved == null ||
        !approved.isFinite || advance == null || !advance.isFinite ||
        balance == null || !balance.isFinite || pending == null ||
        json['estado'] is! String || json['estadoReserva'] is! String) {
      throw const AppException('El estado de pago no tiene el formato esperado.');
    }
    return TripOrder(
      id: order, reservationId: reservation, total: total, approved: approved,
      advanceApproved: advance, balance: balance, inProgress: pending,
      status: json['estado'] as String,
      reservationStatus: json['estadoReserva'] as String,
    );
  }
}

class ApiTripPaymentRepository {
  const ApiTripPaymentRepository(this._api, this._store);

  final ApiClient _api;
  final SessionStore _store;

  String _token() {
    final token = _store.loadToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('La sesión expiró. Inicia sesión de nuevo.');
    }
    return token;
  }

  Future<TripOrder> fetchOrder(String reservationId) async {
    final response = await _api.get(ApiEndpoints.reservationOrder(reservationId),
        token: _token());
    return TripOrder.fromJson(response);
  }

  Future<void> createOrder(String reservationId) async {
    await _api.post(ApiEndpoints.reservationOrder(reservationId), token: _token());
  }

  Future<Uri> startCheckout(int orderId) async {
    final response = await _api.post(ApiEndpoints.orderCheckout(orderId),
        token: _token());
    final raw = response['checkoutUrl'];
    final url = raw is String ? Uri.tryParse(raw) : null;
    if (url == null || url.scheme != 'https' ||
        url.host != 'checkout.wompi.co' || url.port != 443 ||
        url.path != '/p/') {
      throw const AppException('La URL segura de Wompi no es válida.');
    }
    return url;
  }
}
