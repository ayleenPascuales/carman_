import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../data/repositories/profile_repository.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_button.dart';
import '../../../../shared/widgets/carman_card.dart';
import '../../../../shared/widgets/carman_image.dart';
import '../../../../shared/widgets/carman_text_field.dart';
import '../../../../shared/widgets/carman_top_bar.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/sheets.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/profile_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  String _city = 'Cartagena';
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final user = ref.read(authControllerProvider).user;
    if (user != null) {
      _firstName.text = user.firstName;
      _lastName.text = user.lastName;
      _phone.text = user.phone;
      _city = user.city;
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final success = await ref
        .read(profileControllerProvider.notifier)
        .save(
          ProfileUpdate(
            firstName: _firstName.text,
            lastName: _lastName.text,
            phone: _phone.text,
            city: _city,
          ),
        );
    if (!mounted) return;
    if (success) {
      showCarmanSnack(context, 'Perfil actualizado.', kind: SnackKind.success);
      context.pop();
    } else {
      final error = ref.read(profileControllerProvider).error;
      if (error != null) showCarmanSnack(context, error, kind: SnackKind.error);
    }
  }

  Future<void> _pickCity() async {
    final selected = await showCarmanSheet<String>(
      context: context,
      maxHeightFactor: 0.7,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeader(title: 'Tu ciudad'),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              children: AppConfig.cities.map((city) {
                return ListTile(
                  title: Text(city, style: AppTheme.titleMd),
                  leading: Icon(
                    Icons.location_city_rounded,
                    color: city == _city
                        ? AppColors.primary
                        : AppColors.tertiaryText,
                  ),
                  trailing: city == _city
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, city),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
    if (selected != null) setState(() => _city = selected);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(profileControllerProvider).user;
    final profile = ref.watch(profileControllerProvider);
    if (user == null) {
      return const Scaffold(body: CenteredLoader());
    }
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: CarmanTopBar(title: 'Editar perfil', onBack: () => context.pop()),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatarImage(
                        asset: user.avatarAsset,
                        url: user.avatarUrl,
                        initials: user.initials,
                        radius: 42,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 27,
                          height: 27,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.photo_camera_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => showCarmanSnack(
                      context,
                      'La foto de perfil se gestiona desde tu cuenta verificada.',
                      kind: SnackKind.info,
                    ),
                    child: const Text('Cambiar foto'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const InfoBanner(
              title: 'Datos verificados',
              message: 'El correo y el documento de identidad no se pueden modificar desde la app por seguridad. Contacta con soporte si necesitas cambiarlos.',
              icon: Icons.lock_outline_rounded,
              compact: true,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: CarmanTextField(
                    controller: _firstName,
                    label: 'Nombre',
                    validator: (value) =>
                        Validators.required(value, label: 'El nombre'),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CarmanTextField(
                    controller: _lastName,
                    label: 'Apellido',
                    validator: (value) =>
                        Validators.required(value, label: 'El apellido'),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            CarmanTextField(
              controller: _phone,
              label: 'Teléfono',
              prefixIcon: Icons.phone_iphone_rounded,
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
            ),
            const SizedBox(height: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ciudad', style: AppTheme.labelMd),
                const SizedBox(height: 7),
                InkWell(
                  onTap: _pickCity,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_city_rounded,
                          size: 19,
                          color: AppColors.tertiaryText,
                        ),
                        const SizedBox(width: 10),
                        Text(_city, style: AppTheme.bodyMd),
                        const Spacer(),
                        const Icon(
                          Icons.expand_more_rounded,
                          size: 19,
                          color: AppColors.tertiaryText,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            CarmanCard(
              showShadow: false,
              padding: const EdgeInsets.all(13),
              child: Column(
                children: [
                  _ReadOnlyField(
                    icon: Icons.mail_outline_rounded,
                    label: 'Correo electrónico',
                    value: user.email,
                    verified: user.isEmailVerified,
                  ),
                  const Divider(height: 18),
                  _ReadOnlyField(
                    icon: Icons.badge_outlined,
                    label: 'Documento',
                    value: user.document.isEmpty
                        ? 'Por completar'
                        : user.document,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            CarmanButton(
              label: 'Guardar cambios',
              icon: Icons.check_rounded,
              isLoading: profile.isSaving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.icon,
    required this.label,
    required this.value,
    this.verified = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.tertiaryText),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTheme.bodySm.copyWith(fontSize: 9.5)),
              const SizedBox(height: 2),
              Text(value, style: AppTheme.labelMd.copyWith(fontSize: 11.5)),
            ],
          ),
        ),
        if (verified)
          const Icon(
            Icons.verified_rounded,
            size: 16,
            color: AppColors.success,
          ),
      ],
    );
  }
}
