// domain/controllers/game_controller.dart
import '../../../models/room.dart';
import '../../../models/player.dart';
import '../../services/firebase_service.dart';
import '../../data/repositories/room_repository.dart';
import '../../core/crash/crash_reporter.dart';
import '../../core/exceptions.dart';
import '../../core/logging/log_category.dart';
import '../../core/logging/log_level.dart';
import '../../core/telemetry/game_telemetry_service.dart';
import '../../core/telemetry/telemetry_context.dart';
import '../../analytics/analytics_service.dart';

/// High-level controller for game operations
///
/// Coordinates auth and RoomRepository to enforce business rules.
/// Monetization limits are enforced entirely server-side via
/// RoomRepository.canRoomStartGame (Firestore is the single source
/// of truth — see startGame).
class GameController {
  final FirebaseService _firebaseService;
  final RoomRepository _roomRepository;
  final AnalyticsService _analytics = AnalyticsService.instance;
  final GameTelemetryService _telemetry = GameTelemetryService.instance;

  GameController(this._firebaseService, this._roomRepository);

  /// Create a new game room
  ///
  /// Room creation itself is not rate-limited: the monetization gate
  /// (3 free games/day, ad unlocks, Night Pass) applies per-room and is
  /// enforced when a game actually starts, see [startGame].
  Future<Room> createRoom(String hostId, String hostName) async {
    final operation = _telemetry.start(AppLogCategory.room, 'room_created');

    Room? room;
    var attempts = 0;
    try {
      for (var attempt = 0; attempt < 5; attempt++) {
        attempts = attempt + 1;
        final roomCode = _firebaseService.generateRoomCode();
        try {
          room = await _roomRepository.createRoom(roomCode, hostId, hostName);
          break;
        } on RoomException catch (e) {
          if (e.code != 'ROOM_EXISTS' || attempt == 4) {
            rethrow;
          }
        }
      }

      if (room == null) {
        throw RoomException(
          'Could not create a unique room',
          code: 'ROOM_EXISTS',
        );
      }
    } catch (e, stackTrace) {
      // Warning, not error: RoomRepository owns Firestore and has already
      // reported whatever actually failed. This records the domain outcome
      // so the timeline is complete, without a second crash report.
      operation.fail(
        e,
        stackTrace: stackTrace,
        severity: AppLogLevel.warning,
        payload: {'attempts': attempts},
      );
      rethrow;
    }

    // Session Context first: every later event inherits the room the host
    // is now in without repeating it in a payload.
    _telemetry.updateContext({
      TelemetryKeys.roomCode: room.code,
      TelemetryKeys.hostId: hostId,
      TelemetryKeys.playerId: hostId,
      TelemetryKeys.playerName: hostName,
      TelemetryKeys.playerCount: room.players.length,
    });
    operation.finish(payload: {'attempts': attempts});

    // Analytics: Track game creation
    await _analytics.logGameCreated(roomCode: room.code);

    return room;
  }

  /// Join an existing room
  Future<Room> joinRoom(String code, String playerId, String playerName) async {
    final operation = _telemetry.start(AppLogCategory.room, 'room_joined');

    final Room room;
    try {
      final player = Player(id: playerId, name: playerName);
      room = await _roomRepository.joinRoom(code.toUpperCase(), player);
    } catch (e, stackTrace) {
      // See createRoom: the repository already reported the I/O failure.
      operation.fail(e, stackTrace: stackTrace, severity: AppLogLevel.warning);
      rethrow;
    }

    _telemetry.updateContext({
      TelemetryKeys.roomCode: room.code,
      TelemetryKeys.hostId: room.hostId,
      TelemetryKeys.playerId: playerId,
      TelemetryKeys.playerName: playerName,
      TelemetryKeys.playerCount: room.players.length,
    });
    operation.finish();

    await _analytics.logGameJoined(
      roomCode: room.code,
      playerCount: room.players.length,
    );

    return room;
  }

  /// Start a new game in the room
  ///
  /// Checks room-based monetization limits before allowing game to start.
  /// Throws MonetizationException with code 'ROOM_LOCKED' if blocked.
  Future<void> startGame(String roomCode) async {
    // Check if room can start a new game
    final canStart = await _roomRepository.canRoomStartGame(roomCode);

    if (!canStart) {
      // A hard product gate, not a failure: recorded as a normal event so
      // the funnel shows where matches stop happening.
      _telemetry.track(AppLogCategory.monetization, 'match_blocked_by_limit');

      // Analytics: Track blocked game
      final roomData = await _roomRepository.getRoom(roomCode);
      if (roomData != null) {
        await _analytics.logGameBlockedByLimit(
          roomCode: roomCode,
          gamesPlayedToday: roomData.gamesPlayedToday,
          bonusGamesRemaining: roomData.adUnlocksRemaining,
        );
      }

      throw MonetizationException(
        'La sala ha alcanzado el límite de 3 partidas diarias. '
        'Mira un anuncio o activa el Night Pass para continuar.',
        code: 'ROOM_LOCKED',
      );
    }

    // Game can start - monetization check passed
    // Continue with normal game start logic (handled by UI/other controllers)
  }

  /// Mark game as completed and increment counter
  ///
  /// Call this after a game finishes (all rounds completed)
  Future<void> completeGame(String roomCode) async {
    await _roomRepository.incrementGamesPlayed(roomCode);
  }

  // Delegate room state changes to RoomRepository, the single source of truth.
  Future<void> updateRoom(Room room) async {
    await _roomRepository.updateRoom(room);
  }

  Future<void> submitAnswer(
    String roomCode,
    String playerId,
    String answer,
  ) async {
    await _roomRepository.submitAnswerTransaction(roomCode, playerId, answer);
  }

  Future<void> submitVote(
    String roomCode,
    String voterId,
    String votedForId,
  ) async {
    await _roomRepository.submitVoteTransaction(roomCode, voterId, votedForId);
  }

  Future<void> calculateRoundScores(String roomCode) async {
    // Scores are incremented atomically during submitVoteTransaction.
  }

  Future<void> clearRoundData(String roomCode) async {
    await _roomRepository.clearRoundData(roomCode);
  }

  Future<void> deleteRoom(String code) async {
    await _roomRepository.deleteRoom(code);
  }

  Stream<Room?> listenToRoom(String code) {
    return _roomRepository.watchRoom(code);
  }

  /// Signs in anonymously and binds the resulting Firebase UID to every
  /// subsequent report.
  ///
  /// The UID is the only stable identifier the game has — there is no
  /// account system — and it is already non-personal, so it satisfies
  /// docs/engineering/CRASHLYTICS.md ("Who crashed?") without collecting
  /// anything about the player.
  Future<String> signInAnonymously() async {
    final operation = _telemetry.start(
      AppLogCategory.firebase,
      'anonymous_sign_in',
    );

    final String uid;
    try {
      uid = await _firebaseService.signInAnonymously();
    } catch (e, stackTrace) {
      operation.fail(e, stackTrace: stackTrace);
      rethrow;
    }

    CrashReporter.instance.setUser(uid);
    _telemetry.updateContext({TelemetryKeys.playerId: uid});
    operation.finish();

    return uid;
  }
}
