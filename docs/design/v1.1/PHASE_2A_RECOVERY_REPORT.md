# PHASE 2A — RECOVERY REPORT

**Date:** 2026-08-10
**Purpose:** Reconstruct exactly how far BUFÓN 1.1 Phase 2A progressed before the
session was lost to an unexpected shutdown. Audit only — nothing was reset,
reverted, cleaned, committed, or modified.

---

## Session recovery status

Phase 2A was **interrupted mid-file, inside `lib/screens/round_result_screen.dart`.**

The evidence is unambiguous: that file imports six modules it never uses
(`app_elevation`, `app_shapes`, `bufon_phase`, `reduced_motion`,
`keyhole_reveal_transition`, `animated_primary_button`) and creates + drives +
disposes an `AnimationController` named `_keyholeController` whose animation is
never attached to any widget. Imports and the controller were written; the
`build()` rewrite that would consume them was not. These are the only six issues
`flutter analyze` reports.

Everything before that file appears finished and coherent. `PHASE_2A_BASELINE.md`
**does not exist** — it was never created. The ten audit documents plus
`REPOSITORY_RESEARCH.md`, `COMPETITIVE_PATTERN_MATRIX.md` and
`BUFON_V1.1_VISUAL_BLUEPRINT.md` all exist (written 2026-08-09 23:47 →
2026-08-10 00:14) and are the Phase 1 deliverables, not Phase 2A.

Nothing is committed. All Phase 2A work lives in the working tree on `main`.

---

## Completed

### 1. Design system activation — COMPLETE
`lib/main.dart` now ships `theme: AppTheme.lightTheme`, `darkTheme:
AppTheme.darkTheme`, `themeMode: ThemeMode.light`. The Butter Bliss system is
the app's real theme for the first time.

### 3. Light mode foundation — COMPLETE
`AppTheme.lightTheme` is live and is the default register. A new
`BufonPhase`/`PhaseScope` mechanism (`lib/core/theme/bufon_phase.dart`, new file,
~200 lines) encodes the per-phase colour registers the design system requires but
`ThemeData` cannot express: 10 phases, each with `accent`, `onAccent`,
`onSurface`, `onSurfaceMuted`, `theme`, and its own `SystemUiOverlayStyle`.

### 4. Typography / offline fonts — COMPLETE
- `google_fonts` **removed** from `pubspec.yaml` and `pubspec.lock`.
- `assets/fonts/PlusJakartaSans-{400,600,700}.ttf` + `OFL.txt` bundled and
  declared in `pubspec.yaml`.
- `app_typography.dart` uses a single `_kBrandFontFamily` const; zero
  `GoogleFonts` references remain anywhere in `lib/` or `test/`.
- SIL OFL licence registered with `LicenseRegistry` in `main.dart` via
  `_brandFontLicenses()`.

### 5. Brand assets — COMPLETE
`assets/brand/isotype.png` + `wordmark.png` are in the Flutter asset pipeline and
declared in `pubspec.yaml`. New `lib/presentation/widgets/brand_mark.dart`
(`BrandMark` / `BrandMark.rounded`) is the single place the asset path is
written, and it is in use (`home_screen.dart:185`, AppBar title).

### 6. App icon — COMPLETE
All five Android `mipmap-*/ic_launcher.png` and all sixteen iOS
`AppIcon.appiconset` PNGs are replaced with real brand artwork (e.g. 1024×1024
went 10 KB → 682 KB). Done by hand — no `flutter_launcher_icons` dependency was
added.

### 10. Profile reachability — COMPLETE
`ProfileScreen` had zero inbound navigation before. `home_screen.dart` now has an
AppBar `person` action → `_openProfile()` → `context.pushFadeSlide(const
ProfileScreen())`, with haptic + tap sound.

### 11. Leaderboard reachability — COMPLETE
Same pattern: `emoji_events` action → `_openLeaderboard()` →
`context.pushFadeSlide(const LeaderboardScreen())`.

### 14. Reduced motion — COMPLETE (for the widgets that own motion)
New `lib/core/theme/reduced_motion.dart` exposes `context.reduceMotion` (reads
both `disableAnimations` and `accessibleNavigation`) and
`context.motion(full:, reduced:)`. Wired into all four animated widgets:
`timer_widget.dart:130`, `confetti_widget.dart:119`, `game_card.dart:164`,
`animated_primary_button.dart:189`.

