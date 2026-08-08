import 'package:bufon_flutter/analytics/analytics_event_mapping.dart';
import 'package:bufon_flutter/core/logging/app_log_destination.dart';
import 'package:bufon_flutter/core/logging/app_log_entry.dart';
import 'package:bufon_flutter/core/logging/app_logger.dart';
import 'package:bufon_flutter/core/logging/log_category.dart';
import 'package:bufon_flutter/core/telemetry/app_session_observer.dart';
import 'package:bufon_flutter/core/telemetry/game_telemetry_service.dart';
import 'package:bufon_flutter/core/telemetry/telemetry_context.dart';
import 'package:bufon_flutter/core/telemetry/telemetry_event.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Recorder implements AppLogDestination {
  final List<TelemetryEvent> events = [];

  @override
  void onLog(AppLogEntry entry) {
    final event = entry.telemetryEvent;
    if (event != null) events.add(event);
  }

  List<String> get names => events.map((e) => e.name).toList();
  int countOf(String name) => events.where((e) => e.name == name).length;
  TelemetryEvent named(String name) => events.firstWhere((e) => e.name == name);
  void clear() => events.clear();
}

void main() {
  late GameTelemetryService telemetry;
  late _Recorder recorder;

  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() {
    telemetry = GameTelemetryService.instance;
    telemetry.init();
    recorder = _Recorder();
    AppLogger.instance.registerDestination(recorder);
  });

  tearDown(() {
    AppLogger.instance.unregisterDestination(recorder);
    telemetry.endSession();
  });

  group('session lifecycle', () {
    late AppSessionObserver observer;

    setUp(() => observer = AppSessionObserver());
    tearDown(() => observer.dispose());

    test('start opens exactly one session and no app_resumed', () {
      observer.start();

      expect(observer.hasActiveSession, isTrue);
      expect(recorder.countOf('session_started'), 1);
      // Nothing was backgrounded yet; app_started already marks the launch.
      expect(recorder.countOf('app_resumed'), 0);
    });

    test('a duplicate resume does not open a second session', () {
      observer.start();
      recorder.clear();

      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(recorder.countOf('session_started'), 0);
    });

    test('backgrounding closes the session with a duration', () async {
      observer.start();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      recorder.clear();

      observer.didChangeAppLifecycleState(AppLifecycleState.paused);

      expect(recorder.countOf('app_backgrounded'), 1);
      expect(recorder.countOf('session_ended'), 1);
      expect(
        recorder.named('session_ended').context[
          TelemetryKeys.sessionDurationSeconds
        ],
        isNotNull,
      );
      expect(observer.hasActiveSession, isFalse);
    });

    test('background then foreground is one ending and one new session', () {
      observer.start();
      recorder.clear();

      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(recorder.countOf('session_ended'), 1);
      expect(recorder.countOf('session_started'), 1);
      expect(recorder.countOf('app_resumed'), 1);
    });

    test('backgrounding twice does not end the session twice', () {
      observer.start();
      recorder.clear();

      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      observer.didChangeAppLifecycleState(AppLifecycleState.detached);

      expect(recorder.countOf('session_ended'), 1);
    });

    test('inactive is ignored so brief interruptions keep the session', () {
      observer.start();
      recorder.clear();

      observer.didChangeAppLifecycleState(AppLifecycleState.inactive);

      expect(recorder.events, isEmpty);
      expect(observer.hasActiveSession, isTrue);
    });

    test('session duration does not leak into later events', () {
      observer.start();
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      recorder.clear();

      telemetry.track(AppLogCategory.app, 'app_started');

      expect(
        recorder.named('app_started').context[
          TelemetryKeys.sessionDurationSeconds
        ],
        isNull,
      );
    });
  });

  group('migrated domains reach the analytics registry', () {
    // Every event the migration moved out of AnalyticsService must have a
    // mapping, or it silently stops being collected.
    const migrated = {
      'xp_awarded': AppLogCategory.progression,
      'level_up': AppLogCategory.progression,
      'game_completed': AppLogCategory.progression,
      'achievement_unlocked': AppLogCategory.progression,
      'avatar_unlocked': AppLogCategory.progression,
      'avatar_selected': AppLogCategory.progression,
      'title_unlocked': AppLogCategory.progression,
      'title_equipped': AppLogCategory.progression,
      'season_started': AppLogCategory.season,
      'season_ended': AppLogCategory.season,
      'season_reward_granted': AppLogCategory.season,
      'season_viewed': AppLogCategory.season,
      'leaderboards_updated': AppLogCategory.leaderboard,
      'leaderboard_viewed': AppLogCategory.leaderboard,
      'leaderboard_rank_achieved': AppLogCategory.leaderboard,
      'paywall_shown': AppLogCategory.purchases,
      'purchase_started': AppLogCategory.purchases,
      'purchase_completed': AppLogCategory.purchases,
      'rewarded_ad_started': AppLogCategory.ads,
      'rewarded_ad_completed': AppLogCategory.ads,
      'profile_viewed': AppLogCategory.ui,
      'profile_shared': AppLogCategory.ui,
      'returned_same_day': AppLogCategory.app,
      'returned_next_day': AppLogCategory.app,
      'returned_after_week': AppLogCategory.app,
    };

    for (final entry in migrated.entries) {
      test('${entry.key} has a mapping', () {
        expect(
          analyticsEventMappings.containsKey(entry.key),
          isTrue,
          reason: '${entry.key} would be silently dropped',
        );
      });
    }

    test('the ad outcome pair shares one event name', () {
      // Reward earned and reward dismissed are the same action with two
      // outcomes, so they must not be two analytics events fighting to be
      // counted.
      final mapping = analyticsEventMappings['rewarded_ad_completed']!;
      expect(mapping.failureName, 'rewarded_ad_failed');
    });

    test('a purchase failure maps to purchase_failed', () {
      expect(
        analyticsEventMappings['purchase_completed']!.failureName,
        'purchase_failed',
      );
    });
  });

  group('build metadata enriches everything with no manual wiring', () {
    test('app version and build number reach every event once resolved', () {
      // package_info_plus resolves asynchronously, so simulate the moment it
      // lands rather than waiting on a platform channel in a unit test.
      telemetry.updateContext({
        TelemetryKeys.appVersion: '1.2.3',
        TelemetryKeys.buildNumber: '42',
      });

      telemetry.track(AppLogCategory.app, 'app_started');

      final context = recorder.named('app_started').context;
      expect(context[TelemetryKeys.appVersion], '1.2.3');
      expect(context[TelemetryKeys.buildNumber], '42');
    });

    test('build metadata is forwarded to analytics', () {
      // Without this a crash or an event cannot be attributed to a build,
      // which is the first question when triaging a beta.
      expect(analyticsContextKeys, contains(TelemetryKeys.appVersion));
      expect(analyticsContextKeys, contains(TelemetryKeys.buildNumber));
    });

    test('build metadata survives a session ending', () {
      telemetry.updateContext({
        TelemetryKeys.appVersion: '1.2.3',
        TelemetryKeys.buildNumber: '42',
      });
      telemetry.startSession();
      telemetry.endSession();
      recorder.clear();

      // endSession resets to device context; build metadata is device-level
      // and must not be lost with the session.
      telemetry.track(AppLogCategory.app, 'app_started');
      final context = recorder.named('app_started').context;
      expect(context[TelemetryKeys.appVersion], '1.2.3');
      expect(context[TelemetryKeys.buildNumber], '42');
    });
  });

  group('payload discipline', () {
    test('migrated events do not repeat Session Context in the payload', () {
      telemetry.updateContext({TelemetryKeys.roomCode: 'ABCD12'});

      telemetry.track(
        AppLogCategory.ads,
        'rewarded_ad_started',
        payload: {'ad_network': 'admob'},
      );

      final event = recorder.named('rewarded_ad_started');
      expect(event.payload.containsKey(TelemetryKeys.roomCode), isFalse);
      expect(event.context[TelemetryKeys.roomCode], 'ABCD12');
    });

    test('season rewards never carry another player id', () {
      // The reward loop runs over other users; their ids must not leave the
      // device.
      final mapping = analyticsEventMappings['season_reward_granted']!;
      expect(mapping.parameters, isNot(contains('user_id')));
      expect(mapping.parameters, isNot(contains('user_id_hash')));
    });
  });
}
