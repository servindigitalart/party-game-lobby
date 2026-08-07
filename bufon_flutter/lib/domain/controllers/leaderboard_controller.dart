// domain/controllers/leaderboard_controller.dart
import '../../data/repositories/leaderboard_repository.dart';
import '../../core/logging/log_category.dart';
import '../../core/telemetry/game_telemetry_service.dart';
import '../../models/leaderboard_entry.dart';
import '../../models/user_profile.dart';
import '../../core/exceptions.dart';

/// Controller for leaderboard operations
///
/// Responsibilities:
/// - Update leaderboards after game completion
/// - Fetch top players for display
/// - Fetch user's rank
/// - Track leaderboard analytics
class LeaderboardController {
  final LeaderboardRepository _repository;
  final GameTelemetryService _telemetry = GameTelemetryService.instance;

  LeaderboardController({LeaderboardRepository? repository})
    : _repository = repository ?? LeaderboardRepository();

  /// Update all leaderboards after game completion
  ///
  /// Called by ProgressionController after processing game progression
  /// Updates global XP and all weekly leaderboards in a batch
  Future<void> updateLeaderboardsAfterGame({
    required String uid,
    required String nickname,
    required String avatarId,
    required int xp,
    required int level,
    required int xpGained,
    required int winsGained,
    required int votesGained,
  }) async {
    try {
      // Update global XP leaderboard
      await _repository.updateGlobalXP(
        uid: uid,
        nickname: nickname,
        avatarId: avatarId,
        xp: xp,
        level: level,
      );

      // Update weekly leaderboards in a batch
      await _repository.updateWeeklyStats(
        uid: uid,
        nickname: nickname,
        avatarId: avatarId,
        level: level,
        xpGained: xpGained,
        winsGained: winsGained,
        votesGained: votesGained,
      );

      _telemetry.track(
        AppLogCategory.leaderboard,
        'leaderboards_updated',
        payload: {
          'xp_gained': xpGained,
          'wins_gained': winsGained,
          'votes_gained': votesGained,
        },
      );
    } catch (e) {
      throw GameException('Failed to update leaderboards: $e');
    }
  }

  /// Fetch top players for a specific leaderboard
  ///
  /// [type] - Leaderboard type (global XP, weekly XP, etc.)
  /// [limit] - Maximum number of players to fetch (default: 50)
  /// Returns list of entries sorted by rank
  Future<List<LeaderboardEntry>> fetchTopPlayers({
    required LeaderboardType type,
    int limit = 50,
  }) async {
    try {
      final entries = await _repository.fetchTopPlayers(
        type: type,
        limit: limit,
      );

      _telemetry.track(
        AppLogCategory.leaderboard,
        'leaderboard_viewed',
        payload: {'type': type.name, 'entries_count': entries.length},
      );

      return entries;
    } catch (e) {
      throw GameException('Failed to fetch top players: $e');
    }
  }

  /// Fetch user's current rank for a specific leaderboard
  ///
  /// Returns null if user is not on the leaderboard
  Future<LeaderboardEntry?> fetchUserRank({
    required String uid,
    required LeaderboardType type,
  }) async {
    try {
      final entry = await _repository.fetchUserRank(uid: uid, type: type);

      if (entry != null) {
        _telemetry.track(
          AppLogCategory.leaderboard,
          'leaderboard_rank_achieved',
          payload: {
            'type': type.name,
            'rank': entry.rank!,
            'stat_value': entry.getStatValue(type),
          },
        );
      }

      return entry;
    } catch (e) {
      throw GameException('Failed to fetch user rank: $e');
    }
  }

  /// Get current week key (for display purposes)
  String getCurrentWeekKey() {
    return _repository.getCurrentWeekKey();
  }

  /// Helper to update leaderboards from UserProfile
  ///
  /// Convenience method that extracts data from UserProfile
  Future<void> updateLeaderboardsFromProfile({
    required UserProfile profile,
    required int xpGained,
    required int winsGained,
    required int votesGained,
  }) async {
    await updateLeaderboardsAfterGame(
      uid: profile.uid,
      nickname: 'Jugador', // Default - will be overridden by actual nickname
      avatarId: profile.selectedAvatar,
      xp: profile.xp,
      level: profile.level,
      xpGained: xpGained,
      winsGained: winsGained,
      votesGained: votesGained,
    );
  }
}
