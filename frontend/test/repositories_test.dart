import 'package:carman_app/core/errors/app_exception.dart';
import 'package:carman_app/data/local/session_store.dart';
import 'package:carman_app/data/mock/mock_data.dart';
import 'package:carman_app/data/models/booking.dart';
import 'package:carman_app/data/models/payment_method.dart';
import 'package:carman_app/data/models/user_profile.dart';
import 'package:carman_app/data/models/vehicle_query.dart';
import 'package:carman_app/data/repositories/auth_repository.dart';
import 'package:carman_app/data/repositories/booking_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DemoAuthRepository', () {
    late DemoAuthRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repository = DemoAuthRepository(SessionStore(prefs));
    });

    test('logs in with the demo account', () async {
      final session = await repository.login(
        email: 'alex.rivera@carman.es',
        password: 'Carman123',
        remember: true,
      );

      expect(session.user.email, 'alex.rivera@carman.es');
      expect(session.user.isOwner, isTrue);
      expect(session.user.licenseStatus, LicenseStatus.approved);
    });

    test('rejects invalid credentials', () async {
      expect(
        () => repository.login(
          email: 'alex.rivera@carman.es',
          password: 'wrong-password',
          remember: false,
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('registers and can log in again', () async {
      final request = RegistrationRequest(
        firstName: 'María',
        lastName: 'Gómez',
        email: 'maria@example.com',
        phone: '+57 300 000 0000',
        password: 'Carman123',
        city: 'Medellín',
        document: '1020304051',
        birthDate: DateTime(1994, 5, 20),
        role: UserRole.client,
      );

      final registered = await repository.register(request);
      expect(registered.user.fullName, 'María Gómez');
      expect(registered.user.licenseStatus, LicenseStatus.notSubmitted);

      final session = await repository.login(
        email: 'maria@example.com',
        password: 'Carman123',
        remember: true,
      );
      expect(session.user.city, 'Medellín');
    });
  });

  group('DemoBookingRepository', () {
    late DemoBookingRepository repository;
    late BookingDraft draft;

    setUp(() {
      repository = DemoBookingRepository();
      final start = DateTime.now().add(const Duration(days: 2));
      final vehicle = MockData.vehicles.first;
      draft = BookingDraft(
        vehicle: vehicle,
        startAt: start,
        endAt: start.add(const Duration(days: 3)),
        mode: RentalMode.daily,
        pickupPoint: vehicle.pickupPoint!,
        insurance: InsurancePlan.premium,
      );
    });

    test('declines the special test card', () async {
      final card = PaymentMethod(
        id: 'decline',
        type: PaymentMethodType.card,
        label: 'Visa Crédito',
        subtitle: 'Test',
        last4: '0002',
      );

      expect(
        () => repository.createReservation(draft: draft, paymentMethod: card),
        throwsA(isA<PaymentDeclinedException>()),
      );
    });

    test('creates, lists, cancels and reviews a reservation', () async {
      final reservation = await repository.createReservation(
        draft: draft,
        paymentMethod: PaymentMethodsSeed.applePay,
      );

      expect(reservation.status, ReservationStatus.confirmed);
      expect(reservation.pricing.total, closeTo(366.63, 0.01));

      final list = await repository.fetchReservations();
      expect(list.any((item) => item.id == reservation.id), isTrue);

      final cancelled = await repository.cancelReservation(reservation.id);
      expect(cancelled.status, ReservationStatus.cancelled);

      final reviewed = await repository.submitReview(
        id: reservation.id,
        rating: 5,
        comment: 'Excelente',
      );
      expect(reviewed.hasReview, isTrue);
    });

    test('rejects an invalid date range', () async {
      final invalid = BookingDraft(
        vehicle: draft.vehicle,
        startAt: draft.endAt,
        endAt: draft.startAt,
        mode: draft.mode,
        pickupPoint: draft.pickupPoint,
        insurance: draft.insurance,
      );

      expect(
        () => repository.createReservation(
          draft: invalid,
          paymentMethod: PaymentMethodsSeed.applePay,
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
