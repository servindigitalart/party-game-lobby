// data/repositories/room_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../../models/room.dart';
import '../../models/player.dart';
import '../../models/game_phase.dart';
import '../../core/exceptions.dart';
import '../../core/logging/log_category.dart';
import '../../core/logging/log_level.dart';
import '../../core/telemetry/game_telemetry_service.dart';
import '../../core/telemetry/telemetry_context.dart';

/// Repository responsible for all Firestore room operations
/// Uses subcollections for players instead of arrays
///
/// ## Instrumentation
///
/// This layer owns Firestore, so it is the layer that reports Firestore
/// failures. Every mutating operation is wrapped in [_transaction] or
/// [_write], producing a `firestore_transaction` / `firestore_write` event
/// pair with a duration and a shared correlation id. A `started` event with
/// no matching close is how a hung transaction becomes visible.
///
/// Domain events (`match_started`, `vote_submitted`, `round_started`, ...)
/// are emitted once, by whichever path actually owns the truth. Anything
/// observable from the room snapshot — phase, round, player count, host — is
/// derived in [watchRoom] instead of being emitted by each write path, so no
/// transition is reported twice.
class RoomRepository {
  final FirebaseFirestore _firestore;
  final GameTelemetryService _telemetry = GameTelemetryService.instance;

  RoomRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // Last values seen through watchRoom, so a transition is reported once even
  // when several widgets subscribe to the same room.
  String? _lastPhase;
  int? _lastPlayerCount;
  int? _lastRound;
  String? _lastHostId;

  // Helper to get players collection reference
  CollectionReference<Map<String, dynamic>> _playersCollection(
    String roomCode,
  ) {
    return _firestore.collection('rooms').doc(roomCode).collection('players');
  }

  /// Domain exceptions are expected control flow — a full room, an
  /// already-cast vote, a game that already started. They belong in the
  /// breadcrumb trail but must not become crash reports, or the beta signal
  /// drowns in noise. Anything else (Firebase, platform, parsing) is a real
  /// failure.
  AppLogLevel _severityFor(Object error) =>
      error is GameException ? AppLogLevel.warning : AppLogLevel.error;

  /// Wraps a Firestore operation in one telemetry operation.
  Future<T> _firestoreOp<T>(
    String kind,
    String operation,
    Future<T> Function() body,
  ) async {
    final payload = {'operation': operation};
    final telemetryOp = _telemetry.start(
      AppLogCategory.firestore,
      'firestore_$kind',
      payload: payload,
    );

    try {
      final result = await body();
      telemetryOp.finish(payload: payload);
      return result;
    } catch (error, stackTrace) {
      telemetryOp.fail(
        error,
        stackTrace: stackTrace,
        payload: payload,
        severity: _severityFor(error),
      );
      rethrow;
    }
  }

  Future<T> _transaction<T>(String operation, Future<T> Function() body) =>
      _firestoreOp('transaction', operation, body);

  Future<T> _write<T>(String operation, Future<T> Function() body) =>
      _firestoreOp('write', operation, body);

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
      await _transaction('submit_vote', () async {
        return await _firestore.runTransaction((transaction) async {
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
          transaction.update(votedForRef, {
            'score': votedForPlayer.score + 100,
          });
        });
      });

