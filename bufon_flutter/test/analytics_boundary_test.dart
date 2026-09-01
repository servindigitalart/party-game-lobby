// test/analytics_boundary_test.dart
//
// WP19 · T-B, T-C, T-D, T-E, T-F, T-G — the *asynchronous failure boundary*.
//
// The production defect was never that a name was wrong. It was that
// `AnalyticsDestination` handed an `async` SDK call to `unawaited(...)` with
// no error handler, so the rejection arrived after `onLog` had returned,
// sailed past `AppLogger`'s synchronous try/catch, reached
// `runZonedGuarded` in `main` and was filed as a Crashlytics **fatal**.
//
// The existing suite could not see any of that: `_RecordingDestination` in
// `analytics_destination_test.dart` overrides `sendEvent`, which is the exact
// method that touches the SDK. These tests drive the **real**
// `AnalyticsDestination` with a substituted `FirebaseAnalytics`, so the
// containment under test is the shipped code and not a copy of it.

import 'dart:async';

import 'package:bufon_flutter/analytics/analytics_destination.dart';
import 'package:bufon_flutter/core/logging/app_log_destination.dart';
import 'package:bufon_flutter/core/logging/app_log_entry.dart';
import 'package:bufon_flutter/core/logging/app_logger.dart';
import 'package:bufon_flutter/core/logging/log_category.dart';
import 'package:bufon_flutter/core/logging/log_level.dart';
import 'package:bufon_flutter/core/telemetry/app_session_observer.dart';
import 'package:bufon_flutter/core/telemetry/game_telemetry_service.dart';
import 'package:bufon_flutter/core/telemetry/telemetry_context.dart';
import 'package:bufon_flutter/core/telemetry/telemetry_event.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _SdkCall {
  _SdkCall(this.method, this.name, [this.parameters = const {}]);
  final String method;
  final String name;
  final Map<String, Object> parameters;
}

/// A stand-in for the Firebase SDK.
///
/// `implements FirebaseAnalytics` with `noSuchMethod` rather than a mocking
/// package: only three methods are ever reached from `AnalyticsDestination`,
/// and the repository has no mocking dependency to add one for.
class _FakeAnalytics implements FirebaseAnalytics {
  _FakeAnalytics({this.failWith});

  /// When set, every call records itself and then rejects — the production
  /// shape: `async`, so the throw becomes a rejected Future, not a
  /// synchronous exception.
  final Object? failWith;

  final List<_SdkCall> calls = [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    calls.add(_SdkCall('logEvent', name, parameters ?? const {}));
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    calls.add(_SdkCall('logScreenView', screenName ?? ''));
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> setUserId({String? id, AnalyticsCallOptions? callOptions}) async {
    calls.add(_SdkCall('setUserId', id ?? ''));
    if (failWith != null) throw failWith!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used by '
          'AnalyticsDestination; if it now is, this fake must implement it.');
}

/// Exposes the protected SDK seam so an illegal name can be pushed at it
/// directly. Nothing is overridden — the code under test is the real one.
class _TestableDestination extends AnalyticsDestination {
  _TestableDestination({super.analytics});

  void dispatchEvent(String name, [Map<String, Object> parameters = const {}]) =>
      sendEvent(name, parameters);
}

/// Captures everything that reaches the log fan-out.
class _CaptureDestination implements AppLogDestination {
  final List<AppLogEntry> entries = [];

  @override
  void onLog(AppLogEntry entry) => entries.add(entry);

  Iterable<AppLogEntry> get diagnostics => entries.where(
    (e) => e.telemetryEvent == null && e.category == AppLogCategory.analytics,
  );
}

/// The pre-WP19 shape, reproduced *only* to prove the harness below can
/// actually observe an escaping asynchronous error. Without this control the
/// containment assertions would pass against a test that cannot fail.
class _UncontainedDestination implements AppLogDestination {
  @override
  void onLog(AppLogEntry entry) {
    if (entry.telemetryEvent == null) return;
    unawaited(Future<void>.error(StateError('escaped')));
  }
}

void main() {
  late GameTelemetryService telemetry;
  late _CaptureDestination capture;

  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() {
    telemetry = GameTelemetryService.instance;
    telemetry.init();
    telemetry.clearContext([
      TelemetryKeys.roomCode,
      TelemetryKeys.playerId,
      TelemetryKeys.playerCount,
      TelemetryKeys.round,
    ]);
    capture = _CaptureDestination();
    AppLogger.instance.registerDestination(capture);
  });

