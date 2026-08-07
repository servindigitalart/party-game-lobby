// core/logging/app_log_destination.dart

import 'app_log_entry.dart';

/// A sink that receives every log entry [AppLogger] produces.
///
/// Future systems (CrashReporter, AnalyticsService, GameTelemetryService,
/// the Debug Overlay, a BigQuery exporter, ...) plug in by implementing
/// this interface and calling `AppLogger.instance.registerDestination`.
/// AppLogger's public logging API never has to change to support a new
/// destination — only a new class implementing this interface is needed.
abstract class AppLogDestination {
  void onLog(AppLogEntry entry);
}
