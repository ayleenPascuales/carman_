import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../data/models/owner_models.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_card.dart';
import '../../../../shared/widgets/carman_image.dart';
import '../../../../shared/widgets/carman_top_bar.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../trips/application/trips_controller.dart';
import '../../application/owner_controller.dart';

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final state = ref.watch(ownerControllerProvider);
    final trips = ref.watch(tripsControllerProvider);
    final ownIds = state.listings.map((listing) => listing.vehicle.id).toSet();
    final ownUpcoming = (AppConfig.useLiveApi
            ? trips.upcoming.where((trip) => ownIds.contains(trip.vehicle.id))
            : trips.upcoming).toList();
    final pending = ownUpcoming.take(2).toList();

    if (user == null || !user.isOwner) {
      return Scaffold(
        appBar: CarmanTopBar(title: 'Propietario', onBack: () => context.pop()),
        body: EmptyState(
          title: 'Activa el modo propietario',
          message: 'Publica tus coches desde tu perfil.',
          icon: Icons.car_rental_rounded,
          actionLabel: 'Ir a mi perfil',
          onAction: () => context.go('/profile'),
        ),
      );
    }

    final vehiclesSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Tus coches',
          count: state.listings.length,
          actionLabel: 'Añadir',
          onAction: () => context.push('/owner/add-vehicle'),
        ),
        const SizedBox(height: 8),
        if (state.error != null && state.listings.isEmpty)
          EmptyState(
            title: 'No pudimos consultar tu inventario',
            message: state.error!,
            actionLabel: 'Reintentar',
            onAction: () => ref.read(ownerControllerProvider.notifier).load(),
          )
        else if (state.listings.isEmpty)
          EmptyState(
            title: 'Sin vehículos',
            message: 'Publica tu primer coche para empezar.',
            icon: Icons.directions_car_outlined,
            actionLabel: 'Añadir coche',
            onAction: () => context.push('/owner/add-vehicle'),
          )
        else
          CarmanCard(
            padding: EdgeInsets.zero,
            showShadow: false,
            child: Column(
              children: [
                for (var index = 0; index < state.listings.length; index++) ...[
                  _VehicleRow(
                    listing: state.listings[index],
                    onTap: () => context.push(AppConfig.useLiveApi
                        ? '/owner/vehicles/${state.listings[index].vehicle.id}'
                        : '/vehicle/${state.listings[index].vehicle.id}'),
                    onStatusChanged: (status) async {
                      final changed = await ref.read(ownerControllerProvider.notifier)
                          .changeStatus(state.listings[index].vehicle.id, status);
                      if (!context.mounted) return;
                      showCarmanSnack(context,
                          changed ? 'Estado confirmado: ${status.label}.'
                              : ref.read(ownerControllerProvider).error ??
                                  'No se pudo actualizar el estado.',
                          kind: changed ? SnackKind.success : SnackKind.error);
                    },
                  ),
                  if (index != state.listings.length - 1)
                    const Divider(height: 1, indent: 78, endIndent: 14),
                ],
              ],
            ),
          ),
      ],
    );

    final bookingsSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Reservas',
          count: AppConfig.useLiveApi ? (trips.isLoading ? null : ownUpcoming.length)
              : state.stats.pendingReservations,
          actionLabel: 'Ver todas',
          onAction: () => context.go('/trips'),
        ),
        const SizedBox(height: 8),
        if (AppConfig.useLiveApi && trips.isLoading)
          const CenteredLoader()
        else if (AppConfig.useLiveApi && trips.error != null)
          InfoBanner(title: 'No pudimos consultar reservas',
              message: trips.error!, color: AppColors.error)
        else if (pending.isEmpty)
          Text(
            'No hay reservas pendientes.',
            style: AppTheme.bodySm.copyWith(fontSize: 10.5),
          )
        else
          CarmanCard(
            padding: EdgeInsets.zero,
            showShadow: false,
            child: Column(
              children: [
                for (var index = 0; index < pending.length; index++) ...[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CarmanImage(
                        pending[index].vehicle.primaryPhoto,
                        width: 52,
                        height: 44,
                      ),
                    ),
                    title: Text(
                      pending[index].vehicle.title,
                      style: AppTheme.labelMd.copyWith(fontSize: 12),
                    ),
                    subtitle: Text(
                      pending[index].datesLabel,
                      style: AppTheme.bodySm.copyWith(fontSize: 9.5),
                    ),
                    trailing: Text(
                      AppFormatters.money(
                        pending[index].pricing.total,
                        precise: true,
                      ),
                      style: AppTheme.labelMd.copyWith(fontSize: 11),
                    ),
                    onTap: () => context.push('/trip/${pending[index].id}'),
                  ),
                  if (index != pending.length - 1)
                    const Divider(height: 1, indent: 72, endIndent: 14),
                ],
              ],
            ),
          ),
      ],
    );

    final note = Text(
      AppConfig.useLiveApi
          ? 'El panel muestra inventario propio; ingresos y liquidaciones '
            'requieren un contrato de datos adicional.'
          : 'Comisión Carman 15% · Liquidación semanal',
      style: AppTheme.bodySm.copyWith(fontSize: 9),
    );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: CarmanTopBar(
        title: 'Propietario',
        onBack: () => context.pop(),
        actions: [
          IconButton(
            onPressed: () => context.push('/owner/add-vehicle'),
            icon: const Icon(Icons.add_rounded, size: 21),
          ),
        ],
      ),
      body: state.isLoading && state.listings.isEmpty
          ? const CenteredLoader()
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 980;
                final side = constraints.maxWidth > 1240
                    ? (constraints.maxWidth - 1200) / 2
                    : 18.0;
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    ref.invalidate(tripsControllerProvider);
                    await ref.read(ownerControllerProvider.notifier).load();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(side, 4, side, 28),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _Overview(stats: state.stats),
                                    if (state.error != null && state.listings.isNotEmpty)
                                      InfoBanner(title: 'Inventario no actualizado',
                                          message: state.error!, color: AppColors.error),
                                    const SizedBox(height: 22),
                                    vehiclesSection,
                                    const SizedBox(height: 18),
                                    Center(child: note),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    bookingsSection,
                                    const SizedBox(height: 18),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Overview(stats: state.stats),
                              if (state.error != null && state.listings.isNotEmpty)
                                InfoBanner(title: 'Inventario no actualizado',
                                    message: state.error!, color: AppColors.error),
                              const SizedBox(height: 22),
                              vehiclesSection,
                              const SizedBox(height: 22),
                              bookingsSection,
                              const SizedBox(height: 18),
                              Center(child: note),
                            ],
                          ),
                  ),
                );
              },
            ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.stats});

  final OwnerStats stats;

  @override
  Widget build(BuildContext context) {
    if (AppConfig.useLiveApi) {
      return CarmanCard(child: Row(children: [
        Expanded(child: Text('Vehículos propios: ${stats.vehicles}',
            style: AppTheme.titleMd)),
        Text('Activos: ${stats.activeVehicles}', style: AppTheme.labelMd),
      ]));
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Ingresos del mes',
                style: AppTheme.bodySm.copyWith(fontSize: 10.5),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${stats.growth.toStringAsFixed(1)}%',
                  style: AppTheme.labelSm.copyWith(
                    fontSize: 8.5,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            AppFormatters.money(stats.monthlyRevenue),
            style: AppTheme.headlineLg.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _Metric(value: '${stats.vehicles}', label: 'Coches'),
              _MetricDivider(),
              _Metric(value: '${stats.activeVehicles}', label: 'Activos'),
              _MetricDivider(),
              _Metric(
                value: '${(stats.occupancyRate * 100).round()}%',
                label: 'Ocupación',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTheme.titleMd.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(label, style: AppTheme.bodySm.copyWith(fontSize: 9)),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 20, color: AppColors.borderSoft);
  }
}

class _VehicleRow extends StatelessWidget {
  const _VehicleRow({
    required this.listing,
    required this.onTap,
    required this.onStatusChanged,
  });

  final OwnerListing listing;
  final VoidCallback onTap;
  final ValueChanged<OwnerVehicleStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CarmanImage(listing.vehicle.primaryPhoto, width: 54, height: 48),
      ),
      title: Text(
        listing.vehicle.shortTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTheme.titleMd.copyWith(fontSize: 12.5),
      ),
      subtitle: Text(
        '${listing.vehicle.plate} · ${AppFormatters.money(listing.vehicle.pricePerDay)}/día',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTheme.bodySm.copyWith(fontSize: 9.5),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusBadge(
            label: listing.meta.status.label,
            color: listing.meta.status.color,
            small: true,
          ),
          if (!AppConfig.useLiveApi ||
              listing.meta.status == OwnerVehicleStatus.available ||
              listing.meta.status == OwnerVehicleStatus.inactive)
            PopupMenuButton<OwnerVehicleStatus>(
            icon: const Icon(
              Icons.more_vert_rounded,
              size: 18,
              color: AppColors.tertiaryText,
            ),
            onSelected: onStatusChanged,
            itemBuilder: (context) => AppConfig.useLiveApi
                ? [
                    if (listing.meta.status == OwnerVehicleStatus.available)
                      const PopupMenuItem(value: OwnerVehicleStatus.inactive,
                          child: Text('Pausar')),
                    if (listing.meta.status == OwnerVehicleStatus.inactive)
                      const PopupMenuItem(value: OwnerVehicleStatus.available,
                          child: Text('Reactivar')),
                  ] : const [
              PopupMenuItem(
                value: OwnerVehicleStatus.available,
                child: Text('Disponible'),
              ),
              PopupMenuItem(
                value: OwnerVehicleStatus.maintenance,
                child: Text('Mantenimiento'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
