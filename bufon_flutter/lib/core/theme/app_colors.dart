// core/theme/app_colors.dart

import 'package:flutter/material.dart';

/// BUFÓN Color System — implements BUFON_DESIGN_SYSTEM.md v1.1, Capítulo 5.
///
/// This file has two sections:
///
/// 1. The Butter Bliss system (`butter`, `ink`, `paper`, `graphite`, `mint`,
///    `coral`, `sky`, `lavender` + tint/shade ramps) — the canonical palette
///    going forward. New code should only reference these.
/// 2. A LEGACY section preserving every color/gradient the old "casino" theme
///    exposed, byte-for-byte unchanged. Home/Lobby/Game/Voting and every
///    other unmigrated screen still reference these names directly (e.g.
///    `AppColors.primary`, `AppColors.background`) — changing their values
///    now would silently reskin those screens before Fase 3D gets to them,
///    which Fase 3A explicitly must not do. They are deleted only once the
///    last screen that references them migrates (see roadmap Fase 3D+).
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------
  // Butter Bliss — canonical system (Capítulo 5)
  // ---------------------------------------------------------------------

  static const Color butter = Color(0xFFF8EE67);
  static const Color butterTint = Color(0xFFFDFBE8);
  static const Color butterShade = Color(0xFFD9C92A);

  static const Color ink = Color(0xFF191919);
  static const Color inkSoft = Color(0xFF8A8578);
  static const Color inkShade = Color(0xFF000000);

  static const Color paper = Color(0xFFFAFAF7);
  static const Color paperTint = Color(0xFFFFFFFF);
  static const Color paperLine = Color(0xFFE4DFCF);

  static const Color graphite = Color(0xFF242320);
  static const Color graphitePlus1 = Color(0xFF3A382F);
  static const Color graphiteShade = Color(0xFF151410);

  static const Color mint = Color(0xFF63D6A5);
  static const Color mintTint = Color(0xFFE4F6EE);
  static const Color mintShade = Color(0xFF1F9C6E);

  static const Color coral = Color(0xFFFF7A6A);
  static const Color coralTint = Color(0xFFFDE9E4);
  static const Color coralShade = Color(0xFFE85A46);

  static const Color sky = Color(0xFF6BC8FF);
  static const Color skyTint = Color(0xFFE4F3FC);
  static const Color skyShade = Color(0xFF1C7FB8);

  static const Color lavender = Color(0xFF9C8CFF);
  static const Color lavenderTint = Color(0xFFEEEAFB);
  static const Color lavenderShade = Color(0xFF6F5BD6);

  /// Generates a tint (lighter, desaturated) variant of [base] following the
  /// formula documented in Capítulo 5's "Nota de escalabilidad": luminosidad
  /// llevada a 95%, saturación reducida 40%. Use this for any brand color
  /// introduced after this file was written (e.g. a future season accent) so
  /// its ramp stays consistent with the eight defined above, instead of
  /// picking a tint/shade by eye.
  static Color generateTint(Color base) {
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withLightness(0.95)
        .withSaturation((hsl.saturation * 0.6).clamp(0.0, 1.0))
        .toColor();
  }

  /// Generates a shade (darker, more saturated) variant of [base] following
  /// the same documented formula: luminosidad reducida 25%, saturación
  /// aumentada 10%.
  static Color generateShade(Color base) {
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withLightness((hsl.lightness - 0.25).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation * 1.1).clamp(0.0, 1.0))
        .toColor();
  }

  // ---------------------------------------------------------------------
  // LEGACY — unchanged values from the pre-v1.1 "casino" theme.
  // Still consumed directly by lib/screens/*, paywall_screen.dart, and the
  // widgets in lib/presentation/widgets/*. Do not repoint these to Butter
  // Bliss values; migrate call sites instead (Fase 3D+), then delete this
  // section entirely.
  // ---------------------------------------------------------------------

  static const Color background = Color(0xFF111111);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceDark = Color(0xFF16213E);
  static const Color backgroundElevated = Color(0xFF1A1A2E);
  static const Color backgroundCard = Color(0xFF16213E);
  static const Color backgroundAccent = Color(0xFF0F3460);

  static const Color border = Color(0xFF2A2A3E);
  static const Color divider = Color(0xFF1F1F2E);
  static const Color accent = Color(0xFF00D9FF);

  static const Color primary = Color(0xFFE94560);
  static const Color primaryLight = Color(0xFFFF6B7A);
  static const Color primaryDark = Color(0xFFB8354B);

  static const Color gold = Color(0xFFFFD700);
  static const Color goldDark = Color(0xFFFFB700);
  static const Color amber = Color(0xFFFFA500);

  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFE94560);
  static const Color info = Color(0xFF2196F3);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textTertiary = Color(0xFF808080);
  static const Color textDisabled = Color(0xFF4D4D4D);

  static const Color glow = Color(0xFFFF6B7A);
  static const Color shimmer = Color(0x33FFFFFF);

  static const Color timerNormal = Color(0xFF4CAF50);
  static const Color timerWarning = Color(0xFFFF9800);
  static const Color timerDanger = Color(0xFFE94560);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold, goldDark],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [background, backgroundElevated],
  );
}
