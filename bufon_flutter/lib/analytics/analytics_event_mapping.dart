// analytics/analytics_event_mapping.dart

import '../core/telemetry/telemetry_context.dart';
import '../core/telemetry/telemetry_event.dart';

/// How one telemetry event becomes one Firebase Analytics event.
///
/// The registry below is an **allowlist**: a telemetry event with no entry
/// never reaches Firebase. That is deliberate. Telemetry emits engineering
/// diagnostics (`firestore_transaction`, `heartbeat_failed`,
/// `room_listener_attached`) at a volume and granularity that is useful in
/// Talker and Crashlytics but meaningless — and expensive — as product
/// analytics (docs/engineering/ANALYTICS.md: "Avoid noisy events. Every
/// event should exist for a reason.").
class AnalyticsEventMapping {
  const AnalyticsEventMapping({
    this.name,
    this.failureName,
    this.resolveName,
    this.parameters = const [],
  });

  /// Analytics event name on success. Defaults to the telemetry event name,
  /// which is usually correct because both vocabularies are the snake_case
  /// names listed in docs/engineering/ANALYTICS.md.
  final String? name;

  /// Analytics event name when the telemetry event failed. `null` drops
  /// failures — most are engineering signal, not product signal.
  final String? failureName;

  /// Chooses the name from the event itself, for the few telemetry events
  /// that carry more than one product meaning. Wins over [name].
  final String? Function(TelemetryEvent event)? resolveName;

  /// Payload keys forwarded as analytics parameters. Everything else in the
  /// payload is dropped, so a payload can grow for debugging without
  /// silently changing what analytics collects.
  final List<String> parameters;

  /// Resolved analytics event name, or `null` if this event should not be
  /// forwarded at all.
  String? resolve(TelemetryEvent event) {
    switch (event.status) {
      case TelemetryStatus.succeeded:
      case TelemetryStatus.recovered:
        // A resolver's answer is authoritative, including `null`, which
        // means "this variant is already reported by another event".
        // Falling back to `name` here would resurrect the dropped ones.
        final resolver = resolveName;
        if (resolver != null) return resolver(event);
        return name ?? event.name;
      case TelemetryStatus.failed:
      case TelemetryStatus.timeout:
        return failureName;
      // `started` would double-count every operation, and the remaining
      // statuses are retries and no-ops.
      case TelemetryStatus.started:
      case TelemetryStatus.cancelled:
      case TelemetryStatus.retried:
      case TelemetryStatus.ignored:
        return null;
    }
  }
}

/// A phase transition carries several distinct product meanings, so it is
/// the one event whose analytics name depends on its payload. Splitting it
/// into separate telemetry events instead would break the single-source rule
/// established in RoomRepository.watchRoom.
String? _phaseChangedName(TelemetryEvent event) {
  switch (event.payload['to_phase']) {
    case 'voting':
      return 'voting_started';
    case 'roundResult':
      return 'round_finished';
    case 'finalWinner':
      return 'match_finished';
    // `answering` is already reported as round_started.
    default:
      return null;
  }
}

