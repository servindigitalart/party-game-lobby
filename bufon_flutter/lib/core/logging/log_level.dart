// core/logging/log_level.dart

/// Severity levels supported by [AppLogger].
///
/// Ordered from least to most severe. TRACE and DEBUG are considered
/// development-only per docs/engineering/LOGGING.md and are dropped in
/// release builds by [AppLogger].
enum AppLogLevel {
  trace,
  debug,
  info,
  warning,
  error,
  critical,
  fatal,
}
