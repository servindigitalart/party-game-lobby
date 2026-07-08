# Phase 4A Quickstart Guide

**Quick reference for using the Title System and Public Profile features**

## For Users

### How to Unlock Titles

Titles unlock automatically as you play:

1. **Play games** - Earn XP, wins, and votes
2. **Check your progress** - View next unlockable titles
3. **Receive notification** - (Coming soon) When title unlocks
4. **Equip your title** - Show it on your profile

### How to Equip a Title

1. Open your profile (home screen → profile tab)
2. Tap the **share icon** (top right)
3. Your public profile opens
4. Tap **"Change Title"** or **"Select Title"**
5. Choose from your unlocked titles
6. Title appears immediately on your profile

### How to Share Your Profile

1. Open your public profile (profile → share icon)
2. Tap the big **"Share Profile"** button at bottom
3. Wait for PNG generation (~1 second)
4. Choose where to share (WhatsApp, Instagram, etc.)

### How to Share Victory

1. **Win a game** 🎉
2. On the victory screen, tap **"Share Victory"**
3. (Coming soon) Victory card generates and shares

## For Developers

### Quick Integration

#### 1. Use Title Providers

```dart
// Watch user's unlocked titles (stream)
final unlockedTitles = ref.watch(userUnlockedTitlesProvider);

// Get equipped title
final equippedTitle = ref.watch(equippedTitleProvider);

// Check if specific title is unlocked
final hasTitle = ref.watch(
  hasTitleUnlockedProvider('agente_caos'),
);

// Get next 3 unlockable titles
final nextTitles = ref.watch(
  nextUnlockableTitlesProvider(3),
);
```

#### 2. Navigate to Public Profile

```dart
// From anywhere in the app
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ProfilePublicScreen(
      userId: userId,
      isOwnProfile: currentUserId == userId,
    ),
  ),
);
```

#### 3. Show Title Selector

```dart
// Show dialog to select title
await showDialog(
  context: context,
  builder: (_) => const TitleSelectorDialog(),
);
```

#### 4. Equip/Unequip Title

```dart
final controller = ref.read(titleControllerProvider);

// Equip a title
await controller.equipTitle('agente_caos');

// Unequip current title
await controller.unequipTitle();
```

#### 5. Generate Profile Card

```dart
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// Generate PNG bytes
final imageBytes = await ShareProfileCard.generateImage(
  avatar: avatar,
  level: profile.level,
  xp: profile.xp,
  totalWins: profile.totalWins,
  totalVotesReceived: profile.totalVotesReceived,
  totalGames: profile.totalGames,
  equippedTitle: equippedTitle,
);

// Save to temp file
final tempDir = await getTemporaryDirectory();
final file = File('${tempDir.path}/profile.png');
await file.writeAsBytes(imageBytes);

// Share
await Share.shareXFiles(
  [XFile(file.path)],
  text: '¡Mira mi perfil en BUFÓN! 🎭',
);
```

### Title System Reference

#### All Titles

| ID | Name | Rarity | Unlock Condition |
|----|------|--------|------------------|
| `npc_grupo` | NPC del Grupo | Common | 100 XP |
| `mitomano` | Mitómano Certificado | Common | 5 games |
| `agente_caos` | Agente del Caos | Rare | 50 votes |
| `rey_drama` | Rey del Drama | Rare | 10 wins |
| `down_bad` | Down Bad Profesional | Rare | 250 XP |
| `viral_grupo` | Viral del Grupo | Rare | 100 votes |
| `arquitecto` | Arquitecto del Desmadre | Epic | 25 wins + 500 XP |
| `corazon_roto` | Corazón Roto Oficial | Epic | 200 votes |
| `maestro_meme` | Maestro del Meme | Epic | 1000 XP |
| `bufon_supremo` | Bufón Supremo | Legendary | Night Pass |
| `leyenda_semanal` | Leyenda Semanal | Legendary | Top 10 weekly |
| `top_10_global` | Top 10 Global | Legendary | Top 10 global |

#### Rarity Colors

```dart
TitleRarity.common      → Colors.grey (0xFF9E9E9E)
TitleRarity.rare        → Colors.blue (0xFF2196F3)
TitleRarity.epic        → Colors.purple (0xFF9C27B0)
TitleRarity.legendary   → Colors.amber (0xFFFFB300)
```

### Common Use Cases

#### Check if User Has Any Titles

```dart
final unlockedTitles = await ref.read(
  userUnlockedTitlesFutureProvider(userId).future,
);

if (unlockedTitles.isNotEmpty) {
  print('User has ${unlockedTitles.length} titles');
}
```

#### Show Title on Player List

```dart
Widget buildPlayerTile(UserProfile profile) {
  final equippedTitle = profile.equippedTitleId != null
      ? Titles.getById(profile.equippedTitleId!)
      : null;

  return ListTile(
    title: Text(profile.displayName),
    subtitle: equippedTitle != null
        ? Text(
            equippedTitle.name,
            style: TextStyle(
              color: Color(equippedTitle.rarity.color),
            ),
          )
        : null,
  );
}
```

#### Manually Unlock Title (Admin/Testing)

```dart
final controller = ref.read(titleControllerProvider);

await controller.unlockTitle(
  titleId: 'bufon_supremo',
  source: 'admin_grant',
);
```

#### Get Progress Toward Next Title

