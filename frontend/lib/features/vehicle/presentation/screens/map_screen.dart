import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../shared/widgets/carman_image.dart';
import '../../../../shared/widgets/carman_top_bar.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../explore/application/catalog_controller.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  int _selected = 0;

  static const _positions = [
    Offset(0.22, 0.24),
    Offset(0.62, 0.18),
    Offset(0.72, 0.44),
    Offset(0.34, 0.48),
    Offset(0.5, 0.32),
    Offset(0.18, 0.58),
    Offset(0.66, 0.64),
    Offset(0.42, 0.68),
  ];

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogControllerProvider);
    final vehicles = catalog.vehicles;
    final selectedVehicle = vehicles.isEmpty
        ? null
        : vehicles[_selected.clamp(0, vehicles.length - 1)];

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CarmanImage(
            'assets/images/misc/map_proto.jpg',
            fit: BoxFit.cover,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x3DFFFFFF),
                  Color(0x0AFFFFFF),
                  Color(0x99171717),
                ],
                stops: [0, 0.55, 1],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Row(
                    children: [
                      RoundIconButton(
                        icon: Icons.arrow_back_rounded,
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 17,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      catalog.query.city,
                                      style: AppTheme.labelLg.copyWith(
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      '${vehicles.length} vehículos disponibles',
                                      style: AppTheme.bodySm.copyWith(
                                        fontSize: 9.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      RoundIconButton(
                        icon: Icons.tune_rounded,
                        onPressed: () => context.push('/search'),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (vehicles.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.graphite.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          'Toca un precio para ver el vehículo',
                          style: AppTheme.labelSm.copyWith(
                            color: Colors.white,
                            fontSize: 9,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  for (var index = 0; index < vehicles.length; index++)
                    Positioned(
                      left:
                          _positions[index % _positions.length].dx *
                              constraints.maxWidth -
                          35,
                      top:
                          _positions[index % _positions.length].dy *
                              (constraints.maxHeight - 250) +
                          100,
                      child: _PriceMarker(
                        vehicle: vehicles[index],
                        selected: index == _selected,
                        onTap: () => setState(() => _selected = index),
                      ),
                    ),
                ],
              );
            },
          ),
          if (selectedVehicle != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: SafeArea(
                top: false,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _VehicleMapCard(
                    key: ValueKey(selectedVehicle.id),
                    vehicle: selectedVehicle,
                    onTap: () => context.push('/vehicle/${selectedVehicle.id}'),
                  ),
                ),
              ),
            ),
          if (vehicles.isEmpty)
            Positioned.fill(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(30),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.map_outlined,
                        size: 38,
                        color: AppColors.tertiaryText,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No hay vehículos en esta zona',
                        style: AppTheme.headlineSm,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: () => context.pop(),
                        child: const Text('Volver a la lista'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PriceMarker extends StatelessWidget {
  const _PriceMarker({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  final Vehicle vehicle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryViolet : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected ? Colors.white : AppColors.borderSoft,
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33171717),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              AppFormatters.money(vehicle.pricePerDay),
              style: AppTheme.labelLg.copyWith(
                fontSize: 12,
                color: selected ? Colors.white : AppColors.onSurface,
              ),
            ),
          ),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryViolet : AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleMapCard extends StatelessWidget {
  const _VehicleMapCard({
    super.key,
    required this.vehicle,
    required this.onTap,
  });

  final Vehicle vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33171717),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CarmanImage(vehicle.primaryPhoto, width: 105, height: 82),
          ),
          const SizedBox(width: 11),
          Expanded(
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
                        style: AppTheme.titleMd,
                      ),
                    ),
                    const SizedBox(width: 4),
                    RatingBadge(rating: vehicle.rating, compact: true),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${vehicle.locationName} · ${vehicle.transmission.label}',
                  style: AppTheme.bodySm.copyWith(fontSize: 10.5),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: AppTheme.titleLg.copyWith(fontSize: 15),
                    children: [
                      TextSpan(text: AppFormatters.money(vehicle.pricePerDay)),
                      TextSpan(
                        text: ' / día',
                        style: AppTheme.bodySm.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 42,
            height: 42,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(42, 42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Icon(Icons.arrow_forward_rounded, size: 19),
            ),
          ),
        ],
      ),
    );
  }
}
