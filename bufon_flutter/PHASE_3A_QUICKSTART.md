# Phase 3A: Analytics Quick Reference 🎯

## Quick Start

### Initialize Analytics (Already Done)
```dart
// In main.dart - done automatically
await AnalyticsService.instance.initialize();
```

### Track an Event
```dart
final analytics = AnalyticsService.instance;

await analytics.logGameCreated(roomCode: 'ABC123');
await analytics.logGameJoined(roomCode: 'ABC123', playerCount: 4);
```

---

## Event Reference

### Gameplay Events

```dart
// Game created
await analytics.logGameCreated(roomCode: room.code);

// Player joined
await analytics.logGameJoined(
  roomCode: room.code,
  playerCount: room.players.length,
);

// Game started
await analytics.logGameStarted(
  roomCode: room.code,
  playerCount: room.players.length,
  totalRounds: room.totalRounds,
);

// Round started
await analytics.logRoundStarted(
  roomCode: room.code,
  roundNumber: room.currentRound,
  playerCount: room.players.length,
  questionText: 'What would you do if...', // optional
);

// Vote submitted
await analytics.logVoteSubmitted(
  roomCode: room.code,
  roundNumber: room.currentRound,
  timeToVoteSeconds: 15,
);

// Round completed
await analytics.logRoundCompleted(
  roomCode: room.code,
  roundNumber: room.currentRound,
  roundDurationSeconds: 120,
  votesSubmitted: 4,
);

// Player disconnected
await analytics.logPlayerDisconnected(
  roomCode: room.code,
  playerCountRemaining: 3,
  gamePhase: 'voting',
);

// Game finished
await analytics.logGameFinished(
  roomCode: room.code,
  totalRounds: 5,
  totalDurationSeconds: 600,
  finalPlayerCount: 4,
);

// Winner declared
await analytics.logWinnerDeclared(
  roomCode: room.code,
  winningScore: 500,
  totalPlayers: 4,
  wasTiebreaker: false,
);
```

### Monetization Events

```dart
// Paywall shown
await analytics.logPaywallShown(
  roomCode: room.code,
  gamesPlayedToday: 3,
  triggerReason: 'free_limit', // or 'night_pass_upsell'
);

// Rewarded ad watched
await analytics.logRewardedAdWatched(
  roomCode: room.code,
  gamesPlayedToday: 3,
  adNetwork: 'admob',
);

// Rewarded ad completed
await analytics.logRewardedAdCompleted(
  roomCode: room.code,
  rewardAmount: 1,
  timeToCompleteSeconds: 30,
  adNetwork: 'admob',
);

// Rewarded ad failed
await analytics.logRewardedAdFailed(
  roomCode: room.code,
  adNetwork: 'admob',
  failureReason: 'no_fill',
);

// Night Pass purchase initiated
await analytics.logNightPassPurchaseInitiated(
  roomCode: room.code,
  productId: 'night_pass_12h',
  priceMicros: 990000, // $0.99 = 990000 micros
  currency: 'USD',
);

// Night Pass purchased
await analytics.logNightPassPurchased(
  roomCode: room.code,
  productId: 'night_pass_12h',
  purchaseValueMicros: 990000,
  currency: 'USD',
  platform: 'android', // or 'ios'
);

// Night Pass activated
await analytics.logNightPassActivated(
  roomCode: room.code,
  activatedBySelf: true,
  expiresAt: DateTime.now().add(Duration(hours: 12)),
);

// Game blocked by limit
await analytics.logGameBlockedByLimit(
  roomCode: room.code,
  gamesPlayedToday: 3,
  hasNightPass: false,
  adUnlocksRemaining: 0,
);
```

### Retention Events

```dart
// App opened (automatic in main.dart)
await analytics.logAppOpened();

// Session started (automatic in main.dart)
await analytics.logSessionStarted();

// Session ended (call on app close or background)
await analytics.logSessionEnded();

// Manual retention tracking (usually automatic)
await analytics.logReturnedSameDay();
await analytics.logReturnedNextDay();
await analytics.logReturnedAfterWeek();
```

### Quality Events

```dart
// Gameplay error
await analytics.logGameplayError(
  errorType: 'vote_failed',
  errorMessage: 'Transaction timeout',
);

// High latency
await analytics.logHighLatency(
  operationType: 'vote_submission',
  latencyMs: 5000,
);

// Feedback submitted
await analytics.logFeedbackSubmitted(
  feedbackType: 'bug_report',
  rating: 3,
);
```

### Screen Tracking

```dart
// In StatefulWidget
class MyScreen extends StatefulWidget {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.trackScreenView('MyScreen');
  }
}

// In ConsumerWidget (careful - may track on every rebuild)
@override
Widget build(BuildContext context, WidgetRef ref) {
  AnalyticsService.instance.trackScreenView('MyScreen');
  // ...
}
```

