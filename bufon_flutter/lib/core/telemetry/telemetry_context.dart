// core/telemetry/telemetry_context.dart

/// Reserved key names used by the telemetry system.
///
/// Session Context keys and event-envelope keys live here so that adding a
/// new contextual field (docs/telemetry/TELEMETRY_SPEC.md — "Session
/// Context") is a one-line constant addition and never a change to
/// [GameTelemetryService]'s public API.
class TelemetryKeys {
  TelemetryKeys._();

  // --- Session Context ---
  static const String sessionId = 'session_id';
  static const String roomCode = 'room_code';
  static const String hostId = 'host_id';
  static const String playerId = 'player_id';
  static const String playerName = 'player_name';
  static const String playerCount = 'player_count';
  static const String screen = 'screen';
  static const String round = 'round';
  static const String questionId = 'question_id';
  static const String gameState = 'game_state';
  static const String networkStatus = 'network_status';

  // --- Device Context (resolved once at init) ---
  static const String platform = 'platform';
  static const String osVersion = 'os_version';
  static const String locale = 'locale';

  // Populated by whoever owns build metadata; currently unset because the
  // project has no package_info dependency. Reading them is already safe.
  static const String appVersion = 'app_version';
  static const String buildNumber = 'build_number';

  // --- Event envelope ---
  static const String event = 'event';
  static const String eventId = 'event_id';
  static const String status = 'status';
  static const String durationMs = 'duration_ms';
  static const String correlationId = 'correlation_id';
  static const String fromScreen = 'from_screen';
  static const String toScreen = 'to_screen';
}

/// Immutable snapshot of the contextual information attached to every
/// telemetry event and every log entry.
///
/// Deliberately backed by a plain map rather than typed fields: the spec
/// lists a dozen context values today and promises more (battery, memory,
/// network). A map means those arrive without touching any public API.
class TelemetryContext {
  const TelemetryContext(this._values);

  const TelemetryContext.empty() : _values = const {};

  final Map<String, dynamic> _values;

  /// Read-only view, safe to hand to destinations.
  Map<String, dynamic> toMap() => Map<String, dynamic>.unmodifiable(_values);

  dynamic operator [](String key) => _values[key];

  bool get isEmpty => _values.isEmpty;

  /// Returns a copy with [values] applied. A `null` value removes the key,
  /// so callers can clear a field with the same call they set it with.
  TelemetryContext merge(Map<String, dynamic> values) {
    final next = Map<String, dynamic>.from(_values);
    for (final entry in values.entries) {
      if (entry.value == null) {
        next.remove(entry.key);
      } else {
        next[entry.key] = entry.value;
      }
    }
    return TelemetryContext(next);
  }

  /// Returns a copy without [keys].
  TelemetryContext without(Iterable<String> keys) {
    final next = Map<String, dynamic>.from(_values)
      ..removeWhere((key, _) => keys.contains(key));
    return TelemetryContext(next);
  }

  /// Returns a copy keeping only [keys]. Used when a session ends and only
  /// device-level context should survive.
  TelemetryContext retaining(Iterable<String> keys) {
    final next = Map<String, dynamic>.from(_values)
      ..removeWhere((key, _) => !keys.contains(key));
    return TelemetryContext(next);
  }
}
