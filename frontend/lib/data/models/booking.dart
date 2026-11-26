import 'package:material_ui/material_ui.dart';

import '../../core/config/app_config.dart';
import 'vehicle.dart';
import 'vehicle_query.dart';

/// Insurance products available at checkout.
class InsurancePlan {
  const InsurancePlan({
    required this.id,
    required this.name,
    required this.description,
    required this.dailyPrice,
    required this.deductible,
    this.isRecommended = false,
    this.isIncluded = false,
  });

  final String id;
  final String name;
  final String description;
  final double dailyPrice;
  final double deductible;
  final bool isRecommended;
  final bool isIncluded;

  String get deductibleLabel => deductible == 0
      ? 'Franquicia 0€'
      : 'Franquicia ${deductible.toStringAsFixed(0)}€';

  static const basic = InsurancePlan(
    id: 'basic',
    name: 'Cobertura Carman',
    description:
        'Seguro obligatorio, asistencia en carretera y daños a terceros.',
    dailyPrice: 0,
    deductible: 900,
    isIncluded: true,
  );

  static const premium = InsurancePlan(
    id: 'premium',
    name: 'Allianz Premium',
    description: 'Cobertura todo riesgo, franquicia 0€, lunas y neumáticos incluidos, asistencia 24/7.',
    dailyPrice: 18,
    deductible: 0,
    isRecommended: true,
  );
}

class PricingBreakdown {
  const PricingBreakdown({
    required this.mode,
    required this.units,
    required this.unitRate,
    required this.rentalSubtotal,
    required this.insuranceUnits,
    required this.insuranceSubtotal,
    required this.serviceFee,
    required this.taxes,
    required this.discount,
    required this.deposit,
  });

  final RentalMode mode;
  final int units;
  final double unitRate;
  final double rentalSubtotal;
  final int insuranceUnits;
  final double insuranceSubtotal;
  final double serviceFee;
  final double taxes;
  final double discount;
  final double deposit;

  double get subtotal => rentalSubtotal + insuranceSubtotal + serviceFee;
  double get total => subtotal + taxes - discount;

  String get unitLabel {
    if (mode == RentalMode.hourly) return units == 1 ? 'hora' : 'horas';
    return units == 1 ? 'día' : 'días';
  }

  String get rentalLabel => 'Alquiler (${_rate(unitRate)} x $units $unitLabel)';

  static String _rate(double value) {
    if (value % 1 == 0) return '\$${value.toInt()}';
    return '\$${value.toStringAsFixed(2)}';
  }
}

abstract final class PricingService {
  static PricingBreakdown calculate({
    required Vehicle vehicle,
    required RentalMode mode,
    required DateTime startAt,
    required DateTime endAt,
    required InsurancePlan insurance,
  }) {
    if (AppConfig.useLiveApi) {
      // El backend cobra días (DATEDIFF mínimo 1), no horas, IVA, seguro,
      // servicio, depósito ni descuentos calculados solo para la demo.
      final days = DateTime(endAt.year, endAt.month, endAt.day)
          .difference(DateTime(startAt.year, startAt.month, startAt.day))
          .inDays.clamp(1, 365);
      return PricingBreakdown(
        mode: RentalMode.daily,
        units: days,
        unitRate: vehicle.pricePerDay,
        rentalSubtotal: vehicle.pricePerDay * days,
        insuranceUnits: 0,
        insuranceSubtotal: 0,
        serviceFee: 0,
        taxes: 0,
        discount: 0,
        deposit: 0,
      );
    }
    final difference = endAt.difference(startAt);
    final hours = (difference.inMinutes / 60).ceil().clamp(2, 24 * 30);
    final days = (difference.inHours / 24).ceil().clamp(1, 30);
    final units = mode == RentalMode.hourly ? hours : days;
    final unitRate = mode == RentalMode.hourly
        ? vehicle.pricePerHour
        : vehicle.pricePerDay;
    final rentalSubtotal = unitRate * units;

    // Weekly discount for long daily rentals.
    final discount = mode == RentalMode.daily && days >= 7
        ? rentalSubtotal * 0.10
        : 0.0;

    final insuranceUnits = mode == RentalMode.hourly ? days : units;
    final insuranceSubtotal = insurance.dailyPrice * insuranceUnits;
    final serviceFee = mode == RentalMode.hourly
        ? (units * 4).clamp(6, 80).toDouble()
        : days * 8.0;
    final taxable = rentalSubtotal - discount + insuranceSubtotal + serviceFee;
    final taxes = taxable * AppConfig.taxRate;

    return PricingBreakdown(
      mode: mode,
      units: units,
      unitRate: unitRate,
      rentalSubtotal: rentalSubtotal,
      insuranceUnits: insuranceUnits,
      insuranceSubtotal: insuranceSubtotal,
      serviceFee: serviceFee,
      taxes: taxes,
      discount: discount,
      deposit: 150,
    );
  }

  static int unitsFor({
    required RentalMode mode,
    required DateTime startAt,
    required DateTime endAt,
  }) {
    final difference = endAt.difference(startAt);
    if (mode == RentalMode.hourly) {
      final hours = (difference.inMinutes / 60).ceil();
      return hours < 2 ? 2 : hours;
    }
    final days = (difference.inHours / 24).ceil();
    return days < 1 ? 1 : days;
  }
}