### 18. Dependency changes — COMPLETE
Exactly one dependency change: `google_fonts` removed. No additions.
`pubspec.lock` is consistent with `pubspec.yaml`.

### 20. Release build verification — COMPLETE (passes)
`flutter build appbundle --release` succeeds. See **Current verification**.

---

## Partial

### 2. Legacy theme migration — PARTIAL
**Exists:** four screens declare a register — `home_screen.dart:177`
(`BufonPhase.home`), `lobby_screen.dart:239` (`lobby`), `game_screen.dart:303`
(`answering`), `voting_screen.dart:242` (`voting`). `AppTheme.legacyTheme` is no
longer reachable from `MaterialApp`; it survives only as the explicit
`BufonPhase.legacy` opt-in.

**Remains:** four screens have **no** `PhaseScope` and still paint legacy dark
tokens while `MaterialApp` now hands them the *light* theme:

| File | Legacy token uses |
|---|---|
| `lib/screens/round_result_screen.dart` | `AppColors.background`, `surface`, `textPrimary`, `gold` |
| `lib/screens/final_winner_screen.dart` | 1 |
| `lib/presentation/screens/profile_screen.dart` | 14 |
| `lib/presentation/screens/leaderboard_screen.dart` | 7 |

⚠️ **This is a live visual-regression risk, not just unfinished work.** Those
four screens now mix hardcoded dark surfaces with light-theme-derived widget
defaults (`Card`, `ListTile`, `Divider`, `AppBar` text). Profile and Leaderboard
are newly reachable as of this same phase, so the mismatch is now user-visible.
The `BufonPhase.legacy` value exists precisely to hold them safely and is not
applied to any of them.

### 7. Splash — PARTIAL
**Exists:** iOS `LaunchImage.png/@2x/@3x` replaced with real artwork
(68 B placeholders → 15 KB / 55 KB / 125 KB). Android `splash_isotype.png`
copied into all five `drawable-*` density buckets (untracked, new).

**Remains:** `android/app/src/main/res/drawable/launch_background.xml` is
**untouched** — still `@android:color/white` with the bitmap item commented out.
The Android splash images are shipped but never referenced, so Android still
launches to a blank white window. `drawable-v21/` also needs the same treatment,
and `values/styles.xml` + `values-night/styles.xml` still use
`Theme.Light.NoTitleBar` defaults.

### 8. KeyholeRevealTransition activation — PARTIAL (this is the interruption point)
**Exists:**
- `keyhole_reveal_transition.dart` relaxed from `StackFit.expand` to a
  child-sized `Stack` with `Positioned.fill` backdrop, specifically so it could
  be embedded in the reveal card's variable-height Column.
- `round_result_screen.dart` gained `SingleTickerProviderStateMixin`, a
  `_keyholeController` on `MotionDurations.revealStage`, `.forward()` at reveal
  stage 1, and `.dispose()`.

**Remains:** `KeyholeRevealTransition` is **never instantiated**. Grep finds the
class name only inside its own definition file. The controller animates nothing;
the transition has still never rendered a frame. The six unused imports in
`round_result_screen.dart` are the staged-but-unused toolkit for the rewrite that
did not happen.

**Files:** `lib/screens/round_result_screen.dart`,
`lib/presentation/transitions/keyhole_reveal_transition.dart`.

