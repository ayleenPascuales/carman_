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

  Future<Reservation> fetchReservation(String id) async {
    final payload = await _api.get(ApiEndpoints.reservation(id), token: _token());
    return ApiMappers.reservation(payload);
  }

  Future<Reservation> decideWithoutDriver(String id, String decision) async {
    await _api.patch('/reservas/$id/decision-sin-conductor',
        token: _token(), body: {'decision': decision});
    return fetchReservation(id);
  }

  Future<Reservation> transition(String id, {required bool finish}) async {
    await _api.patch(finish ? ApiEndpoints.finishReservation(id)
        : ApiEndpoints.startReservation(id), token: _token());
    return fetchReservation(id);
  }

  @override
  Future<Reservation> createReservation({
    required BookingDraft draft,
    required PaymentMethod paymentMethod,
    bool requestDriver = false,
  }) async {
    final payload = await _api.post(
      ApiEndpoints.vehicleReservation(draft.vehicle.id),
      token: _token(),
      body: {
        'fechaInicioServicio': _date(draft.startAt),
        'horaInicioServicio': _hour(draft.startAt),
        'fechaFinServicio': _date(draft.endAt),
        'horaFinServicio': _hour(draft.endAt),
        'solicitarConductor': requestDriver,
      },
    );
    final id = payload['idReserva'];
    if (id != null) {
      try {
        final reservations = await fetchReservations();
        for (final reservation in reservations) {
          if (reservation.id == '$id') return reservation;
        }
      } on AppException {
        // La operación ya se confirmó; devolver el contrato mínimo sin
        // repetir el POST ni dar a entender que se ha cobrado.
      }
    }
    return ApiMappers.reservation(
      payload,
      fallbackVehicle: draft.vehicle,
      fallbackDraft: draft,
    );
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _hour(DateTime value) {
    const allowed = [8, 9, 10, 11, 14, 15, 16, 17, 18];
    if (value.minute != 0 || !allowed.contains(value.hour)) {
      throw const AppException(
        'Selecciona un horario permitido: 8–11 a. m. o 2–6 p. m.',
        code: 'invalid_time',
      );
    }
    final display = value.hour > 12 ? value.hour - 12 : value.hour;
    return '${value.hour < 12 ? display.toString().padLeft(2, '0') : display}:00 '
        '${value.hour >= 12 ? 'PM' : 'AM'}';
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
  Future<void> submitReview({
    required String id,
    required int rating,
    required String comment,
  }) async {
    await _api.post(
      ApiEndpoints.reviewReservation(id),
      token: _token(),
      body: {
        'tipoObjetivo': 'Vehiculo',
        'puntuacion': rating,
        'comentario': comment.trim(),
      },
    );
    // El POST ya confirmó la escritura; no disparar un segundo GET cuya
    // caída haría pensar que el envío falló y animaría a repetirlo.
  }
}
