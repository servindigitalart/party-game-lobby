# PHASE 2A QUICK REFERENCE
## Monetization Backend API

### 🎯 Quick Start

```dart
// In your widget
final controller = ref.read(monetizationControllerProvider);
final gameController = ref.read(gameControllerProvider);
```

---

## 📘 API Reference

### MonetizationController

#### Check Game Eligibility
```dart
Future<bool> canPlayGame()
```
**Returns:** `true` if allowed  
**Throws:** `MonetizationException` if limit reached  
**Auto-checks:** Night Pass, day reset, bonus games, daily limit

#### Register Game Play
```dart
Future<void> registerGamePlayed()
```
**Effect:** Consumes bonus game OR increments daily counter  
**Night Pass:** Does nothing (unlimited games)

#### Grant Bonus Games
```dart
Future<void> grantBonusGame({int count = 1})
```
**Use Case:** Rewarded ads (Phase 2B)  
**Example:** `await controller.grantBonusGame(count: 3);`

#### Activate Night Pass
```dart
Future<void> activateNightPass(Duration duration)
```
**Use Case:** IAP purchase (Phase 2C)  
**Example:** `await controller.activateNightPass(Duration(hours: 24));`

#### Check Night Pass
```dart
bool hasActiveNightPass()
```
**Returns:** `true` if active and not expired

#### Get Remaining Games
```dart
int? getRemainingFreeGames()
```
**Returns:**
- `null` = Unlimited (Night Pass active)
- `> 0` = Bonus games OR remaining daily games
- `0` = Limit reached

#### Get Stats
```dart
DateTime? getNightPassExpiry()    // When Night Pass expires
int getBonusGamesCount()          // Current bonus games
int getGamesPlayedToday()         // Daily counter
```

---

### GameController

#### Create Room (Enforced)
```dart
Future<Room> createRoom(String hostId, String hostName)
```
**Checks:** Monetization limits before creating  
**Auto-registers:** Game play after creation  
**Throws:** `MonetizationException` if blocked

#### Join Room (Free)
```dart
Future<Room?> joinRoom(String code, String playerId, String playerName)
```
**Note:** Joining doesn't consume games (only creating does)

#### Other Methods
All other FirebaseService methods pass through unchanged:
- `updateRoom()`, `submitAnswer()`, `submitVote()`
- `calculateRoundScores()`, `clearRoundData()`, `deleteRoom()`
- `listenToRoom()`, `signInAnonymously()`

---

### Riverpod Providers

#### Controllers
```dart
final monetizationControllerProvider  // MonetizationController
final gameControllerProvider          // GameController
final localStorageServiceProvider     // LocalStorageService (async)
```

#### Reactive State
```dart
final remainingFreeGamesProvider      // int? - remaining games
final hasActiveNightPassProvider      // bool - Night Pass status
final bonusGamesCountProvider         // int - bonus games count
```

---

## 🎨 UI Integration Examples

### Show Remaining Games Badge
```dart
Consumer(
  builder: (context, ref, _) {
    final remaining = ref.watch(remainingFreeGamesProvider);
    
    if (remaining == null) {
      return Icon(Icons.all_inclusive); // Unlimited
    }
    
    return Text('$remaining juegos restantes');
  },
)
```

### Create Room with Limit Check
```dart
Future<void> _createRoom() async {
  try {
    final gameController = ref.read(gameControllerProvider);
    final userId = await gameController.signInAnonymously();
    
    final room = await gameController.createRoom(userId, userName);
    // Success! Navigate to lobby
    
  } catch (e) {
    if (e is MonetizationException) {
      // Show limit dialog or paywall
      _showLimitDialog(e.message);
    } else {
      // Other error
      _showError(e.toString());
    }
  }
}
```

### Night Pass Indicator
```dart
Consumer(
  builder: (context, ref, _) {
    final hasPass = ref.watch(hasActiveNightPassProvider);
    
    if (!hasPass) return SizedBox.shrink();
    
    final controller = ref.read(monetizationControllerProvider);
    final expiry = controller.getNightPassExpiry();
    
    return Card(
      child: Text('Pase Nocturno activo hasta ${_formatDate(expiry)}'),
    );
  },
)
```

---

## 🚨 Error Handling

### MonetizationException
```dart
try {
  await controller.canPlayGame();
} catch (e) {
  if (e is MonetizationException) {
    print(e.message);  // Spanish error message
    print(e.code);     // 'DAILY_LIMIT_REACHED'
  }
}
```

**Default Message:**
> "Has alcanzado el límite de 3 partidas gratuitas hoy. Vuelve mañana o activa el Pase Nocturno para seguir jugando."

---

## 📊 Business Rules Summary

| Scenario | Behavior |
|----------|----------|
| First 3 games today | ✅ Allowed |
| 4th game (no bonus) | ❌ Blocked |
| New day (midnight) | ✅ Counter resets to 0 |
| Bonus games available | ✅ Consumes bonus first |
| Night Pass active | ✅ Unlimited games |
| Joining a room | ✅ Always free |
| Creating a room | 🔒 Enforced |

---

## 🧪 Testing

### Run All Tests
```bash
flutter test test/monetization_controller_test.dart
```

### Manual Testing Flow
1. Create 3 rooms → Should succeed
2. Try 4th room → Should throw exception
3. Grant bonus: `controller.grantBonusGame(count: 2)`
4. Create 2 more rooms → Should succeed
5. Try 7th room → Should throw exception
6. Activate pass: `controller.activateNightPass(Duration(hours: 1))`
7. Create unlimited rooms → Should succeed

### Reset for Testing
```dart
await controller.clearAllData();
```

---

## 🔧 Storage Keys

Internal SharedPreferences keys (for debugging):
- `gamesPlayedToday` - int
- `lastGameDate` - ISO8601 string
- `bonusGames` - int
- `nightPassExpiry` - ISO8601 string (nullable)

---

## 📚 Related Files

- **Controller:** `lib/domain/controllers/monetization_controller.dart`
- **Game Logic:** `lib/domain/controllers/game_controller.dart`
- **Storage:** `lib/services/local_storage_service.dart`
- **Providers:** `lib/providers/monetization_providers.dart`
- **Exception:** `lib/core/exceptions.dart` (MonetizationException)
- **Tests:** `test/monetization_controller_test.dart`

---

**Last Updated:** February 18, 2026  
**Status:** Phase 2A Complete ✅
