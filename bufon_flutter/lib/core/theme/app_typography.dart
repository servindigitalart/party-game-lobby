// core/theme/app_typography.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';

/// The one place a font family name is written.
///
/// Fase 2A moved typography off `google_fonts`, which fetches font binaries
/// over HTTP on first use. That meant a cold first launch without network —
/// a bar, a house with saturated Wi-Fi, a phone in airplane mode, all normal
/// conditions for a party game — rendered the entire brand in the platform
/// default (Roboto/SF Pro), and a share card generated before the fetch
/// completed left the app with the brand's own name set in someone else's
/// typeface, permanently. The faces are now bundled assets (see
/// `pubspec.yaml`), so nothing about Bufón's identity depends on the network.
const String _kBrandFontFamily = 'PlusJakartaSans';

/// BUFÓN Typography System — implements BUFON_DESIGN_SYSTEM.md v1.1,
/// Capítulo 6.
///
/// Font selection is deliberately isolated to the two private functions
/// below ([_display], [_body]) instead of being inlined in every
/// [TextStyle]. The design doc explicitly left the Display face undecided —
/// v1.0's pick (Fredoka/Baloo/Poppins) was flagged in the v1.1 review as
/// "the generic rounded-app default", and the real candidate needs on-device
/// comparison against the logotype before it's fixed. Until that decision
/// is made, both functions point at the same body-safe face (Plus Jakarta
/// Sans, which the doc *did* already settle on for body/UI text). Swapping
/// the Display face later means editing [_display] only — no call site in
/// the rest of the app changes.
TextStyle _display({
  required double fontSize,
  required FontWeight fontWeight,
  required double height,
  Color? color,
  double? letterSpacing,
}) {
  // TODO(design-system): replace with the chosen Display face once
  // on-device comparison against the logotype (Capítulo 6, v1.1) is done.
  // Fase 2A deliberately did not pick one: the design doc rejects the v1.0
  // shortlist and the blueprint makes "keep this face" a valid outcome of
  // the comparison. Bundling first means the network defect is fixed
  // whichever face wins.
  return TextStyle(
    fontFamily: _kBrandFontFamily,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
    color: color,
    letterSpacing: letterSpacing,
  );
}

TextStyle _body({
  required double fontSize,
  required FontWeight fontWeight,
  required double height,
  Color? color,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: _kBrandFontFamily,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
    color: color,
    letterSpacing: letterSpacing,
  );
}

class AppTypography {
  AppTypography._();

  // Headings. Negative letterSpacing is reserved for display/h1/h2 only
  // (Capítulo 6, v1.1) — h3/h4 keep neutral spacing for legibility at
  // smaller sizes; h3 previously carried -0.2 and has been corrected here.
  static TextStyle get h1 => _display(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.2,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get h2 => _display(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    height: 1.3,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static TextStyle get h3 => _display(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static TextStyle get h4 => _body(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  // Body text
  static TextStyle get body1 => _body(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static TextStyle get body2 => _body(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  // Special
  static TextStyle get caption => _body(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.4,
    color: AppColors.textTertiary,
  );

  static TextStyle get button => _body(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.5,
  );

  static TextStyle get buttonLarge => _body(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: 0.5,
  );

  // Display (big numbers, room codes, timer, final scores) — reserved size
  // per Capítulo 6: the one place in a screen allowed to be this large.
  static TextStyle get display => _display(
    fontSize: 48,
    fontWeight: FontWeight.bold,
    height: 1.1,
    color: AppColors.textPrimary,
    letterSpacing: -1,
  );

  /// Canonical replacement for the old `displayGold` (which pointed at the
  /// now-retired `AppColors.gold`, see Capítulo 5 — Butter absorbs that
  /// role). Not consumed anywhere yet; ready for Fase 3F/3G when
  /// Reveal/Winner screens migrate.
  static TextStyle get displayButter => _display(
    fontSize: 48,
    fontWeight: FontWeight.bold,
    height: 1.1,
    color: AppColors.butterShade,
    letterSpacing: -1,
  );

  @Deprecated('Use displayButter — gold was retired in Capítulo 5 (v1.1).')
  static TextStyle get displayGold => _display(
    fontSize: 48,
    fontWeight: FontWeight.bold,
    height: 1.1,
    color: AppColors.gold,
    letterSpacing: -1,
  );

  /// Applies tabular (fixed-width) figures to any style used for a value
  /// that changes every second or every point scored — timer countdowns,
  /// live scores, round counters. Without this, digits of different widths
  /// (a "1" vs. an "8") make the whole number visually shift every tick,
  /// which Capítulo 6 calls out as breaking the "premium" feel. Not yet
  /// applied anywhere; `TimerWidget`/score displays should adopt it when
  /// they migrate (Fase 3E/3F).
  static TextStyle tabular(TextStyle style) {
    return style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
  }
}
