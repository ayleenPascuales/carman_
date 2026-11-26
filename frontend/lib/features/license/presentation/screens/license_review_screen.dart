import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/user_profile.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_button.dart';
import '../../../../shared/widgets/carman_card.dart';
import '../../../../shared/widgets/carman_top_bar.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../booking/application/booking_controller.dart';
import '../../application/license_controller.dart';

class LicenseReviewScreen extends ConsumerWidget {
  const LicenseReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final license = ref.watch(licenseControllerProvider);
    if (AppConfig.useLiveApi) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: CarmanTopBar(
          title: 'Estado de la licencia',
          onBack: () => context.go('/profile'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: CarmanCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(license.status.icon, color: license.status.color, size: 38),
                  const SizedBox(height: 12),
                  Text(license.status.label, style: AppTheme.headlineSm),
                  const SizedBox(height: 8),
                  Text(
                    'Este estado proviene de tu perfil. La carga segura de '
                    'documentos y los plazos de revisión aún no están disponibles.',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodySm,
                  ),
                  const SizedBox(height: 18),
                  CarmanButton(
                    label: 'Volver al perfil',
                    onPressed: () => context.go('/profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final draft = ref.watch(bookingControllerProvider).draft;
    final isApproved = license.status == LicenseStatus.approved;
    final isPending = license.status == LicenseStatus.pendingReview;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: CarmanTopBar(
        showBack: false,
        centerTitle: true,
        title: 'Carman',
        actions: [
          IconButton(
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: isApproved
                    ? AppColors.successContainer
                    : AppColors.softLavender,
                shape: BoxShape.circle,
                border: Border.all(
                  color: (isApproved ? AppColors.success : AppColors.primary)
                      .withValues(alpha: 0.18),
                  width: 3,
                ),
              ),
              child: Icon(
                isApproved
                    ? Icons.verified_user_rounded
                    : Icons.document_scanner_rounded,
                size: 38,
                color: isApproved ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: StatusBadge(
              label: isApproved
                  ? 'LICENCIA APROBADA'
                  : isPending
                  ? 'EN REVISIÓN TELEMÁTICA'
                  : 'VERIFICACIÓN PENDIENTE',
              color: isApproved ? AppColors.success : AppColors.primary,
              icon: isApproved
                  ? Icons.check_circle_rounded
                  : Icons.hourglass_top_rounded,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isApproved
                ? '¡Ya puedes conducir con Carman!'
                : 'Estamos verificando tu permiso de conducir',
            textAlign: TextAlign.center,
            style: AppTheme.headlineLg.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 7),
          Text(
            isApproved
                ? 'Tu licencia está aprobada y tu cuenta habilitada para reservar y abrir vehículos con la app.'
                : 'Nuestro equipo de seguridad y el sistema biométrico están comprobando la validez de tu documento para habilitar el desbloqueo telemático de vehículos.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMd.copyWith(
              color: AppColors.tertiaryText,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 20),
          CarmanCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _TimelineStep(
                  icon: Icons.upload_file_rounded,
                  title: 'Documento recibido',
                  subtitle: license.submittedAt != null
                      ? 'Enviado correctamente'
                      : 'Recibido por Carman',
                  state: _StepState.done,
                ),
                _TimelineStep(
                  icon: Icons.fingerprint_rounded,
                  title: 'Revisión biométrica',
                  subtitle: isApproved
                      ? 'Documento validado'
                      : 'Comprobando autenticidad y vigencia',
                  state: isApproved ? _StepState.done : _StepState.active,
                  showProgress: !isApproved,
                ),
                _TimelineStep(
                  icon: Icons.verified_user_rounded,
                  title: 'Aprobación final',
                  subtitle: isApproved
                      ? 'Licencia habilitada'
                      : 'Te notificaremos al instante',
                  state: isApproved ? _StepState.done : _StepState.pending,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CarmanCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const IconTile(icon: Icons.schedule_rounded),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plazo estimado de validación',
                        style: AppTheme.bodySm.copyWith(fontSize: 9.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isApproved
                            ? 'Completado'
                            : 'Menos de 15 minutos (generalmente inmediato)',
                        style: AppTheme.titleMd.copyWith(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                if (!isApproved)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const InfoBanner(
            title: 'Notificación al instante',
            message: 'Te enviaremos un SMS y una notificación push en cuanto tu cuenta esté aprobada para conducir.',
            icon: Icons.notifications_active_outlined,
            compact: true,
          ),
          if (draft != null) ...[
            const SizedBox(height: 12),
            CarmanCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_clock_rounded,
                    size: 20,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tu reserva se mantiene asegurada',
                          style: AppTheme.labelLg.copyWith(fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tu reserva para ${draft.vehicle.title} sigue protegida durante este proceso.',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 10,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.graphite,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.security_rounded,
                  color: AppColors.primaryFixedDim,
                  size: 20,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Cifrado biométrico de extremo a extremo · DGT compliant',
                    style: AppTheme.labelSm.copyWith(
                      color: Colors.white,
                      fontSize: 9.5,
                      letterSpacing: 0.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (isApproved)
            CarmanButton(
              label: 'Empezar a reservar',
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: () => context.go('/home'),
            )
          else if (isPending)
            CarmanButton(
              label: 'Explorar vehículos mientras tanto',
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: () => context.go('/home'),
            )
          else
            CarmanButton(
              label: 'Completar verificación',
              icon: Icons.upload_file_rounded,
              onPressed: () => context.push('/license'),
            ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => showCarmanSnack(
                context,
                'Soporte de verificación: soporte@carman.app',
                kind: SnackKind.info,
              ),
              child: const Text('¿Necesitas ayuda con la verificación?'),
            ),
          ),
        ],
      ),
    );
  }
}

enum _StepState { done, active, pending }

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
    this.showProgress = false,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _StepState state;
  final bool showProgress;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _StepState.done => AppColors.success,
      _StepState.active => AppColors.primary,
      _StepState.pending => AppColors.border,
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(
                    alpha: state == _StepState.pending ? 0.25 : 0.12,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  state == _StepState.done
                      ? Icons.check_rounded
                      : state == _StepState.active
                      ? Icons.sync_rounded
                      : icon,
                  size: 17,
                  color: state == _StepState.pending
                      ? AppColors.tertiaryText
                      : color,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.6,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: state == _StepState.done
                        ? AppColors.success.withValues(alpha: 0.35)
                        : AppColors.borderSoft,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.titleMd.copyWith(
                      fontSize: 12.5,
                      color: state == _StepState.pending
                          ? AppColors.tertiaryText
                          : AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTheme.bodySm.copyWith(fontSize: 9.5),
                  ),
                  if (showProgress) ...[
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: const LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor: AppColors.softLavender,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
