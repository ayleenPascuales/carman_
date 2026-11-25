import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../data/models/vehicle_query.dart';
import '../../../../providers.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/carman_button.dart';
import '../../../../shared/widgets/carman_card.dart';
import '../../../../shared/widgets/carman_chips.dart';
import '../../../../shared/widgets/carman_text_field.dart';
import '../../../../shared/widgets/sheets.dart';
import '../../application/catalog_controller.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late VehicleQuery _draft;
  late DateTime _startAt;
  late DateTime _endAt;
  late int _hourlyDuration;
  final _searchController = TextEditingController();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final base = ref.read(catalogControllerProvider).query;
    _draft = base;
    final now = DateTime.now();
    final fallbackStart = DateTime(now.year, now.month, now.day + 1, 10);
    _startAt = base.startAt != null && base.startAt!.isAfter(now)
        ? base.startAt!
        : fallbackStart;
    _endAt = base.endAt != null && base.endAt!.isAfter(_startAt)
        ? base.endAt!
        : _startAt.add(
            Duration(
              days: base.mode == RentalMode.daily ? 3 : 0,
              hours: base.mode == RentalMode.hourly ? 4 : 0,
            ),
          );
    _hourlyDuration = (_endAt.difference(_startAt).inHours).clamp(2, 24);
    _searchController.text = base.text;
    _draft = _draft.copyWith(startAt: _startAt, endAt: _endAt);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Fecha de recogida',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt),
      helpText: 'Hora de recogida',
    );
    if (time == null || !mounted) return;
    final next = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      _startAt = next;
      if (_draft.mode == RentalMode.hourly) {
        _endAt = next.add(Duration(hours: _hourlyDuration));
      } else if (!_endAt.isAfter(next)) {
        _endAt = next.add(const Duration(days: 3));
      }
      _draft = _draft.copyWith(startAt: _startAt, endAt: _endAt);
    });
  }

  Future<void> _pickEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endAt.isAfter(_startAt)
          ? _endAt
          : _startAt.add(const Duration(days: 1)),
      firstDate: _startAt,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Fecha de devolución',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endAt),
      helpText: 'Hora de devolución',
    );
    if (time == null || !mounted) return;
    final next = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!next.isAfter(_startAt)) {
      showCarmanSnack(
        context,
        'La devolución debe ser posterior a la recogida.',
        kind: SnackKind.error,
      );
      return;
    }
    setState(() {
      _endAt = next;
      _draft = _draft.copyWith(startAt: _startAt, endAt: _endAt);
    });
  }

  void _setMode(RentalMode mode) {
    setState(() {
      final DateTime end;
      if (mode == RentalMode.hourly) {
        end = _startAt.add(Duration(hours: _hourlyDuration));
      } else {
        end = _startAt.add(const Duration(days: 3));
      }
      _endAt = end;
      _draft = _draft.copyWith(mode: mode, startAt: _startAt, endAt: _endAt);
    });
  }

  Future<void> _pickDuration() async {
    const options = [2, 4, 6, 8, 12, 24];
    final selected = await showCarmanSheet<int>(
      context: context,
      maxHeightFactor: 0.55,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeader(
            title: 'Duración del alquiler',
            subtitle: 'Mínimo 2 horas. Puedes ampliar desde tu reserva.',
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              children: options.map((hours) {
                final isSelected = hours == _hourlyDuration;
                return ListTile(
                  onTap: () => Navigator.pop(context, hours),
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.tertiaryText,
                  ),
                  title: Text(
                    hours == 24 ? '1 día completo' : '$hours horas',
                    style: AppTheme.titleMd,
                  ),
                  subtitle: Text(
                    hours == 1 ? '1 hora' : '$hours horas de alquiler',
                    style: AppTheme.bodySm,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
    if (selected == null) return;
    setState(() {
      _hourlyDuration = selected;
      _endAt = _startAt.add(Duration(hours: selected));
      _draft = _draft.copyWith(
        mode: RentalMode.hourly,
        startAt: _startAt,
        endAt: _endAt,
      );
    });
  }

  Future<void> _pickPickupPoint() async {
    List<PickupPoint> points;
    try {
      points = await ref.read(pickupPointsProvider(_draft.city).future);
    } catch (_) {
      if (mounted) {
        showCarmanSnack(
          context,
          'No se pudieron cargar los puntos autorizados.',
        );
      }
      return;
    }
    if (!mounted) return;
    if (points.isEmpty) {
      showCarmanSnack(context, 'No hay puntos de entrega en esta ciudad.');
      return;
    }
    final selected = await showCarmanSheet<PickupPoint>(
      context: context,
      maxHeightFactor: 0.75,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeader(
            title: 'Punto de recogida',
            subtitle: 'Elige el lugar donde quieres recibir tu vehículo.',
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: points.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final point = points[index];
                final isSelected = point.name == _draft.pickupPointName;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, point),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.softLavender.withValues(alpha: 0.5)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryViolet
                              : AppColors.borderSoft,
                        ),
                      ),
                      child: Row(
                        children: [
                          const IconTile(icon: Icons.location_on_rounded),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(point.name, style: AppTheme.titleMd),
                                const SizedBox(height: 2),
                                Text(point.address, style: AppTheme.bodySm),
                                if (point.hasDeliveryDetails) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'A ${point.distanceLabel} · ${point.isFree ? 'Entrega gratis' : 'Con cargo'}',
                                    style: AppTheme.labelSm.copyWith(
                                      fontSize: 9.5,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
    if (selected == null) return;
    setState(() {
      _draft = _draft.copyWith(pickupPointName: selected.name);
    });
  }

  Future<void> _pickCity() async {
    final city = await showCarmanSheet<String>(
      context: context,
      maxHeightFactor: 0.7,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeader(title: 'Ciudad de recogida'),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              children: AppConfig.cities.map((item) {
                final selected = item == _draft.city;
                return ListTile(
                  leading: Icon(
                    Icons.location_city_rounded,
                    color: selected
                        ? AppColors.primary
                        : AppColors.tertiaryText,
                  ),
                  title: Text(item, style: AppTheme.titleMd),
                  trailing: selected
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, item),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
    if (city == null) return;
    setState(() {
      _draft = _draft.copyWith(city: city, pickupPointName: '$city · Centro');
    });
  }

  Future<void> _pickPrice() async {
    final isHourly = _draft.mode == RentalMode.hourly;
    final max = isHourly ? 80.0 : 300.0;
    final min = isHourly ? 5.0 : 30.0;
    var value = (_draft.maxPrice ?? max).clamp(min, max).toDouble();
    final result = await showCarmanSheet<double?>(
      context: context,
      maxHeightFactor: 0.55,
      child: StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(
                title: 'Precio máximo',
                subtitle: isHourly
                    ? 'Filtra por tarifa por hora'
                    : 'Filtra por tarifa por día',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sin límite', style: AppTheme.bodySm),
                    Text(
                      AppFormatters.money(value),
                      style: AppTheme.headlineSm.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Slider(
                value: value,
                min: min,
                max: max,
                divisions: ((max - min) / 5).round(),
                label: AppFormatters.money(value),
                onChanged: (next) => setModalState(() => value = next),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, -1.0),
                        child: const Text('Sin límite'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, value),
                        child: const Text('Aplicar'),
                      ),
                    ),
                  ],
                ),
              ),
              const SafeArea(top: false, child: SizedBox(height: 4)),
            ],
          );
        },
      ),
    );
    if (result == null) return;
    setState(() {
      _draft = result < 0
          ? _draft.copyWith(clearMaxPrice: true)
          : _draft.copyWith(maxPrice: result);
    });
  }

  Future<void> _apply() async {
    if (!_endAt.isAfter(_startAt)) {
      showCarmanSnack(
        context,
        'La devolución debe ser posterior a la recogida.',
        kind: SnackKind.error,
      );
      return;
    }
    if (_draft.mode == RentalMode.hourly &&
        _endAt.difference(_startAt).inMinutes < 120) {
      showCarmanSnack(
        context,
        'El alquiler por horas tiene un mínimo de 2 horas.',
        kind: SnackKind.error,
      );
      return;
    }
    final query = _draft.copyWith(
      startAt: _startAt,
      endAt: _endAt,
      text: _searchController.text,
    );
    await ref.read(catalogControllerProvider.notifier).updateQuery(query);
    if (!mounted) return;
    context.go('/home/results');
  }

  void _reset() {
    final city = _draft.city;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day + 1, 10);
    setState(() {
      _draft = VehicleQuery(city: city, pickupPointName: '$city · Centro');
      _startAt = start;
      _endAt = start.add(const Duration(days: 3));
      _hourlyDuration = 4;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = _draft.mode;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cerrar',
        ),
        title: const Text('Buscar'),
        centerTitle: false,
        actions: [TextButton(onPressed: _reset, child: const Text('Limpiar'))],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.maxWidth > 780
              ? (constraints.maxWidth - 720) / 2
              : 0.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(20 + side, 10, 20 + side, 24),
            children: [
              const _Label('Recogida'),
              const SizedBox(height: 8),
              Material(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: _pickCity,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_draft.city} · ${_draft.pickupPointName.split('·').last.trim()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.titleMd.copyWith(fontSize: 13),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                _draft.pickupPointName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.bodySm.copyWith(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _pickPickupPoint,
                          icon: const Icon(Icons.near_me_outlined, size: 17),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Cambiar punto',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              CarmanTextField(
                controller: _searchController,
                hint: 'Marca o modelo',
                prefixIcon: Icons.search_rounded,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              const _Label('Modalidad'),
              const SizedBox(height: 8),
              SegmentedControl<RentalMode>(
                values: RentalMode.values,
                selected: mode,
                labelBuilder: (value) => value.label,
                onChanged: _setMode,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: mode == RentalMode.hourly
                    ? Row(
                        children: [
                          Expanded(
                            child: _SelectionTile(
                              icon: Icons.calendar_today_rounded,
                              label: 'Fecha',
                              value: AppFormatters.shortDate(_startAt),
                              onTap: _pickStartDate,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: _SelectionTile(
                              icon: Icons.schedule_rounded,
                              label: 'Inicio',
                              value: AppFormatters.time(_startAt),
                              onTap: _pickStartDate,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: _SelectionTile(
                              icon: Icons.timelapse_rounded,
                              label: 'Duración',
                              value: '$_hourlyDuration h',
                              onTap: _pickDuration,
                              highlighted: true,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _SelectionTile(
                              icon: Icons.event_available_rounded,
                              label: 'Desde',
                              value:
                                  '${AppFormatters.shortDate(_startAt)} · ${AppFormatters.time(_startAt)}',
                              onTap: _pickStartDate,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: _SelectionTile(
                              icon: Icons.event_busy_rounded,
                              label: 'Hasta',
                              value:
                                  '${AppFormatters.shortDate(_endAt)} · ${AppFormatters.time(_endAt)}',
                              onTap: _pickEndDate,
                              highlighted: true,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),
              const _Label('Categoría'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: VehicleCategory.values
                    .where((category) => category != VehicleCategory.all)
                    .map(
                      (category) => CarmanFilterChip(
                        label: category.label,
                        selected: _draft.category == category,
                        onTap: () => setState(() {
                          _draft = _draft.copyWith(
                            category: _draft.category == category
                                ? VehicleCategory.all
                                : category,
                          );
                        }),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              const _Label('Filtros'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  CarmanFilterChip(
                    label: 'Apertura móvil',
                    selected: _draft.instantBookOnly,
                    onTap: () => setState(() {
                      _draft = _draft.copyWith(
                        instantBookOnly: !_draft.instantBookOnly,
                      );
                    }),
                  ),
                  CarmanFilterChip(
                    label: 'Cancelación gratis',
                    selected: _draft.freeCancellationOnly,
                    onTap: () => setState(() {
                      _draft = _draft.copyWith(
                        freeCancellationOnly: !_draft.freeCancellationOnly,
                      );
                    }),
                  ),
                  CarmanFilterChip(
                    label: 'Automático',
                    selected: _draft.transmission == TransmissionType.automatic,
                    onTap: () => setState(() {
                      _draft = _draft.transmission == TransmissionType.automatic
                          ? _draft.copyWith(clearTransmission: true)
                          : _draft.copyWith(
                              transmission: TransmissionType.automatic,
                            );
                    }),
                  ),
                  CarmanFilterChip(
                    label: _draft.maxPrice == null
                        ? 'Precio'
                        : 'Hasta ${AppFormatters.money(_draft.maxPrice!)}',
                    selected: _draft.maxPrice != null,
                    showClose: _draft.maxPrice != null,
                    onTap: () {
                      if (_draft.maxPrice != null) {
                        setState(() {
                          _draft = _draft.copyWith(clearMaxPrice: true);
                        });
                      } else {
                        _pickPrice();
                      }
                    },
                  ),
                  CarmanFilterChip(
                    label: '5+ plazas',
                    selected: _draft.minSeats == 5,
                    onTap: () => setState(() {
                      _draft = _draft.minSeats == 5
                          ? _draft.copyWith(clearSeats: true)
                          : _draft.copyWith(minSeats: 5);
                    }),
                  ),
                ],
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
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
          child: CarmanButton(
            label: 'Buscar',
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: _apply,
            height: 50,
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTheme.labelMd.copyWith(
        fontSize: 11,
        color: AppColors.tertiaryText,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: highlighted
                  ? AppColors.primaryViolet
                  : AppColors.borderSoft,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 13, color: AppColors.tertiaryText),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: AppTheme.labelSm.copyWith(
                      fontSize: 9,
                      color: AppColors.tertiaryText,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.labelLg.copyWith(
                  fontSize: 11.5,
                  color: highlighted ? AppColors.primary : AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
