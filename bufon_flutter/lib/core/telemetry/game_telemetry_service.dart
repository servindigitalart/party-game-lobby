// core/telemetry/game_telemetry_service.dart

import 'dart:io';
import 'dart:math';

import '../logging/app_logger.dart';
import '../logging/log_category.dart';
import '../logging/log_level.dart';
import 'telemetry_context.dart';
import 'telemetry_event.dart';
import 'telemetry_operation.dart';

/// Single source of truth for gameplay telemetry.
///
/// This is not a logger, not an analytics wrapper and not a crash reporter.
/// It is the one place a meaningful gameplay action is described, exactly
/// once, as a [TelemetryEvent]. Every observability system downstream
/// consumes that same event
/// (docs/telemetry/TELEMETRY_SPEC.md — "One event. Multiple destinations").
///
/// ## Where events go
///
/// ```
/// Gameplay → GameTelemetryService → TelemetryEvent → AppLogger
///                                                      → AppLogDestination(s)
///                                                          → Talker (today)
///                                                          → CrashReporter (future)
///                                                          → Firebase Analytics (future)
///                                                          → Debug Overlay (future)
///                                                          → BigQuery (future)
/// ```
///
/// Fan-out deliberately reuses [AppLogger]'s existing destination
/// mechanism instead of introducing a second dispatcher: a parallel
/// TelemetryDispatcher would duplicate a responsibility the logging layer
/// already owns, and would force every future consumer to subscribe twice.
/// A new destination therefore only implements `AppLogDestination` and
/// checks `entry.telemetryEvent` — no change to the API below is ever
/// required.
///
/// ## Session Context
///
/// The service owns the contextual information described in
/// docs/engineering/LOGGING.md and docs/telemetry/TELEMETRY_SPEC.md, and
/// registers itself as [AppLogger]'s context provider at [init]. From that
/// moment every telemetry event *and* every plain log entry automatically
/// carries session, room and device context. Call sites must never repeat
/// it in a payload.
class GameTelemetryService {
  GameTelemetryService._internal();

  static final GameTelemetryService instance =
      GameTelemetryService._internal();

  /// Device-level keys that outlive an individual play session.
  static const List<String> _deviceKeys = [
    TelemetryKeys.platform,
    TelemetryKeys.osVersion,
    TelemetryKeys.locale,
    TelemetryKeys.appVersion,
    TelemetryKeys.buildNumber,
  ];

  final Random _random = Random();

  TelemetryContext _context = const TelemetryContext.empty();
  bool _isInitialized = false;

  /// Current Session Context snapshot. Read-only; mutate via
  /// [updateContext].
  TelemetryContext get context => _context;

  /// Resolves device context and wires Session Context into [AppLogger].
  ///
  /// Must be called after `AppLogger.instance.init()` and before the first
  /// gameplay action. Safe to call more than once.
  void init() {
    if (_isInitialized) return;
    _isInitialized = true;

    _context = _context.merge(_resolveDeviceContext());
    AppLogger.instance.attachContextProvider(() => _context.toMap());
  }

  // ---------------------------------------------------------------------
  // Session
  // ---------------------------------------------------------------------

  /// Opens a new telemetry session, emits `session_started` and returns the
  /// generated session id. Every subsequent event inherits it.
  String startSession() {
    final sessionId = _newId();
    _context = _context.merge({TelemetryKeys.sessionId: sessionId});
    track(AppLogCategory.app, 'session_started');
    return sessionId;
  }

  /// Emits `session_ended` and drops all session-scoped context, keeping
  /// device context so a following session starts from a valid baseline.
  void endSession() {
    if (_context[TelemetryKeys.sessionId] == null) return;
    track(AppLogCategory.app, 'session_ended');
    _context = _context.retaining(_deviceKeys);
  }

  // ---------------------------------------------------------------------
  // Context
  // ---------------------------------------------------------------------

  /// Merges [values] into Session Context. A `null` value clears its key.
  ///
  /// Use [TelemetryKeys] constants. Adding a new contextual field is a new
  /// constant, never a new method here — which is what keeps this API
  /// stable as the spec's context list grows.
  void updateContext(Map<String, dynamic> values) {
    _context = _context.merge(values);
  }

