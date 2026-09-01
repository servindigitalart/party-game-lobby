// screens/voting_screen.dart
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_phase.dart';
import '../models/player.dart';
import '../providers/game_providers.dart';
import '../core/telemetry/game_telemetry_service.dart';
import '../core/exceptions.dart';
import '../core/game_copy.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_shapes.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/bufon_phase.dart';
import '../core/theme/motion_tokens.dart';
import '../presentation/widgets/game_card.dart';
import '../presentation/widgets/animated_primary_button.dart';
import '../presentation/widgets/bufon_feedback.dart';
import '../presentation/widgets/bufon_loader.dart';
import '../presentation/widgets/bufon_placeholder.dart';
import '../presentation/widgets/bufon_status_panel.dart';
import '../presentation/widgets/game_progress_widgets.dart';
import '../presentation/navigation/page_transitions.dart';
import '../presentation/navigation/room_exit.dart';
import '../presentation/widgets/connection_banner.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import 'round_result_screen.dart';

class VotingScreen extends ConsumerStatefulWidget {
  const VotingScreen({super.key});

  @override
  ConsumerState<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends ConsumerState<VotingScreen> {
  Timer? _autoAdvanceTimer;
  bool _isAdvancing = false;

  /// WP22. One completed transition attempt per screen — see the twin in
  /// `game_screen.dart` for why `_autoAdvanceTimer` alone re-armed itself.
  bool _advanceRequested = false;

  @override
  void initState() {
    super.initState();
    GameTelemetryService.instance.transition('voting');
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _vote(
    BuildContext context,
    WidgetRef ref,
    String roomCode,
    String voterId,
    String votedForId,
  ) async {
    HapticService.mediumImpact();

    try {
      final repository = ref.read(roomRepositoryProvider);
      await repository.submitVoteTransaction(roomCode, voterId, votedForId);

      if (context.mounted) {
        HapticService.success();
        BufonFeedback.show(
          context,
          '¡Voto registrado!',
          tone: BufonFeedbackTone.success,
        );
      }
    } on VotingException catch (e) {
      HapticService.error();
      if (context.mounted) {
        String message = 'Error al votar';
        switch (e.code) {
          case 'ALREADY_VOTED':
            message = 'Ya has votado';
            break;
          case 'SELF_VOTE_FORBIDDEN':
            message = 'No puedes votar por ti mismo';
            break;
          case 'INVALID_PHASE':
            message = 'La votación ya terminó';
            break;
          case 'VOTER_NOT_FOUND':
          case 'VOTED_FOR_NOT_FOUND':
            message = 'Jugador no encontrado';
            break;
          case 'VOTED_FOR_HAS_NO_ANSWER':
            message = 'Esa persona no respondió esta ronda';
            break;
          default:
            message = e.message;
        }

        BufonFeedback.show(context, message);
      }
    } catch (e) {
      HapticService.error();
      if (context.mounted) {
        BufonFeedback.show(
          context,
          'Algo se atoró al registrar tu voto. Inténtalo de nuevo.',
        );
      }
    }
  }

  Future<void> _moveToResults(
    BuildContext context,
    WidgetRef ref,
    String roomCode,
  ) async {
    if (_isAdvancing) return;

    setState(() => _isAdvancing = true);
    try {
      final repository = ref.read(roomRepositoryProvider);
      // WP22 / audit B G-1F, R-10 (sweep variant). Voting was the one stage
      // with no disconnect sweep — `cleanupDisconnectedPlayers` was called
      // from the lobby, from answering and from the round result, and never
      // from here. A player who dropped mid-vote therefore left `votedFor`
      // null on a document nothing would ever remove, and since voting has
      // no clock the room stalled permanently with no recovery path other
      // than everyone leaving.
      //
      // Sweeping first also keeps the client and the server agreeing:
      // `moveToRoundResult` requires every *remaining* document to have
      // voted, so the eligible-player predicate below and that guard are
      // reading the same roster. Same ordering as `_moveToVoting`.
      await repository.cleanupDisconnectedPlayers(roomCode);
      await repository.moveToRoundResult(roomCode);
      SoundService.transition();
    } on RoomException catch (e) {
      // A failed attempt is re-armable; a successful one is not.
      _advanceRequested = false;
      HapticService.error();
      if (context.mounted) {
        BufonFeedback.show(context, _friendlyResultError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isAdvancing = false);
      }
    }
  }

  void _scheduleAutoResults({
    required bool isHost,
    required bool allVoted,
    required String roomCode,
  }) {
    if (!isHost ||
        !allVoted ||
        _isAdvancing ||
        _advanceRequested ||
        _autoAdvanceTimer != null) {
      return;
    }

    _advanceRequested = true;
    _autoAdvanceTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _autoAdvanceTimer = null;
      _moveToResults(context, ref, roomCode);
    });
  }

