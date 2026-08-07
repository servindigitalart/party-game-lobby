// core/telemetry/app_session_observer.dart

import 'package:flutter/widgets.dart';

import '../logging/log_category.dart';
import 'game_telemetry_service.dart';
import 'telemetry_context.dart';

/// Ties the telemetry session to the application lifecycle.
///
/// A session is one **foreground period**: it opens when the app becomes
/// visible and closes when it leaves the foreground. That is what makes
/// session duration mean anything — measuring from launch to process death
/// would count hours of backgrounded time, and `detached` is not reliably
/// delivered on iOS, so sessions would simply never end.
///
/// This class only calls the existing telemetry API. It adds no state to
/// GameTelemetryService and no second path: `session_started` and
/// `session_ended` are the same events `startSession`/`endSession` have
/// always emitted.
///
/// `app_backgrounded` / `app_resumed` live here rather than in
/// ConnectionService, which only observes the lifecycle while the player is
/// inside a room. Here they fire once, always.
class AppSessionObserver with WidgetsBindingObserver {
  AppSessionObserver({GameTelemetryService? telemetry})
    : _telemetry = telemetry ?? GameTelemetryService.instance;

  final GameTelemetryService _telemetry;

  DateTime? _sessionStartedAt;

  /// True while a session is open. Guards against the duplicate
  /// `resumed` some platforms deliver right after launch.
  bool get hasActiveSession => _sessionStartedAt != null;

  /// Registers the observer and opens the first session.
  ///
  /// No `app_resumed` here: nothing was backgrounded yet, and `app_started`
  /// already marks the launch.
  void start() {
    WidgetsBinding.instance.addObserver(this);
    _openSession(isResume: false);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _closeSession();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _openSession(isResume: true);
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _closeSession();
      // `inactive` fires for transient interruptions — a notification
      // shade, an incoming call, the app switcher — and closing a session
      // there would shred the metric into fragments.
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _openSession({required bool isResume}) {
    if (hasActiveSession) return;
    _sessionStartedAt = DateTime.now();
    _telemetry.startSession();
    if (isResume) _telemetry.track(AppLogCategory.app, 'app_resumed');
  }

  void _closeSession() {
    final startedAt = _sessionStartedAt;
    if (startedAt == null) return;
    _sessionStartedAt = null;

    _telemetry.track(AppLogCategory.app, 'app_backgrounded');

    // Duration rides in Session Context so `session_ended` carries it
    // without changing GameTelemetryService's API. endSession() resets the
    // context to device keys straight after, so it cannot leak forward.
    _telemetry.updateContext({
      TelemetryKeys.sessionDurationSeconds: DateTime.now()
          .difference(startedAt)
          .inSeconds,
    });
    _telemetry.endSession();
  }
}
