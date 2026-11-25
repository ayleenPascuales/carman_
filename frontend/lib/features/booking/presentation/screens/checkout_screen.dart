import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../data/models/booking.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../data/models/vehicle_query.dart';
import '../../../../providers.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_button.dart';
import '../../../../shared/widgets/carman_card.dart';
import '../../../../shared/widgets/carman_image.dart';
import '../../../../shared/widgets/carman_top_bar.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/sheets.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../application/booking_controller.dart';
import '../../application/payment_controller.dart';

class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingControllerProvider);
    final draft = booking.draft;

    if (draft == null) {
      return Scaffold(
        appBar: CarmanTopBar(
          title: 'Confirmar reserva',
          onBack: () => context.pop(),
        ),
        body: EmptyState(
          title: 'No hay una reserva en curso',
          message: 'Elige un vehículo para preparar tu checkout.',
          icon: Icons.shopping_bag_outlined,
          actionLabel: 'Explorar vehículos',
          onAction: () => context.go('/home'),
        ),
      );
    }

    final pricing = draft.pricing;
    final details = CarmanCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.calendar_month_rounded,
            title: draft.datesLabel,
            subtitle:
                '${AppFormatters.time(draft.startAt)} → ${AppFormatters.time(draft.endAt)}',
            onEdit: () => _editDates(context, ref, draft),
          ),
          const Divider(height: 1, indent: 48, endIndent: 14),
          _InfoRow(
            icon: Icons.place_outlined,
            title: draft.pickupPoint.name,
            subtitle: draft.pickupPoint.address,
            onEdit: () => _editPickup(context, ref, draft),
          ),
        ],
      ),
    );

    final lockLine = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          size: 12,
          color: AppColors.tertiaryText,
        ),
        const SizedBox(width: 4),
        Text(
          'Pago cifrado · Carman Shield',
          style: AppTheme.bodySm.copyWith(fontSize: 9),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: CarmanTopBar(title: 'Confirmar', onBack: () => context.pop()),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 780;
              final content = wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            children: [
                              _VehicleSummary(draft: draft),
                              const SizedBox(height: 10),
                              details,
                              const SizedBox(height: 10),
                              _InsuranceSelector(draft: draft),
                              const SizedBox(height: 12),
                              lockLine,
                            ],
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          flex: 4,
                          child: Column(
                            children: [
                              _CostBreakdown(
                                pricing: pricing,
                                insuranceName: draft.insurance.name,
                              ),
                              const SizedBox(height: 10),
                              _PaymentCard(
                                onTap: () => context.push('/payment-methods'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _VehicleSummary(draft: draft),
                        const SizedBox(height: 10),
                        details,
                        const SizedBox(height: 10),
                        _InsuranceSelector(draft: draft),
                        const SizedBox(height: 10),
                        _CostBreakdown(
                          pricing: pricing,
                          insuranceName: draft.insurance.name,
                        ),
                        const SizedBox(height: 10),
                        _PaymentCard(
                          onTap: () => context.push('/payment-methods'),
                        ),
                        const SizedBox(height: 12),
                        lockLine,
                      ],
                    );
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
                child: content,
              );
            },
          ),
          if (booking.isPaying) const _PaymentOverlay(),
        ],
      ),
      bottomNavigationBar: _CheckoutBar(
        total: pricing.total,
        isPaying: booking.isPaying,
        onPay: () => _pay(context, ref),
      ),
    );
  }

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
    final reminder = ref.read(bookingControllerProvider.notifier);
    final result = await reminder.pay();
    if (!context.mounted) return;
    switch (result) {
      case PaymentOutcome.success:
        context.pushReplacement('/booking/success');
      case PaymentOutcome.declined:
        unawaited(context.push('/booking/failed'));
      case PaymentOutcome.error:
        final error = ref.read(bookingControllerProvider).error;
        showCarmanSnack(
          context,
          error ?? 'No pudimos procesar el pago. Inténtalo de nuevo.',
          kind: SnackKind.error,
        );
      case PaymentOutcome.licenseRequired:
        await showConfirmDialog(
          context,
          title: 'Verifica tu licencia',
          message: 'Necesitamos validar tu permiso de conducir antes de completar la reserva.',
          confirmLabel: 'Verificar licencia',
          icon: Icons.verified_user_rounded,
        );
        if (context.mounted) unawaited(context.push('/license'));
    }
  }

  Future<void> _editDates(
    BuildContext context,
    WidgetRef ref,
    BookingDraft draft,
  ) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: draft.startAt, end: draft.endAt),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Fechas de tu reserva',
      saveText: 'Aplicar',
    );
    if (range == null) return;
    final startAt = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
      draft.startAt.hour,
      draft.startAt.minute,
    );
    var endAt = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      draft.endAt.hour,
      draft.endAt.minute,
    );
    if (draft.mode == RentalMode.hourly) {
      if (endAt.difference(startAt).inHours < 2) {
        endAt = startAt.add(const Duration(hours: 2));
      }
    } else if (!endAt.isAfter(startAt)) {
      endAt = startAt.add(const Duration(days: 1));
    }
    ref
        .read(bookingControllerProvider.notifier)
        .updateDates(startAt: startAt, endAt: endAt);
  }

  Future<void> _editPickup(
    BuildContext context,
    WidgetRef ref,
    BookingDraft draft,
  ) async {
    List<PickupPoint> points;
    try {
      points = await ref.read(
        pickupPointsProvider(draft.pickupPoint.city).future,
      );
    } catch (_) {
      if (context.mounted) {
        showCarmanSnack(
          context,
          'No se pudieron cargar los puntos autorizados.',
        );
      }
      return;
    }
    if (!context.mounted) return;
    if (points.isEmpty) {
      showCarmanSnack(context, 'No hay puntos disponibles en esta ciudad.');
      return;
    }
    final selected = await showCarmanSheet<PickupPoint>(
      context: context,
      maxHeightFactor: 0.75,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeader(
            title: 'Punto de entrega',
            subtitle: 'Cambiar el lugar de recogida de tu vehículo.',
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: points.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final point = points[index];
                final selected = point.id == draft.pickupPoint.id;
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    side: BorderSide(
                      color: selected
                          ? AppColors.primaryViolet
                          : AppColors.borderSoft,
                    ),
                  ),
                  tileColor: selected
                      ? AppColors.softLavender
                      : AppColors.surface,
                  leading: const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text(point.name, style: AppTheme.titleMd),
                  subtitle: Text(point.address, style: AppTheme.bodySm),
                  trailing: Text(
                    point.isFree ? 'Gratis' : 'Con cargo',
                    style: AppTheme.labelSm.copyWith(
                      color: AppColors.successText,
                      fontSize: 9.5,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, point),
                );
              },
            ),
          ),
        ],
      ),
    );
    if (selected != null) {
      ref.read(bookingControllerProvider.notifier).updatePickup(selected);
    }
  }
}

