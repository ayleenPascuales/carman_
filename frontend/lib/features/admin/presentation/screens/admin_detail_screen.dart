import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/admin_models.dart';
import '../../../../data/repositories/admin_repository.dart';
import '../../../../providers.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_button.dart';
import '../../../../shared/widgets/carman_card.dart';
import '../../../../shared/widgets/carman_top_bar.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/admin_controller.dart';

final adminUserDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) {
      ref.watch(authControllerProvider.select((auth) => auth.user?.id));
      return (ref.watch(adminRepositoryProvider) as ApiAdminRepository)
          .fetchUser(id);
    });

final adminRevisionDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) {
      ref.watch(authControllerProvider.select((auth) => auth.user?.id));
      return (ref.watch(adminRepositoryProvider) as ApiAdminRepository)
          .fetchRevision(id);
    });

class AdminDetailScreen extends ConsumerStatefulWidget {
  const AdminDetailScreen({
    super.key,
    required this.id,
    required this.isRevision,
  });

  final String id;
  final bool isRevision;

  @override
  ConsumerState<AdminDetailScreen> createState() => _AdminDetailScreenState();
}

class _AdminDetailScreenState extends ConsumerState<AdminDetailScreen> {
  final _reason = TextEditingController();
  final _technician = TextEditingController();
  final _document = TextEditingController();
  final _observations = TextEditingController();
  final _mileage = TextEditingController();
  bool _maintenance = false;
  bool _keepInactive = false;
  bool _working = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    _technician.dispose();
    _document.dispose();
    _observations.dispose();
    _mileage.dispose();
    super.dispose();
  }

  Future<void> _act(Future<bool> Function() action) async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final success = await action();
      if (!mounted) return;
      ref.invalidate(
        widget.isRevision
            ? adminRevisionDetailProvider(widget.id)
            : adminUserDetailProvider(widget.id),
      );
      if (!success) {
        setState(
          () => _error = ref.read(adminControllerProvider).error ?? 'El resultado no se confirmó. Actualiza el detalle antes de reintentar.',
        );
      } else {
        showCarmanSnack(
          context,
          'Cambio confirmado por el servidor.',
          kind: SnackKind.success,
        );
      }
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo confirmar el resultado. Consulta el detalle antes de repetir.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _finalize() {
    final name = _technician.text.trim();
    final document = _document.text.trim();
    final notes = _observations.text.trim();
    final mileage = _mileage.text.trim().replaceAll(',', '.');
    final number = mileage.isEmpty ? null : double.tryParse(mileage);
    if (name.isEmpty ||
        name.length > 100 ||
        document.isEmpty ||
        document.length > 20 ||
        notes.isEmpty ||
        notes.length > 200 ||
        mileage.isNotEmpty &&
            (number == null || !number.isFinite || number < 0)) {
      setState(
        () => _error =
            'Indica técnico (máx. 100), documento (máx. 20), '
            'observaciones (máx. 200) y kilometraje válido si lo conoces.',
      );
      return;
    }
    final report = <String, dynamic>{
      'nombreTecnico': name,
      'documentoTecnico': document,
      'observaciones': notes,
      'necesitaMantenimiento': _maintenance,
      'estadoFinal': _maintenance || _keepInactive ? 'inactivo' : 'Activo',
    };
    if (number != null) report['kilometraje'] = number;
    _act(
      () => ref
          .read(adminControllerProvider.notifier)
          .finalizeReview(widget.id, report),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (!AppConfig.useLiveApi || user?.isAdmin != true) {
      return Scaffold(
        appBar: CarmanTopBar(title: 'Administración'),
        body: const EmptyState(
          title: 'Acceso restringido',
          message: 'Solo administradores autenticados en modo API.',
        ),
      );
    }
    final detail = widget.isRevision
        ? ref.watch(adminRevisionDetailProvider(widget.id))
        : ref.watch(adminUserDetailProvider(widget.id));
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: CarmanTopBar(
        title: widget.isRevision ? 'Revisión técnica' : 'Cuenta de usuario',
        onBack: () => context.go('/admin'),
      ),
      body: detail.when(
        loading: () => const CenteredLoader(),
        error: (error, _) => ErrorView(
          message: error is AppException
              ? error.message
              : 'No se pudo consultar el detalle.',
          onRetry: () => ref.invalidate(
            widget.isRevision
                ? adminRevisionDetailProvider(widget.id)
                : adminUserDetailProvider(widget.id),
          ),
        ),
        data: (raw) => ListView(
          padding: const EdgeInsets.all(18),
          children: [
            if (_error != null) ...[
              InfoBanner(
                title: 'Acción no confirmada',
                message: _error!,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
            ],
            if (widget.isRevision) ..._revision(raw) else ..._user(raw),
          ],
        ),
      ),
    );
  }

  List<Widget> _user(Map<String, dynamic> raw) {
    final status = AdminUserStatus.fromApi(raw['estado']);
    final roles = raw['roles'];
    final isAdmin =
        roles is Map<String, dynamic> && roles['administrador'] == true;
    return [
      CarmanCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${raw['nombre'] ?? ''} ${raw['apellido'] ?? ''}'.trim(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('${raw['email'] ?? ''}'),
            const SizedBox(height: 8),
            StatusBadge(label: status.label, color: status.color),
            if (isAdmin)
              const Text(
                'Cuenta administrativa: no suspender desde este panel.',
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (!isAdmin && status == AdminUserStatus.active)
        CarmanButton(
          label: 'Suspender cuenta',
          variant: CarmanButtonVariant.danger,
          onPressed: _working
              ? null
              : () async {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: '¿Suspender esta cuenta?',
                    message:
                        'La persona no podrá utilizar Carman mientras '
                        'permanezca suspendida.',
                    confirmLabel: 'Suspender',
                    destructive: true,
                    icon: Icons.block_rounded,
                  );
                  if (!confirmed || !mounted) return;
                  await _act(
                    () => ref
                        .read(adminControllerProvider.notifier)
                        .updateUserStatus(widget.id, AdminUserStatus.suspended),
                  );
                },
        ),
      if (!isAdmin && status == AdminUserStatus.suspended)
        CarmanButton(
          label: 'Reactivar cuenta',
          onPressed: _working
              ? null
              : () => _act(
                  () => ref
                      .read(adminControllerProvider.notifier)
                      .updateUserStatus(widget.id, AdminUserStatus.active),
                ),
        ),
    ];
  }

  List<Widget> _revision(Map<String, dynamic> raw) {
    final status = '${raw['estado_solicitud_revision']}';
    return [
      CarmanCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${raw['marca'] ?? ''} ${raw['modelo'] ?? ''}'.trim(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('Vehículo #${widget.id} · Placa ${raw['placa'] ?? '—'}'),
            Text(
              'Propietario: ${raw['nombrePropietario'] ?? ''} '
              '${raw['apellidoPropietario'] ?? ''}',
            ),
            const SizedBox(height: 8),
            Text('Solicitud: $status'),
            Text(
              'Motivo: ${raw['motivo_solicitud_revision'] ?? 'No indicado'}',
            ),
            if (raw['motivo_rechazo_revision'] != null)
              Text('Rechazo: ${raw['motivo_rechazo_revision']}'),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (status == 'Pendiente') ...[
        const InfoBanner(
          title: 'Revisión del vehículo',
          message:
              'Aceptar no aprueba una licencia ni finaliza la inspección. '
              'El vehículo queda en mantenimiento.',
        ),
        const SizedBox(height: 12),
        CarmanButton(
          label: 'Aceptar solicitud',
          onPressed: _working
              ? null
              : () => _act(
                  () => ref
                      .read(adminControllerProvider.notifier)
                      .reviewApproval(widget.id, true),
                ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _reason,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Motivo del rechazo'),
        ),
        CarmanButton(
          label: 'Rechazar solicitud',
          variant: CarmanButtonVariant.danger,
          onPressed: _working
              ? null
              : () {
                  if (_reason.text.trim().isEmpty) {
                    setState(() => _error = 'Escribe el motivo del rechazo.');
                    return;
                  }
                  _act(
                    () => ref
                        .read(adminControllerProvider.notifier)
                        .reviewApproval(widget.id, false, reason: _reason.text),
                  );
                },
        ),
      ],
      if (status == 'Aprobada') ...[
        const InfoBanner(
          title: 'Informe técnico',
          message:
              'Registra los datos reales del técnico. Finalizar '
              'no acredita automáticamente ningún pago ni licencia.',
        ),
        TextField(
          controller: _technician,
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'Nombre del técnico'),
        ),
        TextField(
          controller: _document,
          maxLength: 20,
          decoration: const InputDecoration(labelText: 'Documento del técnico'),
        ),
        TextField(
          controller: _mileage,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Kilometraje (opcional)',
          ),
        ),
        TextField(
          controller: _observations,
          maxLength: 200,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Observaciones técnicas',
          ),
        ),
        SwitchListTile(
          title: const Text('Necesita mantenimiento'),
          value: _maintenance,
          onChanged: _working
              ? null
              : (value) => setState(() => _maintenance = value),
        ),
        if (!_maintenance)
          CheckboxListTile(
            title: const Text('Dejar vehículo inactivo'),
            value: _keepInactive,
            onChanged: _working
                ? null
                : (value) => setState(() => _keepInactive = value ?? false),
          ),
        CarmanButton(
          label: 'Finalizar revisión',
          onPressed: _working ? null : _finalize,
        ),
      ],
    ];
  }
}
