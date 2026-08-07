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
  'app_started': AnalyticsEventMapping(name: 'app_open'),
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
  'vote_submitted': AnalyticsEventMapping(
    parameters: ['time_to_vote_seconds'],
  ),

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
];

/// Context key whose value is hashed rather than sent verbatim, because
/// Firebase is an external service and a room code is a shared secret that
/// lets anyone join a private game.
const String analyticsHashedRoomKey = TelemetryKeys.roomCode;
