// domain/controllers/monetization_controller.dart
import '../../services/local_storage_service.dart';
import '../../core/exceptions.dart';

/// Local (device-side) cache of monetization state, backed by
/// SharedPreferences via [LocalStorageService].
///
/// This is NOT the source of truth for whether a game can start —
/// that gate is enforced server-side in Firestore via
/// RoomRepository.canRoomStartGame, checked in GameController.startGame.
/// This controller exists only for potential local UI display (e.g. an
/// optimistic "games remaining" indicator) and is not currently wired
/// into any screen. It mirrors the same rules (3 free games/day, bonus
/// games, Night Pass) but its counters are device-local and can drift
/// from the authoritative per-room counters in Firestore.
class MonetizationController {
  static const int maxFreeGamesPerDay = 3;

  final LocalStorageService _storage;

  MonetizationController(this._storage);

  /// Check if user can play a game right now
  /// Returns true if allowed, throws MonetizationException if blocked
  Future<bool> canPlayGame() async {
    // Night Pass bypasses all limits
    if (_storage.hasActiveNightPass()) {
      return true;
    }

    // Check if we need to reset daily counter
    await _checkAndResetDailyCounter();

    // Check if we have bonus games
    final bonusGames = _storage.getBonusGames();
    if (bonusGames > 0) {
      return true;
    }

    // Check daily limit
    final gamesPlayed = _storage.getGamesPlayedToday();
    if (gamesPlayed >= maxFreeGamesPerDay) {
      throw MonetizationException(
        'Has alcanzado el límite de $maxFreeGamesPerDay partidas gratuitas hoy. '
        'Vuelve mañana o activa el Pase Nocturno para seguir jugando.',
        code: 'DAILY_LIMIT_REACHED',
      );
    }

    return true;
  }

  /// Register that a game was played
  /// Consumes bonus games first, then increments daily counter
  Future<void> registerGamePlayed() async {
    // Night Pass users don't consume anything
    if (_storage.hasActiveNightPass()) {
      return;
    }

    // Consume bonus game if available
    final bonusGames = _storage.getBonusGames();
    if (bonusGames > 0) {
      await _storage.consumeBonusGame();
      return;
    }

    // Otherwise increment daily counter
    await _storage.incrementGamesPlayedToday();
    await _storage.updateLastGameDateToToday();
  }

  /// Grant bonus games to the user
  Future<void> grantBonusGame({int count = 1}) async {
    if (count <= 0) {
      throw ArgumentError('Bonus game count must be positive');
    }
    await _storage.addBonusGames(count);
  }

  /// Activate Night Pass for a duration
  Future<void> activateNightPass(Duration duration) async {
    await _storage.activateNightPass(duration);
  }

  /// Check if user has an active Night Pass
  bool hasActiveNightPass() {
    return _storage.hasActiveNightPass();
  }

  /// Get number of remaining free games today
  /// Returns null if Night Pass is active (unlimited)
  int? getRemainingFreeGames() {
    // Night Pass = unlimited
    if (_storage.hasActiveNightPass()) {
      return null;
    }

    // Bonus games count as remaining
    final bonusGames = _storage.getBonusGames();
    if (bonusGames > 0) {
      return bonusGames;
    }

    // Calculate remaining daily games
    final gamesPlayed = _storage.getGamesPlayedToday();
    final remaining = maxFreeGamesPerDay - gamesPlayed;
    return remaining > 0 ? remaining : 0;
  }

  /// Get Night Pass expiry date (null if not active)
  DateTime? getNightPassExpiry() {
    return _storage.getNightPassExpiry();
  }

  /// Get current bonus games count
  int getBonusGamesCount() {
    return _storage.getBonusGames();
  }

  /// Get games played today
  int getGamesPlayedToday() {
    return _storage.getGamesPlayedToday();
  }

  /// Check if day has changed and reset counter if needed
  Future<void> _checkAndResetDailyCounter() async {
    final lastGameDate = _storage.getLastGameDate();
    final now = DateTime.now();

    // No previous date = first time user
    if (lastGameDate == null) {
      await _storage.updateLastGameDateToToday();
      return;
    }

    // Check if day changed
    final lastDate = DateTime(
      lastGameDate.year,
      lastGameDate.month,
      lastGameDate.day,
    );
    final today = DateTime(now.year, now.month, now.day);

    if (today.isAfter(lastDate)) {
      // New day! Reset counter
      await _storage.resetDailyCounter();
    }
  }

  /// Reset all monetization data (for testing/debug)
  Future<void> clearAllData() async {
    await _storage.clearAll();
  }
}
