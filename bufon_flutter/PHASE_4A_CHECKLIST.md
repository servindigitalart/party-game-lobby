# Phase 4A - Integration Checklist

**Use this checklist to complete Phase 4A implementation**

## 🔧 Bug Fixes

- [ ] **Fix AppTypography errors in profile_screen.dart**
  - Problem: Using `.body` and `.bodyBold` which don't exist
  - Files: `lib/presentation/screens/profile_screen.dart`
  - Action: Replace with correct typography getters (`.body1`, `.body2`, etc.)

- [ ] **Fix Achievements import in final_winner_screen.dart**
  - Problem: `Achievements` class not imported
  - Files: `lib/screens/final_winner_screen.dart`
  - Action: Add `import '../../models/achievement.dart';`

- [ ] **Remove unused imports**
  - Files: Multiple (check IDE warnings)
  - Action: Remove unused imports to clean up code

## 🎨 UI Integration

- [ ] **Test title selector dialog**
  - Navigate to profile → public profile → change title
  - Verify dialog opens and titles load
  - Test equip/unequip functionality

- [ ] **Test profile card share**
  - Open public profile
  - Tap "Share Profile" button
  - Verify PNG generates and share sheet opens
  - Test on iOS and Android

- [ ] **Test victory card button visibility**
  - Win a game
  - Verify "Share Victory" button appears for winner
  - Verify button doesn't appear for losers

- [ ] **Add title to player lobby display** (Optional)
  - Show equipped title next to player name in lobby
  - Use rarity color for title text

## 📱 Functionality

- [ ] **Implement victory card PNG export**
  - Current: Shows "coming soon" message
  - Solution: Use `OverlayEntry` to render widget off-screen
  - Then capture with `RepaintBoundary`
  - File: `lib/screens/final_winner_screen.dart`

- [ ] **Test title unlock flow end-to-end**
  - Play a game and earn enough XP/wins/votes
  - Verify titles unlock automatically
  - Check Firestore for `titles` subcollection entries
  - Verify analytics events fire

- [ ] **Test title display on profile**
  - Equip a title
  - Navigate away and back
  - Verify title persists
  - Check rarity color displays correctly

## 🔥 Firestore

- [ ] **Deploy title security rules**
  - File: `firestore.rules`
  - Add rules for `users/{uid}/titles/{titleId}` subcollection
  - Allow read if authenticated
  - Allow write only for user's own titles
  - Deploy with `firebase deploy --only firestore:rules`

Example rules:
```javascript
match /users/{userId}/titles/{titleId} {
  allow read: if request.auth != null;
  allow write: if request.auth.uid == userId;
}
```

- [ ] **Test Firestore transactions**
  - Verify title unlocks use transactions correctly
  - Test concurrent unlock attempts (shouldn't duplicate)

## 📊 Analytics

- [ ] **Verify analytics events fire**
  - Use Firebase Console → Analytics → DebugView
  - Test each event:
    - title_unlocked
    - title_equipped
    - profile_viewed
    - profile_shared
    - victory_card_shared
  - Verify parameters are correct

- [ ] **Test analytics with null values**
  - Profile with no title
  - Share profile without title
  - Verify no crashes

## 🧪 Testing

- [ ] **Manual test: Unlock each title**
  - Test all 12 unlock conditions
  - Verify each title unlocks at correct threshold
  - Check leaderboard-based titles (Top 10 Global, etc.)

- [ ] **Manual test: Rarity display**
  - Equip a common title → verify gray
  - Equip a rare title → verify blue
  - Equip an epic title → verify purple
  - Equip a legendary title → verify gold

- [ ] **Manual test: Profile sharing**
  - Share profile with title
  - Share profile without title
  - Verify PNG quality (should be crisp)
  - Test on WhatsApp, Instagram, etc.

- [ ] **Manual test: Edge cases**
  - New user (no titles)
  - User with all titles
  - Long player name (check truncation)
  - Very high XP/level (check formatting)

## 🎭 Polish

- [ ] **Add title unlock celebration**
  - Show dialog when new title unlocks
  - Include confetti animation
  - Show title name, description, rarity
  - "Equip Now" button

- [ ] **Add loading states**
  - Title selector dialog loading
  - Profile card generation loading
  - Victory card generation loading

- [ ] **Add error handling**
  - Title unlock failure
  - PNG generation failure
  - Share cancellation
  - Network errors

- [ ] **Add title unlock notification** (Optional)
  - Show in-app notification when title unlocks
  - Don't block gameplay
  - Subtle banner at top

## 📖 Documentation

- [ ] **Update PROJECT_STATUS.md**
  - Add Phase 4A completion status
  - List new features
  - Update next steps

- [ ] **Create Firestore rules documentation**
  - Document title security rules
  - Explain permissions model

- [ ] **Add code comments**
  - Document complex logic in title_controller
  - Add JSDoc to public methods

## 🚀 Deployment Prep

- [ ] **Test on iOS device**
  - Share functionality
  - PNG generation
  - Analytics tracking

- [ ] **Test on Android device**
  - Share functionality
  - PNG generation
  - Analytics tracking

- [ ] **Performance testing**
  - Measure PNG generation time
  - Check title evaluation performance
  - Monitor Firestore read/write counts

- [ ] **Security review**
  - Verify Firestore rules are secure
  - Check for exposed user data
  - Validate input sanitization

## 📝 Optional Enhancements

- [ ] **Add more titles**
  - Seasonal titles (holiday events)
  - Achievement-based titles
  - Special event titles

- [ ] **Add title preview**
  - Show how title looks before equipping
  - Preview on profile card

- [ ] **Add title collections**
  - Group related titles
  - "Collect all 5 chaos titles"

- [ ] **Add title trading/gifting**
  - Send title to friend
  - Unlock through referral

- [ ] **Add title leaderboard**
  - Who has most titles
  - Rarest title owners

## ✅ Definition of Done

Phase 4A is complete when:

- [x] All 12 titles defined and functional
- [x] Title unlock logic working
- [x] Public profile screen complete
- [x] Title selector dialog complete
- [x] Profile card sharing working
- [ ] Victory card sharing working ← **PENDING**
- [ ] All bugs fixed
- [ ] Analytics verified
- [ ] Firestore rules deployed
- [ ] Tested on iOS and Android
- [ ] Documentation updated

## 🎯 Current Status

**Completed:**
- ✅ Core title system (12 titles)
- ✅ Title controller & providers
- ✅ Public profile screen
- ✅ Title selector dialog
- ✅ Profile card generator
- ✅ Victory card generator (UI only)
- ✅ Analytics integration
- ✅ Progression integration

**In Progress:**
- 🔄 Victory card PNG export
- 🔄 Bug fixes (AppTypography, imports)
- 🔄 Testing

**Pending:**
- ⏳ Firestore rules deployment
- ⏳ Device testing
- ⏳ Polish & celebrations
- ⏳ Production deployment

---

**Next Action:** Fix AppTypography errors, then test on device!

**Estimated Time to Complete:** 4-6 hours
- Bugs: 1 hour
- Victory card fix: 2 hours
- Testing: 2-3 hours
- Deployment: 1 hour
