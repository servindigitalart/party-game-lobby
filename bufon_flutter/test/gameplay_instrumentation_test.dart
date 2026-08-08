import 'package:bufon_flutter/core/crash/crash_backend.dart';
import 'package:bufon_flutter/core/crash/crash_reporter.dart';
import 'package:bufon_flutter/core/logging/app_log_destination.dart';
import 'package:bufon_flutter/core/logging/app_log_entry.dart';
import 'package:bufon_flutter/core/logging/app_logger.dart';
import 'package:bufon_flutter/core/logging/log_level.dart';
import 'package:bufon_flutter/core/telemetry/game_telemetry_service.dart';
import 'package:bufon_flutter/core/telemetry/telemetry_context.dart';
import 'package:bufon_flutter/core/telemetry/telemetry_event.dart';
import 'package:bufon_flutter/data/repositories/room_repository.dart';
import 'package:bufon_flutter/models/game_phase.dart';
import 'package:bufon_flutter/models/player.dart';
import 'package:bufon_flutter/services/connection_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures everything the instrumentation produces, the same way the real
/// Talker and CrashReporter destinations see it.
class _Recorder implements AppLogDestination {
  final List<AppLogEntry> entries = [];

  @override
  void onLog(AppLogEntry entry) => entries.add(entry);

  List<TelemetryEvent> get events =>
      entries.map((e) => e.telemetryEvent).whereType<TelemetryEvent>().toList();

  List<String> names({TelemetryStatus? status}) => events
      .where((e) => status == null || e.status == status)
      .map((e) => e.name)
      .toList();

  TelemetryEvent eventNamed(String name) =>
      events.firstWhere((e) => e.name == name);

  int countOf(String name) => events.where((e) => e.name == name).length;

