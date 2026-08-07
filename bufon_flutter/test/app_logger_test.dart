import 'package:bufon_flutter/core/logging/app_log_destination.dart';
import 'package:bufon_flutter/core/logging/app_log_entry.dart';
import 'package:bufon_flutter/core/logging/app_logger.dart';
import 'package:bufon_flutter/core/logging/log_category.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingDestination implements AppLogDestination {
  final List<AppLogEntry> entries = [];

  @override
  void onLog(AppLogEntry entry) => entries.add(entry);

  AppLogEntry get last => entries.last;
}

void main() {
  late AppLogger logger;
  late _RecordingDestination destination;

  setUp(() {
    logger = AppLogger.instance;
    destination = _RecordingDestination();
    logger.registerDestination(destination);
  });

  tearDown(() {
    logger.unregisterDestination(destination);
    logger.detachContextProvider();
  });

  test('context from every attached provider is merged', () {
    logger.attachContextProvider(() => {'session_id': 'abc'});
    logger.attachContextProvider(() => {'player_id': 'p1'});
    logger.attachContextProvider(() => {'platform': 'ios'});

    logger.info(AppLogCategory.room, 'room_created');

    expect(destination.last.context, {
      'session_id': 'abc',
      'player_id': 'p1',
      'platform': 'ios',
    });
  });

  test('a later provider overrides an earlier one on a shared key', () {
    logger.attachContextProvider(() => {'screen': 'home'});
    logger.attachContextProvider(() => {'screen': 'lobby'});

    logger.info(AppLogCategory.navigation, 'screen_changed');

    expect(destination.last.context['screen'], 'lobby');
  });

  test('explicit call context still overrides every provider', () {
    logger.attachContextProvider(() => {'room_code': 'AAAA11'});

    logger.info(
      AppLogCategory.room,
      'room_joined',
      context: {'room_code': 'BBBB22'},
    );

    expect(destination.last.context['room_code'], 'BBBB22');
  });

  test('a throwing provider is skipped without blinding the others', () {
    logger.attachContextProvider(() => {'session_id': 'abc'});
    logger.attachContextProvider(() => throw StateError('not ready'));
    logger.attachContextProvider(() => {'platform': 'ios'});

    expect(
      () => logger.info(AppLogCategory.room, 'room_created'),
      returnsNormally,
    );
    expect(destination.last.context, {
      'session_id': 'abc',
      'platform': 'ios',
    });
  });

  test('detach removes one provider, or all when called bare', () {
    Map<String, dynamic> auth() => {'player_id': 'p1'};
    logger.attachContextProvider(auth);
    logger.attachContextProvider(() => {'platform': 'ios'});

    logger.detachContextProvider(auth);
    logger.info(AppLogCategory.room, 'room_created');
    expect(destination.last.context, {'platform': 'ios'});

    logger.detachContextProvider();
    logger.info(AppLogCategory.room, 'room_created');
    expect(destination.last.context, isEmpty);
  });
}
