// analytics/analytics_events.dart

/// Analytics event names for BUFÓN
///
/// All events are categorized by domain:
/// - Gameplay events: Track core game mechanics
/// - Monetization events: Track revenue and ads
/// - Retention events: Track user engagement
/// - Quality events: Track errors and performance
class AnalyticsEvents {
  AnalyticsEvents._();

  // ============================================================================
  // GAMEPLAY EVENTS
  // ============================================================================

  /// When a player creates a new game room
  /// Parameters:
  /// - room_code_hash: String (SHA256 of room code for privacy)
  /// - player_count: int (always 1 at creation)
  static const String gameCreated = 'game_created';

  /// When a player joins an existing room
  /// Parameters:
  /// - room_code_hash: String
  /// - player_count: int (total players after join)
  static const String gameJoined = 'game_joined';

  /// When host starts the game (transitions from lobby to gameplay)
  /// Parameters:
  /// - room_code_hash: String
  /// - player_count: int
  /// - total_rounds: int
  static const String gameStarted = 'game_started';

  /// When a new round begins
  /// Parameters:
  /// - room_code_hash: String
  /// - round_number: int
  /// - player_count: int
  /// - question_text_hash: String (for question popularity tracking)
  static const String roundStarted = 'round_started';

  /// When a round completes (all votes submitted)
  /// Parameters:
  /// - room_code_hash: String
  /// - round_number: int
  /// - round_duration_seconds: int
  /// - votes_submitted: int
  static const String roundCompleted = 'round_completed';

  /// When a player submits their vote
  /// Parameters:
  /// - room_code_hash: String
  /// - round_number: int
  /// - time_to_vote_seconds: int
  static const String voteSubmitted = 'vote_submitted';

  /// When a player disconnects (heartbeat timeout)
  /// Parameters:
  /// - room_code_hash: String
  /// - player_count_remaining: int
  /// - game_phase: String (lobby/playing/voting/results)
  static const String playerDisconnected = 'player_disconnected';

  /// When the entire game finishes
  /// Parameters:
  /// - room_code_hash: String
  /// - total_rounds: int
  /// - total_duration_seconds: int
  /// - final_player_count: int
  static const String gameFinished = 'game_finished';

  /// When a winner is declared
  /// Parameters:
  /// - room_code_hash: String
  /// - winning_score: int
  /// - total_players: int
  /// - was_tiebreaker: bool
  static const String winnerDeclared = 'winner_declared';

  // ============================================================================
  // PROGRESSION EVENTS (Phase 3)
  // ============================================================================

  /// When a player gains XP
  /// Parameters:
  /// - xp_amount: int
  /// - reason: String (e.g., 'game_completion', 'achievement')
  /// - new_xp: int
  /// - new_level: int
  /// - level_up: bool
  static const String xpAwarded = 'xp_awarded';

  /// When a player levels up
  /// Parameters:
  /// - new_level: int
  /// - total_xp: int
  static const String levelUp = 'level_up';

  /// When a game is completed
  /// Parameters:
  /// - xp_gained: int
  /// - is_winner: bool
  /// - votes_received: int
  /// - new_total_games: int
  /// - new_total_wins: int
  static const String gameCompleted = 'game_completed';

  /// When an achievement is unlocked
  /// Parameters:
  /// - achievement_id: String
  /// - xp_reward: int
  static const String achievementUnlocked = 'achievement_unlocked';

  /// When an avatar is unlocked
  /// Parameters:
  /// - avatar_id: String
  /// - unlock_method: String (e.g., 'achievement', 'level', 'night_pass')
  static const String avatarUnlocked = 'avatar_unlocked';

  /// When a Night Pass exclusive avatar is unlocked
  static const String nightPassAvatarUnlocked = 'night_pass_avatar_unlocked';

  /// When a player selects an avatar
  /// Parameters:
  /// - avatar_id: String
  static const String avatarSelected = 'avatar_selected';

  // ============================================================================
  // LEADERBOARD EVENTS (Phase 3C)
  // ============================================================================

  /// When leaderboard stats are updated after a game/progression event
  /// Parameters:
  /// - xp_gained: int
  /// - wins_gained: int
  /// - votes_gained: int
  /// - week_key: String
  static const String leaderboardsUpdated = 'leaderboards_updated';

