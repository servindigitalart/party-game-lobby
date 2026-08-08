// domain/controllers/progression_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/telemetry/game_telemetry_service.dart';
import '../../models/user_profile.dart';
import '../../core/exceptions.dart';
import '../../core/logging/log_category.dart';

/// Read access to user progression, plus the one cosmetic choice a player
/// is allowed to make.
///
/// Progression is **server-authoritative**. XP, levels, games, wins, votes,
/// achievements, avatars, titles and leaderboards are all granted by the
/// `onMatchCompleted` Cloud Function through the Admin SDK, and
/// `firestore.rules` denies every one of those writes to clients. The
/// methods that used to perform them here were deleted rather than left to
/// fail with permission-denied.
///
/// What remains:
/// - Read the profile
/// - Watch the profile
/// - Select an avatar the server already granted
class ProgressionController {
  final FirebaseFirestore _firestore;
  final GameTelemetryService _telemetry = GameTelemetryService.instance;
  ProgressionController({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;


  /// Reads the player's profile.
  ///
  /// Cannot create one: profiles are created by the `onMatchCompleted` Cloud
  /// Function, and `firestore.rules` denies client creation outright. Until
  /// a player finishes their first match there is nothing stored, so an
  /// empty local profile is returned rather than writing one.
  Future<UserProfile> getOrCreateProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();

    if (doc.exists) {
      return UserProfile.fromJson(doc.data()!, uid: uid);
    }

    return UserProfile(
      uid: uid,
      createdAt: DateTime.now(),
      lastPlayed: DateTime.now(),
    );
  }

  /// Watch user profile in real-time
  Stream<UserProfile?> watchProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromJson(doc.data()!, uid: uid);
    });
  }

  /// Select avatar (must be unlocked)
  Future<void> selectAvatar({
    required String uid,
    required String avatarId,
  }) async {
    final docRef = _firestore.collection('users').doc(uid);

    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);

      if (!doc.exists) {
        throw ProgressionException('User profile not found');
      }

      final profile = UserProfile.fromJson(doc.data()!, uid: uid);

      // Verify avatar is unlocked
      if (!profile.hasAvatar(avatarId)) {
        throw ProgressionException('Avatar not unlocked');
      }

      transaction.update(docRef, {'selectedAvatar': avatarId});

      _telemetry.track(
        AppLogCategory.progression,
        'avatar_selected',
        payload: {'avatar_id': avatarId},
      );
    });
  }

}