### 13. Accessibility foundation — PARTIAL
**Exists:** `Semantics` added to every migrated widget —
`animated_primary_button.dart` (button + label + `excludeSemantics`),
`game_card.dart` (button + *selected* state), `game_progress_widgets.dart`
(`'Ronda X de Y'`), `timer_widget.dart` (`'Quedan N segundos. <urgency>'`),
`brand_mark.dart` (image label 'Bufón', decorative child excluded). New
`AppColors.inkMuted` (#5C574C, ≈7.1:1 on Paper) replaces `inkSoft` (≈3.0:1) for
body-size secondary text; applied on Home.

**Remains:**
- **Zero** `MediaQuery.textScaler` handling anywhere in `lib/` — dynamic type is
  untested and unbounded.
- No `Semantics` on any *screen* — `round_result_screen`, `voting_screen`,
  `game_screen`, `profile_screen`, `leaderboard_screen`,
  `final_winner_screen` have none.
- `inkSoft` → `inkMuted` was swapped on Home only; other call sites not swept.

### 15. Error-copy foundation — PARTIAL
**Exists:** `home_screen.dart:_friendlyRoomError` no longer interpolates
`$error` — raw Dart exception strings can no longer reach a player on Home.

**Remains:** no shared error-copy module was created (no `ErrorCopy`/`error_copy`
anywhere in `lib/`). The fix is local to one method on one screen; `lobby_screen`,
`game_screen`, `voting_screen` and the monetization paths were not swept.

### 17. Motion-system activation — PARTIAL
**Exists:**
- `FadePageRoute` + `context.replaceFade()` + `context.pushAndRemoveAllFade()`
  added to `page_transitions.dart` — the "retreat" transition Capítulo 23
  requires.
- `ConfettiTier` enum (`round`: 50/3 s, `night`: 90/4.5 s) replaces the ad-hoc
  `duration:` parameter.
- `MaterialPageRoute` replaced with `replaceFadeSlide` in `home_screen.dart` (×2)
  and `round_result_screen.dart` (×2).

**Remains:** `FadePageRoute` is defined but **never called** — no site uses
`replaceFade` or `pushAndRemoveAllFade`, so retreat still looks like advance. The
`MaterialPageRoute` sweep did not reach `lobby_screen`, `game_screen`,
`voting_screen`, or `final_winner_screen`.

### 19. Tests — PARTIAL
**Exists:** the existing 145-test suite still passes with zero modifications —
the migration did not break telemetry, monetization, progression, or logging.

**Remains:** **no new test was added for any Phase 2A work.** Nothing covers
`BufonPhase`/`PhaseScope`, `ReducedMotion`, `BrandMark`, `FadePageRoute`,
`ConfettiTier`, the new `Semantics` labels, or `inkMuted` contrast. `test/` is
byte-identical to HEAD.

---

## Not started

### 9. Reveal scoreboard bug — NOT STARTED
`round_result_screen.dart:271-317` renders the full night scoreboard
unconditionally, from `_revealStage == 0`. The `#1` row leaks the winner's
identity before the reveal reaches stage 2, spoiling the engineered 800 ms of
suspense. This is the P1 defect recorded in `MOTION_AUDIT.md:173-178`
(criterion "el scoreboard no es visible hasta que termina la etapa 2 del reveal"
— **fails**), `UX_AUDIT.md:273-276` and `V1.1_GAP_ANALYSIS.md:38`. Zero code
change toward gating it.

Related, also untouched: the winner spotlight is chosen by *round votes*
(`roundSortedPlayers.first`) while the scoreboard sorts by *cumulative score*
(`sortedPlayers`) — the two can disagree, which `UX_AUDIT.md:280` flags.

### 16. Share-card typography/brand foundation — NOT STARTED
`lib/presentation/widgets/share_victory_card.dart` and
`final_winner_screen.dart:_buildOffScreenCard` are **unmodified**. No `BrandMark`,
no bundled-font verification for the rendered PNG, no brand ground. (The card
does now inherit the bundled face indirectly through `AppTypography`, which is
the one thing that improved — but by side effect, not by design.)

---

## Blocked

### 12. Progression / avatar connection — BLOCKED
`round_result_screen.dart:181-190` documents the blocker in-code:
`firestore.rules` restricts `/users/{uid}` reads to `request.auth.uid == userId`,
so a non-winner's device **cannot** read the winner's equipped avatar. The screen
therefore still passes `winnerAvatarId: 'default'`.

The in-code comment asserts *"FinalWinnerScreen resolves it from the signed-in
profile when the viewer is the winner and falls back otherwise."* **That is not
true in the current tree.** `final_winner_screen.dart:97` does a flat
`Avatars.all.firstWhere((a) => a.id == widget.winnerAvatarId)` with no profile
lookup and no viewer check. The comment describes intended work that was not
written. Either the fallback must be implemented or the comment corrected.

Unblocking requires a product/security decision that is not Phase 2A's to make:
either denormalize the equipped avatar id onto the room's player document, or
relax the rule. Flagging, not deciding.

### 7. Splash (Android) — soft-blocked on a decision
Wiring `launch_background.xml` by hand vs. adopting `flutter_native_splash`. The
phase removed a dependency and added none; adding one now is a deliberate call.
The assets are already in place for either path.

---

## Current verification

### `flutter analyze`
```
6 issues found. (ran in 6.8s)

warning • Unused import: '../core/theme/app_elevation.dart'                      • lib/screens/round_result_screen.dart:7:8  • unused_import
warning • Unused import: '../core/theme/app_shapes.dart'                         • lib/screens/round_result_screen.dart:8:8  • unused_import
warning • Unused import: '../core/theme/bufon_phase.dart'                        • lib/screens/round_result_screen.dart:11:8 • unused_import
warning • Unused import: '../core/theme/reduced_motion.dart'                     • lib/screens/round_result_screen.dart:13:8 • unused_import
warning • Unused import: '.../transitions/keyhole_reveal_transition.dart'        • lib/screens/round_result_screen.dart:18:8 • unused_import
warning • Unused import: '.../widgets/animated_primary_button.dart'              • lib/screens/round_result_screen.dart:19:8 • unused_import
```
**0 errors. 6 warnings — all in one file, all the fingerprint of the interruption.**

### `flutter test`
```
00:34 +145: All tests passed!
```
145/145 pass. No test files changed.

### `flutter build appbundle --release`
```
✓ Built build/app/outputs/bundle/release/app-release.aab (51.9MB)
Running Gradle task 'bundleRelease'... 101.3s
exit code 0
```
**Succeeds.** Release signing resolves — `android/key.properties` exists locally
(108 B, gitignored via `android/.gitignore:12`) and
`android/app/build.gradle.kts` now loads it into a real `signingConfigs.release`
instead of signing with debug keys.

Two non-fatal observations:
- **51.9 MB AAB** is large for a party game. Worth a size pass before release —
  the new 682 KB 1024×1024 icon and the brand PNGs are additive but not the
  whole story.
- Gradle emitted a Kotlin incremental-compile cache exception (`lookups.tab`
  storage) from the Flutter tool's own gradle plugin, plus a deprecated
  `minSdkVersion` getter warning. Both are environmental/upstream noise; the
  build completed with exit code 0.
- ⚠️ `build.gradle.kts` will **hard-fail** (`null cannot be cast to non-null type
  kotlin.String`) on any machine or CI runner without `key.properties`. The
  `if (keystorePropertiesFile.exists())` guard protects the *load*, but
  `signingConfigs.create("release")` reads the properties unguarded. Not a
  Phase 2A regression to fix now, but it will bite CI.

---

## Git state

**Branch:** `main`
**HEAD:** `ae65c548cebd3901be8c0858c5411e253ee1628d` — *fix: harden purchase validation and app attestation*
**Commits since:** none. **All Phase 2A work is uncommitted.**

### Modified (41 files)
```
bufon_flutter/pubspec.yaml
bufon_flutter/pubspec.lock
bufon_flutter/lib/main.dart
bufon_flutter/lib/core/theme/app_colors.dart
bufon_flutter/lib/core/theme/app_typography.dart
bufon_flutter/lib/presentation/navigation/page_transitions.dart
bufon_flutter/lib/presentation/transitions/keyhole_reveal_transition.dart
bufon_flutter/lib/presentation/widgets/animated_primary_button.dart
bufon_flutter/lib/presentation/widgets/confetti_widget.dart
bufon_flutter/lib/presentation/widgets/game_card.dart
bufon_flutter/lib/presentation/widgets/game_progress_widgets.dart
bufon_flutter/lib/presentation/widgets/timer_widget.dart
bufon_flutter/lib/screens/game_screen.dart
bufon_flutter/lib/screens/home_screen.dart
bufon_flutter/lib/screens/lobby_screen.dart
bufon_flutter/lib/screens/round_result_screen.dart
bufon_flutter/lib/screens/voting_screen.dart
bufon_flutter/android/app/build.gradle.kts
bufon_flutter/android/app/src/main/res/mipmap-{h,m,xh,xxh,xxxh}dpi/ic_launcher.png   (5 binaries)
bufon_flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png                     (16 binaries)
bufon_flutter/ios/Runner/Assets.xcassets/LaunchImage.imageset/*.png                   (3 binaries)
```
Diff: **1257 insertions, 819 deletions** across 41 files.

### Untracked (27 paths)
```
bufon_flutter/assets/fonts/{OFL.txt,PlusJakartaSans-400.ttf,-600.ttf,-700.ttf}
bufon_flutter/assets/brand/{isotype.png,wordmark.png}
bufon_flutter/lib/core/theme/bufon_phase.dart
bufon_flutter/lib/core/theme/reduced_motion.dart
bufon_flutter/lib/presentation/widgets/brand_mark.dart
bufon_flutter/android/app/src/main/res/drawable-{h,m,xh,xxh,xxxh}dpi/splash_isotype.png
docs/design/Archive.zip
docs/design/v1.1/*.md   (12 Phase 1 audit/blueprint documents)
```

**`docs/design/v1.1/PHASE_2A_BASELINE.md` does not exist and was never created.**

Nothing was staged. Nothing was stashed. No reflog anomalies. No work is
recoverable-but-hidden — the working tree is the complete record.

---

## Recommended resume point

**Finish `lib/screens/round_result_screen.dart`.**

This is the single file the session died inside, it is the only source of the six
analyzer warnings, and it is where three separate Phase 2A items converge:

1. **#8 KeyholeRevealTransition activation** — wrap the reveal card in
   `KeyholeRevealTransition(progress: _keyholeController, …)`. The controller,
   the vsync mixin, the `.forward()` call, the `.dispose()`, and the widget's
   sizing fix are all already in place. Only the `build()` wiring is missing.
2. **#9 Reveal scoreboard bug (P1)** — gate the `'Marcador de la noche'` heading
   and its `ListView` behind `_revealStage >= 2`. `MOTION_AUDIT.md` and
   `V1.1_GAP_ANALYSIS.md` both size this at ~30 min for the game's highest-value
   moment.
3. **#2 Legacy theme migration** — the file already imports `bufon_phase`,
   `app_shapes`, `app_elevation`, `reduced_motion` and `animated_primary_button`
   unused. Wrapping it in `PhaseScope(phase: BufonPhase.reveal, …)` and swapping
   `AppColors.background/surface/textPrimary` + the raw `ElevatedButton` consumes
   every one of them. Analyzer returns to zero.

Doing this one file clears all six warnings, activates a transition that has
never rendered, fixes the P1 defect, and migrates the reveal register — with no
new decisions required.

**Do this before anything else**, because the unused imports currently make
`flutter analyze` non-clean, which masks any warning a subsequent task
introduces.

Runner-up (only if the reveal screen is deferred): wrap `profile_screen.dart`,
`leaderboard_screen.dart` and `final_winner_screen.dart` in
`PhaseScope(phase: BufonPhase.legacy)`. Those three now inherit `lightTheme`
while painting dark tokens, and Profile/Leaderboard became reachable in this same
phase — so the mismatch is shipping to users right now.

---

*Audit only. No files were reset, reverted, checked out, cleaned, committed,
pushed, or modified. No dependencies were installed. Only `flutter analyze`,
`flutter test`, and `flutter build appbundle --release` were executed (the build
wrote `build/`, which is gitignored).*

---
---

# Recovery continuation

**Date:** 2026-08-10 (same day, session resumed after the audit above)
**Scope:** the single resume point identified above — finish
`lib/screens/round_result_screen.dart`. Nothing beyond those three converging
items was implemented. No reset, revert, clean, stash, commit or push.

## What was implemented

### 1. `KeyholeRevealTransition` activated — **COMPLETE**

The brand's declared signature gesture renders frames for the first time since
it was written (commit ca79281).

The stage-1 branch of the answer `AnimatedSwitcher` — previously a bare
`Container` — is now wrapped in the **existing** `KeyholeRevealTransition`,
driven by the **existing** `_keyholeController` that the interrupted session had
already created, started at stage 1 and disposed. The transition itself was not
redesigned, replaced, or given a different animation model.

Wiring, exactly as the blueprint specifies it ("`revealStage` 800 ms, `easeOut`,
origin centre, Graphite backdrop"):

| Blueprint | Implementation |
|---|---|
| `revealStage` 800 ms | `MotionDurations.revealStage` — already on the controller, untouched |
| `easeOut` | new `MotionCurves.reveal` token (see *Files changed*) |
| origin centre | the transition's own default, not overridden |
| Graphite backdrop | `backdropColor: AppColors.graphiteShade` |

Two supporting details:
- A `ClipRRect` on `AppShapes.borderRadiusMd` wraps the transition, so the
  backdrop's corners match the panel's. Without it the mask opened against a
  square hole, which Capítulo 9 ("cero esquinas rectas") forbids.
- **Reduced motion** (Capítulo 28): the mask is fed
  `const AlwaysStoppedAnimation(1.0)` via `context.motion`, which skips the
  keyhole entirely and leaves the surrounding `AnimatedSwitcher`'s cross-fade as
  the whole animation — precisely the "cross-fade simple" the chapter mandates.

The reveal timing and state machine are byte-for-byte unchanged: the 750 ms and
1550 ms timers, `_revealStage`, the haptic escalation and the sound cues were not
touched.

### 2. Scoreboard gated behind stage 2 — **COMPLETE (P1 defect closed)**

`'Marcador de la noche'` and its `ListView` are now inside
`if (_revealStage >= 2)`, with a `Spacer()` in the `else` branch holding the host
CTA at the bottom so the spotlight does not jump when the scoreboard arrives.

**Not built at all** before stage 2, rather than hidden behind `Opacity` or
`Visibility`: an invisible widget is still in the semantics tree, so an
opacity-based "fix" would have looked correct while still spoiling the reveal for
any screen-reader user.

The scoreboard now `Arrive`s from below when it mounts (`MotionDurations.arrive`
+ `MotionCurves.settle`, fade + 24 px rise), per the blueprint's "**Only then**
does the scoreboard `Arrive` from below". Reduced motion gets the end state
directly.

**Nothing about scoring changed.** Winner calculation (`roundSortedPlayers` by
round votes), cumulative ordering (`sortedPlayers` by score), vote counting,
Firestore access, room state, reveal timing and game rules are all untouched —
this is a presentation-only correction. The one non-visual edit is
`List.from(room.players)` → `[...room.players]` on the cumulative list, because
`List.from` erases to `List<dynamic>` and the extracted scoreboard widget needs a
real element type. Same contents, same order.

### 3. Reveal theme migration — **COMPLETE**

`PhaseScope(phase: BufonPhase.reveal)` wraps the whole `roomAsync.when`, not just
the data branch, so the loading and error Scaffolds inherit the register too —
otherwise a slow stream flashed a differently-themed screen mid-round.

Legacy tokens migrated (every one used by this screen; no colour was invented,
all values come from the existing `BufonPhase.reveal` register — Graphite surface,
Butter accent, Ink on accent, Paper on surface):

| Was | Now |
|---|---|
| `Scaffold(backgroundColor: AppColors.background)` | theme (`scaffoldBackgroundColor` → Graphite) |
| `AppBar(backgroundColor: AppColors.surface)` | theme `appBarTheme` (`centerTitle` already true there) |
| `AppColors.goldGradient` + hand-rolled gold shadow | flat `graphitePlus1` + `AppShapes.hairlineBorder(accent)` + `AppElevation.protagonistShadow(accent)` |
| `AppColors.background` as foreground on gold (×7) | `phase.onSurface` / `phase.onSurfaceMuted` / `phase.accent` |
| `AppColors.textPrimary` | `phase.onSurface` |
| `AppColors.gold` (leader tint, avatar, points) | `phase.accent` (Butter) |
| `AppColors.primary` (casino red avatar) | `AppColors.graphite` + `phase.onSurface` |
| `AppColors.surface` / `AppColors.border` (non-host card) | `graphitePlus1` + `AppShapes.hairlineBorder` |
| `BorderRadius.circular(AppSpacing.*)` | `AppShapes.borderRadiusMd` / `borderRadiusXl` |
| bare `ElevatedButton` (no press physics, haptic or sound) | `AnimatedPrimaryButton` |

The winner's name renders at the blueprint's `displayButter` — the accent is
spent on the one word the screen exists to deliver, and on nothing else
(Capítulo 4: one colour protagonist per screen).

Layout and behaviour are preserved; the only structural change is the extraction
of `_NightScoreboard` from `build`, needed because the list is now conditionally
mounted and carries its own entrance.

## Exact files changed

| File | Change |
|---|---|
| `lib/screens/round_result_screen.dart` | All three items. +`_keyholeProgress` (`CurvedAnimation`, disposed), keyhole wired into the stage-1 answer, scoreboard gate, `PhaseScope`, token migration, `_NightScoreboard` extracted, host CTA → `AnimatedPrimaryButton` |
| `lib/core/theme/motion_tokens.dart` | **+1 token**: `MotionCurves.reveal = Curves.easeOut`. The blueprint names `easeOut` for this mask and the six existing curves had no decelerate-only member; `motion_tokens.dart` itself forbids reaching for a raw `Curves.*` at a call site, so the curve was added to the token file rather than inlined in the screen |
| `test/reveal_test.dart` | **New.** 3 tests — see below |

No other file was modified. No dependency was added or removed. No golden
infrastructure, test framework or helper library was introduced.

## Tests

`test/reveal_test.dart` — 3 tests, built on the repository's existing widget-test
pattern (`ProviderScope` + provider overrides + `pumpWidget`), the same shape as
`test/widget_test.dart`. No new framework.

1. **`scoreboard is hidden before reveal stage 2`** — the regression test for the
   P1 defect. The fixture is built so `Sofía` leads the cumulative score, i.e. the
   scoreboard's `#1` row would name the round winner before the spotlight does.
   Asserts the heading and the winner's name are absent at stage 0 *and* at
   stage 1.
2. **`scoreboard becomes visible at reveal stage 2`** — past the 1550 ms timer the
   heading, every player row and the scores are present.
3. **`keyhole mask opens over the answer at stage 1`** — asserts
   `KeyholeRevealTransition` is absent at stage 0, mounted at stage 1, that its
   progress strictly increases between frames, and that it reaches exactly `1.0`
   by the end of the 800 ms stage. This is what makes "the transition renders
   frames" a checkable claim rather than an assertion.

One test-harness note worth recording: the tests pump the reveal in *steps*, not
in one large jump. A single `pump(1050ms)` fires the 750 ms timer and paints the
same frame, so the controller starts with zero elapsed time and the mask reads as
`progress == 0.0`. That is an artifact of fake-async pumping, not product
behaviour — it cost a false alarm during verification and is documented in the
test so it does not cost another.

The tests also pin a phone-shaped 400×900 surface. On the default 800×600 test
window the scoreboard's lazy `ListView` never builds its second row, which made
an early version of test 2 fail for a reason that had nothing to do with the gate.

## Current verification

### `flutter analyze`
```
No issues found! (ran in 5.5s)
```
**All six pre-existing warnings are gone**, and no new one replaced them. Every
import the interrupted session staged is now genuinely consumed —
`app_elevation` (protagonist shadow), `app_shapes` (radii + hairlines),
`bufon_phase` (`PhaseScope` + `context.phase`), `reduced_motion`
(`context.motion` + `context.reduceMotion`), `keyhole_reveal_transition` (the
mask), `animated_primary_button` (the host CTA). One import was added
(`models/player.dart`, for the extracted scoreboard's element type). Nothing was
deleted to silence a warning.

### `flutter test`
```
+148: All tests passed!
```
148/148. The 145 pre-existing tests still pass unmodified; the 3 new ones are the
reveal tests above.

### `flutter build appbundle --release`
```
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from
1645184 to 5728 bytes (99.7% reduction).
Running Gradle task 'bundleRelease'...  319.2s
✓ Built build/app/outputs/bundle/release/app-release.aab (51.9MB)
exit code 0
```
**PASS.** Size is unchanged from the pre-continuation build (51.9 MB) — the size
observation in the audit above still stands and is still out of scope.

## Does `KeyholeRevealTransition` actually render?

**Yes — verified two independent ways.**

1. **Asserted.** Test 3 reads the live widget's `progress.value` across frames:
   absent at stage 0, mounted at stage 1, strictly increasing, exactly `1.0` at
   the end of the 800 ms stage.
2. **Seen.** The screen was rendered to PNG at each stage through a temporary
   harness (with the bundled Plus Jakarta Sans faces loaded so the output was
   legible) and the images were inspected directly. Mid-stage-1 the mask is
   unmistakable: the `graphiteShade` backdrop fills the panel's ends while the
   lighter `graphite` answer panel opens through a circular window in the middle,
   showing `"Algo"`. At stage 2 the mask is fully open and the panel renders as
   an ordinary rounded box. **The temporary harness and its PNGs were deleted
   after inspection** — no golden files, no `tmp_` test, nothing added to the
   suite. `test/` contains exactly one new file.

## Is the scoreboard leak fixed?

**Yes.** Gated on `_revealStage >= 2`, not built before that, and covered by a
named regression test whose fixture is specifically constructed so the leak would
reproduce if the gate were removed. Fase 3F's acceptance criterion — "el
scoreboard no es visible hasta que termina la etapa 2 del reveal" — now holds.
Confirmed in the rendered stage-0 and stage-1 images: nothing below the spotlight
but empty Graphite.

## Is the reveal screen using `PhaseScope` correctly?

**Yes.** `PhaseScope(phase: BufonPhase.reveal)` wraps every branch of
`roomAsync.when`. Descendants read the register through `context.phase` rather
than naming colours; the one place the register is named literally is the screen's
own `build`, which sits *above* the scope it returns and would otherwise read
`legacy` — that is commented in the code so the next reader does not "fix" it.

The rendered stage-2 image confirms the register end to end: Graphite surfaces,
Butter accent on the winner's name / leader row / points, Ink numeral on the
Butter avatar, Paper body text, brand-palette confetti, Butter pill CTA. **No
legacy casino colour appears anywhere on the screen**, and there is no layout
regression or overflow at 400×900.

Reveal joins Home, Lobby, Answering and Voting on a declared register — five of
eight screens. The four-screen gap in the audit above is now three:
`final_winner_screen.dart`, `profile_screen.dart`, `leaderboard_screen.dart`.

## Visual sanity check — results

| # | Check | Result |
|---|---|---|
| 1 | Winner not visible during stage 0 | **PASS** — no name, no scoreboard; only the spotlight's withheld state |
| 2 | Reveal progresses | **PASS** — stage 0 "…" → stage 1 answer → stage 2 author |
| 3 | `KeyholeRevealTransition` visibly renders | **PASS** — circular mask visible mid-stage-1 |
| 4 | Scoreboard appears at stage 2 | **PASS** — arrives from below with all rows |
| 5 | Correct Graphite/Butter semantic context | **PASS** |
| 6 | No legacy casino palette | **PASS** — no gold, no `#E94560`, no `#111111`/`#1A1A2E` |
| 7 | No layout regression | **PASS** — no overflow at 400×900 |

Caveat, stated plainly: this was verified by rendering the widget tree, **not by
playing a live round on a device**. Doing the latter needs a real Firestore room
in the `roundResult` phase with multiple players, which this environment cannot
produce. Every check above holds for the rendered tree; on-device confirmation
during the next playtest is still worth doing. Icons render as filled squares in
the harness (the Material icon font is not loaded in `flutter test`) — a harness
artifact with no product meaning.

## One correction made outside the three items

`round_result_screen.dart` carried a comment, written by the interrupted session,
claiming *"FinalWinnerScreen resolves it from the signed-in profile when the
viewer is the winner and falls back otherwise."* The audit above established that
this is false — `final_winner_screen.dart:97` does a flat
`Avatars.all.firstWhere` on the passed id with no profile lookup and no viewer
check.

The comment was corrected to describe what the code actually does and to point at
this report for the blocker. **No behaviour changed**, and the underlying
progression/avatar security decision was *not* touched — it remains blocked and
out of scope. Leaving a knowingly-false comment in the file being finished would
have misled the next session into thinking the fallback already existed.

## Explicitly not done

Still open on this screen, all deferred by instruction and all recorded in the
blueprint's Reveal section:

- `Hero` transition for the answer arriving from the voting card
- Tweened score counters ("never snap a number")
- A label clarifying that the scoreboard is cumulative while the spotlight is
  by round votes (the two unlabelled sortings)
- `BufonPlaceholder` for the `Error: $error` state
- A "coiled" waiting state for non-hosts
- The pre-reveal engineered silence (blueprint marks this as deliberately
  deferred: the auto-advance timers are synchronisation-adjacent)

And, untouched per instruction: Profile, Leaderboard, share cards, the
progression/avatar decision, splash, CI/CD, release signing, dependencies,
Phase 2B.

## Git state after the continuation

Still `main` @ `ae65c54`, **still nothing committed** — the continuation is
working-tree work like the rest of Phase 2A.

Modified since the audit above: `lib/screens/round_result_screen.dart`,
`lib/core/theme/motion_tokens.dart`.
New untracked: `test/reveal_test.dart`, and this report section.

**Next task (not started):** the audit's runner-up — wrap
`final_winner_screen.dart`, `profile_screen.dart` and `leaderboard_screen.dart`
in `PhaseScope(phase: BufonPhase.legacy)` so the three unmigrated screens stop
inheriting `lightTheme` while painting dark tokens. Profile and Leaderboard
became reachable in this same phase, so that mismatch is user-visible today.
