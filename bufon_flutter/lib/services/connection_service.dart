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

  final FirebaseFirestore _firestore;
  final GameTelemetryService _telemetry = GameTelemetryService.instance;
  Timer? _heartbeatTimer;
  String? _currentRoomCode;
  String? _currentPlayerId;
  bool _isActive = false;
  int _consecutiveFailures = 0;
  bool _isConnectionLost = false;
  _AppLifecycleObserver? _lifecycleObserver;

  ConnectionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

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
    _isConnectionLost = false;

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

  void _onHeartbeatSucceeded() {
    if (!_isConnectionLost) {
      _consecutiveFailures = 0;
      return;
    }

    // The beat got through again: the player is back.
    final missedBeats = _consecutiveFailures;
    _consecutiveFailures = 0;
    _isConnectionLost = false;

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
    _isConnectionLost = true;

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

    if (wasActive) {
      _telemetry.updateContext({TelemetryKeys.networkStatus: 'backgrounded'});
      _telemetry.track(AppLogCategory.app, 'app_backgrounded');
    }

    _markOffline();
  }

  /// Resume heartbeat (when app comes to foreground)
  void resumeHeartbeat() {
    if (_currentRoomCode != null && _currentPlayerId != null) {
      _isActive = true;
      _telemetry.track(AppLogCategory.app, 'app_resumed');
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
    _isConnectionLost = false;

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
    stopHeartbeat();
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
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        onPause();
        break;
      case AppLifecycleState.resumed:
        onResume();
        break;
      case AppLifecycleState.hidden:
        // New state in Flutter 3.13+, treat as paused
        onPause();
        break;
    }
  }
}
