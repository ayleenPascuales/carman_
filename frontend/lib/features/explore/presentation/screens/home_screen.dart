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
import '../../../../shared/widgets/carman_image.dart';
import '../../../../shared/widgets/carman_top_bar.dart';
import '../../../../shared/widgets/fade_slide_in.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/sheets.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../notifications/application/notifications_controller.dart';
import '../../application/catalog_controller.dart';
import '../widgets/vehicle_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogControllerProvider);
    final user = ref.watch(authControllerProvider).user;
    final notifications = ref.watch(notificationsControllerProvider);
    final query = catalog.query;

    final dateLabel = query.startAt != null && query.endAt != null
        ? AppFormatters.dateRange(query.startAt!, query.endAt!)
        : 'Cualquier fecha';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth;
          final side = contentWidth > AppBreakpoints.maxContent
              ? (contentWidth - AppBreakpoints.maxContent) / 2 + 18
              : AppBreakpoints.isMobile(contentWidth)
              ? 18.0
              : 28.0;
          final columns = responsiveColumns(contentWidth);
          return SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () =>
                  ref.read(catalogControllerProvider.notifier).refresh(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(side, 6, side, 0),
                      child: Column(
                        children: [
                          _Header(
                            city: query.city,
                            avatarAsset: user?.avatarAsset,
                            avatarUrl: user?.avatarUrl,
                            initials: user?.initials,
                            hasUnread: notifications.unreadCount > 0,
                            onLocationTap: () =>
                                _showLocationSheet(context, ref),
                            onNotificationsTap: () =>
                                context.push('/notifications'),
                            onAvatarTap: () => context.go('/profile'),
                          ),
                          const SizedBox(height: 16),
                          _SearchBar(
                            dateLabel: dateLabel,
                            onTap: () => context.push('/search'),
                          ),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _CategoryCarousel(
                      selected: query.category,
                      padding: side,
                      onSelected: (category) => ref
                          .read(catalogControllerProvider.notifier)
                          .setCategory(category),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(side, 20, side, 10),
                      child: SectionHeader(
                        title: 'Cerca de ti',
                        count: catalog.count,
                        actionLabel: _sortShort(query.sort),
                        onAction: () => _showSortSheet(context, ref),
                      ),
                    ),
                  ),
                  if (catalog.error != null && catalog.vehicles.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: ErrorView(
                        message: catalog.error!,
                        onRetry: () => ref
                            .read(catalogControllerProvider.notifier)
                            .refresh(),
                      ),
                    )
                  else if (catalog.isLoading && catalog.vehicles.isEmpty)
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: side),
                      sliver: SliverToBoxAdapter(
                        child: LoadingList(count: 2, height: 330),
                      ),
                    )
                  else if (catalog.vehicles.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        title: 'Sin resultados',
                        message: 'Prueba otra categoría o cambia de ciudad.',
                        actionLabel: 'Limpiar filtros',
                        onAction: () => ref
                            .read(catalogControllerProvider.notifier)
                            .updateQuery(VehicleQuery(city: query.city)),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(side, 0, side, 28),
                      sliver: columns == 1
                          ? SliverList.separated(
                              itemCount: catalog.vehicles.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final vehicle = catalog.vehicles[index];
                                return FadeSlideIn(
                                  index: index,
                                  child: VehicleCard(
                                    vehicle: vehicle,
                                    mode: query.mode,
                                    onTap: () =>
                                        context.push('/vehicle/${vehicle.id}'),
                                  ),
                                );
                              },
                            )
                          : SliverGrid(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final vehicle = catalog.vehicles[index];
                                return FadeSlideIn(
                                  index: index,
                                  child: VehicleCard(
                                    vehicle: vehicle,
                                    mode: query.mode,
                                    onTap: () =>
                                        context.push('/vehicle/${vehicle.id}'),
                                  ),
                                );
                              }, childCount: catalog.vehicles.length),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    mainAxisExtent: 348,
                                  ),
                            ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _sortShort(SortOption sort) => switch (sort) {
    SortOption.relevance => 'Relevancia',
    SortOption.priceAsc => 'Menor precio',
    SortOption.priceDesc => 'Mayor precio',
    SortOption.rating => 'Mejor valor',
    SortOption.distance => 'Cercanía',
  };

  void _showLocationSheet(BuildContext context, WidgetRef ref) {
    final catalog = ref.read(catalogControllerProvider);
    showCarmanSheet<void>(
      context: context,
      maxHeightFactor: 0.7,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeader(title: 'Elige una ciudad'),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              children: AppConfig.cities.map((city) {
                final selected = catalog.query.city == city;
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: Text(city, style: AppTheme.titleMd),
                  trailing: selected
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.primary,
                          size: 18,
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(catalogControllerProvider.notifier).setCity(city);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showSortSheet(BuildContext context, WidgetRef ref) {
    final current = ref.read(catalogControllerProvider).query.sort;
    showCarmanSheet<void>(
      context: context,
      maxHeightFactor: 0.6,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeader(title: 'Ordenar'),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
              children: SortOption.values.map((option) {
                final selected = option == current;
                return ListTile(
                  leading: Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 19,
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

class _Header extends StatelessWidget {
  const _Header({
    required this.city,
    required this.hasUnread,
    required this.onLocationTap,
    required this.onNotificationsTap,
    required this.onAvatarTap,
    this.avatarAsset,
    this.avatarUrl,
    this.initials,
  });

  final String city;
  final bool hasUnread;
  final VoidCallback onLocationTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onAvatarTap;
  final String? avatarAsset;
  final String? avatarUrl;
  final String? initials;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onLocationTap,
            borderRadius: BorderRadius.circular(99),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 17,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.titleLg.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.25,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 17,
                    color: AppColors.tertiaryText,
                  ),
                ],
              ),
            ),
          ),
        ),
        Stack(
          children: [
            RoundIconButton(
              icon: Icons.notifications_none_rounded,
              onPressed: onNotificationsTap,
              tooltip: 'Notificaciones',
            ),
            if (hasUnread)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.primaryViolet,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.canvas, width: 1.3),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onAvatarTap,
          child: CircleAvatarImage(
            asset: avatarAsset,
            url: avatarUrl,
            initials: initials,
            radius: 18,
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.dateLabel, required this.onTap});

  final String dateLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 18,
                offset: Offset(0, 6),
                spreadRadius: -8,
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                size: 19,
                color: AppColors.onSurface,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿A dónde vas?',
                      style: AppTheme.labelLg.copyWith(fontSize: 12.5),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      dateLabel,
                      style: AppTheme.bodySm.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.tune_rounded,
                size: 17,
                color: AppColors.tertiaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCarousel extends StatelessWidget {
  const _CategoryCarousel({
    required this.selected,
    required this.onSelected,
    required this.padding,
  });

  final VehicleCategory selected;
  final ValueChanged<VehicleCategory> onSelected;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final categories = [
      VehicleCategory.all,
      VehicleCategory.electric,
      VehicleCategory.suv,
      VehicleCategory.sport,
      VehicleCategory.family,
    ];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: padding),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final category = categories[index];
          return CarmanFilterChip(
            label: category.label,
            selected: category == selected,
            onTap: () => onSelected(category),
          );
        },
      ),
    );
  }
}
