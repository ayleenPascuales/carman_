import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_button.dart';
import '../../../../shared/widgets/carman_text_field.dart';
import '../../../../shared/widgets/carman_top_bar.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../application/auth_controller.dart';
import '../widgets/password_strength_meter.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.email});

  final String? email;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final success = await ref
        .read(authControllerProvider.notifier)
        .resetPassword(
          email: widget.email ?? 'alex.rivera@carman.es',
          password: _password.text,
        );
    if (!mounted) return;
    if (success) {
      showCarmanSnack(
        context,
        'Contraseña actualizada.',
        kind: SnackKind.success,
      );
      context.go('/login?email=${Uri.encodeComponent(widget.email ?? '')}');
    } else {
      final error = ref.read(authControllerProvider).error;
      if (error != null) {
        showCarmanSnack(context, error, kind: SnackKind.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: CarmanTopBar(
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/login');
          }
        },
      ),
      body: MaxWidthContent(
        maxWidth: 500,
        padding: EdgeInsets.zero,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nueva contraseña', style: AppTheme.headlineLg),
                  const SizedBox(height: 6),
                  Text(
                    'Elige una contraseña que no uses en otra cuenta.',
                    style: AppTheme.bodySm.copyWith(fontSize: 12.5),
                  ),
                  const SizedBox(height: 26),
                  PasswordTextField(
                    controller: _password,
                    label: 'Contraseña',
                    hint: 'Mínimo 8 caracteres',
                    textInputAction: TextInputAction.next,
                    validator: Validators.password,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  PasswordStrengthMeter(password: _password.text),
                  const SizedBox(height: 16),
                  PasswordTextField(
                    controller: _confirm,
                    label: 'Confirmar contraseña',
                    hint: 'Repite la contraseña',
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    validator: (value) =>
                        Validators.confirmPassword(value, _password.text),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 13,
                        color: AppColors.tertiaryText,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Se cerrará la sesión en otros dispositivos.',
                          style: AppTheme.bodySm.copyWith(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  CarmanButton(
                    label: 'Guardar contraseña',
                    isLoading: auth.isSubmitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