  tearDown(() => AppLogger.instance.unregisterDestination(capture));

  /// Lets `unawaited` continuations and their error handlers run.
  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  /// Runs [body] in its own guarded zone and returns whatever escaped.
  Future<List<Object>> escapedErrors(Future<void> Function() body) async {
    final escaped = <Object>[];
    final done = Completer<void>();
    runZonedGuarded(
      () async {
        try {
          await body();
        } finally {
          if (!done.isCompleted) done.complete();
        }
      },
      (error, _) => escaped.add(error),
    );
    await done.future;
    await settle();
    return escaped;
  }

  /// The reserved-name rejection exactly as the SDK raises it.
  Object reservedNameError(String name) =>
      ArgumentError.value(name, 'name', 'Event name is reserved and cannot be used');

  group('T-C — the harness can see an escaping asynchronous error', () {
    test('an unhandled rejection from a destination reaches the zone', () async {
      final leaky = _UncontainedDestination();
      final escaped = await escapedErrors(() async {
        AppLogger.instance.registerDestination(leaky);
        telemetry.track(AppLogCategory.app, 'app_backgrounded');
        await settle();
      });
      AppLogger.instance.unregisterDestination(leaky);

      // If this ever goes green-by-emptiness, every containment assertion
      // below becomes meaningless.
      expect(
        escaped,
        isNotEmpty,
        reason: 'the harness cannot detect escape; the other tests are vacuous',
      );
    });
  });

  group('T-D — a rejecting SDK is contained at the boundary', () {
    test('an asynchronous rejection never reaches the zone', () async {
      final analytics = _FakeAnalytics(failWith: reservedNameError('whatever'));
      final destination = AnalyticsDestination(analytics: analytics);

      final escaped = await escapedErrors(() async {
        AppLogger.instance.registerDestination(destination);
        telemetry.track(AppLogCategory.app, 'app_backgrounded');
        await settle();
      });
      AppLogger.instance.unregisterDestination(destination);

      expect(analytics.calls, hasLength(1), reason: 'the SDK was called');
      expect(escaped, isEmpty, reason: 'the rejection escaped containment');
    });

    test('the caller returns normally and later destinations still run', () async {
      final analytics = _FakeAnalytics(failWith: reservedNameError('whatever'));
      final destination = AnalyticsDestination(analytics: analytics);
      final downstream = _CaptureDestination();

      AppLogger.instance.registerDestination(destination);
      AppLogger.instance.registerDestination(downstream);
      addTearDown(() {
        AppLogger.instance.unregisterDestination(destination);
        AppLogger.instance.unregisterDestination(downstream);
      });

      // Telemetry is observational: the call must return like any other.
      expect(
        () => telemetry.track(AppLogCategory.gameplay, 'match_started'),
        returnsNormally,
      );
      await settle();

      expect(
        downstream.entries.where((e) => e.telemetryEvent?.name == 'match_started'),
        hasLength(1),
        reason: 'the failing destination interrupted the fan-out',
      );
    });

    test('a synchronous SDK throw is contained too', () async {
      // `_dispatch` guards both shapes. The SDK validates inside its async
      // body today, but containment covering one shape is not containment.
      final analytics = _FakeAnalytics(failWith: StateError('sync-ish'));
      final destination = _TestableDestination(analytics: analytics);

      final escaped = await escapedErrors(() async {
        destination.dispatchEvent('some_event');
        await settle();
      });

      expect(escaped, isEmpty);
    });
  });

