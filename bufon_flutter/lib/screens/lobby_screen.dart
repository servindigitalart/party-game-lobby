// screens/lobby_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_phase.dart';
import '../providers/game_providers.dart';
import '../core/exceptions.dart';
import '../core/game_copy.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_elevation.dart';
import '../core/theme/app_shapes.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../core/logging/log_category.dart';
import '../core/telemetry/game_telemetry_service.dart';
import '../core/logging/log_level.dart';
import '../core/telemetry/telemetry_event.dart';
import '../presentation/screens/paywall_screen.dart';
import '../presentation/widgets/animated_primary_button.dart';
import 'game_screen.dart';
import 'home_screen.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  final _telemetry = GameTelemetryService.instance;
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();

    // Track screen view
    _telemetry.transition('lobby');

    // Start periodic cleanup check every 30 seconds
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _performCleanup(),
    );
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }

  Future<void> _performCleanup() async {
    final roomCode = ref.read(roomCodeProvider);
    if (roomCode == null) return;

    try {
      final repository = ref.read(roomRepositoryProvider);
      final room = await repository.cleanupDisconnectedPlayers(roomCode);

      // Room was deleted (fewer than 2 players)
      if (room == null && mounted) {
        _navigateToHomeWithMessage('La sala se cerró por desconexión');
      }
    } catch (e, stackTrace) {
      // Cleanup retries in 30 seconds, so one failure is not a crash — but
      // a run of them means the lobby is silently drifting out of sync,
      // which is exactly what the breadcrumb trail needs to show.
      _telemetry.fail(
        AppLogCategory.room,
        'lobby_cleanup_failed',
        error: e,
        stackTrace: stackTrace,
        severity: AppLogLevel.warning,
        status: TelemetryStatus.retried,
      );
    }
  }

  void _navigateToHomeWithMessage(String message) {
    if (!mounted) return;

    // Stop heartbeat
    final connectionService = ref.read(connectionServiceProvider);
    connectionService.stopHeartbeat();

    // Clear room code
    ref.read(roomCodeProvider.notifier).state = null;

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));

    // Show message after navigation
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.orange),
        );
      }
    });
  }

  Future<void> _startGame(
    BuildContext context,
    WidgetRef ref,
    String roomCode,
  ) async {
    try {
      // Check room monetization before starting
      final gameController = ref.read(gameControllerProvider);
      await gameController.startGame(roomCode);

      // Clean up disconnected players before starting
      final repository = ref.read(roomRepositoryProvider);
      await repository.cleanupDisconnectedPlayers(roomCode);

      final questionService = ref.read(questionServiceProvider);

      // Load questions if not loaded
      if (questionService.getAllQuestions().isEmpty) {
        await questionService.loadQuestions();
      }

      // Get first question
      final question = questionService.getRandomQuestion([]);
      ref.read(usedQuestionIdsProvider.notifier).state = [question.id];

      // Get current room
      final roomAsync = ref.read(roomStreamProvider);
      final room = roomAsync.value;
      if (room == null) return;

      await repository.startFirstRound(
        roomCode: room.code,
        questionId: question.id,
        questionText: question.text,
      );

      // `match_started` is emitted by RoomRepository.startFirstRound, which
      // owns the transition, and Session Context is refreshed from the room
      // snapshot — neither belongs in the UI layer.

      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const GameScreen()),
        );
      }
    } on MonetizationException catch (e) {
      if (e.code == 'ROOM_LOCKED' && context.mounted) {
        // Show paywall screen
        final unlocked = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => PaywallScreen(roomCode: roomCode)),
        );

        // If unlocked, retry starting the game
        if (unlocked == true && context.mounted) {
          await _startGame(context, ref, roomCode);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyStartError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _friendlyStartError(Object error) {
    if (error is RoomException) {
      switch (error.code) {
        case 'GAME_ALREADY_STARTED':
          return 'La partida ya empezó.';
        case 'NOT_ENOUGH_PLAYERS':
          return 'Necesitan al menos 3 jugadores para empezar.';
        case 'ROOM_NOT_FOUND':
          return 'La sala ya no existe.';
      }
      return error.message;
    }
    return 'Error al iniciar: $error';
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider);
    final userId = ref.watch(userIdProvider);

    return roomAsync.when(
      data: (room) {
        if (room == null) {
          // Room deleted, navigate to home
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navigateToHomeWithMessage('La sala se cerró por desconexión');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Navigate to game if already started
        if (room.phase != GamePhase.lobby) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const GameScreen()),
            );
          });
        }

        final isHost = room.hostId == userId;
        final canStart = room.players.length >= 3;
        final playersNeeded = (3 - room.players.length).clamp(0, 3);

        // Fase 3D: Lobby migrates to the Butter Bliss light register
        // (Capítulo 33 — "Lobby: Butter, modo claro, lento, expectante"),
        // scoped to this screen only via a local Theme override.
        return Theme(
          data: AppTheme.lightTheme,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Sala de Espera'),
              centerTitle: true,
            ),
            body: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Room code — the Protagonist of this screen (Capítulo 3,
                  // ley 4): the one thing every player needs to see/share.
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.butterTint,
                      borderRadius: AppShapes.borderRadiusXl,
                      border: AppShapes.hairlineBorder(AppColors.butterShade),
                      boxShadow: AppElevation.protagonistShadow(
                        AppColors.butterShade,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Código de Sala',
                          style: AppTypography.body1.copyWith(
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              room.code,
                              style:
                                  AppTypography.tabular(
                                    AppTypography.display,
                                  ).copyWith(
                                    color: AppColors.ink,
                                    fontSize: 32,
                                    letterSpacing: 4,
                                  ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              color: AppColors.ink,
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                Clipboard.setData(
                                  ClipboardData(text: room.code),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Código copiado'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Player list
                  Text(
                    'Jugadores (${room.players.length}/8)',
                    style: AppTypography.h4.copyWith(color: AppColors.ink),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.butterTint,
                      borderRadius: AppShapes.borderRadiusLg,
                      border: AppShapes.hairlineBorder(AppColors.butterShade),
                    ),
                    child: Text(
                      GameCopy.lobbyWaiting(playersNeeded),
                      textAlign: TextAlign.center,
                      style: AppTypography.body1.copyWith(color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: ListView.builder(
                      itemCount: room.players.length,
                      itemBuilder: (context, index) {
                        final player = room.players[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(player.name[0].toUpperCase()),
                            ),
                            title: Text(player.name),
                            trailing: player.isHost
                                ? Chip(
                                    label: Text(
                                      'Host',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    backgroundColor: AppColors.butter,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Start button (host only)
                  if (isHost) ...[
                    AnimatedPrimaryButton(
                      text: canStart
                          ? 'Empezar el desmadre'
                          : GameCopy.lobbyWaiting(playersNeeded),
                      onPressed: canStart
                          ? () => _startGame(context, ref, room.code)
                          : null,
                      backgroundColor: AppColors.butter,
                      textColor: AppColors.ink,
                      disabledBackgroundColor: AppColors.paperLine,
                      disabledForegroundColor: AppColors.inkSoft,
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.butterTint,
                        borderRadius: AppShapes.borderRadiusLg,
                        border: AppShapes.hairlineBorder(AppColors.butterShade),
                      ),
                      child: Text(
                        'El host decide cuándo empieza el caos.',
                        textAlign: TextAlign.center,
                        style: AppTypography.body1.copyWith(
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
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