### User Properties

```dart
// Set user ID (done in auth flow)
await analytics.setUserId('user_12345');

// Set custom properties
await analytics.setUserProperty(
  name: 'has_night_pass',
  value: 'true',
);

await analytics.setUserProperty(
  name: 'games_played_total',
  value: '42',
);
```

---

## Privacy Best Practices

### ✅ DO
```dart
// Hash sensitive data
await analytics.logGameCreated(
  roomCode: 'ABC123', // Will be hashed internally
);

// Track aggregated metrics
await analytics.logGameJoined(
  playerCount: 4, // Number, not player names
);
```

### ❌ DON'T
```dart
// DON'T track PII
await analytics.setUserProperty(
  name: 'email',
  value: 'user@example.com', // ❌ NEVER DO THIS
);

// DON'T track plaintext sensitive data
await analytics.logCustomEvent('custom_event', {
  'room_code': 'ABC123', // ❌ Use hashed version
  'player_name': 'John', // ❌ No player names
});
```

---

## Firebase Console

### View Events
1. Go to Firebase Console → Analytics → Events
2. See event counts and parameters
3. Use Debug View for real-time testing

### Create Funnels
1. Analytics → Funnels → Create Funnel
2. Example: `app_opened` → `game_created` → `game_started` → `game_finished`

### Set Up Conversions
Mark key events as conversions:
- `night_pass_purchased`
- `rewarded_ad_completed`
- `game_finished`

---

## Debugging

### Enable Debug Logging
```dart
// Analytics service already has debug logging
// Events will be printed to console in debug mode
```

### Test with Firebase Debug View
```bash
# Android
adb shell setprop debug.firebase.analytics.app com.yourpackage

# iOS
-FIRDebugEnabled in Xcode scheme arguments
```

### Check Event Delivery
- Events may take 24 hours to appear in console
- Use Debug View for immediate feedback
- Check network connectivity

---

## Common Patterns

### Pattern 1: Track User Flow
```dart
// Home → Create → Lobby → Game
await analytics.trackScreenView('HomeScreen');
await analytics.logGameCreated(roomCode: code);
await analytics.trackScreenView('LobbyScreen');
await analytics.logGameStarted(...);
```

### Pattern 2: Track Monetization Funnel
```dart
// Blocked → Paywall → Ad → Unlocked
await analytics.logGameBlockedByLimit(...);
await analytics.logPaywallShown(...);
await analytics.logRewardedAdWatched(...);
await analytics.logRewardedAdCompleted(...);
```

### Pattern 3: Track Game Session
```dart
// Start → Rounds → Votes → Winner
await analytics.logGameStarted(...);
await analytics.logRoundStarted(...);
await analytics.logVoteSubmitted(...);
await analytics.logWinnerDeclared(...);
await analytics.logGameFinished(...);
```

---

## Performance Tips

✅ **All events are async** - No blocking  
✅ **Firebase batches events** - Efficient network usage  
✅ **Events cached offline** - Sent when connected  
✅ **Minimal overhead** - <10ms per event  

---

## Troubleshooting

### Events not showing up
- Check internet connection
- Wait 24 hours for batch processing
- Use Debug View for immediate feedback
- Verify Firebase config files

### Duplicate events
- Check screen view tracking in build methods
- Use StatefulWidget for screen tracking
- Add debouncing if needed

### Missing parameters
- Check required parameters in method signature
- Verify data types match expectations
- Use named parameters correctly

---

## Key Metrics Dashboard

### Engagement
- **DAU**: Daily active users (`app_opened` count)
- **Session Duration**: Avg `session_ended.session_duration_seconds`
- **Games/Session**: Avg `session_ended.games_played`

### Retention
- **D1**: `returned_next_day` / `app_opened` (yesterday)
- **D7**: `returned_after_week` / `app_opened` (7 days ago)

### Monetization
- **Ad View Rate**: `rewarded_ad_watched` / `paywall_shown`
- **Ad Complete Rate**: `rewarded_ad_completed` / `rewarded_ad_watched`
- **IAP Conversion**: `night_pass_purchased` / `night_pass_purchase_initiated`
- **ARPU**: Sum(`night_pass_purchased.purchase_value_micros`) / DAU

### Quality
- **Error Rate**: `gameplay_error` count / `game_started` count
- **Avg Latency**: Avg `high_latency.latency_ms`
- **Completion Rate**: `game_finished` / `game_started`

---

## Need Help?

- 📖 Full docs: `PHASE_3A_COMPLETE.md`
- 🔥 Firebase Analytics: https://firebase.google.com/docs/analytics
- 📱 FlutterFire: https://firebase.flutter.dev/docs/analytics/overview
