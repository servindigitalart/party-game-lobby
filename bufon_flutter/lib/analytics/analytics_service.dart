// analytics/analytics_service.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/logging/log_category.dart';
import '../core/telemetry/game_telemetry_service.dart';
import 'analytics_events.dart';

/// Remaining analytics surface for features that are not instrumented with
/// telemetry yet.
///
/// ## What this is now
///
/// This class no longer talks to Firebase. `AnalyticsDestination` owns
/// `FirebaseAnalytics`, and everything here emits a telemetry event that the
/// destination forwards, so there is exactly one path from an action to
/// Firebase (docs/telemetry/TELEMETRY_SPEC.md — "One event. Multiple
/// destinations.").
///
/// Every gameplay method is gone: room creation, joins, match start, rounds,
/// votes and disconnects are emitted by RoomRepository, GameController and
/// the room listener, and reach Firebase through the destination's registry.
/// Crash reporting moved to CrashReporter, and screen views to
/// `GameTelemetryService.transition`.
///
/// ## Why it still exists
///
/// Two reasons, both temporary:
///
/// 1. Progression, seasons, titles, leaderboards, ads and purchases have no
///    telemetry instrumentation yet. Their events are emitted here under
///    [AppLogCategory.analytics], which the destination forwards verbatim.
///    Each one moves into the mapping registry as its feature gets
///    instrumented properly.
/// 2. Retention metrics (days since install, session counts, return
///    windows) are stateful bookkeeping over SharedPreferences, which is
///    not something telemetry can derive on its own.
class AnalyticsService {
  AnalyticsService._internal();
  static final AnalyticsService _instance = AnalyticsService._internal();
  static AnalyticsService get instance => _instance;

