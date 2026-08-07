import 'package:bufon_flutter/core/logging/app_log_destination.dart';
import 'package:bufon_flutter/core/logging/app_log_entry.dart';
import 'package:bufon_flutter/core/logging/app_logger.dart';
import 'package:bufon_flutter/core/logging/log_category.dart';
import 'package:bufon_flutter/core/logging/log_level.dart';
import 'package:bufon_flutter/core/telemetry/game_telemetry_service.dart';
import 'package:bufon_flutter/core/telemetry/telemetry_context.dart';
import 'package:bufon_flutter/core/telemetry/telemetry_event.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stand-in for a future CrashReporter / Analytics / Debug Overlay
/// destination: it only implements [AppLogDestination] and reads the typed
/// event back off the entry.
class _RecordingDestination implements AppLogDestination {
  final List<AppLogEntry> entries = [];

  @override
  void onLog(AppLogEntry entry) => entries.add(entry);

  List<TelemetryEvent> get events =>
      entries.map((e) => e.telemetryEvent).whereType<TelemetryEvent>().toList();

  void clear() => entries.clear();
}

void main() {
  late GameTelemetryService telemetry;
  late _RecordingDestination destination;

  setUp(() {
    telemetry = GameTelemetryService.instance;
    telemetry.init();
    destination = _RecordingDestination();
    AppLogger.instance.registerDestination(destination);
  });

  tearDown(() {
    AppLogger.instance.unregisterDestination(destination);
    telemetry.endSession();
  });

  test('track emits exactly one event that reaches destinations', () {
    telemetry.track(AppLogCategory.room, 'room_created');

    expect(destination.events.length, 1);
    expect(destination.events.single.name, 'room_created');
    expect(destination.entries.single.category, AppLogCategory.room);
  });

  test('session context is attached without call sites repeating it', () {
    final sessionId = telemetry.startSession();
    telemetry.updateContext({TelemetryKeys.roomCode: 'ABCD12'});
    destination.clear();

    telemetry.track(AppLogCategory.gameplay, 'match_started');

    final entry = destination.entries.single;
    expect(entry.context[TelemetryKeys.sessionId], sessionId);
    expect(entry.context[TelemetryKeys.roomCode], 'ABCD12');
    expect(entry.context[TelemetryKeys.platform], isNotNull);
  });

  test('clearContext drops a key from later events', () {
    telemetry.updateContext({TelemetryKeys.roomCode: 'ABCD12'});
    telemetry.clearContext([TelemetryKeys.roomCode]);
    destination.clear();

    telemetry.track(AppLogCategory.room, 'room_left');

    expect(destination.entries.single.context[TelemetryKeys.roomCode], isNull);
  });

  test('start/finish share a correlation id and carry a duration', () {
    final operation = telemetry.start(AppLogCategory.room, 'room_created');
    operation.finish(payload: {'attempts': 2});

    final events = destination.events;
    expect(events.length, 2);
    expect(events.first.status, TelemetryStatus.started);
    expect(events.last.status, TelemetryStatus.succeeded);
    expect(events.last.correlationId, events.first.correlationId);
    expect(events.last.duration, isNotNull);
    expect(events.last.payload['attempts'], 2);
  });

  test('an operation closes only once', () {
    final operation = telemetry.start(AppLogCategory.room, 'room_created');
    operation.finish();
    operation.finish();
    operation.fail(Exception('late'));

    expect(destination.events.length, 2);
    expect(operation.isClosed, isTrue);
  });

  test('fail records error severity and keeps the error object', () {
    final error = Exception('firestore unavailable');
    telemetry.fail(AppLogCategory.room, 'room_created', error: error);

    final entry = destination.entries.single;
    expect(entry.level, AppLogLevel.error);
    expect(entry.error, error);
    expect(entry.telemetryEvent!.status, TelemetryStatus.failed);
  });

  test('transition records the screen change and updates context', () {
    telemetry.transition('home');
    destination.clear();

    telemetry.transition('lobby');

    final event = destination.events.single;
    expect(event.name, 'screen_changed');
    expect(event.category, AppLogCategory.navigation);
    expect(event.payload[TelemetryKeys.fromScreen], 'home');
    expect(event.payload[TelemetryKeys.toScreen], 'lobby');
    expect(telemetry.context[TelemetryKeys.screen], 'lobby');
  });

  test('a throwing destination never breaks telemetry', () {
    final broken = _ThrowingDestination();
    AppLogger.instance.registerDestination(broken);
    addTearDown(() => AppLogger.instance.unregisterDestination(broken));

    expect(
      () => telemetry.track(AppLogCategory.room, 'room_created'),
      returnsNormally,
    );
    expect(destination.events.length, 1);
  });
}

class _ThrowingDestination implements AppLogDestination {
  @override
  void onLog(AppLogEntry entry) => throw StateError('destination is down');
}