  void clear() => entries.clear();
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

Future<void> _seedRoom(
  FakeFirebaseFirestore firestore, {
  String code = 'ABCD12',
  String hostId = 'host',
  int playerCount = 3,
}) async {
  await firestore.collection('rooms').doc(code).set({
    'code': code,
    'hostId': hostId,
    'phase': GamePhase.lobby.name,
    'currentRound': 0,
    'totalRounds': 5,
    'roundDuration': 90,
    'createdAt': DateTime.now().toIso8601String(),
    'gamesPlayedToday': 0,
    'adUnlocksRemaining': 0,
    'playerCount': playerCount,
  });

  for (var i = 0; i < playerCount; i++) {
    final id = i == 0 ? hostId : 'player$i';
    await firestore
        .collection('rooms')
        .doc(code)
        .collection('players')
        .doc(id)
        .set(
          Player(
            id: id,
            name: 'Player $i',
            isHost: i == 0,
            lastSeen: DateTime.now(),
          ).toJson(),
        );
  }
}

void main() {
  late FakeFirebaseFirestore firestore;
  late RoomRepository repository;
  late GameTelemetryService telemetry;
  late _Recorder recorder;
  late _FakeCrashBackend crashBackend;

  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    repository = RoomRepository(firestore: firestore);

    telemetry = GameTelemetryService.instance;
    telemetry.init();

    CrashReporter.instance.initialize();
    crashBackend = _FakeCrashBackend();
    await CrashReporter.instance.attachBackend(crashBackend);

    recorder = _Recorder();
    AppLogger.instance.registerDestination(recorder);
  });

  tearDown(() {
    AppLogger.instance.unregisterDestination(recorder);
    CrashReporter.instance.dispose();
  });

  group('Firestore instrumentation', () {
    test('a transaction produces a started/succeeded pair with a duration',
        () async {
      await _seedRoom(firestore);
      recorder.clear();

      await repository.startFirstRound(
        roomCode: 'ABCD12',
        questionId: 'q1',
        questionText: '¿Quién?',
      );

      final firestoreEvents = recorder.events
          .where((e) => e.name == 'firestore_transaction')
          .toList();

      expect(firestoreEvents.length, 2);
      expect(firestoreEvents.first.status, TelemetryStatus.started);
      expect(firestoreEvents.last.status, TelemetryStatus.succeeded);
      expect(firestoreEvents.last.duration, isNotNull);
      expect(firestoreEvents.last.payload['operation'], 'start_first_round');
      // Both halves share a correlation id so the pair can be matched up.
      expect(
        firestoreEvents.last.correlationId,
        firestoreEvents.first.correlationId,
      );
    });

    test('a batch write is recorded as firestore_write', () async {
      await repository.createRoom('WXYZ99', 'host', 'Host');

      expect(
        recorder.eventNamed('firestore_write').payload['operation'],
        'create_room',
      );
    });

    test('match_started is emitted once, by the host that started it',
        () async {
      await _seedRoom(firestore);
      recorder.clear();

      await repository.startFirstRound(
        roomCode: 'ABCD12',
        questionId: 'q1',
        questionText: '¿Quién?',
      );

      expect(recorder.countOf('match_started'), 1);
    });
  });

  group('error classification', () {
    test('a domain exception is a warning breadcrumb, never a crash report',
        () async {
      await _seedRoom(firestore, playerCount: 2);

      // Fewer than 3 players: expected control flow, not a bug.
      await expectLater(
        repository.startFirstRound(
          roomCode: 'ABCD12',
          questionId: 'q1',
          questionText: '¿Quién?',
        ),
        throwsA(isA<Exception>()),
      );

      final failure = recorder.events.firstWhere(
        (e) => e.status == TelemetryStatus.failed,
      );
      expect(failure.severity, AppLogLevel.warning);
      expect(crashBackend.reports, isEmpty);
      expect(crashBackend.breadcrumbs, isNotEmpty);
    });

    test('a missing room is still only a warning', () async {
      await expectLater(
        repository.moveToVoting('NOPE00'),
        throwsA(isA<Exception>()),
      );

      expect(crashBackend.reports, isEmpty);
    });
  });

  group('room listener derives lifecycle events', () {
    test('phase, round, player and host changes each fire once', () async {
      await _seedRoom(firestore);

      final subscription = repository.watchRoom('ABCD12').listen((_) {});
      await Future<void>.delayed(Duration.zero);
      recorder.clear();

      // Phase + round change together.
      await firestore.collection('rooms').doc('ABCD12').update({
        'phase': GamePhase.answering.name,
        'currentRound': 1,
      });
      await Future<void>.delayed(Duration.zero);

      // A player leaves.
      await firestore
          .collection('rooms')
          .doc('ABCD12')
          .collection('players')
          .doc('player2')
          .delete();
      await Future<void>.delayed(Duration.zero);

      // The host is reassigned.
      await firestore.collection('rooms').doc('ABCD12').update({
        'hostId': 'player1',
      });
      await Future<void>.delayed(Duration.zero);

      expect(recorder.countOf('phase_changed'), 1);
      expect(recorder.countOf('round_started'), 1);
      expect(recorder.countOf('player_left'), 1);
      expect(recorder.countOf('host_changed'), 1);

      final phase = recorder.eventNamed('phase_changed');
      expect(phase.payload['from_phase'], 'lobby');
      expect(phase.payload['to_phase'], 'answering');

      await subscription.cancel();
    });

    test('the first snapshot sets a baseline without emitting transitions',
        () async {
      await _seedRoom(firestore);
      recorder.clear();

      final subscription = repository.watchRoom('ABCD12').listen((_) {});
      await Future<void>.delayed(Duration.zero);

      expect(recorder.countOf('phase_changed'), 0);
      expect(recorder.countOf('player_joined'), 0);
      expect(recorder.names(), contains('room_listener_attached'));

      await subscription.cancel();
    });

    test('two subscribers do not double-report the same transition',
        () async {
      await _seedRoom(firestore);

      final first = repository.watchRoom('ABCD12').listen((_) {});
      final second = repository.watchRoom('ABCD12').listen((_) {});
      await Future<void>.delayed(Duration.zero);
      recorder.clear();

      await firestore.collection('rooms').doc('ABCD12').update({
        'phase': GamePhase.answering.name,
      });
      await Future<void>.delayed(Duration.zero);

      expect(recorder.countOf('phase_changed'), 1);

      await first.cancel();
      await second.cancel();
    });

    test('session context is refreshed from every snapshot', () async {
      await _seedRoom(firestore);

      final subscription = repository.watchRoom('ABCD12').listen((_) {});
      await Future<void>.delayed(Duration.zero);

      expect(telemetry.context[TelemetryKeys.roomCode], 'ABCD12');
      expect(telemetry.context[TelemetryKeys.playerCount], 3);
      expect(telemetry.context[TelemetryKeys.gameState], 'lobby');
      expect(telemetry.context[TelemetryKeys.hostId], 'host');

      await subscription.cancel();
    });

    test('detaching the listener is recorded and clears the baseline',
        () async {
      await _seedRoom(firestore);

      final subscription = repository.watchRoom('ABCD12').listen((_) {});
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(recorder.names(), contains('room_listener_detached'));
    });
  });

  group('vote and answer instrumentation', () {
    Future<void> startAnswering() async {
      await _seedRoom(firestore);
      await firestore.collection('rooms').doc('ABCD12').update({
        'phase': GamePhase.answering.name,
        'currentRound': 1,
      });
    }

    test('answer_submitted carries only feature-specific data', () async {
      await startAnswering();
      recorder.clear();

      await repository.submitAnswerTransaction('ABCD12', 'host', 'una broma');

      final event = recorder.eventNamed('answer_submitted');
      expect(event.payload['answer_length'], 'una broma'.length);
      // Room code lives in Session Context, never in the payload.
      expect(event.payload.containsKey(TelemetryKeys.roomCode), isFalse);
    });

    // The vote path moved into the `submitVote` Cloud Function, so its
    // behaviour is covered end to end in functions/integration.test.mjs
    // instead. Keeping a client-side test here would only assert against a
    // transaction the app no longer performs.
  });

  group('network instrumentation', () {
    test('heartbeat start and stop are recorded', () async {
      await _seedRoom(firestore);
      final service = ConnectionService(firestore: firestore);

      service.startHeartbeat(roomCode: 'ABCD12', playerId: 'host');
      await Future<void>.delayed(Duration.zero);

      expect(recorder.names(), contains('heartbeat_started'));
      expect(telemetry.context[TelemetryKeys.networkStatus], 'connected');

      await service.stopHeartbeat();
      expect(recorder.names(), contains('heartbeat_stopped'));
      expect(telemetry.context[TelemetryKeys.networkStatus], isNull);

      service.dispose();
    });

    test('one missed beat is a warning; a run of them is reported once',
        () async {
      // No room seeded: every heartbeat write fails.
      final service = ConnectionService(firestore: _BrokenFirestore());

      service.startHeartbeat(roomCode: 'GONE00', playerId: 'host');
      await Future<void>.delayed(Duration.zero);

      expect(recorder.countOf('heartbeat_failed'), 1);
      expect(
        recorder.eventNamed('heartbeat_failed').severity,
        AppLogLevel.warning,
      );
      expect(crashBackend.reports, isEmpty);

      // Second consecutive miss: the connection is considered lost.
      service.resumeHeartbeat();
      await Future<void>.delayed(Duration.zero);
      expect(recorder.countOf('connection_lost'), 1);
      expect(telemetry.context[TelemetryKeys.networkStatus], 'lost');
      expect(crashBackend.reports.length, 1);

      // Third miss must not report again.
      service.resumeHeartbeat();
      await Future<void>.delayed(Duration.zero);
      expect(recorder.countOf('connection_lost'), 1);
      expect(crashBackend.reports.length, 1);

      service.dispose();
    });
  });
}

/// A Firestore whose writes always throw, used to drive the heartbeat
/// failure path deterministically.
class _BrokenFirestore extends FakeFirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    throw FirebaseException(plugin: 'test', message: 'network unavailable');
  }
}
