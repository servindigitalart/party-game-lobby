// core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_spacing.dart';
import 'app_shapes.dart';

/// BUFÓN App Theme — implements BUFON_DESIGN_SYSTEM.md v1.1.
///
/// [lightTheme]/[darkTheme] are the new Butter Bliss system (Capítulos
/// 5-11, 29-30). They are fully built and ready, but **not yet wired into
/// `main.dart`** — Fase 3A is infrastructure only; no screen may look
/// different because of this file until Fase 3B+ migrates it in. The app
/// keeps running on [legacyTheme] (byte-for-byte the old `darkTheme`,
/// renamed) until then.
class AppTheme {
  AppTheme._();

  // =====================================================================
  // Butter Bliss — canonical system
  // =====================================================================

  /// Paper register (Capítulo 30) — Home, Lobby, Perfil, Leaderboard,
  /// Temporadas, Paywall. Not active yet.
  static ThemeData get lightTheme => _build(brightness: Brightness.light);

  /// Graphite register (Capítulo 29) — Responder, Votar, Reveal, Resultado,
  /// Ganador: "el juego en vivo". Not active yet.
  static ThemeData get darkTheme => _build(brightness: Brightness.dark);

  static ThemeData _build({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final scheme = isDark ? _darkColorScheme : _lightColorScheme;

    // NOTE (known gap, see delivery notes): AppTypography's base styles
    // still carry a hardcoded legacy text color (white) because every
    // current consumer is a pre-migration dark screen that depends on it —
    // changing that default now would break those screens' text visibility
    // today, which this phase must not do. `.apply()` here forces the
    // *new* themes' TextTheme to the correct color per brightness
    // regardless of that hardcoded default, so lightTheme/darkTheme render
    // correctly the moment a screen actually adopts them (Fase 3B+).
    final textTheme = TextTheme(
      displayLarge: AppTypography.display,
      displayMedium: AppTypography.h1,
      displaySmall: AppTypography.h2,
      headlineMedium: AppTypography.h3,
      headlineSmall: AppTypography.h4,
      bodyLarge: AppTypography.body1,
      bodyMedium: AppTypography.body2,
      labelLarge: AppTypography.button,
      bodySmall: AppTypography.caption,
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: AppTypography.h3.copyWith(color: scheme.onSurface),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),

      // Card — flat by default (Capítulo 8: capa Ambiente). Components that
      // need to read as the screen's Protagonist apply
      // AppElevation.protagonistShadow themselves via a Container/
      // BoxDecoration; Material's own Card elevation stays at 0 so it never
      // draws a generic grey shadow.
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHighest,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: AppShapes.card(),
        margin: const EdgeInsets.all(AppSpacing.cardMargin),
      ),

      // Elevated Button — explicit Butter/Sky fill rather than
      // `colorScheme.primary` (see delivery notes: pure Butter is too pale
      // to serve as Material's abstract `primary` role safely, but is
      // exactly right as an explicit, large-surface button fill).
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? AppColors.sky : AppColors.butter,
          foregroundColor: isDark ? AppColors.graphiteShade : AppColors.ink,
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.4),
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: AppShapes.button(),
          textStyle: AppTypography.button,
          minimumSize: const Size(120, AppSpacing.buttonHeight),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(
            color: scheme.outline,
            width: AppShapes.borderWidthHairline,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: AppShapes.button(),
          textStyle: AppTypography.button,
          minimumSize: const Size(120, AppSpacing.buttonHeight),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          textStyle: AppTypography.button,
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: AppShapes.borderRadiusMd,
          borderSide: BorderSide(
            color: scheme.outline,
            width: AppShapes.borderWidthHairline,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppShapes.borderRadiusMd,
          borderSide: BorderSide(
            color: scheme.outline,
            width: AppShapes.borderWidthHairline,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppShapes.borderRadiusMd,
          borderSide: BorderSide(
            color: scheme.primary,
            width: AppShapes.borderWidthFocus,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppShapes.borderRadiusMd,
          borderSide: BorderSide(
            color: scheme.error,
            width: AppShapes.borderWidthFocus,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: AppTypography.body1.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.5),
        ),
      ),

      // Progress Indicator
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: AppShapes.borderWidthHairline,
        space: AppSpacing.lg,
      ),

      // Text selection ("Selection")
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.3),
        selectionHandleColor: scheme.primary,
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: AppTypography.body1.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: AppShapes.card(),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),

      // Dialog — Material renders Dialog/BottomSheet elevation via its own
      // dp→shadow algorithm, not a BoxShadow list, so
      // AppElevation.protagonistShadow doesn't plug in here directly; a
      // Dialog is inherently the screen's Protagonist while open, so a
      // modest elevation + colorScheme.shadow is the closest honest
      // translation of "Capas de Foco" onto Material's own primitives.
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        elevation: 8,
        shadowColor: scheme.shadow,
        shape: AppShapes.heroCard(),
        titleTextStyle: AppTypography.h3.copyWith(color: scheme.onSurface),
        contentTextStyle: AppTypography.body1.copyWith(
          color: scheme.onSurface,
        ),
      ),

      // BottomSheet — only the top corners round; reuses the radiusXl step
      // from AppShapes without forcing AppShapes to special-case this one
      // Material widget's shape.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppShapes.radiusXl),
            topRight: Radius.circular(AppShapes.radiusXl),
          ),
        ),
      ),

      // NavigationBar (Material 3 bottom nav) — unused today (the app
      // navigates via imperative Navigator pushes), prepared for if/when a
      // persistent nav surface is introduced.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        labelTextStyle: WidgetStateProperty.all(
          AppTypography.caption.copyWith(color: scheme.onSurface),
        ),
      ),

      // Icon
      iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
    );
  }

  /// Light ColorScheme (Paper register). `primary` is deliberately
  /// `butterShade`, not the pale base `butter` — see delivery notes:
  /// Material spreads `colorScheme.primary` into thin UI details (focus
  /// rings, selection indicators, text cursors) where pure Butter
  /// (`#F8EE67`) against Paper (`#FAFAF7`) fails a basic visibility check —
  /// both are near-white, so a hairline in Butter would nearly disappear.
  /// True Butter is still used explicitly for large surfaces (button
  /// fills) above, where flat-color contrast against Ink text is what
  /// matters, not a thin outline against Paper.
  static final ColorScheme _lightColorScheme = ColorScheme.light(
    primary: AppColors.butterShade,
    onPrimary: AppColors.ink,
    secondary: AppColors.mintShade,
    onSecondary: AppColors.paper,
    tertiary: AppColors.lavenderShade,
    onTertiary: AppColors.paper,
    error: AppColors.coralShade,
    onError: AppColors.paper,
    surface: AppColors.paper,
    onSurface: AppColors.ink,
    surfaceContainerHighest: AppColors.paperLine,
    outline: AppColors.paperLine,
    outlineVariant: AppColors.paperLine,
    inverseSurface: AppColors.graphite,
    onInverseSurface: AppColors.paper,
    shadow: AppColors.ink,
  );

  /// Dark ColorScheme (Graphite register). `primary` is Sky — a
  /// phase-neutral choice. The design doc assigns Lavender to Votación and
  /// Mint to victory (Capítulo 33), but Material's ColorScheme is one
  /// global value per ThemeData; it can't change per screen within the
  /// same theme. Phase-specific accents (Lavender for voting, Mint for
  /// winning) must stay explicit widget-level colors applied screen by
  /// screen in Fase 3E+, not something baked into this global scheme.
  static final ColorScheme _darkColorScheme = ColorScheme.dark(
    primary: AppColors.sky,
    onPrimary: AppColors.graphiteShade,
    secondary: AppColors.mint,
    onSecondary: AppColors.graphiteShade,
    tertiary: AppColors.lavender,
    onTertiary: AppColors.graphiteShade,
    error: AppColors.coral,
    onError: AppColors.graphiteShade,
    surface: AppColors.graphite,
    onSurface: AppColors.paper,
    surfaceContainerHighest: AppColors.graphitePlus1,
    outline: AppColors.graphitePlus1,
    outlineVariant: AppColors.graphitePlus1,
    inverseSurface: AppColors.paper,
    onInverseSurface: AppColors.ink,
    shadow: AppColors.inkShade,
  );

  // =====================================================================
  // LEGACY — unchanged behavior, still the theme main.dart applies.
  // Delete this getter (and the call site in main.dart) once every screen
  // has migrated to lightTheme/darkTheme (Fase 3D+).
  // =====================================================================

  static ThemeData get legacyTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.gold,
        surface: AppColors.backgroundCard,
        error: AppColors.error,
        onPrimary: AppColors.textPrimary,
        onSecondary: AppColors.background,
        onSurface: AppColors.textPrimary,
        onError: AppColors.textPrimary,
      ),
      useMaterial3: true,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundElevated,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: AppTypography.h3,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),

      cardTheme: CardThemeData(
        color: AppColors.backgroundCard,
        elevation: 4,
        shadowColor: Colors.black45,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        margin: const EdgeInsets.all(AppSpacing.cardMargin),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textPrimary,
          elevation: 4,
          shadowColor: AppColors.primary.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          textStyle: AppTypography.button,
          minimumSize: const Size(120, AppSpacing.buttonHeight),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.primary, width: 2),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          textStyle: AppTypography.button,
          minimumSize: const Size(120, AppSpacing.buttonHeight),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          textStyle: AppTypography.button,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          borderSide: const BorderSide(color: AppColors.backgroundAccent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          borderSide: const BorderSide(color: AppColors.backgroundAccent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: AppTypography.body1.copyWith(color: AppColors.textTertiary),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        circularTrackColor: AppColors.backgroundAccent,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.backgroundAccent,
        thickness: 1,
        space: AppSpacing.lg,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.backgroundCard,
        contentTextStyle: AppTypography.body1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.backgroundCard,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        titleTextStyle: AppTypography.h3,
        contentTextStyle: AppTypography.body1,
      ),

      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 24),

      textTheme: TextTheme(
        displayLarge: AppTypography.display,
        displayMedium: AppTypography.h1,
        displaySmall: AppTypography.h2,
        headlineMedium: AppTypography.h3,
        headlineSmall: AppTypography.h4,
        bodyLarge: AppTypography.body1,
        bodyMedium: AppTypography.body2,
        labelLarge: AppTypography.button,
        bodySmall: AppTypography.caption,
      ),
    );
  }

  /// Set status bar style
  static void setSystemUIOverlay() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }
}
