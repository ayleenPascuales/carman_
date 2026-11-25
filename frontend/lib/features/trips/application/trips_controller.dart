import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/models/booking.dart';
import '../../../providers.dart';

enum TripsTab { upcoming, history, cancelled }

class TripsState {
  const TripsState({
    this.reservations = const [],
    this.isLoading = true,
    this.error,
    this.tab = TripsTab.upcoming,
    this.actionInProgress = false,
  });

  final List<Reservation> reservations;
  final bool isLoading;
  final String? error;
  final TripsTab tab;
  final bool actionInProgress;

  List<Reservation> get upcoming =>
      reservations
          .where((reservation) => reservation.status.isUpcoming)
          .toList()
        ..sort((a, b) => a.startAt.compareTo(b.startAt));

  List<Reservation> get history =>
      reservations
          .where(
            (reservation) => reservation.status == ReservationStatus.completed,
          )
          .toList()
        ..sort((a, b) => b.startAt.compareTo(a.startAt));

  List<Reservation> get cancelled =>
      reservations
          .where(
            (reservation) =>
                reservation.status == ReservationStatus.cancelled ||
                reservation.status == ReservationStatus.rejected ||
                reservation.status == ReservationStatus.expired,
          )
          .toList()
        ..sort((a, b) => b.startAt.compareTo(a.startAt));

  List<Reservation> get currentTab => switch (tab) {
    TripsTab.upcoming => upcoming,
    TripsTab.history => history,
    TripsTab.cancelled => cancelled,
  };

  Reservation? byId(String id) {
    for (final reservation in reservations) {
      if (reservation.id == id) return reservation;
    }
    return null;
  }

  TripsState copyWith({
    List<Reservation>? reservations,
    bool? isLoading,
    String? error,
    TripsTab? tab,
    bool? actionInProgress,
    bool clearError = false,
  }) {
    return TripsState(
      reservations: reservations ?? this.reservations,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      tab: tab ?? this.tab,
      actionInProgress: actionInProgress ?? this.actionInProgress,
    );
  }
}

class TripsController extends Notifier<TripsState> {
  @override
  TripsState build() {
    Future.microtask(refresh);
    return const TripsState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final reservations = await ref
          .read(bookingRepositoryProvider)
          .fetchReservations();
      if (!ref.mounted) return;
      state = state.copyWith(reservations: reservations, isLoading: false);
    } on AppException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, error: error.message);
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'No pudimos cargar tus reservas.',
      );
    }
  }

  void setTab(TripsTab tab) {
    state = state.copyWith(tab: tab);
  }

  Reservation? byId(String id) {
    for (final reservation in state.reservations) {
      if (reservation.id == id) return reservation;
    }
    return null;
  }

  Future<bool> cancel(String id) async {
    state = state.copyWith(actionInProgress: true, clearError: true);
    try {
      final cancelled = await ref
          .read(bookingRepositoryProvider)
          .cancelReservation(id);
      final updated = state.reservations
          .map((reservation) => reservation.id == id ? cancelled : reservation)
          .toList();
      if (!ref.mounted) return true;
      state = state.copyWith(
        reservations: updated,
        actionInProgress: false,
        tab: TripsTab.cancelled,
      );
      return true;
    } on AppException catch (error) {
      state = state.copyWith(actionInProgress: false, error: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        actionInProgress: false,
        error: 'No pudimos cancelar la reserva.',
      );
      return false;
    }
  }

  Future<bool> review({
    required String id,
    required int rating,
    required String comment,
  }) async {
    state = state.copyWith(actionInProgress: true, clearError: true);
    try {
      final reviewed = await ref
          .read(bookingRepositoryProvider)
          .submitReview(id: id, rating: rating, comment: comment);
      final updated = state.reservations
          .map((reservation) => reservation.id == id ? reviewed : reservation)
          .toList();
      state = state.copyWith(reservations: updated, actionInProgress: false);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(actionInProgress: false, error: error.message);
      return false;
    }
  }
}

final tripsControllerProvider = NotifierProvider<TripsController, TripsState>(
  TripsController.new,
);
