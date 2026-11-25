import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/booking/presentation/screens/booking_success_screen.dart';
import '../../features/booking/presentation/screens/checkout_screen.dart';
import '../../features/booking/presentation/screens/payment_failed_screen.dart';
import '../../features/booking/presentation/screens/payment_methods_screen.dart';
import '../../features/booking/presentation/screens/reservation_expired_screen.dart';
import '../../features/driver/presentation/screens/driver_dashboard_screen.dart';
import '../../features/explore/presentation/screens/home_screen.dart';
import '../../features/explore/presentation/screens/results_screen.dart';
import '../../features/explore/presentation/screens/search_screen.dart';
import '../../features/favorites/presentation/screens/favorites_screen.dart';
import '../../features/license/presentation/screens/license_review_screen.dart';
import '../../features/license/presentation/screens/license_verification_screen.dart';
import '../../features/owner/presentation/screens/add_vehicle_screen.dart';
import '../../features/owner/presentation/screens/owner_dashboard_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/shell/presentation/main_shell.dart';
import '../../features/trips/presentation/screens/trip_detail_screen.dart';
import '../../features/trips/presentation/screens/trips_screen.dart';
import '../../features/vehicle/presentation/screens/gallery_screen.dart';
import '../../features/vehicle/presentation/screens/map_screen.dart';
import '../../features/vehicle/presentation/screens/vehicle_detail_screen.dart';
import '../../shared/widgets/responsive_layout.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_routes.dart';

final _routerRefreshProvider = Provider<_RouterRefresh>((ref) {
  final notifier = _RouterRefresh(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_routerRefreshProvider);
  final initialAuth = ref.read(authControllerProvider);

  return GoRouter(
    initialLocation: initialAuth.isAuthenticated
        ? AppRoutes.home
        : AppRoutes.welcome,
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final path = state.uri.path;
      final isPublic = _publicRoutes.contains(path);
      final isAuthFlow =
          path == AppRoutes.login ||
          path == AppRoutes.register ||
          path == AppRoutes.welcome ||
          path == AppRoutes.forgotPassword;

      if (!auth.isAuthenticated && !isPublic) {
        return auth.pendingVerification
            ? AppRoutes.verifyOtp
            : AppRoutes.welcome;
      }
      if (auth.isAuthenticated && isAuthFlow) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => ResponsiveRouteFrame(
          maxWidth: 620,
          child: LoginScreen(initialEmail: state.uri.queryParameters['email']),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) =>
            const ResponsiveRouteFrame(maxWidth: 680, child: RegisterScreen()),
      ),
      GoRoute(
        path: AppRoutes.verifyOtp,
        builder: (context, state) =>
            const ResponsiveRouteFrame(maxWidth: 560, child: OtpScreen()),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ResponsiveRouteFrame(
          maxWidth: 560,
          child: ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => ResponsiveRouteFrame(
          maxWidth: 560,
          child: ResetPasswordScreen(email: state.uri.queryParameters['email']),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'results',
                    builder: (context, state) => const ResultsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.favorites,
                builder: (context, state) => const FavoritesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.trips,
                builder: (context, state) => const TripsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) =>
            const ResponsiveRouteFrame(maxWidth: 900, child: SearchScreen()),
      ),
      GoRoute(
        path: '/vehicle/:id',
        builder: (context, state) => ResponsiveRouteFrame(
          maxWidth: 900,
          child: VehicleDetailScreen(vehicleId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/gallery/:id',
        builder: (context, state) =>
            GalleryScreen(vehicleId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.map,
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        builder: (context, state) =>
            const ResponsiveRouteFrame(maxWidth: 960, child: CheckoutScreen()),
      ),
      GoRoute(
        path: AppRoutes.paymentMethods,
        builder: (context, state) => const ResponsiveRouteFrame(
          maxWidth: 820,
          child: PaymentMethodsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.bookingSuccess,
        builder: (context, state) => const ResponsiveRouteFrame(
          maxWidth: 680,
          child: BookingSuccessScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.bookingFailed,
        builder: (context, state) => const ResponsiveRouteFrame(
          maxWidth: 800,
          child: PaymentFailedScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.bookingExpired,
        builder: (context, state) => const ResponsiveRouteFrame(
          maxWidth: 800,
          child: ReservationExpiredScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.license,
        builder: (context, state) => const ResponsiveRouteFrame(
          maxWidth: 820,
          child: LicenseVerificationScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.licenseReview,
        builder: (context, state) => const ResponsiveRouteFrame(
          maxWidth: 800,
          child: LicenseReviewScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const ResponsiveRouteFrame(
          maxWidth: 760,
          child: NotificationsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) => const ResponsiveRouteFrame(
          maxWidth: 700,
          child: EditProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/trip/:id',
        builder: (context, state) => ResponsiveRouteFrame(
          maxWidth: 900,
          child: TripDetailScreen(reservationId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.driver,
        builder: (context, state) => const ResponsiveRouteFrame(
          maxWidth: 900,
          child: DriverDashboardScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.admin,
        builder: (context, state) => const ResponsiveRouteFrame(
          maxWidth: 1000,
          child: AdminDashboardScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.owner,
        builder: (context, state) => const ResponsiveRouteFrame(
          maxWidth: 1240,
          child: OwnerDashboardScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.addVehicle,
        builder: (context, state) => const ResponsiveRouteFrame(
          maxWidth: 760,
          child: AddVehicleScreen(),
        ),
      ),
    ],
    errorBuilder: (context, state) => _NotFoundScreen(message: state.uri.path),
  );
});

const _publicRoutes = {
  AppRoutes.welcome,
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.verifyOtp,
  AppRoutes.forgotPassword,
  AppRoutes.resetPassword,
};

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.explore_off_rounded,
                  size: 54,
                  color: AppColors.tertiaryText,
                ),
                const SizedBox(height: 14),
                Text('Página no encontrada', style: AppTheme.headlineMd),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: AppTheme.bodySm,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('Volver al inicio'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
