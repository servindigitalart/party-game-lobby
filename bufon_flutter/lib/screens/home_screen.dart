// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/practice_room_repository.dart';
import '../providers/game_providers.dart';
import '../core/telemetry/game_telemetry_service.dart';
import '../core/telemetry/telemetry_context.dart';
import '../core/exceptions.dart';
import '../core/game_copy.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/bufon_phase.dart';
import '../core/theme/app_typography.dart';
import '../presentation/navigation/page_transitions.dart';
import '../presentation/screens/leaderboard_screen.dart';
import '../presentation/screens/profile_screen.dart';
import '../presentation/widgets/animated_primary_button.dart';
import '../presentation/widgets/brand_mark.dart';
import '../presentation/widgets/bufon_feedback.dart';
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

  /// WP26 / R-38. The one message that belongs on the field itself rather
  /// than in a transient toast: the room code this screen used to discard
  /// without a word.
  String? _codeError;

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

    // WP26 / R-38, and the case the item actually cites — BP Part IV §1(d):
    // *"typing a code then pressing 'Crear Sala' silently discards it."*
    // It no longer does. The message lands on the field that would have been
    // thrown away, one tap from the action the player almost certainly meant.
    //
    // The two empty-field guards above and below deliberately keep
    // `_showError`: WP11 adopted `BufonFeedback` as Home's one reporting path
    // and `registered_feedback_adoption_test` probes it through exactly those
    // guards. R-38 names the silent discard, not the reporting mechanism.
    //
    // (`bufon_component_primitives_test` greps this file's source for
    // hand-rolled toast types, so the primitive's name is the only one that
    // may appear here.)
    if (_codeController.text.trim().isNotEmpty) {
      setState(() => _codeError = GameCopy.codeIgnoredWhenCreating);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Multiplayer is Firestore-backed. Stated rather than assumed, so a
      // previous Practice session can never leave the seam pointing at the
      // in-memory repository.
      ref.read(practiceModeProvider.notifier).state = false;
      GameTelemetryService.instance.updateContext({
        TelemetryKeys.gameMode: 'multiplayer',
      });

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

  /// Starts a Practice game (PD-12(c) / R-21).
  ///
  /// Deliberately shorter than `_createRoom`, and every omission is the
  /// point: no `signInAnonymously`, so Practice needs no Firebase Auth and
  /// works on a clean install before any identity exists; and no
  /// `startHeartbeat`, because presence is a Firestore concern and Practice
  /// writes nothing. Everything after this runs on the production screens.
  Future<void> _startPractice() async {
    setState(() => _isLoading = true);

    try {
      // Flip the seam before reading the controller: `gameControllerProvider`
      // watches `roomRepositoryProvider`, which watches this.
      ref.read(practiceModeProvider.notifier).state = true;
      GameTelemetryService.instance.updateContext({
        TelemetryKeys.gameMode: 'practice',
      });

      final name = _nameController.text.trim().isEmpty
          ? GameCopy.practiceHumanName
          : _nameController.text.trim();

      // A local identifier, not an account. Nothing reads it but the
      // in-memory room.
      const humanId = 'practice-human';
      ref.read(userIdProvider.notifier).state = humanId;

      // Straight to the repository, deliberately not through
      // `GameController.createRoom`. That path exists to retry room-code
      // collisions and it reaches `FirebaseService`, which builds
      // `FirebaseAuth.instance` in a field initialiser — so going through it
      // would make Practice depend on a Firebase app for no benefit. A
      // Practice room is local and cannot collide, so there is nothing to
      // retry and nothing to generate.
      final room = await ref
          .read(roomRepositoryProvider)
          .createRoom(PracticeRoomRepository.roomCode, humanId, name);
      ref.read(roomCodeProvider.notifier).state = room.code;

      // The same Session Context a multiplayer room sets, so later events
      // carry the room without repeating it in a payload.
      GameTelemetryService.instance.updateContext({
        TelemetryKeys.roomCode: room.code,
        TelemetryKeys.hostId: humanId,
        TelemetryKeys.playerId: humanId,
        TelemetryKeys.playerName: name,
        TelemetryKeys.playerCount: room.players.length,
      });

      if (mounted) {
        context.replaceFadeSlide(const LobbyScreen());
      }
    } catch (e) {
      ref.read(practiceModeProvider.notifier).state = false;
      _showError(_friendlyRoomError(e, fallback: 'Error al iniciar la práctica'));
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
      ref.read(practiceModeProvider.notifier).state = false;
      GameTelemetryService.instance.updateContext({
        TelemetryKeys.gameMode: 'multiplayer',
      });

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
    BufonFeedback.show(context, message);
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
                        // The screen's heading, so a screen reader can jump to
                        // it. The `BrandMark` in the app bar announces the same
                        // word as an *image*, which carries no structure — the
                        // two are different roles, not a duplicate label.
                        Semantics(
                          header: true,
                          child: Text(
                            'BUFÓN',
                            style: AppTypography.display.copyWith(
                              color: AppColors.ink,
                            ),
                            textAlign: TextAlign.center,
                          ),
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
                        const SizedBox(height: AppSpacing.md),
                        // WP25 / R-23, the half that needs no external fact.
                        // audit A M-4: *"nothing tells the reviewer the game
                        // needs 3 people"*, and audit A §3 records it as a
                        // block point on the very first screen. Stated here,
                        // before anyone commits to creating a room — R-21's
                        // scope asks for exactly that.
                        //
                        // The *legal* half of R-23 is deliberately absent: it
                        // depends on the privacy-policy URL, which R-23's own
                        // BLOCK field names as an App Store Connect fact
                        // (R-15), and WP18 has recovered none of its facts.
                        Text(
                          GameCopy.playersRequired,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.inkMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xl),
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
                          decoration: InputDecoration(
                            labelText: 'Código de sala',
                            errorText: _codeError,
                          ),
                          textCapitalization: TextCapitalization.characters,
                          enabled: !_isLoading,
                          // Clears as soon as the player acts on it, so the
                          // message never outlives the problem.
                          onChanged: (_) {
                            if (_codeError != null) {
                              setState(() => _codeError = null);
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AnimatedPrimaryButton(
                          text: 'Unirse a Sala',
                          variant: PrimaryButtonVariant.outline,
                          backgroundColor: AppColors.ink,
                          onPressed: _isLoading ? null : _joinRoom,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // PD-12(c). Tertiary by construction: a text button
                        // under both multiplayer panels, carrying neither a
                        // fill nor an outline, so the two ways to play with
                        // other people keep the visual weight. Practice is a
                        // real product feature, not a fallback — it is simply
                        // not what Bufón is for.
                        _PracticeEntry(
                          onPressed: _isLoading ? null : _startPractice,
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

/// Home's third way in (PD-12(c) / R-21).
///
/// Bufón is a game for three to eight people on three to eight phones, and
/// Home says so directly above this. Practice is how one person plays it
/// anyway — a full night against two simulated bufones — and it is offered as
/// an ordinary feature, in ordinary language, to everyone.
///
/// Composed to stay tertiary: no fill, no outline, one line of label over one
/// line of explanation, below both multiplayer panels. Capítulo 3 ley 4 gives
/// a screen one primary action, and on Home that is still "Crear Sala".
class _PracticeEntry extends StatelessWidget {
  const _PracticeEntry({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final phase = context.phase;

    return Semantics(
      button: true,
      label: '${GameCopy.practiceTitle}. ${GameCopy.practiceSubtitle}',
      excludeSemantics: true,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              GameCopy.practiceTitle,
              textAlign: TextAlign.center,
              style: AppTypography.body1.copyWith(
                color: phase.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              GameCopy.practiceSubtitle,
              textAlign: TextAlign.center,
              style: AppTypography.body2.copyWith(color: phase.onSurfaceMuted),
            ),
          ],
        ),
      ),
    );
  }
}
