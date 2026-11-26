import 'dart:async';

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../data/models/user_profile.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_button.dart';
import '../../../../shared/widgets/carman_card.dart';
import '../../../../shared/widgets/carman_image.dart';
import '../../../../shared/widgets/carman_text_field.dart';
import '../../../../shared/widgets/carman_top_bar.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/sheets.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/license_controller.dart';

class LicenseVerificationScreen extends ConsumerStatefulWidget {
  const LicenseVerificationScreen({super.key});

  @override
  ConsumerState<LicenseVerificationScreen> createState() =>
      _LicenseVerificationScreenState();
}

class _LicenseVerificationScreenState
    extends ConsumerState<LicenseVerificationScreen> {
  final _number = TextEditingController();
  DateTime? _expiry;
  String _type = 'B';
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final user = ref.read(authControllerProvider).user;
    _number.text = user?.document ?? '';
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _pickImage({
    required bool front,
    required ImageSource source,
  }) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1800,
        imageQuality: 82,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (front) {
        ref.read(licenseControllerProvider.notifier).setFrontImage(bytes);
      } else {
        ref.read(licenseControllerProvider.notifier).setBackImage(bytes);
      }
    } catch (_) {
      if (!mounted) return;
      showCarmanSnack(
        context,
        'No pudimos abrir la cámara o la galería. Puedes usar el documento de ejemplo.',
        kind: SnackKind.error,
      );
    }
  }

  Future<void> _pickExpiry() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _expiry ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 12)),
      helpText: 'Vencimiento de la licencia',
    );
    if (selected != null) setState(() => _expiry = selected);
  }

  Future<void> _pickType() async {
    final selected = await showCarmanSheet<String>(
      context: context,
      maxHeightFactor: 0.55,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeader(title: 'Tipo de licencia'),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              children: ['B', 'B+', 'C1', 'C2'].map((type) {
                return ListTile(
                  title: Text('Tipo $type', style: AppTheme.titleMd),
                  leading: Icon(
                    Icons.drive_eta_rounded,
                    color: type == _type
                        ? AppColors.primary
                        : AppColors.tertiaryText,
                  ),
                  trailing: type == _type
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, type),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
    if (selected != null) setState(() => _type = selected);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!ref.read(licenseControllerProvider).hasFront) {
      showCarmanSnack(
        context,
        'Carga al menos la foto frontal de tu licencia.',
        kind: SnackKind.warning,
      );
      return;
    }
    if (_number.text.trim().isEmpty) {
      showCarmanSnack(
        context,
        'Introduce el número de tu licencia.',
        kind: SnackKind.warning,
      );
      return;
    }
    if (_expiry == null) {
      showCarmanSnack(
        context,
        'Selecciona la fecha de vencimiento.',
        kind: SnackKind.warning,
      );
      return;
    }
    final success = await ref
        .read(licenseControllerProvider.notifier)
        .submit(number: _number.text.trim(), expiry: _expiry!, type: _type);
    if (!mounted) return;
    if (success) {
      unawaited(context.push('/license/review'));
    } else {
      final error = ref.read(licenseControllerProvider).error;
      if (error != null) {
        showCarmanSnack(context, error, kind: SnackKind.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final license = ref.watch(licenseControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: CarmanTopBar(
        title: 'Verificación de identidad',
        overline: license.isApproved
            ? 'Licencia aprobada'
            : license.status == LicenseStatus.pendingReview
            ? 'Revisión en curso'
            : 'Paso 2 de 3',
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/profile');
          }
        },
        actions: [
          IconButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('¿Por qué verificamos tu licencia?'),
                content: Text(
                  AppConfig.useLiveApi
                      ? 'La licencia debe estar vigente. La carga de documentos '
                        'todavía no está habilitada: no envíes fotos por otros canales.'
                      : 'La normativa exige comprobar que el conductor tiene un permiso vigente. '
                        'Esta pantalla muestra un proceso de demostración.',
                  style: AppTheme.bodyMd.copyWith(height: 1.55),
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Entendido'),
                  ),
                ],
              ),
            ),
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: license.isApproved
          ? _ApprovedState(license: license)
          : license.status == LicenseStatus.pendingReview
          ? _PendingState(license: license)
          : AppConfig.useLiveApi
          ? EmptyState(
              title: license.status == LicenseStatus.rejected
                  ? 'Licencia rechazada'
                  : license.status == LicenseStatus.expired
                      ? 'Licencia vencida'
                      : license.status == LicenseStatus.suspended
                          ? 'Licencia suspendida'
                          : 'Licencia no registrada',
              message: 'La carga segura de licencias aún no está disponible. '
                  'Tu estado se consulta desde el perfil del servidor.',
              actionLabel: 'Volver al perfil',
              onAction: () => context.go('/profile'),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 130),
              children: [
                if (license.status == LicenseStatus.rejected)
                  InfoBanner(
                    title: 'Acción requerida · Foto rechazada',
                    message: license.rejectionReason ?? 'El documento estaba borroso o caducado. Sube una foto nítida de tu permiso vigente.',
                    icon: Icons.error_outline_rounded,
                    color: AppColors.error,
                    trailing: Text(
                      'Hace 10m',
                      style: AppTheme.bodySm.copyWith(fontSize: 9.5),
                    ),
                  ),
                if (license.status == LicenseStatus.rejected)
                  const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Licencia de conducir',
                            style: AppTheme.headlineSm.copyWith(fontSize: 17),
                          ),
                        ],
                      ),
                    ),
                    const StatusBadge(
                      label: 'Pendiente',
                      color: AppColors.primary,
                      icon: Icons.hourglass_empty_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                CarmanCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _DocumentHeader(
                        number: '1',
                        title: 'Frente de la licencia',
                        status: license.status == LicenseStatus.rejected
                            ? 'Requiere reemplazo'
                            : license.hasFront
                            ? 'Cargada'
                            : 'Sin cargar',
                        isError: license.status == LicenseStatus.rejected,
                      ),
                      const SizedBox(height: 10),
                      if (license.hasFront)
                        _ImagePreview(
                          bytes: license.frontBytes,
                          asset: license.frontAsset,
                          isError: license.status == LicenseStatus.rejected,
                        )
                      else
                        _UploadArea(
                          title: 'Sube o toma una foto del frente',
                          subtitle: 'Asegúrate de que el nombre y la fecha de caducidad sean legibles.',
                          onCamera: () => _pickImage(
                            front: true,
                            source: ImageSource.camera,
                          ),
                          onGallery: () => _pickImage(
                            front: true,
                            source: ImageSource.gallery,
                          ),
                        ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Nombre y vencimiento visibles.',
                              style: AppTheme.bodySm.copyWith(
                                fontSize: 9.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                          if (license.hasFront)
                            TextButton.icon(
                              onPressed: () => _pickImage(
                                front: true,
                                source: ImageSource.gallery,
                              ),
                              icon: const Icon(
                                Icons.photo_camera_outlined,
                                size: 15,
                              ),
                              label: const Text('Cambiar imagen'),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 30),
                                textStyle: AppTheme.labelMd.copyWith(
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (!license.hasFront)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => ref
                                .read(licenseControllerProvider.notifier)
                                .useDemoFront(),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 28),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Text(
                              'Usar documento de ejemplo (demo)',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                CarmanCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _DocumentHeader(
                        number: '2',
                        title: 'Reverso de la licencia',
                        status: license.hasBack ? 'Cargada' : 'Sin cargar',
                      ),
                      const SizedBox(height: 10),
                      if (license.hasBack)
                        _ImagePreview(
                          bytes: license.backBytes,
                          asset: license.backAsset,
                        )
                      else
                        _UploadArea(
                          title: 'Sube o toma una foto del reverso',
                          subtitle: 'Asegúrate de que el código de barras y las categorías sean legibles.',
                          onCamera: () => _pickImage(
                            front: false,
                            source: ImageSource.camera,
                          ),
                          onGallery: () => _pickImage(
                            front: false,
                            source: ImageSource.gallery,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text('Datos del permiso', style: AppTheme.titleMd),
                const SizedBox(height: 9),
                CarmanTextField(
                  controller: _number,
                  label: 'Número de licencia',
                  hint: 'Ej. 1020304050',
                  prefixIcon: Icons.credit_card_rounded,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickExpiry,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.event_available_rounded,
                                size: 18,
                                color: AppColors.tertiaryText,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  _expiry == null
                                      ? 'Vencimiento'
                                      : 'Vence ${AppFormatters.shortDate(_expiry!)} ${_expiry!.year}',
                                  style: AppTheme.bodyMd.copyWith(
                                    color: _expiry == null
                                        ? AppColors.tertiaryText
                                        : AppColors.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: _pickType,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.drive_eta_rounded,
                                size: 18,
                                color: AppColors.tertiaryText,
                              ),
                              const SizedBox(width: 9),
                              Text('Tipo $_type', style: AppTheme.bodyMd),
                              const Spacer(),
                              const Icon(
                                Icons.expand_more_rounded,
                                size: 17,
                                color: AppColors.tertiaryText,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: AppColors.tertiaryText,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Datos protegidos bajo RGPD',
                      style: AppTheme.bodySm.copyWith(fontSize: 9.5),
                    ),
                    const Spacer(),
                    Text(
                      'Revisión en ~15 min',
                      style: AppTheme.labelSm.copyWith(
                        color: AppColors.primary,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
      bottomNavigationBar:
          license.isApproved || license.status == LicenseStatus.pendingReview
          ? null
          : _SubmitBar(
              completed: (license.hasFront ? 1 : 0) + (license.hasBack ? 1 : 0),
              isSubmitting: license.isSubmitting,
              onSubmit: _submit,
            ),
    );
  }
}

class _ApprovedState extends ConsumerWidget {
  const _ApprovedState({required this.license});

  final LicenseState license;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Center(
          child: Container(
            width: 82,
            height: 82,
            decoration: const BoxDecoration(
              color: AppColors.successContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              size: 40,
              color: AppColors.success,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Licencia verificada',
          textAlign: TextAlign.center,
          style: AppTheme.headlineLg.copyWith(fontSize: 26),
        ),
        const SizedBox(height: 6),
        Text(
          'Ya puedes reservar y abrir coches.',
          textAlign: TextAlign.center,
          style: AppTheme.bodySm.copyWith(height: 1.5, fontSize: 12),
        ),
        const SizedBox(height: 20),
        CarmanCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: license.frontBytes != null
                    ? Image.memory(
                        license.frontBytes!,
                        height: 145,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : CarmanImage(
                        license.frontAsset ?? AppAssets.licenseSample,
                        height: 145,
                        width: double.infinity,
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const IconTile(
                      icon: Icons.check_circle_rounded,
                      foreground: AppColors.success,
                      background: AppColors.successContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Documento aprobado',
                            style: AppTheme.titleMd.copyWith(fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                             AppConfig.useLiveApi
                                 ? 'Estado vigente según tu perfil'
                                 : license.approvedAt != null
                                     ? 'Verificado ${AppFormatters.shortDate(license.approvedAt!)}'
                                     : 'Verificado',
                            style: AppTheme.bodySm.copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const StatusBadge(
                      label: 'Activa',
                      color: AppColors.success,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CarmanButton(
          label: 'Explorar vehículos',
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: () => context.go('/home'),
        ),
        const SizedBox(height: 8),
        if (!AppConfig.useLiveApi) CarmanButton(
          label: 'Actualizar licencia',
          variant: CarmanButtonVariant.outline,
          icon: Icons.upload_file_rounded,
          onPressed: () {
            ref.read(licenseControllerProvider.notifier).startRenewal();
          },
        ),
      ],
    );
  }
}

class _PendingState extends StatelessWidget {
  const _PendingState({required this.license});

  final LicenseState license;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Center(
          child: Container(
            width: 82,
            height: 82,
            decoration: const BoxDecoration(
              color: AppColors.warningContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              size: 38,
              color: AppColors.warning,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Licencia en revisión',
          textAlign: TextAlign.center,
          style: AppTheme.headlineLg.copyWith(fontSize: 26),
        ),
        const SizedBox(height: 6),
        Text(
          AppConfig.useLiveApi
              ? 'El estado de la licencia se consulta en tu perfil.'
              : 'La revisión tarda menos de 15 minutos.',
          textAlign: TextAlign.center,
          style: AppTheme.bodySm.copyWith(height: 1.5, fontSize: 12),
        ),
        const SizedBox(height: 20),
        if (!AppConfig.useLiveApi) const InfoBanner(
          title: 'Te avisaremos al instante',
          message: 'Recibirás una notificación push y un SMS en cuanto la licencia esté aprobada.',
          icon: Icons.notifications_active_outlined,
          compact: true,
        ),
        const SizedBox(height: 16),
        CarmanButton(
          label: 'Ver estado de la revisión',
          icon: Icons.document_scanner_outlined,
          onPressed: () => context.push('/license/review'),
        ),
        const SizedBox(height: 8),
        CarmanButton(
          label: 'Explorar vehículos mientras tanto',
          variant: CarmanButtonVariant.outline,
          onPressed: () => context.go('/home'),
        ),
      ],
    );
  }
}

class _DocumentHeader extends StatelessWidget {
  const _DocumentHeader({
    required this.number,
    required this.title,
    required this.status,
    this.isError = false,
  });

  final String number;
  final String title;
  final String status;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.softLavender,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: AppTheme.labelLg.copyWith(
                color: AppColors.primary,
                fontSize: 11,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: AppTheme.titleMd.copyWith(fontSize: 13)),
        ),
        Row(
          children: [
            Icon(
              isError
                  ? Icons.cancel_outlined
                  : status == 'Cargada'
                  ? Icons.check_circle_outline_rounded
                  : Icons.hourglass_empty_rounded,
              size: 14,
              color: isError
                  ? AppColors.error
                  : status == 'Cargada'
                  ? AppColors.success
                  : AppColors.tertiaryText,
            ),
            const SizedBox(width: 4),
            Text(
              status,
              style: AppTheme.labelSm.copyWith(
                fontSize: 9,
                color: isError
                    ? AppColors.error
                    : status == 'Cargada'
                    ? AppColors.success
                    : AppColors.tertiaryText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({this.bytes, this.asset, this.isError = false});

  final Uint8List? bytes;
  final String? asset;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError ? AppColors.errorContainer : AppColors.borderSoft,
          width: isError ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (bytes != null)
            Image.memory(bytes!, fit: BoxFit.cover)
          else
            CarmanImage(asset ?? AppAssets.licenseSample),
          if (isError)
            Positioned(
              left: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Imagen rechazada: Baja nitidez',
                  style: AppTheme.labelSm.copyWith(
                    color: Colors.white,
                    fontSize: 8.5,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UploadArea extends StatelessWidget {
  const _UploadArea({
    required this.title,
    required this.subtitle,
    required this.onCamera,
    required this.onGallery,
  });

  final String title;
  final String subtitle;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryFixedDim),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.softLavender,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.drive_folder_upload_rounded,
              color: AppColors.primary,
              size: 21,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTheme.titleMd.copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTheme.bodySm.copyWith(fontSize: 9.5, height: 1.4),
          ),
          const SizedBox(height: 11),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onCamera,
                icon: const Icon(Icons.photo_camera_outlined, size: 15),
                label: const Text('Tomar foto'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: AppTheme.labelMd.copyWith(fontSize: 10.5),
                  backgroundColor: AppColors.surface,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onGallery,
                icon: const Icon(Icons.upload_file_rounded, size: 15),
                label: const Text('Cargar'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: AppTheme.labelMd.copyWith(fontSize: 10.5),
                  backgroundColor: AppColors.surface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.completed,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final int completed;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14171717),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Documentos requeridos',
                  style: AppTheme.bodySm.copyWith(fontSize: 10.5),
                ),
                const Spacer(),
                Text(
                  '$completed de 2 completados',
                  style: AppTheme.labelSm.copyWith(fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: completed / 2,
                minHeight: 5,
                backgroundColor: AppColors.surfaceContainerHigh,
              ),
            ),
            const SizedBox(height: 9),
            CarmanButton(
              label: 'Enviar licencia para validación',
              trailingIcon: Icons.arrow_forward_rounded,
              isLoading: isSubmitting,
              onPressed: onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
