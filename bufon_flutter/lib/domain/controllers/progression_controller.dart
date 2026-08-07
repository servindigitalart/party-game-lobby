// domain/controllers/progression_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_profile.dart';
import '../../models/achievement.dart';
import '../../models/avatar.dart';
import '../../analytics/analytics_service.dart';
import '../../core/exceptions.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_category.dart';
import 'leaderboard_controller.dart';
import 'title_controller.dart';

/// Controller for user progression (XP, achievements, avatars, titles)
///
/// Responsibilities:
/// - Increment XP and calculate level
/// - Unlock achievements atomically
/// - Unlock avatars based on requirements
/// - Unlock titles based on progression
/// - Update Firestore with transactions
/// - Prevent duplicate unlocks
/// - Track progression analytics
/// - Update leaderboards after game completion
class ProgressionController {
  final FirebaseFirestore _firestore;
  final AnalyticsService _analytics = AnalyticsService.instance;
  final LeaderboardController? _leaderboardController;
  final TitleController? _titleController;

  ProgressionController({
    FirebaseFirestore? firestore,
    LeaderboardController? leaderboardController,
    TitleController? titleController,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _leaderboardController = leaderboardController,
       _titleController = titleController;

  /// Get user's profile or create if doesn't exist
  Future<UserProfile> getOrCreateProfile(String uid) async {
    final docRef = _firestore.collection('users').doc(uid);
    final doc = await docRef.get();

    if (doc.exists) {
      return UserProfile.fromJson(doc.data()!, uid: uid);
    }

    // Create new profile
    final newProfile = UserProfile(
      uid: uid,
      createdAt: DateTime.now(),
      lastPlayed: DateTime.now(),
    );

    await docRef.set(newProfile.toJson());
    return newProfile;
  }

  /// Watch user profile in real-time
  Stream<UserProfile?> watchProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromJson(doc.data()!, uid: uid);
    });
  }

  /// Award XP and check for level up
  ///
  /// Returns new profile with updated XP and level
  /// Throws [ProgressionException] on error
  Future<UserProfile> awardXP({
    required String uid,
    required int xpAmount,
    required String reason,
  }) async {
    if (xpAmount <= 0) {
      throw ProgressionException('XP amount must be positive');
    }

    final docRef = _firestore.collection('users').doc(uid);

    return await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);

      final profile = doc.exists
          ? UserProfile.fromJson(doc.data()!, uid: uid)
          : UserProfile(
              uid: uid,
              createdAt: DateTime.now(),
              lastPlayed: DateTime.now(),
            );

      final newXp = profile.xp + xpAmount;
      final newLevel = UserProfile.calculateLevel(newXp);
      final didLevelUp = newLevel > profile.level;

      final updates = {
        'xp': newXp,
        'level': newLevel,
        'lastPlayed': FieldValue.serverTimestamp(),
      };

      if (doc.exists) {
        transaction.update(docRef, updates);
      } else {
        transaction.set(docRef, {...profile.toJson(), ...updates});
      }

      // Track analytics
      await _analytics.logXpAwarded(
        xpAmount: xpAmount,
        reason: reason,
        newXp: newXp,
        newLevel: newLevel,
        levelUp: didLevelUp,
      );

      if (didLevelUp) {
        await _analytics.logLevelUp(newLevel: newLevel, totalXp: newXp);
      }

      return profile.copyWith(
        xp: newXp,
        level: newLevel,
        lastPlayed: DateTime.now(),
      );
    });
  }

  /// Record game completion and award XP
  ///
  /// Awards:
  /// - +10 XP per game
  /// - +25 XP for winning
  /// - +5 XP per vote received
  Future<UserProfile> recordGameCompletion({
    required String uid,
    required bool isWinner,
    required int votesReceived,
  }) async {
    final docRef = _firestore.collection('users').doc(uid);

    return await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);

      final profile = doc.exists
          ? UserProfile.fromJson(doc.data()!, uid: uid)
          : UserProfile(
              uid: uid,
              createdAt: DateTime.now(),
              lastPlayed: DateTime.now(),
            );

      // Calculate XP award
      int xpGained = 10; // Base XP per game
      if (isWinner) xpGained += 25; // Bonus for winning
      xpGained += votesReceived * 5; // Bonus per vote

      final newXp = profile.xp + xpGained;
      final newLevel = UserProfile.calculateLevel(newXp);
      final newTotalGames = profile.totalGames + 1;
      final newTotalWins = profile.totalWins + (isWinner ? 1 : 0);
      final newTotalVotes = profile.totalVotesReceived + votesReceived;

      final updates = {
        'xp': newXp,
        'level': newLevel,
        'totalGames': newTotalGames,
        'totalWins': newTotalWins,
        'totalVotesReceived': newTotalVotes,
        'lastPlayed': FieldValue.serverTimestamp(),
      };

      if (doc.exists) {
        transaction.update(docRef, updates);
      } else {
        transaction.set(docRef, {...profile.toJson(), ...updates});
      }

      // Track analytics
      await _analytics.logGameCompleted(
        xpGained: xpGained,
        isWinner: isWinner,
        votesReceived: votesReceived,
        newTotalGames: newTotalGames,
        newTotalWins: newTotalWins,
      );

      return profile.copyWith(
        xp: newXp,
        level: newLevel,
        totalGames: newTotalGames,
        totalWins: newTotalWins,
        totalVotesReceived: newTotalVotes,
        lastPlayed: DateTime.now(),
      );
    });
  }

  /// Check and unlock achievements based on current profile
  ///
  /// Returns list of newly unlocked achievement IDs
  Future<List<String>> checkAndUnlockAchievements(String uid) async {
    final docRef = _firestore.collection('users').doc(uid);

    return await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);

      if (!doc.exists) return [];

      final profile = UserProfile.fromJson(doc.data()!, uid: uid);
      final newlyUnlocked = <String>[];

      // Check each achievement
      for (final achievement in Achievements.all) {
        if (profile.hasAchievement(achievement.id)) {
          continue; // Already unlocked
        }

        bool shouldUnlock = false;

        // Check unlock condition
        if (achievement.id == 'first_game' && profile.totalGames >= 1) {
          shouldUnlock = true;
        } else if (achievement.id == 'first_win' && profile.totalWins >= 1) {
          shouldUnlock = true;
        } else if (achievement.id == 'ten_games' && profile.totalGames >= 10) {
          shouldUnlock = true;
        } else if (achievement.id == 'five_wins' && profile.totalWins >= 5) {
          shouldUnlock = true;
        } else if (achievement.id == 'fifty_votes' &&
            profile.totalVotesReceived >= 50) {
          shouldUnlock = true;
        } else if (achievement.id == 'fifty_games' &&
            profile.totalGames >= 50) {
          shouldUnlock = true;
        } else if (achievement.id == 'twenty_wins' && profile.totalWins >= 20) {
          shouldUnlock = true;
        }

        if (shouldUnlock) {
          newlyUnlocked.add(achievement.id);
        }
      }

      if (newlyUnlocked.isEmpty) return [];

      // Update profile with new achievements and XP
      final updatedAchievements = [
        ...profile.unlockedAchievements,
        ...newlyUnlocked,
      ];

      final xpFromAchievements = newlyUnlocked
          .map((id) => Achievements.getById(id)?.xpReward ?? 0)
          .fold<int>(0, (total, xp) => total + xp);

      final newXp = profile.xp + xpFromAchievements;
      final newLevel = UserProfile.calculateLevel(newXp);

      transaction.update(docRef, {
        'unlockedAchievements': updatedAchievements,
        'xp': newXp,
        'level': newLevel,
      });

      // Track analytics for each achievement
      for (final achievementId in newlyUnlocked) {
        await _analytics.logAchievementUnlocked(
          achievementId: achievementId,
          xpReward: Achievements.getById(achievementId)?.xpReward ?? 0,
        );
      }

      return newlyUnlocked;
    });
  }

  /// Check and unlock avatars based on current profile
  ///
  /// Returns list of newly unlocked avatar IDs
  Future<List<String>> checkAndUnlockAvatars(String uid) async {
    final docRef = _firestore.collection('users').doc(uid);

    return await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);

      if (!doc.exists) return [];

      final profile = UserProfile.fromJson(doc.data()!, uid: uid);
      final newlyUnlocked = <String>[];

      // Check each avatar
      for (final avatar in Avatars.all) {
        if (profile.hasAvatar(avatar.id)) {
          continue; // Already unlocked
        }

        bool shouldUnlock = false;

        switch (avatar.requirementType) {
          case UnlockRequirement.level:
            shouldUnlock = profile.level >= avatar.requirementValue;
            break;
          case UnlockRequirement.gamesPlayed:
            shouldUnlock = profile.totalGames >= avatar.requirementValue;
            break;
          case UnlockRequirement.wins:
            shouldUnlock = profile.totalWins >= avatar.requirementValue;
            break;
          case UnlockRequirement.votesReceived:
            shouldUnlock =
                profile.totalVotesReceived >= avatar.requirementValue;
            break;
          case UnlockRequirement.achievement:
            if (avatar.achievementId != null) {
              shouldUnlock = profile.hasAchievement(avatar.achievementId!);
            }
            break;
          case UnlockRequirement.nightPass:
            // Will be unlocked manually when Night Pass is purchased
            shouldUnlock = false;
            break;
        }

        if (shouldUnlock) {
          newlyUnlocked.add(avatar.id);
        }
      }

      if (newlyUnlocked.isEmpty) return [];

      // Update profile with new avatars
      final updatedAvatars = [...profile.unlockedAvatars, ...newlyUnlocked];

      transaction.update(docRef, {'unlockedAvatars': updatedAvatars});

      // Track analytics for each avatar
      for (final avatarId in newlyUnlocked) {
        final avatar = Avatars.all.firstWhere(
          (a) => a.id == avatarId,
          orElse: () => Avatars.all.first,
        );
        await _analytics.logAvatarUnlocked(
          avatarId: avatarId,
          unlockMethod: avatar.requirementType == UnlockRequirement.nightPass
              ? 'night_pass'
              : 'progression',
        );
      }

      return newlyUnlocked;
    });
  }

  /// Unlock Night Pass avatar (called when Night Pass is purchased)
  Future<void> unlockNightPassAvatar(String uid) async {
    final docRef = _firestore.collection('users').doc(uid);

    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);

      final profile = doc.exists
          ? UserProfile.fromJson(doc.data()!, uid: uid)
          : UserProfile(
              uid: uid,
              createdAt: DateTime.now(),
              lastPlayed: DateTime.now(),
            );

      // Check if already unlocked
      if (profile.hasAvatar('night_pass')) return;

      // Also unlock night pass achievement
      final hasNightPassAchievement = profile.hasAchievement(
        'night_pass_purchase',
      );

      final updates = <String, dynamic>{
        'unlockedAvatars': FieldValue.arrayUnion(['night_pass']),
      };

      if (!hasNightPassAchievement) {
        updates['unlockedAchievements'] = FieldValue.arrayUnion([
          'night_pass_purchase',
        ]);
        updates['xp'] = FieldValue.increment(50); // Achievement XP
        final newXp = profile.xp + 50;
        updates['level'] = UserProfile.calculateLevel(newXp);
      }

      transaction.update(docRef, updates);

      await _analytics.logNightPassAvatarUnlocked();
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

      await _analytics.logAvatarSelected(avatarId: avatarId);
    });
  }

  /// Process all progression updates after game (achievements, avatars, etc.)
  ///
  /// This is the main entry point for post-game progression
  Future<ProgressionResult> processGameProgression({
    required String uid,
    required bool isWinner,
    required int votesReceived,
  }) async {
    try {
      // Track previous stats for leaderboard delta calculation
      final previousProfile = await getOrCreateProfile(uid);
      final previousXp = previousProfile.xp;
      final previousWins = previousProfile.totalWins;
      final previousVotes = previousProfile.totalVotesReceived;

      // 1. Record game completion (awards XP)
      final updatedProfile = await recordGameCompletion(
        uid: uid,
        isWinner: isWinner,
        votesReceived: votesReceived,
      );

      // 2. Check for new achievements
      final newAchievements = await checkAndUnlockAchievements(uid);

      // 3. Check for new avatars
      final newAvatars = await checkAndUnlockAvatars(uid);

      // 4. Check for new titles (Phase 4A)
      final newTitles = <String>[];
      final titleCtrl = _titleController;
      if (titleCtrl != null) {
        try {
          // Evaluate titles based on updated profile
          final titles = await titleCtrl.evaluateUnlockedTitles(
            uid: uid,
            profile: updatedProfile,
          );
          newTitles.addAll(titles);
        } catch (e) {
          // Don't fail progression if title evaluation fails
          AppLogger.instance.warning(
            AppLogCategory.player,
            'Title evaluation failed',
            context: {'uid': uid},
            error: e,
          );
        }
      }

      // 5. Update leaderboards with deltas
      final leaderboardCtrl = _leaderboardController;
      if (leaderboardCtrl != null) {
        final xpGained = updatedProfile.xp - previousXp;
        final winsGained = updatedProfile.totalWins - previousWins;
        final votesGained = updatedProfile.totalVotesReceived - previousVotes;

        await leaderboardCtrl.updateLeaderboardsAfterGame(
          uid: uid,
          nickname: 'Jugador', // TODO: Get actual nickname from user profile
          avatarId: updatedProfile.selectedAvatar,
          xp: updatedProfile.xp,
          level: updatedProfile.level,
          xpGained: xpGained,
          winsGained: winsGained,
          votesGained: votesGained,
        );
      }

      return ProgressionResult(
        profile: updatedProfile,
        newAchievements: newAchievements,
        newAvatars: newAvatars,
        newTitles: newTitles,
      );
    } catch (e) {
      throw ProgressionException('Failed to process progression: $e');
    }
  }
}

/// Result of progression processing
class ProgressionResult {
  final UserProfile profile;
  final List<String> newAchievements;
  final List<String> newAvatars;
  final List<String> newTitles;

  const ProgressionResult({
    required this.profile,
    required this.newAchievements,
    required this.newAvatars,
    this.newTitles = const [],
  });

  bool get hasNewUnlocks =>
      newAchievements.isNotEmpty ||
      newAvatars.isNotEmpty ||
      newTitles.isNotEmpty;

  @override
  String toString() =>
      'ProgressionResult(achievements: ${newAchievements.length}, avatars: ${newAvatars.length}, titles: ${newTitles.length})';
}
