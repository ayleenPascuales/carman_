import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../data/models/owner_models.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../data/repositories/owner_repository.dart';
import '../../../../providers.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_button.dart';
import '../../../../shared/widgets/carman_card.dart';
import '../../../../shared/widgets/carman_image.dart';
import '../../../../shared/widgets/carman_top_bar.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/owner_controller.dart';

enum OwnerVehiclePage { detail, edit, review }

final ownerVehicleDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) {
  ref.watch(authControllerProvider.select((auth) => auth.user?.id));
  return (ref.watch(ownerRepositoryProvider) as ApiOwnerRepository)
      .fetchVehicleDetail(id);
});

class OwnerVehicleScreen extends ConsumerStatefulWidget {
  const OwnerVehicleScreen({
    super.key, required this.vehicleId, this.page = OwnerVehiclePage.detail,
  });

  final String vehicleId;
  final OwnerVehiclePage page;

  @override
  ConsumerState<OwnerVehicleScreen> createState() => _OwnerVehicleScreenState();
}

class _OwnerVehicleScreenState extends ConsumerState<OwnerVehicleScreen> {
  final _price = TextEditingController();
  final _description = TextEditingController();
  final _reason = TextEditingController();
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _price.dispose();
    _description.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _mutate(
      Future<Map<String, dynamic>> Function(ApiOwnerRepository) action) async {
    if (_saving) return;
    setState(() { _saving = true; _error = null; });
    try {
      await action(ref.read(ownerRepositoryProvider) as ApiOwnerRepository);
      if (!mounted) return;
      ref.invalidate(ownerVehicleDetailProvider(widget.vehicleId));
      await ref.read(ownerControllerProvider.notifier).load();
      if (!mounted) return;
      if (ref.read(ownerControllerProvider).error != null) {
        setState(() => _error =
            'El cambio pudo guardarse, pero el inventario no se actualizó. Recarga antes de reintentar.');
        return;
      }
      showCarmanSnack(context, 'Estado confirmado por el servidor.',
          kind: SnackKind.success);
      if (widget.page != OwnerVehiclePage.detail) {
        context.go('/owner/vehicles/${widget.vehicleId}');
      }
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'No se pudo confirmar el resultado. Consulta el detalle antes de reintentar.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.useLiveApi) {
      return Scaffold(
        appBar: CarmanTopBar(title: 'Mi vehículo', onBack: () => context.go('/owner')),
        body: const EmptyState(
          title: 'Vista disponible en modo API',
          message: 'En demostración, el inventario se consulta desde el panel.',
        ),
      );
    }
    final detail = ref.watch(ownerVehicleDetailProvider(widget.vehicleId));
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: CarmanTopBar(
        title: switch (widget.page) {
          OwnerVehiclePage.detail => 'Mi vehículo',
          OwnerVehiclePage.edit => 'Editar vehículo',
          OwnerVehiclePage.review => 'Revisión técnica',
        },
        onBack: () => context.go(widget.page == OwnerVehiclePage.detail
            ? '/owner' : '/owner/vehicles/${widget.vehicleId}'),
      ),
      body: detail.when(
        loading: () => const CenteredLoader(),
        error: (error, _) => EmptyState(
          title: 'No pudimos consultar el vehículo',
          message: error is AppException ? error.message
              : 'Consulta tu inventario y vuelve a intentarlo.',
          actionLabel: 'Reintentar',
          onAction: () => ref.invalidate(ownerVehicleDetailProvider(widget.vehicleId)),
        ),
        data: (raw) {
          final vehicle = Vehicle.fromJson(raw);
          final status = OwnerVehicleStatus.fromApi(raw['estado']);
          final reviewStatus = '${raw['estado_solicitud_revision'] ?? 'Sin_solicitud'}';
          if (!_initialized && widget.page == OwnerVehiclePage.edit) {
            _price.text = vehicle.pricePerDay.toStringAsFixed(2);
            _description.text = vehicle.description;
            _initialized = true;
          }
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              if (_error != null) ...[
                InfoBanner(title: 'No se pudo confirmar el cambio',
                    message: _error!, color: AppColors.error),
                const SizedBox(height: 12),
              ],
              CarmanCard(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CarmanImage(vehicle.primaryPhoto,
                      width: double.infinity, height: 160),
                  const SizedBox(height: 12),
                  Text(vehicle.fullTitle, style: AppTheme.headlineSm),
                  const SizedBox(height: 8),
                  StatusBadge(label: status.label, color: status.color),
                  const SizedBox(height: 8),
                  Text('Placa ${vehicle.plate} · '
                      '${AppFormatters.money(vehicle.pricePerDay, precise: true)}/día'),
                  Text('Revisión: $reviewStatus'),
                  if (raw['motivo_solicitud_revision'] is String &&
                      (raw['motivo_solicitud_revision'] as String).isNotEmpty)
                    Text('Motivo: ${raw['motivo_solicitud_revision']}'),
                  if (raw['motivo_rechazo_revision'] is String &&
                      (raw['motivo_rechazo_revision'] as String).isNotEmpty)
                    InfoBanner(title: 'Observación de revisión',
                        message: raw['motivo_rechazo_revision'] as String,
                        color: AppColors.error),
                ],
              )),
              const SizedBox(height: 14),
              if (widget.page == OwnerVehiclePage.detail) ...[
                CarmanButton(label: 'Editar tarifa y descripción',
                    onPressed: () => context.push(
                        '/owner/vehicles/${widget.vehicleId}/edit')),
                const SizedBox(height: 10),
                CarmanButton(label: 'Solicitar revisión técnica',
                    variant: CarmanButtonVariant.outline,
                    onPressed: reviewStatus == 'Pendiente'
                        ? null : () => context.push(
                            '/owner/vehicles/${widget.vehicleId}/revision')),
                const SizedBox(height: 10),
                if (status == OwnerVehicleStatus.available ||
                    status == OwnerVehicleStatus.inactive)
                  CarmanButton(
                    label: status == OwnerVehicleStatus.available
                        ? 'Pausar publicación' : 'Reactivar publicación',
                    variant: CarmanButtonVariant.outline,
                    onPressed: _saving ? null : () => _mutate((repo) =>
                        repo.changeVehicleState(widget.vehicleId,
                            status == OwnerVehicleStatus.inactive)),
                  ),
                const SizedBox(height: 10),
                const Text('La pausa puede ser rechazada si hay reservas activas. '
                    'La revisión bloquea la disponibilidad; no supone una aprobación.'),
              ] else if (widget.page == OwnerVehiclePage.edit) ...[
                TextField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Tarifa diaria (COP)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  maxLength: 200,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                CarmanButton(label: 'Guardar cambios',
                    onPressed: _saving ? null : () {
                      final price = double.tryParse(
                          _price.text.trim().replaceAll(',', '.'));
                      if (price == null || !price.isFinite || price <= 0) {
                        setState(() => _error = 'Indica una tarifa diaria válida.');
                        return;
                      }
                      _mutate((repo) => repo.updateVehicle(widget.vehicleId,
                          pricePerDay: price,
                          description: _description.text.trim()));
                    }),
              ] else ...[
                const InfoBanner(
                  title: 'Solicitud de revisión',
                  message: 'El servidor comprueba cuándo puedes solicitarla. '
                      'Si se acepta, el vehículo deja de estar disponible '
                      'hasta que termine la revisión técnica.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reason,
                  maxLength: 500,
                  maxLines: 4,
                  decoration: const InputDecoration(
                      labelText: 'Motivo de la revisión'),
                ),
                CarmanButton(label: 'Enviar solicitud',
                    onPressed: _saving ? null : () => _mutate((repo) =>
                        repo.requestReview(widget.vehicleId, _reason.text))),
              ],
            ],
          );
        },
      ),
    );
  }
}
