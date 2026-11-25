import 'package:material_ui/material_ui.dart';

/// Carman design tokens extracted from the Stitch design system.
///
/// The palette is intentionally explicit instead of being generated from a
/// seed colour: the product relies on a very specific violet/graphite contrast.
abstract final class AppColors {
  // Brand.
  static const primary = Color(0xFF6B38D4);
  static const primaryViolet = Color(0xFF7C5AF6);
  static const deepViolet = Color(0xFF5B35D6);
  static const secondary = Color(0xFF712EDD);
  static const primaryContainer = Color(0xFF8455EF);
  static const softLavender = Color(0xFFF1EEFC);
  static const lavenderDeep = Color(0xFFE4DDFB);
  static const primaryFixed = Color(0xFFF4F0FE);
  static const primaryFixedDim = Color(0xFFD0BCFF);
  static const onPrimaryFixed = Color(0xFF23005C);

  // Structural neutrals.
  static const graphite = Color(0xFF17171B);
  static const onSurface = Color(0xFF151517);
  static const onSurfaceVariant = Color(0xFF4D4D57);
  static const secondaryText = Color(0xFF5F5F69);
  static const tertiaryText = Color(0xFF8B8B95);
  static const outline = Color(0xFF7B7486);
  static const outlineVariant = Color(0xFFD8D8DF);
  static const border = Color(0xFFE4E4EA);
  static const borderSoft = Color(0xFFEFEFF3);

  // Surfaces.
  static const canvas = Color(0xFFF6F6F8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF4F4F7);
  static const surfaceContainer = Color(0xFFF2F2F5);
  static const surfaceContainerHigh = Color(0xFFECECF0);
  static const surfaceContainerHighest = Color(0xFFE7E7EB);
  static const surfaceTint = Color(0xFFF4F4F7);

  // Semantic.
  static const success = Color(0xFF0E8A75);
  static const successText = Color(0xFF047857);
  static const successContainer = Color(0xFFD1FAE5);
  static const warning = Color(0xFFB45309);
  static const warningContainer = Color(0xFFFEF3C7);
  static const error = Color(0xFFBA1A1A);
  static const errorStrong = Color(0xFFEF4444);
  static const errorContainer = Color(0xFFFFDAD6);
  static const errorSurface = Color(0xFFFFF1F0);
  static const amber = Color(0xFFF59E0B);
  static const cash = Color(0xFF0F766E);

  // Glass / overlays.
  static const scrim = Color(0xCC171717);
  static const glass = Color(0xF7FFFFFF);
  static const darkOverlay = Color(0xFF1D1B22);

  // Gradients.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryViolet, primary],
  );
  static const heroScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xE6171717)],
    stops: [0.45, 1],
  );
  static const welcomeGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0D0B12), Color(0xFF17131F), Color(0xFF0B0A0E)],
  );
}
