// services/local_storage_service.dart
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing local persistent storage
///
/// Stores monetization-related data:
/// - Daily game counter
/// - Bonus games
/// - Night Pass expiration
class LocalStorageService {
  static const String _keyGamesPlayedToday = 'gamesPlayedToday';
  static const String _keyLastGameDate = 'lastGameDate';
  static const String _keyBonusGames = 'bonusGames';
  static const String _keyNightPassExpiry = 'nightPassExpiry';

  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  /// Factory constructor to create instance with SharedPreferences
  static Future<LocalStorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService(prefs);
  }

  // ==================== Games Played Today ====================

  /// Get number of games played today
  int getGamesPlayedToday() {
    return _prefs.getInt(_keyGamesPlayedToday) ?? 0;
  }

  /// Set number of games played today
  Future<void> setGamesPlayedToday(int count) async {
    await _prefs.setInt(_keyGamesPlayedToday, count);
  }

  /// Increment games played today counter
  Future<void> incrementGamesPlayedToday() async {
    final current = getGamesPlayedToday();
    await setGamesPlayedToday(current + 1);
  }

  // ==================== Last Game Date ====================

  /// Get the last date a game was played
  DateTime? getLastGameDate() {
    final dateString = _prefs.getString(_keyLastGameDate);
    if (dateString == null) return null;

    try {
      return DateTime.parse(dateString);
    } catch (e) {
      return null;
    }
  }

  /// Set the last game date
  Future<void> setLastGameDate(DateTime date) async {
    await _prefs.setString(_keyLastGameDate, date.toIso8601String());
  }

  /// Update last game date to today
  Future<void> updateLastGameDateToToday() async {
    await setLastGameDate(DateTime.now());
  }

  // ==================== Bonus Games ====================

  /// Get number of bonus games available
  int getBonusGames() {
    return _prefs.getInt(_keyBonusGames) ?? 0;
  }

  /// Set number of bonus games
  Future<void> setBonusGames(int count) async {
    await _prefs.setInt(_keyBonusGames, count);
  }

  /// Add bonus games
  Future<void> addBonusGames(int count) async {
    final current = getBonusGames();
    await setBonusGames(current + count);
  }

  /// Consume one bonus game (decrement counter)
  Future<void> consumeBonusGame() async {
    final current = getBonusGames();
    if (current > 0) {
      await setBonusGames(current - 1);
    }
  }

  // ==================== Night Pass ====================

  /// Get Night Pass expiration date
  DateTime? getNightPassExpiry() {
    final dateString = _prefs.getString(_keyNightPassExpiry);
    if (dateString == null) return null;

    try {
      return DateTime.parse(dateString);
    } catch (e) {
      return null;
    }
  }

  /// Set Night Pass expiration date
  Future<void> setNightPassExpiry(DateTime? expiry) async {
    if (expiry == null) {
      await _prefs.remove(_keyNightPassExpiry);
    } else {
      await _prefs.setString(_keyNightPassExpiry, expiry.toIso8601String());
    }
  }

  /// Activate Night Pass for a duration
  Future<void> activateNightPass(Duration duration) async {
    final expiry = DateTime.now().add(duration);
    await setNightPassExpiry(expiry);
  }

  /// Check if Night Pass is currently active
  bool hasActiveNightPass() {
    final expiry = getNightPassExpiry();
    if (expiry == null) return false;
    return DateTime.now().isBefore(expiry);
  }

  // ==================== Reset & Clear ====================

  /// Reset daily counter (called when day changes)
  Future<void> resetDailyCounter() async {
    await setGamesPlayedToday(0);
    await updateLastGameDateToToday();
  }

  /// Clear all monetization data (for testing/debug)
  Future<void> clearAll() async {
    await _prefs.remove(_keyGamesPlayedToday);
    await _prefs.remove(_keyLastGameDate);
    await _prefs.remove(_keyBonusGames);
    await _prefs.remove(_keyNightPassExpiry);
  }
}
