# PHASE 2B-PRO QUICK REFERENCE
## Room-Based Monetization API

---

## 🎯 Quick Start

```dart
// In your code
final gameController = ref.read(gameControllerProvider);
final roomRepository = ref.read(roomRepositoryProvider);
final adService = ref.read(adServiceProvider);
```

---

## 📘 API Reference

### GameController

#### Start Game (with Monetization Check)
```dart
Future<void> startGame(String roomCode)
```
**Behavior:**
- Checks `canRoomStartGame()`
- Throws `MonetizationException('ROOM_LOCKED')` if blocked
- Does NOT start game logic - just validates

**Usage:**
```dart
try {
  await gameController.startGame(roomCode);
  // Continue with game start...
} on MonetizationException catch (e) {
  if (e.code == 'ROOM_LOCKED') {
    // Show paywall
  }
}
```

#### Complete Game
```dart
Future<void> completeGame(String roomCode)
```
**When to call:** After all rounds finish  
**Effect:** Increments `gamesPlayedToday` counter

---

### RoomRepository

#### Check Room Eligibility
```dart
Future<bool> canRoomStartGame(String roomCode)
```
**Returns:** `true` if allowed, `false` if blocked  
**Side effects:**
- Resets counter if day changed
- Consumes ad unlock if available

**Priority:**
1. Night Pass active → true
2. New day → reset → true
3. Ad unlocks > 0 → consume → true
4. Games < 3 → true
5. Else → false

#### Increment Counter
```dart
Future<void> incrementGamesPlayed(String roomCode)
```
**Transaction:** Yes (atomic)  
**Handles:** Day change reset automatically

#### Grant Ad Unlock
```dart
Future<void> grantAdUnlock(String roomCode)
```
**Transaction:** Yes (prevents double reward)  
**Effect:** `adUnlocksRemaining += 1`

#### Activate Night Pass
```dart
Future<void> activateNightPass(String roomCode)
```
**Transaction:** Yes  
**Duration:** 12 hours from now  
**Effect:** Sets `nightPassExpiresAt`

---

### AdService

#### Initialize
```dart
Future<void> initialize()
```
**Call once:** In main() or provider  
**Effect:** Initializes SDK and preloads first ad

#### Show Rewarded Ad
```dart
Future<bool> showRewardedAd()
```
**Returns:** `true` if reward earned, `false` otherwise  
**Auto:** Preloads next ad after showing

**Usage:**
```dart
final earned = await adService.showRewardedAd();
if (earned) {
  await roomRepository.grantAdUnlock(roomCode);
}
```

#### Check Ad Ready
```dart
bool get isAdReady
```
**Returns:** `true` if ad loaded and ready to show

---

### PaywallScreen

#### Navigate to Paywall
```dart
final unlocked = await Navigator.push<bool>(
  context,
  MaterialPageRoute(
    builder: (_) => PaywallScreen(roomCode: roomCode),
  ),
);

if (unlocked == true) {
  // Retry game start
}
```

**Returns:**
- `true` if room unlocked (ad watched or Night Pass bought)
- `false/null` if user dismissed without unlocking

---

## 🎨 UI Integration Examples

### Show Paywall on Lock
```dart
Future<void> _startGame() async {
  try {
    await gameController.startGame(roomCode);
    
    // Monetization passed - continue game start
    final room = await _loadGameData();
    await firebaseService.updateRoom(room);
    Navigator.push(...);
    
  } on MonetizationException catch (e) {
    if (e.code == 'ROOM_LOCKED') {
      final unlocked = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaywallScreen(roomCode: roomCode),
        ),
      );
      
      if (unlocked == true) {
        await _startGame(); // Retry recursively
      }
    }
  }
}
```

### Display Room Status (Optional)
```dart
Consumer(
  builder: (context, ref, _) {
    final roomAsync = ref.watch(roomStreamProvider);
    
    return roomAsync.when(
      data: (room) {
        if (room == null) return SizedBox.shrink();
        
        // Check Night Pass
        if (room.nightPassExpiresAt != null &&
            room.nightPassExpiresAt!.isAfter(DateTime.now())) {
          return _buildNightPassBadge(room.nightPassExpiresAt!);
        }
        
        // Check games remaining
        final remaining = 3 - room.gamesPlayedToday + room.adUnlocksRemaining;
        return Text('$remaining partidas disponibles');
      },
      loading: () => CircularProgressIndicator(),
      error: (e, _) => SizedBox.shrink(),
    );
  },
)
```

---

## 🔧 Room Model Fields

### Access Room Monetization State
```dart
final room = Room(...);

// Daily counter
int gamesPlayed = room.gamesPlayedToday;    // 0-3+

// Ad unlocks
int bonusGames = room.adUnlocksRemaining;   // 0+

// Night Pass
DateTime? expiresAt = room.nightPassExpiresAt;
bool hasPass = expiresAt != null && expiresAt.isAfter(DateTime.now());

// Last game date
String? lastDate = room.lastGameDate;       // "2026-02-18"
```

---

## 🚨 Error Handling

