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
import '../presentation/widgets/bufon_loader.dart';
import '../presentation/widgets/bufon_placeholder.dart';
import '../presentation/widgets/game_progress_widgets.dart';
import '../presentation/navigation/page_transitions.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('¡Voto registrado!'),
            backgroundColor: AppColors.mintShade,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
            duration: const Duration(seconds: 1),
          ),
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.coralShade,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
          ),
        );
      }
    } catch (e) {
      HapticService.error();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Algo se atoró al registrar tu voto. Inténtalo de nuevo.',
            ),
            backgroundColor: AppColors.coralShade,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
          ),
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
      await repository.moveToRoundResult(roomCode);
      SoundService.transition();
    } on RoomException catch (e) {
      HapticService.error();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyResultError(e)),
            backgroundColor: AppColors.coralShade,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
    if (!isHost || !allVoted || _isAdvancing || _autoAdvanceTimer != null) {
      return;
    }

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

    return roomAsync.when(
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
        final allVoted = room.players.every((p) => p.votedFor != null);
        final hasVoted = currentPlayer.votedFor != null;
        final votedCount = room.players.where((p) => p.votedFor != null).length;

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
                                child: GameCard(
                                  text: player.currentAnswer ?? 'Sin respuesta',
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

                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: hasVoted
                          ? AppColors.mint.withValues(alpha: 0.12)
                          : AppColors.graphitePlus1,
                      borderRadius: AppShapes.borderRadiusMd,
                      border: AppShapes.hairlineBorder(
                        hasVoted
                            ? AppColors.mint.withValues(alpha: 0.35)
                            : AppColors.graphitePlus1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // The confirmation lands in place, and it is carried
                        // visually by a colour swap plus an icon swap — so
                        // without this a screen reader is never told the vote
                        // registered. `liveRegion` is tied to `hasVoted`
                        // because the flip happens once per player per round;
                        // the "toca para votar" prompt must not be announced.
                        Semantics(
                          liveRegion: hasVoted,
                          label: hasVoted
                              ? '¡Voto enviado!'
                              : 'Toca una respuesta para votar',
                          excludeSemantics: true,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                hasVoted ? Icons.check_circle : Icons.touch_app,
                                color: hasVoted
                                    ? AppColors.mint
                                    : AppColors.paper.withValues(alpha: 0.72),
                                size: 20,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              // Flexible, not bare: the un-voted prompt is the
                              // longest string in this Row, and beside a
                              // fixed 20 px icon it overruns the card on a
                              // narrow phone once the text scale climbs.
                              Flexible(
                                child: Text(
                                  hasVoted
                                      ? '¡Voto enviado!'
                                      : 'Toca una respuesta para votar',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.body1.copyWith(
                                    color: hasVoted
                                        ? AppColors.mint
                                        : AppColors.paper.withValues(
                                            alpha: 0.72,
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        LinearProgressIndicator(
                          value:
                              room.players
                                  .where((p) => p.votedFor != null)
                                  .length /
                              room.players.length,
                          backgroundColor: AppColors.graphiteShade,
                          valueColor: AlwaysStoppedAnimation(
                            hasVoted ? AppColors.mint : AppColors.lavender,
                          ),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${GameCopy.voteProgress(votedCount, room.players.length)}\n'
                          '${GameCopy.voteWaiting(votedCount, room.players.length)}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.paper.withValues(alpha: 0.72),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
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
      error: (error, stack) => const Scaffold(
        body: BufonPlaceholder(
          variant: BufonPlaceholderVariant.error,
          title: 'No se pudo cargar la votación',
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
