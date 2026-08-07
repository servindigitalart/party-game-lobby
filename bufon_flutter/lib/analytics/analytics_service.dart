// analytics/analytics_service.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/crash/crash_reporter.dart';
import '../core/logging/app_logger.dart';
import '../core/logging/log_category.dart';
import 'analytics_events.dart';

/// Analytics service for BUFÓN
///
/// Singleton pattern - use AnalyticsService.instance
/// Integrates Firebase Analytics and Crashlytics
///
/// Design principles:
/// - No direct calls from UI (use controllers/services)
/// - Events batched automatically by Firebase
/// - Privacy-first (hash sensitive data)
/// - Performance-optimized (async, non-blocking)
class AnalyticsService {
  AnalyticsService._internal();
  static final AnalyticsService _instance = AnalyticsService._internal();
  static AnalyticsService get instance => _instance;

  FirebaseAnalytics? _analytics;
  SharedPreferences? _prefs;

  // Session tracking
  DateTime? _sessionStartTime;
  int _screensVisitedThisSession = 0;
  int _gamesPlayedThisSession = 0;

  bool _isInitialized = false;

  /// Initialize analytics service
  /// Call this once at app startup
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _analytics = FirebaseAnalytics.instance;
      _prefs = await SharedPreferences.getInstance();

      // Enable analytics collection
      await _analytics?.setAnalyticsCollectionEnabled(true);

      // Crash reporting and the global error handlers belong to
      // CrashReporter (docs/engineering/CRASHLYTICS.md — "Only
      // CrashReporter owns Crashlytics"). This service no longer touches
      // Crashlytics or FlutterError.onError.

      _isInitialized = true;

