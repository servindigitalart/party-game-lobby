import 'package:bufon_flutter/core/crash/crash_backend.dart';
import 'package:bufon_flutter/core/crash/crash_reporter.dart';
import 'package:bufon_flutter/core/logging/app_log_destination.dart';
import 'package:bufon_flutter/core/logging/app_log_entry.dart';
import 'package:bufon_flutter/core/logging/app_logger.dart';
import 'package:bufon_flutter/core/logging/log_category.dart';
import 'package:bufon_flutter/core/logging/log_level.dart';
import 'package:bufon_flutter/core/telemetry/game_telemetry_service.dart';
import 'package:bufon_flutter/core/telemetry/telemetry_context.dart';
import 'package:bufon_flutter/core/telemetry/telemetry_event.dart';
import 'package:bufon_flutter/domain/controllers/leaderboard_controller.dart';
import 'package:bufon_flutter/domain/controllers/season_controller.dart';
import 'package:bufon_flutter/domain/controllers/title_controller.dart';
import 'package:bufon_flutter/data/repositories/leaderboard_repository.dart';
import 'package:bufon_flutter/models/leaderboard_entry.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class _Recorder implements AppLogDestination {
  final List<TelemetryEvent> events = [];

  @override
  void onLog(AppLogEntry entry) {
    final event = entry.telemetryEvent;
    if (event != null) events.add(event);
  }

  TelemetryEvent named(String name) => events.firstWhere((e) => e.name == name);
  int countOf(String name) => events.where((e) => e.name == name).length;
  void clear() => events.clear();
}

class _FakeCrashBackend implements CrashBackend {
  final List<CrashReport> reports = [];
  final List<String> breadcrumbs = [];

  @override
  Future<void> initialize() async {}
  @override
  void report(CrashReport report) => reports.add(report);
  @override
  void leaveBreadcrumb(String message) => breadcrumbs.add(message);
  @override
  void setCustomKey(String key, Object value) {}
  @override
  void removeCustomKey(String key) {}
  @override
  void setUser(String? identifier) {}
}

/// Every read fails, which is what a device offline or a rules rejection
/// looks like to these controllers.
class _BrokenFirestore extends FakeFirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    throw FirebaseException(plugin: 'test', message: 'unavailable');
  }
}