class _VehicleSummary extends StatelessWidget {
  const _VehicleSummary({required this.draft});

  final BookingDraft draft;

  @override
  Widget build(BuildContext context) {
    final vehicle = draft.vehicle;
    return CarmanCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CarmanImage(
                  vehicle.primaryPhoto,
                  width: 108,
                  height: 82,
                ),
              ),
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    vehicle.fuel == FuelType.electric ? 'EV' : 'AUTO',
                    style: AppTheme.labelSm.copyWith(
                      color: Colors.white,
                      fontSize: 8,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BadgePill(
                  label: vehicle.fuel == FuelType.electric
                      ? '100% ELÉCTRICO'
                      : vehicle.fuel.label.toUpperCase(),
                  icon: vehicle.fuel.icon,
                  background: AppColors.primaryFixed,
                  foreground: AppColors.onPrimaryFixed,
                ),
                const SizedBox(height: 5),
                Text(
                  vehicle.compactTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.titleLg.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Anfitrión ${vehicle.ownerFirstName}',
                      style: AppTheme.bodySm.copyWith(fontSize: 10.5),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.circle, size: 3, color: AppColors.border),
                    const SizedBox(width: 6),
                    RatingBadge(
                      rating: vehicle.rating,
                      count: vehicle.tripCount,
                      compact: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onEdit,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.labelMd.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodySm.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
            Text(
              'Editar',
              style: AppTheme.labelMd.copyWith(
                fontSize: 10.5,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsuranceSelector extends ConsumerWidget {
  const _InsuranceSelector({required this.draft});

  final BookingDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = [InsurancePlan.basic, InsurancePlan.premium];
    return CarmanCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_rounded,
                size: 17,
                color: AppColors.primary,
              ),
              const SizedBox(width: 7),
              Text('Cobertura', style: AppTheme.labelLg.copyWith(fontSize: 13)),
              const Spacer(),
              Text(
                'Tarifa ${AppFormatters.money(draft.pricing.unitRate)}',
                style: AppTheme.bodySm.copyWith(fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 9),
          for (final plan in plans) ...[
            InkWell(
              onTap: () => ref
                  .read(bookingControllerProvider.notifier)
                  .updateInsurance(plan),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: draft.insurance.id == plan.id
                      ? AppColors.softLavender.withValues(alpha: 0.45)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        color: draft.insurance.id == plan.id
                            ? AppColors.primaryViolet
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: draft.insurance.id == plan.id
                              ? AppColors.primaryViolet
                              : AppColors.border,
                          width: 1.6,
                        ),
                      ),
                      child: draft.insurance.id == plan.id
                          ? const Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                plan.name,
                                style: AppTheme.labelLg.copyWith(
                                  fontSize: 11.5,
                                ),
                              ),
                              if (plan.isRecommended) ...[
                                const SizedBox(width: 5),
                                const BadgePill(
                                  label: 'Recomendado',
                                  background: AppColors.primary,
                                  foreground: Colors.white,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      plan.dailyPrice == 0
                          ? 'Incluido'
                          : '${AppFormatters.money(plan.dailyPrice)}/día',
                      style: AppTheme.labelSm.copyWith(
                        fontSize: 9.5,
                        color: plan.dailyPrice == 0
                            ? AppColors.successText
                            : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 7),
          ],
        ],
      ),
    );
  }
}

class _CostBreakdown extends StatelessWidget {
  const _CostBreakdown({required this.pricing, required this.insuranceName});