/// Telemetry event name → Firebase Analytics mapping.
const Map<String, AnalyticsEventMapping> analyticsEventMappings = {
  // --- Session / retention ---
  'app_started': AnalyticsEventMapping(
    name: 'app_open',
    parameters: [
      'days_since_install',
      'total_sessions',
      'time_of_day',
      'is_first_session',
    ],
  ),
  'session_started': AnalyticsEventMapping(),
  'session_ended': AnalyticsEventMapping(),
  'app_backgrounded': AnalyticsEventMapping(name: 'app_background'),
  'app_resumed': AnalyticsEventMapping(name: 'app_foreground'),

  // --- Room lifecycle ---
  'room_created': AnalyticsEventMapping(
    failureName: 'room_creation_failed',
    parameters: ['attempts'],
  ),
  'room_joined': AnalyticsEventMapping(failureName: 'room_join_failed'),
  'room_closed': AnalyticsEventMapping(),
  'player_joined': AnalyticsEventMapping(),
  'player_left': AnalyticsEventMapping(),
  'host_changed': AnalyticsEventMapping(name: 'host_transferred'),

  // --- Gameplay ---
  'match_started': AnalyticsEventMapping(),
  'match_blocked_by_limit': AnalyticsEventMapping(
    name: 'game_blocked_by_limit',
  ),
  'round_started': AnalyticsEventMapping(),
  'phase_changed': AnalyticsEventMapping(resolveName: _phaseChangedName),
  'answer_submitted': AnalyticsEventMapping(),
  'vote_submitted': AnalyticsEventMapping(parameters: ['time_to_vote_seconds']),

  // --- Networking ---
  'players_timed_out': AnalyticsEventMapping(
    name: 'player_disconnected',
    parameters: ['timed_out_count'],
  ),
  'connection_lost': AnalyticsEventMapping(
    // A lost connection is a product fact, not just an engineering one:
    // it explains abandoned matches.
    failureName: 'connection_lost',
  ),
  'connection_restored': AnalyticsEventMapping(
    name: 'player_reconnected',
    parameters: ['missed_beats'],
  ),

  // --- Sharing ---
  'victory_card_shared': AnalyticsEventMapping(
    parameters: ['votes_received', 'round_wins'],
  ),
  'profile_viewed': AnalyticsEventMapping(
    parameters: ['is_own_profile', 'has_title'],
  ),
  'profile_shared': AnalyticsEventMapping(parameters: ['has_title', 'level']),

  // --- Progression ---
  'xp_awarded': AnalyticsEventMapping(
    parameters: ['xp_amount', 'reason', 'new_level', 'level_up'],
  ),
  'level_up': AnalyticsEventMapping(parameters: ['new_level', 'total_xp']),
  'game_completed': AnalyticsEventMapping(
    parameters: [
      'xp_gained',
      'is_winner',
      'votes_received',
      'total_games',
      'total_wins',
    ],
  ),
  'achievement_unlocked': AnalyticsEventMapping(
    parameters: ['achievement_id', 'xp_reward'],
  ),
  'avatar_unlocked': AnalyticsEventMapping(
    parameters: ['avatar_id', 'unlock_method'],
  ),
  'avatar_selected': AnalyticsEventMapping(parameters: ['avatar_id']),
  'title_unlocked': AnalyticsEventMapping(
    parameters: ['title_id', 'rarity', 'source'],
  ),
  'title_equipped': AnalyticsEventMapping(parameters: ['title_id', 'rarity']),

  // --- Seasons ---
  'season_started': AnalyticsEventMapping(parameters: ['season_id']),
  'season_ended': AnalyticsEventMapping(parameters: ['season_id']),
  'season_reward_granted': AnalyticsEventMapping(
    parameters: ['season_id', 'rank', 'reward'],
  ),
  'season_rank_achieved': AnalyticsEventMapping(
    parameters: ['season_id', 'rank', 'total_xp'],
  ),
  'season_viewed': AnalyticsEventMapping(
    parameters: ['season_id', 'days_remaining'],
  ),

  // --- Leaderboards ---
  'leaderboards_updated': AnalyticsEventMapping(
    parameters: ['xp_gained', 'wins_gained', 'votes_gained'],
  ),
  'leaderboard_viewed': AnalyticsEventMapping(
    parameters: ['type', 'entries_count'],
  ),
  'leaderboard_rank_achieved': AnalyticsEventMapping(
    parameters: ['type', 'rank', 'stat_value'],
  ),

  // --- Monetization ---
  'paywall_shown': AnalyticsEventMapping(
    parameters: ['games_played_today', 'trigger_reason'],
  ),
  'rewarded_ad_started': AnalyticsEventMapping(
    parameters: ['ad_network', 'games_played_today'],
  ),
  'rewarded_ad_completed': AnalyticsEventMapping(
    // The SDK reports failure through the same callback path, so this event
    // carries both outcomes rather than being duplicated.
    failureName: 'rewarded_ad_failed',
    parameters: ['ad_network', 'reward_amount', 'failure_reason'],
  ),
  'purchase_started': AnalyticsEventMapping(
    parameters: ['product_id', 'price_micros', 'currency'],
  ),
  'purchase_completed': AnalyticsEventMapping(
    failureName: 'purchase_failed',
    parameters: [
      'product_id',
      'purchase_value_micros',
      'currency',
      'failure_reason',
    ],
  ),
  'purchase_restored': AnalyticsEventMapping(parameters: ['product_id']),
  'purchase_cancelled': AnalyticsEventMapping(parameters: ['product_id']),

  // --- Retention ---
  'returned_same_day': AnalyticsEventMapping(
    parameters: ['hours_since_last_session'],
  ),
  'returned_next_day': AnalyticsEventMapping(
    parameters: ['hours_since_last_session'],
  ),
  'returned_after_week': AnalyticsEventMapping(
    parameters: ['days_since_last_session'],
  ),
};

/// Session Context keys forwarded as analytics parameters on every event.
///
/// A short, fixed list rather than "whatever is in context": Firebase caps
/// parameters per event, and most context exists for debugging, not for
/// segmentation. Everything omitted here is either collected by Firebase
/// itself (locale, OS version, session), identifies the user rather than
/// describing the event (`player_id` is sent once via `setUserId`), or is
/// personal (`player_name`, per docs/engineering/ANALYTICS.md).
const List<String> analyticsContextKeys = [
  TelemetryKeys.playerCount,
  TelemetryKeys.round,
  TelemetryKeys.platform,
  TelemetryKeys.appVersion,
  TelemetryKeys.buildNumber,
  // Set only for the moment `session_ended` is emitted, so in practice it
  // appears on that event alone.
  TelemetryKeys.sessionDurationSeconds,
];

/// Context key whose value is hashed rather than sent verbatim, because
/// Firebase is an external service and a room code is a shared secret that
/// lets anyone join a private game.
const String analyticsHashedRoomKey = TelemetryKeys.roomCode;
