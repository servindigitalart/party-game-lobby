// screens/round_result_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_copy.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../models/game_phase.dart';
import '../providers/game_providers.dart';
import '../core/telemetry/game_telemetry_service.dart';
import '../core/logging/log_category.dart';
import '../presentation/widgets/confetti_widget.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import 'final_winner_screen.dart';
import 'game_screen.dart';

class RoundResultScreen extends ConsumerStatefulWidget {
  const RoundResultScreen({super.key});

  @override
  ConsumerState<RoundResultScreen> createState() => _RoundResultScreenState();
}

class _RoundResultScreenState extends ConsumerState<RoundResultScreen> {
  int _revealStage = 0;
  final List<Timer> _revealTimers = [];

  @override
  void initState() {
    super.initState();
    GameTelemetryService.instance.transition('round_result');
    _revealTimers.add(
      Timer(const Duration(milliseconds: 750), () {
        if (!mounted) return;
        setState(() => _revealStage = 1);
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

    return roomAsync.when(
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
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const GameScreen()),
            );
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
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => FinalWinnerScreen(
                  winnerName: winner.name,
                  winnerAvatarId: 'default',
                  votesReceived: votesReceived,
                  totalScore: winner.score,
                  isCurrentUserWinner: winner.id == userId,
                ),
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

        final sortedPlayers = List.from(room.players)
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
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            title: Text('Resultados - Ronda ${room.currentRound}'),
            centerTitle: true,
          ),
          body: Stack(
            children: [
              ConfettiWidget(
                isActive: _revealStage >= 2,
                duration: Duration(milliseconds: 1800),
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
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Marcador de la noche',
                      style: AppTypography.h4.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: ListView.builder(
                        itemCount: sortedPlayers.length,
                        itemBuilder: (context, index) {
                          final player = sortedPlayers[index];
                          final position = index + 1;
                          final roundVotes = voteCounts[player.id] ?? 0;

                          return Card(
                            color: position == 1
                                ? AppColors.gold.withValues(alpha: 0.16)
                                : AppColors.surface,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: position == 1
                                    ? AppColors.gold
                                    : AppColors.primary,
                                child: Text(
                                  '$position',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.background,
                                  ),
                                ),
                              ),
                              title: Text(
                                player.name,
                                style: AppTypography.body1.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '$roundVotes votos esta ronda',
                                style: AppTypography.caption,
                              ),
                              trailing: Text(
                                '${player.score} pts',
                                style: AppTypography.body1.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.gold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (isHost)
                      ElevatedButton(
                        onPressed: () => _nextRound(room.code),
                        child: Text(
                          room.currentRound >= room.totalRounds
                              ? 'Coronar al BUFÓN'
                              : 'Soltar la siguiente',
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.buttonRadius,
                          ),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '${GameCopy.nextRound}\nEl host trae la siguiente carta.',
                          textAlign: TextAlign.center,
                          style: AppTypography.body2,
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
  }
}

class _WinnerSpotlight extends StatelessWidget {
  final String winnerName;
  final String answer;
  final int votesReceived;
  final int revealStage;

  const _WinnerSpotlight({
    required this.winnerName,
    required this.answer,
    required this.votesReceived,
    required this.revealStage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            revealStage >= 2 ? Icons.theater_comedy : Icons.visibility,
            size: 46,
            color: AppColors.background,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            revealStage >= 2
                ? 'Y el BUFÓN detrás de eso fue...'
                : 'La respuesta ganadora fue...',
            style: AppTypography.body1.copyWith(
              color: AppColors.background,
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
                      color: AppColors.background,
                    ),
                    textAlign: TextAlign.center,
                  )
                : Container(
                    key: ValueKey('answer-$answer'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.buttonRadius,
                      ),
                    ),
                    child: Text(
                      '"$answer"',
                      style: AppTypography.h4.copyWith(
                        color: AppColors.background,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
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
                      color: AppColors.background.withValues(alpha: 0.72),
                    ),
                    textAlign: TextAlign.center,
                  )
                : Column(
                    key: ValueKey('author-$winnerName'),
                    children: [
                      Text(
                        winnerName,
                        style: AppTypography.display.copyWith(
                          color: AppColors.background,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '$votesReceived votos recibidos',
                        style: AppTypography.body2.copyWith(
                          color: AppColors.background,
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
                color: AppColors.background.withValues(alpha: 0.74),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
