# Phase 1B Quick Reference Guide

## 🚀 How to Use the Connection System

### Starting Heartbeat (Required when joining/creating room)

```dart
// In HomeScreen after successful join/create
final connectionService = ref.read(connectionServiceProvider);
connectionService.startHeartbeat(
  roomCode: room.code,
  playerId: userId,
);
```

### Stopping Heartbeat (Required when leaving room)

```dart
// Before navigating away from room
final connectionService = ref.read(connectionServiceProvider);
connectionService.stopHeartbeat();
```

### Cleaning Up Disconnected Players

```dart
// Returns updated room or null if deleted
final repository = ref.read(roomRepositoryProvider);
final room = await repository.cleanupDisconnectedPlayers(roomCode);

if (room == null) {
  // Room was deleted (fewer than 2 players)
  // Navigate to home and show message
}
```

### Handling Room Deletion in UI

```dart
@override
Widget build(BuildContext context) {
  final roomAsync = ref.watch(roomStreamProvider);
  
  return roomAsync.when(
    data: (room) {
      if (room == null) {
        // Room deleted - navigate away
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateToHomeWithMessage('La sala se cerró por desconexión');
        });
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      
      // Normal UI rendering
      // ...
    },
    loading: () => const CircularProgressIndicator(),
    error: (e, _) => Text('Error: $e'),
  );
}

void _navigateToHomeWithMessage(String message) {
  if (!mounted) return;
  
  // Stop heartbeat
  final connectionService = ref.read(connectionServiceProvider);
  connectionService.stopHeartbeat();
  
  // Clear room code
  ref.read(roomCodeProvider.notifier).state = null;
  
  // Navigate
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => const HomeScreen()),
  );
  
  // Show message
  Future.delayed(const Duration(milliseconds: 500), () {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
        ),
      );
    }
  });
}
```

---

## 📋 Cleanup Trigger Checklist

### When to trigger cleanup:

✅ **Lobby Screen**: Every 30 seconds (automatic via Timer)  
✅ **Before starting game**: When host clicks "Iniciar Juego"  
✅ **Before moving to voting**: When all players submit answers  
✅ **Before next round**: When starting a new round  
✅ **On phase transitions**: Any major state change

### Example: Before Phase Transition

```dart
Future<void> _moveToNextPhase(String roomCode) async {
  // Clean up first
  final repository = ref.read(roomRepositoryProvider);
  final room = await repository.cleanupDisconnectedPlayers(roomCode);
  
  if (room == null) {
    // Room deleted during cleanup
    return;
  }
  
  // Continue with phase transition
  // ...
}
```

---

## 🔍 Debugging Connection Issues

### Check Player Connection Status

```dart
// In any screen with room access
final room = ref.watch(roomStreamProvider).value;
if (room != null) {
  for (final player in room.players) {
    print('${player.name}:');
    print('  lastSeen: ${player.lastSeen}');
    print('  isOnline: ${player.isOnline}');
    print('  isDisconnected: ${player.isDisconnected}');
    print('  secondsSinceLastSeen: ${DateTime.now().difference(player.lastSeen).inSeconds}');
  }
}
```

### Monitor Heartbeat Status

```dart
// Add to ConnectionService for debugging
void _sendHeartbeat() async {
  print('🫀 Sending heartbeat for player $_currentPlayerId');
  // ... existing code
  print('✅ Heartbeat sent successfully');
}
```

### Monitor Cleanup Operations

```dart
// Add to RoomRepository for debugging
Future<Room?> cleanupDisconnectedPlayers(String roomCode) async {
  print('🧹 Starting cleanup for room $roomCode');
  final result = await /* ... existing code ... */;
  
  if (result == null) {
    print('🗑️ Room deleted (too few players)');
  } else {
    print('✅ Cleanup complete. Active players: ${result.players.length}');
  }
  
  return result;
}
```

---

## ⚠️ Common Pitfalls

### 1. Forgetting to Start Heartbeat
❌ **Problem**: Player joins but heartbeat never starts  
✅ **Solution**: Always call `startHeartbeat()` after join/create

### 2. Not Stopping Heartbeat on Exit
❌ **Problem**: Heartbeat continues after leaving room  
✅ **Solution**: Call `stopHeartbeat()` before navigation

### 3. Not Handling null Room
❌ **Problem**: App crashes when room deleted  
✅ **Solution**: Always check `if (room == null)` in build methods

### 4. Forgetting Cleanup Before Phase Changes
❌ **Problem**: Disconnected players participate in next phase  
✅ **Solution**: Always cleanup before major state transitions

