// core/crash/crash_log_destination.dart

import '../logging/app_log_destination.dart';
import '../logging/app_log_entry.dart';
import '../logging/log_category.dart';
import '../logging/log_level.dart';
import '../telemetry/telemetry_context.dart';
import '../telemetry/telemetry_event.dart';
import 'crash_reporter.dart';

/// Bridges [AppLogger] into [CrashReporter].
///
/// This is where breadcrumbs come from. Every telemetry event already
/// travels through AppLogger, so the breadcrumb trail the specification
/// asks for — room created, room joined, match started, vote submitted,
/// navigation, disconnect, reconnect — is produced by instrumentation that
/// already exists. No feature is instrumented twice
/// (docs/telemetry/TELEMETRY_SPEC.md — "Never emit the same event twice").
///
/// ## What is forwarded
///
/// | Entry                        | Breadcrumb | Report          |
/// |------------------------------|------------|-----------------|
/// | Telemetry event, any level   | yes        | if level ≥ error|
/// | Plain log, trace/debug/info  | no         | no              |
/// | Plain log, warning           | yes        | no              |
/// | Plain log, error/critical    | yes        | non-fatal       |
/// | Plain log, fatal             | yes        | fatal           |
///
/// TRACE, DEBUG and INFO are deliberately excluded unless they carry a
/// telemetry event: they are development noise, and Crashlytics' breadcrumb
/// buffer is small enough that filling it with them would push out the
/// events that actually explain a crash.
class CrashLogDestination implements AppLogDestination {
  CrashLogDestination(this._reporter);

  final CrashReporter _reporter;

  @override
  void onLog(AppLogEntry entry) {
    // Entries CrashReporter produced itself are already reported; without
    // this the mirror log would report the same failure twice.
    if (entry.context[CrashReporter.originKey] == true) return;

    final event = entry.telemetryEvent;
    final isReportable = entry.level.index >= AppLogLevel.error.index;

    if (event != null) {
      _reporter.log(_describeEvent(event));
    } else if (entry.level.index >= AppLogLevel.warning.index) {
      _reporter.log('[${entry.category.label}] ${entry.message}');
    }

    if (isReportable) {
      _reporter.reportFromLog(entry);
    }
  }

  /// Compact one-line breadcrumb. Session context is omitted because it is
  /// already attached to the report as custom keys — repeating it on every
  /// breadcrumb would waste the buffer.
  String _describeEvent(TelemetryEvent event) {
    final buffer = StringBuffer(event.name)
      ..write(' status=')
      ..write(event.status.name);

    final duration = event.duration;
    if (duration != null) {
      buffer
        ..write(' ${TelemetryKeys.durationMs}=')
        ..write(duration.inMilliseconds);
    }

    for (final entry in event.payload.entries) {
      buffer.write(' ${entry.key}=${entry.value}');
    }

    return buffer.toString();
  }
}
