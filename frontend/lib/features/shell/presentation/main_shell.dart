import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_profile.dart';
import '../../../shared/widgets/carman_image.dart';
import '../../../shared/widgets/carman_logo.dart';
import '../../auth/application/auth_controller.dart';
import '../../notifications/application/notifications_controller.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsControllerProvider);
    final user = ref.watch(authControllerProvider).user;
    final width = MediaQuery.sizeOf(context).width;

    if (width >= 720) {
      final compact = width < 1050;
      return Scaffold(
        body: Row(
          children: [
            _SideNav(
              currentIndex: navigationShell.currentIndex,
              compact: compact,
              unread: notifications.unreadCount,
              user: user,
              onTap: (index) {
                if (index == navigationShell.currentIndex) {
                  navigationShell.goBranch(index, initialLocation: true);
                } else {
                  navigationShell.goBranch(index);
                }
              },
            ),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _BottomNav(
        currentIndex: navigationShell.currentIndex,
        unread: notifications.unreadCount,
        onTap: (index) {
          if (index == navigationShell.currentIndex) {
            navigationShell.goBranch(index, initialLocation: true);
          } else {
            navigationShell.goBranch(index);
          }
        },
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData(this.icon, this.activeIcon, this.label);

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const _items = [
  _NavItemData(Icons.explore_outlined, Icons.explore_rounded, 'Explorar'),
  _NavItemData(
    Icons.favorite_border_rounded,
    Icons.favorite_rounded,
    'Favoritos',
  ),
  _NavItemData(
    Icons.confirmation_number_outlined,
    Icons.confirmation_number_rounded,
    'Viajes',
  ),
  _NavItemData(Icons.person_outline_rounded, Icons.person_rounded, 'Perfil'),
];

class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.currentIndex,
    required this.compact,
    required this.unread,
    required this.user,
    required this.onTap,
  });

  final int currentIndex;
  final bool compact;
  final int unread;
  final UserProfile? user;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 80 : 226,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 24,
            offset: Offset(8, 0),
          ),
        ],
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 0 : 20,
                22,
                compact ? 0 : 20,
                26,
              ),
              child: compact
                  ? const Center(
                      child: CarmanLogo(showWordmark: false, size: 36),
                    )
                  : const CarmanLogo(size: 34),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) => _NavItem(
                  data: _items[index],
                  active: index == currentIndex,
                  compact: compact,
                  unread: index == 2 ? unread : 0,
                  onTap: () => onTap(index),
                ),
              ),
            ),
            if (!compact) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Row(
                  children: [
                    CircleAvatarImage(
                      asset: user?.avatarAsset,
                      url: user?.avatarUrl,
                      initials: user?.initials,
                      radius: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.firstName ?? 'Invitado',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.labelMd.copyWith(fontSize: 11),
                          ),
                          Text(
                            user?.roles.contains(UserRole.admin) == true
                                ? 'Administrador'
                                : user?.roles.contains(UserRole.owner) == true
                                ? 'Propietario'
                                : user?.roles.contains(UserRole.driver) == true
                                ? 'Conductor'
                                : 'Cliente',
                            style: AppTheme.bodySm.copyWith(fontSize: 8.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                compact ? 'v1' : 'Carman 1.0',
                style: AppTheme.bodySm.copyWith(fontSize: 8.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.active,
    required this.compact,
    required this.unread,
    required this.onTap,
  });

  final _NavItemData data;
  final bool active;
  final bool compact;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final item = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 0 : 12,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: active ? AppColors.softLavender : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: compact
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  active ? data.activeIcon : data.icon,
                  size: 20,
                  color: active ? AppColors.primary : AppColors.tertiaryText,
                ),
                if (unread > 0)
                  Positioned(
                    right: -5,
                    top: -4,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryViolet,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 7,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (!compact) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.label,
                  style: AppTheme.labelMd.copyWith(
                    fontSize: 12,
                    color: active ? AppColors.primary : AppColors.secondaryText,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return compact ? Tooltip(message: data.label, child: item) : item;
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentIndex,
    required this.unread,
    required this.onTap,
  });

  final int currentIndex;
  final int unread;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(_items.length, (index) {
              final active = index == currentIndex;
              final item = _items[index];
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            active ? item.activeIcon : item.icon,
                            size: 20,
                            color: active
                                ? AppColors.primary
                                : AppColors.tertiaryText,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            style: AppTheme.labelSm.copyWith(
                              fontSize: 8.5,
                              letterSpacing: 0,
                              color: active
                                  ? AppColors.primary
                                  : AppColors.tertiaryText,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (index == 2 && unread > 0)
                        Positioned(
                          top: 7,
                          right: 27,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryViolet,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$unread',
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 7,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
