import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';

enum CarmanButtonVariant { primary, secondary, outline, ghost, dark, danger }

/// The single button primitive for the product. It owns tap feedback, loading
/// state and a very restrained violet accent.
class CarmanButton extends StatelessWidget {
  const CarmanButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = CarmanButtonVariant.primary,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.expanded = true,
    this.height = 50,
    this.padding,
    this.heroTag,
  });

  final String label;
  final VoidCallback? onPressed;
  final CarmanButtonVariant variant;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool expanded;
  final double height;
  final EdgeInsets? padding;
  final String? heroTag;

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = _colors();
    final button = SizedBox(
      height: height,
      width: expanded ? double.infinity : null,
      child: Material(
        color: colors.background,
        borderRadius: AppRadius.control,
        child: InkWell(
          onTap: _enabled ? onPressed : null,
          borderRadius: AppRadius.control,
          child: Container(
            padding:
                padding ??
                const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: AppRadius.control,
              border: colors.border == null
                  ? null
                  : Border.all(color: colors.border!, width: 1),
            ),
            child: Row(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.foreground,
                    ),
                  )
                else if (icon != null)
                  Icon(icon, size: 18, color: colors.foreground),
                if (icon != null || isLoading) const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isLoading ? 'Procesando…' : label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.labelLg.copyWith(
                      color: colors.foreground,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                if (trailingIcon != null && !isLoading) ...[
                  const SizedBox(width: 7),
                  Icon(trailingIcon, size: 17, color: colors.foreground),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (heroTag == null) return button;
    return Hero(tag: heroTag!, child: button);
  }

  _ButtonColors _colors() {
    switch (variant) {
      case CarmanButtonVariant.primary:
        return _ButtonColors(
          background: _enabled
              ? AppColors.primaryViolet
              : AppColors.surfaceContainerHigh,
          foreground: _enabled ? Colors.white : AppColors.tertiaryText,
        );
      case CarmanButtonVariant.secondary:
        return const _ButtonColors(
          background: AppColors.surfaceSoft,
          foreground: AppColors.onSurface,
        );
      case CarmanButtonVariant.outline:
        return const _ButtonColors(
          background: Colors.transparent,
          foreground: AppColors.onSurface,
          border: AppColors.borderSoft,
        );
      case CarmanButtonVariant.ghost:
        return const _ButtonColors(
          background: Colors.transparent,
          foreground: AppColors.primary,
        );
      case CarmanButtonVariant.dark:
        return const _ButtonColors(
          background: AppColors.graphite,
          foreground: Colors.white,
        );
      case CarmanButtonVariant.danger:
        return const _ButtonColors(
          background: AppColors.errorSurface,
          foreground: AppColors.error,
        );
    }
  }
}

class _ButtonColors {
  const _ButtonColors({
    required this.background,
    required this.foreground,
    this.border,
  });

  final Color background;
  final Color foreground;
  final Color? border;
}