  final PricingBreakdown pricing;
  final String insuranceName;

  @override
  Widget build(BuildContext context) {
    return CarmanCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'DESGLOSE DE COSTOS',
                style: AppTheme.labelSm.copyWith(
                  fontSize: 10.5,
                  color: AppColors.onSurface,
                  letterSpacing: 0.7,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.info_outline_rounded,
                size: 12,
                color: AppColors.tertiaryText,
              ),
              const SizedBox(width: 3),
              Text(
                'Transparente',
                style: AppTheme.bodySm.copyWith(fontSize: 9.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          KeyValueRow(
            label: pricing.rentalLabel,
            value: AppFormatters.money(pricing.rentalSubtotal, precise: true),
          ),
          KeyValueRow(
            label:
                'Seguro $insuranceName (${pricing.insuranceUnits} ${pricing.insuranceUnits == 1 ? 'día' : 'días'})',
            value: AppFormatters.money(
              pricing.insuranceSubtotal,
              precise: true,
            ),
          ),
          KeyValueRow(
            label: 'Tarifa de servicio Carman',
            value: AppFormatters.money(pricing.serviceFee, precise: true),
          ),
          KeyValueRow(
            label: 'Impuestos y tasas (IVA 21%)',
            value: AppFormatters.money(pricing.taxes, precise: true),
          ),
          if (pricing.discount > 0)
            KeyValueRow(
              label: 'Descuento semanal',
              value:
                  '- ${AppFormatters.money(pricing.discount, precise: true)}',
              valueColor: AppColors.successText,
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total a pagar',
                      style: AppTheme.titleLg.copyWith(fontSize: 14.5),
                    ),
                    Text(
                      'Incluye todas las tasas',
                      style: AppTheme.bodySm.copyWith(fontSize: 9.5),
                    ),
                  ],
                ),
              ),
              Text(
                AppFormatters.money(pricing.total, precise: true),
                style: AppTheme.headlineLg.copyWith(
                  color: AppColors.primary,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lock_reset_rounded,
                  size: 15,
                  color: AppColors.tertiaryText,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 9.5,
                        height: 1.45,
                      ),
                      children: [
                        TextSpan(
                          text:
                              'Depósito de garantía reembolsable: ${AppFormatters.money(pricing.deposit)}',
                          style: const TextStyle(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(
                          text: ' (se retiene temporalmente durante el viaje, no se cobra).',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends ConsumerWidget {
  const _PaymentCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final method = ref.watch(paymentControllerProvider).selected;
    return CarmanCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'MÉTODO DE PAGO',
                style: AppTheme.labelSm.copyWith(
                  fontSize: 10.5,
                  color: AppColors.onSurface,
                  letterSpacing: 0.7,
                ),
              ),
              const Spacer(),
              Text(
                'Cambiar',
                style: AppTheme.labelMd.copyWith(
                  color: AppColors.primary,
                  fontSize: 10.5,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.graphite,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(method.type.icon, color: Colors.white, size: 17),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            method.label,
                            style: AppTheme.labelLg.copyWith(fontSize: 12),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: AppColors.border,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              method.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.bodySm.copyWith(fontSize: 9.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        method.subtitle,
                        style: AppTheme.bodySm.copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 19,
                  height: 19,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryViolet,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryViolet,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.total,
    required this.isPaying,
    required this.onPay,
  });

  final double total;
  final bool isPaying;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: CarmanButton(
          label:
              'Confirmar y pagar ${AppFormatters.money(total, precise: true)}',
          icon: Icons.lock_rounded,
          isLoading: isPaying,
          onPressed: onPay,
          height: 54,
        ),
      ),
    );
  }
}

class _PaymentOverlay extends StatelessWidget {
  const _PaymentOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.graphite.withValues(alpha: 0.5),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33171717),
                  blurRadius: 30,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(height: 16),
                Text('Procesando pago seguro…', style: AppTheme.titleMd),
                const SizedBox(height: 4),
                Text(
                  'Estamos validando tu método de pago con Carman Shield.',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodySm.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
