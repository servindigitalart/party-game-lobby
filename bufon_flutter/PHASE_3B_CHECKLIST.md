# Phase 3B Quick Implementation Checklist

## ✅ Completed

- [x] Achievement model (`lib/models/achievement.dart`)
- [x] Avatar model (`lib/models/avatar.dart`)
- [x] UserProfile model (`lib/models/user_profile.dart`)
- [x] ProgressionController (`lib/domain/controllers/progression_controller.dart`)
- [x] ProgressionException added
- [x] Progression providers created
- [x] Analytics integration
- [x] FinalWinnerScreen integration with progression dialog

## ⚠️ To Complete

### Critical (Required for Phase 3B)
- [ ] Recreate ProfileScreen UI with correct typography
- [ ] Add navigation to ProfileScreen from HomeScreen
- [ ] Update Firestore security rules for `/users/{uid}`

### Integration (Avatar Display)
- [ ] Add avatar emoji to LobbyScreen player list
- [ ] Add avatar emoji to VotingScreen player cards
- [ ] Add avatar emoji to FinalWinnerScreen scoreboard

### Night Pass Integration
- [ ] Call `unlockNightPassAvatar()` in IAPService after purchase
- [ ] Test Night Pass achievement unlock

### Testing
- [ ] Test XP awards after game
- [ ] Test achievement unlocking
- [ ] Test avatar unlocking
- [ ] Test level progression
- [ ] Test profile screen

## 🎯 Quick Wins (Optional)
- [ ] Add confetti animation on level up
- [ ] Add haptic feedback on unlock
- [ ] Add achievement progress indicators
- [ ] Create leaderboard screen

## 📝 Notes

### ProfileScreen Typography Fix
Replace:
- `AppTypography.bodyBold` → `AppTypography.body1.copyWith(fontWeight: FontWeight.bold)`
- `AppTypography.body` → `AppTypography.body1`

### Firestore Rules
```javascript
match /users/{userId} {
  allow read: if request.auth.uid == userId;
  allow create: if request.auth.uid == userId;
  allow update: if request.auth.uid == userId;
}
```

### Avatar Display Pattern
```dart
final profile = ref.watch(userProfileStreamProvider).value;
final avatar = Avatars.getById(profile?.selectedAvatar ?? 'default');

Text(avatar?.emoji ?? '🤡', style: TextStyle(fontSize: 40))
```
