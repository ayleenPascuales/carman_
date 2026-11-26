import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../data/models/booking.dart';
import '../../../../data/repositories/api_booking_repository.dart';
import '../../../../providers.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_button.dart';
import '../../../../shared/widgets/carman_card.dart';
import '../../../../shared/widgets/carman_image.dart';
import '../../../../shared/widgets/carman_top_bar.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/sheets.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../application/trips_controller.dart';
import '../widgets/trip_route_panel.dart';

class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.reservationId});

  final String reservationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tripsControllerProvider);
    final reservation = state.byId(reservationId);

    if (state.isLoading && reservation == null) {
      return const Scaffold(body: CenteredLoader(label: 'Cargando tu viaje…'));
    }
    if (reservation == null) {
      return Scaffold(
        appBar: CarmanTopBar(
          title: 'Detalle del viaje',
          onBack: () => context.pop(),
        ),
        body: EmptyState(
          title: 'No encontramos este viaje',
          message: 'Puede que la reserva se haya eliminado o actualizado.',
          actionLabel: 'Ver mis viajes',
          onAction: () => context.go('/trips'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: CarmanTopBar(
        title: 'Detalle del viaje',
        overline: reservation.code,
        onBack: () => context.pop(),
        actions: [
          IconButton(
            onPressed: () => showCarmanSnack(
              context,
              'Soporte Carman: soporte@carman.app · +57 300 123 4567',
              kind: SnackKind.info,
            ),
            icon: const Icon(Icons.support_agent_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          CarmanCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      CarmanImage(
                        reservation.vehicle.primaryPhoto,
                        height: 165,
                        width: double.infinity,
                      ),
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppColors.heroScrim,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: StatusBadge(
                          label: reservation.status.label,
                          color: reservation.status.color,
                          icon: reservation.status.icon,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reservation.vehicle.fullTitle,
                              style: AppTheme.headlineSm.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Anfitrión ${reservation.vehicle.ownerName} · ${reservation.vehicle.locationName}',
                              style: AppTheme.bodySm.copyWith(fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                      RatingBadge(rating: reservation.vehicle.rating),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!AppConfig.useLiveApi &&
              (reservation.status == ReservationStatus.active ||
              reservation.status == ReservationStatus.confirmed)) ...[
            const SizedBox(height: 12),
            _DigitalKeyCard(reservation: reservation),
          ],
          const SizedBox(height: 16),
          const SectionHeader(title: 'Detalles de la reserva'),
          const SizedBox(height: 8),
          CarmanCard(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.calendar_month_rounded,
                  label: 'Fechas',
                  value: reservation.datesLabel,
                ),
                const Divider(height: 18),
                _DetailRow(
                  icon: Icons.location_on_rounded,
                   label: 'Punto de recogida',
                  value:
                      '${reservation.pickupPoint.name}\n${reservation.pickupPoint.address}',
                ),
                if (!AppConfig.useLiveApi) const Divider(height: 18),
                if (!AppConfig.useLiveApi) _DetailRow(
                  icon: Icons.shield_rounded,
                  label: 'Cobertura',
                  value: reservation.insuranceName,
                ),
                if (!AppConfig.useLiveApi) const Divider(height: 18),
                if (!AppConfig.useLiveApi) _DetailRow(
                  icon: Icons.credit_card_rounded,
                  label: 'Método de pago',
                  value: reservation.paymentMethodLabel,
                ),
              ],
            ),
          ),
          if (AppConfig.useLiveApi) ...[
            const SizedBox(height: 12),
            TripRoutePanel(reservation: reservation),
          ],
          const SizedBox(height: 12),
          CarmanCard(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                if (!AppConfig.useLiveApi) KeyValueRow(
                  label: reservation.pricing.rentalLabel,
                  value: AppFormatters.money(
                    reservation.pricing.rentalSubtotal,
                    precise: true,
                  ),
                ),
                if (!AppConfig.useLiveApi) KeyValueRow(
                  label: 'Seguro y servicio',
                  value: AppFormatters.money(
                    reservation.pricing.insuranceSubtotal +
                        reservation.pricing.serviceFee,
                    precise: true,
                  ),
                ),
                if (!AppConfig.useLiveApi) KeyValueRow(
                  label: 'Impuestos',
                  value: AppFormatters.money(
                    reservation.pricing.taxes,
                    precise: true,
                  ),
                ),
                const Divider(height: 16),
                KeyValueRow(
                   label: AppConfig.useLiveApi ? 'Precio estimado' : 'Total',
                  value: AppFormatters.money(
                    reservation.pricing.total,
                    precise: true,
                  ),
                  emphasize: true,
                  valueColor: AppColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (AppConfig.useLiveApi && reservation.canReview &&
              (reservation.status == ReservationStatus.confirmed ||
               reservation.status == ReservationStatus.active)) ...[
            CarmanButton(
              label: 'Ver orden y pagos',
              icon: Icons.receipt_long_outlined,
              onPressed: () => context.push('/trip/${reservation.id}/payment'),
            ),
            const SizedBox(height: 8),
          ],
          if (AppConfig.useLiveApi && reservation.canReview &&
              reservation.awaitingDriverDecision) ...[
            CarmanButton(
              label: 'Continuar sin conductor',
              onPressed: () => _act(context, ref,
                  () => (ref.read(bookingRepositoryProvider) as ApiBookingRepository)
                      .decideWithoutDriver(reservation.id, 'Continuar')),
            ),
            const SizedBox(height: 8),
            CarmanButton(
              label: 'Esperar conductor',
              variant: CarmanButtonVariant.outline,
              onPressed: () => _act(context, ref,
                  () => (ref.read(bookingRepositoryProvider) as ApiBookingRepository)
                      .decideWithoutDriver(reservation.id, 'Esperar')),
            ),
            const SizedBox(height: 8),
          ],
          if (AppConfig.useLiveApi && reservation.canOperate &&
              (reservation.status == ReservationStatus.confirmed ||
               reservation.status == ReservationStatus.active)) ...[
            CarmanButton(
              label: reservation.status == ReservationStatus.confirmed
                  ? 'Iniciar servicio' : 'Finalizar servicio',
              onPressed: () => _act(context, ref,
                  () => (ref.read(bookingRepositoryProvider) as ApiBookingRepository)
                      .transition(reservation.id,
                          finish: reservation.status == ReservationStatus.active)),
            ),
            const SizedBox(height: 8),
          ],
          if (reservation.status == ReservationStatus.confirmed ||
              (AppConfig.useLiveApi &&
                  reservation.status == ReservationStatus.pendingPayment)) ...[
            if (AppConfig.useLiveApi || reservation.isCancellable)
              CarmanButton(
                label: 'Cancelar reserva',
                variant: CarmanButtonVariant.danger,
                icon: Icons.cancel_outlined,
                onPressed: () => _cancel(context, ref, reservation),
              ),
            const SizedBox(height: 8),
            Text(
              reservation.isCancellable
                  ? (AppConfig.useLiveApi
                      ? 'Sin pagos iniciados, consulta el estado antes de cancelar.'
                      : 'Cancelación gratuita hasta 24 h antes del inicio.')
                  : (AppConfig.useLiveApi
                      ? 'Consulta las condiciones de cancelación de tu reserva.'
                      : 'La reserva ya está dentro del período de cancelación con cargo.'),
              textAlign: TextAlign.center,
              style: AppTheme.bodySm.copyWith(fontSize: 9.5),
            ),
          ] else if (reservation.status == ReservationStatus.completed) ...[
              if (!AppConfig.useLiveApi || reservation.canReview) CarmanButton(
              label: reservation.hasReview
                  ? 'Reseña enviada'
                  : 'Dejar una reseña',
              icon: Icons.star_outline_rounded,
              onPressed: reservation.hasReview
                  ? null
                  : () => _review(context, ref, reservation),
            ),
              if (!AppConfig.useLiveApi || reservation.canReview)
                const SizedBox(height: 8),
             if (!AppConfig.useLiveApi) CarmanButton(
              label: 'Descargar factura',
              variant: CarmanButtonVariant.outline,
              icon: Icons.download_rounded,
              onPressed: () => showCarmanSnack(
                context,
                'Factura enviada a tu correo electrónico.',
                kind: SnackKind.success,
              ),
            ),
          ] else if (reservation.status == ReservationStatus.cancelled) ...[
            const InfoBanner(
              title: 'Reserva cancelada',
              message: 'No se realizó ningún cargo adicional. Puedes volver a reservar cuando quieras.',
              icon: Icons.info_outline_rounded,
              compact: true,
            ),
          ],
          const SizedBox(height: 16),
          if (!AppConfig.useLiveApi) Center(
            child: TextButton(
              onPressed: () => showCarmanSnack(
                context,
                'Abriendo conversación con el anfitrión…',
                kind: SnackKind.info,
              ),
              child: const Text('Contactar'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _act(BuildContext context, WidgetRef ref,
      Future<Reservation> Function() action) async {
    try {
      await action();
      if (!context.mounted) return;
      await ref.read(tripsControllerProvider.notifier).refresh();
      if (context.mounted) {
        showCarmanSnack(context, 'Estado consultado en el servidor.',
            kind: SnackKind.success);
      }
    } catch (_) {
      if (context.mounted) {
        await ref.read(tripsControllerProvider.notifier).refresh();
        if (context.mounted) {
          showCarmanSnack(context,
              'No se pudo confirmar el resultado. Consulta el estado antes de reintentar.',
              kind: SnackKind.error);
        }
      }
    }
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    Reservation reservation,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '¿Cancelar tu reserva?',
      message: AppConfig.useLiveApi
          ? 'La reserva se cancelará si no tiene pagos en proceso o aprobados.'
          : 'Se reembolsará el importe completo a tu método de pago en un plazo de 3 a 5 días hábiles.',
      confirmLabel: 'Sí, cancelar',
      destructive: true,
      icon: Icons.cancel_outlined,
    );
    if (!confirmed || !context.mounted) return;
    final success = await ref
        .read(tripsControllerProvider.notifier)
        .cancel(reservation.id);
    if (!context.mounted) return;
    showCarmanSnack(
      context,
      success
          ? (AppConfig.useLiveApi
              ? 'Reserva cancelada.' : 'Reserva cancelada. El reembolso se procesará automáticamente.')
           : ref.read(tripsControllerProvider).error ??
               'No pudimos cancelar la reserva.',
      kind: success ? SnackKind.success : SnackKind.error,
    );
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    Reservation reservation,
  ) async {
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => _ReviewDialog(reservation: reservation),
    );
    if (submitted == true && context.mounted) {
      showCarmanSnack(
        context,
        '¡Gracias! Tu reseña ayuda a mantener la calidad de Carman.',
        kind: SnackKind.success,
      );
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
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
        Icon(icon, size: 17, color: AppColors.tertiaryText),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTheme.bodySm.copyWith(fontSize: 9.5)),
              const SizedBox(height: 2),
              Text(value, style: AppTheme.labelMd.copyWith(fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DigitalKeyCard extends StatelessWidget {
  const _DigitalKeyCard({required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final active = reservation.status == ReservationStatus.active;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x408B5CF6),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              active ? Icons.nfc_rounded : Icons.lock_clock_rounded,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? 'Llave digital activa' : 'Llave digital programada',
                  style: AppTheme.titleMd.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  active
                      ? 'Acerca el móvil al vehículo para abrirlo.'
                      : 'Disponible 15 minutos antes de la entrega.',
                  style: AppTheme.bodySm.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: active
                ? () => _openKey(context)
                : () => showCarmanSnack(
                    context,
                    'La llave se activará antes de tu entrega.',
                    kind: SnackKind.info,
                  ),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(active ? 'Abrir' : 'Info'),
          ),
        ],
      ),
    );
  }

  void _openKey(BuildContext context) {
    showCarmanSheet<void>(
      context: context,
      maxHeightFactor: 0.62,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeader(
            title: 'Llave digital activa',
            subtitle: 'Acerca el dispositivo al vehículo o pulsa abrir.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Column(
                children: [
                  const Icon(Icons.nfc_rounded, color: Colors.white, size: 42),
                  const SizedBox(height: 12),
                  Text(
                    reservation.digitalKeyCode,
                    style: AppTheme.headlineMd.copyWith(
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pulsa para desbloquear · ${reservation.vehicle.title}',
                    style: AppTheme.bodySm.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SafeArea(top: false, child: SizedBox(height: 6)),
        ],
      ),
    );
  }
}

class _ReviewDialog extends ConsumerStatefulWidget {
  const _ReviewDialog({required this.reservation});

  final Reservation reservation;

  @override
  ConsumerState<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends ConsumerState<_ReviewDialog> {
  final _comment = TextEditingController();
  int _rating = 5;
  bool _submitting = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final success = await ref
        .read(tripsControllerProvider.notifier)
        .review(
          id: widget.reservation.id,
          rating: _rating,
          comment: _comment.text.trim(),
        );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() => _submitting = false);
      final error = ref.read(tripsControllerProvider).error;
      if (error != null) {
        showCarmanSnack(context, error, kind: SnackKind.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('¿Cómo fue tu viaje?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.reservation.vehicle.fullTitle,
              style: AppTheme.bodySm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  onPressed: () => setState(() => _rating = index + 1),
                  icon: Icon(
                    index < _rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: AppColors.amber,
                    size: 30,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  constraints: const BoxConstraints(),
                );
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comment,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Cuéntanos qué tal fue la experiencia…',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Ahora no'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Enviar reseña'),
        ),
      ],
    );
  }
}
