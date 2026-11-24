import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_button.dart';
import '../../../../shared/widgets/carman_text_field.dart';
import '../../../../shared/widgets/carman_top_bar.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../application/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  bool _remember = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(
      text: widget.initialEmail ?? AppConfig.demoEmail,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref.read(authControllerProvider.notifier).setRemember(_remember);
    final success = await ref
        .read(authControllerProvider.notifier)
        .login(
          email: _emailController.text,
          password: _passwordController.text,
          remember: _remember,
        );
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      context.go('/home');
    } else {
      final error = ref.read(authControllerProvider).error;
      if (error != null) {
        showCarmanSnack(context, error, kind: SnackKind.error);
      }
    }
  }

  void _useDemo() {
    setState(() {
      _emailController.text = AppConfig.demoEmail;
      _passwordController.text = AppConfig.demoPassword;
    });
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
            context.go('/welcome');
          }
        },
      ),
      body: MaxWidthContent(
        maxWidth: 500,
        padding: EdgeInsets.zero,
        child: SafeArea(
          top: false,
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bienvenido', style: AppTheme.headlineLg),
                    const SizedBox(height: 6),
                    Text(
                      'Accede a tus reservas y llave digital.',
                      style: AppTheme.bodySm.copyWith(fontSize: 12.5),
                    ),
                    const SizedBox(height: 30),
                    CarmanTextField(
                      controller: _emailController,
                      label: 'Correo',
                      hint: 'tu@correo.com',
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: Validators.email,
                      autofillHints: const [AutofillHints.email],
                    ),
                    const SizedBox(height: 14),
                    PasswordTextField(
                      controller: _passwordController,
                      label: 'Contraseña',
                      hint: 'Tu contraseña',
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Introduce tu contraseña'
                          : null,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 4,
                          ),
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _remember,
                            onChanged: (value) =>
                                setState(() => _remember = value ?? false),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _remember = !_remember),
                          child: Text(
                            'Recordarme',
                            style: AppTheme.bodySm.copyWith(
                              color: AppColors.secondaryText,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (auth.error != null) ...[
                      const SizedBox(height: 16),
                      InfoBanner(
                        title: 'No pudimos acceder',
                        message: auth.error!,
                        icon: Icons.error_outline_rounded,
                        color: AppColors.error,
                        compact: true,
                      ),
                    ],
                    const SizedBox(height: 22),
                    CarmanButton(
                      label: 'Entrar',
                      isLoading: auth.isSubmitting,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: _useDemo,
                        child: const Text('Usar acceso demo'),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Divider(),
                    const SizedBox(height: 18),
                    Center(
                      child: TextButton(
                        onPressed: () => context.push('/register'),
                        child: const Text('¿No tienes cuenta? Crear una'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
