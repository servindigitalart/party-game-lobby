// models/player.dart
class Player {
  final String id;
  final String name;
  final int score;
  final String? currentAnswer;
  final String? votedFor;
  final bool isHost;
  final DateTime lastSeen;
  final bool isOnline;

  Player({
    required this.id,
    required this.name,
    this.score = 0,
    this.currentAnswer,
    this.votedFor,
    this.isHost = false,
    DateTime? lastSeen,
    this.isOnline = true,
  }) : lastSeen = lastSeen ?? DateTime.now();

  /// Check if player is considered disconnected (no heartbeat for 20+ seconds)
  bool get isDisconnected {
    final timeSinceLastSeen = DateTime.now().difference(lastSeen);
    return timeSinceLastSeen.inSeconds > 20;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'score': score,
    'currentAnswer': currentAnswer,
    'votedFor': votedFor,
    'isHost': isHost,
    'lastSeen': lastSeen.toIso8601String(),
    'isOnline': isOnline,
  };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
    id: json['id'] as String,
    name: json['name'] as String,
    score: json['score'] as int? ?? 0,
    currentAnswer: json['currentAnswer'] as String?,
    votedFor: json['votedFor'] as String?,
    isHost: json['isHost'] as bool? ?? false,
    lastSeen: json['lastSeen'] != null
        ? DateTime.parse(json['lastSeen'] as String)
        : DateTime.now(),
    isOnline: json['isOnline'] as bool? ?? true,
  );

  Player copyWith({
    String? id,
    String? name,
    int? score,
    String? currentAnswer,
    String? votedFor,
    bool? isHost,
    DateTime? lastSeen,
    bool? isOnline,
  }) => Player(
    id: id ?? this.id,
    name: name ?? this.name,
    score: score ?? this.score,
    currentAnswer: currentAnswer ?? this.currentAnswer,
    votedFor: votedFor ?? this.votedFor,
    isHost: isHost ?? this.isHost,
    lastSeen: lastSeen ?? this.lastSeen,
    isOnline: isOnline ?? this.isOnline,
  );

  /// True when this player has submitted a usable answer this round.
  ///
  /// Matches the server's definition exactly — `moveToVoting`
  /// (`room_repository.dart`) and the ballot builder (`voting_screen.dart`)
  /// both require a non-empty answer after trimming, while the screens used
  /// to test only `currentAnswer != null`. Audit B **G-1J** recorded that
  /// divergence as latent; stating it once here removes it.
  bool get hasAnswered =>
      currentAnswer != null && currentAnswer!.trim().isNotEmpty;
}

/// Who a phase is actually waiting for.
///
/// WP22 / audit B **G-1F**: both completion predicates counted **every**
/// player document, with no filter at all. One player who had dropped or
/// backgrounded made `allAnswered` permanently false — so answering burned
/// the whole clock, and voting, which has no clock, stalled forever with no
/// recovery path. `Player.isDisconnected` already modelled the concept and
/// had **zero call sites in the entire application**; this extension is the
/// call site it never had.
///
/// Deliberately *not* a filter on the room's roster: a disconnected player is
/// still in the room, still owns their score, and is still removed only by
/// `cleanupDisconnectedPlayers`. This narrows exactly one thing — who a phase
/// is allowed to wait for.
extension PlayerEligibility on Iterable<Player> {
  /// Players a phase may block on. Presence, not participation: whether they
  /// have answered or voted is the *predicate's* business, not this one's.
  Iterable<Player> get eligible => where((player) => !player.isDisconnected);
}
