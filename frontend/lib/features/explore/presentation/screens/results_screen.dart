import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../data/models/vehicle_query.dart';
import '../../../../shared/widgets/carman_chips.dart';
import '../../../../shared/widgets/carman_top_bar.dart';
import '../../../../shared/widgets/fade_slide_in.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/sheets.dart';
import '../../../notifications/application/notifications_controller.dart';
import '../../application/catalog_controller.dart';
import '../widgets/vehicle_card.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogControllerProvider);
    final query = catalog.query;
    final notifications = ref.watch(notificationsControllerProvider);

    final dateSummary = query.startAt != null && query.endAt != null
        ? '${AppFormatters.shortDate(query.startAt!)} · '
              '${_durationLabel(query)}'
        : 'Selecciona tus fechas';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.maxWidth > 940
              ? (constraints.maxWidth - 880) / 2
              : 16.0;
          return SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(side, 6, side, 0),
              child: Row(
                children: [
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Resultados',
                      textAlign: TextAlign.center,
                      style: AppTheme.headlineSm.copyWith(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Stack(
                    children: [
                      RoundIconButton(
                        icon: Icons.notifications_none_rounded,
                        onPressed: () => context.push('/notifications'),
                      ),
                      if (notifications.unreadCount > 0)
                        Positioned(
                          right: 5,
                          top: 5,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryViolet,
                              border: Border.all(
                                color: AppColors.surface,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () =>
                    ref.read(catalogControllerProvider.notifier).refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(side, 0, side, 30),
                  children: [
                    _SearchSummary(
                      city: query.city,
                      summary: dateSummary,
                      onTap: () => context.push('/search'),
                      onFilterTap: () => context.push('/search'),
                      filterCount: query.activeFilterCount,
                    ),
                    if (_hasFilters(query)) ...[
                      const SizedBox(height: 12),
                      _FilterChips(
                        query: query,
                        onRemove: (next) => ref
                            .read(catalogControllerProvider.notifier)
                            .updateQuery(next),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${catalog.count} coches · ${query.city}',
                            style: AppTheme.bodySm.copyWith(fontSize: 11.5),
                          ),
                        ),
                        InkWell(
                          onTap: () => _showSort(context, ref),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 5,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _shortSort(query.sort),
                                  style: AppTheme.labelMd.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.expand_more_rounded,
                                  size: 17,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (catalog.isLoading && catalog.vehicles.isEmpty)
                      const LoadingList(count: 2, height: 330)
                    else if (catalog.error != null && catalog.vehicles.isEmpty)
                      SizedBox(
                        height: 400,
                        child: ErrorView(
                          message: catalog.error!,
                          onRetry: () => ref
                              .read(catalogControllerProvider.notifier)
                              .refresh(),
                        ),
                      )
                    else if (catalog.vehicles.isEmpty)
                      SizedBox(
                        height: 430,
                        child: EmptyState(
                          title: 'No encontramos coches',
                          message: 'Ajusta tus filtros o prueba con otras fechas. También puedes ampliar la zona de búsqueda.',
                          actionLabel: 'Editar búsqueda',
                          onAction: () => context.push('/search'),
                        ),
                      )
                    else ...[
                      for (
                        var index = 0;
                        index < catalog.vehicles.length;
                        index++
                      ) ...[
                        FadeSlideIn(
                          index: index,
                          child: VehicleCard(
                            vehicle: catalog.vehicles[index],
                            mode: query.mode,
                            onTap: () => context.push(
                              '/vehicle/${catalog.vehicles[index].id}',
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (catalog.error != null)
                        InfoBanner(
                          title: 'No pudimos actualizar el catálogo',
                          message: catalog.error!,
                          color: AppColors.error,
                          icon: Icons.error_outline_rounded,
                          compact: true,
                        ),
                      if (catalog.hasMore || catalog.isLoadingMore) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: TextButton(
                            onPressed: catalog.isLoadingMore
                                ? null
                                : () => ref.read(catalogControllerProvider.notifier)
                                    .loadMore(),
                            child: Text(catalog.isLoadingMore
                                ? 'Cargando…' : 'Ver más vehículos'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => context.push('/map'),
                          icon: const Icon(Icons.map_outlined, size: 16),
                          label: const Text('Mapa'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
        },
      ),
    );
  }

  bool _hasFilters(VehicleQuery query) => query.activeFilterCount > 0;

  String _durationLabel(VehicleQuery query) {
    final units = query.hoursOrDays;
    if (units == 0) return 'Fechas por confirmar';
    return query.mode == RentalMode.hourly ? '$units horas' : '$units días';
  }

  String _shortSort(SortOption sort) {
    return switch (sort) {
      SortOption.relevance => 'Relevancia',
      SortOption.priceAsc => 'Menor precio',
      SortOption.priceDesc => 'Mayor precio',
      SortOption.rating => 'Mejor valor',
      SortOption.distance => 'Cercanía',
    };
  }

  void _showSort(BuildContext context, WidgetRef ref) {
    final current = ref.read(catalogControllerProvider).query.sort;
    showCarmanSheet<void>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeader(title: 'Ordenar resultados'),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              children: SortOption.values
                  .where((option) => !AppConfig.useLiveApi ||
                      (option != SortOption.rating &&
                          option != SortOption.distance))
                  .map((option) {
                final selected = option == current;
                return ListTile(
                  leading: Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected
                        ? AppColors.primary
                        : AppColors.tertiaryText,
                  ),
                  title: Text(option.label, style: AppTheme.titleMd),
                  onTap: () {
                    Navigator.pop(context);
                    ref
                        .read(catalogControllerProvider.notifier)
                        .setSort(option);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchSummary extends StatelessWidget {
  const _SearchSummary({
    required this.city,
    required this.summary,
    required this.onTap,
    required this.onFilterTap,
    required this.filterCount,
  });

  final String city;
  final String summary;
  final VoidCallback onTap;
  final VoidCallback onFilterTap;
  final int filterCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.labelLg.copyWith(fontSize: 13),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.bodySm.copyWith(fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppColors.tertiaryText,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Stack(
          clipBehavior: Clip.none,
          children: [
            RoundIconButton(icon: Icons.tune_rounded, onPressed: onFilterTap),
            if (filterCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$filterCount',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.query, required this.onRemove});

  final VehicleQuery query;
  final ValueChanged<VehicleQuery> onRemove;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (query.category != VehicleCategory.all) {
      chips.add(
        CarmanFilterChip(
          label: query.category.label,
          selected: true,
          showClose: true,
          onTap: () => onRemove(query.copyWith(category: VehicleCategory.all)),
        ),
      );
    }
    if (query.maxPrice != null) {
      chips.add(
        CarmanFilterChip(
          label:
              'Precio < ${AppFormatters.money(query.maxPrice!)} / ${query.mode == RentalMode.hourly ? 'h' : 'día'}',
          selected: true,
          showClose: true,
          onTap: () => onRemove(query.copyWith(clearMaxPrice: true)),
        ),
      );
    }
    if (query.transmission != null) {
      chips.add(
        CarmanFilterChip(
          label: query.transmission!.label,
          selected: true,
          showClose: true,
          onTap: () => onRemove(query.copyWith(clearTransmission: true)),
        ),
      );
    }
    if (query.fuel != null) {
      chips.add(
        CarmanFilterChip(
          label: query.fuel!.label,
          selected: true,
          showClose: true,
          onTap: () => onRemove(query.copyWith(clearFuel: true)),
        ),
      );
    }
    if (query.minSeats != null) {
      chips.add(
        CarmanFilterChip(
          label: '${query.minSeats}+ plazas',
          selected: true,
          showClose: true,
          onTap: () => onRemove(query.copyWith(clearSeats: true)),
        ),
      );
    }
    if (query.instantBookOnly) {
      chips.add(
        CarmanFilterChip(
          label: 'Apertura móvil',
          selected: true,
          showClose: true,
          onTap: () => onRemove(query.copyWith(instantBookOnly: false)),
        ),
      );
    }
    if (query.freeCancellationOnly) {
      chips.add(
        CarmanFilterChip(
          label: 'Cancelación gratis',
          selected: true,
          showClose: true,
          onTap: () => onRemove(query.copyWith(freeCancellationOnly: false)),
        ),
      );
    }
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, index) => chips[index],
      ),
    );
  }
}
