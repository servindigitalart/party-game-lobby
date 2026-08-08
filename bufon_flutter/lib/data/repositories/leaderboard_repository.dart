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

  /// Get leaderboard collection reference.
  ///
  /// Every read and write goes through here. They used to build paths
  /// independently and had drifted apart — writes targeted
  /// `leaderboards/<type>/<week>/entries` while reads targeted
  /// `leaderboards/<type>`, and both had an even number of segments, which
  /// Firestore rejects as a collection reference before any request is
  /// sent.
  CollectionReference<Map<String, dynamic>> _getCollection(
    LeaderboardType type, {
    String? weekKey,
  }) {
    final typeDoc = _firestore.collection('leaderboards').doc(
      type.collectionName,
    );

    // For weekly leaderboards, entries live under the week key.
    //
    // This used to be `collection('leaderboards/<type>')`, an even number of
    // path segments, which is a *document* path: Firestore rejects it before
    // any request leaves the device. Every weekly leaderboard read and write
    // therefore threw, which is part of why this code had never run.
    if (type != LeaderboardType.globalXp) {
      return typeDoc.collection(weekKey ?? WeekKey.current());
    }

    // For global, use direct entries
    return typeDoc.collection('entries');
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
