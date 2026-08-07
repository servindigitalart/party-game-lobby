// analytics/retention_tracker.dart

import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging/log_category.dart';
import '../core/telemetry/game_telemetry_service.dart';

/// Stateful retention bookkeeping over local storage.
///
/// This is all that survives of the old `AnalyticsService`. Everything else
/// it did — gameplay, progression, seasons, titles, leaderboards, ads,
/// purchases, screen views, crash reporting — is emitted as telemetry by the
/// feature that owns it and forwarded by `AnalyticsDestination`.
///
/// What remains cannot be derived from telemetry: how long ago the app was
/// installed, how many times it has been opened, and how long since the last
/// launch are facts about *previous* runs of the process, so they need a
/// local store. The class keeps that store and nothing else; it does not
/// know Firebase exists.
class RetentionTracker {
  RetentionTracker._internal();
  static final RetentionTracker instance = RetentionTracker._internal();

  static const String _installKey = 'first_install_time';
  static const String _sessionsKey = 'total_sessions';
  static const String _lastLaunchKey = 'last_session_start';

  final GameTelemetryService _telemetry = GameTelemetryService.instance;

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Returns this launch's retention metrics and records any return window
  /// that was crossed.
  ///
  /// The caller attaches the result to the `app_started` telemetry event, so
  /// one launch produces one analytics event instead of the separate
  /// `app_open` this class used to send alongside it.
  Future<Map<String, dynamic>> readLaunchMetrics() async {
    final prefs = _prefs;
    if (prefs == null) return const {};

    final now = DateTime.now();
    final daysSinceInstall = _daysSinceInstall(prefs, now);
    final totalSessions = (prefs.getInt(_sessionsKey) ?? 0) + 1;
    await prefs.setInt(_sessionsKey, totalSessions);

    _recordReturnWindow(prefs, now);
    await prefs.setInt(_lastLaunchKey, now.millisecondsSinceEpoch);

    return {
      'days_since_install': daysSinceInstall,
      'total_sessions': totalSessions,
      'time_of_day': _timeOfDay(now),
      'is_first_session': totalSessions <= 1,
    };
  }

  int _daysSinceInstall(SharedPreferences prefs, DateTime now) {
    final installed = prefs.getInt(_installKey);
    if (installed == null) {
      prefs.setInt(_installKey, now.millisecondsSinceEpoch);
      return 0;
    }
    return now
        .difference(DateTime.fromMillisecondsSinceEpoch(installed))
        .inDays;
  }

  String _timeOfDay(DateTime now) {
    if (now.hour >= 5 && now.hour < 12) return 'morning';
    if (now.hour >= 12 && now.hour < 17) return 'afternoon';
    if (now.hour >= 17 && now.hour < 21) return 'evening';
    return 'night';
  }

  void _recordReturnWindow(SharedPreferences prefs, DateTime now) {
    final lastLaunch = prefs.getInt(_lastLaunchKey);
    if (lastLaunch == null) return;

    final since = now.difference(
      DateTime.fromMillisecondsSinceEpoch(lastLaunch),
    );

    if (since.inDays >= 7) {
      _track('returned_after_week', {'days_since_last_session': since.inDays});
    } else if (since.inDays == 1) {
      _track('returned_next_day', {'hours_since_last_session': since.inHours});
    } else if (since.inDays == 0 && since.inHours >= 1) {
      _track('returned_same_day', {'hours_since_last_session': since.inHours});
    }
  }

  void _track(String name, Map<String, dynamic> payload) {
    _telemetry.track(AppLogCategory.app, name, payload: payload);
  }
}
