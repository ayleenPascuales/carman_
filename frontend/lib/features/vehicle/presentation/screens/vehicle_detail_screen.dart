import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../data/models/user_profile.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../data/models/vehicle_query.dart';
import '../../../../providers.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_button.dart';
import '../../../../shared/widgets/carman_card.dart';
import '../../../../shared/widgets/carman_image.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/map_preview.dart';
import '../../../../shared/widgets/sheets.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../booking/application/booking_controller.dart';
import '../../../explore/application/catalog_controller.dart';
import '../../../favorites/application/favorites_controller.dart';

class VehicleDetailScreen extends ConsumerStatefulWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<VehicleDetailScreen> createState() =>
      _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends ConsumerState<VehicleDetailScreen> {
  final _pageController = PageController();
  int _photoIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _book(Vehicle vehicle) {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    if (user.licenseStatus != LicenseStatus.approved) {
      final isPending = user.licenseStatus == LicenseStatus.pendingReview;
      showConfirmDialog(
        context,
        title: isPending ? 'Licencia en revisión' : 'Verifica tu licencia',
        message: isPending
            ? 'Nuestro equipo está validando tu permiso de conducir. Te avisaremos en cuanto esté aprobado para que puedas reservar.'
            : 'Para reservar necesitamos comprobar tu permiso de conducir. Solo tarda un par de minutos.',
        confirmLabel: isPending ? 'Ver estado' : 'Verificar ahora',
        icon: Icons.verified_user_rounded,
      ).then((value) {
        if (value && mounted) context.push('/license');
      });
      return;
    }
    ref.read(bookingControllerProvider.notifier).start(vehicle);
    context.push('/checkout');
  }

  void _share(Vehicle vehicle) {
    Clipboard.setData(
      ClipboardData(
        text:
            'Mira este ${vehicle.title} en Carman por ${AppFormatters.money(vehicle.pricePerDay)}/día.',
      ),
    );
    showCarmanSnack(
      context,
      'Enlace del vehículo copiado al portapapeles.',
      kind: SnackKind.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicleAsync = ref.watch(vehicleByIdProvider(widget.vehicleId));
    final catalog = ref.watch(catalogControllerProvider);
    final favorite = ref
        .watch(favoritesControllerProvider)
        .contains(widget.vehicleId);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: vehicleAsync.when(
        loading: () => const _LoadingDetail(),
        error: (error, stackTrace) => SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              Expanded(
                child: ErrorView(
                  message: 'No pudimos cargar este vehículo.',
                  onRetry: () =>
                      ref.invalidate(vehicleByIdProvider(widget.vehicleId)),
                ),
              ),
            ],
          ),
        ),
        data: (vehicle) {
          if (vehicle == null) {
            return SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  const Expanded(
                    child: EmptyState(
                      title: 'Vehículo no disponible',
                      message: 'Puede que el anfitrión lo haya retirado o que las fechas ya no estén libres.',
                      icon: Icons.no_crash_rounded,
                    ),
                  ),
                ],
              ),
            );
          }
          final query = catalog.query;
          final units = query.startAt != null && query.endAt != null
              ? query.hoursOrDays
              : (query.mode == RentalMode.hourly ? 4 : 3);
          final unitRate = query.mode == RentalMode.hourly
              ? vehicle.pricePerHour
              : vehicle.pricePerDay;
          final total = unitRate * units;
          final unitLabel = query.mode == RentalMode.hourly ? 'h' : 'día';

          return Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                      child: Row(
                        children: [
                          _RoundButton(
                            icon: Icons.arrow_back_rounded,
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/home');
                              }
                            },
                          ),
                          const Spacer(),
                          _RoundButton(
                            icon: Icons.ios_share_rounded,
                            onPressed: () => _share(vehicle),
                          ),
                          const SizedBox(width: 8),
                          _RoundButton(
                            icon: favorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: favorite
                                ? AppColors.error
                                : AppColors.onSurface,
                            onPressed: () => ref
                                .read(favoritesControllerProvider.notifier)
                                .toggle(vehicle.id),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 130),
                        children: [
                          _HeroGallery(
                            vehicle: vehicle,
                            pageController: _pageController,
                            index: _photoIndex,
                            onChanged: (index) =>
                                setState(() => _photoIndex = index),
                            onOpen: () =>
                                context.push('/gallery/${vehicle.id}'),
                          ),
                          const SizedBox(height: 14),
                          _TitleCard(vehicle: vehicle),
                          const SizedBox(height: 12),
                          _HostCard(vehicle: vehicle),
                          const SizedBox(height: 22),
                          _SpecsGrid(vehicle: vehicle),
                          const SizedBox(height: 14),
                          _FeaturesCard(features: vehicle.features),
                          const SizedBox(height: 18),
                          _PickupCard(
                            vehicle: vehicle,
                            onTap: () => _showMap(vehicle),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _BookingBar(
                  vehicle: vehicle,
                  unitRate: unitRate,
                  total: total,
                  units: units,
                  unitLabel: unitLabel,
                  onBook: () => _book(vehicle),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMap(Vehicle vehicle) {
    showCarmanSheet<void>(
      context: context,
      maxHeightFactor: 0.82,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(
            title: vehicle.pickupPoint?.name ?? 'Punto de entrega',
            subtitle: vehicle.pickupPoint?.address ?? vehicle.locationName,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: MapPreview(
              height: 250,
              label: vehicle.pickupPoint?.address ?? vehicle.locationName,
              markers: const [MapMarker(x: 0.4, y: 0.5, selected: true)],
              interactive: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.directions_walk_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'A ${vehicle.pickupPoint?.distanceLabel ?? '350 m'} del punto de referencia. Parking privado gratis.',
                    style: AppTheme.bodySm.copyWith(fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
          const SafeArea(top: false, child: SizedBox(height: 12)),
        ],
      ),
    );
  }
}

class _LoadingDetail extends StatelessWidget {
  const _LoadingDetail();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(child: Center(child: CircularProgressIndicator()));
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onPressed,
    this.color = AppColors.onSurface,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: Icon(icon, size: 19, color: color),
        ),
      ),
    );
  }
}

