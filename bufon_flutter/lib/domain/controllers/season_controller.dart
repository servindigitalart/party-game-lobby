// domain/controllers/season_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/season.dart';
import '../../models/leaderboard_entry.dart';
import '../../analytics/analytics_service.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_category.dart';

class SeasonController {
  final FirebaseFirestore _firestore;
  final AnalyticsService _analytics;

  SeasonController({FirebaseFirestore? firestore, AnalyticsService? analytics})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _analytics = analytics ?? AnalyticsService.instance;

  Future<Season?> getCurrentSeason() async {
    try {
      final querySnapshot = await _firestore
          .collection('seasons')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      return Season.fromFirestore(querySnapshot.docs.first);
    } catch (e) {
      AppLogger.instance.error(
        AppLogCategory.firestore,
        'Error getting current season',
        error: e,
      );
      return null;
    }
  }

  Future<Duration?> getSeasonCountdown() async {
    final season = await getCurrentSeason();
    if (season == null || season.isEnded) return null;
    return season.timeRemaining;
  }

  Future<void> finalizeSeason(String seasonId) async {
    try {
      final seasonRef = _firestore.collection('seasons').doc(seasonId);
      final seasonDoc = await seasonRef.get();

      if (!seasonDoc.exists) {
        throw Exception('Season not found');
      }

      final season = Season.fromFirestore(seasonDoc);

      if (!season.isActive) {
        AppLogger.instance.info(
          AppLogCategory.firestore,
          'Season already finalized',
          context: {'seasonId': seasonId},
        );
        return;
      }

      if (!season.isEnded) {
        throw Exception('Cannot finalize season before end date');
      }

      await _firestore.runTransaction((transaction) async {
        final freshDoc = await transaction.get(seasonRef);
        final freshSeason = Season.fromFirestore(freshDoc);

        if (!freshSeason.isActive) {
          AppLogger.instance.info(
            AppLogCategory.firestore,
            'Season already finalized in transaction',
            context: {'seasonId': seasonId},
          );
          return;
        }

        transaction.update(seasonRef, {'isActive': false});
      });

      await Future.wait([
        _rewardTopPlayers(seasonId),
        _archiveSeasonResults(seasonId),
      ]);

      await _analytics.logSeasonEnded(
        seasonId: seasonId,
        seasonName: season.name,
      );

      AppLogger.instance.info(
        AppLogCategory.firestore,
        'Season finalized successfully',
        context: {'seasonId': seasonId},
      );
    } catch (e) {
      AppLogger.instance.error(
        AppLogCategory.firestore,
        'Error finalizing season',
        context: {'seasonId': seasonId},
        error: e,
      );
      rethrow;
    }
  }

  Future<void> _rewardTopPlayers(String seasonId) async {
    try {
      final leaderboardSnapshot = await _firestore
          .collection('leaderboards')
          .doc('global_xp')
          .collection('entries')
          .orderBy('xp', descending: true)
          .limit(100)
          .get();

      final batch = _firestore.batch();
      final now = DateTime.now();

      for (int i = 0; i < leaderboardSnapshot.docs.length; i++) {
        final doc = leaderboardSnapshot.docs[i];
        final userId = doc.id;
        final rank = i + 1;
        final xp = doc.data()['xp'] as int;

        String? titleId;
        String? frameId;
        String? badgeId;

        if (rank == 1) {
          titleId = 'season_champion_legendary';
        } else if (rank <= 10) {
          frameId = 'animated_frame_top10';
        } else if (rank <= 100) {
          badgeId = 'season_top100_badge';
        }

        final rewardRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('seasonRewards')
            .doc(seasonId);

        batch.set(rewardRef, {
          'seasonId': seasonId,
          'userId': userId,
          'rank': rank,
          'titleId': titleId,
          'frameId': frameId,
          'badgeId': badgeId,
          'grantedAt': Timestamp.fromDate(now),
        });

        final historyRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('seasonHistory')
            .doc(seasonId);

        batch.set(historyRef, {
          'seasonName': 'Season ${seasonId.substring(0, 6)}',
          'rank': rank,
          'totalXp': xp,
          'titleEarned': titleId,
          'frameEarned': frameId,
          'badgeEarned': badgeId,
          'endedAt': Timestamp.fromDate(now),
        });

        if (titleId != null) {
          final userRef = _firestore.collection('users').doc(userId);
          batch.update(userRef, {
            'unlockedTitles': FieldValue.arrayUnion([titleId]),
          });
        }

        await _analytics.logSeasonRewardGranted(
          seasonId: seasonId,
          userId: userId,
          rank: rank,
          reward: titleId ?? frameId ?? badgeId ?? 'participation',
        );
      }

      await batch.commit();
      AppLogger.instance.info(
        AppLogCategory.firestore,
        'Rewarded ${leaderboardSnapshot.docs.length} top players',
        context: {'seasonId': seasonId},
      );
    } catch (e) {
      AppLogger.instance.error(
        AppLogCategory.firestore,
        'Error rewarding top players',
        context: {'seasonId': seasonId},
        error: e,
      );
      rethrow;
    }
  }

