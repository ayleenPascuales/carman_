import '../../core/errors/app_exception.dart';
import '../local/session_store.dart';
import '../models/booking.dart';
import '../models/payment_method.dart';
import '../remote/api_client.dart';
import '../remote/api_endpoints.dart';
import '../remote/api_mappers.dart';
import 'booking_repository.dart';

/// Reservation API implementation. The endpoint and payload contract is
/// documented in `docs/api_contract.md`.
class ApiBookingRepository implements BookingRepository {
  ApiBookingRepository(this._api, this._store);

  final ApiClient _api;
  final SessionStore _store;

  String _token() {
    final token = _store.loadToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('La sesión expiró. Inicia sesión de nuevo.');
    }
    return token;
  }

  @override
  Future<List<Reservation>> fetchReservations() async {
    final payload = await _api.get(
      ApiEndpoints.myReservations,
      token: _token(),
    );
    final raw = payload['reservas'] ?? payload['data'] ?? payload['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((json) => ApiMappers.reservation(json))
        .toList();
  }

  @override
  Future<Reservation> createReservation({
    required BookingDraft draft,
    required PaymentMethod paymentMethod,
  }) async {
    final payload = await _api.post(
      ApiEndpoints.reservations,
      token: _token(),
      body: {
        'idVehiculo': int.tryParse(draft.vehicle.id) ?? draft.vehicle.id,
        'fechaInicio': draft.startAt.toIso8601String(),
        'fechaFin': draft.endAt.toIso8601String(),
        'modalidad': draft.mode.name,
        'idPuntoRecogida': draft.pickupPoint.id,
        'idPuntoEntrega': draft.pickupPoint.id,
        'seguro': draft.insurance.id,
        'metodoPagoId': paymentMethod.id,
        'metodoPago': paymentMethod.displayLabel,
      },
    );
    return ApiMappers.reservation(
      payload,
      fallbackVehicle: draft.vehicle,
      fallbackDraft: draft,
    );
  }

  @override
  Future<Reservation> cancelReservation(String id) async {
    final payload = await _api.patch(
      ApiEndpoints.cancelReservation(id),
      token: _token(),
    );
    final raw = payload['reserva'] ?? payload['data'];
    if (raw is Map<String, dynamic>) {
      return ApiMappers.reservation(raw);
    }
    final reservations = await fetchReservations();
    for (final reservation in reservations) {
      if (reservation.id == id) return reservation;
    }
    throw const AppException(
      'La reserva se canceló, pero no se pudo actualizar su estado.',
      code: 'invalid_cancellation',
    );
  }

  @override
  Future<Reservation> submitReview({
    required String id,
    required int rating,
    required String comment,
  }) async {
    final payload = await _api.post(
      ApiEndpoints.reviewReservation(id),
      token: _token(),
      body: {'puntuacion': rating, 'comentario': comment},
    );
    final raw = payload['reserva'] ?? payload['data'];
    if (raw is Map<String, dynamic>) {
      return ApiMappers.reservation(raw);
    }
    final reservations = await fetchReservations();
    for (final reservation in reservations) {
      if (reservation.id == id) {
        return reservation.copyWith(hasReview: true);
      }
    }
    throw const AppException(
      'La reseña se envió, pero no se pudo actualizar la reserva.',
      code: 'invalid_review',
    );
  }
}