  group('T-E — an illegal name is dropped, not dispatched', () {
    test('reserved prefixes and malformed names never reach the SDK', () {
      final analytics = _FakeAnalytics();
      final destination = _TestableDestination(analytics: analytics);

      for (final illegal in const [
        'firebase_thing',
        'google_thing',
        'ga_thing',
        'App_Backgrounded', // not lower-case
        '9lives', // must start with a letter
        '', // empty
        'a_very_long_event_name_that_exceeds_forty_characters',
      ]) {
        expect(
          () => destination.dispatchEvent(illegal),
          returnsNormally,
          reason: '"$illegal" must be dropped, never thrown',
        );
      }

      expect(analytics.calls, isEmpty, reason: 'an illegal name was dispatched');
      expect(capture.diagnostics, hasLength(7));
    });

    test('a legal name is still dispatched', () {
      final analytics = _FakeAnalytics();
      _TestableDestination(analytics: analytics).dispatchEvent('match_started');

      expect(analytics.calls.map((c) => c.name), ['match_started']);
      expect(capture.diagnostics, isEmpty);
    });
  });

  group('T-F — a dropped event is observable, and cannot recurse', () {
    test('one diagnostic, no Firebase event, no recursion', () async {
      final analytics = _FakeAnalytics(failWith: reservedNameError('whatever'));
      final destination = AnalyticsDestination(analytics: analytics);

      AppLogger.instance.registerDestination(destination);
      addTearDown(() => AppLogger.instance.unregisterDestination(destination));

      telemetry.track(AppLogCategory.app, 'app_backgrounded');
      await settle();

      final diagnostics = capture.diagnostics.toList();
      expect(diagnostics, hasLength(1), reason: 'exactly one internal report');
      expect(diagnostics.single.level, AppLogLevel.error);
      expect(diagnostics.single.message, contains('app_backgrounded'));
      expect(diagnostics.single.error, isA<ArgumentError>());

      // The diagnostic carries no telemetry event, which is what stops it
      // re-entering the boundary that just failed. One SDK call went out and
      // exactly one came back failed; a recursive report would show more.
      expect(diagnostics.single.telemetryEvent, isNull);
      expect(analytics.calls, hasLength(1), reason: 'the diagnostic recursed');
    });
  });

  group('T-B — the lifecycle name that shipped broken', () {
    test('backgrounding emits app_backgrounded through the real destination', () async {
      final analytics = _FakeAnalytics();
      final destination = AnalyticsDestination(analytics: analytics);
      AppLogger.instance.registerDestination(destination);
      addTearDown(() => AppLogger.instance.unregisterDestination(destination));

      final observer = AppSessionObserver(telemetry: telemetry);
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      await settle();

      final names = analytics.calls
          .where((c) => c.method == 'logEvent')
          .map((c) => c.name)
          .toList();

      // The assertion that would have caught the defect before release.
      expect(names, contains('app_backgrounded'));
      expect(names, isNot(contains('app_background')));
      expect(names, contains('app_foreground'), reason: 'its twin is untouched');
    });
  });

  group('T-G — session cleanup completes under a failing destination', () {
    test('the session still ends and nothing is stranded', () async {
      final analytics = _FakeAnalytics(failWith: reservedNameError('whatever'));
      final destination = AnalyticsDestination(analytics: analytics);
      final observer = AppSessionObserver(telemetry: telemetry);

      final escaped = await escapedErrors(() async {
        AppLogger.instance.registerDestination(destination);
        observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
        observer.didChangeAppLifecycleState(AppLifecycleState.paused);
        await settle();
      });
      AppLogger.instance.unregisterDestination(destination);

      expect(escaped, isEmpty);
      expect(observer.hasActiveSession, isFalse, reason: 'session left open');

      // `endSession` ran: the id is not stranded in Session Context.
      expect(telemetry.context[TelemetryKeys.sessionId], isNull);

      // And the duration made it onto the event before the reset.
      final ended = analytics.calls.firstWhere(
        (c) => c.name == 'session_ended',
        orElse: () => throw StateError(
          'session_ended never reached the destination; cleanup stopped short. '
          'Saw: ${analytics.calls.map((c) => c.name).toList()}',
        ),
      );
      expect(ended.parameters, contains(TelemetryKeys.sessionDurationSeconds));
    });
  });
}
