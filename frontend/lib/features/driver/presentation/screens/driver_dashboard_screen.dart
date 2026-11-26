import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../data/models/driver_models.dart';
import '../../../../data/models/user_profile.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_button.dart';
import '../../../../shared/widgets/carman_card.dart';
import '../../../../shared/widgets/carman_image.dart';
import '../../../../shared/widgets/carman_top_bar.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/driver_controller.dart';

class DriverDashboardScreen extends ConsumerStatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  ConsumerState<DriverDashboardScreen> createState() =>
      _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends ConsumerState<DriverDashboardScreen> {
  DriverTripStatus? _historyFilter;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final state = ref.watch(driverControllerProvider);

    if (user == null || !user.isDriver) {
      return Scaffold(
        appBar: CarmanTopBar(
          title: 'Conductor',
          onBack: () => Navigator.of(context).maybePop(),
        ),
        body: EmptyState(
          title: 'Activa el modo conductor',
          message: 'Añade el rol de conductor desde tu perfil.',
          icon: Icons.badge_outlined,
          actionLabel: 'Ir a mi perfil',
          onAction: () => context.go('/profile'),
        ),
      );
    }

    if (state.isLoading && state.data == null) {
      return const Scaffold(body: CenteredLoader());
    }

    final data = state.data;
    if (data == null) {
      return Scaffold(
        appBar: CarmanTopBar(title: 'Conductor'),
        body: ErrorView(
          message: state.error ?? 'No pudimos cargar tus servicios.',
          onRetry: () => ref.read(driverControllerProvider.notifier).load(),
        ),
      );
    }

    final current = state.currentTrip;
    final offers = state.offeredTrips;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: CarmanTopBar(
        title: 'Conductor',
        onBack: () => Navigator.of(context).maybePop(),
        actions: [
          if (!AppConfig.useLiveApi)
            IconButton(
              onPressed: () => showCarmanSnack(
                context,
                'Soporte para conductores: conductores@carman.app',
                kind: SnackKind.info,
              ),
              icon: const Icon(Icons.support_agent_rounded, size: 20),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(driverControllerProvider.notifier).load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            _AvailabilityCard(
              availability: data.availability,
              enabled:
                  !state.isChangingAvailability &&
                  !state.isLoading &&
                  state.actionTripId == null &&
                  (!AppConfig.useLiveApi ||
                      data.licenseValid ||
                      data.availability != DriverAvailability.offline),
              onChanged: (value) => ref
                  .read(driverControllerProvider.notifier)
                  .setAvailable(value),
            ),
            const SizedBox(height: 10),
            if (state.error != null) ...[
              InfoBanner(
                title: 'No se confirmó el cambio',
                message: state.error!,
                color: AppColors.error,
              ),
              const SizedBox(height: 10),
            ],
            if (!AppConfig.useLiveApi) _DriverStatsBar(stats: data.stats),
            if (AppConfig.useLiveApi &&
                data.trips.any(
                  (trip) => trip.status == DriverTripStatus.unknown,
                ))
              const InfoBanner(
                title: 'Hay servicios con estado no reconocido',
                message:
                    'Consulta el detalle de la reserva antes de actuar. '
                    'No se habilitarán acciones para esos servicios.',
                color: AppColors.warning,
              ),
            if (AppConfig.useLiveApi && !data.licenseValid)
              InfoBanner(
                title: 'Licencia no vigente',
                message:
                    'Actualiza la licencia desde tu perfil antes de activar '
                    'la disponibilidad o aceptar un servicio.',
                color: AppColors.warning,
                trailing: TextButton(
                  onPressed: () => context.push('/license'),
                  child: const Text('Licencia'),
                ),
              ),
            if (current != null) ...[
              const SizedBox(height: 22),
              SectionHeader(
                title: 'Servicio actual',
                actionLabel: 'Detalle',
                onAction: () => _showTripDetail(context, current),
              ),
              const SizedBox(height: 8),
              _CurrentServiceCard(
                trip: current,
                isProcessing: state.actionTripId == current.id,
                onStart: () async {
                  final result = await ref
                      .read(driverControllerProvider.notifier)
                      .start(current.id);
                  if (!context.mounted) return;
                  if (result) {
                    showCarmanSnack(
                      context,
                      'Servicio iniciado.',
                      kind: SnackKind.success,
                    );
                  }
                },
                onComplete: () async {
                  final result = await ref
                      .read(driverControllerProvider.notifier)
                      .complete(current.id);
                  if (!context.mounted) return;
                  if (result) {
                    showCarmanSnack(
                      context,
                      AppConfig.useLiveApi
                          ? 'Servicio finalizado.'
                          : 'Servicio completado · ${AppFormatters.money(current.earnings)} abonados.',
                      kind: SnackKind.success,
                    );
                  }
                },
              ),
            ],
            const SizedBox(height: 22),
            SectionHeader(
              title: 'Solicitudes',
              count: current == null ? offers.length : 0,
            ),
            const SizedBox(height: 8),
            if (current != null)
              _CurrentServiceNotice()
            else if (offers.isEmpty)
              _EmptyOffers()
            else
              for (final trip in offers) ...[
                _OfferCard(
                  trip: trip,
                  isProcessing: state.actionTripId != null || state.isLoading,
                  canAccept:
                      !AppConfig.useLiveApi ||
                      (data.licenseValid &&
                          data.availability == DriverAvailability.online),
                  onDetail: () => _showTripDetail(context, trip),
                  onAccept: () async {
                    final result = await ref
                        .read(driverControllerProvider.notifier)
                        .accept(trip.id);
                    if (!context.mounted) return;
                    if (result) {
                      showCarmanSnack(
                        context,
                        'Servicio aceptado.',
                        kind: SnackKind.success,
                      );
                    }
                  },
                  onDecline: () async {
                    final result = await ref
                        .read(driverControllerProvider.notifier)
                        .decline(trip.id);
                    if (!context.mounted) return;
                    if (result) {
                      showCarmanSnack(
                        context,
                        'Solicitud rechazada.',
                        kind: SnackKind.info,
                      );
                    }
                  },
                ),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 20),
            if (!AppConfig.useLiveApi)
              _EarningsCard(stats: data.stats, trips: state.recentCompleted),
            if (AppConfig.useLiveApi) ...[
              const SizedBox(height: 12),
              SectionHeader(
                title: 'Historial de servicios',
                count: data.trips
                    .where(
                      (trip) =>
                          trip.status == DriverTripStatus.completed ||
                          trip.status == DriverTripStatus.cancelled,
                    )
                    .length,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final filter in <DriverTripStatus?>[
                    null,
                    DriverTripStatus.completed,
                    DriverTripStatus.cancelled,
                  ])
                    ChoiceChip(
                      label: Text(filter?.label ?? 'Todos'),
                      selected: _historyFilter == filter,
                      onSelected: (_) =>
                          setState(() => _historyFilter = filter),
                    ),
                ],
              ),
              for (final trip in data.trips.where(
                (trip) =>
                    (trip.status == DriverTripStatus.completed ||
                        trip.status == DriverTripStatus.cancelled) &&
                    (_historyFilter == null || trip.status == _historyFilter),
              ))
                ListTile(
                  onTap: () => _showTripDetail(context, trip),
                  title: Text(trip.vehicle.shortTitle),
                  subtitle: Text(
                    '${AppFormatters.shortDate(trip.scheduledAt)} · Reserva #${trip.id}',
                  ),
                  trailing: StatusBadge(
                    label: trip.status.label,
                    color: trip.status.color,
                    small: true,
                  ),
                ),
              if (data.hasMore)
                TextButton(
                  onPressed: state.isLoadingMore
                      ? null
                      : () => ref
                            .read(driverControllerProvider.notifier)
                            .loadMore(),
                  child: Text(
                    state.isLoadingMore
                        ? 'Cargando historial…'
                        : 'Cargar más servicios',
                  ),
                ),
              if (!data.hasMore &&
                  data.trips.every(
                    (trip) =>
                        trip.status != DriverTripStatus.completed &&
                        trip.status != DriverTripStatus.cancelled,
                  ))
                const Text(
                  'Todavía no hay servicios finalizados o cancelados.',
                ),
            ],
            const SizedBox(height: 12),
            _DriverDocuments(
              licenseVerified: AppConfig.useLiveApi
                  ? data.licenseValid
                  : user.licenseStatus == LicenseStatus.approved,
            ),
          ],
        ),
      ),
    );
  }

  void _showTripDetail(BuildContext context, DriverTrip trip) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Detalle del servicio', style: AppTheme.headlineSm),
              const SizedBox(height: 12),
              _RouteRow(
                icon: Icons.trip_origin_rounded,
                color: AppColors.primary,
                text: trip.origin,
              ),
              const SizedBox(height: 10),
              _RouteRow(
                icon: Icons.place_rounded,
                color: AppColors.success,
                text: trip.destination,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 17,
                    color: AppColors.tertiaryText,
                  ),
                  const SizedBox(width: 7),
                  Text(trip.clientName, style: AppTheme.bodyMd),
                  const Spacer(),
                  Text(
                    trip.clientPhone,
                    style: AppTheme.bodySm.copyWith(fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (!AppConfig.useLiveApi)
                Text(
                  trip.notes.isEmpty ? 'Sin notas del cliente.' : trip.notes,
                  style: AppTheme.bodySm.copyWith(fontSize: 10, height: 1.45),
                ),
              const SizedBox(height: 18),
              if (AppConfig.useLiveApi)
                Text(
                  'Reserva #${trip.id} · ${AppFormatters.shortDate(trip.scheduledAt)}'
                  '${trip.endsAt == null ? '' : ' a ${AppFormatters.shortDate(trip.endsAt!)}'}',
                )
              else
                CarmanButton(
                  label: 'Llamar al cliente',
                  icon: Icons.call_outlined,
                  onPressed: () => showCarmanSnack(
                    context,
                    'Llamando a ${trip.clientName}…',
                    kind: SnackKind.info,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.availability,
    required this.onChanged,
    this.enabled = true,
  });

  final DriverAvailability availability;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return CarmanCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      showShadow: false,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: availability.color.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: Icon(availability.icon, size: 18, color: availability.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  availability.label,
                  style: AppTheme.labelMd.copyWith(fontSize: 12.5),
                ),
                const SizedBox(height: 1),
                Text(
                  availability == DriverAvailability.onTrip
                      ? 'Termina el servicio para recibir más solicitudes'
                      : availability == DriverAvailability.online
                      ? AppConfig.useLiveApi
                            ? 'Disponible para servicios según tus reservas'
                            : 'Recibiendo solicitudes en Cartagena'
                      : 'No recibirás solicitudes',
                  style: AppTheme.bodySm.copyWith(fontSize: 9.5),
                ),
              ],
            ),
          ),
          Switch(
            value: availability != DriverAvailability.offline,
            onChanged: !enabled || availability == DriverAvailability.onTrip
                ? null
                : onChanged,
          ),
        ],
      ),
    );
  }
}

