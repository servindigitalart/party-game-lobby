// screens/round_result_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_copy.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_elevation.dart';
import '../core/theme/app_shapes.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/bufon_phase.dart';
import '../core/theme/motion_tokens.dart';
import '../core/theme/reduced_motion.dart';
import '../models/game_phase.dart';
import '../models/player.dart';
import '../providers/game_providers.dart';
import '../core/telemetry/game_telemetry_service.dart';
import '../core/logging/log_category.dart';
import '../presentation/transitions/keyhole_reveal_transition.dart';
import '../presentation/widgets/animated_primary_button.dart';
import '../presentation/widgets/confetti_widget.dart';
import '../services/haptic_service.dart';
import '../presentation/navigation/page_transitions.dart';
import '../services/sound_service.dart';
import 'final_winner_screen.dart';
import 'game_screen.dart';

class RoundResultScreen extends ConsumerStatefulWidget {
  const RoundResultScreen({super.key});

  @override
  ConsumerState<RoundResultScreen> createState() => _RoundResultScreenState();
}

class _RoundResultScreenState extends ConsumerState<RoundResultScreen>
    with SingleTickerProviderStateMixin {
  int _revealStage = 0;
  final List<Timer> _revealTimers = [];

  /// Drives the "mirilla" mask (`BRAND PHYSICS`: "el reveal como mirilla").
  /// The keyhole cut into the isotype's hat bells means "this holds a secret
  /// until it decides to reveal it", which is literally this screen's job.
  /// The transition widget has existed since commit ca79281 and had never
  /// rendered a frame; this is what drives it.
  late final AnimationController _keyholeController;

  /// The curved view of [_keyholeController] handed to the transition.
  /// Separate field so it is disposed explicitly — a [CurvedAnimation] keeps
  /// a listener on its parent.
  late final CurvedAnimation _keyholeProgress;

  @override
  void initState() {
    super.initState();
    GameTelemetryService.instance.transition('round_result');
    _keyholeController = AnimationController(
      // Capítulo 17, tier Dramática — one stage of a Reveal.
      duration: MotionDurations.revealStage,
      vsync: this,
    );
    _keyholeProgress = CurvedAnimation(
      parent: _keyholeController,
      curve: MotionCurves.reveal,
    );
    _revealTimers.add(
      Timer(const Duration(milliseconds: 750), () {
        if (!mounted) return;
        setState(() => _revealStage = 1);
        // An opening, not a spring: easeOut suits an unveiling, whereas the
        // compress/release pair belongs to touch feedback.
        _keyholeController.forward();
        HapticService.lightImpact();
        SoundService.reveal();
      }),
    );
    _revealTimers.add(
      Timer(const Duration(milliseconds: 1550), () {
        if (!mounted) return;
        setState(() => _revealStage = 2);
        HapticService.celebration();
        SoundService.celebration();
      }),
    );
  }

  @override
  void dispose() {
    for (final timer in _revealTimers) {
      timer.cancel();
    }
    _keyholeProgress.dispose();
    _keyholeController.dispose();
    super.dispose();
  }

  Future<void> _nextRound(String roomCode) async {
    // This advances the whole room for every player, so a failure here
    // strands the match. It previously had no catch at all: the exception
    // escaped into the zone and would now be reported as a fatal crash even
    // though the app keeps running.
    try {
      await _advanceRound(roomCode);
    } catch (e, stackTrace) {
      GameTelemetryService.instance.fail(
        AppLogCategory.gameplay,
        'advance_round_failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _advanceRound(String roomCode) async {
    final repository = ref.read(roomRepositoryProvider);

    final room = await repository.cleanupDisconnectedPlayers(roomCode);
    if (room == null) return;

    final questionService = ref.read(questionServiceProvider);
    final roomAsync = ref.read(roomStreamProvider);
    final currentRoom = roomAsync.value;
    if (currentRoom == null) return;

    if (currentRoom.currentRound >= currentRoom.totalRounds) {
      final didFinish = await repository.finishGame(roomCode);
      final gameController = ref.read(gameControllerProvider);
      if (didFinish) {
        await gameController.completeGame(roomCode);
      }
      return;
    }

    await repository.clearRoundData(roomCode);

    final usedIds = ref.read(usedQuestionIdsProvider);
    final question = questionService.getRandomQuestion(usedIds);
    ref.read(usedQuestionIdsProvider.notifier).state = [
      ...usedIds,
      question.id,
    ];

    final updatedRoom = currentRoom.copyWith(
      phase: GamePhase.answering,
      currentQuestionId: question.id,
      currentQuestionText: question.text,
      currentRound: currentRoom.currentRound + 1,
      roundStartTime: DateTime.now(),
    );

    await repository.updateRoom(updatedRoom);
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider);
    final userId = ref.watch(userIdProvider);

    // `context` here sits *above* the PhaseScope this method returns, so
    // `context.phase` would still read `legacy`. The register is named
    // directly instead; every descendant below the scope uses `context.phase`.
    const phase = BufonPhase.reveal;

    final content = roomAsync.when(
      data: (room) {
        if (room == null) {
          return const Scaffold(
            body: Center(child: Text('Sala no encontrada')),
          );
        }

        if (room.players.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('No hay jugadores en la sala')),
          );
        }

        if (room.phase == GamePhase.answering) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.replaceFadeSlide(const GameScreen());
          });
        } else if (room.phase == GamePhase.finalWinner) {
          final sortedPlayers = List.from(room.players)
            ..sort((a, b) => b.score.compareTo(a.score));
          final winner = sortedPlayers.first;
          final votesReceived = room.players
              .where((player) => player.votedFor == winner.id)
              .length;

          // Progression is not triggered from here any more. The
          // `onMatchCompleted` Cloud Function fires on the same
          // phase → finalWinner transition and awards XP, achievements,
          // titles and leaderboard positions with the Admin SDK. A client
          // cannot be trusted with any of it, and firestore.rules now
          // forbids those writes outright.

          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.replaceFadeSlide(
              FinalWinnerScreen(
                winnerName: winner.name,
                // The winner's own equipped avatar can only be resolved by
                // the winner's own device: firestore.rules restricts
                // /users/{uid} reads to `request.auth.uid == userId`, so a
                // non-winner cannot read it and the client cannot be given
                // it here. FinalWinnerScreen therefore shows the default
                // avatar for *every* winner — the per-viewer fallback this
                // comment previously claimed existed does not: that screen
                // does a flat `Avatars.all.firstWhere` on this id, with no
                // profile lookup. Unblocking needs a product decision
                // (denormalise the equipped avatar onto the room's player
                // doc, or relax the rule); see PHASE_2A_RECOVERY_REPORT.md.
                winnerAvatarId: 'default',
                votesReceived: votesReceived,
                totalScore: winner.score,
                isCurrentUserWinner: winner.id == userId,
              ),
            );
          });
        }

        final isHost = room.hostId == userId;
        final voteCounts = <String, int>{};
        for (final player in room.players) {
          final votedFor = player.votedFor;
          if (votedFor != null) {
            voteCounts[votedFor] = (voteCounts[votedFor] ?? 0) + 1;
          }
        }

        // Spread rather than `List.from`, which erases to `List<dynamic>` —
        // the scoreboard is its own widget now and needs a real element type.
        final sortedPlayers = [...room.players]
          ..sort((a, b) => b.score.compareTo(a.score));

        final roundSortedPlayers = List.from(room.players)
          ..sort((a, b) {
            final voteCompare = (voteCounts[b.id] ?? 0).compareTo(
              voteCounts[a.id] ?? 0,
            );
            if (voteCompare != 0) return voteCompare;
            return b.score.compareTo(a.score);
          });

        final winner = roundSortedPlayers.first;
        final winningAnswer = winner.currentAnswer ?? 'Sin respuesta';
        final votesReceived = voteCounts[winner.id] ?? 0;

        return Scaffold(
          // Surfaces come from the register's ThemeData now (Graphite), not
          // from the legacy casino palette.
          appBar: AppBar(
            title: Text('Resultados - Ronda ${room.currentRound}'),
          ),
          body: Stack(
            children: [
              ConfettiWidget(
                isActive: _revealStage >= 2,
                tier: ConfettiTier.round,
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 650),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeOutBack,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.92 + (value * 0.08),
                            child: child,
                          ),
                        );
                      },
                      child: _WinnerSpotlight(
                        winnerName: winner.name,
                        answer: winningAnswer,
                        votesReceived: votesReceived,
                        revealStage: _revealStage,
                        keyholeProgress: _keyholeProgress,
                      ),
                    ),

                    // THE GATE. The scoreboard's `#1` row identifies the
                    // winner, so rendering it from stage 0 — as this screen
                    // did until Fase 2A — let a player read the answer off
                    // the bottom of the screen during the 800 ms of
                    // engineered suspense above it. Capítulo 35 Fase 3F's
                    // acceptance criterion is explicit: "el scoreboard no es
                    // visible hasta que termina la etapa 2 del reveal."
                    //
                    // Not built at all before stage 2, rather than hidden
                    // with opacity: an invisible widget is still in the
                    // semantics tree, so a screen-reader user would have had
                    // the reveal spoiled by a fix that looked correct.
                    if (_revealStage >= 2) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Marcador de la noche',
                        style: AppTypography.h4.copyWith(
                          color: phase.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Expanded(
                        child: _NightScoreboard(
                          players: sortedPlayers,
                          voteCounts: voteCounts,
                        ),
                      ),
                    ] else
                      // Holds the button at the bottom so the spotlight does
                      // not jump when the scoreboard arrives.
                      const Spacer(),
                    const SizedBox(height: AppSpacing.md),
                    if (isHost)
                      AnimatedPrimaryButton(
                        text: room.currentRound >= room.totalRounds
                            ? 'Coronar al BUFÓN'
                            : 'Soltar la siguiente',
                        onPressed: () => _nextRound(room.code),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.graphitePlus1,
                          borderRadius: AppShapes.borderRadiusMd,
                          border: AppShapes.hairlineBorder(
                            phase.onSurface.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Text(
                          '${GameCopy.nextRound}\nEl host trae la siguiente carta.',
                          textAlign: TextAlign.center,
                          style: AppTypography.body2.copyWith(
                            color: phase.onSurfaceMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) =>
          Scaffold(body: Center(child: Text('Error: $error'))),
    );

    // Wrapped around `when` rather than around each branch so the loading
    // and error states inherit the register too — otherwise a slow stream
    // flashed a differently-themed Scaffold in the middle of a round.
    return PhaseScope(phase: phase, child: content);
  }
}

