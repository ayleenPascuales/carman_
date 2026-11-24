import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Brand lockup used on welcome, auth and profile surfaces.
class CarmanLogo extends StatelessWidget {
  const CarmanLogo({
    super.key,
    this.showWordmark = true,
    this.light = false,
    this.size = 40,
  });

  final bool showWordmark;
  final bool light;
  final double size;

  @override
  Widget build(BuildContext context) {
    final foreground = light ? Colors.white : AppColors.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(size * 0.3),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryViolet.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.directions_car_filled_rounded,
            color: Colors.white,
            size: size * 0.5,
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(width: AppSpacing.md),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Carman',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: size * 0.5,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                  color: foreground,
                ),
              ),
              Text(
                'MOBILITY REIMAGINED',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: size * 0.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.15,
                  color: light
                      ? Colors.white.withValues(alpha: 0.55)
                      : AppColors.tertiaryText,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Square mark used on splash / launcher-like contexts.
class CarmanMark extends StatelessWidget {
  const CarmanMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryViolet.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(
        Icons.directions_car_filled_rounded,
        color: Colors.white,
        size: size * 0.52,
      ),
    );
  }
}