  /// When a player views a leaderboard
  /// Parameters:
  /// - type: String
  /// - week_key: String?
  /// - entries_count: int
  static const String leaderboardViewed = 'leaderboard_viewed';

  /// When a player achieves a tracked leaderboard rank
  /// Parameters:
  /// - type: String
  /// - rank: int
  /// - stat_value: int
  /// - week_key: String?
  static const String leaderboardRankAchieved = 'leaderboard_rank_achieved';

  // ============================================================================
  // TITLE EVENTS (Phase 4A)
  // ============================================================================

  /// When a player unlocks a title
  /// Parameters:
  /// - title_id: String
  /// - title_name: String
  /// - rarity: String
  /// - source: String (achievement/leaderboard/milestone)
  static const String titleUnlocked = 'title_unlocked';

  /// When a player equips a title
  /// Parameters:
  /// - title_id: String
  /// - title_name: String
  /// - rarity: String
  static const String titleEquipped = 'title_equipped';

  /// When a player views a profile (own or other)
  /// Parameters:
  /// - is_own_profile: bool
  /// - has_title: bool
  static const String profileViewed = 'profile_viewed';

  /// When a player shares their profile
  /// Parameters:
  /// - has_title: bool
  /// - level: int
  static const String profileShared = 'profile_shared';

  /// When a player shares a victory card
  /// Parameters:
  /// - votes_received: int
  /// - round_wins: int
  static const String victoryCardShared = 'victory_card_shared';

  // ============================================================================
  // SEASONAL EVENTS (Phase 4C)
  // ============================================================================

  /// When a new season starts
  /// Parameters:
  /// - season_id: String
  /// - season_name: String
  static const String seasonStarted = 'season_started';

  /// When a season ends
  /// Parameters:
  /// - season_id: String
  /// - season_name: String
  static const String seasonEnded = 'season_ended';

  /// When a reward is granted to a player
  /// Parameters:
  /// - season_id: String
  /// - user_id_hash: String
  /// - rank: int
  /// - reward: String
  static const String seasonRewardGranted = 'season_reward_granted';

  /// When a player achieves a season rank
  /// Parameters:
  /// - season_id: String
  /// - rank: int
  /// - total_xp: int
  static const String seasonRankAchieved = 'season_rank_achieved';

  /// When a player views season details
  /// Parameters:
  /// - season_id: String
  /// - days_remaining: int
  static const String seasonViewed = 'season_viewed';

  // ============================================================================
  // MONETIZATION EVENTS
  // ============================================================================

  /// When the paywall screen is shown to a player
  /// Parameters:
  /// - room_code_hash: String
  /// - games_played_today: int
  /// - trigger_reason: String (free_limit/no_bonus_games)
  static const String paywallShown = 'paywall_shown';

  /// When a player initiates watching a rewarded ad
  /// Parameters:
  /// - room_code_hash: String
  /// - ad_network: String (admob)
  /// - games_played_today: int
  static const String rewardedAdWatched = 'rewarded_ad_watched';

  /// When a rewarded ad completes successfully
  /// Parameters:
  /// - room_code_hash: String
  /// - ad_network: String
  /// - reward_amount: int (bonus games granted)
  /// - time_to_complete_seconds: int
  static const String rewardedAdCompleted = 'rewarded_ad_completed';

  /// When a rewarded ad fails to complete
  /// Parameters:
  /// - room_code_hash: String
  /// - ad_network: String
  /// - failure_reason: String
  static const String rewardedAdFailed = 'rewarded_ad_failed';

  /// When a player initiates Night Pass purchase
  /// Parameters:
  /// - room_code_hash: String
  /// - product_id: String
  /// - price_micros: int
  /// - currency: String
  static const String nightPassPurchaseInitiated =
      'night_pass_purchase_initiated';

  /// When Night Pass purchase completes successfully
  /// Parameters:
  /// - room_code_hash: String
  /// - product_id: String
  /// - purchase_value_micros: int
  /// - currency: String
  /// - platform: String (android/ios)
  static const String nightPassPurchased = 'night_pass_purchased';

  /// When Night Pass is activated for a room
  /// Parameters:
  /// - room_code_hash: String
  /// - activated_by_self: bool
  /// - expires_at: int (timestamp)
  static const String nightPassActivated = 'night_pass_activated';

  /// When a game start is blocked by free game limit
  /// Parameters:
  /// - room_code_hash: String
  /// - games_played_today: int
  /// - bonus_games_remaining: int
  static const String gameBlockedByLimit = 'game_blocked_by_limit';

