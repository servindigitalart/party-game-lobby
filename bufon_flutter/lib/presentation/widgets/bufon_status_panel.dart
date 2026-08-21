// presentation/widgets/bufon_status_panel.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/bufon_phase.dart';

/// Where the room is, from the player's point of view.
///
/// Two states, because two states is what the loop screens actually draw.
/// Answering has only the first; Voting swaps between them on `hasVoted`.
/// There is no `error`, `empty` or `loading` value here — those belong to
/// `BufonPlaceholder` and `BufonLoader`, which already own them at 14 call
/// sites each. A third primitive re-implementing them would be the second
/// implementation of an existing feature.
enum BufonStatusTone {
  /// The room is still working. The panel recedes: neutral surface, the
  /// phase's own accent on the bar.
  pending,

  /// This player's part is done, whatever the rest of the room is doing.
  /// Mint — the same confirmation colour `BufonFeedback.success` uses, so a
  /// confirmation reads the same whether it lands in a panel or a snackbar.
  confirmed,
}

/// The answer/vote progress container — implements
/// BUFON_V1.1_VISUAL_BLUEPRINT.md's `BufonStatusPanel`: "one answer/vote
/// progress container; replaces 4 divergent inline versions".
///
/// Before this existed, Answering and Voting hand-rolled the same tinted,
/// hairline-bordered block with a determinate bar and a centred status line,
/// diverging on fill, border alpha and live-region placement.
///
/// **No caller supplies a colour.** [tone] states what is true and the panel
/// resolves the fill, the hairline, the headline and the bar from it and from
/// the ambient register. That is the whole point: the four inline versions
/// diverged precisely because each one picked its own colours.
class BufonStatusPanel extends StatelessWidget {
  /// The status line. One or two short sentences, centred, muted. Every
  /// consumer has one, so it is required.
  final String message;

  /// Determinate fill, 0..1. Null renders no bar — a panel that is only a
  /// status line is still this panel.
  final double? progress;

  /// A short line above the bar, stating what the player themself must do or
  /// has just done. Null renders no headline row.
  ///
  /// The glyph is derived from [tone] rather than passed in: a pending
  /// headline is always an instruction and a confirmed one is always a tick,
  /// so an `icon` parameter would only allow the two to disagree.
  final String? headline;

  final BufonStatusTone tone;

  /// One composite announcement for the whole panel. A screen reader hearing
  /// a headline, a bar percentage and a two-line caption as four unrelated
  /// fragments learns less than it does from one sentence.
  final String? statusLabel;

  /// Announce [statusLabel] as a live region.
  ///
  /// True only in the *resolved* state. While the room is still working the
  /// node stays readable on focus but silent — otherwise a full room fires up
  /// to eight announcements a round, and the rotating waiting copy
  /// re-announces the same state on every rebuild.
  final bool live;

  const BufonStatusPanel({
    super.key,
    required this.message,
    this.progress,
    this.headline,
    this.tone = BufonStatusTone.pending,
    this.statusLabel,
    this.live = false,
  });

  @override
  Widget build(BuildContext context) {
    final phase = context.phase;
    final scheme = Theme.of(context).colorScheme;
    final confirmed = tone == BufonStatusTone.confirmed;

    // Confirmed states carry Mint everywhere; pending states recede into the
    // register and let the phase's own accent carry the bar.
    final Color accent = confirmed ? AppColors.mint : phase.accent;

    final panel = Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: confirmed
            ? AppColors.mint.withValues(alpha: 0.12)
            : scheme.surfaceContainerHighest,
        borderRadius: AppShapes.borderRadiusMd,
        border: AppShapes.hairlineBorder(
          confirmed ? AppColors.mint.withValues(alpha: 0.35) : scheme.outline,
        ),
      ),
      child: Column(
        children: [
          if (headline != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  confirmed ? Icons.check_circle : Icons.touch_app,
                  color: confirmed ? accent : phase.onSurfaceMuted,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.xs),
                // Flexible, not bare: an instruction beside a fixed 20 px
                // glyph overruns a narrow phone once the text scale climbs.
                Flexible(
                  child: Text(
                    headline!,
                    textAlign: TextAlign.center,
                    style: AppTypography.body1.copyWith(
                      color: confirmed ? accent : phase.onSurfaceMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (progress != null) ...[
            LinearProgressIndicator(
              value: progress,
              // The ground showing through the panel. Taking the register's
              // `surface` rather than a literal keeps the recess correct on
              // Paper as well as on Graphite.
              backgroundColor: scheme.surface,
              valueColor: AlwaysStoppedAnimation(accent),
              minHeight: 6,
              // Not AppShapes: derived from the bar's own height (6/2), not a
              // design-token choice — the smallest step (radiusXs = 8) is
              // larger than the bar itself.
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            message,
            style: AppTypography.caption.copyWith(color: phase.onSurfaceMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    if (statusLabel == null) return panel;

    return Semantics(
      label: statusLabel,
      liveRegion: live,
      // One node for the panel. The bar's percentage and the caption restate
      // what the label already says; announced separately they read as
      // unrelated fragments.
      excludeSemantics: true,
      child: panel,
    );
  }
}