/// The cumulative night scoreboard.
///
/// Extracted from `build` in Fase 2A because it is now conditionally
/// mounted (see THE GATE) and needs its own entrance — inline, the Arrive
/// wrapper would have sat three levels deep inside an `if` inside a `Column`.
/// Presentation only: ordering, scores and vote counts are all computed by
/// the caller exactly as before.
class _NightScoreboard extends StatelessWidget {
  final List<Player> players;
  final Map<String, int> voteCounts;

  const _NightScoreboard({required this.players, required this.voteCounts});

  @override
  Widget build(BuildContext context) {
    final phase = context.phase;

    final list = ListView.builder(
      itemCount: players.length,
      itemBuilder: (context, index) {
        final player = players[index];
        final position = index + 1;
        final roundVotes = voteCounts[player.id] ?? 0;
        final isLeader = position == 1;

        return Card(
          // `null` falls through to cardTheme (Graphite+1). Only the leader
          // row is tinted, and with the register's accent rather than the
          // retired `gold`.
          color: isLeader ? phase.accent.withValues(alpha: 0.16) : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isLeader ? phase.accent : AppColors.graphite,
              child: Text(
                '$position',
                style: AppTypography.body2.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isLeader ? phase.onAccent : phase.onSurface,
                ),
              ),
            ),
            title: Text(
              player.name,
              style: AppTypography.body1.copyWith(
                fontWeight: FontWeight.bold,
                color: phase.onSurface,
              ),
            ),
            subtitle: Text(
              '$roundVotes votos esta ronda',
              style: AppTypography.caption.copyWith(
                color: phase.onSurfaceMuted,
              ),
            ),
            trailing: Text(
              '${player.score} pts',
              style: AppTypography.body1.copyWith(
                fontWeight: FontWeight.bold,
                color: phase.accent,
              ),
            ),
          ),
        );
      },
    );

    // Arrive from below (Capítulo 16/23) — the scoreboard enters *after* the
    // reveal has landed, so it should read as arriving rather than as having
    // been there all along. Reduced motion gets the end state directly.
    if (context.reduceMotion) return list;

    return TweenAnimationBuilder<double>(
      duration: MotionDurations.arrive,
      curve: MotionCurves.settle,
      tween: Tween(begin: 1.0, end: 0.0),
      builder: (context, value, child) => Opacity(
        opacity: 1 - value,
        child: Transform.translate(
          offset: Offset(0, value * AppSpacing.xl),
          child: child,
        ),
      ),
      child: list,
    );
  }
}

