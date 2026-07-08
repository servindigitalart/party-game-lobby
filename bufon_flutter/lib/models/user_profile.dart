// models/user_profile.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

/// User profile with progression data
class UserProfile {
  final String uid;
  final int xp;
  final int level;
  final int totalGames;
  final int totalWins;
  final int totalVotesReceived;
  final List<String> unlockedAchievements;
  final List<String> unlockedAvatars;
  final String selectedAvatar;
  final String? equippedTitleId; // Phase 4A: Title system
  final DateTime createdAt;
  final DateTime lastPlayed;

  const UserProfile({
    required this.uid,
    this.xp = 0,
    this.level = 1,
    this.totalGames = 0,
    this.totalWins = 0,
    this.totalVotesReceived = 0,
    this.unlockedAchievements = const [],
    this.unlockedAvatars = const ['default'], // Default avatar unlocked
    this.selectedAvatar = 'default',
    this.equippedTitleId,
    required this.createdAt,
    required this.lastPlayed,
  });

  /// Calculate level from XP
  /// Formula: level = floor(sqrt(xp / 100)) + 1
  static int calculateLevel(int xp) {
    return (sqrt(xp / 100)).floor() + 1;
  }

  /// Calculate XP required for next level
  int get xpForNextLevel {
    final nextLevel = level + 1;
    return (pow((nextLevel - 1), 2) * 100).toInt();
  }

  /// Calculate XP required for current level
  int get xpForCurrentLevel {
    if (level <= 1) return 0;
    return (pow((level - 1), 2) * 100).toInt();
  }

  /// Progress to next level (0.0 to 1.0)
  double get levelProgress {
    final currentLevelXp = xpForCurrentLevel;
    final nextLevelXp = xpForNextLevel;
    final xpInLevel = xp - currentLevelXp;
    final xpNeeded = nextLevelXp - currentLevelXp;

    if (xpNeeded <= 0) return 1.0;
    return (xpInLevel / xpNeeded).clamp(0.0, 1.0);
  }

  /// XP needed to reach next level
  int get xpToNextLevel {
    return (xpForNextLevel - xp).clamp(0, double.infinity).toInt();
  }

  /// Win rate percentage
  double get winRate {
    if (totalGames == 0) return 0.0;
    return (totalWins / totalGames) * 100;
  }

  /// Average votes per game
  double get averageVotesPerGame {
    if (totalGames == 0) return 0.0;
    return totalVotesReceived / totalGames;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json, {String? uid}) {
    final xpValue = json['xp'] as int? ?? 0;

    return UserProfile(
      uid: uid ?? json['uid'] as String,
      xp: xpValue,
      level: json['level'] as int? ?? calculateLevel(xpValue),
      totalGames: json['totalGames'] as int? ?? 0,
      totalWins: json['totalWins'] as int? ?? 0,
      totalVotesReceived: json['totalVotesReceived'] as int? ?? 0,
      unlockedAchievements:
          (json['unlockedAchievements'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      unlockedAvatars:
          (json['unlockedAvatars'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          ['default'],
      selectedAvatar: json['selectedAvatar'] as String? ?? 'default',
      equippedTitleId: json['equippedTitleId'] as String?,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastPlayed:
          (json['lastPlayed'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'xp': xp,
      'level': level,
      'totalGames': totalGames,
      'totalWins': totalWins,
      'totalVotesReceived': totalVotesReceived,
      'unlockedAchievements': unlockedAchievements,
      'unlockedAvatars': unlockedAvatars,
      'selectedAvatar': selectedAvatar,
      if (equippedTitleId != null) 'equippedTitleId': equippedTitleId,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastPlayed': Timestamp.fromDate(lastPlayed),
    };
  }

  UserProfile copyWith({
    String? uid,
    int? xp,
    int? level,
    int? totalGames,
    int? totalWins,
    int? totalVotesReceived,
    List<String>? unlockedAchievements,
    List<String>? unlockedAvatars,
    String? selectedAvatar,
    String? equippedTitleId,
    DateTime? createdAt,
    DateTime? lastPlayed,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      totalGames: totalGames ?? this.totalGames,
      totalWins: totalWins ?? this.totalWins,
      totalVotesReceived: totalVotesReceived ?? this.totalVotesReceived,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
      unlockedAvatars: unlockedAvatars ?? this.unlockedAvatars,
      selectedAvatar: selectedAvatar ?? this.selectedAvatar,
      equippedTitleId: equippedTitleId ?? this.equippedTitleId,
      createdAt: createdAt ?? this.createdAt,
      lastPlayed: lastPlayed ?? this.lastPlayed,
    );
  }

  /// Check if achievement is unlocked
  bool hasAchievement(String achievementId) {
    return unlockedAchievements.contains(achievementId);
  }

  /// Check if avatar is unlocked
  bool hasAvatar(String avatarId) {
    return unlockedAvatars.contains(avatarId);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          uid == other.uid;

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() =>
      'UserProfile(uid: $uid, level: $level, xp: $xp, games: $totalGames, wins: $totalWins)';
}