  String _friendlyResultError(RoomException error) {
    switch (error.code) {
      case 'VOTES_PENDING':
        return 'Todavía falta gente por votar.';
      case 'INVALID_PHASE':
        return 'La ronda ya cambió.';
      case 'ROOM_NOT_FOUND':
        return 'La sala ya no existe.';
    }
    return error.message;
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider);
    final userId = ref.watch(userIdProvider);

    // Track screen view (only once per build with different room)

    // WP25 / R-11. `RoomPopScope` makes Android's back gesture a deliberate
    // leave instead of an accident: every room screen is the root of its own
    // stack (they arrive through `replaceFadeSlide` / `pushAndRemoveAllFade`),
    // so back used to pop the *application* while the player's document, their
    // heartbeat and their room membership all stayed alive.
    return RoomPopScope(
      child: roomAsync.when(
      data: (room) {
        if (room == null) {
          return const Scaffold(
            body: Center(child: Text('Sala no encontrada')),
          );
        }

        if (room.phase == GamePhase.roundResult) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.replaceFadeSlide(const RoundResultScreen());
          });
        }

        final currentPlayer = room.players
            .where((player) => player.id == userId)
            .firstOrNull;
        if (currentPlayer == null) {
          return const Scaffold(
            body: Center(child: Text('Ya no estás en esta sala')),
          );
        }
        final isHost = room.hostId == userId;

        // WP22 / audit B G-1F. Completion is over the players this phase may
        // wait for. Eligibility is *presence*, not participation: a player
        // who did not answer still votes, and their vote is still required.
        //
        // The ballot below is deliberately NOT filtered the same way. A
        // dropped player's answer stays votable — `submitVote` accepts any
        // target with an answer — so narrowing the roster we wait on must not
        // narrow the cards on offer. Different predicates, different jobs.
        final eligible = room.players.eligible.toList();
        final eligibleCount = eligible.length;
        final votedCount = eligible.where((p) => p.votedFor != null).length;
        final allVoted = eligibleCount > 0 && votedCount == eligibleCount;
        final hasVoted = currentPlayer.votedFor != null;

        final shuffledPlayers = List<Player>.from(room.players);
        shuffledPlayers.removeWhere(
          (player) =>
              player.currentAnswer == null ||
              player.currentAnswer!.trim().isEmpty,
        );
        shuffledPlayers.shuffle(Random(room.code.hashCode));

        _scheduleAutoResults(
          isHost: isHost,
          allVoted: allVoted,
          roomCode: room.code,
        );

