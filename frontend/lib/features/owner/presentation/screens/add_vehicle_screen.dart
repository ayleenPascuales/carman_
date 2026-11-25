import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../data/repositories/vehicle_repository.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_button.dart';
import '../../../../shared/widgets/carman_card.dart';
import '../../../../shared/widgets/carman_chips.dart';
import '../../../../shared/widgets/carman_text_field.dart';
import '../../../../shared/widgets/carman_top_bar.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/sheets.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/owner_controller.dart';

class AddVehicleScreen extends ConsumerStatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  ConsumerState<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends ConsumerState<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController(text: '${DateTime.now().year - 1}');
  final _plate = TextEditingController();
  final _priceDay = TextEditingController();
  final _priceHour = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  VehicleCategory _category = VehicleCategory.suv;
  FuelType _fuel = FuelType.electric;
  TransmissionType _transmission = TransmissionType.automatic;
  int _seats = 5;
  String _city = 'Cartagena';

  @override
  void dispose() {
    _brand.dispose();
    _model.dispose();
    _year.dispose();
    _plate.dispose();
    _priceDay.dispose();
    _priceHour.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final priceDay = double.tryParse(_priceDay.text.replaceAll(',', '.'));
    final priceHour = double.tryParse(_priceHour.text.replaceAll(',', '.'));
    if (priceDay == null || priceDay <= 0) {
      showCarmanSnack(
        context,
        'Introduce una tarifa diaria válida.',
        kind: SnackKind.warning,
      );
      return;
    }
    if (priceHour == null || priceHour <= 0) {
      showCarmanSnack(
        context,
        'Introduce una tarifa por hora válida.',
        kind: SnackKind.warning,
      );
      return;
    }
    if (_location.text.trim().isEmpty) {
      showCarmanSnack(
        context,
        'Indica el barrio o punto de entrega.',
        kind: SnackKind.warning,
      );
      return;
    }
    final success = await ref
        .read(ownerControllerProvider.notifier)
        .publish(
          VehicleDraft(
            brand: _brand.text.trim(),
            model: _model.text.trim(),
            year: int.parse(_year.text),
            plate: _plate.text.trim().toUpperCase(),
            seats: _seats,
            category: _category,
            fuel: _fuel,
            transmission: _transmission,
            pricePerDay: priceDay,
            pricePerHour: priceHour,
            city: _city,
            location: _location.text.trim(),
            description: _description.text.trim(),
          ),
        );
    if (!mounted) return;
    if (success) {
      showCarmanSnack(
        context,
        'Vehículo enviado a revisión. Te avisaremos al aprobarlo.',
        kind: SnackKind.success,
      );
      context.pop();
    } else {
      final error = ref.read(ownerControllerProvider).error;
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
          const SheetHeader(title: 'Ciudad del vehículo'),
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
    final owner = ref.watch(ownerControllerProvider);
    final user = ref.watch(authControllerProvider).user;
    if (user == null || !user.isOwner) {
      return Scaffold(
        appBar: CarmanTopBar(
          title: 'Registrar vehículo',
          onBack: () => context.pop(),
        ),
        body: EmptyState(
          title: 'Activa el modo propietario',
          message: 'Necesitas el rol de propietario para publicar vehículos en Carman.',
          icon: Icons.car_rental_rounded,
          actionLabel: 'Ir a mi perfil',
          onAction: () => context.go('/profile'),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: CarmanTopBar(
        title: 'Registrar vehículo',
        onBack: () => context.pop(),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Text(
              'Datos del vehículo',
              style: AppTheme.headlineSm.copyWith(fontSize: 17),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: CarmanTextField(
                    controller: _brand,
                    label: 'Marca',
                    hint: 'Tesla',
                    validator: (value) =>
                        Validators.required(value, label: 'La marca'),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CarmanTextField(
                    controller: _model,
                    label: 'Modelo',
                    hint: 'Model Y',
                    validator: (value) =>
                        Validators.required(value, label: 'El modelo'),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: CarmanTextField(
                    controller: _year,
                    label: 'Año',
                    hint: '2023',
                    keyboardType: TextInputType.number,
                    validator: Validators.year,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CarmanTextField(
                    controller: _plate,
                    label: 'Placa',
                    hint: 'ABC-123',
                    textCapitalization: TextCapitalization.characters,
                    validator: Validators.plate,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9-]'),
                      ),
                      LengthLimitingTextInputFormatter(10),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Categoría', style: AppTheme.labelMd),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: VehicleCategory.values
                  .where((category) => category != VehicleCategory.all)
                  .map(
                    (category) => CarmanFilterChip(
                      label: category.label,
                      icon: category.icon,
                      selected: _category == category,
                      onTap: () => setState(() => _category = category),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Combustible', style: AppTheme.labelMd),
                      const SizedBox(height: 7),
                      DropdownButtonFormField<FuelType>(
                        initialValue: _fuel,
                        decoration: const InputDecoration(),
                        items: FuelType.values
                            .map(
                              (fuel) => DropdownMenuItem(
                                value: fuel,
                                child: Text(fuel.label),
                              ),
                            )
                            .toList(),
                        onChanged: (fuel) =>
                            setState(() => _fuel = fuel ?? _fuel),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Plazas', style: AppTheme.labelMd),
                      const SizedBox(height: 7),
                      DropdownButtonFormField<int>(
                        initialValue: _seats,
                        decoration: const InputDecoration(),
                        items: const [2, 4, 5, 7, 8]
                            .map(
                              (seats) => DropdownMenuItem(
                                value: seats,
                                child: Text('$seats plazas'),
                              ),
                            )
                            .toList(),
                        onChanged: (seats) =>
                            setState(() => _seats = seats ?? _seats),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Transmisión', style: AppTheme.labelMd),
            const SizedBox(height: 7),
            SegmentedControl<TransmissionType>(
              values: TransmissionType.values,
              selected: _transmission,
              labelBuilder: (value) => value.label,
              onChanged: (value) => setState(() => _transmission = value),
            ),
            const SizedBox(height: 18),
            Text(
              'Tarifas y ubicación',
              style: AppTheme.headlineSm.copyWith(fontSize: 17),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: CarmanTextField(
                    controller: _priceDay,
                    label: 'Precio por día',
                    hint: '75',
                    prefixIcon: Icons.payments_outlined,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) =>
                        Validators.required(value, label: 'La tarifa diaria'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CarmanTextField(
                    controller: _priceHour,
                    label: 'Precio por hora',
                    hint: '18',
                    prefixIcon: Icons.schedule_rounded,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) =>
                        Validators.required(value, label: 'La tarifa por hora'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickCity,
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Ciudad',
                  prefixIcon: Icon(Icons.location_city_rounded, size: 19),
                ),
                child: Row(
                  children: [
                    Text(_city, style: AppTheme.bodyMd),
                    const Spacer(),
                    const Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: AppColors.tertiaryText,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            CarmanTextField(
              controller: _location,
              label: 'Barrio / punto de entrega',
              hint: 'Bocagrande, Manga, Centro…',
              prefixIcon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 14),
            CarmanTextField(
              controller: _description,
              label: 'Descripción (opcional)',
              hint: 'Cuéntales a los clientes qué hace especial tu coche.',
              maxLines: 3,
              maxLength: 200,
            ),
            const SizedBox(height: 8),
            CarmanCard(
              padding: const EdgeInsets.all(12),
              showShadow: false,
              color: AppColors.surfaceSoft,
              child: Row(
                children: [
                  const Icon(
                    Icons.photo_camera_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Añade al menos 5 fotos nítidas después de crear el vehículo para acelerar la revisión.',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 10,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            CarmanButton(
              label: 'Enviar a revisión',
              trailingIcon: Icons.arrow_forward_rounded,
              isLoading: owner.isPublishing,
              onPressed: _submit,
            ),
            const SizedBox(height: 10),
            Text(
              'La información se revisa antes de publicar.',
              textAlign: TextAlign.center,
              style: AppTheme.bodySm.copyWith(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}