  final GameTelemetryService _telemetry = GameTelemetryService.instance;

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  /// Loads the local store used for retention bookkeeping.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
  }

  // ==========================================================================
  // RETENTION
  // ==========================================================================

  /// Returns the retention metrics for this launch and records any return
  /// window that was crossed.
  ///
  /// The caller attaches the result to the `app_started` telemetry event, so
  /// one launch produces one analytics event rather than the `app_open` plus
  /// `session_started` pair this class used to emit alongside telemetry's own.
  Future<Map<String, dynamic>> readLaunchMetrics() async {
    if (!_isInitialized) return const {};

    final daysSinceInstall = await _daysSinceInstall();
    final totalSessions = await _incrementTotalSessions();

    await _recordReturnWindow();
    await _prefs?.setInt(
      'last_session_start',
      DateTime.now().millisecondsSinceEpoch,
    );

    return {
      AnalyticsParameters.daysSinceInstall: daysSinceInstall,
      AnalyticsParameters.totalSessions: totalSessions,
      AnalyticsParameters.timeOfDay: _timeOfDay(),
      AnalyticsParameters.isFirstSession: totalSessions <= 1,
    };
  }

  // ==========================================================================
  // MONETIZATION
  // ==========================================================================

  Future<void> logPaywallShown({
    required String roomCode,
    required int gamesPlayedToday,
    required String triggerReason,
  }) async {
    _emit(
      AnalyticsEvents.paywallShown,
      {
        AnalyticsParameters.gamesPlayedToday: gamesPlayedToday,
        AnalyticsParameters.triggerReason: triggerReason,
      },
    );
  }

  Future<void> logRewardedAdWatched({
    required String roomCode,
    required int gamesPlayedToday,
    String adNetwork = 'admob',
  }) async {
    _emit(AnalyticsEvents.rewardedAdWatched, {
      AnalyticsParameters.adNetwork: adNetwork,
      AnalyticsParameters.gamesPlayedToday: gamesPlayedToday,
    });
  }

  Future<void> logRewardedAdCompleted({
    required String roomCode,
    required int rewardAmount,
    required int timeToCompleteSeconds,
    String adNetwork = 'admob',
  }) async {
    _emit(AnalyticsEvents.rewardedAdCompleted, {
      AnalyticsParameters.adNetwork: adNetwork,
      AnalyticsParameters.rewardAmount: rewardAmount,
      AnalyticsParameters.timeToCompleteSeconds: timeToCompleteSeconds,
    });
  }

  Future<void> logRewardedAdFailed({
    required String roomCode,
    required String failureReason,
    String adNetwork = 'admob',
  }) async {
    _emit(AnalyticsEvents.rewardedAdFailed, {
      AnalyticsParameters.adNetwork: adNetwork,
      AnalyticsParameters.failureReason: failureReason,
    });
  }

  Future<void> logNightPassPurchaseInitiated({
    required String roomCode,
    required String productId,
    required int priceMicros,
    required String currency,
  }) async {
    _emit(AnalyticsEvents.nightPassPurchaseInitiated, {
      AnalyticsParameters.productId: productId,
      AnalyticsParameters.priceMicros: priceMicros,
      AnalyticsParameters.currency: currency,
    });
  }

  Future<void> logNightPassPurchased({
    required String roomCode,
    required String productId,
    required int purchaseValueMicros,
    required String currency,
    required String platform,
  }) async {
    _emit(AnalyticsEvents.nightPassPurchased, {
      AnalyticsParameters.productId: productId,
      AnalyticsParameters.purchaseValueMicros: purchaseValueMicros,
      AnalyticsParameters.currency: currency,
      AnalyticsParameters.platform: platform,
    });
  }

  Future<void> logNightPassActivated({
    required String roomCode,
    required bool activatedBySelf,
    required DateTime expiresAt,
  }) async {
    _emit(AnalyticsEvents.nightPassActivated, {
      AnalyticsParameters.activatedBySelf: activatedBySelf,
      AnalyticsParameters.expiresAt: expiresAt.millisecondsSinceEpoch ~/ 1000,
    });
  }

  // ==========================================================================
  // PROGRESSION
  // ==========================================================================

  Future<void> logXpAwarded({
    required int xpAmount,
    required String reason,
    required int newXp,
    required int newLevel,
    required bool levelUp,
  }) async {
    _emit(AnalyticsEvents.xpAwarded, {
      'xp_amount': xpAmount,
      'reason': reason,
      'new_xp': newXp,
      'new_level': newLevel,
      'level_up': levelUp,
    });
  }

  Future<void> logLevelUp({required int newLevel, required int totalXp}) async {
    _emit(AnalyticsEvents.levelUp, {
      'new_level': newLevel,
      'total_xp': totalXp,
    });
  }

  Future<void> logGameCompleted({
    required int xpGained,
    required bool isWinner,
    required int votesReceived,
    required int newTotalGames,
    required int newTotalWins,
  }) async {
    _emit(AnalyticsEvents.gameCompleted, {
      'xp_gained': xpGained,
      'is_winner': isWinner,
      'votes_received': votesReceived,
      'new_total_games': newTotalGames,
      'new_total_wins': newTotalWins,
    });
  }

  Future<void> logAchievementUnlocked({
    required String achievementId,
    required int xpReward,
  }) async {
    _emit(AnalyticsEvents.achievementUnlocked, {
      'achievement_id': achievementId,
      'xp_reward': xpReward,
    });
  }

  Future<void> logAvatarUnlocked({
    required String avatarId,
    required String unlockMethod,
  }) async {
    _emit(AnalyticsEvents.avatarUnlocked, {
      'avatar_id': avatarId,
      'unlock_method': unlockMethod,
    });
  }

  Future<void> logNightPassAvatarUnlocked() async {
    _emit(AnalyticsEvents.nightPassAvatarUnlocked, const {});
  }

  Future<void> logAvatarSelected({required String avatarId}) async {
    _emit(AnalyticsEvents.avatarSelected, {'avatar_id': avatarId});
  }

  // ==========================================================================
  // LEADERBOARDS
  // ==========================================================================

  Future<void> logLeaderboardsUpdated({
    required int xpGained,
    required int winsGained,
    required int votesGained,
    required String weekKey,
  }) async {
    _emit(AnalyticsEvents.leaderboardsUpdated, {
      'xp_gained': xpGained,
      'wins_gained': winsGained,
      'votes_gained': votesGained,
      'week_key': weekKey,
    });
  }

  Future<void> logLeaderboardViewed({
    required String type,
    String? weekKey,
    required int entriesCount,
  }) async {
    _emit(AnalyticsEvents.leaderboardViewed, {
      'type': type,
      if (weekKey != null) 'week_key': weekKey,
      'entries_count': entriesCount,
    });
  }

  Future<void> logLeaderboardRankAchieved({
    required String type,
    required int rank,
    required int statValue,
    String? weekKey,
  }) async {
    _emit(AnalyticsEvents.leaderboardRankAchieved, {
      'type': type,
      'rank': rank,
      'stat_value': statValue,
      if (weekKey != null) 'week_key': weekKey,
    });
  }

  // ==========================================================================
  // TITLES AND PROFILE
  // ==========================================================================

  Future<void> logTitleUnlocked({
    required String titleId,
    required String titleName,
    required String rarity,
    required String source,
  }) async {
    _emit(AnalyticsEvents.titleUnlocked, {
      'title_id': titleId,
      'title_name': titleName,
      'rarity': rarity,
      'source': source,
    });
  }

  Future<void> logTitleEquipped({
    required String titleId,
    required String titleName,
    required String rarity,
  }) async {
    _emit(AnalyticsEvents.titleEquipped, {
      'title_id': titleId,
      'title_name': titleName,
      'rarity': rarity,
    });
  }

  Future<void> logProfileViewed({
    required bool isOwnProfile,
    required bool hasTitle,
  }) async {
    _emit(AnalyticsEvents.profileViewed, {
      'is_own_profile': isOwnProfile,
      'has_title': hasTitle,
    });
  }

  Future<void> logProfileShared({
    required bool hasTitle,
    required int level,
  }) async {
    _emit(AnalyticsEvents.profileShared, {
      'has_title': hasTitle,
      'level': level,
    });
  }

  // ==========================================================================
  // SEASONS
  // ==========================================================================

  Future<void> logSeasonStarted({
    required String seasonId,
    required String seasonName,
  }) async {
    _emit(AnalyticsEvents.seasonStarted, {
      'season_id': seasonId,
      'season_name': seasonName,
    });
  }

  Future<void> logSeasonEnded({
    required String seasonId,
    required String seasonName,
  }) async {
    _emit(AnalyticsEvents.seasonEnded, {
      'season_id': seasonId,
      'season_name': seasonName,
    });
  }

  Future<void> logSeasonRewardGranted({
    required String seasonId,
    required String userId,
    required int rank,
    required String reward,
  }) async {
    _emit(AnalyticsEvents.seasonRewardGranted, {
      'season_id': seasonId,
      // Hashed here rather than in the destination: this is another
      // player's id, not the current user's.
      'user_id_hash': _hash(userId),
      'rank': rank,
      'reward': reward,
    });
  }

  Future<void> logSeasonRankAchieved({
    required String seasonId,
    required int rank,
    required int totalXp,
  }) async {
    _emit(AnalyticsEvents.seasonRankAchieved, {
      'season_id': seasonId,
      'rank': rank,
      'total_xp': totalXp,
    });
  }

  Future<void> logSeasonViewed({
    required String seasonId,
    required int daysRemaining,
  }) async {
    _emit(AnalyticsEvents.seasonViewed, {
      'season_id': seasonId,
      'days_remaining': daysRemaining,
    });
  }

  // ==========================================================================
  // PRIVATE HELPERS
  // ==========================================================================

  /// Emits an analytics-only event.
  ///
  /// [AppLogCategory.analytics] is what tells AnalyticsDestination to
  /// forward it verbatim, since these events have no mapping registry entry
  /// yet. Room code and player count are not passed: they already travel in
  /// Session Context and the destination attaches them.
  void _emit(String name, Map<String, dynamic> parameters) {
    _telemetry.track(
      AppLogCategory.analytics,
      name,
      payload: parameters,
    );
  }

  String _hash(String input) =>
      sha256.convert(utf8.encode(input)).toString().substring(0, 16);

  Future<int> _daysSinceInstall() async {
    final installTime = _prefs?.getInt('first_install_time');
    if (installTime == null) {
      await _prefs?.setInt(
        'first_install_time',
        DateTime.now().millisecondsSinceEpoch,
      );
      return 0;
    }
    return DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(installTime))
        .inDays;
  }

  Future<int> _incrementTotalSessions() async {
    final newTotal = (_prefs?.getInt('total_sessions') ?? 0) + 1;
    await _prefs?.setInt('total_sessions', newTotal);
    return newTotal;
  }

  String _timeOfDay() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 21) return 'evening';
    return 'night';
  }

  Future<void> _recordReturnWindow() async {
    final lastSession = _prefs?.getInt('last_session_start');
    if (lastSession == null) return;

    final since = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastSession),
    );

    if (since.inDays >= 7) {
      _emit(AnalyticsEvents.returnedAfterWeek, {
        AnalyticsParameters.daysSinceLastSession: since.inDays,
      });
    } else if (since.inDays == 1) {
      _emit(AnalyticsEvents.returnedNextDay, {
        AnalyticsParameters.hoursSinceLastSession: since.inHours,
      });
    } else if (since.inDays == 0 && since.inHours >= 1) {
      _emit(AnalyticsEvents.returnedSameDay, {
        AnalyticsParameters.hoursSinceLastSession: since.inHours,
      });
    }
  }
}
