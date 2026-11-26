import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../data/models/user_profile.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_card.dart';
import '../../../../shared/widgets/carman_image.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/sheets.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../driver/application/driver_controller.dart';
import '../../../license/application/license_controller.dart';
import '../../../notifications/application/notifications_controller.dart';
import '../../../owner/application/owner_controller.dart';
import '../../application/profile_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _pushNotifications = true;
  bool _biometric = true;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final profile = ref.watch(profileControllerProvider);
    final license = ref.watch(licenseControllerProvider);
    final notifications = ref.watch(notificationsControllerProvider);
    final user = profile.user ?? auth.user;

    if (user == null) {
      return const Scaffold(body: CenteredLoader());
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.maxWidth > 1000
              ? (constraints.maxWidth - 820) / 2
              : 18.0;
          return SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await ref.read(notificationsControllerProvider.notifier).refresh();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(side, 8, side, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Perfil',
                      style: AppTheme.headlineMd.copyWith(fontSize: 22),
                    ),
                  ),
                  Stack(
                    children: [
                      IconButton(
                        onPressed: () => context.push('/notifications'),
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          size: 20,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      if (notifications.unreadCount > 0)
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryViolet,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => _showSettingsSheet(context),
                    icon: const Icon(Icons.tune_rounded, size: 19),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _ProfileHeader(user: user),
              const SizedBox(height: 20),
              _StatsBar(user: user),
              const SizedBox(height: 12),
              _StatusLine(
                license: license,
                onTap: () {
                  if (license.status == LicenseStatus.pendingReview) {
                    context.push('/license/review');
                  } else {
                    context.push('/license');
                  }
                },
              ),
              const SizedBox(height: 20),
              CarmanCard(
                padding: EdgeInsets.zero,
                showShadow: false,
                child: Column(
                  children: [
                    _MenuItem(
                      icon: Icons.person_outline_rounded,
                      title: 'Editar perfil',
                      onTap: () => context.push('/profile/edit'),
                    ),
                    _MenuItem(
                      icon: Icons.verified_user_outlined,
                      title: 'Licencia',
                      trailing: Text(
                        license.status.label,
                        style: AppTheme.bodySm.copyWith(
                          fontSize: 10,
                          color: license.status.color,
                        ),
                      ),
                      onTap: () {
                        if (license.status == LicenseStatus.pendingReview) {
                          context.push('/license/review');
                        } else {
                          context.push('/license');
                        }
                      },
                    ),
                    if (AppConfig.useLiveApi && user.roles.contains(UserRole.client))
                      _MenuItem(
                        icon: Icons.receipt_long_outlined,
                        title: 'Historial de pagos',
                        onTap: () => context.push('/payment-history'),
                      )
                    else if (!AppConfig.useLiveApi)
                      _MenuItem(
                        icon: Icons.credit_card_outlined,
                        title: 'Métodos de pago (demo)',
                        onTap: () => context.push('/payment-methods'),
                      ),
                    _MenuItem(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notificaciones',
                      trailing: notifications.unreadCount > 0
                          ? Text(
                              '${notifications.unreadCount}',
                              style: AppTheme.labelSm.copyWith(
                                color: AppColors.primary,
                                fontSize: 9,
                              ),
                            )
                          : null,
                      onTap: () => context.push('/notifications'),
                    ),
                    _MenuItem(
                      icon: Icons.badge_outlined,
                      title: user.isDriver
                          ? 'Panel de conductor'
                          : 'Hazte conductor',
                      onTap: () => _openDriver(context, ref, user),
                    ),
                    _MenuItem(
                      icon: Icons.car_rental_outlined,
                      title: user.isOwner
                          ? 'Panel de propietario'
                          : 'Hazte propietario',
                      onTap: () => _openOwner(context, ref, user),
                      isLast: !user.isAdmin,
                    ),
                    if (user.isAdmin)
                      _MenuItem(
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'Administración',
                        onTap: () => context.push('/admin'),
                        isLast: true,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              CarmanCard(
                padding: EdgeInsets.zero,
                showShadow: false,
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _pushNotifications,
                      onChanged: (value) {
                        setState(() => _pushNotifications = value);
                      },
                      secondary: const Icon(
                        Icons.notifications_active_outlined,
                        size: 19,
                        color: AppColors.secondaryText,
                      ),
                      title: Text(
                        'Notificaciones push',
                        style: AppTheme.labelMd.copyWith(fontSize: 12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 1,
                      ),
                    ),
                    const Divider(height: 1, indent: 48, endIndent: 14),
                    SwitchListTile(
                      value: _biometric,
                      onChanged: (value) {
                        setState(() => _biometric = value);
                      },
                      secondary: const Icon(
                        Icons.fingerprint_rounded,
                        size: 20,
                        color: AppColors.secondaryText,
                      ),
                      title: Text(
                        'Acceso biométrico',
                        style: AppTheme.labelMd.copyWith(fontSize: 12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 1,
                      ),
                    ),
                    const Divider(height: 1, indent: 48, endIndent: 14),
                    _MenuItem(
                      icon: Icons.support_agent_rounded,
                      title: 'Ayuda',
                      onTap: () => _showSupport(context),
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Center(
                child: TextButton.icon(
                  onPressed: () => _logout(context, ref),
                  icon: const Icon(Icons.logout_rounded, size: 15),
                  label: const Text('Cerrar sesión'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.secondaryText,
                  ),
                ),
              ),
              Center(
                child: Text(
                  'Carman 1.0',
                  style: AppTheme.bodySm.copyWith(fontSize: 9),
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

  Future<void> _openDriver(
    BuildContext context,
    WidgetRef ref,
    UserProfile user,
  ) async {
    if (!user.isDriver) {
      if (user.licenseStatus != LicenseStatus.approved) {
        showCarmanSnack(
          context,
          'Verifica tu licencia para activar el modo conductor.',
          kind: SnackKind.warning,
        );
        unawaited(context.push('/license'));
        return;
      }
      final confirmed = await showConfirmDialog(
        context,
        title: 'Hazte conductor',
        message: 'Recibe solicitudes y gana por servicio.',
        confirmLabel: 'Continuar',
        icon: Icons.badge_outlined,
      );
      if (!confirmed || !context.mounted) return;
      final success = await ref
          .read(profileControllerProvider.notifier)
          .addRole(UserRole.driver);
      if (!context.mounted) return;
      if (!success) {
        final error = ref.read(profileControllerProvider).error;
        if (error != null) {
          showCarmanSnack(context, error, kind: SnackKind.error);
        }
        return;
      }
      ref.invalidate(driverControllerProvider);
      showCarmanSnack(
        context,
        'Modo conductor activado.',
        kind: SnackKind.success,
      );
    }
    unawaited(context.push('/driver'));
  }

  Future<void> _openOwner(
    BuildContext context,
    WidgetRef ref,
    UserProfile user,
  ) async {
    if (AppConfig.useLiveApi && !user.isOwner) {
      unawaited(context.push('/owner/add-vehicle'));
      return;
    }
    if (user.isOwner) {
      unawaited(context.push('/owner'));
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hazte propietario',
      message: 'Podrás publicar tu coche y recibir reservas verificadas.',
      confirmLabel: 'Continuar',
      icon: Icons.car_rental_rounded,
    );
    if (!confirmed || !context.mounted) return;
    final success = await ref
        .read(profileControllerProvider.notifier)
        .addRole(UserRole.owner);
    if (!context.mounted) return;
    if (success) {
      ref.invalidate(ownerControllerProvider);
      showCarmanSnack(
        context,
        'Modo propietario activado.',
        kind: SnackKind.success,
      );
      unawaited(context.push('/owner'));
    } else {
      final error = ref.read(profileControllerProvider).error;
      if (error != null) showCarmanSnack(context, error, kind: SnackKind.error);
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cerrar sesión',
      message: '¿Quieres salir de tu cuenta?',
      confirmLabel: 'Salir',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(authControllerProvider.notifier).logout();
    if (context.mounted) context.go('/welcome');
  }

  void _showSupport(BuildContext context) {
    showCarmanSheet<void>(
      context: context,
      maxHeightFactor: 0.55,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeader(title: 'Ayuda'),
          ListTile(
            leading: const IconTile(icon: Icons.chat_bubble_outline_rounded),
            title: const Text('Chat en vivo'),
            trailing: const Icon(Icons.chevron_right_rounded, size: 18),
            onTap: () {
              Navigator.pop(context);
              showCarmanSnack(context, 'Abriendo chat…', kind: SnackKind.info);
            },
          ),
          ListTile(
            leading: const IconTile(icon: Icons.mail_outline_rounded),
            title: const Text('soporte@carman.app'),
            trailing: const Icon(Icons.chevron_right_rounded, size: 18),
            onTap: () {
              Navigator.pop(context);
              showCarmanSnack(
                context,
                'Correo copiado.',
                kind: SnackKind.success,
              );
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showCarmanSheet<void>(
      context: context,
      maxHeightFactor: 0.7,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeader(title: 'Ajustes'),
          ListTile(
            leading: const Icon(Icons.language_rounded, size: 19),
            title: const Text('Idioma'),
            trailing: Text(
              'Español',
              style: AppTheme.bodySm.copyWith(fontSize: 10),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined, size: 19),
            title: const Text('Tema'),
            trailing: Text(
              'Claro',
              style: AppTheme.bodySm.copyWith(fontSize: 10),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined, size: 19),
            title: const Text('Privacidad y términos'),
            trailing: const Icon(Icons.chevron_right_rounded, size: 18),
            onTap: () {
              Navigator.pop(context);
              showCarmanSnack(
                context,
                'Disponible en carman.app/legal',
                kind: SnackKind.info,
              );
            },
          ),
          if (!AppConfig.useLiveApi) ...[
            const Divider(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Demo',
                  style: AppTheme.overline.copyWith(fontSize: 8.5),
                ),
              ),
            ),
            _SheetAction(
              label: 'Pago rechazado',
              onTap: () {
                Navigator.pop(context);
                context.push('/booking/failed');
              },
            ),
            _SheetAction(
              label: 'Reserva expirada',
              onTap: () {
                Navigator.pop(context);
                context.push('/booking/expired');
              },
            ),
            _SheetAction(
              label: 'Licencia rechazada',
              onTap: () async {
                Navigator.pop(context);
                await ref
                    .read(licenseControllerProvider.notifier)
                    .simulateRejection();
                if (context.mounted) unawaited(context.push('/license'));
              },
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatarImage(
          asset: user.avatarAsset,
          url: user.avatarUrl,
          initials: user.initials,
          radius: 27,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.headlineSm.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodySm.copyWith(fontSize: 10.5),
              ),
              const SizedBox(height: 4),
              Text(
                user.roles.map((role) => role.label).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodySm.copyWith(
                  fontSize: 9.5,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => context.push('/profile/edit'),
          icon: const Icon(Icons.edit_outlined, size: 17),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _Stat(value: '${user.tripCount}', label: 'Viajes'),
          const _StatDivider(),
           _Stat(
             value: AppConfig.useLiveApi ? '—' : user.rating.toStringAsFixed(1),
             label: 'Valoración',
           ),
          const _StatDivider(),
          _Stat(
            value: user.memberSince != null
                ? AppFormatters.monthYear(user.memberSince!)
                : '2024',
            label: 'Miembro',
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.titleMd.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
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
    return Container(width: 1, height: 22, color: AppColors.borderSoft);
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.license, required this.onTap});

  final LicenseState license;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final approved = license.isApproved;
    final color = approved
        ? AppColors.success
        : license.status == LicenseStatus.pendingReview
        ? AppColors.warning
        : AppColors.error;
    final title = approved
        ? 'Conductor verificado'
        : license.status == LicenseStatus.pendingReview
        ? 'Licencia en revisión'
        : 'Verifica tu licencia';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              approved
                  ? Icons.verified_user_rounded
                  : Icons.error_outline_rounded,
              size: 17,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: AppTheme.labelMd.copyWith(fontSize: 11.5, color: color),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 17,
              color: AppColors.tertiaryText,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 1,
          ),
          leading: Icon(icon, size: 19, color: AppColors.secondaryText),
          title: Text(title, style: AppTheme.labelMd.copyWith(fontSize: 12)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailing != null) ...[trailing!, const SizedBox(width: 5)],
              const Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: AppColors.tertiaryText,
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 48, endIndent: 14),
      ],
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      title: Text(label, style: AppTheme.labelMd.copyWith(fontSize: 11.5)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 16),
    );
  }
}
