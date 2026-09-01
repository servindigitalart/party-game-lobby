// analytics/analytics_destination.dart

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../core/logging/app_log_destination.dart';
import '../core/logging/app_log_entry.dart';
import '../core/logging/app_logger.dart';
import '../core/logging/log_category.dart';
import '../core/telemetry/telemetry_context.dart';
import '../core/telemetry/telemetry_event.dart';
import 'analytics_event_mapping.dart';

/// Forwards telemetry events to Firebase Analytics.
///
/// ```
/// Gameplay → GameTelemetryService → AppLogger → AnalyticsDestination
///                                                  → Firebase Analytics
/// ```
///
/// This is the only class in the application allowed to import
/// `firebase_analytics`. Gameplay emits one telemetry event and analytics
/// receives it automatically; no feature knows Firebase Analytics exists
/// (docs/telemetry/TELEMETRY_SPEC.md — "Integration Rules").
///
/// Two things are deliberately *not* forwarded:
///
/// * Anything without a registry entry (see [analyticsEventMappings]).
///   Engineering diagnostics stay in Talker and Crashlytics.
/// * `started` halves of operations, which would double-count every action.
class AnalyticsDestination implements AppLogDestination {
  AnalyticsDestination({FirebaseAnalytics? analytics}) : _analytics = analytics;

  /// Firebase caps parameters per event; the policy here stays well under it,
  /// but the cap is enforced so a future payload cannot silently break
  /// logging for a whole event.
  static const int _maxParameters = 25;

  /// Firebase truncates string parameter values at 100 characters.
  static const int _maxParameterLength = 100;

  /// Firebase's *structural* rule for an event name: begins with a letter,
  /// alphanumeric-or-underscore thereafter, at most 40 characters.
  ///
  /// The SDK's exact-match reserved list is deliberately **not** duplicated
  /// here. It is a private `const` inside `firebase_analytics` that would
  /// silently drift the moment the package is upgraded, and a hand-copied
  /// blocklist in production is exactly the failure mode WP19 exists to close.
  /// It is covered twice over instead: `analytics_reserved_names_test.dart`
  /// asserts the whole registry against the installed package's own copy, so
  /// a reserved name cannot enter the registry; and [_dispatch] contains the
  /// SDK's rejection if one ever reaches it by another route.
  static final RegExp _eventNamePattern = RegExp(r'^[a-z][a-z0-9_]{0,39}$');

  /// Prefixes the SDK rejects outright. `firebase_` is enforced by the
  /// package today; `google_` and `ga_` are reserved by the Firebase
  /// specification and are included so the edge does not depend on which of
  /// them the current SDK version happens to check.
  static const List<String> _reservedPrefixes = ['firebase_', 'google_', 'ga_'];

  final FirebaseAnalytics? _analytics;

  /// Resolved lazily: the destination can be constructed before
  /// `Firebase.initializeApp` has run, and `FirebaseAnalytics.instance`
  /// throws until it has.
  FirebaseAnalytics get _firebase => _analytics ?? FirebaseAnalytics.instance;

  String? _userId;

  /// Enables collection. Called once from `main` after Firebase is up, the
  /// same shape as CrashBackend.initialize.
  Future<void> initialize() async {
    await _firebase.setAnalyticsCollectionEnabled(true);
  }

  // The three calls below are the entire surface this class has against
  // Firebase. They are isolated so tests can observe what would be sent
  // without standing up a Firebase app or mocking a platform channel.
  //
  // Every one of them routes through [_dispatch], which is the telemetry
  // boundary: nothing Firebase Analytics does may become an application
  // error (WP19 / audit C C-2).

  @protected
  @visibleForTesting
  void sendEvent(String name, Map<String, Object> parameters) {
    // Edge validation (audit C T-1): the registry used to be able to emit
    // anything at all. An illegal name is dropped and reported internally
    // rather than dispatched — dropped, never thrown, because telemetry is
    // observational and must not fail its caller.
    if (!_isDispatchableEventName(name)) {
      _reportDeliveryFailure(
        'logEvent',
        name,
        ArgumentError.value(name, 'name', 'Not a valid Analytics event name'),
      );
      return;
    }
    _dispatch(
      'logEvent',
      name,
      () => _firebase.logEvent(name: name, parameters: parameters),
    );
  }

  @protected
  @visibleForTesting
  void sendScreenView(String screenName) {
    // No name validation: `logScreenView` sends the built-in `screen_view`
    // event and passes the screen as a *parameter*, so the event-name rules
    // do not apply to this string.
    _dispatch(
      'logScreenView',
      screenName,
      () => _firebase.logScreenView(screenName: screenName),
    );
  }

  @protected
  @visibleForTesting
  void sendUserId(String id) {
    _dispatch('setUserId', 'user_id', () => _firebase.setUserId(id: id));
  }

  /// True when [name] satisfies Firebase's structural event-name rules.
  ///
  /// See [_eventNamePattern] for why the exact-match reserved list is not
  /// checked here.
  static bool _isDispatchableEventName(String name) {
    if (!_eventNamePattern.hasMatch(name)) return false;
    for (final prefix in _reservedPrefixes) {
      if (name.startsWith(prefix)) return false;
    }
    return true;
  }

