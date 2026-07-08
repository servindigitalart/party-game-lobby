// data/repositories/room_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../../models/room.dart';
import '../../models/player.dart';
import '../../models/game_phase.dart';
import '../../core/exceptions.dart';
import '../../analytics/analytics_service.dart';

/// Repository responsible for all Firestore room operations
/// Uses subcollections for players instead of arrays
class RoomRepository {
  final FirebaseFirestore _firestore;
  final AnalyticsService _analytics = AnalyticsService.instance;

  RoomRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // Helper to get players collection reference
  CollectionReference<Map<String, dynamic>> _playersCollection(
    String roomCode,
  ) {
    return _firestore.collection('rooms').doc(roomCode).collection('players');
  }

  /// Submit a vote using an atomic transaction
  ///
  /// Updates only the specific player documents involved
  ///
  /// Validations:
  /// - Room must exist
  /// - Game phase must be voting
  /// - Voter must not have already voted
  /// - Cannot vote for yourself
  /// - Voted-for player must exist
  ///
  /// Throws:
  /// - [VotingException] if validation fails
  /// - [RoomException] if room doesn't exist
  Future<void> submitVoteTransaction(
    String roomCode,
    String voterId,
    String votedForId,
  ) async {
    final roomRef = _firestore.collection('rooms').doc(roomCode);
    final voterRef = _playersCollection(roomCode).doc(voterId);
    final votedForRef = _playersCollection(roomCode).doc(votedForId);

    final voteStartTime = DateTime.now();

    try {
      await _firestore.runTransaction((transaction) async {
        // Get room to validate phase
        final roomSnapshot = await transaction.get(roomRef);
        if (!roomSnapshot.exists) {
          throw RoomException('Room not found', code: 'ROOM_NOT_FOUND');
        }

        final roomData = roomSnapshot.data();
        if (roomData == null) {
          throw RoomException('Room data is null', code: 'INVALID_ROOM_DATA');
        }

        final room = Room.fromJson(roomData);

        // Validate game phase
        if (room.phase != GamePhase.voting) {
          throw VotingException(
            'Voting is not allowed in current game phase: ${room.phase.name}',
            code: 'INVALID_PHASE',
          );
        }

        // Get voter
        final voterSnapshot = await transaction.get(voterRef);
        if (!voterSnapshot.exists) {
          throw VotingException(
            'Voter not found in room',
            code: 'VOTER_NOT_FOUND',
          );
        }

        final voter = Player.fromJson(voterSnapshot.data()!);

        // Check if already voted
        if (voter.votedFor != null) {
          throw VotingException(
            'You have already voted',
            code: 'ALREADY_VOTED',
          );
        }

        // Validate not voting for self
        if (voterId == votedForId) {
          throw VotingException(
            'Cannot vote for yourself',
            code: 'SELF_VOTE_FORBIDDEN',
          );
        }

        // Get voted-for player
        final votedForSnapshot = await transaction.get(votedForRef);
        if (!votedForSnapshot.exists) {
          throw VotingException(
            'Voted-for player not found in room',
            code: 'VOTED_FOR_NOT_FOUND',
          );
        }

        final votedForPlayer = Player.fromJson(votedForSnapshot.data()!);
        if (votedForPlayer.currentAnswer == null ||
            votedForPlayer.currentAnswer!.trim().isEmpty) {
          throw VotingException(
            'Cannot vote for a player without an answer',
            code: 'VOTED_FOR_HAS_NO_ANSWER',
          );
        }

        // Update voter: mark as voted
        transaction.update(voterRef, {'votedFor': votedForId});

        // Update voted-for player: increment score
        transaction.update(votedForRef, {'score': votedForPlayer.score + 100});
      });

      // Track vote submission - get round number from room
      final roomSnapshot = await roomRef.get();
      final room = Room.fromJson(roomSnapshot.data()!);
      final timeToVoteSeconds = DateTime.now()
          .difference(voteStartTime)
          .inSeconds;

      await _analytics.logVoteSubmitted(
        roomCode: roomCode,
        roundNumber: room.currentRound,
        timeToVoteSeconds: timeToVoteSeconds,
      );
    } on FirebaseException catch (e) {
      throw RoomException(
        'Firebase error during vote: ${e.message}',
        code: e.code,
      );
    }
  }

