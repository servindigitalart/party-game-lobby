// domain/controllers/title_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/logging/log_category.dart';
import '../../core/telemetry/game_telemetry_service.dart';
import '../../models/title.dart';
import '../../models/user_profile.dart';
import '../../core/exceptions.dart';

/// Controller for title system
///
/// Responsibilities:
/// - Evaluate which titles a user has unlocked
/// - Unlock new titles
/// - Equip/unequip titles
/// - Watch user's unlocked titles
/// - Integrate with analytics
class TitleController {
  final FirebaseFirestore _firestore;
  final GameTelemetryService _telemetry = GameTelemetryService.instance;

  TitleController({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get user's unlocked titles
  Future<List<UnlockedTitle>> getUnlockedTitles(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('titles')
          .get();

      return snapshot.docs
          .map((doc) => UnlockedTitle.fromJson(doc.data(), doc.id))
          .toList();
    } on FirebaseException catch (e) {
      throw GameException('Failed to get unlocked titles: ${e.message}');
    }
  }

  /// Watch user's unlocked titles in real-time
  Stream<List<UnlockedTitle>> watchUserTitles(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('titles')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UnlockedTitle.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Evaluate and unlock new titles based on user profile
  ///
  /// Returns list of newly unlocked title IDs
  Future<List<String>> evaluateUnlockedTitles({
    required String uid,
    required UserProfile profile,
    int? globalRank,
    int? weeklyRank,
  }) async {
    try {
      final currentlyUnlocked = await getUnlockedTitles(uid);
      final unlockedIds = currentlyUnlocked.map((t) => t.titleId).toSet();
      final newlyUnlocked = <String>[];

      for (final title in Titles.all) {
        // Skip if already unlocked
        if (unlockedIds.contains(title.id)) continue;

        bool shouldUnlock = false;
        String source = 'milestone';

        // Check unlock conditions
        switch (title.unlockConditionType) {
          case UnlockConditionType.xp:
            shouldUnlock = profile.xp >= title.unlockValue;
            break;

          case UnlockConditionType.wins:
            shouldUnlock = profile.totalWins >= title.unlockValue;
            break;

          case UnlockConditionType.votes:
            shouldUnlock = profile.totalVotesReceived >= title.unlockValue;
            break;

          case UnlockConditionType.games:
            shouldUnlock = profile.totalGames >= title.unlockValue;
            break;

          case UnlockConditionType.leaderboardRank:
            source = 'leaderboard';
            if (globalRank != null && globalRank <= title.unlockValue) {
              shouldUnlock = true;
            } else if (weeklyRank != null && weeklyRank <= title.unlockValue) {
              shouldUnlock = true;
            }
            break;

          case UnlockConditionType.nightPass:
            // Check if user has night_pass_purchase achievement
            shouldUnlock = profile.hasAchievement('night_pass_purchase');
            source = 'achievement';
            break;

          case UnlockConditionType.achievement:
            if (title.achievementId != null) {
              shouldUnlock = profile.hasAchievement(title.achievementId!);
              source = 'achievement';
            }
            break;

          case UnlockConditionType.secret:
            // Secret titles have custom unlock logic
            // For now, skip them
            continue;
        }

        if (shouldUnlock) {
          await unlockTitle(uid: uid, titleId: title.id, source: source);
          newlyUnlocked.add(title.id);
        }
      }

      return newlyUnlocked;
    } catch (e) {
      throw GameException('Failed to evaluate titles: $e');
    }
  }

  /// Unlock a specific title for a user
  ///
  /// Uses transaction to prevent duplicate unlocks
  Future<void> unlockTitle({
    required String uid,
    required String titleId,
    required String source,
  }) async {
    try {
      final titleRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('titles')
          .doc(titleId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(titleRef);

        // Prevent duplicate unlock
        if (doc.exists) {
          return;
        }

        final unlockedTitle = UnlockedTitle(
          titleId: titleId,
          unlockedAt: DateTime.now(),
          source: source,
        );

        transaction.set(titleRef, unlockedTitle.toJson());
      });

      final title = Titles.getById(titleId);
      if (title != null) {
        _telemetry.track(
          AppLogCategory.progression,
          'title_unlocked',
          payload: {
            'title_id': titleId,
            'rarity': title.rarity.name,
            'source': source,
          },
        );
      }
    } on FirebaseException catch (e) {
      throw GameException('Failed to unlock title: ${e.message}');
    }
  }

  /// Equip a title for a user
  ///
  /// User must have unlocked the title first
  Future<void> equipTitle({
    required String uid,
    required String titleId,
  }) async {
    try {
      final userRef = _firestore.collection('users').doc(uid);
      final titleRef = userRef.collection('titles').doc(titleId);

      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final titleDoc = await transaction.get(titleRef);

        if (!userDoc.exists) {
          throw GameException('User profile not found');
        }

        if (!titleDoc.exists) {
          throw GameException('Title not unlocked');
        }

        transaction.update(userRef, {'equippedTitleId': titleId});
      });

      final title = Titles.getById(titleId);
      if (title != null) {
        _telemetry.track(
          AppLogCategory.progression,
          'title_equipped',
          payload: {'title_id': titleId, 'rarity': title.rarity.name},
        );
      }
    } on FirebaseException catch (e) {
      throw GameException('Failed to equip title: ${e.message}');
    }
  }

  /// Unequip current title
  Future<void> unequipTitle({required String uid}) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'equippedTitleId': FieldValue.delete(),
      });
    } on FirebaseException catch (e) {
      throw GameException('Failed to unequip title: ${e.message}');
    }
  }

  /// Check if user has unlocked a specific title
  Future<bool> hasTitleUnlocked({
    required String uid,
    required String titleId,
  }) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('titles')
          .doc(titleId)
          .get();

      return doc.exists;
    } on FirebaseException catch (e) {
      throw GameException('Failed to check title: ${e.message}');
    }
  }

  /// Get titles that user can unlock next (closest to unlocking)
  Future<List<BufonTitle>> getNextUnlockableTitles({
    required String uid,
    required UserProfile profile,
    int limit = 3,
  }) async {
    try {
      final unlocked = await getUnlockedTitles(uid);
      final unlockedIds = unlocked.map((t) => t.titleId).toSet();

      final available = Titles.all
          .where((t) => !unlockedIds.contains(t.id))
          .toList();

      // Sort by how close user is to unlocking
      available.sort((a, b) {
        final progressA = _getUnlockProgress(a, profile);
        final progressB = _getUnlockProgress(b, profile);
        return progressB.compareTo(progressA);
      });

      return available.take(limit).toList();
    } catch (e) {
      throw GameException('Failed to get next titles: $e');
    }
  }

  /// Calculate unlock progress (0.0 to 1.0)
  double _getUnlockProgress(BufonTitle title, UserProfile profile) {
    switch (title.unlockConditionType) {
      case UnlockConditionType.xp:
        return (profile.xp / title.unlockValue).clamp(0.0, 1.0);
      case UnlockConditionType.wins:
        return (profile.totalWins / title.unlockValue).clamp(0.0, 1.0);
      case UnlockConditionType.votes:
        return (profile.totalVotesReceived / title.unlockValue).clamp(0.0, 1.0);
      case UnlockConditionType.games:
        return (profile.totalGames / title.unlockValue).clamp(0.0, 1.0);
      default:
        return 0.0;
    }
  }
}
