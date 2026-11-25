import 'package:material_ui/material_ui.dart';

import 'vehicle.dart';

enum DriverAvailability {
  offline(
    'Desconectado',
    Color(0xFF8B8B95),
    Icons.pause_circle_outline_rounded,
  ),
  online('Disponible', Color(0xFF0E8A75), Icons.check_circle_rounded),
  onTrip('En servicio', Color(0xFF7C5AF6), Icons.directions_car_filled_rounded);

  const DriverAvailability(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}

enum DriverTripStatus {
  offered('Nuevo', Color(0xFF7C5AF6), Icons.bolt_rounded),
  accepted('Aceptado', Color(0xFF2563EB), Icons.check_rounded),
  enRoute('En camino', Color(0xFFB45309), Icons.navigation_rounded),
  inProgress('En curso', Color(0xFF0E8A75), Icons.directions_car_rounded),
  completed('Completado', Color(0xFF5F5F69), Icons.done_all_rounded),
  cancelled('Cancelado', Color(0xFFBA1A1A), Icons.cancel_outlined);

  const DriverTripStatus(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;

  bool get isCurrent =>
      this == accepted || this == enRoute || this == inProgress;

  bool get canAccept => this == offered;

  static DriverTripStatus fromApi(Object? value) {
    final normalized = '${value ?? ''}'.toLowerCase();
    if (normalized.contains('ofert') || normalized.contains('offer')) {
      return offered;
    }
    if (normalized.contains('acept') || normalized.contains('accept')) {
      return accepted;
    }
    if (normalized.contains('camino') || normalized.contains('route')) {
      return enRoute;
    }
    if (normalized.contains('curso') || normalized.contains('progress')) {
      return inProgress;
    }
    if (normalized.contains('complet') || normalized.contains('done')) {
      return completed;
    }
    if (normalized.contains('cancel')) return cancelled;
    return offered;
  }
}

class DriverTrip {
  const DriverTrip({
    required this.id,
    required this.clientName,
    required this.clientPhone,
    required this.vehicle,
    required this.origin,
    required this.destination,
    required this.scheduledAt,
    required this.distanceKm,
    required this.durationMinutes,
    required this.earnings,
    this.status = DriverTripStatus.offered,
    this.clientAvatarAsset,
    this.notes = '',
  });

  final String id;
  final String clientName;
  final String clientPhone;
  final String? clientAvatarAsset;
  final Vehicle vehicle;
  final String origin;
  final String destination;
  final DateTime scheduledAt;
  final double distanceKm;
  final int durationMinutes;
  final double earnings;
  final DriverTripStatus status;
  final String notes;

  bool get isCurrent => status.isCurrent;

  DriverTrip copyWith({DriverTripStatus? status}) {
    return DriverTrip(
      id: id,
      clientName: clientName,
      clientPhone: clientPhone,
      clientAvatarAsset: clientAvatarAsset,
      vehicle: vehicle,
      origin: origin,
      destination: destination,
      scheduledAt: scheduledAt,
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      earnings: earnings,
      status: status ?? this.status,
      notes: notes,
    );
  }
}

class DriverStats {
  const DriverStats({
    required this.tripsToday,
    required this.earningsToday,
    required this.earningsWeek,
    required this.rating,
    required this.acceptanceRate,
    required this.hoursOnline,
    required this.completedTotal,
  });

  final int tripsToday;
  final double earningsToday;
  final double earningsWeek;
  final double rating;
  final double acceptanceRate;
  final double hoursOnline;
  final int completedTotal;

  DriverStats copyWith({
    int? tripsToday,
    double? earningsToday,
    double? earningsWeek,
    double? rating,
    double? acceptanceRate,
    double? hoursOnline,
    int? completedTotal,
  }) {
    return DriverStats(
      tripsToday: tripsToday ?? this.tripsToday,
      earningsToday: earningsToday ?? this.earningsToday,
      earningsWeek: earningsWeek ?? this.earningsWeek,
      rating: rating ?? this.rating,
      acceptanceRate: acceptanceRate ?? this.acceptanceRate,
      hoursOnline: hoursOnline ?? this.hoursOnline,
      completedTotal: completedTotal ?? this.completedTotal,
    );
  }
}

class DriverDashboardData {
  const DriverDashboardData({
    required this.stats,
    required this.availability,
    required this.trips,
  });

  final DriverStats stats;
  final DriverAvailability availability;
  final List<DriverTrip> trips;

  DriverDashboardData copyWith({
    DriverStats? stats,
    DriverAvailability? availability,
    List<DriverTrip>? trips,
  }) {
    return DriverDashboardData(
      stats: stats ?? this.stats,
      availability: availability ?? this.availability,
      trips: trips ?? this.trips,
    );
  }
}
