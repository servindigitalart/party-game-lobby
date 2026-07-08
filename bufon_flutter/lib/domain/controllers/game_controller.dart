// domain/controllers/game_controller.dart
import '../../../models/room.dart';
import '../../../models/player.dart';
import '../../services/firebase_service.dart';
import '../../data/repositories/room_repository.dart';
import '../../core/exceptions.dart';
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

  GameController(this._firebaseService, this._roomRepository);

  /// Create a new game room
  ///
  /// Room creation itself is not rate-limited: the monetization gate
  /// (3 free games/day, ad unlocks, Night Pass) applies per-room and is
  /// enforced when a game actually starts, see [startGame].
  Future<Room> createRoom(String hostId, String hostName) async {
    Room? room;
    for (var attempt = 0; attempt < 5; attempt++) {
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

    // Analytics: Track game creation
    await _analytics.logGameCreated(roomCode: room.code);

    return room;
  }

  /// Join an existing room
  Future<Room> joinRoom(String code, String playerId, String playerName) async {
    final player = Player(id: playerId, name: playerName);
    final room = await _roomRepository.joinRoom(code.toUpperCase(), player);

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

  Future<String> signInAnonymously() async {
    return await _firebaseService.signInAnonymously();
  }
}
