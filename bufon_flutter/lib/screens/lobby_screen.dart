// screens/lobby_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_phase.dart';
import '../providers/game_providers.dart';
import '../core/exceptions.dart';
import '../core/game_copy.dart';
import '../analytics/analytics_service.dart';
import '../presentation/screens/paywall_screen.dart';
import 'game_screen.dart';
import 'home_screen.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  final _analytics = AnalyticsService.instance;
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();

    // Track screen view
    _analytics.trackScreenView('LobbyScreen');

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
    } catch (e) {
      // Silently fail - cleanup will retry in 30 seconds
      debugPrint('Cleanup failed: $e');
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

      // Track game started
      await _analytics.logGameStarted(
        roomCode: roomCode,
        playerCount: room.players.length,
        totalRounds: room.totalRounds,
      );

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

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sala de Espera'),
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Room code
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Código de Sala',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            room.code,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: room.code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Código copiado')),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Player list
                Text(
                  'Jugadores (${room.players.length}/8)',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Text(
                    GameCopy.lobbyWaiting(playersNeeded),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 16),
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
                              ? const Chip(label: Text('Host'))
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Start button (host only)
                if (isHost) ...[
                  ElevatedButton(
                    onPressed: canStart
                        ? () => _startGame(context, ref, room.code)
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                    ),
                    child: Text(
                      canStart
                          ? 'Empezar el desmadre'
                          : GameCopy.lobbyWaiting(playersNeeded),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'El host decide cuándo empieza el caos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
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