```dart
final nextTitles = await ref.read(
  nextUnlockableTitlesProvider(3).future,
);

for (final (title, progress) in nextTitles) {
  print('${title.name}: ${(progress * 100).toStringAsFixed(0)}% complete');
}
```

### Analytics

All analytics are automatic, but you can manually track:

```dart
final analytics = AnalyticsService.instance;

// When title unlocks (automatic in controller)
await analytics.logTitleUnlocked(
  titleId: 'agente_caos',
  titleName: 'Agente del Caos',
  rarity: 'rare',
  source: 'milestone',
);

// When title equipped (automatic in controller)
await analytics.logTitleEquipped(
  titleId: 'agente_caos',
  titleName: 'Agente del Caos',
  rarity: 'rare',
);

// When profile viewed (automatic in screen)
await analytics.logProfileViewed(
  isOwnProfile: true,
  hasTitle: true,
);

// When profile shared (automatic in share method)
await analytics.logProfileShared(
  hasTitle: true,
  level: 5,
);

// When victory card shared
await analytics.logVictoryCardShared(
  votesReceived: 3,
  roundWins: 2,
);
```

### Firestore Queries

#### Get User's Titles

```dart
final titlesSnapshot = await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .collection('titles')
    .get();

final titles = titlesSnapshot.docs.map((doc) {
  return UnlockedTitle.fromJson(doc.data());
}).toList();
```

#### Check if Title Unlocked

```dart
final titleDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .collection('titles')
    .doc('agente_caos')
    .get();

final hasTitle = titleDoc.exists;
```

#### Get Equipped Title

```dart
final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .get();

final equippedTitleId = userDoc.data()?['equippedTitleId'] as String?;
```

### Testing

#### Test Title Unlock

```dart
// 1. Create test user profile
final profile = UserProfile(
  uid: 'test_user',
  displayName: 'Test',
  selectedAvatar: 'joker',
  xp: 100, // Should unlock "NPC del Grupo"
  totalGames: 5, // Should unlock "Mitómano Certificado"
  // ... other fields
);

// 2. Run evaluation
final controller = ref.read(titleControllerProvider);
await controller.evaluateUnlockedTitles();

// 3. Check unlocked titles
final titles = await controller.getUnlockedTitles('test_user');
expect(titles.length, 2);
```

#### Test Title Equip

```dart
final controller = ref.read(titleControllerProvider);

// Equip
await controller.equipTitle('agente_caos');

// Verify
final profile = await ref.read(
  userProfileFutureProvider('test_user').future,
);
expect(profile.equippedTitleId, 'agente_caos');
```

#### Test PNG Generation

```dart
// This is tricky - needs rendering context
// Best tested in integration tests with actual widget tree
testWidgets('Profile card generates PNG', (tester) async {
  await tester.pumpWidget(MyApp());
  
  // Navigate to profile
  // Tap share button
  // Verify PNG bytes are generated
});
```

### Troubleshooting

#### Titles Not Unlocking

1. Check user's XP/wins/votes in Firestore
2. Verify progression controller is called after game
3. Check title unlock conditions in `title.dart`
4. Look for errors in title controller logs
5. Verify Firestore permissions allow writes to `titles` subcollection

#### Title Not Appearing on Profile

1. Check `equippedTitleId` in user document
2. Verify title ID is valid
3. Check if `Titles.getById()` returns null
4. Verify profile screen is watching the correct provider

#### PNG Not Generating

1. Check if `share_plus` and `path_provider` are installed
2. Verify permissions (iOS: NSPhotoLibraryUsageDescription)
3. Check temp directory is accessible
4. Look for exceptions in PNG generation try/catch
5. Ensure widget is fully rendered before capture

#### Share Not Working

1. Check platform permissions
2. Verify `share_plus` is configured correctly
3. Test with different share targets
4. Check file path is valid
5. Ensure file is not deleted before share completes

### Best Practices

1. **Always use providers** - Don't call controller directly
2. **Handle loading states** - Use `.when()` on AsyncValue
3. **Check for null** - Equipped title can be null
4. **Catch errors** - PNG generation can fail
5. **Track analytics** - Use built-in analytics methods
6. **Test on device** - Share doesn't work in simulator
7. **Clean up temp files** - Delete after sharing
8. **Use transactions** - Prevent race conditions
9. **Non-blocking** - Don't block UI for title evaluation
10. **Haptic feedback** - Add for premium feel

---

## Quick Commands

### View All Titles

```dart
final allTitles = Titles.all; // List<Title>
```

### Filter by Rarity

```dart
final legendaryTitles = ref.watch(
  titlesByRarityProvider(TitleRarity.legendary),
);
```

### Get Title by ID

```dart
final title = Titles.getById('agente_caos'); // Title?
```

### Watch for Title Unlocks

```dart
ref.listen(userUnlockedTitlesProvider, (previous, next) {
  next.whenData((titles) {
    if (previous?.value != null && 
        titles.length > previous!.value!.length) {
      // New title unlocked!
      showTitleUnlockDialog();
    }
  });
});
```

---

## Next Steps

1. Read `PHASE_4A_COMPLETE.md` for full details
2. Test title unlocking in your game
3. Customize title unlock animations
4. Deploy Firestore security rules
5. Add more titles for your game's needs

**Questions?** Check the architecture docs or create an issue.
