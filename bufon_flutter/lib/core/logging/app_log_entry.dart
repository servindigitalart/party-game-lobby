// core/logging/app_log_entry.dart

import 'log_category.dart';
import 'log_level.dart';

/// Whether [key] is an internal context key.
///
/// Keys prefixed with `_` carry structured objects or routing markers meant
/// for a specific destination — the typed `TelemetryEvent`, CrashReporter's
/// origin marker — rather than data to display or export. Destinations that
/// render or forward context must skip them.
///
/// Defined here so the convention has exactly one owner; previously the
/// console formatter and the crash reporter each spelled it out.
bool isInternalContextKey(String key) => key.startsWith('_');

/// A single structured log record.
///
/// This is the payload every [AppLogDestination] receives from [AppLogger].
/// It carries raw, unformatted data so each destination (console, a future
/// CrashReporter, AnalyticsService, GameTelemetryService, Debug Overlay, a
/// BigQuery exporter, ...) can render or forward it however it needs to,
/// without AppLogger dictating a single text format.
class AppLogEntry {
  const AppLogEntry({
    required this.level,
    required this.category,
    required this.message,
    required this.context,
    required this.timestamp,
    this.error,
    this.stackTrace,
  });

  final AppLogLevel level;
  final AppLogCategory category;
  final String message;

  /// Merged context: whatever was attached via a context provider plus
  /// whatever was passed explicitly to the log call.
  final Map<String, dynamic> context;
  final DateTime timestamp;
  final Object? error;
  final StackTrace? stackTrace;

  /// [context] without internal keys — what a destination should render,
  /// export or turn into custom keys.
  Map<String, dynamic> get publicContext => {
    for (final entry in context.entries)
      if (!isInternalContextKey(entry.key)) entry.key: entry.value,
  };
}
