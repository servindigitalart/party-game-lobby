// core/logging/app_log_entry.dart

import 'log_category.dart';
import 'log_level.dart';

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
}
