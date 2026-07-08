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
}
