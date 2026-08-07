// analytics/analytics_destination.dart

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../core/logging/app_log_destination.dart';
import '../core/logging/app_log_entry.dart';
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
/// * Anything without a registry entry (see [analyticsEventMappings]),
///   unless it is a legacy [AppLogCategory.analytics] event still produced
///   by AnalyticsService. Engineering diagnostics stay in Talker and
///   Crashlytics.
/// * `started` halves of operations, which would double-count every action.
class AnalyticsDestination implements AppLogDestination {
  AnalyticsDestination({FirebaseAnalytics? analytics}) : _analytics = analytics;

  /// Firebase caps parameters per event; the policy here stays well under it,
  /// but the cap is enforced so a future payload cannot silently break
  /// logging for a whole event.
  static const int _maxParameters = 25;

  /// Firebase truncates string parameter values at 100 characters.
  static const int _maxParameterLength = 100;

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

  @protected
  @visibleForTesting
  void sendEvent(String name, Map<String, Object> parameters) {
    unawaited(_firebase.logEvent(name: name, parameters: parameters));
  }

  @protected
  @visibleForTesting
  void sendScreenView(String screenName) {
    unawaited(_firebase.logScreenView(screenName: screenName));
  }

  @protected
  @visibleForTesting
  void sendUserId(String id) {
    unawaited(_firebase.setUserId(id: id));
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

    final String name;
    final Map<String, dynamic> payload;

    if (mapping != null) {
      final resolved = mapping.resolve(event);
      if (resolved == null) return;
      name = resolved;
      payload = {
        for (final key in mapping.parameters)
          if (event.payload.containsKey(key)) key: event.payload[key],
      };
    } else if (event.category == AppLogCategory.analytics) {
      // Legacy path: events AnalyticsService still emits directly for
      // progression and monetization, which are analytics events by
      // construction. They move into the registry as their features get
      // properly instrumented.
      name = event.name;
      payload = event.payload;
    } else {
      return;
    }

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
