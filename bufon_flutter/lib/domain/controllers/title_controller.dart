// domain/controllers/title_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/logging/log_level.dart';
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
    } on FirebaseException catch (e, stackTrace) {
      _readFailed('titles_fetch_failed', e, stackTrace);
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
    } on FirebaseException catch (e, stackTrace) {
      // The player tapped a title and it did not stick: unexpected, and
      // worth a crash report.
      _telemetry.fail(
        AppLogCategory.progression,
        'title_equip_failed',
        error: e,
        stackTrace: stackTrace,
        payload: {'title_id': titleId},
      );
      throw GameException('Failed to equip title: ${e.message}');
    }
  }

  /// Unequip current title
  Future<void> unequipTitle({required String uid}) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'equippedTitleId': FieldValue.delete(),
      });
    } on FirebaseException catch (e, stackTrace) {
      _telemetry.fail(
        AppLogCategory.progression,
        'title_unequip_failed',
        error: e,
        stackTrace: stackTrace,
      );
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
    } on FirebaseException catch (e, stackTrace) {
      _readFailed('title_check_failed', e, stackTrace);
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
    } catch (e, stackTrace) {
      _readFailed('next_titles_fetch_failed', e, stackTrace);
      throw GameException('Failed to get next titles: $e');
    }
  }

  /// Records a failed read.
  ///
  /// Reads run inside providers that rebuild and retry, and the screen
  /// already shows an error state, so a failure here is recoverable and must
  /// stay a warning: it becomes a breadcrumb, never a crash report, and a
  /// player scrolling a list offline cannot flood Crashlytics.
  ///
  /// The original stack trace is forwarded explicitly. Wrapping in
  /// `GameException('...: $e')` stringifies the cause and throws from here,
  /// so without this the report would point at the wrapper instead of the
  /// Firestore call that actually failed.
  void _readFailed(String event, Object error, StackTrace stackTrace) {
    _telemetry.fail(
      AppLogCategory.progression,
      event,
      error: error,
      stackTrace: stackTrace,
      severity: AppLogLevel.warning,
    );
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
