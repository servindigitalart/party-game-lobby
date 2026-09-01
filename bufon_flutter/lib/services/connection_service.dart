// services/connection_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import '../core/logging/log_category.dart';
import '../core/logging/log_level.dart';
import '../core/telemetry/game_telemetry_service.dart';
import '../core/telemetry/telemetry_context.dart';
import '../core/telemetry/telemetry_event.dart';

/// Service responsible for maintaining player connection heartbeat
///
/// Updates player's lastSeen timestamp every 10 seconds to indicate
/// they are still active in the game. Automatically stops when app
/// goes to background and resumes when foregrounded.
///
/// ## Instrumentation
///
/// The heartbeat is the only continuous signal about this device's
/// connectivity, so it is where connection loss and recovery are detected.
/// A single failed beat is normal on mobile and is recorded as a warning; a
/// run of them means the player is actually disconnected and is escalated
/// once, so a flapping network cannot spam crash reports.
class ConnectionService {
  /// Consecutive failed beats before the connection is considered lost.
  /// Two misses is 20s, the same window `cleanupDisconnectedPlayers` uses to
  /// evict a player, so the two views of "disconnected" agree.
  static const int _lostAfterConsecutiveFailures = 2;

  final FirebaseFirestore? _injectedFirestore;
  final GameTelemetryService _telemetry = GameTelemetryService.instance;
  Timer? _heartbeatTimer;
  String? _currentRoomCode;
  String? _currentPlayerId;
  bool _isActive = false;
  int _consecutiveFailures = 0;
  bool _isConnectionLost = false;
  _AppLifecycleObserver? _lifecycleObserver;

  /// Whether the heartbeat is currently considered lost.
  ///
  /// WP25 / **R-37**, BP **P4**. This service has run since launch with **no
  /// UI at all** — the Blueprint's component table records it as
  /// *"Heartbeat only, no UI"* — so a player whose beats were failing had no
  /// way to know, and the confusion behind audit A **H-2** had no explanation
  /// on screen.
  ///
  /// A `ValueNotifier` rather than a stream or a provider: R-37's non-goals
  /// are *"no new dependency; no new service"*, and this is the smallest
  /// thing a widget can already listen to. It mirrors `_isConnectionLost`
  /// exactly — the same two-consecutive-failure definition, which is itself
  /// matched to `cleanupDisconnectedPlayers`' 20 s window — so it introduces
  /// no second opinion about what "disconnected" means.
  final ValueNotifier<bool> connectionLost = ValueNotifier<bool>(false);

  ConnectionService({FirebaseFirestore? firestore})
    : _injectedFirestore = firestore;

  /// Resolved lazily, for the same reason `RoomRepository` resolves
  /// `FirebaseFunctions` lazily and says so: *"`FirebaseFunctions.instance`
  /// throws until `Firebase.initializeApp` has run, and this repository is
  /// constructed by a provider that may be read earlier — and by tests that
  /// never start Firebase at all."*
  ///
  /// WP25 made that true of this service too. `ConnectionBanner` (R-37) reads
  /// `connectionServiceProvider` to watch [connectionLost], and constructing
  /// the service for a widget must not require a Firestore handle the widget
  /// will never use. Production is unaffected: `Firebase.initializeApp` runs
  /// in `main` long before any room screen is built.
  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  /// Start heartbeat for a player in a room
  ///
  /// Updates player's lastSeen every 10 seconds
  /// Sets isOnline = true
  void startHeartbeat({required String roomCode, required String playerId}) {
    // Tear the previous timer down synchronously.
    //
    // This used to call stopHeartbeat(), which is async: it suspended on
    // `await _markOffline()` and resumed *after* this method had already
    // stored the new room, setting _currentRoomCode back to null and
    // _isActive back to false. Every subsequent beat then returned early, so
    // the heartbeat was permanently dead and players were evicted by the
    // 20s timeout. Found by the telemetry added in this phase.
    //
    // The previous room's `isOnline: false` is not written here; that room's
    // player is evicted by the same timeout anyway.
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _currentRoomCode = roomCode;
    _currentPlayerId = playerId;
    _isActive = true;
    _consecutiveFailures = 0;
    _setConnectionLost(false);

    _telemetry.updateContext({TelemetryKeys.networkStatus: 'connected'});
    _telemetry.track(AppLogCategory.network, 'heartbeat_started');

    // Send immediate heartbeat
    _sendHeartbeat();

    // Set up periodic heartbeat (every 10 seconds)
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _sendHeartbeat(),
    );

