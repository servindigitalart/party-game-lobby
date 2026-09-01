// presentation/widgets/connection_banner.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game_copy.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/bufon_phase.dart';
import '../../providers/game_providers.dart';

/// Says out loud what `ConnectionService` has always known privately.
///
/// WP25 / **R-37**, Blueprint **P4** (*"Connectivity banner on the loop —
/// LOW visual / **HIGH** UX … Uses the existing `ConnectionService`"*). The
/// service has beaten every 10 s since launch and escalated a lost connection
/// to telemetry, but the Blueprint's own component table records its UI as
/// *"Heartbeat only, no UI"* — so the player it was tracking could not see
/// any of it. Audit A **H-2**'s confusion, where a room quietly evaporates
/// after an app switch, had no explanation on screen at all.
///
/// **Renders nothing while connected**, so every existing layout — including
/// the large-text and viewport matrices WP4/WP5 established — is unchanged in
/// the normal case. It occupies space only when there is something to say.
///
/// No new dependency and no new service, per R-37's non-goals: it listens to
/// the `ValueNotifier` on the service that already exists, which mirrors the
/// same two-missed-beats definition `cleanupDisconnectedPlayers` evicts on.
/// There is no second opinion here about what "disconnected" means.
class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionServiceProvider);
    final phase = context.phase;

    return ValueListenableBuilder<bool>(
      valueListenable: connection.connectionLost,
      builder: (context, lost, _) {
        if (!lost) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              // The register's own muted surface: this is a status, not a
              // failure, and Capítulo 4 allows one accent per screen — which
              // the phase already spends elsewhere.
              color: phase.onSurface.withValues(alpha: 0.08),
              borderRadius: AppShapes.borderRadiusMd,
              border: AppShapes.hairlineBorder(
                phase.onSurface.withValues(alpha: 0.18),
              ),
            ),
            child: Semantics(
              // One node, and a live one: the whole point is that the player
              // is told without having to go looking.
              liveRegion: true,
              label: GameCopy.connectionLost,
              excludeSemantics: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 18,
                    color: phase.onSurfaceMuted,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      GameCopy.connectionLost,
                      style: AppTypography.caption.copyWith(
                        color: phase.onSurfaceMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
