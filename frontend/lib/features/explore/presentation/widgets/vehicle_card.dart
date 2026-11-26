import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../data/models/vehicle_query.dart';
import '../../../../shared/widgets/carman_image.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../favorites/application/favorites_controller.dart';

class VehicleCard extends ConsumerWidget {
  const VehicleCard({
    super.key,
    required this.vehicle,
    required this.onTap,
    this.mode = RentalMode.daily,
  });

  final Vehicle vehicle;
  final VoidCallback onTap;
  final RentalMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref
        .watch(favoritesControllerProvider)
        .contains(vehicle.id);
    final price = mode == RentalMode.hourly
        ? vehicle.pricePerHour
        : vehicle.pricePerDay;
    final unit = mode == RentalMode.hourly ? 'h' : 'día';

    return HoverLift(
      child: Semantics(
        button: true,
        label: '${vehicle.title}, ${AppFormatters.money(price)} por $unit',
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x07000000),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                    spreadRadius: -12,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Hero(
                        tag: 'vehicle-${vehicle.id}',
                        child: CarmanImage(
                          vehicle.primaryPhoto,
                          height: 198,
                          width: double.infinity,
                        ),
                      ),
                      Positioned(
                        left: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                vehicle.instantBook
                                    ? Icons.key_rounded
                                    : Icons.place_outlined,
                                size: 11,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                vehicle.instantBook
                                    ? 'Apertura móvil'
                                    : vehicle.locationName,
                                style: AppTheme.labelSm.copyWith(
                                  fontSize: 9,
                                  color: Colors.white,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: GestureDetector(
                          onTap: () => ref
                              .read(favoritesControllerProvider.notifier)
                              .toggle(vehicle.id),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.surface.withValues(alpha: 0.92),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 16,
                              color: isFavorite
                                  ? AppColors.error
                                  : AppColors.secondaryText,
                            ),
                          ),
                        ),
                      ),
                      if (!AppConfig.useLiveApi || vehicle.reviewCount > 0)
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: RatingBadge(
                          rating: vehicle.rating,
                          count: AppConfig.useLiveApi
                              ? vehicle.reviewCount : vehicle.tripCount,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                vehicle.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.titleLg.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${vehicle.year}',
                              style: AppTheme.bodySm.copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${vehicle.transmission.label} · ${vehicle.seats} plazas · ${vehicle.fuel.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodySm.copyWith(fontSize: 10.5),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: AppTheme.headlineSm.copyWith(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: AppFormatters.money(price),
                                        ),
                                        TextSpan(
                                          text: ' / $unit',
                                          style: AppTheme.bodySm.copyWith(
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (vehicle.freeCancellation)
                                    Text(
                                      'Cancelación gratis',
                                      style: AppTheme.bodySm.copyWith(
                                        fontSize: 9.5,
                                        color: AppColors.success,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: onTap,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryViolet,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_outward_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
