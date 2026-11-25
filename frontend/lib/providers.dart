import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_config.dart';
import 'data/local/session_store.dart';
import 'data/models/vehicle.dart';
import 'data/remote/api_client.dart';
import 'data/repositories/admin_repository.dart';
import 'data/repositories/api_booking_repository.dart';
import 'data/repositories/api_notification_repository.dart';
import 'data/repositories/api_profile_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/booking_repository.dart';
import 'data/repositories/driver_repository.dart';
import 'data/repositories/notification_repository.dart';
import 'data/repositories/owner_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'data/repositories/vehicle_repository.dart';

/// Overridden in `main.dart` after SharedPreferences finishes loading.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('SharedPreferences no inicializado'),
);

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SessionStore(ref.watch(sharedPreferencesProvider)),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.dispose);
  return client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (AppConfig.useLiveApi) {
    return ApiAuthRepository(
      ref.watch(apiClientProvider),
      ref.watch(sessionStoreProvider),
    );
  }
  return DemoAuthRepository(ref.watch(sessionStoreProvider));
});

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  if (AppConfig.useLiveApi) {
    return ApiVehicleRepository(
      ref.watch(apiClientProvider),
      ref.watch(sessionStoreProvider),
    );
  }
  return DemoVehicleRepository();
});

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  if (AppConfig.useLiveApi) {
    return ApiBookingRepository(
      ref.watch(apiClientProvider),
      ref.watch(sessionStoreProvider),
    );
  }
  return DemoBookingRepository();
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  if (AppConfig.useLiveApi) {
    return ApiProfileRepository(
      ref.watch(apiClientProvider),
      ref.watch(sessionStoreProvider),
    );
  }
  return DemoProfileRepository();
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  if (AppConfig.useLiveApi) {
    return ApiNotificationRepository(
      ref.watch(apiClientProvider),
      ref.watch(sessionStoreProvider),
    );
  }
  return DemoNotificationRepository();
});

final ownerRepositoryProvider = Provider<OwnerRepository>((ref) {
  if (AppConfig.useLiveApi) {
    return ApiOwnerRepository(
      ref.watch(apiClientProvider),
      ref.watch(sessionStoreProvider),
    );
  }
  return DemoOwnerRepository();
});

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  if (AppConfig.useLiveApi) {
    return ApiDriverRepository(
      ref.watch(apiClientProvider),
      ref.watch(sessionStoreProvider),
    );
  }
  return DemoDriverRepository();
});

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  if (AppConfig.useLiveApi) {
    return ApiAdminRepository(
      ref.watch(apiClientProvider),
      ref.watch(sessionStoreProvider),
    );
  }
  return DemoAdminRepository();
});

final pickupPointsProvider = FutureProvider.family<List<PickupPoint>, String>(
  (ref, city) => ref.watch(vehicleRepositoryProvider).fetchPickupPoints(city),
);

final vehicleByIdProvider = FutureProvider.family<Vehicle?, String>(
  (ref, id) => ref.watch(vehicleRepositoryProvider).fetchById(id),
);
