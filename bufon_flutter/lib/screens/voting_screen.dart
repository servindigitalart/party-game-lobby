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
import '../analytics/analytics_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../presentation/widgets/game_card.dart';
import '../presentation/widgets/animated_primary_button.dart';
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
            backgroundColor: AppColors.success,
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
            backgroundColor: AppColors.error,
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
            content: Text('Error inesperado: $e'),
            backgroundColor: AppColors.error,
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
            backgroundColor: AppColors.error,
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
    AnalyticsService.instance.trackScreenView('VotingScreen');

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

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
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
                GameProgressBar(
                  currentRound: room.currentRound,
                  totalRounds: room.totalRounds,
                ),
                const SizedBox(height: AppSpacing.lg),

                Text(
                  '¿Cuál es la respuesta más chistosa?',
                  style: AppTypography.h2.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppSpacing.buttonRadius,
                    ),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    room.currentQuestionText ?? '',
                    style: AppTypography.body1.copyWith(
                      color: AppColors.primary,
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

                Expanded(
                  child: ListView.separated(
                    itemCount: shuffledPlayers.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final player = shuffledPlayers[index];
                      final isSelected = currentPlayer.votedFor == player.id;
                      final canVote = !hasVoted && player.id != userId;

                      return TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: 200 + (index * 50)),
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
                          selectedColor: AppColors.success,
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
                ),
                const SizedBox(height: AppSpacing.md),

                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: hasVoted
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.buttonRadius,
                    ),
                    border: Border.all(
                      color: hasVoted
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.border,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            hasVoted ? Icons.check_circle : Icons.touch_app,
                            color: hasVoted
                                ? AppColors.success
                                : AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            hasVoted
                                ? '¡Voto enviado!'
                                : 'Toca una respuesta para votar',
                            style: AppTypography.body1.copyWith(
                              color: hasVoted
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      LinearProgressIndicator(
                        value:
                            room.players
                                .where((p) => p.votedFor != null)
                                .length /
                            room.players.length,
                        backgroundColor: AppColors.surfaceDark,
                        valueColor: AlwaysStoppedAnimation(
                          hasVoted ? AppColors.success : AppColors.accent,
                        ),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${GameCopy.voteProgress(votedCount, room.players.length)}\n'
                        '${GameCopy.voteWaiting(votedCount, room.players.length)}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
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
                    backgroundColor: AppColors.success,
                    isLoading: _isAdvancing,
                  ),
              ],
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) =>
          Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }
}

class _VoteTransitionBanner extends StatelessWidget {
  final String title;
  final String subtitle;

  const _VoteTransitionBanner({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 250),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.how_to_vote, color: AppColors.success),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.h4.copyWith(color: AppColors.success),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.body2.copyWith(
                      color: AppColors.textSecondary,
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
