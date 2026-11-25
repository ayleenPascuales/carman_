import 'package:material_ui/material_ui.dart';

/// 8pt spatial grid with 4pt half-steps.
abstract final class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const huge = 32.0;
  static const giant = 48.0;

  static const screenPadding = EdgeInsets.symmetric(horizontal: lg);
  static const cardPadding = EdgeInsets.all(lg);
  static const pagePadding = EdgeInsets.fromLTRB(lg, lg, lg, xxl);
}

abstract final class AppRadius {
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const pill = 999.0;

  static const card = BorderRadius.all(Radius.circular(18));
  static const control = BorderRadius.all(Radius.circular(14));
  static const sheet = BorderRadius.vertical(top: Radius.circular(xl));
}
