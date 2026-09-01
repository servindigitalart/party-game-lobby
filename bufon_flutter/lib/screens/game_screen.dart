// screens/game_screen.dart
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
import '../core/theme/app_elevation.dart';
import '../core/theme/app_shapes.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/bufon_phase.dart';
import '../core/theme/motion_tokens.dart';
import '../presentation/widgets/timer_widget.dart';
import '../presentation/widgets/animated_primary_button.dart';
import '../presentation/widgets/bufon_feedback.dart';
import '../presentation/widgets/bufon_loader.dart';
import '../presentation/widgets/bufon_placeholder.dart';
import '../presentation/widgets/bufon_status_panel.dart';
import '../presentation/widgets/game_progress_widgets.dart';
import '../presentation/navigation/page_transitions.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import 'voting_screen.dart';
import 'home_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final _answerController = TextEditingController();
  Timer? _timer;
  Timer? _autoAdvanceTimer;
  /// Placeholder for the single frame before the room snapshot arrives.
  ///
  /// `_startTimer` recomputes this from `room.roundStartTime` and
  /// `room.roundDuration` on the first post-frame callback, so this value is
  /// never used for a decision — it is kept in step with
  /// `Room.roundDuration`'s default (WP23 / PD-1: 60 s) purely so the first
  /// painted frame does not show a number the round will never have.
  int _remainingSeconds = 60;
  bool _isAdvancing = false;

  /// WP22. One completed transition attempt per screen.
  ///
  /// `_autoAdvanceTimer` alone was not enough: it nulls itself inside its own
  /// callback, and `_moveToVoting`'s `finally` calls `setState`, so the
  /// rebuild that follows a *successful* advance re-armed the timer and fired
  /// a second transition two seconds later. The server rejected it with
  /// `INVALID_PHASE`, so the room was never harmed — but the client was
  /// asking again for something it had already achieved, and audit B §9.3
  /// asks for "auto-advance fires once, not repeatedly".
  ///
  /// Cleared only on failure, so a genuine transient error can still be
  /// retried by the next trigger. On success it stays set and the screen is
  /// replaced by the phase change anyway.
  bool _advanceRequested = false;

  @override
  void initState() {
    super.initState();
    GameTelemetryService.instance.transition('game');
  }

  @override
  void dispose() {
    _answerController.dispose();
    _timer?.cancel();
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  void _navigateToHomeWithMessage(String message) {
    if (!mounted) return;

    final connectionService = ref.read(connectionServiceProvider);
    connectionService.stopHeartbeat();

    ref.read(roomCodeProvider.notifier).state = null;

    // Before the navigation, for the same reason as `lobby_screen`: the root
    // messenger sits above the Navigator, so a message handed over now
    // survives the retreat, while one scheduled after it was discarded by a
    // `mounted` guard on an already-disposed route.
    BufonFeedback.show(context, message);

    // Leaving the room is a retreat (Capítulo 23) — the player is being put
    // back out of the game, not moved forward through it.
    context.pushAndRemoveAllFade(const HomeScreen());
  }

  void _startTimer(DateTime startTime, int duration) {
    _timer?.cancel();

    final elapsed = DateTime.now().difference(startTime).inSeconds;
    _remainingSeconds = duration - elapsed;

    if (_remainingSeconds <= 0) {
      _remainingSeconds = 0;
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingSeconds--;
          if (_remainingSeconds <= 0) {
            _remainingSeconds = 0;
            timer.cancel();
          }
        });
      }
    });
  }

  Future<void> _submitAnswer(String roomCode, String playerId) async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) {
      HapticService.warning();
      BufonFeedback.show(context, 'Escribe una respuesta');
      return;
    }

    HapticService.mediumImpact();

    try {
      final repository = ref.read(roomRepositoryProvider);
      await repository.submitAnswerTransaction(roomCode, playerId, answer);

      if (mounted) {
        HapticService.success();
        BufonFeedback.show(
          context,
          'Respuesta enviada',
          tone: BufonFeedbackTone.success,
        );
      }
    } on GameException catch (e) {
      HapticService.error();
      if (mounted) {
        BufonFeedback.show(context, _friendlyAnswerError(e));
      }
    } catch (e) {
      HapticService.error();
      if (mounted) {
        BufonFeedback.show(
          context,
          'Algo se atoró al enviar. Inténtalo de nuevo.',
        );
      }
    }
  }

  Future<void> _moveToVoting(String roomCode) async {
    if (_isAdvancing) return;

    setState(() => _isAdvancing = true);
    try {
      final repository = ref.read(roomRepositoryProvider);
      await repository.cleanupDisconnectedPlayers(roomCode);
      await repository.moveToVoting(
        roomCode,
        requireAllAnswered: _remainingSeconds > 0,
      );
      SoundService.transition();
    } on GameException catch (e) {
      // A failed attempt is re-armable; a successful one is not.
      _advanceRequested = false;
      HapticService.error();
      if (mounted) {
        BufonFeedback.show(context, _friendlyPhaseError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isAdvancing = false);
      }
    }
  }

  void _scheduleAutoVoting({
    required bool isHost,
    required bool shouldAdvance,
    required String roomCode,
  }) {
    if (!isHost ||
        !shouldAdvance ||
        _isAdvancing ||
        _advanceRequested ||
        _autoAdvanceTimer != null) {
      return;
    }

    _advanceRequested = true;
    _autoAdvanceTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _autoAdvanceTimer = null;
      _moveToVoting(roomCode);
    });
  }

  String _friendlyAnswerError(GameException error) {
    switch (error.code) {
      case 'ALREADY_ANSWERED':
        return 'Ya mandaste tu respuesta.';
      case 'EMPTY_ANSWER':
        return 'Escribe una respuesta primero.';
      case 'ROOM_NOT_FOUND':
        return 'La sala ya no existe.';
    }
    return error.message;
  }

  String _friendlyPhaseError(GameException error) {
    switch (error.code) {
      case 'ANSWERS_PENDING':
        return 'Todavía falta gente por responder.';
      case 'NO_ANSWERS_SUBMITTED':
        return 'Nadie respondió. Denle otra oportunidad al caos.';
      // WP22: with a single answer the ballot would hold one card its own
      // author is forbidden to pick, so voting could never end. The round
      // stays open instead — which is what this copy asks for.
      case 'NOT_ENOUGH_ANSWERS':
        return 'Falta al menos una respuesta más para poder votar.';
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

    return roomAsync.when(
      data: (room) {
        if (room == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navigateToHomeWithMessage('La sala se cerró por desconexión');
          });
          return const Scaffold(body: Center(child: BufonLoader()));
        }

        if (room.phase == GamePhase.voting) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.replaceFadeSlide(const VotingScreen());
          });
        }

        if (room.roundStartTime != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startTimer(room.roundStartTime!, room.roundDuration);
          });
        }

        final currentPlayer = room.players
            .where((player) => player.id == userId)
            .firstOrNull;
        if (currentPlayer == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navigateToHomeWithMessage('Saliste de la sala.');
          });
          return const Scaffold(body: Center(child: BufonLoader()));
        }
        final isHost = room.hostId == userId;

        // WP22 / audit B G-1F. Completion is measured over the players this
        // phase may legitimately wait for, not over every document in the
        // subcollection. One player who had dropped or backgrounded used to
        // make `allAnswered` permanently false, which is why the room burned
        // the whole clock every time — the testers' "we had to wait for the
        // timer" complaint, with a cause that was never the timer.
        final eligible = room.players.eligible.toList();
        final eligibleCount = eligible.length;
        final answeredCount = eligible.where((p) => p.hasAnswered).length;
        final allAnswered = eligibleCount > 0 && answeredCount == eligibleCount;
        final hasAnswered = currentPlayer.hasAnswered;

        // WP22 / audit B G-1G + G-1H. Two answers is what makes a ballot
        // votable (`RoomRepository.moveToVoting` states why), so the host
        // does not attempt a transition the guard is certain to reject.
        //
        // This is also what ends the zero-answer stranding. The old code
        // fired every 2 s at expiry, threw NO_ANSWERS_SUBMITTED, toasted the
        // error and rescheduled itself forever. Now the attempt simply is
        // not made: the room stays in `answering` with the answer field
        // live, and the moment a second answer lands `shouldAdvance` turns
        // true and the round proceeds on its own.
        final expired = _remainingSeconds <= 0;
        final canOpenBallot = answeredCount >= 2;

        _scheduleAutoVoting(
          isHost: isHost,
          shouldAdvance: canOpenBallot && (allAnswered || expired),
          roomCode: room.code,
        );

        // Fase 3E: the answering phase is the Graphite register with Sky as
        // its single accent (Capítulo 33 — "Solo yo y mi ingenio contra el
        // reloj"). Surfaces now come from the theme instead of the legacy
        // casino palette.
        return PhaseScope(
          phase: BufonPhase.answering,
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
                  // Scrollable region. Everything above the status panel can
                  // grow (long question, 200% text scale, raised keyboard)
                  // without pushing the pinned footer off screen.
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Fase 2B WP15 (G13): the round used to be stated
                          // twice. `RoundIndicator` in the app bar already
                          // reads "Ronda 3/5"; `GameProgressBar` repeated the
                          // same `currentRound / totalRounds` a hundred pixels
                          // below it as segments, a sentence and a percentage.
                          // The app bar keeps it, as secondary context, and
                          // the timer is left as the one progress signal the
                          // player is meant to feel. The bar itself is
                          // untouched and still serves Voting, whose app bar
                          // is the only other place the round is stated.
                          TimerWidget(
                            remainingSeconds: _remainingSeconds,
                            totalSeconds: room.roundDuration,
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          // The question is the one Protagonist of this screen
                          // (Capítulo 3 ley 4 / Capítulo 8): flat Graphite+1 with a Sky
                          // hairline and a Sky-tinted shadow, never the old red
                          // gradient (Capítulo 3 ley 1 forbids gradient as a default).
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: AppColors.graphitePlus1,
                              borderRadius: AppShapes.borderRadiusXl,
                              border: AppShapes.hairlineBorder(
                                AppColors.sky.withValues(alpha: 0.45),
                              ),
                              boxShadow: AppElevation.protagonistShadow(
                                AppColors.sky,
                              ),
                            ),
                            child: Semantics(
                              header: true,
                              child: Text(
                                room.currentQuestionText ?? '',
                                style: AppTypography.h2.copyWith(
                                  color: AppColors.paper,
                                  height: 1.3,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          if (_isAdvancing ||
                              allAnswered ||
                              _remainingSeconds <= 0) ...[
                            _TransitionBanner(
                              title: GameCopy.revealingAnswers,
                              subtitle: allAnswered
                                  ? 'Nadie se puede arrepentir ya.'
                                  : 'Se acabó el tiempo. Lo que quedó, quedó.',
                              icon: Icons.visibility,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],

                          if (!hasAnswered) ...[
                            Semantics(
                              header: true,
                              child: Text(
                                'Tu respuesta:',
                                style: AppTypography.h4.copyWith(
                                  color: AppColors.paper,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextField(
                              controller: _answerController,
                              maxLength: 100,
                              maxLines: 3,
                              style: AppTypography.body1.copyWith(
                                color: AppColors.paper,
                              ),
                              // Fill, borders and radii now come from
                              // inputDecorationTheme (Capítulo 14: tokens, never
                              // literals) instead of being hand-rolled per field.
                              decoration: const InputDecoration(
                                hintText: 'Escribe algo gracioso...',
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) =>
                                  _submitAnswer(room.code, currentPlayer.id),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AnimatedPrimaryButton(
                              text: 'Enviar Respuesta',
                              onPressed: () =>
                                  _submitAnswer(room.code, currentPlayer.id),
                              icon: Icons.send,
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(
                                color: AppColors.mint.withValues(alpha: 0.12),
                                borderRadius: AppShapes.borderRadiusLg,
                                border: AppShapes.focusBorder(
                                  AppColors.mint.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: AppColors.mint,
                                    size: 48,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    '¡Respuesta enviada!',
                                    style: AppTypography.h3.copyWith(
                                      color: AppColors.mint,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    'Tu respuesta:',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.paper.withValues(
                                        alpha: 0.72,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    currentPlayer.currentAnswer ?? '',
                                    style: AppTypography.body1.copyWith(
                                      color: AppColors.paper,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  BufonStatusPanel(
                    // Denominator is the eligible roster too. Counting a
                    // player who has dropped would leave the panel saying
                    // "falta 1 bufón" about somebody nothing is waiting for.
                    progress: eligibleCount == 0
                        ? 0
                        : answeredCount / eligibleCount,
                    message:
                        '${GameCopy.answerProgress(answeredCount, eligibleCount)}\n'
                        '${GameCopy.answerWaiting(answeredCount, eligibleCount)}',
                    // Announced once, when the last answer lands — not on
                    // every player's answer, which is up to eight
                    // announcements a round, and not on the progress bar's
                    // every frame. While the room is still answering the
                    // node stays readable on focus but silent, which also
                    // keeps `answerWaiting`'s rotating variants from
                    // re-announcing the same state.
                    statusLabel: allAnswered
                        ? 'Todos respondieron'
                        : '${GameCopy.answerProgress(answeredCount, eligibleCount)}. '
                              '${GameCopy.answerWaiting(answeredCount, eligibleCount)}',
                    live: allAnswered,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  if (isHost && allAnswered)
                    AnimatedPrimaryButton(
                      text: _isAdvancing ? 'Revelando...' : 'Iniciar Votación',
                      onPressed: () => _moveToVoting(room.code),
                      icon: Icons.how_to_vote,
                      isLoading: _isAdvancing,
                    ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: BufonLoader())),
      error: (error, stack) => Scaffold(
        body: BufonPlaceholder(
          variant: BufonPlaceholderVariant.error,
          title: 'Se perdió la sala',
          // The exception itself is already on its way to
          // AppLogger/Crashlytics through the repository layer; a player can
          // do nothing with a Firestore error string.
          actionLabel: 'Volver al Inicio',
          onAction: () {
            // Same retreat as every other way out of a room. This was the
            // one exit still on a raw `MaterialPageRoute`, so abandoning a
            // lost room animated with the platform default instead of with
            // Bufón's own motion at all.
            context.pushAndRemoveAllFade(const HomeScreen());
          },
        ),
      ),
    );
  }
}

class _TransitionBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _TransitionBanner({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    // Arrive (Capítulo 16): enters already compressed and expands to rest.
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
            Icon(icon, color: AppColors.butter),
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
