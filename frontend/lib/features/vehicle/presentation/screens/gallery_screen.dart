import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../data/models/user_profile.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../providers.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_image.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../booking/application/booking_controller.dart';
import '../../../favorites/application/favorites_controller.dart';

enum _GalleryFilter { all, exterior, interior, detail }

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  final _pageController = PageController();
  _GalleryFilter _filter = _GalleryFilter.all;
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<String> _photos(Vehicle vehicle) {
    final all = vehicle.photos;
    if (all.isEmpty) return const [];
    return switch (_filter) {
      _GalleryFilter.all => all,
      _GalleryFilter.exterior => [
        for (var i = 0; i < all.length; i++)
          if (i % 4 == 0 || i % 4 == 2 || i % 4 == 3) all[i],
      ],
      _GalleryFilter.interior => [
        for (var i = 0; i < all.length; i++)
          if (i % 4 == 1) all[i],
      ],
      _GalleryFilter.detail => all.length > 3 ? [all.last] : all,
    };
  }

  String _filterLabel(_GalleryFilter filter, Vehicle vehicle) {
    final count = switch (filter) {
      _GalleryFilter.all => vehicle.photos.length,
      _GalleryFilter.exterior => _photosForCount(
        vehicle,
        _GalleryFilter.exterior,
      ),
      _GalleryFilter.interior => _photosForCount(
        vehicle,
        _GalleryFilter.interior,
      ),
      _GalleryFilter.detail => _photosForCount(vehicle, _GalleryFilter.detail),
    };
    final label = switch (filter) {
      _GalleryFilter.all => 'Todas',
      _GalleryFilter.exterior => 'Exterior',
      _GalleryFilter.interior => 'Interior',
      _GalleryFilter.detail => 'Detalles',
    };
    return '$label ($count)';
  }

  int _photosForCount(Vehicle vehicle, _GalleryFilter filter) {
    final all = vehicle.photos;
    return switch (filter) {
      _GalleryFilter.all => all.length,
      _GalleryFilter.exterior => [
        for (var i = 0; i < all.length; i++)
          if (i % 4 == 0 || i % 4 == 2 || i % 4 == 3) all[i],
      ].length,
      _GalleryFilter.interior => [
        for (var i = 0; i < all.length; i++)
          if (i % 4 == 1) all[i],
      ].length,
      _GalleryFilter.detail => all.length > 3 ? 1 : all.length,
    };
  }

  void _reserve(Vehicle vehicle) {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    if (user.licenseStatus != LicenseStatus.approved) {
      showCarmanSnack(
        context,
        'Verifica tu licencia para poder reservar.',
        kind: SnackKind.warning,
        actionLabel: 'Verificar',
        onAction: () => context.push('/license'),
      );
      return;
    }
    ref.read(bookingControllerProvider.notifier).start(vehicle);
    context.push('/checkout');
  }

  @override
  Widget build(BuildContext context) {
    final vehicleAsync = ref.watch(vehicleByIdProvider(widget.vehicleId));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0E0D12),
        body: vehicleAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          error: (_, _) => Center(
            child: TextButton(
              onPressed: () => context.pop(),
              child: const Text('Volver'),
            ),
          ),
          data: (vehicle) {
            if (vehicle == null) {
              return const Center(
                child: Text(
                  'Vehículo no disponible',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }
            final photos = _photos(vehicle);
            final favorite = ref
                .watch(favoritesControllerProvider)
                .contains(vehicle.id);
            return SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: [
                        _GlassIconButton(
                          icon: Icons.close_rounded,
                          onPressed: () => context.pop(),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            'Foto ${_index + 1} de ${photos.length}',
                            style: AppTheme.labelMd.copyWith(
                              color: Colors.white,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        const Spacer(),
                        _GlassIconButton(
                          icon: Icons.ios_share_rounded,
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: vehicle.fullTitle),
                            );
                            showCarmanSnack(
                              context,
                              'Enlace copiado.',
                              kind: SnackKind.success,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _GlassIconButton(
                          icon: favorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: favorite ? AppColors.error : Colors.white,
                          onPressed: () => ref
                              .read(favoritesControllerProvider.notifier)
                              .toggle(vehicle.id),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _GalleryFilter.values.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 7),
                      itemBuilder: (context, index) {
                        final filter = _GalleryFilter.values[index];
                        final selected = filter == _filter;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _filter = filter;
                              _index = 0;
                            });
                            _pageController.jumpToPage(0);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 13),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primaryViolet
                                  : Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Text(
                              _filterLabel(filter, vehicle),
                              style: AppTheme.labelMd.copyWith(
                                color: Colors.white,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          itemCount: photos.length,
                          onPageChanged: (index) =>
                              setState(() => _index = index),
                          itemBuilder: (context, index) => InteractiveViewer(
                            minScale: 1,
                            maxScale: 3,
                            child: Center(
                              child: CarmanImage(
                                photos[index],
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                          ),
                        ),
                        if (photos.length > 1) ...[
                          Positioned(
                            left: 14,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: _GlassIconButton(
                                icon: Icons.chevron_left_rounded,
                                size: 38,
                                onPressed: () => _pageController.previousPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 14,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: _GlassIconButton(
                                icon: Icons.chevron_right_rounded,
                                size: 38,
                                onPressed: () => _pageController.nextPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                ),
                              ),
                            ),
                          ),
                        ],
                        Positioned(
                          right: 14,
                          bottom: 14,
                          child: _GlassIconButton(
                            icon: Icons.zoom_in_rounded,
                            onPressed: () => showCarmanSnack(
                              context,
                              'Pellizca la imagen para ampliar los detalles.',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 74,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: photos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final selected = index == _index;
                        return GestureDetector(
                          onTap: () => _pageController.jumpToPage(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 58,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primaryViolet
                                    : Colors.white.withValues(alpha: 0.2),
                                width: selected ? 2.4 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CarmanImage(photos[index]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF211F28),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.09),
                      ),
                    ),
                    child: Row(
                      children: [
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
                                      style: AppTheme.titleLg.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryViolet,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${vehicle.year}',
                                      style: AppTheme.labelSm.copyWith(
                                        color: Colors.white,
                                        fontSize: 8.5,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                vehicle.traction,
                                style: AppTheme.bodySm.copyWith(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 10.5,
                                ),
                              ),
                              const SizedBox(height: 5),
                              RichText(
                                text: TextSpan(
                                  style: AppTheme.titleLg.copyWith(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  children: [
                                    TextSpan(
                                      text:
                                          '${AppFormatters.money(vehicle.pricePerHour)}/h',
                                    ),
                                    TextSpan(
                                      text:
                                          '  ·  ${AppFormatters.money(vehicle.pricePerDay)}/día',
                                      style: AppTheme.bodySm.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.55,
                                        ),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: () => _reserve(vehicle),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(118, 46),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            backgroundColor: AppColors.primaryViolet,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Reservar'),
                              SizedBox(width: 5),
                              Icon(Icons.arrow_forward_rounded, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onPressed,
    this.color = Colors.white,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.45, color: color),
        ),
      ),
    );
  }
}
