// core/logging/talker_log_destination.dart

import 'package:talker/talker.dart';

import 'app_log_destination.dart';
import 'app_log_entry.dart';
import 'log_category.dart';
import 'log_level.dart';

/// Built-in destination that forwards log entries to [Talker].
///
/// This is the only class in the codebase that talks to Talker directly.
/// Every other destination, and the rest of the application, only ever
/// sees [AppLogger]'s public API.
class TalkerLogDestination implements AppLogDestination {
  TalkerLogDestination()
    : _talker = Talker(
        settings: TalkerSettings(
          timeFormat: TimeFormat.timeAndSeconds,
          titles: const {'fatal': 'FATAL'},
          colors: {'fatal': AnsiPen()..red(bold: true)},
        ),
      );

  final Talker _talker;

  @override
  void onLog(AppLogEntry entry) {
    final formatted = _format(entry);

    switch (entry.level) {
      case AppLogLevel.trace:
        _talker.verbose(formatted);
        break;
      case AppLogLevel.debug:
        _talker.debug(formatted);
        break;
      case AppLogLevel.info:
        _talker.info(formatted);
        break;
      case AppLogLevel.warning:
        _talker.warning(formatted, entry.error, entry.stackTrace);
        break;
      case AppLogLevel.error:
        _talker.error(formatted, entry.error, entry.stackTrace);
        break;
      case AppLogLevel.critical:
        _talker.critical(formatted, entry.error, entry.stackTrace);
        break;
      case AppLogLevel.fatal:
        _talker.logCustom(
          TalkerLog(
            formatted,
            key: 'fatal',
            title: 'FATAL',
            logLevel: LogLevel.critical,
            exception: entry.error,
            stackTrace: entry.stackTrace,
          ),
        );
        break;
    }
  }

  String _format(AppLogEntry entry) {
    final label = entry.category.label;
    if (entry.context.isEmpty) return '[$label] ${entry.message}';
    final contextString = entry.context.entries
        .map((e) => '${e.key}=${e.value}')
        .join(' ');
    return '[$label] ${entry.message} | $contextString';
  }
}
