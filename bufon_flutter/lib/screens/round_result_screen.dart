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
import '../presentation/widgets/bufon_loader.dart';
import '../presentation/widgets/bufon_placeholder.dart';
import '../presentation/widgets/bufon_player_row.dart';
import '../presentation/widgets/confetti_widget.dart';
import '../services/haptic_service.dart';
import '../presentation/navigation/page_transitions.dart';
import '../presentation/navigation/room_exit.dart';
import '../presentation/widgets/connection_banner.dart';
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

  /// In-flight guard for [_nextRound].
  ///
  /// WP22 / audit B **G-2F**, reconciled as **R-13**. Its two siblings —
  /// `game_screen._moveToVoting` and `voting_screen._moveToResults` — have
  /// always had this flag; the round-result CTA never did. A double tap
  /// therefore ran `_advanceRound` twice: two question draws (one of which is
  /// discarded, so a question is silently consumed from the round's history
  /// without ever being shown) and two `currentRound + 1` writes off the same
  /// stale snapshot. The phase transitions themselves are transaction-guarded,
  /// but `_advanceRound`'s non-final branch is a whole-document `updateRoom`,
  /// which is not.
  bool _isAdvancing = false;

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
    if (_isAdvancing) return;
    setState(() => _isAdvancing = true);

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
    } finally {
      // `mounted` matters here in a way it does not for the siblings: the
      // successful path navigates away, so this state object is commonly
      // disposed before the flag is cleared.
      if (mounted) setState(() => _isAdvancing = false);
    }
  }

  Future<void> _advanceRound(String roomCode) async {
    final repository = ref.read(roomRepositoryProvider);

    final room = await repository.cleanupDisconnectedPlayers(roomCode);
    if (room == null) return;

    final questionService = ref.read(questionServiceProvider);

    // WP23 / audit B G-2E. A host promoted mid-game by
    // `cleanupDisconnectedPlayers` reaches this path with its own
    // `QuestionService`, which never loaded the corpus because it was never
    // the device that passed through the lobby. Without this the promoted
    // host draws from an empty list.
    if (questionService.getAllQuestions().isEmpty) {
      await questionService.loadQuestions();
    }

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

    // WP23 / R-18: the room's history, not this device's. The old
    // `usedQuestionIdsProvider` lived in the host's memory, so a host handover
    // handed the next draw to a device with a different — usually empty —
    // list, and the room could re-ask a question it had already used.
    final question = questionService.getRandomQuestion(
      currentRoom.usedQuestionIds,
    );

    // WP23 / audit B X-3: a transactional, field-level write replaces
    // `updateRoom(room.copyWith(...))`, which rewrote the whole document from
    // a stale snapshot — including the monetisation fields the server owns —
    // and computed `currentRound + 1` on the client. Both now happen inside
    // the transaction, from its own read.
    await repository.advanceToNextRound(
      roomCode: roomCode,
      questionId: question.id,
      questionText: question.text,
    );
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
            body: BufonPlaceholder(
              variant: BufonPlaceholderVariant.error,
              title: 'Sala no encontrada',
            ),
          );
        }

        if (room.players.isEmpty) {
          return const Scaffold(
            body: BufonPlaceholder(title: 'No hay jugadores en la sala'),
          );
        }

        if (room.phase == GamePhase.answering) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.replaceFadeSlide(const GameScreen());
          });
        } else if (room.phase == GamePhase.finalWinner) {
          final sortedPlayers = [...room.players]
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
                // Already sorted and already in memory — the ceremony's
                // standings section needs no query of its own.
                standings: sortedPlayers,
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
                    // WP25 / R-37, BP P4: renders nothing while connected, so
                    // every existing layout is unchanged in the normal case.
                    const ConnectionBanner(),
                    // Fase 2B WP5 — the scroll boundary moved outward.
                    //
                    // The spotlight is the most text-scale-sensitive block in
                    // the app (a display-size name over a multi-line answer),
                    // and it sat as a non-flex sibling of a tight flex child:
                    // `Expanded(_NightScoreboard)` after stage 2, `Spacer()`
                    // before it. Once the spotlight outgrew the space left
                    // over, that child was allotted a negative extent and this
                    // Column overflowed — at 1.0x already, with a full
                    // eight-player room.
                    //
                    // Spotlight and scoreboard are one region of content, so
                    // they scroll together inside the `Expanded`. The CTA
                    // stays outside it and stays reachable.
                    //
                    // The `Spacer` that used to hold the button at the bottom
                    // before stage 2 is gone: this `Expanded` does that job in
                    // both stages, which is what the Spacer's comment asked
                    // for, and it cannot go negative.
                    Expanded(
                      child: SingleChildScrollView(
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
                              Semantics(
                                header: true,
                                child: Text(
                                  'Marcador de la noche',
                                  style: AppTypography.h4.copyWith(
                                    color: phase.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _NightScoreboard(
                                players: sortedPlayers,
                                voteCounts: voteCounts,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (isHost)
                      AnimatedPrimaryButton(
                        text: room.currentRound >= room.totalRounds
                            ? 'Coronar al BUFÓN'
                            : 'Soltar la siguiente',
                        onPressed: _isAdvancing
                            ? null
                            : () => _nextRound(room.code),
                        isLoading: _isAdvancing,
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
      loading: () => const Scaffold(body: Center(child: BufonLoader())),
      // WP25 / R-11 — see `lobby_screen`. Same dead end, same fix.
      error: (error, stack) => Scaffold(
        body: BufonPlaceholder(
          variant: BufonPlaceholderVariant.error,
          title: 'No se pudo cargar el resultado',
          actionLabel: GameCopy.backToHome,
          onAction: () => RoomExit.toHome(context, ref),
        ),
      ),
    );

    // Wrapped around `when` rather than around each branch so the loading
    // and error states inherit the register too — otherwise a slow stream
    // flashed a differently-themed Scaffold in the middle of a round.
    // WP25 / R-11. `RoomPopScope` makes Android's back gesture a deliberate
    // leave instead of an accident: every room screen is the root of its own
    // stack (they arrive through `replaceFadeSlide` / `pushAndRemoveAllFade`),
    // so back used to pop the *application* while the player's document, their
    // heartbeat and their room membership all stayed alive.
    return RoomPopScope(
      child: PhaseScope(phase: phase, child: content),
    );
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
    // Fase 2B WP5: part of the screen's page scroll now rather than its own
    // scrollable, so the spotlight above it can grow with the text scale
    // instead of squeezing this list to a negative height. Bounded by the
    // eight-player room cap, so shrink-wrapping costs nothing.
    final list = ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: players.length,
      itemBuilder: (context, index) {
        final player = players[index];
        final position = index + 1;

        return BufonPlayerRow(
          position: position,
          name: player.name,
          detail: '${voteCounts[player.id] ?? 0} votos esta ronda',
          trailingLabel: '${player.score} pts',
          // Only the leader row is tinted, and with the register's accent
          // rather than the retired `gold`.
          highlighted: position == 1,
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
        border: AppShapes.hairlineBorder(phase.accent.withValues(alpha: 0.45)),
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
                // The payoff of the whole screen, and it lands *in place* —
                // no navigation happens, so without a live region a screen
                // reader is never told the reveal finished. It fires exactly
                // once: this branch is only built at stage 2, and the label is
                // fixed for the round, so there is nothing to re-announce.
                : Semantics(
                    key: ValueKey('author-$winnerName'),
                    liveRegion: true,
                    label: '$winnerName, $votesReceived votos recibidos',
                    excludeSemantics: true,
                    child: Column(
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
