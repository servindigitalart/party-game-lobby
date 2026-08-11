import 'package:flutter/material.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/bufon_phase.dart';

/// Round progress indicator showing current round and total rounds.
///
/// Fase 2A: recoloured onto the active phase register (it previously used the
/// legacy casino surface and red accent, which would have read as a stray
/// navy pill on a Graphite screen). Tabular figures added so the round number
/// does not shift width as it changes (Capítulo 6). Shape moved to a pill
/// (Capítulo 9).
///
/// Known, deliberately deferred: `Icons.sports_esports` is a gamepad, which
/// frames Bufón as a video game rather than a table game — the audit calls it
/// a semantic mis-pick. Substituting it needs the custom glyph set
/// (Capítulo 12), which is a later phase, so it is left untouched here rather
/// than swapped for another guess.
class RoundIndicator extends StatelessWidget {
  final int currentRound;
  final int totalRounds;

  const RoundIndicator({
    super.key,
    required this.currentRound,
    required this.totalRounds,
  });

  @override
  Widget build(BuildContext context) {
    final phase = context.phase;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Ronda $currentRound de $totalRounds',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: AppShapes.borderRadiusFull,
          border: AppShapes.hairlineBorder(scheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_esports, color: phase.accent, size: 20),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Ronda ',
              style: AppTypography.body2.copyWith(
                color: phase.onSurfaceMuted,
              ),
            ),
            Text(
              '$currentRound',
              style: AppTypography.tabular(AppTypography.body1).copyWith(
                color: phase.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '/$totalRounds',
              style: AppTypography.tabular(AppTypography.body2).copyWith(
                color: phase.onSurfaceMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Progress bar for game completion
class GameProgressBar extends StatelessWidget {
  final int currentRound;
  final int totalRounds;

  const GameProgressBar({
    super.key,
    required this.currentRound,
    required this.totalRounds,
  });

  @override
  Widget build(BuildContext context) {
    final phase = context.phase;
    final scheme = Theme.of(context).colorScheme;
    final progress = totalRounds == 0 ? 0.0 : currentRound / totalRounds;

    return Column(
      children: [
        Row(
          children: List.generate(totalRounds, (index) {
            final isCompleted = index < currentRound - 1;
            final isCurrent = index == currentRound - 1;

            return Expanded(
              child: Container(
                margin: EdgeInsets.only(
                  right: index < totalRounds - 1 ? AppSpacing.xs : 0,
                ),
                height: 6,
                decoration: BoxDecoration(
                  // The current round now reads differently from a finished
                  // one — previously `isCompleted || isCurrent` painted both
                  // identically, so a player could not see where they were.
                  color: isCurrent
                      ? phase.accent
                      : isCompleted
                      ? phase.accent.withValues(alpha: 0.45)
                      : scheme.surfaceContainerHighest,
                  // Intentionally not AppShapes: this radius is derived
                  // from the segment's own height (6/2 = 3 for a full
                  // stadium cap on a bar this thin), not a design-token
                  // choice — the smallest AppShapes step (radiusXs = 8)
                  // would be larger than the segment itself and clip oddly.
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ronda $currentRound de $totalRounds',
              style: AppTypography.caption.copyWith(
                color: phase.onSurfaceMuted,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: AppTypography.tabular(AppTypography.caption).copyWith(
                color: phase.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
