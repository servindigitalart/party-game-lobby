// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_providers.dart';
import '../core/telemetry/game_telemetry_service.dart';
import '../analytics/analytics_service.dart';
import '../core/exceptions.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../presentation/widgets/animated_primary_button.dart';
import '../presentation/widgets/season_countdown_banner.dart';
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
  final _analytics = AnalyticsService.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Track screen view
    _analytics.trackScreenView('HomeScreen');
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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LobbyScreen()),
        );
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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LobbyScreen()),
        );
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
    return '$fallback: $error';
  }

  @override
  Widget build(BuildContext context) {
    // Fase 3D: Home migrates to the Butter Bliss light register (Capítulo
    // 30 — "la vida social alrededor del juego"). Scoped to this screen's
    // subtree with a local Theme override rather than touching main.dart,
    // so no other screen is affected.
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
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
                        // Season Countdown Banner at top
                        const SeasonCountdownBanner(),
                        const SizedBox(height: AppSpacing.lg),
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
                            color: AppColors.inkSoft,
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
                          backgroundColor: AppColors.butter,
                          textColor: AppColors.ink,
                          disabledBackgroundColor: AppColors.paperLine,
                          disabledForegroundColor: AppColors.inkSoft,
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
                        OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  // AnimatedPrimaryButton triggers this same
                                  // haptic+sound pair internally on tap-down; this
                                  // button has no built-in feedback, so it's added
                                  // explicitly here to match (Capítulo 18/19 — every
                                  // main button gets haptic + sound).
                                  HapticFeedback.lightImpact();
                                  SoundService.tap();
                                  _joinRoom();
                                },
                          child: const Text('Unirse a Sala'),
                        ),
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
