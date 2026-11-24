import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_button.dart';
import '../../../../shared/widgets/carman_top_bar.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../application/auth_controller.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  int _resendSeconds = 45;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
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

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    if (_controller.text.length != 6) {
      showCarmanSnack(
        context,
        'Introduce los 6 dígitos.',
        kind: SnackKind.warning,
      );
      return;
    }
    final wasAuthenticated = ref.read(authControllerProvider).isAuthenticated;
    final success = await ref
        .read(authControllerProvider.notifier)
        .verifyOtp(_controller.text);
    if (!mounted) return;
    if (success) {
      if (wasAuthenticated && context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } else {
      final error = ref.read(authControllerProvider).error;
      if (error != null) {
        showCarmanSnack(context, error, kind: SnackKind.error);
      }
    }
  }

  Future<void> _resend() async {
    await ref.read(authControllerProvider.notifier).resendOtp();
    if (!mounted) return;
    _startTimer();
    showCarmanSnack(context, 'Código reenviado.', kind: SnackKind.success);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final phone =
        auth.user?.phone ??
        ref.read(authControllerProvider.notifier).pendingPhone;
    final displayPhone = phone != null && phone.isNotEmpty
        ? phone
        : '+57 612 849 203';
    final code = _controller.text;

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
          child: GestureDetector(
            onTap: _focusNode.requestFocus,
            behavior: HitTestBehavior.opaque,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Verifica tu teléfono', style: AppTheme.headlineLg),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      style: AppTheme.bodySm.copyWith(fontSize: 12.5),
                      children: [
                        const TextSpan(text: 'Código enviado a '),
                        TextSpan(
                          text: displayPhone,
                          style: const TextStyle(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: 0,
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          showCursor: false,
                          enableInteractiveSelection: false,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          autofillHints: const [AutofillHints.oneTimeCode],
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _verify(),
                        ),
                      ),
                      Row(
                        children: List.generate(6, (index) {
                          final hasDigit = index < code.length;
                          final isActive = index == code.length;
                          return Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              height: 54,
                              margin: EdgeInsets.only(
                                right: index == 5 ? 0 : 8,
                              ),
                              decoration: BoxDecoration(
                                color: hasDigit
                                    ? AppColors.softLavender
                                    : AppColors.surfaceSoft,
                                borderRadius: BorderRadius.circular(12),
                                border: isActive
                                    ? Border.all(
                                        color: AppColors.primaryViolet,
                                        width: 1.3,
                                      )
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  hasDigit ? code[index] : '',
                                  style: AppTheme.headlineMd.copyWith(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  if (auth.error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      auth.error!,
                      style: AppTheme.bodySm.copyWith(
                        color: AppColors.error,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        '¿No recibiste el código?',
                        style: AppTheme.bodySm.copyWith(fontSize: 10.5),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _resendSeconds == 0 ? _resend : null,
                        child: Text(
                          _resendSeconds == 0
                              ? 'Reenviar'
                              : '00:${_resendSeconds.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Demo: ${AppConfig.demoOtp}',
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 9.5,
                      color: AppColors.tertiaryText,
                    ),
                  ),
                  const SizedBox(height: 22),
                  CarmanButton(
                    label: 'Verificar',
                    isLoading: auth.isSubmitting,
                    onPressed: _verify,
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Cambiar número'),
                    ),
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