class _DriverStatsBar extends StatelessWidget {
  const _DriverStatsBar({required this.stats});

  final DriverStats stats;

  @override
  Widget build(BuildContext context) {
    return CarmanCard(
      padding: const EdgeInsets.symmetric(vertical: 13),
      showShadow: false,
      child: Row(
        children: [
          _Stat(value: '${stats.tripsToday}', label: 'Viajes hoy'),
          const _StatDivider(),
          _Stat(value: AppFormatters.money(stats.earningsToday), label: 'Hoy'),
          const _StatDivider(),
          _Stat(
            value: AppConfig.useLiveApi && stats.rating == 0
                ? '—'
                : stats.rating.toStringAsFixed(1),
            label: 'Valoración',
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

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

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 20, color: AppColors.borderSoft);
  }
}

class _CurrentServiceCard extends StatelessWidget {
  const _CurrentServiceCard({
    required this.trip,
    required this.isProcessing,
    required this.onStart,
    required this.onComplete,
  });

  final DriverTrip trip;
  final bool isProcessing;
  final Future<void> Function() onStart;
  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context) {
    final inProgress = trip.status == DriverTripStatus.inProgress;
    return CarmanCard(
      padding: const EdgeInsets.all(14),
      showShadow: false,
      child: Column(
        children: [
          Row(
            children: [
              StatusBadge(
                label: trip.status.label,
                color: trip.status.color,
                icon: trip.status.icon,
                small: true,
              ),
              const Spacer(),
              Text(
                AppFormatters.time(trip.scheduledAt),
                style: AppTheme.labelMd.copyWith(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatarImage(
                asset: trip.clientAvatarAsset,
                initials: trip.clientName,
                radius: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.titleMd.copyWith(fontSize: 13),
                    ),
                    Text(
                      trip.clientPhone,
                      style: AppTheme.bodySm.copyWith(fontSize: 9.5),
                    ),
                  ],
                ),
              ),
              if (!AppConfig.useLiveApi)
                IconButton(
                  onPressed: () => showCarmanSnack(
                    context,
                    'Llamando a ${trip.clientName}…',
                    kind: SnackKind.info,
                  ),
                  icon: const Icon(Icons.call_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _RouteRow(
            icon: Icons.trip_origin_rounded,
            color: AppColors.primary,
            text: trip.origin,
          ),
          const SizedBox(height: 8),
          _RouteRow(
            icon: Icons.place_rounded,
            color: AppColors.success,
            text: trip.destination,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: CarmanImage(
                  trip.vehicle.primaryPhoto,
                  width: 44,
                  height: 34,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trip.vehicle.shortTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodySm.copyWith(fontSize: 10.5),
                ),
              ),
              if (!AppConfig.useLiveApi)
                Text(
                  AppFormatters.money(trip.earnings),
                  style: AppTheme.labelMd.copyWith(fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: CarmanButton(
              label: inProgress ? 'Finalizar servicio' : 'Iniciar servicio',
              trailingIcon: inProgress
                  ? Icons.check_rounded
                  : Icons.navigation_rounded,
              height: 44,
              isLoading: isProcessing,
              onPressed: inProgress ? onComplete : onStart,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTheme.bodySm.copyWith(
              fontSize: 10.5,
              color: AppColors.onSurface,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.trip,
    required this.isProcessing,
    required this.onAccept,
    required this.onDecline,
    required this.onDetail,
    this.canAccept = true,
  });

  final DriverTrip trip;
  final bool isProcessing;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;
  final VoidCallback onDetail;
  final bool canAccept;

  @override
  Widget build(BuildContext context) {
    return CarmanCard(
      padding: const EdgeInsets.all(13),
      showShadow: false,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.primaryViolet,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Nuevo servicio',
                style: AppTheme.labelSm.copyWith(
                  fontSize: 9,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Text(
                AppFormatters.time(trip.scheduledAt),
                style: AppTheme.labelMd.copyWith(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  trip.clientName,
                  style: AppTheme.titleMd.copyWith(fontSize: 13),
                ),
              ),
              if (!AppConfig.useLiveApi)
                Text(
                  AppFormatters.money(trip.earnings),
                  style: AppTheme.titleMd.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _RouteRow(
            icon: Icons.trip_origin_rounded,
            color: AppColors.primary,
            text: trip.origin,
          ),
          const SizedBox(height: 5),
          _RouteRow(
            icon: Icons.place_rounded,
            color: AppColors.success,
            text: trip.destination,
          ),
          const SizedBox(height: 10),
          if (AppConfig.useLiveApi)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onDetail,
                child: Text('Reserva #${trip.id} · Ver detalle'),
              ),
            ),
          Row(
            children: [
              if (!AppConfig.useLiveApi)
                Text(
                  '${trip.distanceKm.toStringAsFixed(1)} km · ${trip.durationMinutes} min',
                  style: AppTheme.bodySm.copyWith(fontSize: 9.5),
                ),
              const Spacer(),
              TextButton(
                onPressed: isProcessing ? null : onDecline,
                child: const Text('Rechazar'),
              ),
              const SizedBox(width: 2),
              SizedBox(
                height: 36,
                child: FilledButton(
                  onPressed: isProcessing || !canAccept ? null : onAccept,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    textStyle: AppTheme.labelMd.copyWith(fontSize: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  child: isProcessing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Aceptar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.stats, required this.trips});

  final DriverStats stats;
  final List<DriverTrip> trips;

  @override
  Widget build(BuildContext context) {
    return CarmanCard(
      padding: const EdgeInsets.all(14),
      showShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Ganancias de la semana',
                style: AppTheme.bodySm.copyWith(fontSize: 10.5),
              ),
              const Spacer(),
              Text(
                AppFormatters.money(stats.earningsWeek),
                style: AppTheme.headlineSm.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${stats.completedTotal} viajes completados',
                  style: AppTheme.bodySm.copyWith(fontSize: 9.5),
                ),
              ),
              Text(
                '${(stats.acceptanceRate * 100).round()}% aceptación',
                style: AppTheme.bodySm.copyWith(fontSize: 9.5),
              ),
            ],
          ),
          if (trips.isNotEmpty) ...[
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Último servicio',
                    style: AppTheme.bodySm.copyWith(fontSize: 9.5),
                  ),
                ),
                Text(
                  '${trips.first.clientName} · ${AppFormatters.money(trips.first.earnings)}',
                  style: AppTheme.bodySm.copyWith(fontSize: 9.5),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DriverDocuments extends StatelessWidget {
  const _DriverDocuments({required this.licenseVerified});

  final bool licenseVerified;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          licenseVerified ? Icons.verified_user_rounded : Icons.error_outline,
          size: 15,
          color: licenseVerified ? AppColors.success : AppColors.warning,
        ),
        const SizedBox(width: 6),
        Text(
          licenseVerified ? 'Licencia verificada' : 'Licencia pendiente',
          style: AppTheme.bodySm.copyWith(fontSize: 9.5),
        ),
        const Spacer(),
        if (!AppConfig.useLiveApi)
          Text('Soporte 24/7', style: AppTheme.bodySm.copyWith(fontSize: 9.5)),
      ],
    );
  }
}

class _CurrentServiceNotice extends StatelessWidget {
  const _CurrentServiceNotice();

  @override
  Widget build(BuildContext context) {
    return CarmanCard(
      showShadow: false,
      child: Row(
        children: [
          const Icon(
            Icons.timer_outlined,
            size: 17,
            color: AppColors.tertiaryText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Termina el servicio actual para recibir nuevas solicitudes.',
              style: AppTheme.bodySm.copyWith(fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOffers extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CarmanCard(
      showShadow: false,
      child: Row(
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 18,
            color: AppColors.tertiaryText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No hay solicitudes por ahora.',
              style: AppTheme.bodySm.copyWith(fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }
}
