import 'package:bufon_flutter/core/crash/crash_backend.dart';
import 'package:bufon_flutter/core/crash/crash_reporter.dart';
import 'package:bufon_flutter/core/logging/app_logger.dart';
import 'package:bufon_flutter/core/logging/log_category.dart';
import 'package:bufon_flutter/core/logging/log_level.dart';
import 'package:bufon_flutter/core/telemetry/game_telemetry_service.dart';
import 'package:bufon_flutter/core/telemetry/telemetry_context.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBackend implements CrashBackend {
  final List<CrashReport> reports = [];
  final List<String> breadcrumbs = [];
  final Map<String, Object> keys = {};
  final List<String> removedKeys = [];
  String? user;
  bool initialized = false;

  @override
  Future<void> initialize() async => initialized = true;

  @override
  void report(CrashReport report) => reports.add(report);

  @override
  void leaveBreadcrumb(String message) => breadcrumbs.add(message);

  @override
  void setCustomKey(String key, Object value) => keys[key] = value;

  @override
  void removeCustomKey(String key) {
    keys.remove(key);
    removedKeys.add(key);
  }

  @override
  void setUser(String? identifier) => user = identifier;
}

class _BrokenBackend extends _FakeBackend {
  @override
  void report(CrashReport report) => throw StateError('backend is down');
}

