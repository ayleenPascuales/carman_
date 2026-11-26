import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../data/models/payment_history_entry.dart';
import '../../../../providers.dart';
import '../../../../shared/widgets/carman_card.dart';
import '../../../../shared/widgets/carman_top_bar.dart';
import '../../../../shared/widgets/feedback_widgets.dart';

class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = AppConfig.useLiveApi
        ? ref.watch(paymentHistoryProvider)
        : null;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: CarmanTopBar(title: 'Historial de pagos', onBack: () => context.pop()),
      body: history == null
          ? const EmptyState(
              title: 'Solo disponible con la API',
              message: 'Los movimientos del modo demo no son pagos reales.',
            )
          : history.when(
              loading: () => const CenteredLoader(),
              error: (_, _) => ErrorView(
                message: 'No se pudo consultar el historial de pagos.',
                onRetry: () => ref.invalidate(paymentHistoryProvider),
              ),
              data: (payments) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(paymentHistoryProvider);
                  await ref.read(paymentHistoryProvider.future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(18),
                  children: [
                    Text(
                      'Hasta 100 movimientos recientes de tus reservas. '
                      'Una reserva sin movimientos no implica un cobro. '
                      'El checkout web no procesa pagos.',
                      style: AppTheme.bodySm,
                    ),
                    const SizedBox(height: 16),
                    if (payments.isEmpty)
                      const EmptyState(
                        title: 'Sin movimientos registrados',
                        message: 'No se encontraron pagos en tus reservas.',
                      ),
                    for (final payment in payments) ...[
                      _PaymentTile(payment: payment),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});
  final PaymentHistoryEntry payment;

  @override
  Widget build(BuildContext context) {
    return CarmanCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Reserva #${payment.reservationId}',
                    style: AppTheme.titleMd),
              ),
              Text(AppFormatters.money(payment.amount, precise: true),
                  style: AppTheme.titleMd),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${payment.type} · ${payment.status}'
            '${payment.date == null ? '' : ' · ${AppFormatters.shortDate(payment.date!)}'}',
            style: AppTheme.bodySm,
          ),
          if (payment.method != null)
            Text(payment.method!, style: AppTheme.bodySm),
        ],
      ),
    );
  }
}
