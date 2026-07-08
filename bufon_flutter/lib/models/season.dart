// models/season.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Season {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final int themeColor;
  final bool isActive;
  final DateTime createdAt;

  Season({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.themeColor,
    required this.isActive,
    required this.createdAt,
  });

  bool get isEnded => DateTime.now().isAfter(endDate);

  bool get isStarted => DateTime.now().isAfter(startDate);

  Duration get timeRemaining {
    if (isEnded) return Duration.zero;
    return endDate.difference(DateTime.now());
  }

  int get daysRemaining => timeRemaining.inDays;

  factory Season.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Season(
      id: doc.id,
      name: data['name'] as String,
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      themeColor: data['themeColor'] as int,
      isActive: data['isActive'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'themeColor': themeColor,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Season copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    int? themeColor,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Season(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      themeColor: themeColor ?? this.themeColor,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SeasonReward {
  final String id;
  final String seasonId;
  final String userId;
  final int rank;
  final String? titleId;
  final String? frameId;
  final String? badgeId;
  final DateTime grantedAt;

  SeasonReward({
    required this.id,
    required this.seasonId,
    required this.userId,
    required this.rank,
    this.titleId,
    this.frameId,
    this.badgeId,
    required this.grantedAt,
  });

  factory SeasonReward.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SeasonReward(
      id: doc.id,
      seasonId: data['seasonId'] as String,
      userId: data['userId'] as String,
      rank: data['rank'] as int,
      titleId: data['titleId'] as String?,
      frameId: data['frameId'] as String?,
      badgeId: data['badgeId'] as String?,
      grantedAt: (data['grantedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'seasonId': seasonId,
      'userId': userId,
      'rank': rank,
      'titleId': titleId,
      'frameId': frameId,
      'badgeId': badgeId,
      'grantedAt': Timestamp.fromDate(grantedAt),
    };
  }
}

class SeasonHistory {
  final String seasonId;
  final String seasonName;
  final int rank;
  final int totalXp;
  final String? titleEarned;
  final String? frameEarned;
  final String? badgeEarned;
  final DateTime endedAt;

  SeasonHistory({
    required this.seasonId,
    required this.seasonName,
    required this.rank,
    required this.totalXp,
    this.titleEarned,
    this.frameEarned,
    this.badgeEarned,
    required this.endedAt,
  });

  factory SeasonHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SeasonHistory(
      seasonId: doc.id,
      seasonName: data['seasonName'] as String,
      rank: data['rank'] as int,
      totalXp: data['totalXp'] as int,
      titleEarned: data['titleEarned'] as String?,
      frameEarned: data['frameEarned'] as String?,
      badgeEarned: data['badgeEarned'] as String?,
      endedAt: (data['endedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'seasonName': seasonName,
      'rank': rank,
      'totalXp': totalXp,
      'titleEarned': titleEarned,
      'frameEarned': frameEarned,
      'badgeEarned': badgeEarned,
      'endedAt': Timestamp.fromDate(endedAt),
    };
  }
}
