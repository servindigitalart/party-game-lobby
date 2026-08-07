// core/crash/firebase_crashlytics_backend.dart

import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../logging/log_level.dart';
import 'crash_backend.dart';

/// Firebase Crashlytics implementation of [CrashBackend].
///
/// This is the only file in the application allowed to import
/// `firebase_crashlytics`. Swapping in Sentry, Bugsnag or Datadog means
/// writing a sibling of this class and changing the one line in `main.dart`
/// that constructs it.
///
/// Every call is fire-and-forget: Crashlytics returns futures, but a failure
/// to record must never surface to the caller
/// (docs/telemetry/TELEMETRY_SPEC.md — "Failure Strategy").
class FirebaseCrashlyticsBackend implements CrashBackend {
  FirebaseCrashlyticsBackend({FirebaseCrashlytics? crashlytics})
    : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  final FirebaseCrashlytics _crashlytics;

  @override
  Future<void> initialize() async {
    // Debug builds would otherwise flood the console with noise from
    // errors the developer is actively looking at.
    await _crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
  }

  @override
  void report(CrashReport report) {
    unawaited(
      _crashlytics.recordError(
        report.error,
        report.stackTrace,
        reason: report.reason,
        fatal: report.isFatal,
        information: [
          'category: ${report.category.name}',
          'severity: ${_severityLabel(report.severity)}',
        ],
      ),
    );
  }

  @override
  void leaveBreadcrumb(String message) {
    unawaited(_crashlytics.log(message));
  }

  @override
  void setCustomKey(String key, Object value) {
    unawaited(_crashlytics.setCustomKey(key, value));
  }

  @override
  void removeCustomKey(String key) {
    // Crashlytics has no removal API; an empty value is the closest
    // equivalent and keeps a stale room code from outliving its room.
    unawaited(_crashlytics.setCustomKey(key, ''));
  }

  @override
  void setUser(String? identifier) {
    unawaited(_crashlytics.setUserIdentifier(identifier ?? ''));
  }

  /// Maps [AppLogLevel] onto the severity vocabulary the Firebase console
  /// is triaged with (docs/engineering/CRASHLYTICS.md — "Severity").
  String _severityLabel(AppLogLevel severity) {
    switch (severity) {
      case AppLogLevel.fatal:
      case AppLogLevel.critical:
        return 'critical';
      case AppLogLevel.error:
        return 'major';
      case AppLogLevel.warning:
        return 'minor';
      case AppLogLevel.info:
      case AppLogLevel.debug:
      case AppLogLevel.trace:
        return 'informational';
    }
  }
}
