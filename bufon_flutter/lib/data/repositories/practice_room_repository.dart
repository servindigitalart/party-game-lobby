// data/repositories/practice_room_repository.dart
import 'dart:async';

import '../../core/exceptions.dart';
import '../../core/moderation/content_filter.dart';
import '../../models/game_phase.dart';
import '../../models/player.dart';
import '../../models/room.dart';
import 'room_repository.dart';

/// Practice Mode's room, held entirely in memory.
///
/// **PD-12(c) / R-21.** Bufón needs three people on three phones, and that
/// requirement is real: `RoomRepository.startFirstRound` refuses to leave the
/// lobby below three players, and this class does not weaken it. Practice
/// satisfies it honestly instead — one human and two simulated bufones, three
/// players, the same guard.
///
/// **What this class is.** A substitute *persistence* layer, nothing more. It
/// implements the same interface [RoomRepository] exposes and is swapped in at
/// the existing `roomRepositoryProvider` seam, so the production lobby, game,
/// voting, round-result and ceremony screens drive a Practice game exactly as
/// they drive a multiplayer one. There is no second gameplay engine, no second
/// scoring engine, no second winner engine, and no forked screen.
///
/// **What it is not.** It is not a demo mode, a reviewer mode, or a test
/// hook. It is reached only by a person tapping "Practica solo" on Home. It
/// never inspects who the user is, whether the app is under review, how it was
/// built, or any remote value — the only thing that selects it is that
/// explicit tap.
///
/// **Firebase.** None. No Firestore document is read or written, no
/// authentication is required, and no Cloud Function is called. A Practice
/// game runs on a plane.
class PracticeRoomRepository implements RoomRepository {
  PracticeRoomRepository();

  /// The two simulated players. Fixed ids and names: a Practice game is
  /// reproducible, so a bug found in one is findable again in the next.
  /// A Practice room is local and single-occupancy, so its code is fixed
  /// rather than generated. Nothing can collide with it, and a reproducible
  /// code makes a reported Practice bug reproducible too.
  ///
  /// **Six characters, like every other room code.** The lobby's code card is
  /// laid out for the six `generateRoomCode` produces; an eight-character
  /// code overflowed it by 28 px at 390 pt. Practice reuses the production
  /// lobby, so it has to respect the production shape.
  static const String roomCode = 'PRACT1';

  static const String botOneId = 'practice-bot-1';
  static const String botTwoId = 'practice-bot-2';
  static const String botOneName = 'Chascarrillo';
  static const String botTwoName = 'Retruécano';

  /// Mirrors the server's award in `submitVote`: a vote is worth 100 points.
  /// Stated here because this class simulates the *persistence* of that rule,
  /// and the number must not drift from the one `onMatchCompleted` divides by.
  static const int pointsPerVote = 100;

  /// What the bufones write, indexed by round. Deterministic by construction:
  /// no `Random`, no clock, no identity. The same round always produces the
  /// same two answers, so a Practice run is reproducible by hand and in tests.
  static const List<String> _botOneAnswers = [
    'Un tamal con credencial de elector',
    'Mi tía bailando cumbia en la sala',
    'El perro que se robó las quesadillas',
    'Un chisme que ya sabía toda la cuadra',
    'La chancla voladora de mi mamá',
  ];

  static const List<String> _botTwoAnswers = [
    'El primo que llega sin avisar',
    'Una torta ahogada a las 3 de la mañana',
    'El vecino que canta en la regadera',
    'La foto que nadie quería que existiera',
    'Un microondas con vida propia',
  ];

  Room? _room;
  final StreamController<Room?> _rooms = StreamController<Room?>.broadcast();

  Room get _current {
    final room = _room;
    if (room == null) {
      throw RoomException('Practice room not found', code: 'ROOM_NOT_FOUND');
    }
    return room;
  }

  void _publish(Room room) {
    _room = room;
    if (!_rooms.isClosed) _rooms.add(room);
  }

  Player? _playerOrNull(Room room, String id) {
    for (final player in room.players) {
      if (player.id == id) return player;
    }
    return null;
  }

  List<Player> _replace(Room room, Player updated) => [
    for (final player in room.players)
      if (player.id == updated.id) updated else player,
  ];

  /// A fresh round for one player.
  ///
  /// `Player.copyWith` resolves every field with `??`, so it can set a value
  /// but never clear one — and clearing `currentAnswer`/`votedFor` is exactly
  /// what a new round needs. Rebuilding the player is the local fix; widening
  /// `copyWith` would be a model change this package has no business making.
  Player _clearedForNextRound(Player player) => Player(
    id: player.id,
    name: player.name,
    score: player.score,
    isHost: player.isHost,
    lastSeen: player.lastSeen,
    isOnline: player.isOnline,
  );

  // --- the bufones -------------------------------------------------------

