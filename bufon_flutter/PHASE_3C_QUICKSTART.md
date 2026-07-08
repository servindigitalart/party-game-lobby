# Phase 3C Quickstart: Leaderboards

**5-Minute Integration Guide** ⚡

---

## 🚀 Quick Start

### 1. Navigate to Leaderboards

```dart
// Add button to HomeScreen or ProfileScreen
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LeaderboardScreen(),
      ),
    );
  },
  child: const Text('Rankings'),
)
```

### 2. Leaderboards Update Automatically

No manual integration needed! Leaderboards update automatically when:
- ProgressionController processes game completion
- User gains XP, wins, or votes

### 3. View Top Players

```dart
// In any widget
final topPlayers = ref.watch(
  topPlayersProvider(LeaderboardType.globalXp)
);

topPlayers.when(
  data: (entries) {
    // Display entries
    for (final entry in entries) {
      print('#${entry.rank} - ${entry.nickname}: ${entry.xp} XP');
    }
  },
  loading: () => CircularProgressIndicator(),
  error: (e, _) => Text('Error: $e'),
);
```

### 4. Get User's Rank

```dart
final userId = ref.watch(userIdProvider);
final userRank = ref.watch(
  userRankProvider((userId!, LeaderboardType.weeklyXp))
);

userRank.when(
  data: (entry) => entry != null 
    ? Text('Your rank: #${entry.rank}')
    : Text('Not ranked yet'),
  loading: () => CircularProgressIndicator(),
  error: (_, __) => SizedBox.shrink(),
);
```

---

## 📋 Leaderboard Types

| Type | Description | Stat Tracked |
|------|-------------|--------------|
| `LeaderboardType.globalXp` | All-time XP ranking | Total XP |
| `LeaderboardType.weeklyXp` | This week's XP | Weekly XP gains |
| `LeaderboardType.weeklyVotes` | Most Chaotic | Weekly votes received |
| `LeaderboardType.weeklyWins` | Most wins this week | Weekly wins |

---

## 🔧 Required Setup

### 1. Firestore Indexes

Create composite indexes in Firebase Console:

```
Collection: leaderboards/global_xp/entries
Field: xp
Order: Descending

Collection: leaderboards/weekly_xp/{weekKey}/entries
Field: xp
Order: Descending

Collection: leaderboards/weekly_wins/{weekKey}/entries
Field: totalWins
Order: Descending

Collection: leaderboards/weekly_votes/{weekKey}/entries
Field: totalVotes
Order: Descending
```

**Or** let Firestore auto-create them:
1. Run the app
2. View each leaderboard type
3. Check Firebase Console for index creation links
4. Click to create indexes

### 2. Firestore Security Rules

Add to `firestore.rules`:

```javascript
match /leaderboards/{type}/entries/{uid} {
  allow read: if request.auth != null;
  allow write: if request.auth != null && request.auth.uid == uid;
}

match /leaderboards/{type}/{weekKey}/entries/{uid} {
  allow read: if request.auth != null;
  allow write: if request.auth != null && request.auth.uid == uid;
}
```

Deploy:
```bash
firebase deploy --only firestore:rules
```

---

## 📱 UI Integration Examples

### Add to Navigation