        // Fase 3E: voting is the Graphite register with Lavender as its
        // single accent (Capítulo 33 — "Estoy juzgando en secreto"). A
        // screenshot of this screen is now distinguishable from the answering
        // screen without reading a word, which is the acceptance criterion.
        return PhaseScope(
          phase: BufonPhase.voting,
          child: Scaffold(
            appBar: AppBar(
              title: RoundIndicator(
                currentRound: room.currentRound,
                totalRounds: room.totalRounds,
              ),
              centerTitle: true,
            ),
            body: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // WP25 / R-37, BP P4: renders nothing while connected, so
                  // every existing layout is unchanged in the normal case.
                  const ConnectionBanner(),
                  // Fase 2B WP5 — the scroll boundary moved outward.
                  //
                  // It used to sit on the answer list alone, which made the
                  // round header, the status block and the CTA all non-flex
                  // siblings of a tight `Expanded`. Once the header grew with
                  // the text scale, `freeSpace` went negative, the `Expanded`
                  // was allotted a negative extent and this Column overflowed
                  // (267 px at 1.4x on a 360x800 phone).
                  //
                  // The question and the answers are one region of content, so
                  // they now scroll together inside the `Expanded`. The status
                  // block and the CTA stay outside it: they are live chrome,
                  // and the vote confirmation must never scroll out of view.
                  //
                  // At 1.0x with content that fits, the scroll view is inert
                  // and every element lands exactly where it did before.
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GameProgressBar(
                            currentRound: room.currentRound,
                            totalRounds: room.totalRounds,
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          Semantics(
                            header: true,
                            child: Text(
                              '¿Cuál es la respuesta más chistosa?',
                              style: AppTypography.h2.copyWith(
                                color: AppColors.paper,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.lavender.withValues(alpha: 0.12),
                              borderRadius: AppShapes.borderRadiusMd,
                              border: AppShapes.hairlineBorder(
                                AppColors.lavender.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              room.currentQuestionText ?? '',
                              style: AppTypography.body1.copyWith(
                                color: AppColors.lavender,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          if (_isAdvancing || allVoted) ...[
                            _VoteTransitionBanner(
                              title: GameCopy.countingVotes,
                              subtitle: 'El juicio social ya está cerrado.',
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],

                          // Part of the page scroll now, not its own scrollable.
                          // Bounded by the answer cap (8 players), so shrink-
                          // wrapping costs nothing.
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: shuffledPlayers.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              final player = shuffledPlayers[index];
                              final isSelected =
                                  currentPlayer.votedFor == player.id;
                              final canVote = !hasVoted && player.id != userId;

                              return TweenAnimationBuilder<double>(
                                duration: Duration(
                                  milliseconds: 200 + (index * 50),
                                ),
                                tween: Tween(begin: 0.0, end: 1.0),
                                curve: Curves.easeOut,
                                builder: (context, value, child) {
                                  return Opacity(
                                    opacity: value,
                                    child: Transform.translate(
                                      offset: Offset(20 * (1 - value), 0),
                                      child: child,
                                    ),
                                  );
                                },
                                // WP26 / R-38, BP P9: the own card is muted and
                                // unvotable, and until now the only thing that
                                // said why lived inside a `Semantics` string —
                                // so a sighted player was told nothing at all.
                                child: GameCard(
                                  text: player.id == userId
                                      ? '${GameCopy.yourAnswerLabel}: '
                                            '${player.currentAnswer ?? "Sin respuesta"}'
                                      : player.currentAnswer ?? 'Sin respuesta',
                                  isSelected: isSelected,
                                  isDisabled: !canVote,
                                  semanticLabel: player.id == userId
                                      ? 'Tu respuesta: ${player.currentAnswer ?? "sin respuesta"}. '
                                            'No puedes votar por ti mismo.'
                                      : null,
                                  onTap: canVote
                                      ? () => _vote(
                                          context,
                                          ref,
                                          room.code,
                                          currentPlayer.id,
                                          player.id,
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  BufonStatusPanel(
                    tone: hasVoted
                        ? BufonStatusTone.confirmed
                        : BufonStatusTone.pending,
                    // The confirmation lands in place, and it is carried
                    // visually by a colour swap plus an icon swap — so
                    // without a label a screen reader is never told the vote
                    // registered. `live` is tied to `hasVoted` because the
                    // flip happens once per player per round; the "toca para
                    // votar" prompt must not be announced.
                    headline: hasVoted
                        ? '¡Voto enviado!'
                        : 'Toca una respuesta para votar',
                    statusLabel: hasVoted
                        ? '¡Voto enviado!'
                        : 'Toca una respuesta para votar',
                    live: hasVoted,
                    // Denominator is the eligible roster too, so the panel
                    // never reports waiting on somebody who has dropped.
                    progress: eligibleCount == 0
                        ? 0
                        : votedCount / eligibleCount,
                    message:
                        '${GameCopy.voteProgress(votedCount, eligibleCount)}\n'
                        '${GameCopy.voteWaiting(votedCount, eligibleCount)}',
                  ),
                  const SizedBox(height: AppSpacing.md),

                  if (isHost && allVoted)
                    AnimatedPrimaryButton(
                      text: _isAdvancing ? 'Contando...' : 'Ver Resultados',
                      onPressed: () => _moveToResults(context, ref, room.code),
                      icon: Icons.emoji_events,
                      backgroundColor: AppColors.mintShade,
                      isLoading: _isAdvancing,
                    ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: BufonLoader())),
      // WP25 / R-11 — see `lobby_screen`. Same dead end, same fix.
      error: (error, stack) => Scaffold(
        body: BufonPlaceholder(
          variant: BufonPlaceholderVariant.error,
          title: 'No se pudo cargar la votación',
          actionLabel: GameCopy.backToHome,
          onAction: () => RoomExit.toHome(context, ref),
        ),
      ),
      ),
    );
  }
}

class _VoteTransitionBanner extends StatelessWidget {
  final String title;
  final String subtitle;

  const _VoteTransitionBanner({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    // Arrive (Capítulo 16). This previously used
    // `AnimatedOpacity(opacity: 1)` with nothing driving the value, so it
    // never animated at all while its twin on the answering screen did.
    return TweenAnimationBuilder<double>(
      duration: MotionDurations.arrive,
      tween: Tween(begin: 0.0, end: 1.0),
      curve: MotionCurves.release,
      builder: (context, value, child) {
        final scale =
            MotionScale.arriveFrom + ((1 - MotionScale.arriveFrom) * value);
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.butter.withValues(alpha: 0.12),
          borderRadius: AppShapes.borderRadiusLg,
          border: AppShapes.hairlineBorder(
            AppColors.butter.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.how_to_vote, color: AppColors.butter),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.h4.copyWith(color: AppColors.butter),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.body2.copyWith(
                      color: AppColors.paper.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
