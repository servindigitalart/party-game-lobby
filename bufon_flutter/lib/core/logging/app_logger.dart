// core/logging/app_logger.dart

import 'package:flutter/foundation.dart';

import 'app_log_destination.dart';
import 'app_log_entry.dart';
import 'log_category.dart';
import 'log_level.dart';
import 'talker_log_destination.dart';

/// Supplies a slice of context to be merged into every log entry.
///
/// Each contributor (GameTelemetryService's Session Context, a future
/// Authentication, DeviceInfo or Performance provider) owns one of these and
/// knows nothing about the others.
typedef AppLogContextProvider = Map<String, dynamic> Function();

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

  /// Callbacks supplying context (e.g. session id, room code, player id)
  /// automatically attached to every subsequent log entry.
  ///
  /// This is the extension point services use to contribute context without
  /// AppLogger knowing anything about sessions, rooms, players or devices:
  /// GameTelemetryService owns Session Context, and a future
  /// Authentication / DeviceInfo / Performance provider contributes its own
  /// slice alongside it.
  final List<AppLogContextProvider> _contextProviders = [];

  bool _isInitialized = false;

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
  /// Any number of providers may be attached; each contributes an
  /// independent slice of context and none needs to know the others exist.
  /// They are merged in registration order, so a later provider overrides
  /// an earlier one on a shared key, and explicit `context` passed to a log
  /// call overrides all of them.
  ///
  /// A provider that throws is skipped for that entry — logging must never
  /// fail because a contributor is unavailable
  /// (docs/telemetry/TELEMETRY_SPEC.md: "Telemetry is passive").
  void attachContextProvider(AppLogContextProvider provider) {
    _contextProviders.add(provider);
  }

  /// Removes [provider] if it was attached; removes every provider when
  /// called without an argument.
  void detachContextProvider([AppLogContextProvider? provider]) {
    if (provider == null) {
      _contextProviders.clear();
    } else {
      _contextProviders.remove(provider);
    }
  }

  /// Snapshot of every attached provider's context, merged in registration
  /// order — the same map that would be attached to a log entry right now.
  ///
  /// This is how CrashReporter enriches a report without knowing that
  /// GameTelemetryService (or a future Authentication or DeviceInfo
  /// provider) exists.
  Map<String, dynamic> get currentContext => _collectContext();

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

  /// Logs at a level chosen at runtime.
  ///
  /// The named level methods above are the ergonomic API for call sites
  /// that know their level statically. This one exists for the systems that
  /// carry a level as data — GameTelemetryService dispatching a
  /// [AppLogEntry]'s severity, CrashReporter mirroring a report — so they
  /// do not each reimplement a switch over all seven levels.
  void log(
    AppLogLevel level,
    AppLogCategory category,
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      level,
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
      ..._collectContext(),
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

  /// Merges every attached provider's context in registration order.
  ///
  /// A provider that throws contributes nothing rather than failing the log
  /// call, so one broken contributor cannot blind the others.
  Map<String, dynamic> _collectContext() {
    if (_contextProviders.isEmpty) return const {};

    final merged = <String, dynamic>{};
    for (final provider in _contextProviders) {
      try {
        merged.addAll(provider());
      } catch (_) {
        // Intentionally skipped; see doc comment above.
      }
    }
    return merged;
  }
}
