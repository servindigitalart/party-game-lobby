// presentation/widgets/bufon_player_row.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/bufon_phase.dart';

/// One player in a standings list — implements
/// BUFON_V1.1_VISUAL_BLUEPRINT.md's `BufonPlayerRow`, reduced to the part the
/// repository can actually support today.
///
/// **The avatar boundary.** The blueprint asks for "avatar + name + host/online
/// chip". `Player` (models/player.dart) carries `id, name, score,
/// currentAnswer, votedFor, isHost, lastSeen, isOnline` and **no `avatarId`** —
/// the emoji faces elsewhere in the app come from `LeaderboardEntry.avatarId`
/// and `UserProfile.selectedAvatar`, which are different models on different
/// screens. An in-game row therefore cannot show a face without a model and a
/// Firestore field that do not exist, and the blueprint itself lists "avatar
/// assets" as an unmet dependency of this component. What every in-game row
/// draws instead is a disc carrying the player's standing, and that is what
/// [position] renders. `isOnline` is likewise not surfaced: it is written by
/// `ConnectionService` and read by no widget in the app, so a presence dot
/// would be a new feature rather than a consolidation.
///
/// **Display data only.** No `Player`, no `LeaderboardEntry`, no repository,
/// no controller, no provider — the caller flattens its own model into
/// strings, exactly as `BufonPlaceholder` and `GameCard` require. That is also
/// what keeps this from drifting into a leaderboard component: ranking rules,
/// medal ladders and stat labels stay on the screen that owns them.
class BufonPlayerRow extends StatelessWidget {
  /// Standing in the list, 1-based. Rendered in the leading disc.
  final int position;

  final String name;

  /// One supporting line — what this player did this round. Null renders a
  /// single-line row.
  final String? detail;

  /// The row's one trailing figure, already formatted with its unit by the
  /// caller ('30 pts'). A `String` rather than a `Widget` slot on purpose:
  /// a widget slot would hand the caller back the styling this primitive
  /// exists to own.
  final String? trailingLabel;

  /// Marks the row at the top of the standing. The tint is emphasis only —
  /// [position] states the same thing in text, so the standing never depends
  /// on colour alone.
  final bool highlighted;

  const BufonPlayerRow({
    super.key,
    required this.position,
    required this.name,
    this.detail,
    this.trailingLabel,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final phase = context.phase;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      // One node per row. Read as fragments, a row announces a bare number, a
      // name and an unrelated figure with nothing relating them.
      label: [
        'Puesto $position',
        name,
        if (detail != null) detail!,
        if (trailingLabel != null) trailingLabel!,
      ].join(', '),
      excludeSemantics: true,
      child: Card(
        // `null` falls through to cardTheme. Only the leading row is tinted,
        // and with the register's own accent.
        color: highlighted ? phase.accent.withValues(alpha: 0.16) : null,
        child: ListTile(
          leading: CircleAvatar(
            // The ground the card sits on, so the disc reads as a recess in
            // the card rather than a second card.
            backgroundColor: highlighted ? phase.accent : scheme.surface,
            child: Text(
              '$position',
              style: AppTypography.body2.copyWith(
                fontWeight: FontWeight.bold,
                color: highlighted ? phase.onAccent : phase.onSurface,
              ),
            ),
          ),
          title: Text(
            name,
            style: AppTypography.body1.copyWith(
              fontWeight: FontWeight.bold,
              color: phase.onSurface,
            ),
          ),
          subtitle: detail == null
              ? null
              : Text(
                  detail!,
                  style: AppTypography.caption.copyWith(
                    color: phase.onSurfaceMuted,
                  ),
                ),
          trailing: trailingLabel == null
              ? null
              : Text(
                  trailingLabel!,
                  style: AppTypography.body1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: phase.accent,
                  ),
                ),
        ),
      ),
    );
  }
}
