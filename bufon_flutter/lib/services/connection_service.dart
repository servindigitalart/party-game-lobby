// services/connection_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import '../core/logging/app_logger.dart';
import '../core/logging/log_category.dart';

/// Service responsible for maintaining player connection heartbeat
///
/// Updates player's lastSeen timestamp every 10 seconds to indicate
/// they are still active in the game. Automatically stops when app
/// goes to background and resumes when foregrounded.
class ConnectionService {
  final FirebaseFirestore _firestore;
  Timer? _heartbeatTimer;
  String? _currentRoomCode;
  String? _currentPlayerId;
  bool _isActive = false;
  _AppLifecycleObserver? _lifecycleObserver;

  ConnectionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Start heartbeat for a player in a room
  ///
  /// Updates player's lastSeen every 10 seconds
  /// Sets isOnline = true
  void startHeartbeat({required String roomCode, required String playerId}) {
    // Stop existing heartbeat if any
    stopHeartbeat();

    _currentRoomCode = roomCode;
    _currentPlayerId = playerId;
    _isActive = true;

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
    } catch (e) {
      // Silently fail - heartbeat will retry in 10 seconds
      AppLogger.instance.warning(
        AppLogCategory.network,
        'Heartbeat failed',
        context: {'roomCode': _currentRoomCode, 'playerId': _currentPlayerId},
        error: e,
      );
    }
  }

  /// Pause heartbeat (when app goes to background)
  void pauseHeartbeat() {
    _isActive = false;
    _heartbeatTimer?.cancel();
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
    _isActive = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    await _markOffline();

    _currentRoomCode = null;
    _currentPlayerId = null;
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
    } catch (e) {
      AppLogger.instance.warning(
        AppLogCategory.network,
        'Failed to mark offline',
        context: {'roomCode': _currentRoomCode, 'playerId': _currentPlayerId},
        error: e,
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
