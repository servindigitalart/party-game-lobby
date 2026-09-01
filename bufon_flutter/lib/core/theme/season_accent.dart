// core/theme/season_accent.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';

/// The colour a season is allowed to paint itself.
///
/// WP26 / **R-32**, Blueprint **F7**. `Season.themeColor` is a bare `int`
/// read straight out of Firestore and handed to `Color(...)` — an
/// **unconstrained colour-injection path onto the app's first screen**. A
/// season document could put any ARGB value on Home's banner, including one
/// that fails contrast, clashes with the register, or is simply not a Bufón
/// colour. Nothing in the client checked, because there was nothing to check
/// against.
///
/// This is the check. Four named accents, resolved client-side from the
/// design system, and anything else falls back to one of them. R-32's
/// non-goal is explicit: *"does not require a Firestore schema change —
/// resolve client-side"*, so the stored `themeColor` is untouched and
/// `toFirestore` still round-trips it. What changes is that nothing paints
/// with it directly any more.
///
/// Shaped after [Rarity] (`rarity.dart`), which WP17 built for the same
/// problem — a stored value that used to be turned into a colour at the call
/// site, replaced by an enum in the theme layer that answers with one. The
/// caller states meaning; the design system answers with a `Color`.
enum SeasonAccent {
  lavender,
  sky,
  mint,
  coral;

  /// The season accent for a stored `themeColor`.
  ///
  /// An exact match on one of the four Butter Bliss accents wins. **Anything
  /// else — including the values live season documents may already carry —
  /// resolves to [lavender]**, which is both a real accent and the register
  /// the season surface already reads as. This is the whole point: an
  /// unrecognised int can no longer reach the screen as a colour.
  factory SeasonAccent.fromThemeColor(int themeColor) =>
      switch (themeColor) {
        _ when themeColor == AppColors.lavender.toARGB32() =>
          SeasonAccent.lavender,
        _ when themeColor == AppColors.sky.toARGB32() => SeasonAccent.sky,
        _ when themeColor == AppColors.mint.toARGB32() => SeasonAccent.mint,
        _ when themeColor == AppColors.coral.toARGB32() => SeasonAccent.coral,
        _ => SeasonAccent.lavender,
      };

  Color get color => switch (this) {
    SeasonAccent.lavender => AppColors.lavender,
    SeasonAccent.sky => AppColors.sky,
    SeasonAccent.mint => AppColors.mint,
    SeasonAccent.coral => AppColors.coral,
  };
}