```dart
// In HomeScreen
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

### Add to App Bar

```dart
// In any screen's AppBar
AppBar(
  title: const Text('BUFÓN'),
  actions: [
    IconButton(
      icon: const Icon(Icons.leaderboard),
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

### Custom Leaderboard Widget

```dart
class MiniLeaderboard extends ConsumerWidget {
  const MiniLeaderboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPlayers = ref.watch(
      topPlayersProvider(LeaderboardType.globalXp)
    );

    return topPlayers.when(
      data: (entries) => Column(
        children: entries.take(3).map((entry) {
          return ListTile(
            leading: Text('#${entry.rank}'),
            title: Text(entry.nickname),
            trailing: Text('${entry.xp} XP'),
          );
        }).toList(),
      ),
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
```

---

## 🧪 Testing Locally

### 1. Create Test Data

```dart
// In a test/debug screen
Future<void> populateTestLeaderboards() async {
  final controller = ref.read(leaderboardControllerProvider);
  
  for (int i = 1; i <= 20; i++) {
    await controller.updateLeaderboardsAfterGame(
      uid: 'test_user_$i',
      nickname: 'Jugador $i',
      avatarId: 'default',
      xp: 1000 - (i * 50),
      level: 10 - (i ~/ 5),
      xpGained: 50,
      winsGained: i % 5 == 0 ? 1 : 0,
      votesGained: i % 3,
    );
  }
}
```

### 2. Verify Leaderboards

1. Run the app
2. Navigate to LeaderboardScreen
3. Check all 3 tabs load correctly
4. Verify top 3 podium displays
5. Test pull-to-refresh

### 3. Check Week Key

```dart
final weekKey = ref.watch(currentWeekKeyProvider);
print('Current week: $weekKey'); // e.g., "2026-08"
```

---

## 🎯 Common Use Cases

### Show User's Global Rank in Profile

```dart
// In ProfileScreen
Consumer(
  builder: (context, ref, child) {
    final userId = ref.watch(userIdProvider);
    if (userId == null) return SizedBox.shrink();
    
    final userRank = ref.watch(
      userRankProvider((userId, LeaderboardType.globalXp))
    );
    
    return userRank.when(
      data: (entry) => entry != null
        ? Text('Ranking Global: #${entry.rank}')
        : Text('Sin ranking'),
      loading: () => SizedBox.shrink(),
      error: (_, __) => SizedBox.shrink(),
    );
  },
)
```

### Show Top 3 on Home Screen

```dart
// In HomeScreen
final top3 = ref.watch(
  topPlayersProvider(LeaderboardType.weeklyXp)
);

top3.when(
  data: (entries) => Column(
    children: [
      Text('🏆 Top 3 de la Semana'),
      ...entries.take(3).map((entry) => 
        Text('#${entry.rank} ${entry.nickname} - ${entry.xp} XP')
      ),
    ],
  ),
  loading: () => SizedBox.shrink(),
  error: (_, __) => SizedBox.shrink(),
)
```

### Weekly Reset Notification

```dart
// Check if new week started
final weekKey = ref.watch(currentWeekKeyProvider);
final lastSeenWeek = prefs.getString('last_seen_week');

if (lastSeenWeek != weekKey) {
  // Show notification: "New week started! Fresh rankings!"
  prefs.setString('last_seen_week', weekKey);
}
```

---

## 🐛 Troubleshooting

### Leaderboard Not Updating

**Problem:** Leaderboard doesn't update after game

**Solution:**
1. Check ProgressionController has LeaderboardController injected
2. Verify `processGameProgression` is being called
3. Check Firestore rules allow writes
4. Check network connectivity

### Rank Shows Null

**Problem:** User's rank is null

**Solution:**
1. User needs to play at least one game
2. For weekly leaderboards, user needs activity this week
3. Check user ID is correct
4. Verify Firestore document exists

### Indexes Not Working

**Problem:** "The query requires an index" error

**Solution:**
1. Click the link in the error message
2. Or create indexes manually in Firebase Console
3. Wait 1-2 minutes for indexes to build
4. Refresh the app

### Week Key Incorrect

**Problem:** Week key doesn't match expected format

**Solution:**
1. Verify system date is correct
2. Check `WeekKey.current()` implementation
3. ISO 8601 weeks start on Monday

---

## 📊 Analytics Tracking

All leaderboard events are tracked automatically:

```dart
// These fire automatically:
AnalyticsService.instance.logLeaderboardsUpdated(...);
AnalyticsService.instance.logLeaderboardViewed(...);
AnalyticsService.instance.logLeaderboardRankAchieved(...);
```

View in Firebase Analytics:
1. Go to Firebase Console
2. Analytics → Events
3. Look for `leaderboards_updated`, `leaderboard_viewed`, `leaderboard_rank_achieved`

---

## 🎨 Customization

### Change Podium Colors

```dart
// In leaderboard_screen.dart
Color _getTop3Color(int rank) {
  switch (rank) {
    case 1:
      return Colors.amber;        // Change gold color
    case 2:
      return Colors.grey;         // Change silver color
    case 3:
      return Colors.brown;        // Change bronze color
    default:
      return AppColors.textPrimary;
  }
}
```

### Change Leaderboard Limit

```dart
// Fetch top 100 instead of top 50
final topPlayers = await controller.fetchTopPlayers(
  type: LeaderboardType.globalXp,
  limit: 100,  // Default is 50
);
```

### Add More Leaderboard Types

```dart
// In leaderboard_entry.dart
enum LeaderboardType {
  globalXp,
  weeklyXp,
  weeklyVotes,
  weeklyWins,
  monthlyXp,  // Add new type
}

// Update LeaderboardScreen tabs
TabBar(
  tabs: const [
    Tab(text: 'Global'),
    Tab(text: 'Esta Semana'),
    Tab(text: 'Este Mes'),  // New tab
    Tab(text: 'Más Caótico'),
  ],
)
```

---

## ✅ Deployment Checklist

- [ ] Firestore indexes created
- [ ] Firestore security rules deployed
- [ ] LeaderboardScreen added to navigation
- [ ] Analytics events verified in Firebase Console
- [ ] Tested with real data
- [ ] Performance tested (< 1 second load time)
- [ ] UI reviewed on different screen sizes
- [ ] Error states tested (offline, no data, etc.)

---

## 📚 Next Steps

1. **Test thoroughly** - Play multiple games and check leaderboards
2. **Monitor analytics** - Track engagement metrics
3. **Gather feedback** - See how players respond
4. **Iterate UI** - Adjust based on user feedback

---

## 🎉 You're Done!

Leaderboards are now live in your app. Players can compete, climb the ranks, and see how they stack up each week!

For detailed technical documentation, see [PHASE_3C_COMPLETE.md](PHASE_3C_COMPLETE.md).