  /// **The telemetry boundary.** Contains every failure of the one SDK
  /// surface this class owns.
  ///
  /// `logEvent`, `logScreenView` and `setUserId` are `async`: they reject
  /// *after* [onLog] has already returned, so `AppLogger`'s synchronous
  /// try/catch around the destination fan-out (`app_logger.dart:268-275`)
  /// cannot see them. Left `unawaited` with no error handler — which is what
  /// this code did until WP19 — the rejection escaped to `runZonedGuarded`
  /// (`crash_reporter.dart:123-131`) and was recorded as a Crashlytics
  /// **fatal**. A dropped analytics event was being reported as an
  /// application crash, on every single backgrounding.
  ///
  /// Analytics is observational. It may lose data; it may never claim the
  /// application died. Both failure shapes are contained here: an
  /// asynchronous rejection through `catchError`, and a synchronous throw
  /// from the SDK through the surrounding try/catch. The call stays
  /// `unawaited` on purpose — no caller waits on analytics, and no game
  /// state transition may ever depend on it.
  void _dispatch(String operation, String name, Future<void> Function() call) {
    try {
      unawaited(
        call().catchError((Object error, StackTrace stackTrace) {
          _reportDeliveryFailure(operation, name, error, stackTrace);
        }),
      );
    } catch (error, stackTrace) {
      // Not observed in production today — the SDK validates inside its
      // async body — but containment that covers only one of the two shapes
      // is not containment.
      _reportDeliveryFailure(operation, name, error, stackTrace);
    }
  }

  /// Records that an analytics event was dropped, using the logging
  /// architecture that already exists (audit C T-3 / R-05).
  ///
  /// This is what makes [_dispatch] safe rather than merely quiet: containing
  /// the error without it would trade a visible false crash for invisible
  /// data loss, and "no crashes" would look identical to "analytics silently
  /// broken".
  ///
  /// **It can never become a Firebase event, and it cannot recurse.** It is a
  /// plain log with *no telemetry event attached*, and [onLog] returns on its
  /// first two lines for exactly that shape (`entry.telemetryEvent == null`),
  /// so the diagnostic for a failed dispatch cannot re-enter the boundary
  /// that just failed. `AppLogLevel.error` routes it to Talker and, through
  /// `CrashLogDestination`, to a **non-fatal** Crashlytics report
  /// (`crash_backend.dart:42` — only `fatal` severity is fatal), which is
  /// precisely the classification WP19 exists to establish: a telemetry
  /// delivery failure, not an application crash.
  ///
  /// Only the operation and the event name are recorded. Parameters are not:
  /// they carry session context, and this path exists for diagnosis, not
  /// collection.
  void _reportDeliveryFailure(
    String operation,
    String name,
    Object error, [
    StackTrace? stackTrace,
  ]) {
    AppLogger.instance.error(
      AppLogCategory.analytics,
      'Analytics $operation dropped "$name"',
      context: {'analytics_operation': operation, 'analytics_event': name},
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void onLog(AppLogEntry entry) {
    final event = entry.telemetryEvent;
    if (event == null) return;

    _syncUserId(entry.context);

    // Screen views use a dedicated Firebase API rather than logEvent, so
    // they land in the built-in screen reports.
    if (event.name == 'screen_changed') {
      final screen = event.payload[TelemetryKeys.toScreen];
      if (screen is String) sendScreenView(screen);
      return;
    }

    final mapping = analyticsEventMappings[event.name];
    if (mapping == null) return;

    final name = mapping.resolve(event);
    if (name == null) return;

    final payload = {
      for (final key in mapping.parameters)
        if (event.payload.containsKey(key)) key: event.payload[key],
    };

    sendEvent(name, _buildParameters(payload, entry.context));
  }

  /// Binds reports to the anonymous Firebase UID once it appears in Session
  /// Context, without gameplay having to call analytics.
  void _syncUserId(Map<String, dynamic> context) {
    final playerId = context[TelemetryKeys.playerId];
    if (playerId is! String || playerId == _userId) return;
    _userId = playerId;
    sendUserId(playerId);
  }

  /// Merges the event payload with the shared context policy and coerces
  /// everything into what Firebase accepts.
  Map<String, Object> _buildParameters(
    Map<String, dynamic> payload,
    Map<String, dynamic> context,
  ) {
    final merged = <String, dynamic>{
      for (final key in analyticsContextKeys)
        if (context[key] != null) key: context[key],
      ...payload,
    };

    final roomCode = context[analyticsHashedRoomKey];
    if (roomCode is String && roomCode.isNotEmpty) {
      merged['room_code_hash'] = _hash(roomCode);
    }

    final parameters = <String, Object>{};
    for (final entry in merged.entries) {
      if (parameters.length >= _maxParameters) break;
      final value = _asParameterValue(entry.value);
      if (value != null) parameters[entry.key] = value;
    }
    return parameters;
  }

  /// Firebase Analytics accepts only String and num parameter values.
  /// Booleans in particular used to be passed straight through and were
  /// rejected at the platform channel.
  Object? _asParameterValue(Object? value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is bool) return value ? 1 : 0;
    final text = value.toString();
    if (text.isEmpty) return null;
    return text.length <= _maxParameterLength
        ? text
        : text.substring(0, _maxParameterLength);
  }

  /// Room codes are a shared secret: whoever has one can join the game. The
  /// hash keeps rooms countable and joinable-by-nobody.
  String _hash(String input) =>
      sha256.convert(utf8.encode(input)).toString().substring(0, 16);
}