  /// Get a room by code (with players from subcollection)
  Future<Room?> getRoom(String code) async {
    final roomDoc = await _firestore.collection('rooms').doc(code).get();
    if (!roomDoc.exists) return null;

    // Load players from subcollection
    final playersSnapshot = await _playersCollection(code).get();
    final players = playersSnapshot.docs
        .map((doc) => Player.fromJson(doc.data()))
        .toList();

    return Room.fromJson(roomDoc.data()!, players: players);
  }

  /// Watch room updates in real-time (combines room doc + players subcollection)
  Stream<Room?> watchRoom(String code) {
    final roomStream = _firestore.collection('rooms').doc(code).snapshots().map(
      (snapshot) {
        if (!snapshot.exists) return null;
        return snapshot.data();
      },
    );

    final playersStream = _playersCollection(code).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Player.fromJson(doc.data())).toList();
    });

    // Combine room and players streams
    return Rx.combineLatest2<Map<String, dynamic>?, List<Player>, Room?>(
      roomStream,
      playersStream,
      (roomData, players) {
        if (roomData == null) return null;
        return Room.fromJson(roomData, players: players);
      },
    );
  }

  /// Update room phase
  Future<void> updatePhase(String roomCode, GamePhase phase) async {
    final oldPhase = await _getCurrentPhase(roomCode);

    await _firestore.collection('rooms').doc(roomCode).update({
      'phase': phase.name,
    });

    // Track phase transitions for analytics
    final room = await getRoom(roomCode);
    if (room != null) {
      if (phase == GamePhase.answering && oldPhase != GamePhase.answering) {
        // New round started
        await _analytics.logRoundStarted(
          roomCode: roomCode,
          roundNumber: room.currentRound,
          playerCount: room.players.length,
        );
      } else if (phase == GamePhase.roundResult &&
          oldPhase == GamePhase.voting) {
        // Round completed - calculate votes submitted
        final votesSubmitted = room.players
            .where((p) => p.votedFor != null)
            .length;

        await _analytics.logRoundCompleted(
          roomCode: roomCode,
          roundNumber: room.currentRound,
          roundDurationSeconds: 0, // Could be tracked with round start time
          votesSubmitted: votesSubmitted,
        );
      }
    }
  }

  /// Helper to get current phase before updating
  Future<GamePhase?> _getCurrentPhase(String roomCode) async {
    final roomDoc = await _firestore.collection('rooms').doc(roomCode).get();
    if (!roomDoc.exists) return null;
    final data = roomDoc.data();
    if (data == null) return null;
    final phaseName = data['phase'] as String?;
    if (phaseName == null) return null;
    return GamePhase.values.firstWhere((p) => p.name == phaseName);
  }

  /// Update entire room (use sparingly, prefer field-level updates)
  Future<void> updateRoom(Room room) async {
    final roomData = room.toJson();
    // Don't try to update players array - they're in subcollection
    await _firestore.collection('rooms').doc(room.code).update(roomData);
  }

  /// Start the first round from lobby with a selected question.
  Future<void> startFirstRound({
    required String roomCode,
    required String questionId,
    required String questionText,
  }) async {
    final roomRef = _firestore.collection('rooms').doc(roomCode);

    await _firestore.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);
      if (!roomSnapshot.exists) {
        throw RoomException('Room not found', code: 'ROOM_NOT_FOUND');
      }

      final room = Room.fromJson(roomSnapshot.data()!);
      if (room.phase != GamePhase.lobby) {
        throw RoomException(
          'Game already started',
          code: 'GAME_ALREADY_STARTED',
        );
      }

      final playerCount = roomSnapshot.data()?['playerCount'] as int?;
      if (playerCount != null && playerCount < 3) {
        throw RoomException(
          'At least 3 players are required',
          code: 'NOT_ENOUGH_PLAYERS',
        );
      }

      transaction.update(roomRef, {
        'phase': GamePhase.answering.name,
        'currentQuestionId': questionId,
        'currentQuestionText': questionText,
        'currentRound': 1,
        'roundStartTime': DateTime.now().toIso8601String(),
      });
    });
  }

  /// Move from answering to voting after every active player has answered.
  Future<void> moveToVoting(
    String roomCode, {
    bool requireAllAnswered = true,
  }) async {
    final roomRef = _firestore.collection('rooms').doc(roomCode);

    await _firestore.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);
      if (!roomSnapshot.exists) {
        throw RoomException('Room not found', code: 'ROOM_NOT_FOUND');
      }

      final room = Room.fromJson(roomSnapshot.data()!);
      if (room.phase != GamePhase.answering) {
        throw RoomException(
          'Cannot start voting from phase ${room.phase.name}',
          code: 'INVALID_PHASE',
        );
      }

      final playersSnapshot = await _playersCollection(roomCode).get();
      final players = playersSnapshot.docs
          .map((doc) => Player.fromJson(doc.data()))
          .toList();
      final answeredCount = players
          .where(
            (player) =>
                player.currentAnswer != null &&
                player.currentAnswer!.trim().isNotEmpty,
          )
          .length;

      if (requireAllAnswered && answeredCount < players.length) {
        throw RoomException(
          'Not all players have answered',
          code: 'ANSWERS_PENDING',
        );
      }

      if (answeredCount == 0) {
        throw RoomException(
          'No answers submitted',
          code: 'NO_ANSWERS_SUBMITTED',
        );
      }

      transaction.update(roomRef, {
        'phase': GamePhase.voting.name,
        'roundStartTime': DateTime.now().toIso8601String(),
      });
    });
  }

  /// Move from voting to round results after every active player has voted.
  Future<void> moveToRoundResult(String roomCode) async {
    final roomRef = _firestore.collection('rooms').doc(roomCode);

    await _firestore.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);
      if (!roomSnapshot.exists) {
        throw RoomException('Room not found', code: 'ROOM_NOT_FOUND');
      }

      final room = Room.fromJson(roomSnapshot.data()!);
      if (room.phase != GamePhase.voting) {
        throw RoomException(
          'Cannot show results from phase ${room.phase.name}',
          code: 'INVALID_PHASE',
        );
      }

      final playersSnapshot = await _playersCollection(roomCode).get();
      final players = playersSnapshot.docs
          .map((doc) => Player.fromJson(doc.data()))
          .toList();
      final allVoted =
          players.isNotEmpty &&
          players.every((player) => player.votedFor != null);

      if (!allVoted) {
        throw RoomException(
          'Not all players have voted',
          code: 'VOTES_PENDING',
        );
      }

      transaction.update(roomRef, {'phase': GamePhase.roundResult.name});
    });
  }

  /// Move from round results to final winner once.
  ///
  /// Returns true only for the call that actually transitions the room. Repeated
  /// host taps after the transition are ignored so completion counters are not
  /// incremented twice.
  Future<bool> finishGame(String roomCode) async {
    final roomRef = _firestore.collection('rooms').doc(roomCode);

    return await _firestore.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);
      if (!roomSnapshot.exists) {
        throw RoomException('Room not found', code: 'ROOM_NOT_FOUND');
      }

      final room = Room.fromJson(roomSnapshot.data()!);
      if (room.phase == GamePhase.finalWinner) {
        return false;
      }

      if (room.phase != GamePhase.roundResult) {
        throw RoomException(
          'Cannot finish game from phase ${room.phase.name}',
          code: 'INVALID_PHASE',
        );
      }

      transaction.update(roomRef, {'phase': GamePhase.finalWinner.name});
      return true;
    });
  }

  /// Submit answer atomically (prevents race conditions)
  Future<void> submitAnswerTransaction(
    String roomCode,
    String playerId,
    String answer,
  ) async {
    final trimmedAnswer = answer.trim();
    if (trimmedAnswer.isEmpty) {
      throw GameException('Answer cannot be empty', code: 'EMPTY_ANSWER');
    }

    final roomRef = _firestore.collection('rooms').doc(roomCode);
    final playerRef = _playersCollection(roomCode).doc(playerId);

    try {
      await _firestore.runTransaction((transaction) async {
        // Validate room exists and phase
        final roomSnapshot = await transaction.get(roomRef);
        if (!roomSnapshot.exists) {
          throw RoomException('Room not found', code: 'ROOM_NOT_FOUND');
        }

        final room = Room.fromJson(roomSnapshot.data()!);

        // Validate phase
        if (room.phase != GamePhase.answering) {
          throw GameException(
            'Cannot submit answer in current phase: ${room.phase.name}',
          );
        }

        // Validate player exists
        final playerSnapshot = await transaction.get(playerRef);
        if (!playerSnapshot.exists) {
          throw GameException('Player not found in room');
        }

        final player = Player.fromJson(playerSnapshot.data()!);
        if (player.currentAnswer != null &&
            player.currentAnswer!.trim().isNotEmpty) {
          throw GameException(
            'You have already answered',
            code: 'ALREADY_ANSWERED',
          );
        }

        // Update only this player's answer
        transaction.update(playerRef, {'currentAnswer': trimmedAnswer});
      });
    } on FirebaseException catch (e) {
      throw RoomException(
        'Firebase error during answer submission: ${e.message}',
        code: e.code,
      );
    }
  }

  /// Clear round data (answers and votes) for next round
  Future<void> clearRoundData(String roomCode) async {
    final playersSnapshot = await _playersCollection(roomCode).get();

    // Batch update all players
    final batch = _firestore.batch();

    for (final doc in playersSnapshot.docs) {
      batch.update(doc.reference, {'currentAnswer': null, 'votedFor': null});
    }

    await batch.commit();
  }

  /// Delete room (and all player subcollection docs)
  Future<void> deleteRoom(String code) async {
    final batch = _firestore.batch();

    // Delete all players
    final playersSnapshot = await _playersCollection(code).get();
    for (final doc in playersSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete room
    batch.delete(_firestore.collection('rooms').doc(code));

    await batch.commit();
  }

  /// Create room (with host as first player)
  Future<Room> createRoom(String code, String hostId, String hostName) async {
    final roomRef = _firestore.collection('rooms').doc(code);
    final existingRoom = await roomRef.get();
    if (existingRoom.exists) {
      throw RoomException('Room code already exists', code: 'ROOM_EXISTS');
    }

    final batch = _firestore.batch();

    // Create room document (without players array)
    final room = Room(
      code: code,
      hostId: hostId,
      players: [], // Will be loaded from subcollection
    );

    batch.set(roomRef, {...room.toJson(), 'playerCount': 1});

    // Create host player in subcollection
    final hostPlayer = Player(id: hostId, name: hostName, isHost: true);

    batch.set(_playersCollection(code).doc(hostId), hostPlayer.toJson());

    await batch.commit();

    return room.copyWith(players: [hostPlayer]);
  }

  /// Join room by adding player to subcollection
  Future<Room> joinRoom(String code, Player player) async {
    final roomRef = _firestore.collection('rooms').doc(code);
    final playerRef = _playersCollection(code).doc(player.id);

    final existingPlayer = await playerRef.get();
    if (existingPlayer.exists) {
      final room = await getRoom(code);
      if (room == null) {
        throw RoomException('Room not found', code: 'ROOM_NOT_FOUND');
      }
      return room;
    }

    final fallbackPlayersSnapshot = await _playersCollection(code).get();

    await _firestore.runTransaction((transaction) async {
      // Check room exists
      final roomSnapshot = await transaction.get(roomRef);
      if (!roomSnapshot.exists) {
        throw RoomException('Room not found', code: 'ROOM_NOT_FOUND');
      }

      final room = Room.fromJson(roomSnapshot.data()!);
      if (room.phase != GamePhase.lobby) {
        throw RoomException(
          'Game already started',
          code: 'GAME_ALREADY_STARTED',
        );
      }

      // Check room capacity
      final playerCount =
          roomSnapshot.data()?['playerCount'] as int? ??
          fallbackPlayersSnapshot.docs.length;
      if (playerCount >= 8) {
        throw RoomException('Room is full', code: 'ROOM_FULL');
      }

      final playerSnapshot = await transaction.get(playerRef);
      if (playerSnapshot.exists) {
        return;
      }

      // Add player to subcollection
      transaction.set(playerRef, player.toJson());
      transaction.update(roomRef, {'playerCount': FieldValue.increment(1)});
    });

    final room = await getRoom(code);
    if (room == null) {
      throw RoomException('Room not found', code: 'ROOM_NOT_FOUND');
    }
    return room;
  }

  /// Clean up disconnected players atomically
  ///
  /// Removes players who haven't sent a heartbeat in 20+ seconds
  /// Reassigns host if the current host is disconnected
  /// Deletes room if fewer than 2 players remain
  ///
  /// Returns:
  /// - Updated room if cleanup succeeded
  /// - null if room was deleted
  ///
  /// Throws:
  /// - [RoomException] if room doesn't exist
  Future<Room?> cleanupDisconnectedPlayers(String roomCode) async {
    final roomRef = _firestore.collection('rooms').doc(roomCode);

    try {
      final result = await _firestore.runTransaction((transaction) async {
        // Get room
        final roomSnapshot = await transaction.get(roomRef);
        if (!roomSnapshot.exists) {
          throw RoomException('Room not found', code: 'ROOM_NOT_FOUND');
        }

        final roomData = roomSnapshot.data()!;
        final currentHostId = roomData['hostId'] as String;

        // Get all players
        final playersSnapshot = await _playersCollection(roomCode).get();
        final now = DateTime.now();

        final activePlayers = <Player>[];
        final disconnectedPlayerIds = <String>[];

        for (final doc in playersSnapshot.docs) {
          final player = Player.fromJson(doc.data());
          final timeSinceLastSeen = now.difference(player.lastSeen);

          if (timeSinceLastSeen.inSeconds <= 20) {
            activePlayers.add(player);
          } else {
            disconnectedPlayerIds.add(player.id);
          }
        }

        // No changes needed
        if (disconnectedPlayerIds.isEmpty) {
          return Room.fromJson(roomData, players: activePlayers);
        }

        // Delete disconnected players
        for (final playerId in disconnectedPlayerIds) {
          transaction.delete(_playersCollection(roomCode).doc(playerId));
        }

        // If fewer than 2 players, delete room
        if (activePlayers.length < 2) {
          // Delete all remaining players
          for (final player in activePlayers) {
            transaction.delete(_playersCollection(roomCode).doc(player.id));
          }
          transaction.delete(roomRef);
          return null;
        }

        // Check if host was disconnected
        final hostStillActive = activePlayers.any((p) => p.id == currentHostId);

        if (!hostStillActive) {
          // Reassign host to first active player
          final newHostId = activePlayers.first.id;

          // Update room hostId
          transaction.update(roomRef, {
            'hostId': newHostId,
            'playerCount': activePlayers.length,
          });

          // Update old host flag (if they exist)
          for (final player in activePlayers) {
            if (player.id == newHostId && !player.isHost) {
              transaction.update(_playersCollection(roomCode).doc(player.id), {
                'isHost': true,
              });
            } else if (player.id != newHostId && player.isHost) {
              transaction.update(_playersCollection(roomCode).doc(player.id), {
                'isHost': false,
              });
            }
          }

          return Room.fromJson({
            ...roomData,
            'hostId': newHostId,
          }, players: activePlayers);
        }

        transaction.update(roomRef, {'playerCount': activePlayers.length});
        return Room.fromJson(roomData, players: activePlayers);
      });

      // Track disconnections outside transaction
      if (result != null) {
        // Count disconnected players by comparing before/after
        final currentPlayerCount = result.players.length;
        final roomSnapshot = await roomRef.get();
        final roomData = roomSnapshot.data()!;

        // Log each disconnection event
        await _analytics.logPlayerDisconnected(
          roomCode: roomCode,
          playerCountRemaining: currentPlayerCount,
          gamePhase: roomData['phase'] as String? ?? 'unknown',
        );
      }

      return result;
    } on FirebaseException catch (e) {
      throw RoomException(
        'Firebase error during cleanup: ${e.message}',
        code: e.code,
      );
    }
  }

  /// Check if room can start a new game based on monetization rules
  ///
  /// Rules:
  /// 1. If nightPassExpiresAt > now → allow
  /// 2. If adUnlocksRemaining > 0 → consume 1 and allow
  /// 3. If gamesPlayedToday < 3 → allow
  /// 4. Else → block (throw exception)
  ///
  /// Also handles daily reset if date changed
  Future<bool> canRoomStartGame(String roomCode) async {
    final roomRef = _firestore.collection('rooms').doc(roomCode);

    return await _firestore.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);
      if (!roomSnapshot.exists) {
        throw RoomException('Room not found', code: 'ROOM_NOT_FOUND');
      }

      final roomData = roomSnapshot.data()!;
      final room = Room.fromJson(roomData);

      // Get current date (yyyy-MM-dd)
      final today = _formatDate(DateTime.now());

      // Check if day changed - reset counter if needed
      if (room.lastGameDate != null && room.lastGameDate != today) {
        transaction.update(roomRef, {
          'gamesPlayedToday': 0,
          'lastGameDate': today,
        });
        return true; // New day, allow game
      }

      // Priority 1: Check Night Pass
      if (room.nightPassExpiresAt != null &&
          room.nightPassExpiresAt!.isAfter(DateTime.now())) {
        return true; // Night Pass active - unlimited games
      }

      // Priority 2: Check ad unlocks
      if (room.adUnlocksRemaining > 0) {
        transaction.update(roomRef, {
          'adUnlocksRemaining': FieldValue.increment(-1),
        });
        return true; // Consume ad unlock
      }

      // Priority 3: Check daily limit
      if (room.gamesPlayedToday < 3) {
        return true; // Under limit
      }

      // Blocked - need ad or Night Pass
      return false;
    });
  }

  /// Increment games played counter after completing a game
  Future<void> incrementGamesPlayed(String roomCode) async {
    final roomRef = _firestore.collection('rooms').doc(roomCode);
    final today = _formatDate(DateTime.now());

    await _firestore.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);
      if (!roomSnapshot.exists) {
        throw RoomException('Room not found', code: 'ROOM_NOT_FOUND');
      }

      final roomData = roomSnapshot.data()!;
      final room = Room.fromJson(roomData);

      // Reset counter if day changed
      if (room.lastGameDate != null && room.lastGameDate != today) {
        transaction.update(roomRef, {
          'gamesPlayedToday': 1,
          'lastGameDate': today,
        });
      } else {
        transaction.update(roomRef, {
          'gamesPlayedToday': FieldValue.increment(1),
          'lastGameDate': today,
        });
      }
    });
  }

  /// Grant ad unlock to room (called after watching rewarded ad)
  ///
  /// Uses transaction to prevent double reward
  Future<void> grantAdUnlock(String roomCode) async {
    final roomRef = _firestore.collection('rooms').doc(roomCode);

    await _firestore.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);
      if (!roomSnapshot.exists) {
        throw RoomException('Room not found', code: 'ROOM_NOT_FOUND');
      }

      transaction.update(roomRef, {
        'adUnlocksRemaining': FieldValue.increment(1),
      });
    });
  }

  // Night Pass activation is performed server-side by the `verifyNightPass`
  // Cloud Function (functions/src/index.ts) via the Admin SDK, which writes
  // nightPassExpiresAt directly after validating the purchase receipt. There
  // is deliberately no client-callable method here: firestore.rules blocks
  // client writes to nightPassExpiresAt, so a client-side method could never
  // have worked, and it previously had zero callers in the app.

  /// Helper to format date as yyyy-MM-dd
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