### MonetizationException
```dart
try {
  await gameController.startGame(roomCode);
} catch (e) {
  if (e is MonetizationException) {
    print(e.message);  // Spanish error message
    print(e.code);     // 'ROOM_LOCKED'
    
    // Show paywall or error dialog
  } else {
    // Other error
  }
}
```

**Error Message:**
> "La sala ha alcanzado el límite de 3 partidas diarias. Mira un anuncio o activa el Night Pass para continuar."

---

## 📊 Business Rules Summary

| Scenario | Room State | Behavior |
|----------|-----------|----------|
| First 3 games | gamesPlayedToday: 0-2 | ✅ Allow |
| 4th game | gamesPlayedToday: 3, no unlocks | ❌ Block → Paywall |
| After ad watched | adUnlocksRemaining: 1 | ✅ Allow → Consume unlock |
| New day | lastGameDate != today | ✅ Reset counter → Allow |
| Night Pass active | nightPassExpiresAt > now | ✅ Unlimited games |
| Night Pass expired | nightPassExpiresAt < now | ⚠️ Back to daily limit |

---

## 🧪 Testing Workflow

### Test Daily Limit
```dart
final repository = RoomRepository();

// Simulate 3 games
for (int i = 0; i < 3; i++) {
  await repository.incrementGamesPlayed(roomCode);
}

// Should block
final canStart = await repository.canRoomStartGame(roomCode);
print(canStart); // false
```

### Test Ad Unlock
```dart
// Grant ad unlock
await repository.grantAdUnlock(roomCode);

// Should allow
final canStart = await repository.canRoomStartGame(roomCode);
print(canStart); // true (consumes unlock)
```

### Test Night Pass
```dart
// Activate Night Pass
await repository.activateNightPass(roomCode);

// Should allow unlimited
for (int i = 0; i < 10; i++) {
  final canStart = await repository.canRoomStartGame(roomCode);
  print(canStart); // true (doesn't consume anything)
}
```

### Test Daily Reset
```dart
// Manually set old date
await roomRef.update({'lastGameDate': '2026-02-17'});

// Should reset on next check
final canStart = await repository.canRoomStartGame(roomCode);
print(canStart); // true (counter reset to 0)
```

---

## 🔐 Security Notes

### Preventing Exploits

1. **Double Ad Reward**
   - ✅ Firestore transaction prevents duplicate increments
   - ✅ `showRewardedAd()` validates callback fired

2. **Manual Counter Manipulation**
   - ✅ All writes through repository (no direct Firestore access in UI)
   - ✅ Validation logic in transaction

3. **Bypassing Limit**
   - ✅ Check happens in `canRoomStartGame()` transaction
   - ✅ Cannot start game without passing check

4. **Date Manipulation**
   - ✅ Server-side date comparison
   - ✅ Reset logic in transaction (atomic)

---

## 📱 Platform-Specific Notes

### Android
- AdMob App ID in `AndroidManifest.xml`
- Internet permissions required
- ProGuard rules auto-handled by google_mobile_ads

### iOS
- AdMob App ID in `Info.plist`
- SKAdNetwork items configured (8 networks)
- App Transport Security allows HTTP for ads
- ATT (App Tracking Transparency) optional - ads work without

---

## 🎯 Production Deployment Checklist

### Before Release

- [ ] Replace test ad unit IDs with production IDs
- [ ] Create AdMob account and app
- [ ] Test on real devices (Android + iOS)
- [ ] Verify ad loading works
- [ ] Test Night Pass purchase flow (Phase 2C)
- [ ] Test daily reset at midnight
- [ ] Verify transactions prevent duplicates
- [ ] Check analytics tracking

### Ad Unit ID Replacement

**File:** `lib/services/ad_service.dart`

```dart
// Replace these with your actual IDs from AdMob console
static const String _prodAdUnitIdAndroid = 'ca-app-pub-XXXX/YYYY';
static const String _prodAdUnitIdIOS = 'ca-app-pub-XXXX/YYYY';
```

---

## 📚 Related Files

- **AdService:** `lib/services/ad_service.dart`
- **PaywallScreen:** `lib/presentation/screens/paywall_screen.dart`
- **GameController:** `lib/domain/controllers/game_controller.dart`
- **RoomRepository:** `lib/data/repositories/room_repository.dart`
- **Room Model:** `lib/models/room.dart`
- **Providers:** `lib/providers/ad_providers.dart`
- **Exception:** `lib/core/exceptions.dart`

---

## 🆘 Troubleshooting

### Ad Not Loading
```dart
// Check logs
debugPrint('[AdService] logs...');

// Verify initialization
await MobileAds.instance.initialize();

// Check internet permission
// AndroidManifest.xml: INTERNET permission

// Test ad units working?
// Use test IDs first
```

### Paywall Not Showing
```dart
// Verify exception thrown
try {
  await gameController.startGame(roomCode);
} on MonetizationException catch (e) {
  print('Code: ${e.code}'); // Should be 'ROOM_LOCKED'
}
```

### Counter Not Resetting
```dart
// Check date format
print(room.lastGameDate); // Should be "yyyy-MM-dd"

// Verify transaction executes
// Check Firestore console for updated values
```

---

**Last Updated:** February 18, 2026  
**Phase:** 2B-PRO Complete ✅  
**Next:** Phase 2C - IAP Integration
