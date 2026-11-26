import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';

bool _isExampleImage(String path) {
  final host = Uri.tryParse(path)?.host.toLowerCase();
  if (host == null) return false;
  return const [
    'example.com',
    'example.org',
    'example.net',
  ].any((domain) => host == domain || host.endsWith('.$domain'));
}

/// Handles both bundled assets (demo catalogue) and remote URLs (API
/// catalogue) with a branded fallback when a photograph is unavailable.
class CarmanImage extends StatelessWidget {
  const CarmanImage(
    this.path, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
  });

  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = path.isEmpty || _isExampleImage(path)
        ? _fallback()
        : path.startsWith('http')
        ? Image.network(
            path,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (_, _, _) => _fallback(),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return _placeholder(
                const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              );
            },
          )
        : Image.asset(
            path,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (_, _, _) => _fallback(),
          );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }

  Widget _fallback() => _placeholder(
    const Icon(
      Icons.directions_car_filled_rounded,
      size: 46,
      color: Colors.white70,
    ),
  );

  Widget _placeholder(Widget child) => Container(
    width: width,
    height: height,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3C3547), AppColors.graphite],
      ),
    ),
    child: Center(child: child),
  );
}

class CircleAvatarImage extends StatelessWidget {
  const CircleAvatarImage({
    super.key,
    this.asset,
    this.url,
    this.initials,
    this.radius = 22,
  });

  final String? asset;
  final String? url;
  final String? initials;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final path = asset ?? url;
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.softLavender,
        border: Border.all(color: AppColors.surface, width: 2),
      ),
      child: ClipOval(
        child: path != null
            ? CarmanImage(path, fit: BoxFit.cover)
            : Center(
                child: Text(
                  initials ?? 'C',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: radius * 0.72,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
      ),
    );
  }
}
