import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class CarmanCard extends StatelessWidget {
  const CarmanCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.onTap,
    this.color = AppColors.surface,
    this.borderColor,
    this.borderRadius = AppRadius.card,
    this.showShadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final Color? borderColor;
  final BorderRadius borderRadius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: borderRadius,
      side: borderColor == null
          ? BorderSide.none
          : BorderSide(color: borderColor!, width: 1),
    );
    final content = Padding(padding: padding, child: child);

    // Material (rather than a decorated Container) is the card's surface so
    // nested ListTiles and InkWells paint their effects correctly.
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: showShadow && color == AppColors.surface
            ? const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 22,
                  offset: Offset(0, 8),
                  spreadRadius: -8,
                ),
              ]
            : null,
      ),
      child: Material(
        color: color,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(onTap: onTap, borderRadius: borderRadius, child: content),
      ),
    );
  }
}

class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.size = 38,
    this.background = AppColors.surfaceSoft,
    this.foreground = AppColors.primary,
    this.radius = 12,
  });

  final IconData icon;
  final double size;
  final Color background;
  final Color foreground;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: size * 0.44, color: foreground),
    );
  }
}

class DottedDivider extends StatelessWidget {
  const DottedDivider({super.key, this.color = AppColors.borderSoft});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const dashWidth = 4.0;
        const dashSpace = 4.0;
        final count = (width / (dashWidth + dashSpace)).floor();
        return Row(
          children: List.generate(
            count,
            (index) => Container(
              width: dashWidth,
              height: 1,
              margin: const EdgeInsets.only(right: dashSpace),
              color: color,
            ),
          ),
        );
      },
    );
  }
}

class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
    this.valueColor,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: emphasize
                  ? const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    )
                  : const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12.5,
                      color: AppColors.secondaryText,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: emphasize ? 15 : 12.5,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
