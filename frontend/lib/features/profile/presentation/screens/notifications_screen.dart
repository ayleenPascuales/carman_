import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_top_bar.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../notifications/application/notifications_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: CarmanTopBar(
        title: 'Notificaciones',
        onBack: () => context.pop(),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () async {
                try {
                  await ref.read(notificationsControllerProvider.notifier).markAllRead();
                } catch (_) {
                  if (context.mounted) {
                    showCarmanSnack(context, 'No se pudo marcar como leído. Inténtalo de nuevo.',
                        kind: SnackKind.error);
                  }
                }
              },
              child: const Text('Leer todo'),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () =>
            ref.read(notificationsControllerProvider.notifier).refresh(),
        child: state.isLoading && state.items.isEmpty
            ? const CenteredLoader()
            : state.items.isEmpty
            ? const EmptyState(
                title: 'Sin notificaciones',
                message: 'Aquí verás tus reservas y mensajes.',
                icon: Icons.notifications_none_rounded,
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
                itemCount: state.items.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 48),
                itemBuilder: (context, index) {
                  final item = state.items[index];
                  return InkWell(
                    onTap: () async {
                      try {
                        await ref.read(notificationsControllerProvider.notifier)
                            .markRead(item.id);
                      } catch (_) {
                        if (context.mounted) {
                          showCarmanSnack(context, 'No se pudo marcar como leído.',
                              kind: SnackKind.error);
                        }
                      }
                      if (!context.mounted) return;
                      if (item.actionRoute != null) {
                        if (item.actionRoute == '/trips') {
                          context.go('/trips');
                        } else {
                          unawaited(context.push(item.actionRoute!));
                        }
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: item.kind.color.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              item.kind.icon,
                              size: 16,
                              color: item.kind.color,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTheme.labelMd.copyWith(
                                          fontSize: 12,
                                          fontWeight: item.isRead
                                              ? FontWeight.w600
                                              : FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      AppFormatters.relative(item.createdAt),
                                      style: AppTheme.bodySm.copyWith(
                                        fontSize: 8.5,
                                      ),
                                    ),
                                    if (!item.isRead) ...[
                                      const SizedBox(width: 5),
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primaryViolet,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.bodySm.copyWith(
                                    fontSize: 10.5,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
