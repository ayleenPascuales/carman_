import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../data/models/user_profile.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_button.dart';
import '../../../../shared/widgets/carman_chips.dart';
import '../../../../shared/widgets/carman_text_field.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/sheets.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../application/auth_controller.dart';
import '../widgets/password_strength_meter.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController(text: '+57 ');
  final _document = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _licenseNumber = TextEditingController();
  String _city = 'Cartagena';
  DateTime? _birthDate;
  DateTime? _licenseExpiry;
  String _licenseType = 'B';
  UserRole _role = UserRole.client;
  bool _terms = false;
  int _step = 0;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _document.dispose();
    _password.dispose();
    _confirm.dispose();
    _licenseNumber.dispose();
    super.dispose();
  }

  bool get _needsLicense => _role != UserRole.client;

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_step == 0) {
      if (_birthDate == null) {
        showCarmanSnack(
          context,
          'Selecciona tu fecha de nacimiento.',
          kind: SnackKind.warning,
        );
        return;
      }
      final age = _age(_birthDate!);
      if (age < 18) {
        showCarmanSnack(
          context,
          'Debes tener al menos 18 años para crear una cuenta.',
          kind: SnackKind.error,
        );
        return;
      }
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      if (!_terms) {
        showCarmanSnack(
          context,
          'Acepta los términos y la política de privacidad para continuar.',
          kind: SnackKind.warning,
        );
        return;
      }
      setState(() => _step = 2);
      return;
    }
    if (_needsLicense) {
      if (_licenseNumber.text.trim().isEmpty) {
        showCarmanSnack(
          context,
          'Introduce el número de tu licencia.',
          kind: SnackKind.warning,
        );
        return;
      }
      if (_licenseExpiry == null) {
        showCarmanSnack(
          context,
          'Selecciona la fecha de vencimiento.',
          kind: SnackKind.warning,
        );
        return;
      }
      if (_licenseExpiry!.isBefore(DateTime.now())) {
        showCarmanSnack(
          context,
          'Tu licencia está vencida.',
          kind: SnackKind.error,
        );
        return;
      }
    }
    await _submit();
  }

  Future<void> _submit() async {
    final success = await ref
        .read(authControllerProvider.notifier)
        .register(
          RegistrationRequest(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.replaceAll(RegExp(r'[^\d+]'), ''),
            password: _password.text,
            city: _city,
            document: _document.text.trim(),
            birthDate: _birthDate!,
            role: _role,
            licenseNumber: _needsLicense ? _licenseNumber.text.trim() : null,
            licenseExpiry: _needsLicense ? _licenseExpiry : null,
            licenseType: _licenseType,
          ),
        );
    if (!mounted) return;
    if (success) {
      unawaited(context.push('/verify-otp'));
    } else {
      final error = ref.read(authControllerProvider).error;
      if (error != null) {
        showCarmanSnack(context, error, kind: SnackKind.error);
      }
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step -= 1);
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/welcome');
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Fecha de nacimiento',
    );
    if (selected != null) setState(() => _birthDate = selected);
  }

  Future<void> _pickLicenseExpiry() async {
    final selected = await showDatePicker(
      context: context,
      initialDate:
          _licenseExpiry ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      helpText: 'Vencimiento de la licencia',
    );
    if (selected != null) setState(() => _licenseExpiry = selected);
  }

  int _age(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          onPressed: _back,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const SizedBox.shrink(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Center(child: StepDots(count: 3, current: _step)),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: MaxWidthContent(
        maxWidth: 560,
        padding: EdgeInsets.zero,
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    behavior: HitTestBehavior.opaque,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.04, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: _step == 0
                              ? _buildPersonalStep()
                              : _step == 1
                              ? _buildSecurityStep()
                              : _buildRoleStep(),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
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
                        CarmanButton(
                          label: _step == 2 ? 'Crear mi cuenta' : 'Continuar',
                          trailingIcon: _step == 2
                              ? Icons.arrow_forward_rounded
                              : Icons.arrow_forward_rounded,
                          isLoading: auth.isSubmitting,
                          onPressed: _next,
                        ),
                        if (_step == 0) ...[
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: () => context.push('/login'),
                            child: const Text(
                              '¿Ya tienes cuenta? Inicia sesión',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Crea tu cuenta', style: AppTheme.headlineLg),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: CarmanTextField(
                controller: _firstName,
                label: 'Nombre',
                hint: 'Carlos',
                prefixIcon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (value) =>
                    Validators.required(value, label: 'El nombre'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CarmanTextField(
                controller: _lastName,
                label: 'Apellido',
                hint: 'Soto',
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (value) =>
                    Validators.required(value, label: 'El apellido'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        CarmanTextField(
          controller: _email,
          label: 'Correo electrónico',
          hint: 'carlos.soto@gmail.com',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: Validators.email,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 14),
        CarmanTextField(
          controller: _document,
          label: 'Documento de identidad',
          hint: '1020304050',
          prefixIcon: Icons.badge_outlined,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(12),
          ],
          validator: Validators.document,
        ),
        const SizedBox(height: 14),
        CarmanTextField(
          controller: _phone,
          label: 'Teléfono móvil',
          hint: '+57 300 123 4567',
          prefixIcon: Icons.phone_iphone_rounded,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d+\s]')),
            LengthLimitingTextInputFormatter(17),
          ],
          validator: (value) {
            final error = Validators.phone(value);
            if (error != null) return error;
            if (AppConfig.useLiveApi &&
                !RegExp(r'^\+[1-9]\d{7,14}$')
                    .hasMatch(value!.replaceAll(RegExp(r'\s'), ''))) {
              return 'Incluye indicativo internacional, por ejemplo +573001234567';
            }
            return null;
          },
          helper: 'Te enviaremos un código SMS para verificar el número.',
        ),
        const SizedBox(height: 14),
        _SelectField(
          label: 'Ciudad',
          icon: Icons.location_city_rounded,
          value: _city,
          onTap: _pickCity,
        ),
        const SizedBox(height: 14),
        _SelectField(
          label: 'Fecha de nacimiento',
          icon: Icons.cake_outlined,
          value: _birthDate == null
              ? 'Selecciona tu fecha'
              : '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}',
          onTap: _pickBirthDate,
        ),
      ],
    );
  }

  Widget _buildSecurityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Seguridad', style: AppTheme.headlineLg),
        const SizedBox(height: 18),
        PasswordTextField(
          controller: _password,
          label: 'Crear contraseña segura',
          hint: 'Mínimo 8 caracteres',
          textInputAction: TextInputAction.next,
          validator: Validators.password,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        PasswordStrengthMeter(password: _password.text),
        const SizedBox(height: 14),
        PasswordTextField(
          controller: _confirm,
          label: 'Confirmar contraseña',
          hint: 'Repite tu contraseña',
          textInputAction: TextInputAction.done,
          validator: (value) =>
              Validators.confirmPassword(value, _password.text),
        ),
        const SizedBox(height: 18),
        InkWell(
          onTap: () => setState(() => _terms = !_terms),
          borderRadius: BorderRadius.circular(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: _terms,
                  onChanged: (value) => setState(() => _terms = value ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 11,
                      height: 1.55,
                      color: AppColors.secondaryText,
                    ),
                    children: [
                      const TextSpan(text: 'Acepto los '),
                      TextSpan(
                        text: 'Términos del Servicio',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: ' y la '),
                      TextSpan(
                        text: 'política de privacidad',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: ' de Carman.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: _showTerms,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 30),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Leer términos y privacidad'),
        ),
      ],
    );
  }

  Widget _buildRoleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tu perfil', style: AppTheme.headlineLg),
        const SizedBox(height: 16),
        SelectPill(
          label: 'Cliente',
          subtitle: 'Alquila coches',
          icon: Icons.person_outline_rounded,
          selected: _role == UserRole.client,
          onTap: () => setState(() => _role = UserRole.client),
        ),
        const SizedBox(height: 9),
        SelectPill(
          label: 'Propietario',
          subtitle: 'Publica tus coches',
          icon: Icons.car_rental_rounded,
          selected: _role == UserRole.owner,
          onTap: () => setState(() => _role = UserRole.owner),
        ),
        const SizedBox(height: 9),
        SelectPill(
          label: 'Conductor',
          subtitle: 'Conduce con Carman',
          icon: Icons.badge_outlined,
          selected: _role == UserRole.driver,
          onTap: () => setState(() => _role = UserRole.driver),
        ),
        if (_needsLicense) ...[
          const SizedBox(height: 20),
          Text('Licencia de conducción', style: AppTheme.titleMd),
          const SizedBox(height: 5),
          Text(
            'Necesaria para conductores y propietarios que entregan vehículos.',
            style: AppTheme.bodySm.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 12),
          CarmanTextField(
            controller: _licenseNumber,
            label: 'Número de licencia',
            hint: 'Ej. 1020304050',
            prefixIcon: Icons.credit_card_rounded,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            validator: (value) => _needsLicense
                ? Validators.required(value, label: 'La licencia')
                : null,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SelectField(
                  label: 'Vencimiento',
                  icon: Icons.event_available_rounded,
                  value: _licenseExpiry == null
                      ? 'Selecciona la fecha'
                      : '${_licenseExpiry!.day}/${_licenseExpiry!.month}/${_licenseExpiry!.year}',
                  onTap: _pickLicenseExpiry,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SelectField(
                  label: 'Tipo de licencia',
                  icon: Icons.drive_eta_rounded,
                  value: 'Tipo $_licenseType',
                  onTap: _pickLicenseType,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 13,
              color: AppColors.tertiaryText,
            ),
            const SizedBox(width: 5),
            Text(
              'Datos protegidos',
              style: AppTheme.bodySm.copyWith(fontSize: 9.5),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickCity() async {
    final city = await showCarmanSheet<String>(
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
                final selected = city == _city;
                return ListTile(
                  title: Text(city, style: AppTheme.titleMd),
                  leading: Icon(
                    Icons.location_city_rounded,
                    color: selected
                        ? AppColors.primary
                        : AppColors.tertiaryText,
                  ),
                  trailing: selected
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
    if (city != null) setState(() => _city = city);
  }

  Future<void> _pickLicenseType() async {
    final type = await showCarmanSheet<String>(
      context: context,
      maxHeightFactor: 0.55,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeader(
            title: 'Tipo de licencia',
            subtitle: 'Selecciona la categoría que figura en tu documento.',
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              children: ['B', 'B+', 'C1', 'C2'].map((type) {
                final selected = type == _licenseType;
                return ListTile(
                  title: Text('Tipo $type', style: AppTheme.titleMd),
                  subtitle: Text(
                    type == 'B'
                        ? 'Vehículos particulares hasta 3.500 kg'
                        : 'Vehículos de mayor categoría',
                    style: AppTheme.bodySm,
                  ),
                  leading: Icon(
                    Icons.drive_eta_rounded,
                    color: selected
                        ? AppColors.primary
                        : AppColors.tertiaryText,
                  ),
                  trailing: selected
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
    if (type != null) setState(() => _licenseType = type);
  }

  Future<void> _showTerms() {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Términos y privacidad'),
        content: SingleChildScrollView(
          child: Text(
            'Carman conecta clientes, conductores y propietarios de vehículos. '
            'Al crear una cuenta confirmas que la información proporcionada es veraz, '
            'que eres mayor de 18 años y que aceptas las condiciones de uso, la política '
            'de cancelación y el tratamiento de datos necesario para gestionar reservas, '
            'verificar licencias y procesar pagos.\n\n'
            'Tus documentos se cifran en tránsito y solo se comparten con el equipo de '
            'verificación. Puedes solicitar la eliminación de tu cuenta desde soporte.',
            style: AppTheme.bodyMd.copyWith(height: 1.55),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _terms = true);
            },
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.labelMd),
        const SizedBox(height: 7),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(icon, size: 19, color: AppColors.tertiaryText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodyMd.copyWith(color: AppColors.onSurface),
                  ),
                ),
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
    );
  }
}