class BookingDraft {
  const BookingDraft({
    required this.vehicle,
    required this.startAt,
    required this.endAt,
    required this.mode,
    required this.pickupPoint,
    required this.insurance,
    this.paymentMethodId,
    this.paymentMethodLabel,
  });

  final Vehicle vehicle;
  final DateTime startAt;
  final DateTime endAt;
  final RentalMode mode;
  final PickupPoint pickupPoint;
  final InsurancePlan insurance;
  final String? paymentMethodId;
  final String? paymentMethodLabel;

  PricingBreakdown get pricing => PricingService.calculate(
    vehicle: vehicle,
    mode: mode,
    startAt: startAt,
    endAt: endAt,
    insurance: insurance,
  );

  String get datesLabel {
    final days = PricingService.unitsFor(
      mode: mode,
      startAt: startAt,
      endAt: endAt,
    );
    final suffix = mode == RentalMode.hourly ? '$days h' : '$days días';
    return '${_day(startAt)} – ${_day(endAt)} ($suffix)';
  }

  String _day(DateTime date) {
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  BookingDraft copyWith({
    DateTime? startAt,
    DateTime? endAt,
    RentalMode? mode,
    PickupPoint? pickupPoint,
    InsurancePlan? insurance,
    String? paymentMethodId,
    String? paymentMethodLabel,
  }) {
    return BookingDraft(
      vehicle: vehicle,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      mode: mode ?? this.mode,
      pickupPoint: pickupPoint ?? this.pickupPoint,
      insurance: insurance ?? this.insurance,
      paymentMethodId: paymentMethodId ?? this.paymentMethodId,
      paymentMethodLabel: paymentMethodLabel ?? this.paymentMethodLabel,
    );
  }
}

enum ReservationStatus {
  pendingPayment('Pendiente', Color(0xFFB45309), Icons.schedule_rounded),
  confirmed(
    'Confirmada',
    Color(0xFF0E8A75),
    Icons.check_circle_outline_rounded,
  ),
  active('En curso', Color(0xFF6B38D4), Icons.key_rounded),
  completed('Completada', Color(0xFF525252), Icons.done_all_rounded),
  cancelled('Cancelada', Color(0xFF7B7486), Icons.cancel_outlined),
  rejected('Rechazada', Color(0xFFBA1A1A), Icons.error_outline_rounded),
  expired('Expirada', Color(0xFF7B7486), Icons.hourglass_disabled_rounded);

  const ReservationStatus(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;

  bool get isUpcoming =>
      this == pendingPayment || this == confirmed || this == active;

  bool get isFinal => this == completed || this == cancelled || this == expired;
}

class Reservation {
  const Reservation({
    required this.id,
    required this.code,
    required this.vehicle,
    required this.startAt,
    required this.endAt,
    required this.mode,
    required this.pickupPoint,
    required this.pricing,
    required this.status,
    required this.createdAt,
    this.paymentMethodLabel = 'Apple Pay · Mastercard •••• 4242',
    this.digitalKeyCode = 'CRMN-4821',
    this.insuranceName = 'Allianz Premium',
    this.hasReview = false,
    this.canReview = true,
    this.cancellationFee = 0,
    this.canOperate = false,
    this.awaitingDriverDecision = false,
  });

  final String id;
  final String code;
  final Vehicle vehicle;
  final DateTime startAt;
  final DateTime endAt;
  final RentalMode mode;
  final PickupPoint pickupPoint;
  final PricingBreakdown pricing;
  final ReservationStatus status;
  final DateTime createdAt;
  final String paymentMethodLabel;
  final String digitalKeyCode;
  final String insuranceName;
  final bool hasReview;
  final bool canReview;
  final double cancellationFee;
  final bool canOperate;
  final bool awaitingDriverDecision;

  String get datesLabel {
    final days = PricingService.unitsFor(
      mode: mode,
      startAt: startAt,
      endAt: endAt,
    );
    final suffix = mode == RentalMode.hourly ? '$days h' : '$days días';
    return '${_day(startAt)} – ${_day(endAt)} ($suffix)';
  }

  String _day(DateTime date) {
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  bool get isCancellable =>
      status == ReservationStatus.confirmed &&
      startAt.difference(DateTime.now()).inHours >= 24;

  Reservation copyWith({
    ReservationStatus? status,
    String? paymentMethodLabel,
    bool? hasReview,
  }) {
    return Reservation(
      id: id,
      code: code,
      vehicle: vehicle,
      startAt: startAt,
      endAt: endAt,
      mode: mode,
      pickupPoint: pickupPoint,
      pricing: pricing,
      status: status ?? this.status,
      createdAt: createdAt,
      paymentMethodLabel: paymentMethodLabel ?? this.paymentMethodLabel,
      digitalKeyCode: digitalKeyCode,
      insuranceName: insuranceName,
      hasReview: hasReview ?? this.hasReview,
      canReview: canReview,
      cancellationFee: cancellationFee,
      canOperate: canOperate,
      awaitingDriverDecision: awaitingDriverDecision,
    );
  }
}

enum PaymentFailure {
  cardDeclined,
  insufficientFunds,
  expiredHold,
  networkError,
}
