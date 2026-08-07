// core/crash/crash_backend.dart

import 'package:flutter/foundation.dart';

import '../logging/log_category.dart';
import '../logging/log_level.dart';

/// A single error handed to a crash backend.
///
/// Modelled as an object rather than a parameter list so that a new field
/// (fingerprint, feature flags, attachment) never changes [CrashBackend]'s
/// signature and therefore never breaks an existing backend.
@immutable
class CrashReport {
  const CrashReport({
    required this.error,
    required this.category,
    required this.severity,
    required this.timestamp,
    this.stackTrace,
    this.reason,
  });

  final Object error;
  final StackTrace? stackTrace;

  /// Functional area the failure belongs to
  /// (docs/engineering/CRASHLYTICS.md — "Categorization").
  final AppLogCategory category;

  /// Reuses [AppLogLevel] rather than a parallel severity enum. The
  /// specification's Critical / Major / Minor / Informational map onto
  /// fatal+critical / error / warning / info.
  final AppLogLevel severity;

  /// Whether the application could not continue. Fatal reports come from
  /// the zone and platform handlers; everything else is recoverable
  /// (docs/engineering/CRASHLYTICS.md — "Error Types").
  ///
  /// Derived from [severity] rather than stored alongside it: two fields
  /// for one fact allowed incoherent reports — fatal but labelled minor.
  bool get isFatal => severity == AppLogLevel.fatal;

  /// Short human explanation of what was being attempted.
  final String? reason;

  final DateTime timestamp;
}

/// Destination for crash reports.
///
/// [CrashReporter] talks only to this interface, so replacing Firebase
/// Crashlytics with Sentry, Bugsnag or Datadog is a new implementation of
/// these six methods and one line in `main.dart` — no gameplay code and no
/// change to CrashReporter's public API.
///
/// Every method returns `void` on purpose: crash reporting is passive and
/// must never make a caller wait or fail
/// (docs/telemetry/TELEMETRY_SPEC.md — "Failure Strategy").
abstract class CrashBackend {
  /// Prepares the backend. Called once, after its underlying SDK is ready.
  Future<void> initialize();

  /// Records one error.
  void report(CrashReport report);

  /// Appends a breadcrumb to the trail attached to the next report.
  void leaveBreadcrumb(String message);

  /// Sets a key attached to every subsequent report, including native
  /// crashes the Dart layer never sees.
  void setCustomKey(String key, Object value);

  void removeCustomKey(String key);

  /// Associates reports with a user. `null` clears the association.
  void setUser(String? identifier);
}
