import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../data/models/booking.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_button.dart';
import '../../../../shared/widgets/carman_card.dart';
import '../../../../shared/widgets/carman_image.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/sheets.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../application/booking_controller.dart';

class BookingSuccessScreen extends ConsumerWidget {
  const BookingSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservation = ref.watch(bookingControllerProvider).lastReservation;
    if (reservation == null) {
      return Scaffold(
        body: EmptyState(
          title: 'No encontramos la reserva',
          message: 'Vuelve a tus viajes para ver el estado de tus reservas.',
          icon: Icons.receipt_long_outlined,
          actionLabel: 'Ir a mis viajes',
          onAction: () => context.go('/trips'),
        ),
      );
    }
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) =>
                      Transform.scale(scale: value, child: child),
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: AppColors.successContainer,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 42,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '¡Reserva confirmada!',
                textAlign: TextAlign.center,
                style: AppTheme.headlineLg.copyWith(fontSize: 27),
              ),
              const SizedBox(height: 6),
              Text(
                'Tu llave digital estará lista antes de la entrega.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyMd.copyWith(
                  color: AppColors.tertiaryText,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              CarmanCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CarmanImage(
                            reservation.vehicle.primaryPhoto,
                            width: 95,
                            height: 72,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Código de reserva',
                                style: AppTheme.bodySm.copyWith(fontSize: 9.5),
                              ),
                              Text(
                                reservation.code,
                                style: AppTheme.titleLg.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                reservation.vehicle.fullTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.bodySm.copyWith(fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                        const StatusBadge(
                          label: 'Confirmada',
                          color: AppColors.success,
                          icon: Icons.check_circle_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(),
                    const SizedBox(height: 12),
                    _Row(
                      icon: Icons.calendar_month_rounded,
                      label: 'Fechas',
                      value: reservation.datesLabel,
                    ),
                    const SizedBox(height: 9),
                    _Row(
                      icon: Icons.location_on_rounded,
                      label: 'Entrega',
                      value: reservation.pickupPoint.name,
                    ),
                    const SizedBox(height: 9),
                    _Row(
                      icon: Icons.payments_outlined,
                      label: 'Total pagado',
                      value: AppFormatters.money(
                        reservation.pricing.total,
                        precise: true,
                      ),
                    ),
                    const SizedBox(height: 9),
                    _Row(
                      icon: Icons.credit_card_rounded,
                      label: 'Método',
                      value: reservation.paymentMethodLabel,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.softLavender,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.key_rounded,
                        color: AppColors.primary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Llave digital',
                            style: AppTheme.labelMd.copyWith(fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            reservation.digitalKeyCode,
                            style: AppTheme.bodySm.copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showDigitalKey(context, reservation),
                      child: const Text('Abrir'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              CarmanButton(
                label: 'Ver mis viajes',
                icon: Icons.receipt_long_outlined,
                onPressed: () => context.go('/trips'),
              ),
              const SizedBox(height: 8),
              CarmanButton(
                label: 'Volver a explorar',
                variant: CarmanButtonVariant.outline,
                onPressed: () => context.go('/home'),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => showCarmanSnack(
                    context,
                    'Factura enviada a tu correo electrónico.',
                    kind: SnackKind.success,
                  ),
                  child: const Text('Enviar factura por correo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDigitalKey(BuildContext context, Reservation reservation) {
    showCarmanSheet<void>(
      context: context,
      maxHeightFactor: 0.6,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeader(
            title: 'Llave digital',
            subtitle: 'Se activará 15 minutos antes de tu reserva.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Column(
                children: [
                  const Icon(Icons.nfc_rounded, color: Colors.white, size: 38),
                  const SizedBox(height: 10),
                  Text(
                    reservation.digitalKeyCode,
                    style: AppTheme.headlineMd.copyWith(
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Apertura remota · ${reservation.vehicle.title}',
                    style: AppTheme.bodySm.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SafeArea(top: false, child: SizedBox(height: 10)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.tertiaryText),
        const SizedBox(width: 7),
        Text(label, style: AppTheme.bodySm.copyWith(fontSize: 10.5)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTheme.labelMd.copyWith(
              fontSize: 11,
              color: AppColors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
