import 'package:bufon_flutter/analytics/analytics_destination.dart';
import 'package:bufon_flutter/analytics/analytics_event_mapping.dart';
import 'package:bufon_flutter/core/logging/app_logger.dart';
import 'package:bufon_flutter/core/logging/log_category.dart';
import 'package:bufon_flutter/core/logging/log_level.dart';
import 'package:bufon_flutter/core/telemetry/game_telemetry_service.dart';
import 'package:bufon_flutter/core/telemetry/telemetry_context.dart';
import 'package:bufon_flutter/core/telemetry/telemetry_event.dart';
import 'package:flutter_test/flutter_test.dart';

class _LoggedEvent {
  _LoggedEvent(this.name, this.parameters);
  final String name;
  final Map<String, Object> parameters;
}

/// Captures what the destination would send to Firebase, by overriding the
/// three methods that are its entire surface against the SDK.
class _RecordingDestination extends AnalyticsDestination {
  final List<_LoggedEvent> events = [];
  final List<String> screenViews = [];
  final List<String> userIds = [];

  @override
  void sendEvent(String name, Map<String, Object> parameters) =>
      events.add(_LoggedEvent(name, parameters));

  @override
  void sendScreenView(String screenName) => screenViews.add(screenName);

  @override
  void sendUserId(String id) => userIds.add(id);
}

