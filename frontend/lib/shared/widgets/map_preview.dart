import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Lightweight stylised map used as a preview. It avoids API keys while still
/// giving the location a premium, product-specific appearance.
class MapPreview extends StatelessWidget {
  const MapPreview({
    super.key,
    this.height = 150,
    this.label,
    this.showLabel = true,
    this.markers = const [],
    this.interactive = false,
  });

  final double height;
  final String? label;
  final bool showLabel;
  final List<MapMarker> markers;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              AppAssets.mapProto,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Color(0xFFEDE9F4),
                child: _MapPainterBackground(),
              ),
            ),
            const ColoredBox(color: Color(0x1AF5F0FF)),
            Positioned.fill(child: CustomPaint(painter: _RoadOverlayPainter())),
            if (markers.isNotEmpty)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        for (final marker in markers)
                          Positioned(
                            left: marker.x * constraints.maxWidth - 20,
                            top: marker.y * (constraints.maxHeight - 48),
                            child: _Marker(marker: marker),
                          ),
                      ],
                    );
                  },
                ),
              ),
            if (showLabel && label != null)
              Positioned(
                left: 12,
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.borderSoft),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12171717),
                        blurRadius: 14,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          label!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                      if (interactive)
                        const Icon(
                          Icons.open_in_full_rounded,
                          size: 15,
                          color: AppColors.tertiaryText,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MapMarker {
  const MapMarker({
    required this.x,
    required this.y,
    this.selected = false,
    this.priceLabel,
  });

  final double x;
  final double y;
  final bool selected;
  final String? priceLabel;
}

class _Marker extends StatelessWidget {
  const _Marker({required this.marker});

  final MapMarker marker;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: marker.priceLabel == null
              ? const EdgeInsets.all(9)
              : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: marker.selected
                ? AppColors.primaryViolet
                : AppColors.graphite,
            borderRadius: BorderRadius.circular(
              marker.priceLabel == null ? 999 : AppRadius.md,
            ),
            border: Border.all(
              color: Colors.white,
              width: marker.selected ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: marker.priceLabel == null
              ? const Icon(
                  Icons.directions_car_filled_rounded,
                  size: 16,
                  color: Colors.white,
                )
              : Text(
                  marker.priceLabel!,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
        ),
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    );
  }
}

class _MapPainterBackground extends StatelessWidget {
  const _MapPainterBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BlockPainter(), size: Size.infinite);
  }
}

class _BlockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE1D9EC)
      ..style = PaintingStyle.fill;
    final random = math.Random(4);
    for (var i = 0; i < 26; i++) {
      final width = random.nextDouble() * 54 + 12;
      final height = random.nextDouble() * 38 + 12;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            random.nextDouble() * size.width,
            random.nextDouble() * size.height,
            width,
            height,
          ),
          const Radius.circular(5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoadOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final roadBorder = Paint()
      ..color = const Color(0xFFD3CADF).withValues(alpha: 0.7)
      ..strokeWidth = 8.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paths = [
      Path()
        ..moveTo(-20, size.height * 0.25)
        ..quadraticBezierTo(
          size.width * 0.35,
          size.height * 0.1,
          size.width * 0.7,
          size.height * 0.38,
        )
        ..quadraticBezierTo(
          size.width * 0.9,
          size.height * 0.55,
          size.width + 30,
          size.height * 0.5,
        ),
      Path()
        ..moveTo(size.width * 0.18, -20)
        ..quadraticBezierTo(
          size.width * 0.25,
          size.height * 0.55,
          size.width * 0.58,
          size.height + 20,
        ),
    ];
    for (final path in paths) {
      canvas.drawPath(path, roadBorder);
      canvas.drawPath(path, road);
    }

    final water = Paint()..color = const Color(0xFFD7E8F5);
    final wave = Path()
      ..moveTo(size.width * 0.75, -10)
      ..lineTo(size.width + 10, -10)
      ..lineTo(size.width + 10, size.height + 10)
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.85,
        size.width * 0.72,
        size.height + 10,
      )
      ..close();
    canvas.drawPath(wave, water);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
