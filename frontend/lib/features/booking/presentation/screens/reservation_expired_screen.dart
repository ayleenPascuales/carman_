import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../data/mock/mock_data.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../data/models/vehicle_query.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_button.dart';
import '../../../../shared/widgets/carman_card.dart';
import '../../../../shared/widgets/carman_top_bar.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../explore/application/catalog_controller.dart';

class ReservationExpiredScreen extends ConsumerWidget {
  const ReservationExpiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(catalogControllerProvider).query;
    final vehicle = MockData.vehicles.first;
    final similar = ref.watch(catalogControllerProvider).vehicles.length;

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
                    icon: Icons.close_rounded,
                    onPressed: () => context.go('/home'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Inicio  /  Reserva expirada',
                    style: AppTheme.bodySm.copyWith(fontSize: 10.5),
                  ),
                  const Spacer(),
                  RoundIconButton(
                    icon: Icons.help_outline_rounded,
                    onPressed: () => showCarmanSnack(
                      context,
                      'Las reservas se mantienen durante 15 minutos mientras se completa el pago.',
                      kind: SnackKind.info,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 24),
                children: [
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.hourglass_disabled_rounded,
                        size: 40,
                        color: AppColors.tertiaryText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.graphite,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '00:00 · Tiempo de retención agotado',
                        style: AppTheme.labelSm.copyWith(
                          color: Colors.white,
                          fontSize: 9.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Tu reserva ha expirado',
                    textAlign: TextAlign.center,
                    style: AppTheme.headlineLg.copyWith(fontSize: 27),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'La retención de 15 minutos terminó. El ${vehicle.shortTitle} volvió al catálogo.',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyMd.copyWith(
                      color: AppColors.tertiaryText,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 22),
                  CarmanCard(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.bookmark_added_outlined,
                              size: 17,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'Parámetros de tu viaje',
                              style: AppTheme.labelLg.copyWith(fontSize: 12),
                            ),
                            const Spacer(),
                            Text(
                              'GUARDADOS',
                              style: AppTheme.labelSm.copyWith(
                                color: AppColors.success,
                                fontSize: 8.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 13),
                        _ParamRow(
                          icon: Icons.location_on_rounded,
                          label: 'Ubicación de recogida',
                          value: '${query.city} · Centro',
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 9),
                          child: Divider(),
                        ),
                        _ParamRow(
                          icon: Icons.calendar_month_rounded,
                          label: 'Fechas y duración',
                          value: query.startAt != null && query.endAt != null
                              ? '${AppFormatters.dateRange(query.startAt!, query.endAt!)} · ${query.hoursOrDays} ${query.mode == RentalMode.hourly ? 'h' : 'días'}'
                              : 'Fechas por confirmar',
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 9),
                          child: Divider(),
                        ),
                        _ParamRow(
                          icon: Icons.electric_car_rounded,
                          label: 'Categoría preferida',
                          value: query.category == VehicleCategory.all
                              ? 'Cualquier categoría'
                              : query.category.label,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  InfoBanner(
                    title: 'Disponibilidad alta',
                    message: 'Hay $similar coches similares en ${query.city}.',
                    icon: Icons.bolt_rounded,
                    color: AppColors.success,
                    compact: true,
                  ),
                  const SizedBox(height: 18),
                  CarmanButton(
                    label: 'Buscar coches con las mismas fechas',
                    icon: Icons.search_rounded,
                    trailingIcon: Icons.arrow_forward_rounded,
                    onPressed: () => context.go('/home/results'),
                  ),
                  const SizedBox(height: 8),
                  CarmanButton(
                    label: 'Ver si sigue libre',
                    variant: CarmanButtonVariant.outline,
                    icon: Icons.replay_rounded,
                    onPressed: () => context.push('/vehicle/${vehicle.id}'),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('Inicio'),
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
}

class _ParamRow extends StatelessWidget {
  const _ParamRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.tertiaryText),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTheme.bodySm.copyWith(fontSize: 9.5)),
              const SizedBox(height: 2),
              Text(value, style: AppTheme.labelMd.copyWith(fontSize: 11.5)),
            ],
          ),
        ),
      ],
    );
  }
}
