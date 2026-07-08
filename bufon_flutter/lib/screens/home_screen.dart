// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_providers.dart';
import '../analytics/analytics_service.dart';
import '../core/exceptions.dart';
import '../presentation/widgets/season_countdown_banner.dart';
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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Season Countdown Banner at top
              const SeasonCountdownBanner(),
              const SizedBox(height: 24),
              const Text(
                'BUFÓN',
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '¿Quién es el más chistoso?',
                style: TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tu nombre',
                  border: OutlineInputBorder(),
                ),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _createRoom,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Crear Sala', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Código de sala',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _isLoading ? null : _joinRoom,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Unirse a Sala',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
