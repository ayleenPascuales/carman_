import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Consistent top bar for transactional screens. It blends into the screen
/// background and avoids dividers or boxed containers.
class CarmanTopBar extends StatelessWidget implements PreferredSizeWidget {
  const CarmanTopBar({
    super.key,
    this.title,
    this.subtitle,
    this.overline,
    this.onBack,
    this.actions = const [],
    this.showBack = true,
    this.transparent = true,
    this.centerTitle = false,
    this.bottom,
  });

  final String? title;
  final String? subtitle;
  final String? overline;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final bool showBack;
  final bool transparent;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight((bottom?.preferredSize.height ?? 0) + 56);

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (showBack) ...[
                  _BackButton(onBack: onBack),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: centerTitle
                      ? Center(child: _titleBlock(center: true))
                      : _titleBlock(center: false),
                ),
                ...actions,
              ],
            ),
          ),
        ),
        ?bottom,
      ],
    );

    final safeContent = SafeArea(bottom: false, child: content);
    if (transparent) return safeContent;
    return ColoredBox(color: AppColors.surface, child: safeContent);
  }

  Widget _titleBlock({required bool center}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (overline != null)
          Text(
            overline!.toUpperCase(),
            style: AppTheme.overline.copyWith(fontSize: 8.5),
          ),
        if (title != null)
          Text(
            title!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.headlineSm.copyWith(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        if (subtitle != null)
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.bodySm.copyWith(fontSize: 10.5),
          ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onBack ?? () => Navigator.of(context).maybePop(),
          child: const Icon(
            Icons.arrow_back_rounded,
            size: 19,
            color: AppColors.onSurface,
          ),
        ),
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color = AppColors.onSurface,
    this.background = AppColors.surface,
    this.size = 38,
    this.iconSize = 18,
    this.tooltip,
    this.showBorder = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final Color background;
  final double size;
  final double iconSize;
  final String? tooltip;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: size,
      height: size,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: showBorder
                  ? Border.all(color: AppColors.borderSoft)
                  : null,
            ),
            child: Icon(icon, size: iconSize, color: color),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