void main() {
  late CrashReporter reporter;
  late _FakeBackend backend;

  setUp(() async {
    reporter = CrashReporter.instance;
    reporter.initialize();
    backend = _FakeBackend();
    await reporter.attachBackend(backend);
  });

  tearDown(() {
    reporter.dispose();
    AppLogger.instance.detachContextProvider();
  });

  group('recording', () {
    test('recordNonFatal reaches the backend once, not fatal', () {
      final error = Exception('firestore write failed');
      reporter.recordNonFatal(error, category: AppLogCategory.firestore);

      expect(backend.reports.length, 1);
      expect(backend.reports.single.error, error);
      expect(backend.reports.single.isFatal, isFalse);
      expect(backend.reports.single.category, AppLogCategory.firestore);
    });

    test('recordFatal marks the report fatal', () {
      reporter.recordFatal(Exception('boom'), reason: 'zone');

      expect(backend.reports.single.isFatal, isTrue);
      expect(backend.reports.single.severity, AppLogLevel.fatal);
      expect(backend.reports.single.reason, 'zone');
    });

    test('fatal:true promotes severity, so the two cannot disagree', () {
      reporter.recordError(
        Exception('boom'),
        severity: AppLogLevel.warning,
        fatal: true,
      );

      expect(backend.reports.single.severity, AppLogLevel.fatal);
      expect(backend.reports.single.isFatal, isTrue);
    });

    test('recordAssertion is critical but not fatal', () {
      reporter.recordAssertion('room had no host');

      final report = backend.reports.single;
      expect(report.error, isA<AssertionError>());
      expect(report.severity, AppLogLevel.critical);
      expect(report.isFatal, isFalse);
      expect(report.stackTrace, isNotNull);
    });

    test('an explicit record produces exactly one report', () {
      // recordError mirrors into AppLogger, which feeds the crash
      // destination back; the origin marker must stop a second report.
      reporter.recordError(Exception('once'));

      expect(backend.reports.length, 1);
    });

    test('a throwing backend never propagates', () async {
      reporter.dispose();
      reporter.initialize();
      await reporter.attachBackend(_BrokenBackend());

      expect(() => reporter.recordError(Exception('x')), returnsNormally);
    });
  });

  group('AppLogger integration', () {
    test('an error log becomes one non-fatal report', () {
      final error = Exception('snapshot closed');
      AppLogger.instance.error(
        AppLogCategory.firestore,
        'Listener died',
        error: error,
      );

      expect(backend.reports.length, 1);
      expect(backend.reports.single.error, error);
      expect(backend.reports.single.isFatal, isFalse);
      expect(backend.reports.single.reason, 'Listener died');
    });

    test('a fatal log becomes a fatal report', () {
      AppLogger.instance.fatal(AppLogCategory.room, 'Room state corrupted');

      expect(backend.reports.single.isFatal, isTrue);
    });

    test('info and warning logs are never reported', () {
      AppLogger.instance.info(AppLogCategory.room, 'Room created');
      AppLogger.instance.warning(AppLogCategory.network, 'Slow heartbeat');

      expect(backend.reports, isEmpty);
    });

    test('warning leaves a breadcrumb, info does not', () {
      AppLogger.instance.info(AppLogCategory.room, 'Room created');
      expect(backend.breadcrumbs, isEmpty);

      AppLogger.instance.warning(AppLogCategory.network, 'Slow heartbeat');
      expect(backend.breadcrumbs.single, contains('Slow heartbeat'));
    });
  });

  group('breadcrumbs from telemetry', () {
    late GameTelemetryService telemetry;

    setUp(() {
      telemetry = GameTelemetryService.instance;
      telemetry.init();
    });

    test('a telemetry event becomes a breadcrumb without extra code', () {
      telemetry.track(
        AppLogCategory.room,
        'room_created',
        payload: {'attempts': 2},
      );

      expect(backend.breadcrumbs.single, 'room_created status=succeeded attempts=2');
    });

    test('start/finish leaves both breadcrumbs with a duration', () {
      telemetry.start(AppLogCategory.room, 'room_joined').finish();

      expect(backend.breadcrumbs.length, 2);
      expect(backend.breadcrumbs.first, contains('status=started'));
      expect(backend.breadcrumbs.last, contains('duration_ms='));
    });

    test('a failing operation breadcrumbs and reports once', () {
      final operation = telemetry.start(AppLogCategory.room, 'room_created');
      operation.fail(Exception('offline'));

      expect(backend.breadcrumbs.length, 2);
      expect(backend.reports.length, 1);
      expect(backend.reports.single.category, AppLogCategory.room);
    });
  });

  group('custom keys', () {
    test('session context is pushed automatically as keys', () {
      AppLogger.instance.attachContextProvider(
        () => {TelemetryKeys.roomCode: 'ABCD12', TelemetryKeys.playerCount: 4},
      );

      reporter.recordError(Exception('x'));

      expect(backend.keys[TelemetryKeys.roomCode], 'ABCD12');
      expect(backend.keys[TelemetryKeys.playerCount], 4);
    });

    test('unchanged keys are not pushed twice', () {
      AppLogger.instance.attachContextProvider(
        () => {TelemetryKeys.roomCode: 'ABCD12'},
      );

      reporter.log('first');
      backend.keys.clear();
      reporter.log('second');

      expect(backend.keys, isEmpty);
    });

    test('a key that leaves the context is removed', () {
      var roomCode = 'ABCD12';
      AppLogger.instance.attachContextProvider(
        () => roomCode.isEmpty ? {} : {TelemetryKeys.roomCode: roomCode},
      );

      reporter.log('in room');
      roomCode = '';
      reporter.log('left room');

      expect(backend.removedKeys, contains(TelemetryKeys.roomCode));
    });

    test('structured "_"-prefixed context never becomes a key', () {
      AppLogger.instance.attachContextProvider(() => {'_telemetry': Object()});

      reporter.log('breadcrumb');

      expect(backend.keys.keys.where((k) => k.startsWith('_')), isEmpty);
    });

    test('manual keys are namespaced by domain', () {
      reporter.setCustomKey(CrashKeyDomain.firebase, 'uid', 'u1');
      expect(backend.keys['firebase_uid'], 'u1');

      reporter.removeCustomKey(CrashKeyDomain.firebase, 'uid');
      expect(backend.keys.containsKey('firebase_uid'), isFalse);
    });
  });

  group('buffering', () {
    test('reports before a backend exists are flushed on attach', () async {
      reporter.dispose();
      reporter.initialize();

      reporter.recordError(Exception('during firebase init'));
      reporter.log('early breadcrumb');

      final late = _FakeBackend();
      await reporter.attachBackend(late);

      expect(late.initialized, isTrue);
      expect(late.reports.length, 1);
      expect(late.breadcrumbs, contains('early breadcrumb'));
    });
  });

  group('user', () {
    test('setUser and clearUser reach the backend', () {
      reporter.setUser('player-1');
      expect(backend.user, 'player-1');

      reporter.clearUser();
      expect(backend.user, isNull);
    });
  });
}
