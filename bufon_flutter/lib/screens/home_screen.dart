// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_providers.dart';
import '../core/telemetry/game_telemetry_service.dart';
import '../core/exceptions.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/bufon_phase.dart';
import '../core/theme/app_typography.dart';
import '../presentation/navigation/page_transitions.dart';
import '../presentation/screens/leaderboard_screen.dart';
import '../presentation/screens/profile_screen.dart';
import '../presentation/widgets/animated_primary_button.dart';
import '../presentation/widgets/brand_mark.dart';
import '../presentation/widgets/season_countdown_banner.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import 'lobby_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Track screen view
    GameTelemetryService.instance.transition('home');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Por favor ingresa tu nombre');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final gameController = ref.read(gameControllerProvider);

      // Sign in anonymously
      final userId = await gameController.signInAnonymously();
      ref.read(userIdProvider.notifier).state = userId;

      // Create room (checks monetization limits and registers game)
      final room = await gameController.createRoom(
        userId,
        _nameController.text.trim(),
      );
      ref.read(roomCodeProvider.notifier).state = room.code;

      // Start heartbeat
      final connectionService = ref.read(connectionServiceProvider);
      connectionService.startHeartbeat(roomCode: room.code, playerId: userId);

      if (mounted) {
        // Capítulo 23: forward movement through the loop uses Arrive
        // (fade + slide), not Material's default route transition.
        context.replaceFadeSlide(const LobbyScreen());
      }
    } catch (e) {
      _showError(_friendlyRoomError(e, fallback: 'Error al crear sala'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinRoom() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Por favor ingresa tu nombre');
      return;
    }

    if (_codeController.text.trim().isEmpty) {
      _showError('Por favor ingresa el código de sala');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final gameController = ref.read(gameControllerProvider);

      // Sign in anonymously
      final userId = await gameController.signInAnonymously();
      ref.read(userIdProvider.notifier).state = userId;

      // Join room
      final room = await gameController.joinRoom(
        _codeController.text.trim(),
        userId,
        _nameController.text.trim(),
      );

      ref.read(roomCodeProvider.notifier).state = room.code;

      // Start heartbeat
      final connectionService = ref.read(connectionServiceProvider);
      connectionService.startHeartbeat(roomCode: room.code, playerId: userId);

      if (mounted) {
        // Capítulo 23: forward movement through the loop uses Arrive
        // (fade + slide), not Material's default route transition.
        context.replaceFadeSlide(const LobbyScreen());
      }
    } catch (e) {
      _showError(_friendlyRoomError(e, fallback: 'Error al unirse'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyRoomError(Object error, {required String fallback}) {
    if (error is RoomException) {
      switch (error.code) {
        case 'ROOM_NOT_FOUND':
          return 'No encontramos esa sala.';
        case 'ROOM_FULL':
          return 'Esa sala ya está llena.';
        case 'GAME_ALREADY_STARTED':
          return 'Esa partida ya empezó.';
        case 'ROOM_EXISTS':
          return 'No pudimos crear sala. Intenta de nuevo.';
      }
      return error.message;
    }
    // Capítulo 26: never surface a raw exception to a player. The technical
    // detail already reaches AppLogger/Crashlytics through the repository
    // layer; interpolating `$error` here only put a Dart exception string in
    // front of someone trying to start a game.
    return '$fallback. Inténtalo de nuevo en un momento.';
  }

  void _openProfile() {
    HapticService.lightImpact();
    SoundService.tap();
    context.pushFadeSlide(const ProfileScreen());
  }

  void _openLeaderboard() {
    HapticService.lightImpact();
    SoundService.tap();
    context.pushFadeSlide(const LeaderboardScreen());
  }

  @override
  Widget build(BuildContext context) {
    // Fase 3D put Home on the Butter Bliss light register (Capítulo 30 — "la
    // vida social alrededor del juego") via a bare local Theme override.
    // Fase 2A replaces that with PhaseScope, which additionally carries the
    // register's accent and its system-bar styling.
    return PhaseScope(
      phase: BufonPhase.home,
      child: Scaffold(
        appBar: AppBar(
          // The isotype is the identity anchor of the shell (Capítulo 2: "la
          // marca vive en la geometría"), and the two actions are what makes
          // the progression surface reachable at all — before Fase 2A neither
          // ProfileScreen nor LeaderboardScreen had a single inbound
          // navigation, so every reward the backend granted was invisible.
          title: const BrandMark(size: 36),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.emoji_events),
              tooltip: 'Rankings',
              onPressed: _isLoading ? null : _openLeaderboard,
            ),
            IconButton(
              icon: const Icon(Icons.person),
              tooltip: 'Mi perfil',
              onPressed: _isLoading ? null : _openProfile,
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'BUFÓN',
                          style: AppTypography.display.copyWith(
                            color: AppColors.ink,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '¿Quién es el más chistoso?',
                          style: AppTypography.body1.copyWith(
                            // inkMuted, not inkSoft: the tint fails AA at
                            // body size on Paper. See AppColors.inkMuted.
                            color: AppColors.inkMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Tu nombre',
                          ),
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AnimatedPrimaryButton(
                          text: 'Crear Sala',
                          onPressed: _isLoading ? null : _createRoom,
                          isLoading: _isLoading,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const Divider(),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _codeController,
                          decoration: const InputDecoration(
                            labelText: 'Código de sala',
                          ),
                          textCapitalization: TextCapitalization.characters,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AnimatedPrimaryButton(
                          text: 'Unirse a Sala',
                          variant: PrimaryButtonVariant.outline,
                          backgroundColor: AppColors.ink,
                          onPressed: _isLoading ? null : _joinRoom,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // A season is context, not the reason the app was
                        // opened: it sits below the primary actions so it
                        // stops out-competing the brand for attention on the
                        // first screen (Capítulo 3 ley 4).
                        const SeasonCountdownBanner(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
