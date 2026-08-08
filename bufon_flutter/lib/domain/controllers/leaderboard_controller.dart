// domain/controllers/leaderboard_controller.dart
import '../../data/repositories/leaderboard_repository.dart';
import '../../core/logging/log_level.dart';
import '../../core/logging/log_category.dart';
import '../../core/telemetry/game_telemetry_service.dart';
import '../../models/leaderboard_entry.dart';
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
    } catch (e, stackTrace) {
      _readFailed('leaderboard_fetch_failed', e, stackTrace, {
        'type': type.name,
      });
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
    } catch (e, stackTrace) {
      _readFailed('leaderboard_rank_fetch_failed', e, stackTrace, {
        'type': type.name,
      });
      throw GameException('Failed to fetch user rank: $e');
    }
  }

  /// Records a failed leaderboard read.
  ///
  /// These run inside FutureProviders, which Riverpod rebuilds and retries.
  /// Warning severity keeps a player refreshing a leaderboard offline from
  /// turning into a stream of identical crash reports, while the breadcrumb
  /// still explains an empty screen.
  void _readFailed(
    String event,
    Object error,
    StackTrace stackTrace,
    Map<String, dynamic> payload,
  ) {
    _telemetry.fail(
      AppLogCategory.leaderboard,
      event,
      error: error,
      stackTrace: stackTrace,
      severity: AppLogLevel.warning,
      payload: payload,
    );
  }

  /// Get current week key (for display purposes)
  String getCurrentWeekKey() {
    return _repository.getCurrentWeekKey();
  }

}
