import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/models/vehicle_query.dart';
import '../../../providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../explore/application/catalog_controller.dart';
import '../../notifications/application/notifications_controller.dart';
import '../../trips/application/trips_controller.dart';
import 'payment_controller.dart';

enum PaymentOutcome { success, declined, error, licenseRequired }

class BookingFailureData {
  const BookingFailureData({
    required this.vehicle,
    required this.startAt,
    required this.endAt,
    required this.total,
    required this.holdExpiresAt,
    this.declineCode = 'ERR_CARD_DECLINED',
    this.reason = 'Fondos insuficientes o límite de tarjeta excedido',
    this.paymentLabel = 'Visa Crédito •••• 0002',
  });

  final Vehicle vehicle;
  final DateTime startAt;
  final DateTime endAt;
  final double total;
  final DateTime holdExpiresAt;
  final String declineCode;
  final String reason;
  final String paymentLabel;
}

class BookingState {
  const BookingState({
    this.draft,
    this.isPaying = false,
    this.error,
    this.failure,
    this.lastReservation,
  });

  final BookingDraft? draft;
  final bool isPaying;
  final String? error;
  final BookingFailureData? failure;
  final Reservation? lastReservation;

  BookingState copyWith({
    BookingDraft? draft,
    bool? isPaying,
    String? error,
    BookingFailureData? failure,
    Reservation? lastReservation,
    bool clearError = false,
    bool clearFailure = false,
  }) {
    return BookingState(
      draft: draft ?? this.draft,
      isPaying: isPaying ?? this.isPaying,
      error: clearError ? null : (error ?? this.error),
      failure: clearFailure ? null : (failure ?? this.failure),
      lastReservation: lastReservation ?? this.lastReservation,
    );
  }
}

class BookingController extends Notifier<BookingState> {
  @override
  BookingState build() => const BookingState();

  void start(Vehicle vehicle) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 10);
    final catalogQuery = ref.read(catalogControllerProvider).query;
    final startAt =
        catalogQuery.startAt != null && catalogQuery.startAt!.isAfter(now)
        ? catalogQuery.startAt!
        : tomorrow;
    final duration =
        catalogQuery.endAt != null && catalogQuery.endAt!.isAfter(startAt)
        ? catalogQuery.endAt!.difference(startAt)
        : catalogQuery.mode == RentalMode.hourly
        ? const Duration(hours: 4)
        : const Duration(days: 3);
    final endAt =
        catalogQuery.endAt != null && catalogQuery.endAt!.isAfter(startAt)
        ? catalogQuery.endAt!
        : startAt.add(duration);
    state = BookingState(
      draft: BookingDraft(
        vehicle: vehicle,
        startAt: startAt,
        endAt: endAt,
        mode: catalogQuery.mode,
        pickupPoint: vehicle.pickupPoint ?? _fallbackPickup(vehicle),
        insurance: InsurancePlan.premium,
      ),
    );
  }

  PickupPoint _fallbackPickup(Vehicle vehicle) {
    // The demo has a guaranteed pickup point for each seeded vehicle.
    if (vehicle.pickupPoint != null) return vehicle.pickupPoint!;
    return const PickupPoint(
      id: 'pp-default',
      name: 'Cartagena · Centro',
      city: 'Cartagena',
      address: 'Muelle Los Pegasos',
      distance: 0.3,
    );
  }

  void updateDates({required DateTime startAt, required DateTime endAt}) {
    final draft = state.draft;
    if (draft == null) return;
    state = state.copyWith(
      draft: draft.copyWith(startAt: startAt, endAt: endAt),
      clearError: true,
    );
  }

  void updateMode(RentalMode mode) {
    final draft = state.draft;
    if (draft == null) return;
    final units = draft.pricing.units;
    final DateTime endAt;
    if (mode == RentalMode.hourly) {
      endAt = draft.startAt.add(Duration(hours: units.clamp(2, 24)));
    } else {
      endAt = draft.startAt.add(Duration(days: units.clamp(1, 30)));
    }
    state = state.copyWith(
      draft: draft.copyWith(mode: mode, endAt: endAt),
    );
  }

  void updateInsurance(InsurancePlan insurance) {
    final draft = state.draft;
    if (draft == null) return;
    state = state.copyWith(draft: draft.copyWith(insurance: insurance));
  }

  void updatePickup(PickupPoint point) {
    final draft = state.draft;
    if (draft == null) return;
    state = state.copyWith(draft: draft.copyWith(pickupPoint: point));
  }

  void setError(String? message) {
    if (message == null) {
      state = state.copyWith(clearError: true);
    } else {
      state = state.copyWith(error: message);
    }
  }

  void clearFailure() {
    state = state.copyWith(clearFailure: true);
  }

  Future<PaymentOutcome> pay() async {
    final draft = state.draft;
    if (draft == null) return PaymentOutcome.error;
    final user = ref.read(authControllerProvider).user;
    if (user == null || !user.canBook) {
      return PaymentOutcome.licenseRequired;
    }
    state = state.copyWith(
      isPaying: true,
      clearError: true,
      clearFailure: true,
    );
    final method = ref.read(paymentControllerProvider).selected;
    try {
      final reservation = await ref
          .read(bookingRepositoryProvider)
          .createReservation(draft: draft, paymentMethod: method);
      state = state.copyWith(isPaying: false, lastReservation: reservation);
      ref.invalidate(tripsControllerProvider);
      ref
          .read(notificationsControllerProvider.notifier)
          .addReservation(reservation: reservation);
      return PaymentOutcome.success;
    } on PaymentDeclinedException catch (error) {
      state = state.copyWith(
        isPaying: false,
        failure: BookingFailureData(
          vehicle: draft.vehicle,
          startAt: draft.startAt,
          endAt: draft.endAt,
          total: draft.pricing.total,
          holdExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
          declineCode: error.declineCode,
          reason: error.reason,
          paymentLabel: method.displayLabel,
        ),
      );
      return PaymentOutcome.declined;
    } on AppException catch (error) {
      state = state.copyWith(isPaying: false, error: error.message);
      return PaymentOutcome.error;
    } catch (_) {
      state = state.copyWith(
        isPaying: false,
        error: 'No pudimos procesar el pago. Inténtalo de nuevo.',
      );
      return PaymentOutcome.error;
    }
  }

  void clear() {
    state = const BookingState();
  }
}

final bookingControllerProvider =
    NotifierProvider<BookingController, BookingState>(BookingController.new);
