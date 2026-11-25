import '../../core/constants/app_assets.dart';
import '../models/driver_models.dart';
import 'mock_data.dart';

abstract final class DriverMockData {
  static List<DriverTrip> trips() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [
      DriverTrip(
        id: 'svc-1001',
        clientName: 'Laura Pérez',
        clientPhone: '+57 301 555 0192',
        clientAvatarAsset: AppAssets.avatarElenaAlt,
        vehicle: MockData.vehicles[0],
        origin: 'Centro Histórico · Plaza de la Aduana',
        destination: 'Hotel Estelar · Bocagrande',
        scheduledAt: today.add(const Duration(hours: 15, minutes: 30)),
        distanceKm: 4.2,
        durationMinutes: 18,
        earnings: 18,
        status: DriverTripStatus.enRoute,
        notes: 'El cliente está en la recepción del hotel.',
      ),
      DriverTrip(
        id: 'svc-1002',
        clientName: 'María Gómez',
        clientPhone: '+57 300 771 2044',
        clientAvatarAsset: AppAssets.avatarUser,
        vehicle: MockData.vehicles[3],
        origin: 'Aeropuerto Rafael Núñez · Terminal nacional',
        destination: 'Bocagrande · Calle 6',
        scheduledAt: today.add(const Duration(hours: 17, minutes: 30)),
        distanceKm: 12.4,
        durationMinutes: 35,
        earnings: 28,
        status: DriverTripStatus.offered,
      ),
      DriverTrip(
        id: 'svc-1003',
        clientName: 'Andrés Prieto',
        clientPhone: '+57 315 240 8830',
        clientAvatarAsset: AppAssets.avatarElena,
        vehicle: MockData.vehicles[2],
        origin: 'Manga · Calle 28',
        destination: 'Getsemaní · Plaza Trinidad',
        scheduledAt: today.add(const Duration(hours: 20)),
        distanceKm: 6.1,
        durationMinutes: 22,
        earnings: 20,
        status: DriverTripStatus.offered,
      ),
      DriverTrip(
        id: 'svc-0998',
        clientName: 'Daniel Mejía',
        clientPhone: '+57 302 010 4833',
        vehicle: MockData.vehicles[4],
        origin: 'Castillogrande',
        destination: 'Centro · Torre del Reloj',
        scheduledAt: today.add(const Duration(hours: 9, minutes: 15)),
        distanceKm: 7.8,
        durationMinutes: 26,
        earnings: 32,
        status: DriverTripStatus.completed,
      ),
    ];
  }

  static const stats = DriverStats(
    tripsToday: 4,
    earningsToday: 86,
    earningsWeek: 412,
    rating: 4.92,
    acceptanceRate: 0.96,
    hoursOnline: 5.5,
    completedTotal: 328,
  );
}
