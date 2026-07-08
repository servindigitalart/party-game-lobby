// screens/game_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_phase.dart';
import '../providers/game_providers.dart';
import '../core/exceptions.dart';
import '../core/game_copy.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../presentation/widgets/timer_widget.dart';
import '../presentation/widgets/animated_primary_button.dart';
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
  int _remainingSeconds = 90;
  bool _isAdvancing = false;

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

    context.pushAndRemoveAllFadeSlide(const HomeScreen());

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
          ),
        );
      }
    });
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Escribe una respuesta'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
        ),
      );
      return;
    }

    HapticService.mediumImpact();

    try {
      final repository = ref.read(roomRepositoryProvider);
      await repository.submitAnswerTransaction(roomCode, playerId, answer);

      if (mounted) {
        HapticService.success();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Respuesta enviada'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } on GameException catch (e) {
      HapticService.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyAnswerError(e)),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar: $e'),
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
      HapticService.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyPhaseError(e)),
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

  void _scheduleAutoVoting({
    required bool isHost,
    required bool shouldAdvance,
    required String roomCode,
  }) {
    if (!isHost ||
        !shouldAdvance ||
        _isAdvancing ||
        _autoAdvanceTimer != null) {
      return;
    }

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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final isHost = room.hostId == userId;
        final allAnswered = room.players.every((p) => p.currentAnswer != null);
        final hasAnswered = currentPlayer.currentAnswer != null;
        final answeredCount = room.players
            .where((p) => p.currentAnswer != null)
            .length;

        _scheduleAutoVoting(
          isHost: isHost,
          shouldAdvance: allAnswered || _remainingSeconds <= 0,
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

                TimerWidget(
                  remainingSeconds: _remainingSeconds,
                  totalSeconds: room.roundDuration,
                ),
                const SizedBox(height: AppSpacing.xl),

                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    room.currentQuestionText ?? '',
                    style: AppTypography.h2.copyWith(
                      color: Colors.white,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                if (_isAdvancing || allAnswered || _remainingSeconds <= 0) ...[
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
                  Text(
                    'Tu respuesta:',
                    style: AppTypography.h4.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _answerController,
                    maxLength: 100,
                    maxLines: 3,
                    style: AppTypography.body1.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Escribe algo gracioso...',
                      hintStyle: AppTypography.body1.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.buttonRadius,
                        ),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.buttonRadius,
                        ),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.buttonRadius,
                        ),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      counterStyle: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) =>
                        _submitAnswer(room.code, currentPlayer.id),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AnimatedPrimaryButton(
                    text: 'Enviar Respuesta',
                    onPressed: () => _submitAnswer(room.code, currentPlayer.id),
                    icon: Icons.send,
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.cardRadius,
                      ),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                          size: 48,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          '¡Respuesta enviada!',
                          style: AppTypography.h3.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Tu respuesta:',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          currentPlayer.currentAnswer ?? '',
                          style: AppTypography.body1.copyWith(
                            color: AppColors.textPrimary,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],

                const Spacer(),

                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.buttonRadius,
                    ),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value:
                            room.players
                                .where((p) => p.currentAnswer != null)
                                .length /
                            room.players.length,
                        backgroundColor: AppColors.surfaceDark,
                        valueColor: AlwaysStoppedAnimation(AppColors.accent),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${GameCopy.answerProgress(answeredCount, room.players.length)}\n'
                        '${GameCopy.answerWaiting(answeredCount, room.players.length)}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                if (isHost && allAnswered)
                  AnimatedPrimaryButton(
                    text: _isAdvancing ? 'Revelando...' : 'Iniciar Votación',
                    onPressed: () => _moveToVoting(room.code),
                    icon: Icons.how_to_vote,
                    backgroundColor: AppColors.accent,
                    isLoading: _isAdvancing,
                  ),
              ],
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                },
                child: const Text('Volver al Inicio'),
              ),
            ],
          ),
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
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 350),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(scale: 0.96 + (value * 0.04), child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.gold),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.h4.copyWith(color: AppColors.gold),
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
