import 'package:material_ui/material_ui.dart';

import 'vehicle.dart';

enum OwnerVehicleStatus {
  available(
    'Disponible',
    Color(0xFF0E8A75),
    Icons.check_circle_outline_rounded,
  ),
  rented('Alquilado', Color(0xFF6B38D4), Icons.key_rounded),
  maintenance('Mantenimiento', Color(0xFFB45309), Icons.build_rounded),
  review('Revisión pendiente', Color(0xFF2563EB), Icons.fact_check_outlined);

  const OwnerVehicleStatus(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;

  static OwnerVehicleStatus fromApi(Object? value) {
    return switch ('$value'.toLowerCase()) {
      'activo' || 'disponible' || 'available' => available,
      'alquilado' || 'rented' || 'en_uso' => rented,
      'en_mantenimiento' || 'mantenimiento' || 'maintenance' => maintenance,
      'revision_pendiente' || 'review' || 'pendiente' => review,
      _ => available,
    };
  }
}

class OwnerVehicle {
  const OwnerVehicle({
    required this.id,
    required this.vehicleId,
    required this.status,
    required this.nextService,
    required this.monthlyRevenue,
    required this.tripsThisMonth,
    this.documentsInOrder = true,
  });

  final String id;
  final String vehicleId;
  final OwnerVehicleStatus status;
  final DateTime nextService;
  final double monthlyRevenue;
  final int tripsThisMonth;
  final bool documentsInOrder;
}

class OwnerStats {
  const OwnerStats({
    required this.vehicles,
    required this.activeVehicles,
    required this.monthlyRevenue,
    required this.pendingReservations,
    required this.occupancyRate,
    required this.previousMonthRevenue,
  });

  final int vehicles;
  final int activeVehicles;
  final double monthlyRevenue;
  final int pendingReservations;
  final double occupancyRate;
  final double previousMonthRevenue;

  double get growth {
    if (previousMonthRevenue == 0) return 0;
    return ((monthlyRevenue - previousMonthRevenue) / previousMonthRevenue) *
        100;
  }
}

class OwnerListing {
  const OwnerListing({required this.meta, required this.vehicle});

  final OwnerVehicle meta;
  final Vehicle vehicle;
}

class OwnerDashboardData {
  const OwnerDashboardData({required this.stats, required this.listings});

  final OwnerStats stats;
  final List<OwnerListing> listings;
}
