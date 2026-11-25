import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/fade_slide_in.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../explore/presentation/widgets/vehicle_card.dart';
import '../../application/favorites_controller.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteVehiclesProvider);
    final ids = ref.watch(favoritesControllerProvider);

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
          onRefresh: () async => ref.invalidate(favoriteVehiclesProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(side, 12, side, 30),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GUARDADOS', style: AppTheme.overline),
                        const SizedBox(height: 3),
                        Text('Tus favoritos', style: AppTheme.headlineMd),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.softLavender,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '${ids.length} coches',
                      style: AppTheme.labelSm.copyWith(
                        color: AppColors.primary,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              favorites.when(
                loading: () => const LoadingList(count: 2, height: 330),
                error: (error, stackTrace) => ErrorView(
                  message: 'No pudimos cargar tus favoritos.',
                  onRetry: () => ref.invalidate(favoriteVehiclesProvider),
                ),
                data: (vehicles) {
                  if (vehicles.isEmpty) {
                    return EmptyState(
                      title: 'Tu garaje está vacío',
                      message: 'Guarda los coches que te gusten con el corazón y compáralos cuando quieras.',
                      icon: Icons.favorite_border_rounded,
                      actionLabel: 'Explorar vehículos',
                      onAction: () => context.go('/home'),
                    );
                  }
                  return LayoutBuilder(
                    builder: (context, inner) {
                      final columns = inner.maxWidth > 700 ? 2 : 1;
                      final cardWidth =
                          (inner.maxWidth - (columns - 1) * 14) / columns;
                      return Column(
                        children: [
                          Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: [
                              for (var index = 0;
                                  index < vehicles.length;
                                  index++)
                                SizedBox(
                                  width: cardWidth,
                                  child: FadeSlideIn(
                                    index: index,
                                    child: VehicleCard(
                                      vehicle: vehicles[index],
                                      onTap: () => context.push(
                                        '/vehicle/${vehicles[index].id}',
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Los precios pueden variar según las fechas seleccionadas.',
                            textAlign: TextAlign.center,
                            style: AppTheme.bodySm.copyWith(fontSize: 9.5),
                          ),
                        ],
                      );
                    },
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
