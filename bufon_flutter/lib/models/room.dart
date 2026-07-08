// models/room.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'game_phase.dart';
import 'player.dart';

class Room {
  final String code;
  final String hostId;
  final GamePhase phase;
  final List<Player>
  players; // Loaded from subcollection, not stored in room doc
  final String? currentQuestionId;
  final String? currentQuestionText;
  final int currentRound;
  final int totalRounds;
  final DateTime? roundStartTime;
  final int roundDuration; // in seconds
  final DateTime createdAt;

  // Room-based monetization fields
  final int gamesPlayedToday;
  final int adUnlocksRemaining;
  final DateTime? nightPassExpiresAt;
  final String? lastGameDate; // yyyy-MM-dd format

  Room({
    required this.code,
    required this.hostId,
    this.phase = GamePhase.lobby,
    this.players = const [],
    this.currentQuestionId,
    this.currentQuestionText,
    this.currentRound = 0,
    this.totalRounds = 5,
    this.roundStartTime,
    this.roundDuration = 90,
    DateTime? createdAt,
    this.gamesPlayedToday = 0,
    this.adUnlocksRemaining = 0,
    this.nightPassExpiresAt,
    this.lastGameDate,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'code': code,
    'hostId': hostId,
    'phase': phase.name,
    // players NOT stored in room document (stored in subcollection)
    'currentQuestionId': currentQuestionId,
    'currentQuestionText': currentQuestionText,
    'currentRound': currentRound,
    'totalRounds': totalRounds,
    'roundStartTime': roundStartTime?.toIso8601String(),
    'roundDuration': roundDuration,
    'createdAt': createdAt.toIso8601String(),
    'gamesPlayedToday': gamesPlayedToday,
    'adUnlocksRemaining': adUnlocksRemaining,
    'nightPassExpiresAt': nightPassExpiresAt != null
        ? Timestamp.fromDate(nightPassExpiresAt!)
        : null,
    'lastGameDate': lastGameDate,
  };

  factory Room.fromJson(Map<String, dynamic> json, {List<Player>? players}) {
    return Room(
      code: json['code'] as String,
      hostId: json['hostId'] as String,
      phase: GamePhase.values.firstWhere(
        (e) => e.name == json['phase'],
        orElse: () => GamePhase.lobby,
      ),
      players: players ?? [], // Players loaded separately from subcollection
      currentQuestionId: json['currentQuestionId'] as String?,
      currentQuestionText: json['currentQuestionText'] as String?,
      currentRound: json['currentRound'] as int? ?? 0,
      totalRounds: json['totalRounds'] as int? ?? 5,
      roundStartTime: json['roundStartTime'] != null
          ? DateTime.parse(json['roundStartTime'] as String)
          : null,
      roundDuration: json['roundDuration'] as int? ?? 90,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      gamesPlayedToday: json['gamesPlayedToday'] as int? ?? 0,
      adUnlocksRemaining: json['adUnlocksRemaining'] as int? ?? 0,
      nightPassExpiresAt: json['nightPassExpiresAt'] != null
          ? (json['nightPassExpiresAt'] as Timestamp).toDate()
          : null,
      lastGameDate: json['lastGameDate'] as String?,
    );
  }

  Room copyWith({
    String? code,
    String? hostId,
    GamePhase? phase,
    List<Player>? players,
    String? currentQuestionId,
    String? currentQuestionText,
    int? currentRound,
    int? totalRounds,
    DateTime? roundStartTime,
    int? roundDuration,
    DateTime? createdAt,
    int? gamesPlayedToday,
    int? adUnlocksRemaining,
    DateTime? nightPassExpiresAt,
    String? lastGameDate,
  }) => Room(
    code: code ?? this.code,
    hostId: hostId ?? this.hostId,
    phase: phase ?? this.phase,
    players: players ?? this.players,
    currentQuestionId: currentQuestionId ?? this.currentQuestionId,
    currentQuestionText: currentQuestionText ?? this.currentQuestionText,
    currentRound: currentRound ?? this.currentRound,
    totalRounds: totalRounds ?? this.totalRounds,
    roundStartTime: roundStartTime ?? this.roundStartTime,
    roundDuration: roundDuration ?? this.roundDuration,
    createdAt: createdAt ?? this.createdAt,
    gamesPlayedToday: gamesPlayedToday ?? this.gamesPlayedToday,
    adUnlocksRemaining: adUnlocksRemaining ?? this.adUnlocksRemaining,
    nightPassExpiresAt: nightPassExpiresAt ?? this.nightPassExpiresAt,
    lastGameDate: lastGameDate ?? this.lastGameDate,
  );
}
