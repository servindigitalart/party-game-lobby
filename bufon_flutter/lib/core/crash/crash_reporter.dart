// core/crash/crash_reporter.dart

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../logging/app_log_entry.dart';
import '../logging/app_logger.dart';
import '../logging/log_category.dart';
import '../logging/log_level.dart';
import 'crash_backend.dart';
import 'crash_log_destination.dart';

/// Logical grouping for manually set custom keys
/// (docs/engineering/CRASHLYTICS.md — "Custom Keys").
///
/// Forcing every ad-hoc key through a domain is what stops the key list
/// from sprawling into hundreds of unrelated names. The resulting key is
/// `domain_name`, matching the naming the automatic keys already use
/// (`session_id`, `room_code`, `player_id`, ...).
enum CrashKeyDomain {
  session,
  room,
  player,
  game,
  device,
  network,
  build,
  firebase,
  ui,
}

/// Single entry point for every error in the application.
///
/// Nothing outside `lib/core/crash/` may import `firebase_crashlytics`.
/// CrashReporter knows only [CrashBackend], so the crash provider can be
/// replaced without touching a single call site
/// (docs/engineering/CRASHLYTICS.md — "Only CrashReporter owns
/// Crashlytics").
///
/// ## Flow
///
/// ```
/// FlutterError.onError ─┐
/// PlatformDispatcher ───┤
/// runZonedGuarded ──────┼──→ CrashReporter ──→ CrashBackend
/// AppLogger (error+) ───┤                       └─ FirebaseCrashlyticsBackend
/// explicit recordX() ───┘                          (Sentry / Bugsnag / …)
/// ```
///
/// ## Context
///
/// Reports are enriched automatically from [AppLogger.currentContext] — the
/// merged output of every attached context provider, which today means
/// GameTelemetryService's Session Context and device information, and
/// tomorrow whatever Authentication or Performance contributes. Gameplay
/// code never passes these values by hand.
///
/// ## Ordering
///
/// [initialize] installs the global handlers and starts buffering, so
/// failures during Firebase startup are still captured. [attachBackend]
/// then flushes everything collected so far.
class CrashReporter {
  CrashReporter._internal();

  static final CrashReporter instance = CrashReporter._internal();

  /// Context key marking a log entry that CrashReporter itself produced, so
  /// [CrashLogDestination] does not report it a second time. The leading
  /// underscore keeps it out of console formatting.
  static const String originKey = '_crash_origin';

  /// Cap on reports and breadcrumbs held before a backend is attached.
  /// Startup is short; an unbounded buffer would be a leak, not a feature.
  static const int _maxPendingActions = 100;

  CrashBackend? _backend;
  final List<void Function(CrashBackend)> _pending = [];

  /// Custom keys already pushed to the backend, so each sync sends only
  /// what actually changed.
  final Map<String, Object> _pushedKeys = {};

  CrashLogDestination? _destination;
  bool _isInitialized = false;

  // ---------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------