  /// The answer a bot writes in [round]. Wraps once the list is exhausted, so
  /// a longer game keeps working without a special case.
  String _botAnswer(String botId, int round) {
    final answers = botId == botOneId ? _botOneAnswers : _botTwoAnswers;
    final index = (round - 1) % answers.length;
    return answers[index < 0 ? 0 : index];
  }

  /// Who a bot votes for in [round].
  ///
  /// Deterministic and self-vote-free, which is the same constraint the server
  /// enforces. The target alternates by round parity so a Practice night has
  /// some movement in the standings rather than the same winner every time —
  /// still entirely predictable, which is the point.
  String _botVote(String botId, int round, String humanId) {
    final even = round.isEven;
    if (botId == botOneId) return even ? botTwoId : humanId;
    return even ? humanId : botOneId;
  }

  /// Both bufones answer as soon as the round opens.
  ///
  /// Deliberately at the *start* of answering rather than in reaction to the
  /// human: the human is the host and drives the phase, so the bots must
  /// already be ready when they do. It also keeps the production completion
  /// predicate honest — `allAnswered` becomes true because three players
  /// really have answered.
  Room _botsAnswer(Room room) {
    var players = room.players;
    for (final botId in [botOneId, botTwoId]) {
      final bot = _playerOrNull(room, botId);
      if (bot == null) continue;
      players = [
        for (final player in players)
          if (player.id == botId)
            player.copyWith(currentAnswer: _botAnswer(botId, room.currentRound))
          else
            player,
      ];
    }
    return room.copyWith(players: players);
  }

  /// Both bufones vote, and the points land exactly as the server would land
  /// them: `pointsPerVote` to whoever was voted for.
  Room _botsVote(Room room) {
    var players = room.players;
    for (final botId in [botOneId, botTwoId]) {
      final bot = _playerOrNull(room, botId);
      if (bot == null || bot.votedFor != null) continue;

      final target = _botVote(botId, room.currentRound, room.hostId);
      players = [
        for (final player in players)
          if (player.id == botId)
            player.copyWith(votedFor: target)
          else if (player.id == target)
            player.copyWith(score: player.score + pointsPerVote)
          else
            player,
      ];
    }
    return room.copyWith(players: players);
  }

  // --- RoomRepository ----------------------------------------------------

  @override
  Future<Room> createRoom(String code, String hostId, String hostName) async {
    // The same policy as multiplayer, deliberately. Filtering is a property
    // of the input, not of the mode — a Practice-only exemption would be the
    // conditional behaviour R-21's non-goals forbid.
    ContentFilter.instance.enforce(hostName);
    // Three players from the first frame: the human as host, and the two
    // bufones as ordinary participants. Nothing downstream has to know they
    // are simulated — they are `Player`s like any other.
    final room = Room(
      code: code,
      hostId: hostId,
      phase: GamePhase.lobby,
      players: [
        Player(id: hostId, name: hostName, isHost: true),
        Player(id: botOneId, name: botOneName),
        Player(id: botTwoId, name: botTwoName),
      ],
    );
    _publish(room);
    return room;
  }

  @override
  Future<Room?> getRoom(String code) async => _room;

  @override
  Stream<Room?> watchRoom(String code) async* {
    if (_room != null) yield _room;
    yield* _rooms.stream;
  }

  @override
  Future<Room> joinRoom(String code, Player player) async {
    // A Practice room is full by definition — one human, two bufones. Nobody
    // else can join, and the production cap is respected rather than raised.
    throw RoomException('Room is full', code: 'ROOM_FULL');
  }

  @override
  Future<void> updateRoom(Room room) async => _publish(room);

  @override
  Future<void> startFirstRound({
    required String roomCode,
    required String questionId,
    required String questionText,
  }) async {
    final room = _current;
    if (room.phase != GamePhase.lobby) {
      throw RoomException('Game already started', code: 'GAME_ALREADY_STARTED');
    }
    // The production minimum, mirrored rather than skipped. Practice passes it
    // because it genuinely has three players.
    if (room.players.length < 3) {
      throw RoomException(
        'At least 3 players are required',
        code: 'NOT_ENOUGH_PLAYERS',
      );
    }

    _publish(
      _botsAnswer(
        room.copyWith(
          phase: GamePhase.answering,
          currentQuestionId: questionId,
          currentQuestionText: questionText,
          currentRound: 1,
          roundStartTime: DateTime.now(),
          usedQuestionIds: [...room.usedQuestionIds, questionId],
        ),
      ),
    );
  }

  @override
  Future<void> submitAnswerTransaction(
    String roomCode,
    String playerId,
    String answer,
  ) async {
    ContentFilter.instance.enforce(answer);
    final room = _current;
    final player = _playerOrNull(room, playerId);
    if (player == null) {
      throw RoomException('Player not found', code: 'PLAYER_NOT_FOUND');
    }
    _publish(
      room.copyWith(
        players: _replace(room, player.copyWith(currentAnswer: answer)),
      ),
    );
  }