      // Round, room code and player count already travel in Session Context,
      // refreshed from the room snapshot. Reading the room back from
      // Firestore here — one extra document read on the hot voting path,
      // once per player per round — existed only to fill an analytics
      // parameter and is gone.
      _telemetry.track(
        AppLogCategory.voting,
        'vote_submitted',
        payload: {
          'time_to_vote_seconds': DateTime.now()
              .difference(voteStartTime)
              .inSeconds,
        },
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
        )
        .doOnListen(
          () => _telemetry.track(
            AppLogCategory.firestore,
            'room_listener_attached',
          ),
        )
        .doOnCancel(() {
          _telemetry.track(AppLogCategory.firestore, 'room_listener_detached');
          _resetObservedRoom();
        })
        .doOnError(
          (error, stackTrace) => _telemetry.fail(
            AppLogCategory.firestore,
            'room_listener_failed',
            error: error,
            stackTrace: stackTrace,
          ),
        )
        .doOnData(_observeRoom);
  }

  /// Derives room lifecycle events from the snapshot stream.
  ///
  /// Everything observable from the room document is reported here rather
  /// than by each write path, for three reasons: a transition is recorded on
  /// every device that witnesses it and not only on the host's, the event
  /// fires whichever code path caused it, and it can only be emitted once
  /// per actual change because the comparison state lives on the repository
  /// (a singleton) rather than per subscription.
  ///
  /// Session Context is refreshed on every snapshot without emitting
  /// anything, so a crash always carries the current room, round, phase and
  /// player count at zero breadcrumb cost.
  void _observeRoom(Room? room) {
    if (room == null) {
      // The room document is gone: closed by cleanup, or deleted by the host.
      if (_lastPhase != null) {
        _telemetry.track(AppLogCategory.room, 'room_closed');
        _resetObservedRoom();
      }
      return;
    }

    _telemetry.updateContext({
      TelemetryKeys.roomCode: room.code,
      TelemetryKeys.hostId: room.hostId,
      TelemetryKeys.playerCount: room.players.length,
      TelemetryKeys.round: room.currentRound,
      TelemetryKeys.gameState: room.phase.name,
      TelemetryKeys.questionId: room.currentQuestionId,
    });

    final phase = room.phase.name;
    if (_lastPhase != null && _lastPhase != phase) {
      _telemetry.track(
        AppLogCategory.gameplay,
        'phase_changed',
        payload: {'from_phase': _lastPhase, 'to_phase': phase},
      );
    }
    _lastPhase = phase;

    // currentRound starts at 0 and becomes 1 when the match starts, so this
    // covers every round including the first.
    if (_lastRound != null && _lastRound != room.currentRound) {
      _telemetry.track(AppLogCategory.gameplay, 'round_started');
    }
    _lastRound = room.currentRound;

    final playerCount = room.players.length;
    final previousCount = _lastPlayerCount;
    if (previousCount != null && previousCount != playerCount) {
      _telemetry.track(
        AppLogCategory.player,
        playerCount > previousCount ? 'player_joined' : 'player_left',
        payload: {'previous_player_count': previousCount},
      );
    }
    _lastPlayerCount = playerCount;

    if (_lastHostId != null && _lastHostId != room.hostId) {
      _telemetry.track(
        AppLogCategory.room,
        'host_changed',
        payload: {'previous_host_id': _lastHostId},
      );
    }
    _lastHostId = room.hostId;
  }

  void _resetObservedRoom() {
    _lastPhase = null;
    _lastPlayerCount = null;
    _lastRound = null;
    _lastHostId = null;
  }

  // `updatePhase` and `_getCurrentPhase` were removed here. They had no
  // callers anywhere in the app, and between them performed three Firestore
  // reads (the room doc twice plus the players subcollection) purely to fill
  // analytics parameters for round transitions. Those transitions are now
  // derived from the room snapshot in `watchRoom`, at no read cost.

  /// Update entire room (use sparingly, prefer field-level updates)
  Future<void> updateRoom(Room room) async {
    final roomData = room.toJson();
    // Don't try to update players array - they're in subcollection
    await _write(
      'update_room',
      () => _firestore.collection('rooms').doc(room.code).update(roomData),
    );
  }

  /// Start the first round from lobby with a selected question.
  Future<void> startFirstRound({
    required String roomCode,
    required String questionId,
    required String questionText,
  }) async {
    final roomRef = _firestore.collection('rooms').doc(roomCode);

    await _transaction('start_first_round', () async {
      return await _firestore.runTransaction((transaction) async {
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
    });

    // Emitted only by the host, who owns this transition. Every other device
    // sees it as phase_changed through the room listener.
    _telemetry.track(AppLogCategory.gameplay, 'match_started');
  }

  /// Move from answering to voting after every active player has answered.
  Future<void> moveToVoting(
    String roomCode, {
    bool requireAllAnswered = true,
  }) async {
    final roomRef = _firestore.collection('rooms').doc(roomCode);

    await _transaction('move_to_voting', () async {
      return await _firestore.runTransaction((transaction) async {
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
    });
  }

  /// Move from voting to round results after every active player has voted.
  Future<void> moveToRoundResult(String roomCode) async {
    final roomRef = _firestore.collection('rooms').doc(roomCode);

    await _transaction('move_to_round_result', () async {
      return await _firestore.runTransaction((transaction) async {
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
    });
  }

  /// Move from round results to final winner once.
  ///
  /// Returns true only for the call that actually transitions the room. Repeated
  /// host taps after the transition are ignored so completion counters are not
  /// incremented twice.
  Future<bool> finishGame(String roomCode) async {
    final roomRef = _firestore.collection('rooms').doc(roomCode);

    return await _transaction('finish_game', () async {
      return _firestore.runTransaction((transaction) async {
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
      await _transaction('submit_answer', () async {
        return _firestore.runTransaction((transaction) async {
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
      });
      // Answers live in the player subcollection, so this transition is not
      // observable from the room snapshot the way phase and round are.
      _telemetry.track(
        AppLogCategory.gameplay,
        'answer_submitted',
        payload: {'answer_length': trimmedAnswer.length},
      );
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

    await _write('clear_round_data', () async {
      return batch.commit();
    });
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

    await _write('delete_room', () async {
      return batch.commit();
    });
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

    await _write('create_room', () async {
      return batch.commit();
    });

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

    await _transaction('join_room', () async {
      return _firestore.runTransaction((transaction) async {
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

    // Captured out of the transaction so the reason players vanished can be
    // reported after it commits. The room listener reports `player_left`,
    // but only cleanup knows it was a heartbeat timeout.
    var timedOutCount = 0;

    try {
      final result = await _transaction('cleanup_players', () async {
        return _firestore.runTransaction((transaction) async {
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

          timedOutCount = disconnectedPlayerIds.length;

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
          final hostStillActive = activePlayers.any(
            (p) => p.id == currentHostId,
          );

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
                transaction.update(
                  _playersCollection(roomCode).doc(player.id),
                  {'isHost': true},
                );
              } else if (player.id != newHostId && player.isHost) {
                transaction.update(
                  _playersCollection(roomCode).doc(player.id),
                  {'isHost': false},
                );
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
      });

      if (timedOutCount > 0) {
        _telemetry.track(
          AppLogCategory.network,
          'players_timed_out',
          payload: {
            'timed_out_count': timedOutCount,
            'room_deleted': result == null,
          },
        );
      }

      // Track disconnections outside transaction
      // The phase and remaining player count used to be re-read from
      // Firestore here just to fill analytics parameters. Both already ride
      // in Session Context via the room listener, so `players_timed_out`
      // above carries them for free.
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

    return await _transaction('can_start_game', () async {
      return _firestore.runTransaction((transaction) async {
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
    });
  }

  /// Increment games played counter after completing a game
  Future<void> incrementGamesPlayed(String roomCode) async {
    final roomRef = _firestore.collection('rooms').doc(roomCode);
    final today = _formatDate(DateTime.now());

    await _transaction('increment_games_played', () async {
      return _firestore.runTransaction((transaction) async {
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
    });
  }

  /// Grant ad unlock to room (called after watching rewarded ad)
  ///
  /// Uses transaction to prevent double reward
  Future<void> grantAdUnlock(String roomCode) async {
    final roomRef = _firestore.collection('rooms').doc(roomCode);

    await _transaction('grant_ad_unlock', () async {
      return _firestore.runTransaction((transaction) async {
        final roomSnapshot = await transaction.get(roomRef);
        if (!roomSnapshot.exists) {
          throw RoomException('Room not found', code: 'ROOM_NOT_FOUND');
        }

        transaction.update(roomRef, {
          'adUnlocksRemaining': FieldValue.increment(1),
        });
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
