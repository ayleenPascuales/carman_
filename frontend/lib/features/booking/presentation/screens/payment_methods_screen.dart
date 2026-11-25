import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../data/models/booking.dart';
import '../../../../data/models/payment_method.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_button.dart';
import '../../../../shared/widgets/carman_card.dart';
import '../../../../shared/widgets/carman_image.dart';
import '../../../../shared/widgets/carman_text_field.dart';
import '../../../../shared/widgets/carman_top_bar.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/sheets.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../application/booking_controller.dart';
import '../../application/payment_controller.dart';

class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payment = ref.watch(paymentControllerProvider);
    final draft = ref.watch(bookingControllerProvider).draft;
    final selected = payment.selected;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: CarmanTopBar(title: 'Pago', onBack: () => context.pop()),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
        children: [
          if (draft != null) _ReservationSummary(draft: draft),
          if (draft != null) const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'Métodos guardados',
                style: AppTheme.headlineSm.copyWith(fontSize: 17),
              ),
              const Spacer(),
              Text(
                '${payment.methods.length} disponibles',
                style: AppTheme.bodySm.copyWith(fontSize: 10.5),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final method in payment.methods) ...[
            _MethodTile(
              method: method,
              selected: method.id == selected.id,
              onTap: () {
                ref.read(paymentControllerProvider.notifier).select(method.id);
              },
            ),
            const SizedBox(height: 9),
          ],
          const SizedBox(height: 12),
          Text(
            'Añadir nuevo método',
            style: AppTheme.headlineSm.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 10),
          CarmanCard(
            padding: const EdgeInsets.all(13),
            onTap: () => _openAddCard(context, ref),
            child: Row(
              children: [
                const IconTile(
                  icon: Icons.add_rounded,
                  background: AppColors.softLavender,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nueva tarjeta crédito / débito',
                        style: AppTheme.titleMd,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Visa, Mastercard, American Express',
                        style: AppTheme.bodySm.copyWith(fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.tertiaryText,
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          CarmanCard(
            padding: const EdgeInsets.all(13),
            onTap: () => showCarmanSnack(
              context,
              'La transferencia instantánea se habilitará con la pasarela de pagos.',
              kind: SnackKind.info,
            ),
            child: Row(
              children: [
                const IconTile(
                  icon: Icons.swap_horiz_rounded,
                  background: AppColors.surfaceContainer,
                  foreground: AppColors.secondaryText,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transferencia instantánea o Bizum',
                        style: AppTheme.titleMd,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Confirmación en 60 segundos',
                        style: AppTheme.bodySm.copyWith(fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.tertiaryText,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SaveSwitch(
            value: payment.saveForFuture,
            onChanged: (value) => ref
                .read(paymentControllerProvider.notifier)
                .setSaveForFuture(value),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 24,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (draft != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(
                        'Importe de retención y cobro',
                        style: AppTheme.bodySm.copyWith(fontSize: 10.5),
                      ),
                      const Spacer(),
                      Text(
                        AppFormatters.money(draft.pricing.total, precise: true),
                        style: AppTheme.titleMd.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              CarmanButton(
                label: 'Confirmar',
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () {
                  showCarmanSnack(
                    context,
                    '${payment.selected.displayLabel} seleccionado.',
                    kind: SnackKind.success,
                  );
                  if (context.canPop()) context.pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAddCard(BuildContext context, WidgetRef ref) async {
    final added = await showCarmanSheet<bool>(
      context: context,
      maxHeightFactor: 0.88,
      child: const AddCardSheet(),
    );
    if (added == true && context.mounted) {
      showCarmanSnack(
        context,
        'Tarjeta añadida correctamente.',
        kind: SnackKind.success,
      );
    }
  }
}

class _ReservationSummary extends StatelessWidget {
  const _ReservationSummary({required this.draft});

  final BookingDraft draft;

  @override
  Widget build(BuildContext context) {
    return CarmanCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: CarmanImage(
              draft.vehicle.primaryPhoto,
              width: 80,
              height: 62,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reserva actual',
                  style: AppTheme.bodySm.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 2),
                Text(
                  draft.vehicle.compactTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.titleMd,
                ),
                const SizedBox(height: 2),
                Text(
                  '${draft.pricing.units} ${draft.pricing.unitLabel} · ${draft.insurance.name}',
                  style: AppTheme.bodySm.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Total a pagar',
                style: AppTheme.bodySm.copyWith(fontSize: 9),
              ),
              Text(
                AppFormatters.money(draft.pricing.total, precise: true),
                style: AppTheme.titleLg.copyWith(fontSize: 15),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.softLavender.withValues(alpha: 0.4)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 34,
                decoration: BoxDecoration(
                  color: method.type == PaymentMethodType.applePay
                      ? AppColors.graphite
                      : AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  method.type.icon,
                  size: 19,
                  color: method.type == PaymentMethodType.applePay
                      ? Colors.white
                      : AppColors.secondaryText,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          method.label,
                          style: AppTheme.titleMd.copyWith(fontSize: 14),
                        ),
                        if (method.isDefault) ...[
                          const SizedBox(width: 6),
                          const BadgePill(
                            label: 'Por defecto',
                            background: AppColors.softLavender,
                            foreground: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      method.description,
                      style: AppTheme.bodySm.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              Container(
                width: 21,
                height: 21,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? AppColors.primaryViolet
                        : AppColors.border,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryViolet,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveSwitch extends StatelessWidget {
  const _SaveSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: value,
            onChanged: (next) => onChanged(next ?? false),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Guardar este método para futuros viajes',
                style: AppTheme.labelMd.copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AddCardSheet extends ConsumerStatefulWidget {
  const AddCardSheet({super.key});

  @override
  ConsumerState<AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends ConsumerState<AddCardSheet> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _holder = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();

  @override
  void dispose() {
    _number.dispose();
    _holder.dispose();
    _expiry.dispose();
    _cvv.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final success = await ref
        .read(paymentControllerProvider.notifier)
        .addCard(
          number: _number.text,
          expiry: _expiry.text,
          holder: _holder.text,
        );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      final error = ref.read(paymentControllerProvider).error;
      if (error != null) showCarmanSnack(context, error, kind: SnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payment = ref.watch(paymentControllerProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SheetHeader(
          title: 'Añadir nueva tarjeta',
          subtitle: 'Los datos se cifran y se envían directamente a la pasarela de pago.',
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  CarmanTextField(
                    controller: _number,
                    label: 'Número de tarjeta',
                    hint: '4242 4242 4242 4242',
                    prefixIcon: Icons.credit_card_rounded,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(19),
                      _CardNumberFormatter(),
                    ],
                    validator: Validators.cardNumber,
                  ),
                  const SizedBox(height: 14),
                  CarmanTextField(
                    controller: _holder,
                    label: 'Titular de la tarjeta',
                    hint: 'Como aparece en la tarjeta',
                    prefixIcon: Icons.person_outline_rounded,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    validator: (value) =>
                        Validators.required(value, label: 'El titular'),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: CarmanTextField(
                          controller: _expiry,
                          label: 'Vencimiento',
                          hint: 'MM/AA',
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                            _ExpiryFormatter(),
                          ],
                          validator: Validators.expiry,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CarmanTextField(
                          controller: _cvv,
                          label: 'CVV',
                          hint: '123',
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          obscureText: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          validator: Validators.cvv,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const InfoBanner(
                    title: 'Tarjeta de prueba',
                    message: '4242 4242 4242 4242 aprueba el pago. 4000 0000 0000 0002 simula un rechazo bancario.',
                    icon: Icons.science_outlined,
                    compact: true,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: CarmanButton(
                      label: 'Guardar tarjeta',
                      icon: Icons.lock_rounded,
                      isLoading: payment.isSaving,
                      onPressed: _submit,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Al guardar aceptas que Carman almacene un token seguro, nunca el número completo.',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodySm.copyWith(fontSize: 9.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final value = buffer.toString();
    return TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final value = digits.length > 2
        ? '${digits.substring(0, 2)}/${digits.substring(2)}'
        : digits;
    return TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}