  @override
  Future<void> moveToVoting(
    String roomCode, {
    bool requireAllAnswered = true,
  }) async {
    final room = _current;
    final answered = room.players.where((p) => p.hasAnswered).length;
    // Both WP22 ballot guards, mirrored.
    if (answered == 0) {
      throw RoomException(
        'No answers were submitted',
        code: 'NO_ANSWERS_SUBMITTED',
      );
    }
    if (answered < 2) {
      throw RoomException(
        'A ballot needs at least 2 answers',
        code: 'NOT_ENOUGH_ANSWERS',
      );
    }
    _publish(room.copyWith(phase: GamePhase.voting));
  }

  @override
  Future<void> submitVoteTransaction(
    String roomCode,
    String voterId,
    String votedForId,
  ) async {
    final room = _current;
    if (voterId == votedForId) {
      throw RoomException('You cannot vote for yourself', code: 'SELF_VOTE');
    }
    final voter = _playerOrNull(room, voterId);
    final target = _playerOrNull(room, votedForId);
    if (voter == null || target == null) {
      throw RoomException('Player not found', code: 'PLAYER_NOT_FOUND');
    }
    if (voter.votedFor != null) {
      throw RoomException('You already voted', code: 'ALREADY_VOTED');
    }

    var players = [
      for (final player in room.players)
        if (player.id == voterId)
          player.copyWith(votedFor: votedForId)
        else if (player.id == votedForId)
          player.copyWith(score: player.score + pointsPerVote)
        else
          player,
    ];

    // The bufones vote in the same beat, so the round completes without a
    // second device — which is the whole point of Practice.
    _publish(_botsVote(room.copyWith(players: players)));
  }

  @override
  Future<void> moveToRoundResult(String roomCode) async =>
      _publish(_current.copyWith(phase: GamePhase.roundResult));

  @override
  Future<void> advanceToNextRound({
    required String roomCode,
    required String questionId,
    required String questionText,
  }) async {
    final room = _current;
    if (room.phase != GamePhase.roundResult) {
      throw RoomException('Round is not finished', code: 'INVALID_PHASE');
    }
    final next = room.copyWith(
      phase: GamePhase.answering,
      currentQuestionId: questionId,
      currentQuestionText: questionText,
      currentRound: room.currentRound + 1,
      roundStartTime: DateTime.now(),
      usedQuestionIds: [...room.usedQuestionIds, questionId],
      players: [
        for (final player in room.players)
          _clearedForNextRound(player),
      ],
    );
    _publish(_botsAnswer(next));
  }

  @override
  Future<void> clearRoundData(String roomCode) async {
    final room = _current;
    _publish(
      room.copyWith(
        players: [
          for (final player in room.players)
            _clearedForNextRound(player),
        ],
      ),
    );
  }

  @override
  Future<bool> finishGame(String roomCode) async {
    final room = _current;
    if (room.phase == GamePhase.finalWinner) return false;
    _publish(room.copyWith(phase: GamePhase.finalWinner));
    return true;
  }

  /// Not available in Practice, and the throw is the honest answer.
  ///
  /// R-20 Package 2 added this to the repository interface, so this class has
  /// to satisfy it — but a Practice room holds one human and two bufones. The
  /// human is the host and cannot remove themselves, and the bufones are
  /// first-party constants, not people. Removing one would also break the
  /// three-player minimum Practice exists to satisfy honestly.
  ///
  /// **Practice's product contract is unchanged by this package.** The lobby
  /// never offers the control here, because the only other rows are bots.
  @override
  Future<void> removePlayer({
    required String roomCode,
    required String hostId,
    required String playerId,
  }) async {
    throw RoomException(
      'Players cannot be removed in Practice',
      code: 'NOT_SUPPORTED',
    );
  }

  @override
  Future<Room?> cleanupDisconnectedPlayers(String roomCode) async {
    // Nobody disconnects in Practice: the bufones are local and the human is
    // holding the phone. Returning the room unchanged keeps the production
    // call site working without giving it a special case.
    return _room;
  }

  /// Practice has no daily match limit and no paywall — there is nothing to
  /// monetise about playing against two local bufones.
  @override
  Future<bool> canRoomStartGame(String roomCode) async => true;

  @override
  Future<void> incrementGamesPlayed(String roomCode) async {}

  @override
  Future<void> grantAdUnlock(String roomCode) async {}

  @override
  Future<void> deleteRoom(String code) async {
    _room = null;
    if (!_rooms.isClosed) _rooms.add(null);
  }

  /// Releases the stream. The provider owns the lifecycle.
  void dispose() {
    if (!_rooms.isClosed) _rooms.close();
  }
}
