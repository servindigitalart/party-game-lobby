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

/// One row of the night's final ranking: a player, their competition rank,
/// and whether the server considers them a winner.
///
/// WP24 / **PD-4(a)**, R-17. The night's ranking used to be computed three
/// separate times from three different expressions — the ceremony
/// (`round_result_screen.dart`), the round scoreboard, and the round winner —
/// and only one of them broke ties. This is the single ranking R-17 asks for:
/// produced once, consumed by the winner presentation and the standings.
class FinalStanding {
  final Player player;

  /// **Competition ranking**: equal scores share a rank and the next rank
  /// skips accordingly, so 500/500/500/400 ranks 1/1/1/4 — never 1/1/1/2
  /// (dense) and never 1/2/3/4 (ordinal).
  final int rank;

  /// Exactly the server's rule at `onMatchCompleted.ts:167` —
  /// `score > 0 && score == topScore`. **A tie is reported, never broken.**
  final bool isWinner;

  const FinalStanding({
    required this.player,
    required this.rank,
    required this.isWinner,
  });
}

/// The night's final ranking, and the winner set that goes with it.
///
/// WP24 implements **PD-4(a)**: *the ceremony adopts the server's policy and
/// crowns all tied players*. Before this, the ceremony sorted by score with
/// **no tie-break** and took `.first` — and because Dart's `List.sort` is not
/// guaranteed stable and the input arrives in Firestore document-ID order,
/// the crowned player was whichever tied player's anonymous UID sorted first.
/// The server meanwhile crowned *all* of them, so the room saw one name while
/// the backend credited three. Audit B: *"Neither layer is wrong on its own
/// terms; they were simply never reconciled."*
///
/// The reconciliation is this: [isWinner] is computed from **score alone**,
/// with the server's exact expression. No tie-breaker is introduced, and none
/// can be — verified at HEAD, no second dimension exists (no `answeredAt`, no
/// `votedAt`, no `serverTimestamp` in the round-timing path, and `score` *is*
/// `100 × votes`, so votes are not an independent axis).
extension FinalRanking on Iterable<Player> {
  /// The whole room, ordered for display, ranked by competition ranking.
  ///
  /// **Population.** Every player, with no eligibility filter. This is
  /// deliberate and is the one thing that must not be "tidied": the server
  /// ranks every document in `rooms/{code}/players` and applies no
  /// disconnection filter, so filtering here with [PlayerEligibility.eligible]
  /// would drop a player the server still counts as a winner — exactly when a
  /// tied player's heartbeat lapses near the end. Gameplay eligibility and
  /// ranking population are different concepts and stay different.
  ///
  /// **Ordering within an equal score is presentation only.** Score is the
  /// only meaningful key; names order the rest so the list is stable and
  /// explicable rather than arbitrary. It cannot affect [FinalStanding.isWinner],
  /// which never reads position. Two players sharing a score *and* a name
  /// render identically, so the output is deterministic even though their
  /// relative order is not observable.
  List<FinalStanding> get finalRanking {
    final ordered = toList()
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        return a.name.compareTo(b.name);
      });
    if (ordered.isEmpty) return const [];

    // `ordered.first` is the maximum by construction. A top score of 0 means
    // nobody is crowned: `score > 0` is part of the server's rule, so a room
    // where no vote ever landed ends with an empty winner set rather than an
    // arbitrary player holding a zero-point crown.
    final topScore = ordered.first.score;

    final standings = <FinalStanding>[];
    var rank = 1;
    for (var i = 0; i < ordered.length; i++) {
      if (i > 0 && ordered[i].score != ordered[i - 1].score) rank = i + 1;
      standings.add(
        FinalStanding(
          player: ordered[i],
          rank: rank,
          isWinner: ordered[i].score > 0 && ordered[i].score == topScore,
        ),
      );
    }
    return standings;
  }

}
