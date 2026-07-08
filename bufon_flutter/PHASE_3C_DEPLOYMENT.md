# Phase 3C Deployment Checklist

**Phase:** 3C - Global and Weekly Leaderboards  
**Date:** February 19, 2026  
**Status:** Ready for Deployment

---

## 📋 Pre-Deployment

### Code Review
- [x] All files compiled without errors
- [x] Analytics integration complete
- [x] Providers properly configured
- [x] Controllers integrated with progression
- [x] UI components styled correctly
- [ ] Code review by team
- [ ] Unit tests written and passing

### Testing
- [ ] Manual testing on iOS device
- [ ] Manual testing on Android device
- [ ] Test all 4 leaderboard types
- [ ] Test week transition behavior
- [ ] Test empty states
- [ ] Test error states
- [ ] Test pull-to-refresh
- [ ] Performance testing (<1s load time)
- [ ] Test with 100+ entries
- [ ] Test offline behavior

---

## 🔥 Firebase Console Setup

### 1. Firestore Indexes

#### Option A: Auto-Create (Recommended)
1. Run the app
2. View each leaderboard tab
3. Click index creation links in console
4. Wait 1-2 minutes for indexes to build

#### Option B: Manual Creation
Go to Firebase Console → Firestore → Indexes → Create Index

**Index 1: Global XP**
```
Collection: leaderboards/global_xp/entries
Fields: xp (Descending)
Query scope: Collection
```

**Index 2: Weekly XP**
```
Collection group: entries
Fields: xp (Descending)
Query scope: Collection group
```

**Index 3: Weekly Wins**
```
Collection group: entries
Fields: totalWins (Descending)
Query scope: Collection group
```

**Index 4: Weekly Votes**
```
Collection group: entries
Fields: totalVotes (Descending)
Query scope: Collection group
```

### 2. Firestore Security Rules

Add to `firestore.rules`:

```javascript
// Leaderboards - Global
match /leaderboards/{type}/entries/{uid} {
  // Anyone can read leaderboards
  allow read: if request.auth != null;
  
  // Users can only write their own entry
  allow write: if request.auth != null && request.auth.uid == uid;
}

// Leaderboards - Weekly (with week key)
match /leaderboards/{type}/{weekKey}/entries/{uid} {
  // Anyone can read leaderboards
  allow read: if request.auth != null;
  
  // Users can only write their own entry
  allow write: if request.auth != null && request.auth.uid == uid;
}
```

Deploy rules:
```bash
cd /Users/servinemilio/Documents/REPOS/party-game-lobby
firebase deploy --only firestore:rules
```

### 3. Verify Rules Deployed

```bash
firebase firestore:rules:get
```

Expected output should include leaderboard rules.

---

## 📱 App Integration

### 1. Add Navigation

Add to `HomeScreen` or create a dedicated navigation:

```dart
// In HomeScreen or bottom navigation
ListTile(
  leading: const Icon(Icons.emoji_events),
  title: const Text('Rankings'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LeaderboardScreen(),
      ),
    );
  },
)
```

### 2. Add to App Bar (Optional)

```dart
AppBar(
  title: const Text('BUFÓN'),
  actions: [
    IconButton(
      icon: const Icon(Icons.leaderboard),
      tooltip: 'Rankings',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const LeaderboardScreen(),
          ),
        );
      },
    ),
  ],
)
```

### 3. Verify Imports

Add to relevant screens:

```dart
import 'package:bufon_flutter/presentation/screens/leaderboard_screen.dart';
```

---

## 🧪 Testing Procedure

### 1. Create Test Data

Run this in a debug/test screen (temporary):

```dart
Future<void> _populateTestLeaderboards() async {
  final controller = ref.read(leaderboardControllerProvider);
  
  for (int i = 1; i <= 30; i++) {
    await controller.updateLeaderboardsAfterGame(
      uid: 'test_user_$i',
      nickname: 'Jugador $i',
      avatarId: i % 2 == 0 ? 'default' : 'cool_cat',
      xp: 1000 - (i * 30),
      level: 10 - (i ~/ 6),
      xpGained: 50,
      winsGained: i % 5 == 0 ? 1 : 0,
      votesGained: i % 3,
    );
  }
  
  print('Test data created!');
}
```

### 2. Verify Leaderboards

1. Open LeaderboardScreen
2. Check "Global" tab shows entries
3. Check "Esta Semana" tab shows entries
4. Check "Más Caótico" tab shows entries
5. Verify top 3 podium displays correctly
6. Verify user's row is highlighted (if user has played)
7. Pull to refresh and verify data updates

### 3. Test Game Flow

1. Play a complete game
2. Check leaderboards update automatically
3. Verify XP, wins, and votes increment
4. Check analytics events fire in Firebase Console

### 4. Test Week Transition

