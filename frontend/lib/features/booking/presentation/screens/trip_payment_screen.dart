import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../data/repositories/api_trip_payment_repository.dart';
import '../../../../providers.dart';
import '../../../../shared/widgets/carman_button.dart';
import '../../../../shared/widgets/carman_card.dart';
import '../../../../shared/widgets/carman_top_bar.dart';
import '../../../../shared/widgets/feedback_widgets.dart';

class TripPaymentScreen extends ConsumerStatefulWidget {
  const TripPaymentScreen({super.key, required this.reservationId});

  final String reservationId;

  @override
  ConsumerState<TripPaymentScreen> createState() => _TripPaymentScreenState();
}

class _TripPaymentScreenState extends ConsumerState<TripPaymentScreen> {
  TripOrder? _order;
  bool _loading = true;
  bool _busy = false;
  bool _orderMissing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _order = null;
      _orderMissing = false;
    });
    try {
      final order = await ref.read(tripPaymentRepositoryProvider)
          .fetchOrder(widget.reservationId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _orderMissing = false;
        _loading = false;
      });
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _orderMissing = error.code == 'http_404';
        _error = error.message;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudo consultar el estado de la orden.';
        });
      }
    }
  }

  Future<void> _createOrder() async {
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(tripPaymentRepositoryProvider)
          .createOrder(widget.reservationId);
      if (mounted) await _refresh();
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Consulta de nuevo el estado antes de repetir la solicitud.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkout() async {
    final order = _order;
    if (order == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      final url = await ref.read(tripPaymentRepositoryProvider)
          .startCheckout(order.id);
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (!opened) {
        setState(() => _error = 'No se pudo abrir el checkout de Wompi.');
      }
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'El checkout no se abrió. Consulta la orden antes de reintentar.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: CarmanTopBar(
        title: 'Orden y saldo',
        onBack: () => context.go('/trip/${widget.reservationId}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (_error != null) ...[
              InfoBanner(
                title: 'No se pudo actualizar el pago',
                message: _error!,
                icon: Icons.error_outline_rounded,
                compact: true,
              ),
              const SizedBox(height: 12),
            ],
            if (order != null) ...[
              CarmanCard(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Orden #${order.id} · ${order.status}'),
                  const SizedBox(height: 10),
                  KeyValueRow(label: 'Total de la orden',
                      value: AppFormatters.money(order.total, precise: true)),
                  KeyValueRow(label: 'Aprobado por el servidor',
                      value: AppFormatters.money(order.approved, precise: true)),
                  KeyValueRow(label: 'Saldo pendiente',
                      value: AppFormatters.money(order.balance, precise: true)),
                  Text(order.inProgress > 0
                      ? 'Hay ${order.inProgress} pago(s) pendiente(s) de confirmación.'
                      : order.advanceApproved > 0
                          ? 'Anticipo aprobado.'
                          : 'El anticipo todavía no está aprobado.'),
                ],
              )),
              const SizedBox(height: 12),
              if (order.balance > 0 && order.status == 'Activa' &&
                  (order.reservationStatus == 'Confirmada' ||
                      order.reservationStatus == 'EnCurso'))
                CarmanButton(
                  label: order.advanceApproved > 0
                      ? 'Abrir checkout Sandbox' : 'Pagar anticipo (Sandbox)',
                  onPressed: _busy ? null : _checkout,
                ),
            ] else if (_orderMissing) ...[
              const InfoBanner(
                title: 'Aún no hay orden',
                message: 'Solo una reserva confirmada puede generar una orden.',
                icon: Icons.info_outline_rounded,
              ),
              const SizedBox(height: 12),
              CarmanButton(label: 'Generar orden',
                  onPressed: _busy ? null : _createOrder),
            ],
            const SizedBox(height: 14),
            CarmanButton(
              label: 'Consultar estado en el servidor',
              variant: CarmanButtonVariant.outline,
              onPressed: _busy ? null : _refresh,
            ),
            const SizedBox(height: 12),
            const Text(
              'La vuelta del checkout no confirma el pago. '
              'Solo el estado aprobado por el servidor permite continuar. '
              'Los pagos están disponibles únicamente en Wompi Sandbox.',
            ),
          ],
        ],
      ),
    );
  }
}
