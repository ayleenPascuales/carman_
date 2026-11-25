import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.color = AppColors.primary,
    this.background,
    this.icon,
    this.small = false,
  });

  final String label;
  final Color color;
  final Color? background;
  final IconData? icon;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 9,
        vertical: small ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: small ? 10 : 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: AppTheme.labelSm.copyWith(
              fontSize: small ? 8.5 : 9.5,
              color: color,
              letterSpacing: 0.15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class RatingBadge extends StatelessWidget {
  const RatingBadge({
    super.key,
    required this.rating,
    this.count,
    this.dark = false,
    this.compact = false,
  });

  final double rating;
  final int? count;
  final bool dark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: dark
            ? Colors.black.withValues(alpha: 0.42)
            : AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12.5, color: AppColors.amber),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(2),
            style: AppTheme.labelMd.copyWith(
              fontSize: compact ? 9.5 : 10.5,
              fontWeight: FontWeight.w800,
              color: dark ? Colors.white : AppColors.onSurface,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 2),
            Text(
              '($count)',
              style: AppTheme.bodySm.copyWith(
                fontSize: compact ? 8.5 : 9.5,
                color: dark
                    ? Colors.white.withValues(alpha: 0.62)
                    : AppColors.tertiaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class BadgePill extends StatelessWidget {
  const BadgePill({
    super.key,
    required this.label,
    this.icon,
    this.background = AppColors.surface,
    this.foreground = AppColors.onSurface,
    this.borderColor,
  });

  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTheme.labelSm.copyWith(
              fontSize: 9,
              color: foreground,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = EdgeInsets.zero,
    this.uppercase = false,
    this.count,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;
  final bool uppercase;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              uppercase ? title.toUpperCase() : title,
              style: uppercase
                  ? AppTheme.overline.copyWith(color: AppColors.tertiaryText)
                  : AppTheme.titleMd.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
            ),
          ),
          if (count != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '$count',
                style: AppTheme.labelSm.copyWith(
                  color: AppColors.secondaryText,
                  fontSize: 9,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                minimumSize: const Size(0, 26),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style: AppTheme.labelMd.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StepDots extends StatelessWidget {
  const StepDots({
    super.key,
    required this.count,
    required this.current,
    this.activeWidth = 22,
  });

  final int count;
  final int current;
  final double activeWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final active = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? activeWidth : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active
                ? AppColors.primaryViolet
                : AppColors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}