  Future<void> _archiveSeasonResults(String seasonId) async {
    try {
      final leaderboardSnapshot = await _firestore
          .collection('leaderboards')
          .doc('global_xp')
          .collection('entries')
          .orderBy('xp', descending: true)
          .limit(1000)
          .get();

      final batch = _firestore.batch();

      for (final doc in leaderboardSnapshot.docs) {
        final archiveRef = _firestore
            .collection('seasons')
            .doc(seasonId)
            .collection('final_results')
            .doc(doc.id);

        batch.set(archiveRef, {
          ...doc.data(),
          'archivedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      AppLogger.instance.info(
        AppLogCategory.firestore,
        'Archived ${leaderboardSnapshot.docs.length} results',
        context: {'seasonId': seasonId},
      );
    } catch (e) {
      AppLogger.instance.error(
        AppLogCategory.firestore,
        'Error archiving season results',
        context: {'seasonId': seasonId},
        error: e,
      );
      rethrow;
    }
  }

  Future<Season> createNextSeason({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required int themeColor,
  }) async {
    try {
      final currentSeason = await getCurrentSeason();
      if (currentSeason != null && currentSeason.isActive) {
        throw Exception('Cannot create new season while one is active');
      }

      final seasonRef = _firestore.collection('seasons').doc();
      final now = DateTime.now();

      final season = Season(
        id: seasonRef.id,
        name: name,
        startDate: startDate,
        endDate: endDate,
        themeColor: themeColor,
        isActive: true,
        createdAt: now,
      );

      await seasonRef.set(season.toFirestore());

      await _analytics.logSeasonStarted(
        seasonId: season.id,
        seasonName: season.name,
      );

      return season;
    } catch (e) {
      AppLogger.instance.error(
        AppLogCategory.firestore,
        'Error creating next season',
        error: e,
      );
      rethrow;
    }
  }

  Future<List<SeasonHistory>> getUserSeasonHistory(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('seasonHistory')
          .orderBy('endedAt', descending: true)
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => SeasonHistory.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.instance.error(
        AppLogCategory.firestore,
        'Error getting user season history',
        context: {'userId': userId},
        error: e,
      );
      return [];
    }
  }

  Future<int?> getUserSeasonRank(String userId, String seasonId) async {
    try {
      final historyDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('seasonHistory')
          .doc(seasonId)
          .get();

      if (!historyDoc.exists) return null;

      return historyDoc.data()?['rank'] as int?;
    } catch (e) {
      AppLogger.instance.error(
        AppLogCategory.firestore,
        'Error getting user season rank',
        context: {'userId': userId, 'seasonId': seasonId},
        error: e,
      );
      return null;
    }
  }

  Stream<Season?> watchCurrentSeason() {
    return _firestore
        .collection('seasons')
        .where('isActive', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return Season.fromFirestore(snapshot.docs.first);
        });
  }

  Future<List<LeaderboardEntry>> getSeasonLeaderboard({
    required String seasonId,
    int limit = 100,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('seasons')
          .doc(seasonId)
          .collection('final_results')
          .orderBy('xp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return LeaderboardEntry(
          uid: doc.id,
          nickname: data['username'] as String? ?? 'Unknown',
          avatarId: data['avatarId'] as String? ?? 'default',
          xp: data['xp'] as int? ?? 0,
          level: data['level'] as int? ?? 1,
          totalWins: data['totalWins'] as int? ?? 0,
          totalVotes: data['totalVotes'] as int? ?? 0,
          updatedAt:
              (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          rank: data['rank'] as int?,
        );
      }).toList();
    } catch (e) {
      AppLogger.instance.error(
        AppLogCategory.firestore,
        'Error getting season leaderboard',
        context: {'seasonId': seasonId},
        error: e,
      );
      return [];
    }
  }
}