class _HeroGallery extends StatelessWidget {
  const _HeroGallery({
    required this.vehicle,
    required this.pageController,
    required this.index,
    required this.onChanged,
    required this.onOpen,
  });

  final Vehicle vehicle;
  final PageController pageController;
  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        height: MediaQuery.sizeOf(context).width > 700 ? 330 : 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppShadows.card,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: pageController,
                onPageChanged: onChanged,
                itemCount: vehicle.photos.length,
                itemBuilder: (context, photoIndex) {
                  final image = CarmanImage(vehicle.photos[photoIndex]);
                  return photoIndex == 0
                      ? Hero(tag: 'vehicle-${vehicle.id}', child: image)
                      : image;
                },
              ),
              const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.heroScrim),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.graphite.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        vehicle.fuel.icon,
                        size: 13,
                        color: AppColors.primaryFixedDim,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${vehicle.fuel.label.toUpperCase()} • ${vehicle.ecoLabel.toUpperCase()}',
                        style: AppTheme.labelSm.copyWith(
                          color: Colors.white,
                          fontSize: 8.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.photo_camera_outlined,
                        size: 13,
                        color: AppColors.onSurface,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${index + 1}/${vehicle.photos.length} Fotos',
                        style: AppTheme.labelSm.copyWith(
                          color: AppColors.onSurface,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleCard extends StatelessWidget {
  const _TitleCard({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vehicle.brand.toUpperCase(),
                style: AppTheme.labelSm.copyWith(
                  color: AppColors.primary,
                  fontSize: 9,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${vehicle.model} ${vehicle.year}',
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 23,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${vehicle.categoryLabel} · ${vehicle.traction}',
                style: AppTheme.bodySm.copyWith(fontSize: 10.5),
              ),
            ],
          ),
        ),
        RatingBadge(rating: vehicle.rating, count: vehicle.tripCount),
      ],
    );
  }
}

class _HostCard extends StatelessWidget {
  const _HostCard({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatarImage(
          asset: vehicle.ownerAvatarAsset,
          initials: vehicle.ownerName,
          radius: 18,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vehicle.ownerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.titleMd.copyWith(fontSize: 12.5),
              ),
              const SizedBox(height: 1),
              Text(
                vehicle.ownerBadgeLabel,
                style: AppTheme.bodySm.copyWith(fontSize: 9.5),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => showCarmanSnack(
            context,
            'Mensaje enviado a ${vehicle.ownerFirstName}.',
            kind: SnackKind.success,
          ),
          child: const Text('Mensaje'),
        ),
      ],
    );
  }
}