      AppLogger.instance.info(
        AppLogCategory.analytics,
        'Service initialized',
      );
    } catch (e) {
      AppLogger.instance.error(
        AppLogCategory.analytics,
        'Failed to initialize',
        error: e,
      );
    }
  }

  /// Set user properties for segmentation
  Future<void> setUserId(String userId) async {
    if (!_isInitialized) return;
    await _analytics?.setUserId(id: userId);
    CrashReporter.instance.setUser(userId);
  }

  Future<void> setUserProperty(String name, String value) async {
    if (!_isInitialized) return;
    await _analytics?.setUserProperty(name: name, value: value);
  }

  // ==========================================================================
  // GAMEPLAY EVENTS
  // ==========================================================================

  Future<void> logGameCreated({required String roomCode}) async {
    await _logEvent(
      AnalyticsEvents.gameCreated,
      parameters: {
        AnalyticsParameters.roomCodeHash: _hashString(roomCode),
        AnalyticsParameters.playerCount: 1,
      },
    );
  }

  Future<void> logGameJoined({
    required String roomCode,
    required int playerCount,
  }) async {
    await _logEvent(
      AnalyticsEvents.gameJoined,
      parameters: {
        AnalyticsParameters.roomCodeHash: _hashString(roomCode),
        AnalyticsParameters.playerCount: playerCount,
      },
    );
  }

  Future<void> logGameStarted({
    required String roomCode,
    required int playerCount,
    required int totalRounds,
  }) async {
    await _logEvent(
      AnalyticsEvents.gameStarted,
      parameters: {
        AnalyticsParameters.roomCodeHash: _hashString(roomCode),
        AnalyticsParameters.playerCount: playerCount,
        AnalyticsParameters.totalRounds: totalRounds,
      },
    );

    _gamesPlayedThisSession++;
  }

  Future<void> logRoundStarted({
    required String roomCode,
    required int roundNumber,
    required int playerCount,
    String? questionText,
  }) async {
    await _logEvent(
      AnalyticsEvents.roundStarted,
      parameters: {
        AnalyticsParameters.roomCodeHash: _hashString(roomCode),
        AnalyticsParameters.roundNumber: roundNumber,
        AnalyticsParameters.playerCount: playerCount,
        if (questionText != null)
          AnalyticsParameters.questionTextHash: _hashString(questionText),
      },
    );
  }

  Future<void> logRoundCompleted({
    required String roomCode,
    required int roundNumber,
    required int roundDurationSeconds,
    required int votesSubmitted,
  }) async {
    await _logEvent(
      AnalyticsEvents.roundCompleted,
      parameters: {
        AnalyticsParameters.roomCodeHash: _hashString(roomCode),
        AnalyticsParameters.roundNumber: roundNumber,
        AnalyticsParameters.roundDurationSeconds: roundDurationSeconds,
        AnalyticsParameters.votesSubmitted: votesSubmitted,
      },
    );
  }

  Future<void> logVoteSubmitted({
    required String roomCode,
    required int roundNumber,
    required int timeToVoteSeconds,
  }) async {
    await _logEvent(
      AnalyticsEvents.voteSubmitted,
      parameters: {
        AnalyticsParameters.roomCodeHash: _hashString(roomCode),
        AnalyticsParameters.roundNumber: roundNumber,
        AnalyticsParameters.timeToVoteSeconds: timeToVoteSeconds,
      },
    );
  }

  Future<void> logPlayerDisconnected({
    required String roomCode,
    required int playerCountRemaining,
    required String gamePhase,
  }) async {
    await _logEvent(
      AnalyticsEvents.playerDisconnected,
      parameters: {
        AnalyticsParameters.roomCodeHash: _hashString(roomCode),
        AnalyticsParameters.playerCountRemaining: playerCountRemaining,
        AnalyticsParameters.gamePhase: gamePhase,
      },
    );
  }

  Future<void> logGameFinished({
    required String roomCode,
    required int totalRounds,
    required int totalDurationSeconds,
    required int finalPlayerCount,
  }) async {
    await _logEvent(
      AnalyticsEvents.gameFinished,
      parameters: {
        AnalyticsParameters.roomCodeHash: _hashString(roomCode),
        AnalyticsParameters.totalRounds: totalRounds,
        AnalyticsParameters.gameDurationSeconds: totalDurationSeconds,
        AnalyticsParameters.finalPlayerCount: finalPlayerCount,
      },
    );
  }

  Future<void> logWinnerDeclared({
    required String roomCode,
    required int winningScore,
    required int totalPlayers,
    bool wasTiebreaker = false,
  }) async {
    await _logEvent(
      AnalyticsEvents.winnerDeclared,
      parameters: {
        AnalyticsParameters.roomCodeHash: _hashString(roomCode),
        AnalyticsParameters.winningScore: winningScore,
        AnalyticsParameters.totalPlayers: totalPlayers,
        AnalyticsParameters.wasTiebreaker: wasTiebreaker,
      },
    );
  }

  // ==========================================================================
  // MONETIZATION EVENTS
  // ==========================================================================

  Future<void> logPaywallShown({
    required String roomCode,
    required int gamesPlayedToday,
    required String triggerReason,
  }) async {
    await _logEvent(
      AnalyticsEvents.paywallShown,
      parameters: {
        AnalyticsParameters.roomCodeHash: _hashString(roomCode),
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
    await _logEvent(
      AnalyticsEvents.rewardedAdWatched,
      parameters: {
        AnalyticsParameters.roomCodeHash: _hashString(roomCode),
        AnalyticsParameters.adNetwork: adNetwork,
        AnalyticsParameters.gamesPlayedToday: gamesPlayedToday,
      },
    );
  }

  Future<void> logRewardedAdCompleted({
    required String roomCode,
    required int rewardAmount,
    required int timeToCompleteSeconds,
    String adNetwork = 'admob',
  }) async {
    await _logEvent(
      AnalyticsEvents.rewardedAdCompleted,
      parameters: {
        AnalyticsParameters.roomCodeHash: _hashString(roomCode),
        AnalyticsParameters.adNetwork: adNetwork,
        AnalyticsParameters.rewardAmount: rewardAmount,
        AnalyticsParameters.timeToCompleteSeconds: timeToCompleteSeconds,
      },
    );
  }

  Future<void> logRewardedAdFailed({
    required String roomCode,
    required String failureReason,
    String adNetwork = 'admob',
  }) async {
    await _logEvent(
      AnalyticsEvents.rewardedAdFailed,
      parameters: {
        AnalyticsParameters.roomCodeHash: _hashString(roomCode),
        AnalyticsParameters.adNetwork: adNetwork,
        AnalyticsParameters.failureReason: failureReason,
      },
    );
  }

  Future<void> logNightPassPurchaseInitiated({
    required String roomCode,
    required String productId,
    required int priceMicros,
    required String currency,
  }) async {
    await _logEvent(
      AnalyticsEvents.nightPassPurchaseInitiated,
      parameters: {
        AnalyticsParameters.roomCodeHash: _hashString(roomCode),
        AnalyticsParameters.productId: productId,
        AnalyticsParameters.priceMicros: priceMicros,
        AnalyticsParameters.currency: currency,
      },
    );
  }

  Future<void> logNightPassPurchased({
    required String roomCode,
    required String productId,
    required int purchaseValueMicros,
    required String currency,
    required String platform,
  }) async {
    await _logEvent(
      AnalyticsEvents.nightPassPurchased,
      parameters: {
        AnalyticsParameters.roomCodeHash: _hashString(roomCode),
        AnalyticsParameters.productId: productId,
        AnalyticsParameters.purchaseValueMicros: purchaseValueMicros,
        AnalyticsParameters.currency: currency,
        AnalyticsParameters.platform: platform,
      },
    );
  }

  Future<void> logNightPassActivated({
    required String roomCode,
    required bool activatedBySelf,
    required DateTime expiresAt,
  }) async {
    await _logEvent(
      AnalyticsEvents.nightPassActivated,
      parameters: {
        AnalyticsParameters.roomCodeHash: _hashString(roomCode),
        AnalyticsParameters.activatedBySelf: activatedBySelf,
        AnalyticsParameters.expiresAt: expiresAt.millisecondsSinceEpoch ~/ 1000,
      },
    );
  }

  Future<void> logGameBlockedByLimit({
    required String roomCode,
    required int gamesPlayedToday,
    required int bonusGamesRemaining,
  }) async {
    await _logEvent(
      AnalyticsEvents.gameBlockedByLimit,
      parameters: {
        AnalyticsParameters.roomCodeHash: _hashString(roomCode),
        AnalyticsParameters.gamesPlayedToday: gamesPlayedToday,
        AnalyticsParameters.bonusGamesRemaining: bonusGamesRemaining,
      },
    );
  }

  // ==========================================================================
  // RETENTION EVENTS
  // ==========================================================================

  Future<void> logAppOpened() async {
    final daysSinceInstall = await _getDaysSinceInstall();
    final totalSessions = await _incrementTotalSessions();

    await _logEvent(
      AnalyticsEvents.appOpened,
      parameters: {
        AnalyticsParameters.daysSinceInstall: daysSinceInstall,
        AnalyticsParameters.totalSessions: totalSessions,
      },
    );

    // Check for returning users
    await _checkReturnStatus();
  }

  Future<void> logSessionStarted() async {
    _sessionStartTime = DateTime.now();
    _screensVisitedThisSession = 0;
    _gamesPlayedThisSession = 0;

    final isFirstSession = await _isFirstSession();
    final timeOfDay = _getTimeOfDay();

    await _logEvent(
      AnalyticsEvents.sessionStarted,
      parameters: {
        AnalyticsParameters.timeOfDay: timeOfDay,
        AnalyticsParameters.isFirstSession: isFirstSession ? 1 : 0,
      },
    );

    // Update last session time
    await _prefs?.setInt(
      'last_session_start',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> logSessionEnded() async {
    if (_sessionStartTime == null) return;

    final sessionDuration = DateTime.now()
        .difference(_sessionStartTime!)
        .inSeconds;

    await _logEvent(
      AnalyticsEvents.sessionEnded,
      parameters: {
        AnalyticsParameters.sessionDurationSeconds: sessionDuration,
        AnalyticsParameters.screensVisited: _screensVisitedThisSession,
        AnalyticsParameters.gamesPlayed: _gamesPlayedThisSession,
      },
    );

    _sessionStartTime = null;
  }

  void trackScreenView(String screenName) {
    _screensVisitedThisSession++;
    _analytics?.logScreenView(screenName: screenName);
  }

  // ==========================================================================
  // QUALITY EVENTS
  // ==========================================================================

  Future<void> logGameplayError({
    required String errorType,
    required String errorPhase,
    bool isRecoverable = true,
    StackTrace? stackTrace,
  }) async {
    await _logEvent(
      AnalyticsEvents.gameplayError,
      parameters: {
        AnalyticsParameters.errorType: errorType,
        AnalyticsParameters.errorPhase: errorPhase,
        AnalyticsParameters.isRecoverable: isRecoverable,
      },
    );

    // Also report non-recoverable failures as a crash.
    if (!isRecoverable) {
      CrashReporter.instance.recordNonFatal(
        Exception(errorType),
        stackTrace: stackTrace,
        category: AppLogCategory.gameplay,
        reason: 'Gameplay error in $errorPhase',
      );
    }
  }

  Future<void> logHighLatency({
    required int latencyMs,
    required String actionType,
  }) async {
    if (latencyMs < 1000) return; // Only log if > 1 second

    await _logEvent(
      AnalyticsEvents.highLatency,
      parameters: {
        AnalyticsParameters.latencyMs: latencyMs,
        AnalyticsParameters.actionType: actionType,
      },
    );
  }

  Future<void> logFeedbackSubmitted({
    required String feedbackType,
    required int rating,
  }) async {
    await _logEvent(
      AnalyticsEvents.feedbackSubmitted,
      parameters: {
        AnalyticsParameters.feedbackType: feedbackType,
        AnalyticsParameters.rating: rating,
      },
    );
  }

  // ==========================================================================
  // PRIVATE HELPERS
  // ==========================================================================

  Future<void> _logEvent(String name, {Map<String, Object>? parameters}) async {
    if (!_isInitialized) return;

    try {
      await _analytics?.logEvent(name: name, parameters: parameters);

      AppLogger.instance.debug(
        AppLogCategory.analytics,
        'Event: $name',
        context: parameters,
      );
    } catch (e) {
      AppLogger.instance.error(
        AppLogCategory.analytics,
        'Failed to log event $name',
        error: e,
      );
    }
  }

  /// Hash sensitive data for privacy
  String _hashString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16); // First 16 chars
  }

  String _hashUserId(String userId) {
    return _hashString(userId);
  }

  /// Get days since first install
  Future<int> _getDaysSinceInstall() async {
    final installTime = _prefs?.getInt('first_install_time');
    if (installTime == null) {
      // First install
      await _prefs?.setInt(
        'first_install_time',
        DateTime.now().millisecondsSinceEpoch,
      );
      return 0;
    }

    final installDate = DateTime.fromMillisecondsSinceEpoch(installTime);
    return DateTime.now().difference(installDate).inDays;
  }

  /// Increment and return total sessions
  Future<int> _incrementTotalSessions() async {
    final current = _prefs?.getInt('total_sessions') ?? 0;
    final newTotal = current + 1;
    await _prefs?.setInt('total_sessions', newTotal);
    return newTotal;
  }

  /// Check if this is the first session
  Future<bool> _isFirstSession() async {
    final totalSessions = _prefs?.getInt('total_sessions') ?? 0;
    return totalSessions <= 1;
  }

  /// Get time of day category
  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 21) return 'evening';
    return 'night';
  }

  /// Check if user is returning and log appropriate event
  Future<void> _checkReturnStatus() async {
    final lastSession = _prefs?.getInt('last_session_start');
    if (lastSession == null) return;

    final lastSessionTime = DateTime.fromMillisecondsSinceEpoch(lastSession);
    final now = DateTime.now();
    final hoursSince = now.difference(lastSessionTime).inHours;
    final daysSince = now.difference(lastSessionTime).inDays;

    if (daysSince >= 7) {
      // Returned after a week
      await _logEvent(
        AnalyticsEvents.returnedAfterWeek,
        parameters: {AnalyticsParameters.daysSinceLastSession: daysSince},
      );
    } else if (daysSince == 1) {
      // Next day return (D1 retention)
      await _logEvent(
        AnalyticsEvents.returnedNextDay,
        parameters: {AnalyticsParameters.hoursSinceLastSession: hoursSince},
      );
    } else if (daysSince == 0 && hoursSince >= 1) {
      // Same day return
      await _logEvent(
        AnalyticsEvents.returnedSameDay,
        parameters: {AnalyticsParameters.hoursSinceLastSession: hoursSince},
      );
    }
  }

  // ==========================================================================
  // PROGRESSION ANALYTICS (Phase 3)
  // ==========================================================================

  Future<void> logXpAwarded({
    required int xpAmount,
    required String reason,
    required int newXp,
    required int newLevel,
    required bool levelUp,
  }) async {
    await _logEvent(
      AnalyticsEvents.xpAwarded,
      parameters: {
        'xp_amount': xpAmount,
        'reason': reason,
        'new_xp': newXp,
        'new_level': newLevel,
        'level_up': levelUp,
      },
    );
  }

  Future<void> logLevelUp({required int newLevel, required int totalXp}) async {
    await _logEvent(
      AnalyticsEvents.levelUp,
      parameters: {'new_level': newLevel, 'total_xp': totalXp},
    );
  }

  Future<void> logGameCompleted({
    required int xpGained,
    required bool isWinner,
    required int votesReceived,
    required int newTotalGames,
    required int newTotalWins,
  }) async {
    await _logEvent(
      AnalyticsEvents.gameCompleted,
      parameters: {
        'xp_gained': xpGained,
        'is_winner': isWinner,
        'votes_received': votesReceived,
        'new_total_games': newTotalGames,
        'new_total_wins': newTotalWins,
      },
    );
  }

  Future<void> logAchievementUnlocked({
    required String achievementId,
    required int xpReward,
  }) async {
    await _logEvent(
      AnalyticsEvents.achievementUnlocked,
      parameters: {'achievement_id': achievementId, 'xp_reward': xpReward},
    );
  }

  Future<void> logAvatarUnlocked({
    required String avatarId,
    required String unlockMethod,
  }) async {
    await _logEvent(
      AnalyticsEvents.avatarUnlocked,
      parameters: {'avatar_id': avatarId, 'unlock_method': unlockMethod},
    );
  }

  Future<void> logNightPassAvatarUnlocked() async {
    await _logEvent(AnalyticsEvents.nightPassAvatarUnlocked);
  }

  Future<void> logAvatarSelected({required String avatarId}) async {
    await _logEvent(
      AnalyticsEvents.avatarSelected,
      parameters: {'avatar_id': avatarId},
    );
  }

  // ==========================================================================
  // LEADERBOARD ANALYTICS (Phase 3C)
  // ==========================================================================

  Future<void> logLeaderboardsUpdated({
    required int xpGained,
    required int winsGained,
    required int votesGained,
    required String weekKey,
  }) async {
    await _logEvent(
      AnalyticsEvents.leaderboardsUpdated,
      parameters: {
        'xp_gained': xpGained,
        'wins_gained': winsGained,
        'votes_gained': votesGained,
        'week_key': weekKey,
      },
    );
  }

  Future<void> logLeaderboardViewed({
    required String type,
    String? weekKey,
    required int entriesCount,
  }) async {
    await _logEvent(
      AnalyticsEvents.leaderboardViewed,
      parameters: {
        'type': type,
        if (weekKey != null) 'week_key': weekKey,
        'entries_count': entriesCount,
      },
    );
  }

  Future<void> logLeaderboardRankAchieved({
    required String type,
    required int rank,
    required int statValue,
    String? weekKey,
  }) async {
    await _logEvent(
      AnalyticsEvents.leaderboardRankAchieved,
      parameters: {
        'type': type,
        'rank': rank,
        'stat_value': statValue,
        if (weekKey != null) 'week_key': weekKey,
      },
    );
  }

  // ==========================================================================
  // TITLE ANALYTICS (Phase 4A)
  // ==========================================================================

  Future<void> logTitleUnlocked({
    required String titleId,
    required String titleName,
    required String rarity,
    required String source,
  }) async {
    await _logEvent(
      AnalyticsEvents.titleUnlocked,
      parameters: {
        'title_id': titleId,
        'title_name': titleName,
        'rarity': rarity,
        'source': source,
      },
    );
  }

  Future<void> logTitleEquipped({
    required String titleId,
    required String titleName,
    required String rarity,
  }) async {
    await _logEvent(
      AnalyticsEvents.titleEquipped,
      parameters: {
        'title_id': titleId,
        'title_name': titleName,
        'rarity': rarity,
      },
    );
  }

  Future<void> logProfileViewed({
    required bool isOwnProfile,
    required bool hasTitle,
  }) async {
    await _logEvent(
      AnalyticsEvents.profileViewed,
      parameters: {'is_own_profile': isOwnProfile, 'has_title': hasTitle},
    );
  }

  Future<void> logProfileShared({
    required bool hasTitle,
    required int level,
  }) async {
    await _logEvent(
      AnalyticsEvents.profileShared,
      parameters: {'has_title': hasTitle, 'level': level},
    );
  }

  Future<void> logVictoryCardShared({
    required int votesReceived,
    required int roundWins,
  }) async {
    await _logEvent(
      AnalyticsEvents.victoryCardShared,
      parameters: {'votes_received': votesReceived, 'round_wins': roundWins},
    );
  }

  // ==========================================================================
  // SEASONAL EVENTS
  // ==========================================================================

  Future<void> logSeasonStarted({
    required String seasonId,
    required String seasonName,
  }) async {
    await _logEvent(
      AnalyticsEvents.seasonStarted,
      parameters: {'season_id': seasonId, 'season_name': seasonName},
    );
  }

  Future<void> logSeasonEnded({
    required String seasonId,
    required String seasonName,
  }) async {
    await _logEvent(
      AnalyticsEvents.seasonEnded,
      parameters: {'season_id': seasonId, 'season_name': seasonName},
    );
  }

  Future<void> logSeasonRewardGranted({
    required String seasonId,
    required String userId,
    required int rank,
    required String reward,
  }) async {
    await _logEvent(
      AnalyticsEvents.seasonRewardGranted,
      parameters: {
        'season_id': seasonId,
        'user_id_hash': _hashUserId(userId),
        'rank': rank,
        'reward': reward,
      },
    );
  }

  Future<void> logSeasonRankAchieved({
    required String seasonId,
    required int rank,
    required int totalXp,
  }) async {
    await _logEvent(
      AnalyticsEvents.seasonRankAchieved,
      parameters: {'season_id': seasonId, 'rank': rank, 'total_xp': totalXp},
    );
  }

  Future<void> logSeasonViewed({
    required String seasonId,
    required int daysRemaining,
  }) async {
    await _logEvent(
      AnalyticsEvents.seasonViewed,
      parameters: {'season_id': seasonId, 'days_remaining': daysRemaining},
    );
  }

  // ==========================================================================
  // QUALITY & PERFORMANCE
  // ==========================================================================
}