### 5. Not Checking mounted Before Navigation
❌ **Problem**: Navigation errors after widget disposed  
✅ **Solution**: Always `if (!mounted) return` before navigation

---

## 🧪 Testing Checklist

### Manual Testing

- [ ] Create room - heartbeat starts
- [ ] Join room - heartbeat starts  
- [ ] Background app - heartbeat pauses
- [ ] Foreground app - heartbeat resumes
- [ ] Close app - heartbeat stops
- [ ] Force-kill app - detected after 20s
- [ ] Host disconnects - new host assigned
- [ ] Only 1 player left - room deleted
- [ ] Room deleted - UI navigates to home
- [ ] SnackBar shown on room deletion

### Multi-Device Testing

- [ ] 3 devices join room
- [ ] Device A (host) force-closes app
- [ ] After 20s: Device B or C becomes host
- [ ] Device D joins - sees correct host
- [ ] Device B and C disconnect
- [ ] Device D navigated to home with message

---

## 📊 Monitoring in Production

### Key Metrics to Track

1. **Heartbeat Success Rate**: Should be >99%
2. **Average Cleanup Time**: Should be <500ms
3. **Rooms Deleted per Day**: Track cleanup frequency
4. **Host Reassignments**: Monitor leadership changes
5. **Player Disconnect Rate**: Identify connection issues

### Firestore Dashboard Queries

```javascript
// Rooms with inactive players
db.collection('rooms').where('players.isOnline', '==', false)

// Rooms with old lastSeen (stuck heartbeat)
// (Manual query - check lastSeen timestamps)
```

---

## 🔧 Tuning Parameters

### Current Settings

```dart
// ConnectionService
const HEARTBEAT_INTERVAL = Duration(seconds: 10);

// Player model
const DISCONNECT_THRESHOLD = 20; // seconds

// LobbyScreen
const CLEANUP_INTERVAL = Duration(seconds: 30);

// RoomRepository
const MIN_PLAYERS = 2;
```

### Adjustment Guidelines

- **Faster heartbeat** (e.g., 5s): More responsive, higher Firestore cost
- **Slower heartbeat** (e.g., 15s): Lower cost, slower disconnect detection
- **Longer disconnect threshold** (e.g., 30s): More forgiving, slower cleanup
- **Shorter threshold** (e.g., 15s): Faster cleanup, risk of false positives

---

## 🎓 Best Practices

### DO ✅
- Start heartbeat immediately after join/create
- Stop heartbeat before navigating away
- Cleanup before phase transitions
- Handle null room in all UI builders
- Use WidgetsBinding for post-frame navigation
- Check mounted before setState/navigation
- Log cleanup operations for debugging

### DON'T ❌
- Start multiple heartbeats for same player
- Forget to dispose Timers
- Navigate without checking mounted
- Skip cleanup before important transitions
- Ignore room == null case
- Use update() instead of runTransaction()
- Show technical errors to users

---

## 📚 Related Documentation

- `PHASE_1B_COMPLETE.md` - Full implementation details
- `PHASE_1B_ARCHITECTURE.md` - System diagrams
- `TECHNICAL_DIAGNOSTIC.md` - Architecture audit
- `VOTING_FIX_REPORT.md` - Phase 1A (race condition fix)

---

## 🆘 Troubleshooting

### Symptom: Players not being cleaned up
**Check**: 
1. Is cleanup being called? (Add logs)
2. Is transaction succeeding? (Check Firestore logs)
3. Is lastSeen being updated? (Check player data)

### Symptom: Host not reassigning
**Check**:
1. Is cleanup detecting host disconnect?
2. Are there other active players?
3. Is transaction updating hostId?

### Symptom: Room not deleting when empty
**Check**:
1. Is cleanup counting active players correctly?
2. Is transaction.delete() being called?
3. Is roomStream updating to null?

### Symptom: Heartbeat not stopping
**Check**:
1. Is stopHeartbeat() being called?
2. Is Timer being cancelled?
3. Is _isActive set to false?

---

## 🎯 Quick Win Checklist

Starting a new screen that displays rooms?

1. [ ] Watch roomStreamProvider
2. [ ] Handle room == null case
3. [ ] Add _navigateToHomeWithMessage() helper
4. [ ] Start heartbeat on entry (if needed)
5. [ ] Stop heartbeat on exit
6. [ ] Add cleanup before major actions
7. [ ] Test with force-killed device

---

**Remember**: The connection system is designed to be **forgiving and self-healing**. Trust the cleanup process and focus on proper heartbeat lifecycle management!
