import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../data/models/booking.dart';
import '../../../../shared/widgets/carman_chips.dart';
import '../../../../shared/widgets/carman_image.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../application/trips_controller.dart';

class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripsControllerProvider);
    final reservations = trips.currentTab;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.maxWidth > 1000
              ? (constraints.maxWidth - 960) / 2
              : 18.0;
          return SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => ref.read(tripsControllerProvider.notifier).refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(side, 8, side, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Viajes',
                      style: AppTheme.headlineMd.copyWith(fontSize: 22),
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.push('/notifications'),
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      size: 20,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SegmentedControl<TripsTab>(
                values: TripsTab.values,
                selected: trips.tab,
                labelBuilder: (tab) => switch (tab) {
                  TripsTab.upcoming => 'Próximos',
                  TripsTab.history => 'Historial',
                  TripsTab.cancelled => 'Canceladas',
                },
                onChanged: (tab) =>
                    ref.read(tripsControllerProvider.notifier).setTab(tab),
              ),
              const SizedBox(height: 18),
              if (trips.isLoading)
                const LoadingList(count: 2, height: 120)
              else if (trips.error != null)
                ErrorView(
                  message: trips.error!,
                  onRetry: () =>
                      ref.read(tripsControllerProvider.notifier).refresh(),
                )
              else if (reservations.isEmpty)
                EmptyState(
                  title: switch (trips.tab) {
                    TripsTab.upcoming => 'Sin viajes próximos',
                    TripsTab.history => 'Sin viajes completados',
                    TripsTab.cancelled => 'Sin cancelaciones',
                  },
                  message: 'Tus reservas aparecerán aquí.',
                  icon: Icons.card_travel_rounded,
                  actionLabel: 'Explorar',
                  onAction: () => context.go('/home'),
                )
              else
                LayoutBuilder(
                  builder: (context, inner) {
                    final columns = inner.maxWidth > 700 ? 2 : 1;
                    final cardWidth =
                        (inner.maxWidth - (columns - 1) * 12) / columns;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final reservation in reservations)
                          SizedBox(
                            width: cardWidth,
                            child: _TripCard(
                              reservation: reservation,
                              onTap: () =>
                                  context.push('/trip/${reservation.id}'),
                            ),
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      );
        },
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.reservation, required this.onTap});

  final Reservation reservation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = reservation.status == ReservationStatus.active;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CarmanImage(
                  reservation.vehicle.primaryPhoto,
                  width: 90,
                  height: 76,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            reservation.vehicle.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.titleMd.copyWith(fontSize: 13),
                          ),
                        ),
                        if (active)
                          const Icon(
                            Icons.key_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      reservation.datesLabel,
                      style: AppTheme.bodySm.copyWith(fontSize: 10.5),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: reservation.status.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          reservation.status.label,
                          style: AppTheme.labelSm.copyWith(
                            fontSize: 8.5,
                            color: reservation.status.color,
                            letterSpacing: 0,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          AppFormatters.money(
                            reservation.pricing.total,
                            precise: true,
                          ),
                          style: AppTheme.labelMd.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.tertiaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
