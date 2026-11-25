import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';

class CarmanFilterChip extends StatelessWidget {
  const CarmanFilterChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.showClose = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryViolet : AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: selected ? Colors.white : AppColors.tertiaryText,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: AppTheme.labelMd.copyWith(
                  fontSize: 12,
                  color: selected ? Colors.white : AppColors.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (showClose) ...[
                const SizedBox(width: 3),
                Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: selected ? Colors.white : AppColors.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onChanged,
    this.iconBuilder,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelBuilder;
  final Widget Function(T value)? iconBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: AppRadius.control,
      ),
      child: Row(
        children: values.map((value) {
          final isSelected = value == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (iconBuilder != null) ...[
                      iconBuilder!(value),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        labelBuilder(value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.labelLg.copyWith(
                          fontSize: 12.5,
                          color: isSelected
                              ? AppColors.onSurface
                              : AppColors.tertiaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class SelectPill extends StatelessWidget {
  const SelectPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.softLavender : AppColors.surfaceSoft,
          borderRadius: AppRadius.control,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primaryViolet : Colors.transparent,
                border: Border.all(
                  color: selected ? AppColors.primaryViolet : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 11),
            if (icon != null) ...[
              Icon(
                icon,
                size: 19,
                color: selected ? AppColors.primary : AppColors.tertiaryText,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTheme.labelLg.copyWith(
                      fontSize: 13,
                      color: selected
                          ? AppColors.deepViolet
                          : AppColors.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTheme.bodySm.copyWith(fontSize: 10.5),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