  /// Installs the global Flutter and platform error handlers and starts
  /// listening to [AppLogger].
  ///
  /// Call as early as possible in `main`, before Firebase — errors raised
  /// while the backend is still unavailable are buffered, not lost.
  /// Safe to call more than once.
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    FlutterError.onError = recordFlutterError;

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      recordFatal(
        error,
        stackTrace: stackTrace,
        reason: 'Uncaught platform error',
      );
      return true;
    };

    _destination = CrashLogDestination(this);
    AppLogger.instance.registerDestination(_destination!);
  }

  /// Runs [body] inside a guarded zone so unhandled asynchronous errors
  /// become fatal reports (docs/engineering/CRASHLYTICS.md — "Flutter
  /// Errors").
  ///
  /// `WidgetsFlutterBinding.ensureInitialized()` must be called *inside*
  /// [body] so the binding and the zone match.
  void guard(FutureOr<void> Function() body) {
    runZonedGuarded(body, (error, stackTrace) {
      recordFatal(
        error,
        stackTrace: stackTrace,
        reason: 'Uncaught asynchronous error',
      );
    });
  }

  /// Attaches the crash backend and flushes everything buffered so far.
  Future<void> attachBackend(CrashBackend backend) async {
    try {
      await backend.initialize();
    } catch (e, stackTrace) {
      // A backend that cannot start must not stop the app from starting.
      AppLogger.instance.error(
        AppLogCategory.crashlytics,
        'Crash backend failed to initialize',
        error: e,
        stackTrace: stackTrace,
        context: const {originKey: true},
      );
      return;
    }

    _backend = backend;

    final buffered = List<void Function(CrashBackend)>.from(_pending);
    _pending.clear();
    for (final action in buffered) {
      _run(action);
    }

    AppLogger.instance.info(
      AppLogCategory.crashlytics,
      'Crash backend attached',
      context: {originKey: true, 'buffered_actions': buffered.length},
    );
  }

  /// Detaches the backend and stops listening to [AppLogger]. Intended for
  /// tests and for shutting reporting down cleanly.
  void dispose() {
    if (_destination != null) {
      AppLogger.instance.unregisterDestination(_destination!);
      _destination = null;
    }
    _backend = null;
    _pending.clear();
    _pushedKeys.clear();
    _isInitialized = false;
  }

  // ---------------------------------------------------------------------
  // Recording
  // ---------------------------------------------------------------------

  /// Records an error. The default is non-fatal: the application kept
  /// running.
  void recordError(
    Object error, {
    StackTrace? stackTrace,
    AppLogCategory category = AppLogCategory.system,
    AppLogLevel severity = AppLogLevel.error,
    String? reason,
    bool fatal = false,
  }) {
    _record(
      CrashReport(
        error: error,
        stackTrace: stackTrace,
        category: category,
        // `fatal: true` promotes the severity, so fatality has exactly one
        // representation and cannot contradict the label.
        severity: fatal ? AppLogLevel.fatal : severity,
        reason: reason,
        timestamp: DateTime.now(),
      ),
      logIt: true,
    );
  }

  /// The application cannot continue. Used by the zone and platform
  /// handlers.
  void recordFatal(
    Object error, {
    StackTrace? stackTrace,
    AppLogCategory category = AppLogCategory.system,
    String? reason,
  }) {
    recordError(
      error,
      stackTrace: stackTrace,
      category: category,
      severity: AppLogLevel.fatal,
      reason: reason,
      fatal: true,
    );
  }

  /// A recoverable failure that still represents a bug — a failed Firestore
  /// transaction, a closed snapshot, a room inconsistency.
  void recordNonFatal(
    Object error, {
    StackTrace? stackTrace,
    AppLogCategory category = AppLogCategory.system,
    AppLogLevel severity = AppLogLevel.error,
    String? reason,
  }) {
    recordError(
      error,
      stackTrace: stackTrace,
      category: category,
      severity: severity,
      reason: reason,
    );
  }

  /// Logic reached a state that should be impossible
  /// (docs/engineering/CRASHLYTICS.md — error type "Unexpected").
  ///
  /// Recorded as non-fatal so the player is not interrupted, but at
  /// [AppLogLevel.critical] so it is never sampled away.
  void recordAssertion(
    String message, {
    AppLogCategory category = AppLogCategory.system,
    String? reason,
    StackTrace? stackTrace,
  }) {
    recordError(
      AssertionError(message),
      stackTrace: stackTrace ?? StackTrace.current,
      category: category,
      severity: AppLogLevel.critical,
      reason: reason ?? 'Unexpected state',
    );
  }

  /// Handler installed on `FlutterError.onError`.
  ///
  /// Framework errors are recorded as non-fatal. The previous
  /// implementation used `recordFlutterFatalError`, which marked every
  /// layout overflow as a crash and distorted the crash-free-sessions
  /// metric; only the zone and platform handlers produce fatals now.
  void recordFlutterError(FlutterErrorDetails details) {
    // Keep the framework's own console output in debug builds.
    FlutterError.presentError(details);

    recordError(
      details.exception,
      stackTrace: details.stack,
      category: AppLogCategory.ui,
      severity: AppLogLevel.error,
      reason: details.context?.toString() ?? details.library,
    );
  }

  /// Records an entry that already travelled through [AppLogger].
  ///
  /// Called only by [CrashLogDestination]. It does not log again, which is
  /// what keeps one failure to exactly one console line and one report.
  void reportFromLog(AppLogEntry entry) {
    _record(
      CrashReport(
        error: entry.error ?? entry.message,
        stackTrace: entry.stackTrace,
        category: entry.category,
        severity: entry.level,
        reason: entry.error == null ? null : entry.message,
        timestamp: entry.timestamp,
      ),
      logIt: false,
    );
  }

  // ---------------------------------------------------------------------
  // Context
  // ---------------------------------------------------------------------

  /// Leaves a breadcrumb. Prefer letting telemetry events produce these —
  /// see [CrashLogDestination].
  void log(String message) {
    _syncCustomKeys();
    _dispatch((backend) => backend.leaveBreadcrumb(message));
  }

  void setUser(String identifier) {
    _dispatch((backend) => backend.setUser(identifier));
  }

  void clearUser() {
    _dispatch((backend) => backend.setUser(null));
  }

  /// Sets a key under [domain], producing `domain_name`.
  ///
  /// Session, room, player, game, device and build keys are already
  /// maintained automatically from context providers; this is for the
  /// occasional key a specific feature needs.
  void setCustomKey(CrashKeyDomain domain, String name, Object value) {
    final key = '${domain.name}_$name';
    _pushedKeys[key] = value;
    _dispatch((backend) => backend.setCustomKey(key, value));
  }

  void removeCustomKey(CrashKeyDomain domain, String name) {
    final key = '${domain.name}_$name';
    _pushedKeys.remove(key);
    _dispatch((backend) => backend.removeCustomKey(key));
  }

  // ---------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------

  void _record(CrashReport report, {required bool logIt}) {
    _syncCustomKeys();
    _dispatch((backend) => backend.report(report));

    if (!logIt) return;

    // Mirror into the log stream so the failure is visible in the console
    // and to every other destination. The origin marker stops
    // CrashLogDestination from reporting it a second time.
    AppLogger.instance.log(
      report.severity,
      report.category,
      report.reason ?? 'Unhandled error',
      error: report.error,
      stackTrace: report.stackTrace,
      context: {originKey: true, 'fatal': report.isFatal},
    );
  }

  /// Pushes the difference between [AppLogger.currentContext] and what the
  /// backend already holds.
  ///
  /// Keys are refreshed before every report and breadcrumb, so a native
  /// crash the Dart layer never sees still carries the room, session and
  /// screen the player was in.
  void _syncCustomKeys() {
    final context = AppLogger.instance.currentContext;

    for (final entry in context.entries) {
      if (isInternalContextKey(entry.key)) continue;

      final value = _asCustomKeyValue(entry.value);
      if (value == null || _pushedKeys[entry.key] == value) continue;

      _pushedKeys[entry.key] = value;
      _dispatch((backend) => backend.setCustomKey(entry.key, value));
    }

    final stale = _pushedKeys.keys
        .where((key) => !context.containsKey(key))
        .toList();
    for (final key in stale) {
      _pushedKeys.remove(key);
      _dispatch((backend) => backend.removeCustomKey(key));
    }
  }

  /// Crash backends accept primitives only. Anything else is stringified;
  /// null drops the key rather than writing "null".
  Object? _asCustomKeyValue(Object? value) {
    if (value == null) return null;
    if (value is String || value is int || value is double || value is bool) {
      return value;
    }
    return value.toString();
  }

  void _dispatch(void Function(CrashBackend) action) {
    final backend = _backend;
    if (backend == null) {
      if (_pending.length < _maxPendingActions) _pending.add(action);
      return;
    }
    _run(action);
  }

  void _run(void Function(CrashBackend) action) {
    try {
      action(_backend!);
    } catch (_) {
      // Crash reporting must never crash the application
      // (docs/telemetry/TELEMETRY_SPEC.md — "Failure Strategy").
    }
  }
}