class _SpecsGrid extends StatelessWidget {
  const _SpecsGrid({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final specs = [
      (
        'Autonomía',
        vehicle.autonomyKm > 0 ? '${vehicle.autonomyKm} km' : 'N/D',
        vehicle.fuel == FuelType.electric ? 'WLTP estimado' : 'Autonomía mixta',
        Icons.bolt_rounded,
        AppColors.softLavender,
      ),
      (
        'Aceleración',
        vehicle.acceleration != null
            ? '${vehicle.acceleration!.toStringAsFixed(1)} seg'
            : 'N/D',
        '0 a 100 km/h',
        Icons.speed_rounded,
        const Color(0xFFF3E8FF),
      ),
      (
        'Capacidad',
        '${vehicle.seats} plazas',
        vehicle.luggageLiters != null
            ? '${vehicle.luggageLiters} L maletero'
            : '${vehicle.doors} puertas',
        Icons.airline_seat_recline_normal_rounded,
        const Color(0xFFEDE9FE),
      ),
      (
        'Tracción',
        vehicle.traction.split(' ').first,
        vehicle.traction,
        Icons.all_inclusive_rounded,
        AppColors.surfaceContainer,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: specs.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 9,
        crossAxisSpacing: 9,
        mainAxisExtent: 108,
      ),
      itemBuilder: (context, index) {
        final spec = specs[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      spec.$1,
                      style: AppTheme.bodySm.copyWith(fontSize: 10.5),
                    ),
                  ),
                  Container(
                    width: 27,
                    height: 27,
                    decoration: BoxDecoration(
                      color: spec.$5,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(spec.$4, size: 15, color: AppColors.primary),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                spec.$2,
                style: AppTheme.headlineSm.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                spec.$3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodySm.copyWith(fontSize: 9.5),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FeaturesCard extends StatelessWidget {
  const _FeaturesCard({required this.features});

  final List<VehicleFeature> features;

  @override
  Widget build(BuildContext context) {
    return CarmanCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          for (var index = 0; index < features.length; index++) ...[
            if (index > 0) const Divider(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    features[index].icon,
                    size: 17,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        features[index].title,
                        style: AppTheme.labelLg.copyWith(fontSize: 12.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        features[index].description,
                        style: AppTheme.bodySm.copyWith(
                          fontSize: 11,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PickupCard extends StatelessWidget {
  const _PickupCard({required this.vehicle, required this.onTap});

  final Vehicle vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final point = vehicle.pickupPoint;
    return CarmanCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: MapPreview(
                height: 120,
                showLabel: false,
                markers: const [MapMarker(x: 0.42, y: 0.4, selected: true)],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 19,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          point?.name ?? vehicle.locationName,
                          style: AppTheme.labelLg.copyWith(fontSize: 12.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${point?.address ?? vehicle.locationName} · Parking privado',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodySm.copyWith(fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      point?.isFree == true ? 'Gratis' : 'Incluido',
                      style: AppTheme.labelSm.copyWith(
                        color: AppColors.onSurface,
                        fontSize: 9,
                      ),
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

class _BookingBar extends StatelessWidget {
  const _BookingBar({
    required this.vehicle,
    required this.unitRate,
    required this.total,
    required this.units,
    required this.unitLabel,
    required this.onBook,
  });

  final Vehicle vehicle;
  final double unitRate;
  final double total;
  final int units;
  final String unitLabel;
  final VoidCallback onBook;

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
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: TextSpan(
                      style: AppTheme.headlineMd.copyWith(fontSize: 21),
                      children: [
                        TextSpan(text: AppFormatters.money(unitRate)),
                        TextSpan(
                          text: ' / $unitLabel',
                          style: AppTheme.bodySm.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Total $units $unitLabel: ${AppFormatters.money(total)}',
                    style: AppTheme.labelSm.copyWith(
                      fontSize: 10,
                      color: AppColors.tertiaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 190,
              child: CarmanButton(
                label: 'Reservar ahora',
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: vehicle.isAvailable ? onBook : null,
                height: 48,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
