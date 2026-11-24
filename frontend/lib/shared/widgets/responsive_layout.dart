import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// Layout breakpoints shared by every screen.
abstract final class AppBreakpoints {
  static const double mobile = 700;
  static const double desktop = 1050;
  static const double maxContent = 1240;
  static const double maxForm = 480;
  static const double maxReading = 780;

  static bool isMobile(double width) => width < mobile;
  static bool isDesktop(double width) => width >= desktop;

  static double sidePadding(double width, {double max = maxContent}) {
    if (width <= max) return width < mobile ? 18 : 28;
    return ((width - max) / 2).clamp(28, 120);
  }
}

/// Keeps a screen centered at a readable width without breaking its scroll
/// viewport height. Ideal for forms, detail pages and secondary screens.
class MaxWidthContent extends StatelessWidget {
  const MaxWidthContent({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxContent,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final base = padding ?? const EdgeInsets.symmetric(horizontal: 18);
        final available = constraints.maxWidth - base.horizontal;
        final side = available > maxWidth
            ? base.left + (available - maxWidth) / 2
            : base.left;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: side),
          child: child,
        );
      },
    );
  }
}

/// Subtle desktop hover lift. Ignored on touch layouts and when the user
/// disables animations.
class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.child,
    this.scale = 1.006,
    this.enabled = true,
  });

  final Widget child;
  final double scale;
  final bool enabled;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovering = false;

  bool get _enabled =>
      widget.enabled &&
      (kIsWeb ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  @override
  Widget build(BuildContext context) {
    if (!_enabled || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? widget.scale : 1,
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

int responsiveColumns(
  double width, {
  int mobile = 1,
  int tablet = 2,
  int desktop = 3,
}) {
  if (width >= AppBreakpoints.desktop) return desktop;
  if (width >= AppBreakpoints.mobile) return tablet;
  return mobile;
}

/// Centers a full-screen route on wide displays. The page keeps a tight
/// viewport height and a corrected MediaQuery width, so every existing screen
/// remains functional while looking intentional on web.
class ResponsiveRouteFrame extends StatelessWidget {
  const ResponsiveRouteFrame({
    super.key,
    required this.child,
    this.maxWidth = 1100,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= maxWidth + 32) return child;
    final width = maxWidth;
    return ColoredBox(
      color: const Color(0xFFF1F1F4),
      child: Center(
        child: MediaQuery(
          data: media.copyWith(size: Size(width, media.size.height)),
          child: SizedBox(width: width, height: media.size.height, child: child),
        ),
      ),
    );
  }
}
