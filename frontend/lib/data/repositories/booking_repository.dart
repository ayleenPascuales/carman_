import '../../core/errors/app_exception.dart';
import '../mock/mock_data.dart';
import '../models/booking.dart';
import '../models/payment_method.dart';

abstract interface class BookingRepository {
  Future<List<Reservation>> fetchReservations();

  Future<Reservation> createReservation({
    required BookingDraft draft,
    required PaymentMethod paymentMethod,
    bool requestDriver = false,
  });

  Future<Reservation> cancelReservation(String id);

  Future<void> submitReview({
    required String id,
    required int rating,
    required String comment,
  });
}

class DemoBookingRepository implements BookingRepository {
  DemoBookingRepository() : _reservations = [...MockData.reservations];

  final List<Reservation> _reservations;

  @override
  Future<List<Reservation>> fetchReservations() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return [..._reservations]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Reservation> createReservation({
    required BookingDraft draft,
    required PaymentMethod paymentMethod,
    bool requestDriver = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 1600));

    if (!draft.endAt.isAfter(draft.startAt)) {
      throw const ValidationException(
        'La fecha de devolución debe ser posterior a la de recogida.',
      );
    }
    if (paymentMethod.isDeclineScenario) {
      throw const PaymentDeclinedException();
    }

    final reservation = Reservation(
      id: 'res-${DateTime.now().millisecondsSinceEpoch}',
      code:
          'CRMN-${(DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}',
      vehicle: draft.vehicle,
      startAt: draft.startAt,
      endAt: draft.endAt,
      mode: draft.mode,
      pickupPoint: draft.pickupPoint,
      pricing: draft.pricing,
      status: ReservationStatus.confirmed,
      createdAt: DateTime.now(),
      paymentMethodLabel: paymentMethod.displayLabel,
      insuranceName: draft.insurance.name,
      digitalKeyCode:
          'CRMN-${(DateTime.now().microsecondsSinceEpoch % 9000 + 1000)}',
    );
    _reservations.insert(0, reservation);
    return reservation;
  }

  @override
  Future<Reservation> cancelReservation(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final index = _reservations.indexWhere(
      (reservation) => reservation.id == id,
    );
    if (index == -1) {
      throw const ValidationException('No encontramos esta reserva.');
    }
    final reservation = _reservations[index];
    if (!reservation.isCancellable) {
      throw const ValidationException(
        'La reserva ya no puede cancelarse sin cargo. Contacta con soporte.',
      );
    }
    final cancelled = reservation.copyWith(status: ReservationStatus.cancelled);
    _reservations[index] = cancelled;
    return cancelled;
  }

  @override
  Future<void> submitReview({
    required String id,
    required int rating,
    required String comment,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    final index = _reservations.indexWhere(
      (reservation) => reservation.id == id,
    );
    if (index == -1) {
      throw const ValidationException('No encontramos esta reserva.');
    }
    if (rating < 1 || rating > 5) {
      throw const ValidationException('Selecciona una puntuación válida.');
    }
    final reviewed = _reservations[index].copyWith(hasReview: true);
    _reservations[index] = reviewed;
  }
}
