// presentation/widgets/bufon_feedback.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// The two things a transient message in Bufón ever says.
///
/// The blueprint's `BufonFeedback` sketch (COMPONENT_INVENTORY.md §3) proposed
/// reading the tone "from the phase accent". The repository says otherwise:
/// across all 21 hand-built snackbars, success is Mint and failure is Coral on
/// *every* register — Home, Lobby, Answering, Voting, Profile, Paywall. That is
/// correct and this primitive keeps it. An error has to look like an error on
/// the screen it happens on; if feedback took the phase accent, a failure on
/// Home would be Butter and a failure on Voting would be Lavender.
enum BufonFeedbackTone {
  /// Something the player did landed. Mint.
  success,

  /// Something failed, was rejected, or is missing. Coral.
  ///
  /// `game_screen`'s empty-answer guard is deliberately folded in here: it
  /// fires `HapticService.warning()` but has always painted `coralShade`, so a
  /// third tone would be the only visual state in the app with no precedent.
  error,
}

/// One entry point for transient feedback — implements
/// BUFON_V1.1_VISUAL_BLUEPRINT.md's `BufonFeedback`: "one toast/snackbar entry
/// point; replaces 12 call sites with 5 colour sources". The count has since
/// grown to 21 call sites drawing from eight different colour sources
/// (`coral`, `coralShade`, `mintShade`, `AppColors.success`, `AppColors.error`,
/// `Colors.green`, `Colors.red.shade700`, and the bare theme default).
///
/// **The caller states meaning; this class decides appearance.** There is no
/// colour, shape, elevation, icon, action or behaviour parameter, and there is
/// no `duration`. A feedback surface that can be restyled per call site is how
/// eight colour sources happen in the first place.
///
/// Deliberately *not* a notification framework: no queue, no priorities, no
/// `SnackBarAction`. The codebase contains zero `SnackBarAction` uses, so an
/// action API would be pure speculation.
///
/// Haptics stay at the call site. They are paired with only 11 of the 21
/// snackbars; folding them in would silently add haptics to the other 10,
/// which is a behaviour change rather than a de-duplication.
class BufonFeedback {
  BufonFeedback._();

  /// A confirmation is read and forgotten; the two success snackbars that
  /// already set a duration both chose one second.
  static const Duration _successDuration = Duration(seconds: 1);

  /// Material's own default, stated explicitly so the difference from
  /// [_successDuration] is a decision rather than an omission.
  static const Duration _errorDuration = Duration(seconds: 4);

  /// Fill for [tone]. Register-independent on purpose — see [BufonFeedbackTone].
  static Color _surface(BufonFeedbackTone tone) => switch (tone) {
    BufonFeedbackTone.success => AppColors.mintShade,
    BufonFeedbackTone.error => AppColors.coralShade,
  };

  /// Ink, not Paper, on both fills.
  ///
  /// Every existing call site overrode `backgroundColor` but left the text to
  /// `snackBarTheme.contentTextStyle`, which resolves to Paper
  /// (`onInverseSurface`). Paper measures 3.33:1 on `mintShade` and 3.36:1 on
  /// `coralShade` — below the 4.5:1 floor for body text. Ink measures 5.06:1
  /// and 5.01:1 on the same two fills. Capítulo 5 already says text over a
  /// brand colour is Ink; this is that rule applied to the one surface that
  /// had escaped it. Asserted in the tests, not just claimed here.
  static const Color _onSurface = AppColors.ink;

  /// Shows [message] with the presentation [tone] implies.
  ///
  /// **Everything is resolved eagerly, here, from the caller's [context].**
  /// `ScaffoldMessenger.of(context)` walks up to the root messenger created by
  /// `MaterialApp`, which sits *outside* every `PhaseScope` — a `SnackBar`
  /// therefore builds in a context whose register is not the calling screen's.
  /// Nothing below may be deferred to a `Builder` or left to the ambient
  /// theme, or a snackbar raised from a Graphite screen would be styled by the
  /// root's light theme. The fully-formed `SnackBar` is handed over; the
  /// messenger is given no styling decisions to make.
  static void show(
    BuildContext context,
    String message, {
    BufonFeedbackTone tone = BufonFeedbackTone.error,
  }) {
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          // Explicit, so the root theme's `contentTextStyle` cannot supply a
          // foreground chosen for a different background than the one above.
          style: AppTypography.body1.copyWith(color: _onSurface),
        ),
        backgroundColor: _surface(tone),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        duration: tone == BufonFeedbackTone.success
            ? _successDuration
            : _errorDuration,
      ),
    );
  }
}
