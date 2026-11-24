import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../data/models/admin_models.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_button.dart';
import '../../../../shared/widgets/carman_card.dart';
import '../../../../shared/widgets/carman_chips.dart';
import '../../../../shared/widgets/carman_image.dart';
import '../../../../shared/widgets/carman_text_field.dart';
import '../../../../shared/widgets/carman_top_bar.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/admin_controller.dart';

enum _AdminTab { overview, users, approvals }

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final _search = TextEditingController();
  _AdminTab _tab = _AdminTab.overview;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final state = ref.watch(adminControllerProvider);

    if (user == null || !user.isAdmin) {
      return Scaffold(
        appBar: CarmanTopBar(
          title: 'Administración',
          onBack: () => Navigator.of(context).maybePop(),
        ),
        body: const EmptyState(
          title: 'Acceso restringido',
          message: 'Esta sección es solo para administradores.',
          icon: Icons.admin_panel_settings_outlined,
        ),
      );
    }

    if (state.isLoading && state.data == null) {
      return const Scaffold(body: CenteredLoader());
    }

    final data = state.data;
    if (data == null) {
      return Scaffold(
        appBar: CarmanTopBar(title: 'Administración'),
        body: ErrorView(
          message: state.error ?? 'No pudimos cargar la administración.',
          onRetry: () => ref.read(adminControllerProvider.notifier).load(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: CarmanTopBar(
        title: 'Administración',
        onBack: () => Navigator.of(context).maybePop(),
        actions: [
          IconButton(
            onPressed: () => ref.read(adminControllerProvider.notifier).load(),
            icon: const Icon(Icons.refresh_rounded, size: 19),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
              child: SegmentedControl<_AdminTab>(
                values: _AdminTab.values,
                selected: _tab,
                labelBuilder: (tab) => switch (tab) {
                  _AdminTab.overview => 'Resumen',
                  _AdminTab.users => 'Usuarios',
                  _AdminTab.approvals => 'Aprobaciones',
                },
                onChanged: (tab) => setState(() => _tab = tab),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previousChildren, ?currentChild],
                ),
                child: switch (_tab) {
                  _AdminTab.overview => _OverviewTab(
                    key: const ValueKey('overview'),
                    data: data,
                    onApprovals: () =>
                        setState(() => _tab = _AdminTab.approvals),
                    onUsers: () => setState(() => _tab = _AdminTab.users),
                    onUser: (user) => _showUserSheet(context, user),
                  ),
                  _AdminTab.users => _UsersTab(
                    key: const ValueKey('users'),
                    users: data.users,
                    query: _query,
                    searchController: _search,
                    onQueryChanged: (value) => setState(() => _query = value),
                    onTapUser: (user) => _showUserSheet(context, user),
                  ),
                  _AdminTab.approvals => _ApprovalsTab(
                    key: const ValueKey('approvals'),
                    approvals: data.approvals,
                    actionId: state.actionId,
                    onReview: (item, approved) =>
                        _reviewApproval(context, item, approved),
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reviewApproval(
    BuildContext context,
    AdminApproval approval,
    bool approved,
  ) async {
    final success = await ref
        .read(adminControllerProvider.notifier)
        .reviewApproval(approval.id, approved);
    if (!context.mounted) return;
    showCarmanSnack(
      context,
      success
          ? approved
                ? 'Solicitud aprobada.'
                : 'Solicitud rechazada.'
          : 'No se pudo actualizar la solicitud.',
      kind: success ? SnackKind.success : SnackKind.error,
    );
  }

  Future<void> _showUserSheet(BuildContext context, AdminUser user) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  CircleAvatarImage(
                    asset: user.avatarAsset,
                    initials: user.initials,
                    radius: 24,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: AppTheme.headlineSm.copyWith(fontSize: 17),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: AppTheme.bodySm.copyWith(fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: user.status.label,
                    color: user.status.color,
                    small: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _UserSheetRow(label: 'Teléfono', value: user.phone),
              _UserSheetRow(label: 'Ciudad', value: user.city),
              _UserSheetRow(
                label: 'Registro',
                value: AppFormatters.weekdayDate(user.joinedAt),
              ),
              _UserSheetRow(label: 'Viajes', value: '${user.trips}'),
              _UserSheetRow(label: 'Roles', value: user.rolesLabel),
              const SizedBox(height: 16),
              if (user.status == AdminUserStatus.suspended)
                CarmanButton(
                  label: 'Reactivar cuenta',
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: () async {
                    final success = await ref
                        .read(adminControllerProvider.notifier)
                        .updateUserStatus(user.id, AdminUserStatus.active);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    showCarmanSnack(
                      context,
                      success ? 'Cuenta reactivada.' : 'No se pudo reactivar.',
                      kind: success ? SnackKind.success : SnackKind.error,
                    );
                  },
                )
              else
                CarmanButton(
                  label: 'Suspender cuenta',
                  variant: CarmanButtonVariant.danger,
                  icon: Icons.block_rounded,
                  onPressed: () async {
                    final success = await ref
                        .read(adminControllerProvider.notifier)
                        .updateUserStatus(user.id, AdminUserStatus.suspended);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    showCarmanSnack(
                      context,
                      success
                          ? 'Cuenta suspendida.'
                          : 'No se pudo suspender la cuenta.',
                      kind: success ? SnackKind.success : SnackKind.error,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    super.key,
    required this.data,
    required this.onApprovals,
    required this.onUsers,
    required this.onUser,
  });

  final AdminDashboardData data;
  final VoidCallback onApprovals;
  final VoidCallback onUsers;
  final ValueChanged<AdminUser> onUser;

  @override
  Widget build(BuildContext context) {
    final pending = data.approvals
        .where((item) => item.status == AdminApprovalStatus.pending)
        .toList();
    final newest = [...data.users]
      ..sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 28),
      children: [
        _StatsPanel(stats: data.stats),
        const SizedBox(height: 12),
        CarmanCard(
          padding: const EdgeInsets.all(14),
          showShadow: false,
          onTap: onApprovals,
          child: Row(
            children: [
              const IconTile(
                icon: Icons.fact_check_outlined,
                foreground: AppColors.warning,
                background: AppColors.warningContainer,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aprobaciones pendientes',
                      style: AppTheme.labelMd.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pending.isEmpty
                          ? 'Todo al día'
                          : '${pending.length} solicitudes esperando revisión',
                      style: AppTheme.bodySm.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.tertiaryText,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionHeader(
          title: 'Nuevos usuarios',
          actionLabel: 'Ver todos',
          onAction: onUsers,
        ),
        const SizedBox(height: 8),
        CarmanCard(
          padding: EdgeInsets.zero,
          showShadow: false,
          child: Column(
            children: [
              for (var index = 0; index < newest.take(4).length; index++) ...[
                _UserRow(
                  user: newest[index],
                  onTap: () => onUser(newest[index]),
                ),
                if (index < newest.take(4).length - 1)
                  const Divider(height: 1, indent: 66, endIndent: 14),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(
              Icons.shield_outlined,
              size: 14,
              color: AppColors.success,
            ),
            const SizedBox(width: 5),
            Text(
              'Sistema operativo · Carman Admin',
              style: AppTheme.bodySm.copyWith(fontSize: 9),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 13),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Usuarios registrados',
                style: AppTheme.bodySm.copyWith(fontSize: 10.5),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '+${stats.growth.toStringAsFixed(1)}%',
                  style: AppTheme.labelSm.copyWith(
                    fontSize: 8.5,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppFormatters.integer(stats.totalUsers),
            style: AppTheme.headlineLg.copyWith(
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _Metric(value: '${stats.activeDrivers}', label: 'Conductores'),
              _MetricDivider(),
              _Metric(value: '${stats.activeVehicles}', label: 'Vehículos'),
              _MetricDivider(),
              _Metric(
                value: '${stats.reservationsToday}',
                label: 'Reservas hoy',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Ingresos del mes',
                style: AppTheme.bodySm.copyWith(fontSize: 9.5),
              ),
              const Spacer(),
              Text(
                AppFormatters.money(stats.revenueMonth),
                style: AppTheme.labelMd.copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTheme.titleMd.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(label, style: AppTheme.bodySm.copyWith(fontSize: 8.5)),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 20, color: AppColors.borderSoft);
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab({
    super.key,
    required this.users,
    required this.query,
    required this.searchController,
    required this.onQueryChanged,
    required this.onTapUser,
  });

  final List<AdminUser> users;
  final String query;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<AdminUser> onTapUser;

  @override
  Widget build(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final filtered = users.where((user) {
      if (normalized.isEmpty) return true;
      return '${user.name} ${user.email} ${user.rolesLabel}'
          .toLowerCase()
          .contains(normalized);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
          child: CarmanTextField(
            controller: searchController,
            hint: 'Buscar usuario',
            prefixIcon: Icons.search_rounded,
            onChanged: onQueryChanged,
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const EmptyState(
                  title: 'Sin usuarios',
                  message: 'Prueba otra búsqueda.',
                  icon: Icons.person_search_outlined,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 66),
                  itemBuilder: (context, index) => _UserRow(
                    user: filtered[index],
                    onTap: () => onTapUser(filtered[index]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user, required this.onTap});

  final AdminUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatarImage(
              asset: user.avatarAsset,
              initials: user.initials,
              radius: 19,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.labelMd.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodySm.copyWith(fontSize: 9.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(
                  label: user.status.label,
                  color: user.status.color,
                  small: true,
                ),
                const SizedBox(height: 2),
                Text(
                  user.primaryRole.label,
                  style: AppTheme.bodySm.copyWith(fontSize: 8.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalsTab extends StatelessWidget {
  const _ApprovalsTab({
    super.key,
    required this.approvals,
    required this.actionId,
    required this.onReview,
  });

  final List<AdminApproval> approvals;
  final String? actionId;
  final void Function(AdminApproval approval, bool approved) onReview;

  @override
  Widget build(BuildContext context) {
    if (approvals.isEmpty) {
      return const EmptyState(
        title: 'Sin solicitudes',
        message: 'No hay documentos pendientes.',
        icon: Icons.fact_check_outlined,
      );
    }
    final sorted = [...approvals]
      ..sort((a, b) {
        if (a.status == AdminApprovalStatus.pending &&
            b.status != AdminApprovalStatus.pending) {
          return -1;
        }
        if (a.status != AdminApprovalStatus.pending &&
            b.status == AdminApprovalStatus.pending) {
          return 1;
        }
        return b.submittedAt.compareTo(a.submittedAt);
      });
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 2 : 1;
        final cardWidth =
            (constraints.maxWidth - 36 - (columns - 1) * 12) / columns;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 28),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final approval in sorted)
                SizedBox(
                  width: cardWidth,
                  child: _ApprovalRow(
                    approval: approval,
                    isProcessing: actionId == approval.id,
                    onApprove: () => onReview(approval, true),
                    onReject: () => onReview(approval, false),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ApprovalRow extends StatelessWidget {
  const _ApprovalRow({
    required this.approval,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  final AdminApproval approval;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final pending = approval.status == AdminApprovalStatus.pending;
    return CarmanCard(
      showShadow: false,
      padding: const EdgeInsets.all(13),
      child: Column(
        children: [
          Row(
            children: [
              IconTile(
                icon: approval.type.icon,
                foreground: pending ? AppColors.primary : AppColors.success,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      approval.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.labelMd.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${approval.subjectName} · ${approval.type.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodySm.copyWith(fontSize: 9.5),
                    ),
                  ],
                ),
              ),
              if (pending)
                Text(
                  AppFormatters.relative(approval.submittedAt),
                  style: AppTheme.bodySm.copyWith(fontSize: 8.5),
                )
              else
                StatusBadge(
                  label: approval.status == AdminApprovalStatus.approved
                      ? 'Aprobada'
                      : 'Rechazada',
                  color: approval.status == AdminApprovalStatus.approved
                      ? AppColors.success
                      : AppColors.error,
                  small: true,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  approval.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodySm.copyWith(fontSize: 9.5),
                ),
              ),
              if (pending) ...[
                _MiniAction(
                  icon: Icons.close_rounded,
                  color: AppColors.error,
                  background: AppColors.errorSurface,
                  onTap: isProcessing ? null : onReject,
                ),
                const SizedBox(width: 6),
                _MiniAction(
                  icon: Icons.check_rounded,
                  color: AppColors.success,
                  background: AppColors.successContainer,
                  onTap: isProcessing ? null : onApprove,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _UserSheetRow extends StatelessWidget {
  const _UserSheetRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTheme.bodySm.copyWith(fontSize: 10)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTheme.labelMd.copyWith(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
