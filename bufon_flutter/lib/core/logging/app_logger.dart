// core/logging/app_logger.dart

import 'package:flutter/foundation.dart';

import 'app_log_destination.dart';
import 'app_log_entry.dart';
import 'log_category.dart';
import 'log_level.dart';
import 'talker_log_destination.dart';

/// Structured logging facade for Bufón.
///
/// [AppLogger] is the only part of the application allowed to know how logs
/// are actually delivered. Every other layer (screens, controllers,
/// repositories, services) must log exclusively through the level methods
/// below, per docs/engineering/CODING_STANDARD.md ("Always use AppLogger").
///
/// Internally, every log call becomes an [AppLogEntry] and is fanned out to
/// a list of [AppLogDestination]s. Talker is registered as the default
/// destination so console/history logging works out of the box. Future
/// systems (CrashReporter, AnalyticsService, GameTelemetryService, the
/// Debug Overlay, a future BigQuery exporter, ...) plug in by implementing
/// [AppLogDestination] and calling [registerDestination] — the level
/// methods (`trace`/`debug`/`info`/`warning`/`error`/`critical`/`fatal`)
/// never need to change to support a new destination.
class AppLogger {
  AppLogger._internal() {
    _destinations.add(TalkerLogDestination());
  }

  static final AppLogger instance = AppLogger._internal();

  final List<AppLogDestination> _destinations = [];
  bool _isInitialized = false;

  /// Supplies context (e.g. session id, room code, player id) that should be
  /// automatically attached to every subsequent log entry.
  ///
  /// This is the extension point GameTelemetryService will use later to
  /// inject Session Context (docs/engineering/LOGGING.md) without AppLogger
  /// needing to know anything about sessions, rooms or players.
  Map<String, dynamic> Function()? _contextProvider;

  /// Initializes the logging system. Must be called once during app
  /// startup, before other services that may want to log.
  ///
  /// Safe to call more than once; only the first call has an effect.
  void init() {
    if (_isInitialized) return;
    _isInitialized = true;
    info(AppLogCategory.system, 'AppLogger initialized');
  }

  /// Registers an additional destination that will receive every future
  /// log entry (e.g. CrashReporter, AnalyticsService, GameTelemetryService,
  /// the Debug Overlay, a BigQuery exporter).
  ///
  /// The rest of the application never needs to know a destination exists —
  /// only whichever service owns it calls this at its own init time.
  void registerDestination(AppLogDestination destination) {
    _destinations.add(destination);
  }

  /// Removes a previously registered destination, if present.
  void unregisterDestination(AppLogDestination destination) {
    _destinations.remove(destination);
  }

  /// Registers a callback invoked on every log call to obtain context that
  /// should be merged into that entry (e.g. current session/room/player).
  ///
  /// Explicit `context` passed to a log call takes precedence over keys
  /// provided here.
  void attachContextProvider(Map<String, dynamic> Function() provider) {
    _contextProvider = provider;
  }

  /// Removes a previously attached context provider, if any.
  void detachContextProvider() {
    _contextProvider = null;
  }

  /// Very detailed information. Development only; dropped in release
  /// builds.
  void trace(
    AppLogCategory category,
    String message, {
    Map<String, dynamic>? context,
  }) {
    _log(AppLogLevel.trace, category, message, context: context);
  }

  /// Useful information for developers. Development only; dropped in
  /// release builds.
  void debug(
    AppLogCategory category,
    String message, {
    Map<String, dynamic>? context,
  }) {
    _log(AppLogLevel.debug, category, message, context: context);
  }

  /// Normal application events (e.g. room created, player joined, vote
  /// submitted).
  void info(
    AppLogCategory category,
    String message, {
    Map<String, dynamic>? context,
  }) {
    _log(AppLogLevel.info, category, message, context: context);
  }

  /// Unexpected but recoverable situations (e.g. reconnect, retry, slow
  /// network).
  void warning(
    AppLogCategory category,
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      AppLogLevel.warning,
      category,
      message,
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// An operation failed but the application continues running.
  void error(
    AppLogCategory category,
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      AppLogLevel.error,
      category,
      message,
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// A severe failure that puts the application in a degraded state but
  /// does not require termination.
  void critical(
    AppLogCategory category,
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      AppLogLevel.critical,
      category,
      message,
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// The application cannot continue safely. A crash is expected to follow.
  void fatal(
    AppLogCategory category,
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      AppLogLevel.fatal,
      category,
      message,
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _log(
    AppLogLevel level,
    AppLogCategory category,
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // TRACE/DEBUG are development-only per docs/engineering/LOGGING.md.
    if (kReleaseMode &&
        (level == AppLogLevel.trace || level == AppLogLevel.debug)) {
      return;
    }

    final mergedContext = <String, dynamic>{
      ...?_contextProvider?.call(),
      ...?context,
    };

    final entry = AppLogEntry(
      level: level,
      category: category,
      message: message,
      context: mergedContext,
      timestamp: DateTime.now(),
      error: error,
      stackTrace: stackTrace,
    );

    for (final destination in _destinations) {
      try {
        destination.onLog(entry);
      } catch (_) {
        // A destination must never take down logging or the app itself
        // (docs/telemetry/TELEMETRY_SPEC.md: "Telemetry is passive").
      }
    }
  }
}
