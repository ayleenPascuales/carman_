import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

abstract final class AppTheme {
  static const _family = 'Manrope';

  static const display = TextStyle(
    fontFamily: _family,
    fontSize: 32,
    height: 1.16,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    color: AppColors.onSurface,
  );

  static const headlineLg = TextStyle(
    fontFamily: _family,
    fontSize: 26,
    height: 1.24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.55,
    color: AppColors.onSurface,
  );

  static const headlineMd = TextStyle(
    fontFamily: _family,
    fontSize: 21,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.onSurface,
  );

  static const headlineSm = TextStyle(
    fontFamily: _family,
    fontSize: 17,
    height: 1.38,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
    color: AppColors.onSurface,
  );

  static const titleLg = TextStyle(
    fontFamily: _family,
    fontSize: 15.5,
    height: 1.45,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurface,
  );

  static const titleMd = TextStyle(
    fontFamily: _family,
    fontSize: 14.5,
    height: 1.4,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );

  static const bodyLg = TextStyle(
    fontFamily: _family,
    fontSize: 15,
    height: 1.55,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );

  static const bodyMd = TextStyle(
    fontFamily: _family,
    fontSize: 13.5,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );

  static const bodySm = TextStyle(
    fontFamily: _family,
    fontSize: 11.5,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: AppColors.tertiaryText,
  );

  static const labelLg = TextStyle(
    fontFamily: _family,
    fontSize: 13.5,
    height: 1.35,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.05,
  );

  static const labelMd = TextStyle(
    fontFamily: _family,
    fontSize: 11.5,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.05,
  );

  static const labelSm = TextStyle(
    fontFamily: _family,
    fontSize: 10,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  static const overline = TextStyle(
    fontFamily: _family,
    fontSize: 9.5,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.9,
    color: AppColors.tertiaryText,
  );

  static const price = TextStyle(
    fontFamily: _family,
    fontSize: 22,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AppColors.onSurface,
  );

  static ThemeData get light {
    final scheme = const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryFixed,
      onPrimaryContainer: AppColors.onPrimaryFixed,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.softLavender,
      onSecondaryContainer: AppColors.deepViolet,
      tertiary: AppColors.tertiaryText,
      onTertiary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: Color(0xFF93000A),
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      shadow: Color(0x14000000),
      scrim: AppColors.scrim,
      inverseSurface: Color(0xFF2A2A2F),
      onInverseSurface: Color(0xFFF3F3F5),
      inversePrimary: AppColors.primaryFixedDim,
      surfaceTint: AppColors.primary,
    );

    final baseText = Typography.material2021().black.apply(
      fontFamily: _family,
      bodyColor: AppColors.onSurface,
      displayColor: AppColors.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: _family,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      canvasColor: AppColors.canvas,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      hoverColor: AppColors.onSurface.withValues(alpha: 0.025),
      highlightColor: AppColors.onSurface.withValues(alpha: 0.03),
      textTheme: baseText.copyWith(
        displayLarge: display,
        displayMedium: display,
        headlineLarge: headlineLg,
        headlineMedium: headlineMd,
        headlineSmall: headlineSm,
        titleLarge: titleLg,
        titleMedium: titleMd,
        bodyLarge: bodyLg,
        bodyMedium: bodyMd,
        bodySmall: bodySm,
        labelLarge: labelLg,
        labelMedium: labelMd,
        labelSmall: labelSm,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.onSurface, size: 21),
        titleTextStyle: headlineSm,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryViolet,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surfaceContainerHigh,
          disabledForegroundColor: AppColors.tertiaryText,
          minimumSize: const Size.fromHeight(50),
          textStyle: labelLg.copyWith(fontSize: 14),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.control),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurface,
          side: const BorderSide(color: AppColors.borderSoft),
          minimumSize: const Size.fromHeight(50),
          textStyle: labelLg.copyWith(fontSize: 13),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.control),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: labelLg.copyWith(fontSize: 12.5),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceSoft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: bodyMd.copyWith(color: AppColors.tertiaryText),
        labelStyle: labelMd.copyWith(color: AppColors.secondaryText),
        errorStyle: bodySm.copyWith(color: AppColors.error),
        prefixIconColor: AppColors.tertiaryText,
        suffixIconColor: AppColors.tertiaryText,
        border: OutlineInputBorder(
          borderRadius: AppRadius.control,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.control,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.control,
          borderSide: const BorderSide(
            color: AppColors.primaryViolet,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.control,
          borderSide: const BorderSide(
            color: AppColors.errorStrong,
            width: 1.3,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.control,
          borderSide: const BorderSide(
            color: AppColors.errorStrong,
            width: 1.5,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSoft,
        thickness: 0.8,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1D1D22),
        contentTextStyle: bodyMd.copyWith(color: Colors.white, fontSize: 12.5),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.xl)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
        showDragHandle: false,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceSoft,
        selectedColor: AppColors.primaryViolet,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: labelMd.copyWith(color: AppColors.secondaryText),
        secondaryLabelStyle: labelMd.copyWith(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primaryViolet
              : AppColors.surfaceContainerHigh,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => Colors.transparent,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primaryViolet
              : AppColors.surface,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: AppColors.border, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryViolet,
        linearTrackColor: AppColors.surfaceContainerHigh,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(3),
        radius: const Radius.circular(99),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? AppColors.primaryViolet.withValues(alpha: 0.45)
              : AppColors.onSurface.withValues(alpha: 0.18),
        ),
        trackColor: const WidgetStatePropertyAll(Colors.transparent),
        crossAxisMargin: 2,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primaryViolet,
        selectionColor: AppColors.primaryViolet.withValues(alpha: 0.22),
        selectionHandleColor: AppColors.primaryViolet,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _MinimalPageTransitionsBuilder(),
          TargetPlatform.iOS: _MinimalPageTransitionsBuilder(),
          TargetPlatform.macOS: _MinimalPageTransitionsBuilder(),
          TargetPlatform.windows: _MinimalPageTransitionsBuilder(),
          TargetPlatform.linux: _MinimalPageTransitionsBuilder(),
        },
      ),
    );
  }
}

class _MinimalPageTransitionsBuilder extends PageTransitionsBuilder {
  const _MinimalPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.015),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
