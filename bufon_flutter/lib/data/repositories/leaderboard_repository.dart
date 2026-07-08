// data/repositories/leaderboard_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/leaderboard_entry.dart';
import '../../core/exceptions.dart';

/// Repository for leaderboard operations
///
/// Handles:
/// - Updating global XP leaderboard
/// - Updating weekly leaderboards (XP, wins, votes)
/// - Fetching top players
/// - Fetching user rank
/// - Weekly reset logic
class LeaderboardRepository {
  final FirebaseFirestore _firestore;

  LeaderboardRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get leaderboard collection reference
  CollectionReference<Map<String, dynamic>> _getCollection(
    LeaderboardType type, {
    String? weekKey,
  }) {
    final path = 'leaderboards/${type.collectionName}';

    // For weekly leaderboards, use week-specific document
    if (type != LeaderboardType.globalXp) {
      final week = weekKey ?? WeekKey.current();
      return _firestore.collection(path).doc(week).collection('entries');
    }

    // For global, use direct entries
    return _firestore.collection('$path/entries');
  }

  /// Update global XP leaderboard
  ///
  /// Called when user gains XP
  Future<void> updateGlobalXP({
    required String uid,
    required String nickname,
    required String avatarId,
    required int xp,
    required int level,
  }) async {
    try {
      final docRef = _firestore
          .collection('leaderboards/global_xp/entries')
          .doc(uid);

      await docRef.set({
        'uid': uid,
        'nickname': nickname,
        'avatarId': avatarId,
        'xp': xp,
        'level': level,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw GameException('Failed to update global leaderboard: ${e.message}');
    }
  }

  /// Update weekly stats (XP, wins, votes)
  ///
  /// Called after game completion
  Future<void> updateWeeklyStats({
    required String uid,
    required String nickname,
    required String avatarId,
    required int level,
    required int xpGained,
    required int winsGained,
    required int votesGained,
  }) async {
    try {
      final weekKey = WeekKey.current();
      final batch = _firestore.batch();

      // Update weekly XP
      if (xpGained > 0) {
        final xpRef = _firestore
            .collection('leaderboards/weekly_xp/$weekKey/entries')
            .doc(uid);

        batch.set(xpRef, {
          'uid': uid,
          'nickname': nickname,
          'avatarId': avatarId,
          'level': level,
          'xp': FieldValue.increment(xpGained),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Update weekly wins
      if (winsGained > 0) {
        final winsRef = _firestore
            .collection('leaderboards/weekly_wins/$weekKey/entries')
            .doc(uid);

        batch.set(winsRef, {
          'uid': uid,
          'nickname': nickname,
          'avatarId': avatarId,
          'level': level,
          'totalWins': FieldValue.increment(winsGained),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Update weekly votes
      if (votesGained > 0) {
        final votesRef = _firestore
            .collection('leaderboards/weekly_votes/$weekKey/entries')
            .doc(uid);

        batch.set(votesRef, {
          'uid': uid,
          'nickname': nickname,
          'avatarId': avatarId,
          'level': level,
          'totalVotes': FieldValue.increment(votesGained),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
    } on FirebaseException catch (e) {
      throw GameException('Failed to update weekly leaderboards: ${e.message}');
    }
  }

  /// Fetch top players for a leaderboard type
  ///
  /// Returns up to [limit] top players ordered by stat value
  Future<List<LeaderboardEntry>> fetchTopPlayers({
    required LeaderboardType type,
    int limit = 50,
    String? weekKey,
  }) async {
    try {
      final collection = _getCollection(type, weekKey: weekKey);

      // Determine sort field based on type
      final String sortField;
      switch (type) {
        case LeaderboardType.globalXp:
        case LeaderboardType.weeklyXp:
          sortField = 'xp';
          break;
        case LeaderboardType.weeklyVotes:
          sortField = 'totalVotes';
          break;
        case LeaderboardType.weeklyWins:
          sortField = 'totalWins';
          break;
      }

      final querySnapshot = await collection
          .orderBy(sortField, descending: true)
          .limit(limit)
          .get();

      final entries = <LeaderboardEntry>[];
      for (var i = 0; i < querySnapshot.docs.length; i++) {
        final doc = querySnapshot.docs[i];
        final entry = LeaderboardEntry.fromJson(
          doc.data(),
          uid: doc.id,
          rank: i + 1, // Rank is 1-indexed
        );
        entries.add(entry);
      }

      return entries;
    } on FirebaseException catch (e) {
      throw GameException('Failed to fetch leaderboard: ${e.message}');
    }
  }

  /// Fetch user's rank for a leaderboard type
  ///
  /// Returns null if user is not on leaderboard
  Future<LeaderboardEntry?> fetchUserRank({
    required String uid,
    required LeaderboardType type,
    String? weekKey,
  }) async {
    try {
      final collection = _getCollection(type, weekKey: weekKey);

      // Get user's entry
      final userDoc = await collection.doc(uid).get();

      if (!userDoc.exists) {
        return null;
      }

      final userData = userDoc.data()!;
      final userEntry = LeaderboardEntry.fromJson(userData, uid: uid);

      // Determine sort field and user's stat value
      final String sortField;
      final int userStatValue;

      switch (type) {
        case LeaderboardType.globalXp:
        case LeaderboardType.weeklyXp:
          sortField = 'xp';
          userStatValue = userEntry.xp;
          break;
        case LeaderboardType.weeklyVotes:
          sortField = 'totalVotes';
          userStatValue = userEntry.totalVotes;
          break;
        case LeaderboardType.weeklyWins:
          sortField = 'totalWins';
          userStatValue = userEntry.totalWins;
          break;
      }

      // Count how many users have higher stats
      final higherScoresQuery = await collection
          .where(sortField, isGreaterThan: userStatValue)
          .count()
          .get();

      final rank = higherScoresQuery.count! + 1;

      return userEntry.copyWith(rank: rank);
    } on FirebaseException catch (e) {
      throw GameException('Failed to fetch user rank: ${e.message}');
    }
  }

  /// Check if weekly leaderboards need reset
  ///
  /// This is called automatically - old data remains archived
  /// New week data is created on-demand when users play
  Future<bool> shouldResetWeekly() async {
    // Weekly reset is automatic via week key
    // Old weeks remain archived in Firestore
    // No explicit reset needed
    return false;
  }

  /// Get current week key
  String getCurrentWeekKey() {
    return WeekKey.current();
  }

  /// Archive old weekly leaderboards (optional cleanup)
  ///
  /// Can be called via Cloud Function on weekly basis
  Future<void> archiveOldWeeklyLeaderboards({required int weeksToKeep}) async {
    // This would typically be handled by a Cloud Function
    // For now, just a placeholder
    // Old weeks are automatically "archived" by using week-specific documents
  }
}