void main() {
  late _RecordingDestination destination;
  late GameTelemetryService telemetry;

  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() {
    destination = _RecordingDestination();
    telemetry = GameTelemetryService.instance;
    telemetry.init();
    telemetry.clearContext([
      TelemetryKeys.roomCode,
      TelemetryKeys.playerId,
      TelemetryKeys.playerCount,
      TelemetryKeys.round,
    ]);
    AppLogger.instance.registerDestination(destination);
  });

  tearDown(() => AppLogger.instance.unregisterDestination(destination));

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('mapping', () {
    test('a mapped event reaches Firebase under its analytics name', () async {
      telemetry.track(AppLogCategory.room, 'host_changed');
      await settle();

      expect(destination.events.single.name, 'host_transferred');
    });

    test('an event with no mapping is dropped', () async {
      telemetry.track(AppLogCategory.firestore, 'room_listener_attached');
      telemetry.track(AppLogCategory.network, 'heartbeat_failed');
      await settle();

      expect(destination.events, isEmpty);
    });

    test('phase_changed resolves to a different name per phase', () async {
      for (final phase in ['voting', 'roundResult', 'finalWinner']) {
        telemetry.track(
          AppLogCategory.gameplay,
          'phase_changed',
          payload: {'to_phase': phase},
        );
      }
      // `answering` is already covered by round_started and must be dropped.
      telemetry.track(
        AppLogCategory.gameplay,
        'phase_changed',
        payload: {'to_phase': 'answering'},
      );
      await settle();

      expect(
        destination.events.map((e) => e.name),
        ['voting_started', 'round_finished', 'match_finished'],
      );
    });

    test('progression events are mapped, not passed through', () async {
      telemetry.track(
        AppLogCategory.progression,
        'xp_awarded',
        payload: {'xp_amount': 50, 'reason': 'game_completion'},
      );
      await settle();

      expect(destination.events.single.name, 'xp_awarded');
      expect(destination.events.single.parameters['xp_amount'], 50);
    });

    test('an unmapped event is dropped whatever its category', () async {
      // There is no passthrough any more: category alone never grants
      // access to Firebase.
      telemetry.track(AppLogCategory.progression, 'some_internal_step');
      await settle();

      expect(destination.events, isEmpty);
    });

    test('screen changes use the dedicated screen-view API', () async {
      telemetry.transition('lobby');
      await settle();

      expect(destination.screenViews, ['lobby']);
      expect(destination.events, isEmpty);
    });
  });

  group('duplicate prevention', () {
    test('the started half of an operation is never counted', () async {
      final operation = telemetry.start(AppLogCategory.room, 'room_created');
      await settle();
      expect(destination.events, isEmpty);

      operation.finish();
      await settle();
      expect(destination.events.map((e) => e.name), ['room_created']);
    });

    test('a failure maps to its own event name, not the success name',
        () async {
      telemetry
          .start(AppLogCategory.room, 'room_joined')
          .fail(Exception('full'), severity: AppLogLevel.warning);
      await settle();

      expect(destination.events.single.name, 'room_join_failed');
    });

    test('a failure with no failureName is dropped entirely', () async {
      telemetry.fail(
        AppLogCategory.gameplay,
        'match_started',
        error: Exception('nope'),
      );
      await settle();

      expect(destination.events, isEmpty);
    });

    test('one gameplay action produces exactly one analytics event',
        () async {
      telemetry.track(
        AppLogCategory.voting,
        'vote_submitted',
        payload: {'time_to_vote_seconds': 4},
      );
      await settle();

      expect(destination.events.length, 1);
      expect(destination.events.single.name, 'vote_submitted');
    });
  });

  group('parameters', () {
    test('session context is attached and the room code is hashed', () async {
      telemetry.updateContext({
        TelemetryKeys.roomCode: 'ABCD12',
        TelemetryKeys.playerCount: 4,
        TelemetryKeys.round: 2,
      });

      telemetry.track(AppLogCategory.gameplay, 'match_started');
      await settle();

      final parameters = destination.events.single.parameters;
      expect(parameters[TelemetryKeys.playerCount], 4);
      expect(parameters[TelemetryKeys.round], 2);
      expect(parameters.containsKey(TelemetryKeys.roomCode), isFalse);
      expect(parameters['room_code_hash'], isA<String>());
      expect(parameters['room_code_hash'], isNot('ABCD12'));
    });

    test('personal and identifying context is never sent as a parameter',
        () async {
      telemetry.updateContext({
        TelemetryKeys.playerName: 'Emilio',
        TelemetryKeys.playerId: 'uid-1',
        TelemetryKeys.hostId: 'uid-1',
        TelemetryKeys.sessionId: 'session-1',
      });

      telemetry.track(AppLogCategory.gameplay, 'match_started');
      await settle();

      final parameters = destination.events.single.parameters;
      for (final key in [
        TelemetryKeys.playerName,
        TelemetryKeys.playerId,
        TelemetryKeys.hostId,
        TelemetryKeys.sessionId,
      ]) {
        expect(parameters.containsKey(key), isFalse, reason: key);
      }
    });

    test('only allowlisted payload keys are forwarded', () async {
      telemetry.track(
        AppLogCategory.room,
        'room_created',
        payload: {'attempts': 2, 'internal_debug_blob': 'x' * 500},
      );
      await settle();

      final parameters = destination.events.single.parameters;
      expect(parameters['attempts'], 2);
      expect(parameters.containsKey('internal_debug_blob'), isFalse);
    });

    test('booleans become numbers and long strings are truncated', () async {
      telemetry.track(
        AppLogCategory.progression,
        'xp_awarded',
        payload: {'level_up': true, 'reason': 'y' * 250},
      );
      await settle();

      final parameters = destination.events.single.parameters;
      // Firebase rejects bool parameters; they used to be passed straight
      // through by AnalyticsService.
      expect(parameters['level_up'], 1);
      expect((parameters['reason']! as String).length, 100);
    });

    test('the anonymous uid is bound once, from context', () async {
      telemetry.updateContext({TelemetryKeys.playerId: 'uid-42'});

      telemetry.track(AppLogCategory.gameplay, 'match_started');
      telemetry.track(AppLogCategory.gameplay, 'match_started');
      await settle();

      expect(destination.userIds, ['uid-42']);
    });
  });

  test('every mapping resolves a name for a succeeded event', () {
    for (final entry in analyticsEventMappings.entries) {
      final event = TelemetryEvent(
        id: 'id',
        name: entry.key,
        category: AppLogCategory.app,
        severity: AppLogLevel.info,
        status: TelemetryStatus.succeeded,
        timestamp: DateTime(2026),
        context: const TelemetryContext.empty(),
        payload: const {'to_phase': 'voting'},
      );
      final resolved = entry.value.resolve(event);
      expect(resolved, isNotNull, reason: entry.key);
      // Firebase event names: <=40 chars, snake_case, start with a letter.
      expect(resolved!.length, lessThanOrEqualTo(40), reason: entry.key);
      expect(
        RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(resolved),
        isTrue,
        reason: entry.key,
      );
    }
  });
}