1. Check current week key
2. Verify weekly leaderboards use correct week
3. (Optional) Change system date to next week
4. Verify new week key is used
5. Verify previous week data is archived

---

## 📊 Analytics Verification

### 1. Firebase Console

Go to: Firebase Console → Analytics → Events

Wait 24 hours for initial data, or use DebugView:

### 2. Enable Debug Mode

**iOS:**
```bash
# Run in terminal
adb shell setprop debug.firebase.analytics.app com.yourpackage.bufon_flutter
```

**Android:**
```bash
# Add to run configuration
--dart-define=FIREBASE_ANALYTICS_DEBUG_MODE=true
```

### 3. Verify Events

Check these events appear:
- `leaderboards_updated`
- `leaderboard_viewed`
- `leaderboard_rank_achieved`
- `xp_awarded`
- `level_up`
- `game_completed`

---

## 🚀 Deployment Steps

### 1. Version Bump

Update `pubspec.yaml`:

```yaml
version: 1.3.0+10  # Increment version
```

### 2. Build Release

**iOS:**
```bash
cd bufon_flutter
flutter build ios --release
# Open Xcode and archive
```

**Android:**
```bash
cd bufon_flutter
flutter build appbundle --release
```

### 3. Deploy Firestore Rules

```bash
cd /Users/servinemilio/Documents/REPOS/party-game-lobby
firebase deploy --only firestore:rules
```

### 4. Upload to Stores

**Google Play:**
1. Go to Google Play Console
2. Upload `build/app/outputs/bundle/release/app-release.aab`
3. Update release notes:
   ```
   🆕 Leaderboards!
   - Compete globally and weekly
   - Track your rank in real-time
   - Fresh weekly challenges
   - Performance improvements
   ```

**App Store:**
1. Open Xcode
2. Archive and upload
3. Submit for review
4. Update release notes (similar to Android)

---

## 📝 Post-Deployment

### 1. Monitor Analytics

Check after 24-48 hours:
- % of users viewing leaderboards
- Average time on leaderboard screen
- Leaderboard update success rate
- Any errors in Crashlytics

### 2. Monitor Performance

Track in Firebase Performance:
- Leaderboard load time (target: <1s)
- Batch update time (target: <500ms)
- Query performance

### 3. Monitor Costs

Check Firestore usage:
- Document reads per day
- Document writes per day
- Network egress

Expected cost increase: Minimal (only top 50 fetches)

### 4. User Feedback

Monitor:
- App Store reviews mentioning leaderboards
- Support tickets
- Social media feedback
- In-app feedback (if available)

---

## 🐛 Troubleshooting

### Issue: "Query requires an index"

**Solution:**
1. Click the link in the error
2. Create the index in Firebase Console
3. Wait 1-2 minutes for index to build
4. Retry

### Issue: Leaderboard not updating

**Solution:**
1. Check `processGameProgression` is being called
2. Verify ProgressionController has LeaderboardController
3. Check Firestore rules allow writes
4. Check network connectivity

### Issue: Week key incorrect

**Solution:**
1. Verify device system date is correct
2. Check `WeekKey.current()` implementation
3. Check ISO 8601 week calculation

### Issue: Rankings seem wrong

**Solution:**
1. Verify Firestore indexes are active
2. Check query is using `orderBy` + `limit`
3. Verify no client-side sorting
4. Check data consistency

---

## ✅ Final Checklist

- [ ] Code compiled without errors
- [ ] All tests passing
- [ ] Firestore indexes created
- [ ] Firestore rules deployed
- [ ] Navigation integrated
- [ ] Test data created and verified
- [ ] Analytics events verified
- [ ] iOS build successful
- [ ] Android build successful
- [ ] Version bumped
- [ ] Release notes written
- [ ] Uploaded to stores
- [ ] Monitoring configured

---

## 📚 Reference Documents

- [PHASE_3C_COMPLETE.md](PHASE_3C_COMPLETE.md) - Full technical documentation
- [PHASE_3C_QUICKSTART.md](PHASE_3C_QUICKSTART.md) - Quick integration guide
- [PHASE_3C_SUMMARY.md](PHASE_3C_SUMMARY.md) - Implementation summary
- [PROJECT_STATUS.md](PROJECT_STATUS.md) - Overall project status

---

## 🎉 Launch Announcement

**Sample announcement for social media/in-app:**

> 🏆 **NEW: Weekly Leaderboards!**
> 
> Compete with players worldwide in our new ranking system:
> - 🌍 Global XP Rankings
> - 📅 Weekly Fresh Starts
> - 🎭 Most Chaotic Player Award
> - 🏅 Top 3 Celebration
> 
> Every week is a new chance to climb to the top!
> 
> #BUFON #Leaderboards #Update

---

**Deployment Status:** ⏳ Ready for deployment pending final testing

Once checklist is complete, Phase 3C is ready to ship! 🚀