    // Listen to app lifecycle changes (register once, reuse on subsequent
    // startHeartbeat calls to avoid accumulating observers on reconnect).
    if (_lifecycleObserver == null) {
      _lifecycleObserver = _AppLifecycleObserver(
        onPause: pauseHeartbeat,
        onResume: resumeHeartbeat,
      );
      WidgetsBinding.instance.addObserver(_lifecycleObserver!);
    }
  }

  /// Send heartbeat to update lastSeen timestamp
  Future<void> _sendHeartbeat() async {
    if (!_isActive || _currentRoomCode == null || _currentPlayerId == null) {
      return;
    }

    try {
      final playerRef = _firestore
          .collection('rooms')
          .doc(_currentRoomCode)
          .collection('players')
          .doc(_currentPlayerId);

      await playerRef.update({
        'lastSeen': DateTime.now().toIso8601String(),
        'isOnline': true,
      });

      _onHeartbeatSucceeded();
    } catch (e, stackTrace) {
      _onHeartbeatFailed(e, stackTrace);
    }
  }

  /// Keeps [connectionLost] in step with `_isConnectionLost`. Every write to
  /// that flag goes through here so the two cannot drift.
  void _setConnectionLost(bool lost) {
    _isConnectionLost = lost;
    connectionLost.value = lost;
  }

  void _onHeartbeatSucceeded() {
    if (!_isConnectionLost) {
      _consecutiveFailures = 0;
      return;
    }

    // The beat got through again: the player is back.
    final missedBeats = _consecutiveFailures;
    _consecutiveFailures = 0;
    _setConnectionLost(false);

    _telemetry.updateContext({TelemetryKeys.networkStatus: 'connected'});
    _telemetry.track(
      AppLogCategory.network,
      'connection_restored',
      payload: {'missed_beats': missedBeats},
    );
  }

  void _onHeartbeatFailed(Object error, StackTrace stackTrace) {
    _consecutiveFailures++;

    // A single missed beat is ordinary on mobile: breadcrumb, no report.
    if (_consecutiveFailures < _lostAfterConsecutiveFailures) {
      _telemetry.fail(
        AppLogCategory.network,
        'heartbeat_failed',
        error: error,
        stackTrace: stackTrace,
        severity: AppLogLevel.warning,
        status: TelemetryStatus.retried,
        payload: {'consecutive_failures': _consecutiveFailures},
      );
      return;
    }

    // Escalate once per outage, not once per beat, so a flapping network
    // cannot flood crash reporting.
    if (_isConnectionLost) return;
    _setConnectionLost(true);

    _telemetry.updateContext({TelemetryKeys.networkStatus: 'lost'});
    _telemetry.fail(
      AppLogCategory.network,
      'connection_lost',
      error: error,
      stackTrace: stackTrace,
      payload: {'consecutive_failures': _consecutiveFailures},
    );
  }

  /// Pause heartbeat (when app goes to background)
  void pauseHeartbeat() {
    final wasActive = _isActive;
    _isActive = false;
    _heartbeatTimer?.cancel();

    // `app_backgrounded` belongs to AppSessionObserver, which sees the
    // lifecycle whether or not the player is in a room. Only the network
    // status is this service's to report.
    if (wasActive) {
      _telemetry.updateContext({TelemetryKeys.networkStatus: 'backgrounded'});
    }

    _markOffline();
  }

  /// Resume heartbeat (when app comes to foreground)
  void resumeHeartbeat() {
    if (_currentRoomCode != null && _currentPlayerId != null) {
      _isActive = true;
      _sendHeartbeat();
      _heartbeatTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _sendHeartbeat(),
      );
    }
  }

  /// Stop heartbeat completely and mark player offline
  Future<void> stopHeartbeat() async {
    final wasRunning = _currentRoomCode != null;
    _isActive = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    await _markOffline();

    _currentRoomCode = null;
    _currentPlayerId = null;
    _consecutiveFailures = 0;
    _setConnectionLost(false);

    if (wasRunning) {
      _telemetry.track(AppLogCategory.network, 'heartbeat_stopped');
      _telemetry.clearContext([TelemetryKeys.networkStatus]);
    }
  }

  /// Mark current player as offline
  Future<void> _markOffline() async {
    if (_currentRoomCode == null || _currentPlayerId == null) return;

    try {
      final playerRef = _firestore
          .collection('rooms')
          .doc(_currentRoomCode)
          .collection('players')
          .doc(_currentPlayerId);

      await playerRef.update({'isOnline': false});
    } catch (e, stackTrace) {
      // Best effort: the heartbeat timeout evicts the player anyway.
      _telemetry.fail(
        AppLogCategory.network,
        'mark_offline_failed',
        error: e,
        stackTrace: stackTrace,
        severity: AppLogLevel.warning,
      );
    }
  }

  /// Dispose and cleanup
  void dispose() {
    // `stopHeartbeat` is async and resets [connectionLost] in its tail, so
    // the notifier can only be disposed once that has finished — disposing it
    // alongside the call left the reset writing to a dead notifier.
    stopHeartbeat().whenComplete(connectionLost.dispose);
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
      _lifecycleObserver = null;
    }
  }
}

/// App lifecycle observer for connection service
class _AppLifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback onPause;
  final VoidCallback onResume;

  _AppLifecycleObserver({required this.onPause, required this.onResume});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        onPause();
        break;
      case AppLifecycleState.resumed:
        onResume();
        break;

      // WP25 / **R-12**, audit A **H-2**. `inactive` used to pause the
      // heartbeat, and on iOS it fires for Control Centre, the app switcher
      // and a notification banner — transient interruptions where the app is
      // still in the foreground and the player has not gone anywhere.
      // Pausing there stopped the beats, and two missed beats is the 20 s
      // window `cleanupDisconnectedPlayers` evicts on, so pulling down
      // Control Centre could cost a reviewer their own room.
      //
      // This is not a new judgement about the lifecycle: `AppSessionObserver`
      // already made it, and says so in its own words — *"`inactive` fires
      // for transient interruptions … and closing a session there would
      // shred the metric into fragments."* Two observers on the same event
      // disagreed; now they do not.
      //
      // **Genuine disconnect detection is unchanged.** A real backgrounding
      // still delivers `paused` (and `hidden` on newer Flutter), both of
      // which still pause. The 20 s window, the eviction sweep and WP22's
      // eligibility filtering are untouched — WP25's stop condition asks for
      // exactly that guarantee.
      case AppLifecycleState.inactive:
        break;
    }
  }
}
