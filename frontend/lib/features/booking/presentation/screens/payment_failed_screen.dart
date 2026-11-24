import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../data/mock/mock_data.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_button.dart';
import '../../../../shared/widgets/carman_card.dart';
import '../../../../shared/widgets/carman_image.dart';
import '../../../../shared/widgets/carman_top_bar.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../application/booking_controller.dart';

class PaymentFailedScreen extends ConsumerWidget {
  const PaymentFailedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingControllerProvider);
    final now = DateTime.now();
    final vehicle = state.failure?.vehicle ?? MockData.vehicles.first;
    final failure =
        state.failure ??
        BookingFailureData(
          vehicle: vehicle,
          startAt: now.add(const Duration(days: 1)),
          endAt: now.add(const Duration(days: 4)),
          total: 366.63,
          holdExpiresAt: now.add(const Duration(minutes: 10)),
        );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => context.go('/home'),
                  ),
                  const Spacer(),
                  RoundIconButton(
                    icon: Icons.help_outline_rounded,
                    onPressed: () => _contactSupport(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  Center(
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.credit_card_off_rounded,
                        size: 36,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pudimos procesar tu pago',
                    textAlign: TextAlign.center,
                    style: AppTheme.headlineLg.copyWith(fontSize: 26),
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      style: AppTheme.bodyMd.copyWith(
                        color: AppColors.tertiaryText,
                        height: 1.5,
                      ),
                      children: [
                        const TextSpan(text: 'Tu reserva para el '),
                        TextSpan(
                          text: vehicle.title,
                          style: const TextStyle(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: ' no se ha completado.'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  CarmanCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.errorContainer),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CÓDIGO: ${failure.declineCode}',
                                      style: AppTheme.labelSm.copyWith(
                                        fontSize: 9.5,
                                        color: AppColors.error,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      failure.reason,
                                      style: AppTheme.bodySm.copyWith(
                                        fontSize: 11,
                                        color: AppColors.secondaryText,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No se realizó ningún cobro de ${AppFormatters.money(failure.total, precise: true)}.',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 11,
                            height: 1.55,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  CarmanCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              'VEHÍCULO RETENIDO',
                              style: AppTheme.overline.copyWith(fontSize: 8.5),
                            ),
                            const Spacer(),
                            const StatusBadge(
                              label: 'Reserva Temporal',
                              small: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: CarmanImage(
                                vehicle.primaryPhoto,
                                width: 82,
                                height: 65,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vehicle.fullTitle,
                                    style: AppTheme.titleMd.copyWith(
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _SmallRow(
                                    icon: Icons.calendar_month_rounded,
                                    text: AppFormatters.dateRange(
                                      failure.startAt,
                                      failure.endAt,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  _SmallRow(
                                    icon: Icons.location_on_rounded,
                                    text:
                                        failure.vehicle.pickupPoint?.name ??
                                        'Punto de entrega Carman',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.warningContainer.withValues(
                              alpha: 0.55,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 16,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  'El vehículo quedará disponible para otros usuarios si no completas el pago.',
                                  style: AppTheme.bodySm.copyWith(
                                    fontSize: 10,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                              CountdownText(
                                endTime: failure.holdExpiresAt,
                                style: AppTheme.labelMd.copyWith(
                                  color: AppColors.warning,
                                  fontSize: 11,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  CarmanButton(
                    label: 'Reintentar con otro método de pago',
                    icon: Icons.sync_alt_rounded,
                    onPressed: () {
                      if (state.draft == null) {
                        ref
                            .read(bookingControllerProvider.notifier)
                            .start(vehicle);
                      }
                      ref
                          .read(bookingControllerProvider.notifier)
                          .clearFailure();
                      context.go('/checkout');
                    },
                  ),
                  const SizedBox(height: 8),
                  CarmanButton(
                    label: 'Elegir otro vehículo similar',
                    variant: CarmanButtonVariant.outline,
                    icon: Icons.directions_car_outlined,
                    onPressed: () => context.go('/home'),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _contactSupport(context),
                      icon: const Icon(Icons.support_agent_rounded, size: 18),
                      label: const Text('Contactar a soporte Carman'),
                    ),
                  ),
                  Center(
                    child: Text(
                      'Tiempo habitual de respuesta menor a 2 minutos',
                      style: AppTheme.bodySm.copyWith(fontSize: 9.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _contactSupport(BuildContext context) {
    showCarmanSnack(
      context,
      'Soporte Carman: +57 300 123 4567 · soporte@carman.app',
      kind: SnackKind.info,
    );
  }
}

class _SmallRow extends StatelessWidget {
  const _SmallRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppColors.tertiaryText),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.bodySm.copyWith(fontSize: 9.5),
          ),
        ),
      ],
    );
  }
}
