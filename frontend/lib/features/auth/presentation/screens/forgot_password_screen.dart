import 'dart:async';

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

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;
  int _resendSeconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _email.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  Future<void> _send({bool resend = false}) async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final success = await ref
        .read(authControllerProvider.notifier)
        .requestPasswordReset(_email.text.trim());
    if (!mounted) return;
    if (success) {
      setState(() => _sent = true);
      _startTimer();
      if (resend) {
        showCarmanSnack(context, 'Enlace reenviado.', kind: SnackKind.success);
      }
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
            child: _sent ? _buildSent(context) : _buildForm(auth),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(AuthState auth) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recuperar acceso', style: AppTheme.headlineLg),
          const SizedBox(height: 6),
          Text(
            'Te enviaremos un enlace seguro a tu correo.',
            style: AppTheme.bodySm.copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 28),
          CarmanTextField(
            controller: _email,
            label: 'Correo electrónico',
            hint: 'tu@correo.com',
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: Validators.email,
          ),
          if (auth.error != null) ...[
            const SizedBox(height: 14),
            InfoBanner(
              title: 'No pudimos enviar el enlace',
              message: auth.error!,
              color: AppColors.error,
              icon: Icons.error_outline_rounded,
              compact: true,
            ),
          ],
          const SizedBox(height: 24),
          CarmanButton(
            label: 'Enviar enlace',
            icon: Icons.arrow_forward_rounded,
            isLoading: auth.isSubmitting,
            onPressed: _send,
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Volver'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: AppColors.softLavender,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            color: AppColors.primary,
            size: 23,
          ),
        ),
        const SizedBox(height: 18),
        Text('Revisa tu correo', style: AppTheme.headlineLg),
        const SizedBox(height: 6),
        Text(
          _email.text.trim(),
          style: AppTheme.bodySm.copyWith(fontSize: 12.5),
        ),
        if (AppConfig.useLiveApi) ...[
          const SizedBox(height: 8),
          Text(
            'Si existe una cuenta, abre el enlace recibido en tu correo. '
            'Por seguridad, no se puede cambiar la contraseña solo desde esta pantalla.',
            style: AppTheme.bodySm,
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Text('¿No llegó?', style: AppTheme.bodySm.copyWith(fontSize: 11.5)),
            const Spacer(),
            TextButton(
              onPressed: _resendSeconds == 0 ? () => _send(resend: true) : null,
              child: Text(
                _resendSeconds == 0
                    ? 'Reenviar'
                    : 'Reenviar en 00:${_resendSeconds.toString().padLeft(2, '0')}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (!AppConfig.useLiveApi) CarmanButton(
          label: 'Abrir enlace de recuperación',
          icon: Icons.open_in_new_rounded,
          onPressed: () => context.push(
            '/reset-password?email=${Uri.encodeComponent(_email.text.trim())}',
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Volver a iniciar sesión'),
          ),
        ),
      ],
    );
  }
}