  // ============================================================================
  // RETENTION EVENTS
  // ============================================================================

  /// When the app is opened (cold start)
  /// Parameters:
  /// - days_since_install: int
  /// - total_sessions: int
  static const String appOpened = 'app_opened';

  /// When a user session starts
  /// Parameters:
  /// - time_of_day: String (morning/afternoon/evening/night)
  /// - is_first_session: bool
  static const String sessionStarted = 'session_started';

  /// When a user session ends
  /// Parameters:
  /// - session_duration_seconds: int
  /// - screens_visited: int
  /// - games_played: int
  static const String sessionEnded = 'session_ended';

  /// When a user returns on the same day
  /// Parameters:
  /// - hours_since_last_session: int
  static const String returnedSameDay = 'returned_same_day';

  /// When a user returns the next day (D1 retention)
  /// Parameters:
  /// - hours_since_last_session: int
  static const String returnedNextDay = 'returned_next_day';

  /// When a user returns after 7+ days
  /// Parameters:
  /// - days_since_last_session: int
  static const String returnedAfterWeek = 'returned_after_week';

  // ============================================================================
  // QUALITY EVENTS
  // ============================================================================

  /// When an error occurs during gameplay
  /// Parameters:
  /// - error_type: String
  /// - error_phase: String (lobby/gameplay/voting/results)
  /// - is_recoverable: bool
  static const String gameplayError = 'gameplay_error';

  /// When network latency is high
  /// Parameters:
  /// - latency_ms: int
  /// - action_type: String (vote/answer/join)
  static const String highLatency = 'high_latency';

  /// When a user provides feedback
  /// Parameters:
  /// - feedback_type: String (bug/feature/other)
  /// - rating: int (1-5)
  static const String feedbackSubmitted = 'feedback_submitted';
}

/// Parameter keys for analytics events
class AnalyticsParameters {
  AnalyticsParameters._();

  // Common
  static const String roomCodeHash = 'room_code_hash';
  static const String playerCount = 'player_count';
  static const String roundNumber = 'round_number';
  static const String gamePhase = 'game_phase';

  // Gameplay
  static const String totalRounds = 'total_rounds';
  static const String gameDurationSeconds = 'game_duration_seconds';
  static const String roundDurationSeconds = 'round_duration_seconds';
  static const String questionTextHash = 'question_text_hash';
  static const String votesSubmitted = 'votes_submitted';
  static const String timeToVoteSeconds = 'time_to_vote_seconds';
  static const String playerCountRemaining = 'player_count_remaining';
  static const String finalPlayerCount = 'final_player_count';
  static const String winningScore = 'winning_score';
  static const String totalPlayers = 'total_players';
  static const String wasTiebreaker = 'was_tiebreaker';

  // Monetization
  static const String gamesPlayedToday = 'games_played_today';
  static const String bonusGamesRemaining = 'bonus_games_remaining';
  static const String triggerReason = 'trigger_reason';
  static const String adNetwork = 'ad_network';
  static const String rewardAmount = 'reward_amount';
  static const String timeToCompleteSeconds = 'time_to_complete_seconds';
  static const String failureReason = 'failure_reason';
  static const String productId = 'product_id';
  static const String priceMicros = 'price_micros';
  static const String purchaseValueMicros = 'purchase_value_micros';
  static const String currency = 'currency';
  static const String platform = 'platform';
  static const String activatedBySelf = 'activated_by_self';
  static const String expiresAt = 'expires_at';

  // Retention
  static const String daysSinceInstall = 'days_since_install';
  static const String totalSessions = 'total_sessions';
  static const String timeOfDay = 'time_of_day';
  static const String isFirstSession = 'is_first_session';
  static const String sessionDurationSeconds = 'session_duration_seconds';
  static const String screensVisited = 'screens_visited';
  static const String gamesPlayed = 'games_played';
  static const String hoursSinceLastSession = 'hours_since_last_session';
  static const String daysSinceLastSession = 'days_since_last_session';

  // Quality
  static const String errorType = 'error_type';
  static const String errorPhase = 'error_phase';
  static const String isRecoverable = 'is_recoverable';
  static const String latencyMs = 'latency_ms';
  static const String actionType = 'action_type';
  static const String feedbackType = 'feedback_type';
  static const String rating = 'rating';
}
