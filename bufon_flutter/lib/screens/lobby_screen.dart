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
import '../core/theme/motion_tokens.dart';
import '../core/theme/bufon_phase.dart';
import '../core/theme/app_typography.dart';
import '../core/logging/log_category.dart';
import '../core/telemetry/game_telemetry_service.dart';
import '../core/logging/log_level.dart';
import '../core/telemetry/telemetry_event.dart';
import '../presentation/navigation/page_transitions.dart';
import '../presentation/navigation/room_exit.dart';
import '../presentation/widgets/connection_banner.dart';
import '../presentation/screens/paywall_screen.dart';
import '../presentation/widgets/animated_primary_button.dart';
import '../presentation/widgets/bufon_feedback.dart';
import '../presentation/widgets/bufon_loader.dart';
import '../presentation/widgets/bufon_placeholder.dart';
import '../services/haptic_service.dart';
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
  Timer? _copyResetTimer;
  bool _codeCopied = false;

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
    _copyResetTimer?.cancel();
    super.dispose();
  }

  void _copyRoomCode(String code) {
    HapticService.selectionClick();
    Clipboard.setData(ClipboardData(text: code));
    setState(() => _codeCopied = true);
    _copyResetTimer?.cancel();
    _copyResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _codeCopied = false);
    });
  }

  Future<void> _performCleanup() async {
    final roomCode = ref.read(roomCodeProvider);
    if (roomCode == null) return;

    try {
      final repository = ref.read(roomRepositoryProvider);
      final room = await repository.cleanupDisconnectedPlayers(roomCode);

      // Room was deleted (fewer than 2 players)
      if (room == null && mounted) {
        _navigateToHomeWithMessage(GameCopy.roomClosedTooFewPlayers);
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

    // Before the navigation, not 500 ms after it. `BufonFeedback` hands the
    // finished message to the root messenger `MaterialApp` owns, which lives
    // above the Navigator — so it outlives this route and is still on screen
    // once Home has faded in. Scheduling it afterwards never worked:
    // `pushReplacement` disposes this route when the 250 ms retreat completes,
    // so the `mounted` guard the delayed callback needed was already false.
    BufonFeedback.show(context, message);

    context.replaceFade(const HomeScreen());
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

      // Get current room
      final roomAsync = ref.read(roomStreamProvider);
      final room = roomAsync.value;
      if (room == null) return;

      // WP23 / R-18. This used to be `getRandomQuestion([])` — an empty list,
      // every single game — so a room's second game drew from the full corpus
      // again and could re-ask what the first game had just asked. That is the
      // 80.6 %-over-two-games repeat rate the package exists to reduce. The
      // room's own history is the authority now, and `startFirstRound` appends
      // to it inside its transaction.
      final question = questionService.getRandomQuestion(room.usedQuestionIds);

      await repository.startFirstRound(
        roomCode: room.code,
        questionId: question.id,
        questionText: question.text,
      );

      // `match_started` is emitted by RoomRepository.startFirstRound, which
      // owns the transition, and Session Context is refreshed from the room
      // snapshot — neither belongs in the UI layer.

      if (context.mounted) {
        context.replaceFadeSlide(const GameScreen());
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
        BufonFeedback.show(context, _friendlyStartError(e));
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
    // Capítulo 26: the technical detail stays in logs, never on screen.
    return 'No pudimos empezar la partida. Inténtalo de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider);
    final userId = ref.watch(userIdProvider);

    // WP25 / R-11. `RoomPopScope` makes Android's back gesture a deliberate
    // leave instead of an accident: every room screen is the root of its own
    // stack (they arrive through `replaceFadeSlide` / `pushAndRemoveAllFade`),
    // so back used to pop the *application* while the player's document, their
    // heartbeat and their room membership all stayed alive.
    return RoomPopScope(
      child: roomAsync.when(
      data: (room) {
        if (room == null) {
          // Room deleted, navigate to home
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navigateToHomeWithMessage(GameCopy.roomClosedTooFewPlayers);
          });
          return const Scaffold(body: Center(child: BufonLoader()));
        }

        // Navigate to game if already started
        if (room.phase != GamePhase.lobby) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.replaceFadeSlide(const GameScreen());
          });
        }

        final isHost = room.hostId == userId;
        final canStart = room.players.length >= 3;
        final playersNeeded = (3 - room.players.length).clamp(0, 3);

        // Fase 3D put Lobby on the Butter Bliss light register (Capítulo
        // 33 — "Lobby: Butter, modo claro, lento, expectante"); Fase 2A
        // moves it from a bare Theme override to PhaseScope.
        return PhaseScope(
          phase: BufonPhase.lobby,
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
                  // WP25 / R-37, BP P4: renders nothing while connected, so
                  // every existing layout is unchanged in the normal case.
                  const ConnectionBanner(),
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
                        Semantics(
                          header: true,
                          child: Text(
                            'Código de Sala',
                            style: AppTypography.body1.copyWith(
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              room.code,
                              semanticsLabel: room.code.split('').join(' '),
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
                              // The label tracks the state: after copying,
                              // the icon swaps to a check, and a screen
                              // reader that re-reads the control would
                              // otherwise still be told "copiar".
                              tooltip: _codeCopied
                                  ? 'Código copiado'
                                  : 'Copiar código de sala',
                              // Capítulo 18: copying the room code fires an
                              // icon Swap to a check, "nunca solo un Snackbar
                              // silencioso" — before Fase 2A the only visual
                              // confirmation was a toast at the far end of
                              // the screen.
                              icon: AnimatedSwitcher(
                                duration: MotionDurations.swap,
                                child: Icon(
                                  _codeCopied ? Icons.check : Icons.copy,
                                  key: ValueKey(_codeCopied),
                                  color: _codeCopied
                                      ? AppColors.mintShade
                                      : AppColors.ink,
                                ),
                              ),
                              onPressed: () => _copyRoomCode(room.code),
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
      loading: () => const Scaffold(body: Center(child: BufonLoader())),
      // WP25 / R-11 (audit A S-5 ≡ BP P7). This placeholder had no action at
      // all: *"Once a room stream fails, no route out exists: no back arrow,
      // no retry, no home button. The reviewer must force-quit."*
      error: (error, stack) => Scaffold(
        body: BufonPlaceholder(
          variant: BufonPlaceholderVariant.error,
          title: 'No se pudo cargar la sala',
          actionLabel: GameCopy.backToHome,
          onAction: () => RoomExit.toHome(context, ref),
        ),
      ),
      ),
    );
  }
}
