// models/leaderboard_entry.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of leaderboards
enum LeaderboardType {
  globalXp,
  weeklyXp,
  weeklyVotes,
  weeklyWins;

  String get collectionName {
    switch (this) {
      case LeaderboardType.globalXp:
        return 'global_xp';
      case LeaderboardType.weeklyXp:
        return 'weekly_xp';
      case LeaderboardType.weeklyVotes:
        return 'weekly_votes';
      case LeaderboardType.weeklyWins:
        return 'weekly_wins';
    }
  }

  String get displayName {
    switch (this) {
      case LeaderboardType.globalXp:
        return 'Ranking Global';
      case LeaderboardType.weeklyXp:
        return 'XP de la Semana';
      case LeaderboardType.weeklyVotes:
        return 'Más Carismático';
      case LeaderboardType.weeklyWins:
        return 'Más Ganador';
    }
  }

  String get statLabel {
    switch (this) {
      case LeaderboardType.globalXp:
        return 'XP Total';
      case LeaderboardType.weeklyXp:
        return 'XP';
      case LeaderboardType.weeklyVotes:
        return 'Votos';
      case LeaderboardType.weeklyWins:
        return 'Victorias';
    }
  }
}

/// Entry in a leaderboard
class LeaderboardEntry {
  final String uid;
  final String nickname;
  final String avatarId;
  final int xp;
  final int level;
  final int totalWins;
  final int totalVotes;
  final DateTime updatedAt;

  // Computed rank (not stored in Firestore)
  final int? rank;

  const LeaderboardEntry({
    required this.uid,
    required this.nickname,
    required this.avatarId,
    required this.xp,
    required this.level,
    required this.totalWins,
    required this.totalVotes,
    required this.updatedAt,
    this.rank,
  });

  /// Get the stat value for a specific leaderboard type
  int getStatValue(LeaderboardType type) {
    switch (type) {
      case LeaderboardType.globalXp:
      case LeaderboardType.weeklyXp:
        return xp;
      case LeaderboardType.weeklyVotes:
        return totalVotes;
      case LeaderboardType.weeklyWins:
        return totalWins;
    }
  }

  factory LeaderboardEntry.fromJson(
    Map<String, dynamic> json, {
    String? uid,
    int? rank,
  }) {
    return LeaderboardEntry(
      uid: uid ?? json['uid'] as String,
      nickname: json['nickname'] as String? ?? 'Jugador',
      avatarId: json['avatarId'] as String? ?? 'default',
      xp: json['xp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      totalWins: json['totalWins'] as int? ?? 0,
      totalVotes: json['totalVotes'] as int? ?? 0,
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rank: rank,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'nickname': nickname,
      'avatarId': avatarId,
      'xp': xp,
      'level': level,
      'totalWins': totalWins,
      'totalVotes': totalVotes,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  LeaderboardEntry copyWith({
    String? uid,
    String? nickname,
    String? avatarId,
    int? xp,
    int? level,
    int? totalWins,
    int? totalVotes,
    DateTime? updatedAt,
    int? rank,
  }) {
    return LeaderboardEntry(
      uid: uid ?? this.uid,
      nickname: nickname ?? this.nickname,
      avatarId: avatarId ?? this.avatarId,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      totalWins: totalWins ?? this.totalWins,
      totalVotes: totalVotes ?? this.totalVotes,
      updatedAt: updatedAt ?? this.updatedAt,
      rank: rank ?? this.rank,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeaderboardEntry &&
          runtimeType == other.runtimeType &&
          uid == other.uid;

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() =>
      'LeaderboardEntry(uid: $uid, nickname: $nickname, xp: $xp, rank: $rank)';
}

/// Helper to get current week key for weekly leaderboards
class WeekKey {
  /// Get week key in format: YYYY-WW (e.g., "2026-08")
  static String current() {
    final now = DateTime.now();
    final year = now.year;
    final weekNumber = _getWeekNumber(now);
    return '$year-${weekNumber.toString().padLeft(2, '0')}';
  }

  /// Calculate ISO week number
  static int _getWeekNumber(DateTime date) {
    // ISO 8601 week date system
    final dayOfYear = int.parse(
      date.difference(DateTime(date.year, 1, 1)).inDays.toString(),
    );
    final weekday = date.weekday;

    // Week 1 is the week with the first Thursday
    final week = ((dayOfYear - weekday + 10) / 7).floor();

    if (week < 1) {
      // Last week of previous year
      return _getWeekNumber(DateTime(date.year - 1, 12, 31));
    } else if (week > 52) {
      // Check if it's actually week 1 of next year
      if (DateTime(date.year, 12, 31).weekday < 4) {
        return 1;
      }
    }

    return week;
  }

  /// Check if a week key is current
  static bool isCurrent(String weekKey) {
    return weekKey == current();
  }
}
