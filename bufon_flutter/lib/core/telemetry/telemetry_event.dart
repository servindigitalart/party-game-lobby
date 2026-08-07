// core/telemetry/telemetry_event.dart

import 'package:flutter/foundation.dart';

import '../logging/app_log_entry.dart';
import '../logging/log_category.dart';
import '../logging/log_level.dart';
import 'telemetry_context.dart';

/// Outcome of the action an event describes
/// (docs/telemetry/TELEMETRY_SPEC.md — "Status").
enum TelemetryStatus {
  started,
  succeeded,
  failed,
  cancelled,
  retried,
  timeout,
  recovered,
  ignored,
}

/// A single, canonical record of something meaningful that happened.
///
/// One gameplay action produces exactly one [TelemetryEvent]
/// (docs/telemetry/TELEMETRY_SPEC.md — "Golden Rule"). Every observability
/// system — the console today, CrashReporter / Firebase Analytics / a debug
/// overlay / BigQuery tomorrow — consumes this same object rather than
/// emitting its own.
///
/// Category and severity intentionally reuse [AppLogCategory] and
/// [AppLogLevel] instead of declaring parallel telemetry-only enums: the
/// project must not carry two taxonomies for the same concept
/// (AGENTS.md — "Never introduce a second implementation of an existing
/// feature").
@immutable
class TelemetryEvent {
  const TelemetryEvent({
    required this.id,
    required this.name,
    required this.category,
    required this.severity,
    required this.status,
    required this.timestamp,
    required this.context,
    this.payload = const {},
    this.correlationId,
    this.duration,
    this.error,
    this.stackTrace,
  });

  /// Key under which the whole event travels inside
  /// [AppLogEntry.context], so destinations that want the typed object can
  /// recover it via [TelemetryLogEntry.telemetryEvent] while destinations
  /// that only understand flat maps keep working.
  ///
  /// The leading underscore marks it as non-printable for formatters.
  static const String entryKey = '_telemetry';

  final String id;

  /// snake_case action name, e.g. `room_created` (never abbreviated).
  final String name;
  final AppLogCategory category;
  final AppLogLevel severity;
  final TelemetryStatus status;
  final DateTime timestamp;

  /// Session Context snapshot at emission time.
  final TelemetryContext context;

  /// Feature-specific data only. Anything shared belongs in [context]
  /// (docs/telemetry/TELEMETRY_SPEC.md — "Payload Rules").
  final Map<String, dynamic> payload;

  /// Shared by every event belonging to the same logical operation, so a
  /// flow can be reconstructed end to end.
  final String? correlationId;
  final Duration? duration;
  final Object? error;
  final StackTrace? stackTrace;

  /// Flat, primitive-only view of the event envelope and payload.
  ///
  /// Session Context is deliberately absent: [AppLogger] merges it into
  /// every entry through its context provider, so including it here would
  /// duplicate it.
  Map<String, dynamic> toFlatMap() => <String, dynamic>{
    TelemetryKeys.event: name,
    TelemetryKeys.eventId: id,
    TelemetryKeys.status: status.name,
    if (duration != null) TelemetryKeys.durationMs: duration!.inMilliseconds,
    if (correlationId != null) TelemetryKeys.correlationId: correlationId,
    ...payload,
  };

  @override
  String toString() => 'TelemetryEvent($name, ${status.name})';
}

/// Typed access to the telemetry event that produced a log entry.
///
/// Lives in the telemetry layer so `core/logging` never has to know
/// telemetry exists. A future CrashReporter / AnalyticsService / debug
/// overlay implements `AppLogDestination` and switches on this getter:
/// non-null means "this entry is a telemetry event", null means "plain log".
extension TelemetryLogEntry on AppLogEntry {
  TelemetryEvent? get telemetryEvent {
    final value = context[TelemetryEvent.entryKey];
    return value is TelemetryEvent ? value : null;
  }
}