class _WinnerSpotlight extends StatelessWidget {
  final String winnerName;
  final String answer;
  final int votesReceived;
  final int revealStage;

  /// Drives the keyhole mask over the winning answer. Owned by the screen
  /// (it is tied to the stage-1 timer), passed down rather than rebuilt here.
  final Animation<double> keyholeProgress;

  const _WinnerSpotlight({
    required this.winnerName,
    required this.answer,
    required this.votesReceived,
    required this.revealStage,
    required this.keyholeProgress,
  });

  @override
  Widget build(BuildContext context) {
    final phase = context.phase;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        // Flat Graphite+1, not the retired gold gradient: Capítulo 3 ley 1
        // allows a gradient only in the ceremonial layer (the Ganador de la
        // Noche screen), and `gold` is not a Butter Bliss colour at all.
        // What makes this the Protagonist is the accent hairline and the
        // accent-tinted shadow, per Capítulo 8.
        color: AppColors.graphitePlus1,
        borderRadius: AppShapes.borderRadiusXl,
        border: AppShapes.hairlineBorder(
          phase.accent.withValues(alpha: 0.45),
        ),
        boxShadow: AppElevation.protagonistShadow(phase.accent),
      ),
      child: Column(
        children: [
          Icon(
            revealStage >= 2 ? Icons.theater_comedy : Icons.visibility,
            size: 46,
            color: phase.accent,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            revealStage >= 2
                ? 'Y el BUFÓN detrás de eso fue...'
                : 'La respuesta ganadora fue...',
            style: AppTypography.body1.copyWith(
              color: phase.onSurface,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.97, end: 1).animate(animation),
                  child: child,
                ),
              );
            },
            child: revealStage == 0
                ? Text(
                    '...',
                    key: const ValueKey('anticipation'),
                    style: AppTypography.display.copyWith(
                      color: phase.onSurfaceMuted,
                    ),
                    textAlign: TextAlign.center,
                  )
                // Stage 1: the answer *opens* through the keyhole mask
                // instead of merely fading in. This is the brand's declared
                // signature gesture — the isotype's hat bells carry a
                // keyhole cut meaning "this holds a secret until it decides
                // to reveal it" — and `KeyholeRevealTransition` had existed
                // since commit ca79281 without ever rendering a frame.
                //
                // The ClipRRect keeps the backdrop's corners on the same
                // radius as the panel (Capítulo 9: cero esquinas rectas);
                // without it the mask would open against a square hole.
                : ClipRRect(
                    key: ValueKey('answer-$answer'),
                    borderRadius: AppShapes.borderRadiusMd,
                    child: KeyholeRevealTransition(
                      // Capítulo 28: a Reveal must have a reduced version.
                      // Pinning progress to 1.0 skips the mask entirely and
                      // leaves the AnimatedSwitcher's cross-fade above as the
                      // whole animation, which is exactly the "cross-fade
                      // simple" the chapter asks for.
                      progress: context.motion<Animation<double>>(
                        full: keyholeProgress,
                        reduced: const AlwaysStoppedAnimation(1.0),
                      ),
                      // Darkest tone in the register, so the unopened mask
                      // reads as a hole in the card rather than a gap.
                      backdropColor: AppColors.graphiteShade,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: const BoxDecoration(
                          color: AppColors.graphite,
                          borderRadius: AppShapes.borderRadiusMd,
                        ),
                        child: Text(
                          '"$answer"',
                          style: AppTypography.h4.copyWith(
                            color: phase.onSurface,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            child: revealStage < 2
                ? Text(
                    'Preparando el señalamiento...',
                    key: const ValueKey('author-hidden'),
                    style: AppTypography.body2.copyWith(
                      color: phase.onSurfaceMuted,
                    ),
                    textAlign: TextAlign.center,
                  )
                : Column(
                    key: ValueKey('author-$winnerName'),
                    children: [
                      Text(
                        winnerName,
                        // The blueprint's `displayButter`: the accent is
                        // spent on the one word the whole screen exists to
                        // deliver, and on nothing else (Capítulo 4 — un solo
                        // protagonista de color por pantalla).
                        style: AppTypography.display.copyWith(
                          color: phase.accent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '$votesReceived votos recibidos',
                        style: AppTypography.body2.copyWith(
                          color: phase.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
          if (revealStage >= 2) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              GameCopy.roundWinnerPrefix,
              style: AppTypography.caption.copyWith(
                color: phase.onSurfaceMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