  /// Removes [keys] from Session Context (e.g. on leaving a room).
  void clearContext(Iterable<String> keys) {
    _context = _context.without(keys);
  }

  // ---------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------

  /// Records one meaningful action.
  ///
  /// [name] is snake_case and never abbreviated (`room_created`,
  /// `vote_submitted`). [payload] carries feature-specific data only —
  /// anything shared already travels in Session Context.
  void track(
    AppLogCategory category,
    String name, {
    Map<String, dynamic>? payload,
    TelemetryStatus status = TelemetryStatus.succeeded,
    AppLogLevel severity = AppLogLevel.info,
    Duration? duration,
    String? correlationId,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _emit(
      TelemetryEvent(
        id: _newId(),
        name: name,
        category: category,
        severity: severity,
        status: status,
        timestamp: DateTime.now(),
        context: _context,
        payload: payload ?? const {},
        correlationId: correlationId,
        duration: duration,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  /// Begins an operation whose duration matters, emits its `started` event
  /// and returns a handle to close it with `finish` / `fail` / `cancel`.
  ///
  /// ```dart
  /// final op = telemetry.start(AppLogCategory.room, 'room_created');
  /// try {
  ///   final room = await repository.createRoom(...);
  ///   op.finish(payload: {'attempts': attempts});
  /// } catch (e, s) {
  ///   op.fail(e, stackTrace: s);
  ///   rethrow;
  /// }
  /// ```
  TelemetryOperation start(
    AppLogCategory category,
    String name, {
    Map<String, dynamic>? payload,
    String? correlationId,
  }) {
    final id = correlationId ?? _newId();

    track(
      category,
      name,
      status: TelemetryStatus.started,
      payload: payload,
      correlationId: id,
    );

    return TelemetryOperation(
      telemetry: this,
      category: category,
      name: name,
      correlationId: id,
    );
  }

  /// Records a failure that had no matching [start] — an error surfacing
  /// from a listener, a callback or a guard clause.
  void fail(
    AppLogCategory category,
    String name, {
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? payload,
    AppLogLevel severity = AppLogLevel.error,
    TelemetryStatus status = TelemetryStatus.failed,
    String? correlationId,
  }) {
    track(
      category,
      name,
      status: status,
      severity: severity,
      payload: payload,
      correlationId: correlationId,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Records a screen change and updates the current screen in Session
  /// Context, so every later event knows where the player was
  /// (docs/engineering/LOGGING.md — "Navigation Logging").
  ///
  /// [from] defaults to the screen currently held in context.
  void transition(String to, {String? from}) {
    final previous = from ?? _context[TelemetryKeys.screen] as String?;
    _context = _context.merge({TelemetryKeys.screen: to});

    track(
      AppLogCategory.navigation,
      'screen_changed',
      payload: {
        if (previous != null) TelemetryKeys.fromScreen: previous,
        TelemetryKeys.toScreen: to,
      },
    );
  }

  // ---------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------

  /// Hands the event to [AppLogger], which merges Session Context and fans
  /// it out to every registered destination.
  ///
  /// The typed event rides along under [TelemetryEvent.entryKey] so smart
  /// destinations get the object, while the flattened envelope keeps dumb
  /// destinations (and the console) useful.
  void _emit(TelemetryEvent event) {
    final entryContext = <String, dynamic>{
      ...event.toFlatMap(),
      TelemetryEvent.entryKey: event,
    };

    AppLogger.instance.log(
      event.severity,
      event.category,
      event.name,
      context: entryContext,
      error: event.error,
      stackTrace: event.stackTrace,
    );
  }

  Map<String, dynamic> _resolveDeviceContext() {
    // App version and build number need a build-metadata source the project
    // does not depend on yet; their keys already exist and any future phase
    // fills them through updateContext without touching this class.
    try {
      return {
        TelemetryKeys.platform: Platform.operatingSystem,
        TelemetryKeys.osVersion: Platform.operatingSystemVersion,
        TelemetryKeys.locale: Platform.localeName,
      };
    } catch (_) {
      // Telemetry is passive: an unreadable platform must never stop the
      // app from starting.
      return const {};
    }
  }

  String _newId() {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final salt = _random.nextInt(0xFFFFFF).toRadixString(36);
    return '$time-$salt';
  }
}