void main() {
  late _Recorder recorder;
  late _FakeCrashBackend crash;
  late GameTelemetryService telemetry;

  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() async {
    telemetry = GameTelemetryService.instance;
    telemetry.init();

    CrashReporter.instance.initialize();
    crash = _FakeCrashBackend();
    await CrashReporter.instance.attachBackend(crash);

    recorder = _Recorder();
    AppLogger.instance.registerDestination(recorder);
  });

  tearDown(() {
    AppLogger.instance.unregisterDestination(recorder);
    CrashReporter.instance.dispose();
  });

  group('read failures are warnings, never crash reports', () {
    test('a failed leaderboard fetch breadcrumbs without reporting', () async {
      final controller = LeaderboardController(
        repository: LeaderboardRepository(firestore: _BrokenFirestore()),
      );

      await expectLater(
        controller.fetchTopPlayers(type: LeaderboardType.globalXp),
        throwsA(isA<Exception>()),
      );

      final event = recorder.named('leaderboard_fetch_failed');
      expect(event.severity, AppLogLevel.warning);
      expect(event.status, TelemetryStatus.failed);
      expect(crash.reports, isEmpty);
      expect(crash.breadcrumbs, isNotEmpty);
    });

    test('a failed title read is a warning', () async {
      final controller = TitleController(firestore: _BrokenFirestore());

      await expectLater(
        controller.getUnlockedTitles('uid'),
        throwsA(isA<Exception>()),
      );

      expect(
        recorder.named('titles_fetch_failed').severity,
        AppLogLevel.warning,
      );
      expect(crash.reports, isEmpty);
    });

    test('a failed season read is a warning and returns a fallback', () async {
      final controller = SeasonController(firestore: _BrokenFirestore());

      // Previously this path used AppLogger.error, which becomes a crash
      // report; being offline must not do that.
      expect(await controller.getCurrentSeason(), isNull);

      expect(recorder.named('season_fetch_failed').severity, AppLogLevel.warning);
      expect(crash.reports, isEmpty);
    });

    test('repeated read failures never report, however many there are',
        () async {
      final controller = SeasonController(firestore: _BrokenFirestore());

      for (var i = 0; i < 12; i++) {
        await controller.getCurrentSeason();
      }

      expect(recorder.countOf('season_fetch_failed'), 12);
      expect(crash.reports, isEmpty);
    });
  });

  group('write failures on a player action are reported', () {
    test('a failed title equip produces exactly one crash report', () async {
      final controller = TitleController(firestore: _BrokenFirestore());

      await expectLater(
        controller.equipTitle(uid: 'uid', titleId: 'jester'),
        throwsA(isA<Exception>()),
      );

      final event = recorder.named('title_equip_failed');
      expect(event.severity, AppLogLevel.error);
      expect(event.payload['title_id'], 'jester');
      expect(crash.reports.length, 1);
    });
  });

  group('the original cause survives the domain wrapper', () {
    test('the report carries the Firestore error, not the GameException',
        () async {
      final controller = TitleController(firestore: _BrokenFirestore());

      await expectLater(
        controller.equipTitle(uid: 'uid', titleId: 'jester'),
        throwsA(isA<Exception>()),
      );

      // Wrapping in GameException('...: $e') stringifies the cause and
      // throws from the wrapper, so without forwarding the caught error and
      // stack the report would point at the wrong frame.
      expect(crash.reports.single.error, isA<FirebaseException>());
      expect(crash.reports.single.stackTrace, isNotNull);
    });
  });

  group('session context reaches every failure', () {
    test('a failure carries room, round and platform without being passed',
        () async {
      telemetry.updateContext({
        TelemetryKeys.roomCode: 'ABCD12',
        TelemetryKeys.round: 3,
        TelemetryKeys.playerCount: 5,
      });

      final controller = SeasonController(firestore: _BrokenFirestore());
      await controller.getCurrentSeason();

      final context = recorder.named('season_fetch_failed').context;
      expect(context[TelemetryKeys.roomCode], 'ABCD12');
      expect(context[TelemetryKeys.round], 3);
      expect(context[TelemetryKeys.playerCount], 5);
      expect(context[TelemetryKeys.platform], isNotNull);

      telemetry.clearContext([
        TelemetryKeys.roomCode,
        TelemetryKeys.round,
        TelemetryKeys.playerCount,
      ]);
    });
  });

  group('retry visibility', () {
    test('a retried attempt is a warning; only exhaustion is reported', () {
      // Mirrors AdService.loadRewardedAd: each backoff attempt breadcrumbs,
      // and the give-up is the single escalation.
      for (var attempt = 1; attempt <= 3; attempt++) {
        telemetry.fail(
          AppLogCategory.ads,
          'ad_load_failed',
          error: Exception('no fill'),
          severity: AppLogLevel.warning,
          status: TelemetryStatus.retried,
          payload: {'attempt': attempt, 'will_retry': true},
        );
      }
      expect(crash.reports, isEmpty);

      telemetry.fail(
        AppLogCategory.ads,
        'ad_load_retries_exhausted',
        error: Exception('no fill'),
        payload: {'attempts': 3},
      );

      expect(recorder.countOf('ad_load_failed'), 3);
      expect(crash.reports.length, 1);
      expect(crash.reports.single.category, AppLogCategory.ads);
    });

    test('retried status never reaches analytics as a completed action', () {
      telemetry.fail(
        AppLogCategory.ads,
        'ad_load_failed',
        error: Exception('no fill'),
        severity: AppLogLevel.warning,
        status: TelemetryStatus.retried,
      );

      expect(recorder.named('ad_load_failed').status, TelemetryStatus.retried);
    });
  });
}
