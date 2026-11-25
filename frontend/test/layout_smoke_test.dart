import 'dart:convert';

import 'package:carman_app/core/theme/app_theme.dart';
import 'package:carman_app/data/mock/mock_data.dart';
import 'package:carman_app/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:carman_app/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:carman_app/features/auth/presentation/screens/login_screen.dart';
import 'package:carman_app/features/auth/presentation/screens/otp_screen.dart';
import 'package:carman_app/features/auth/presentation/screens/register_screen.dart';
import 'package:carman_app/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:carman_app/features/auth/presentation/screens/welcome_screen.dart';
import 'package:carman_app/features/booking/presentation/screens/checkout_screen.dart';
import 'package:carman_app/features/booking/presentation/screens/payment_failed_screen.dart';
import 'package:carman_app/features/booking/presentation/screens/payment_methods_screen.dart';
import 'package:carman_app/features/booking/presentation/screens/reservation_expired_screen.dart';
import 'package:carman_app/features/driver/presentation/screens/driver_dashboard_screen.dart';
import 'package:carman_app/features/explore/presentation/screens/home_screen.dart';
import 'package:carman_app/features/explore/presentation/screens/results_screen.dart';
import 'package:carman_app/features/explore/presentation/screens/search_screen.dart';
import 'package:carman_app/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:carman_app/features/license/presentation/screens/license_review_screen.dart';
import 'package:carman_app/features/license/presentation/screens/license_verification_screen.dart';
import 'package:carman_app/features/owner/presentation/screens/add_vehicle_screen.dart';
import 'package:carman_app/features/owner/presentation/screens/owner_dashboard_screen.dart';
import 'package:carman_app/features/profile/presentation/screens/notifications_screen.dart';
import 'package:carman_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:carman_app/features/trips/presentation/screens/trip_detail_screen.dart';
import 'package:carman_app/features/trips/presentation/screens/trips_screen.dart';
import 'package:carman_app/features/vehicle/presentation/screens/gallery_screen.dart';
import 'package:carman_app/features/vehicle/presentation/screens/map_screen.dart';
import 'package:carman_app/features/vehicle/presentation/screens/vehicle_detail_screen.dart';
import 'package:carman_app/providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Layout smoke tests: each screen must render at a phone viewport without
/// throwing overflow or assertion errors.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-Variable.ttf'));
    await loader.load();
    await initializeDateFormatting('es');
    await initializeDateFormatting('es_CO');
  });

  final screens = <String, Widget Function()>{
    'welcome': () => const WelcomeScreen(),
    'login': () => const LoginScreen(),
    'register': () => const RegisterScreen(),
    'forgot': () => const ForgotPasswordScreen(),
    'reset': () => const ResetPasswordScreen(email: 'alex@carman.app'),
    'otp': () => const OtpScreen(),
    'home': () => const HomeScreen(),
    'search': () => const SearchScreen(),
    'results': () => const ResultsScreen(),
    'favorites': () => const FavoritesScreen(),
    'vehicle detail': () => const VehicleDetailScreen(vehicleId: 'veh-tesla-y'),
    'gallery': () => const GalleryScreen(vehicleId: 'veh-tesla-y'),
    'map': () => const MapScreen(),
    'trips': () => const TripsScreen(),
    'trip detail': () => const TripDetailScreen(reservationId: 'res-upcoming'),
    'notifications': () => const NotificationsScreen(),
    'profile': () => const ProfileScreen(),
    'owner': () => const OwnerDashboardScreen(),
    'driver': () => const DriverDashboardScreen(),
    'admin': () => const AdminDashboardScreen(),
    'add vehicle': () => const AddVehicleScreen(),
    'checkout empty': () => const CheckoutScreen(),
    'payment methods': () => const PaymentMethodsScreen(),
    'payment failed': () => const PaymentFailedScreen(),
    'reservation expired': () => const ReservationExpiredScreen(),
    'license': () => const LicenseVerificationScreen(),
    'license review': () => const LicenseReviewScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('renders ${entry.key} without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({
        'carman.session.user': jsonEncode(MockData.demoUser.toJson()),
        'carman.session.token': 'test-token',
      });
      final preferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
          child: MaterialApp(theme: AppTheme.light, home: entry.value()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();

      expect(tester.takeException(), isNull);
      if (entry.key == 'search') {
        expect(find.textContaining('Instance of'), findsNothing);
        expect(find.textContaining('Cartagena'), findsWidgets);
      }
      if (entry.key == 'profile') {
        expect(find.text('Panel de conductor'), findsOneWidget);
        expect(find.text('Administración'), findsOneWidget);
      }
      if (entry.key == 'driver') {
        expect(find.text('Servicio actual'), findsOneWidget);
        expect(find.text('Solicitudes'), findsOneWidget);
      }
      if (entry.key == 'admin') {
        expect(find.text('Usuarios registrados'), findsOneWidget);
        expect(find.text('Aprobaciones pendientes'), findsOneWidget);
      }
    });
  }
  for (final entry in screens.entries) {
    testWidgets('renders ${entry.key} on desktop without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({
        'carman.session.user': jsonEncode(MockData.demoUser.toJson()),
        'carman.session.token': 'test-token',
      });
      final preferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
          child: MaterialApp(theme: AppTheme.light, home: entry.value()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  }
}
