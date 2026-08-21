# WP6 — Adoption Reconciliation

**Date:** 2026-08-18
**Baseline commit:** `28ae0da fix: support large text in voting and round results`
**Nature:** implementation work package. Nothing committed, staged or pushed.

> **The rule this WP was given:** *no añadir complejidad para justificar que un token exista.*
> Every artifact below ends **adopted with a real call site**, **removed**, or **retained with a
> concrete documented reason**. Three of the six ended in removal. That is the correct outcome, not
> a shortfall — the cheapest way to make a token honest is usually to delete it.

---

## 1. Baseline

| | |
|---|---|
| **HEAD at start** | `28ae0dad8fde08b26b09a5d795fd4cd900fdf366` |
| **origin/main at start** | `28ae0dad8fde08b26b09a5d795fd4cd900fdf366` |
| **Divergence** | none — confirmed before any edit |
| **Working tree at start** | clean except three known untracked files |
| **Tests at start** | **217 passing, 0 failing** |
| **`flutter analyze` at start** | No issues found |
| **`git diff --check` at start** | clean (exit 0) |

Untracked and deliberately **not touched** at any point: `docs/design/Archive.zip`,
`docs/design/v1.1/WP4_RECOVERY_REPORT.md`, `docs/design/v1.1/WP5_RECOVERY_REPORT.md`.

---

## 2. Artifact census

| Artifact | State before | Decision | State after | Evidence / call site |
|---|---|---|---|---|
| **Android splash** | branded `splash_isotype.png` present in 5 density buckets, **referenced by nothing**; launch window inherited `?android:colorBackground` | **ADOPT** | branded butter launch wired in all configs, incl. API 31+ | `values/styles.xml`, `values/colors.xml`, `values-v31/styles.xml`, both `launch_background.xml`; verified in the built APK |
| **`assets/brand/wordmark.png`** | declared in `pubspec.yaml`, **0 call sites**, shipped 96 KB in every install | **REMOVE from bundle** | unbundled; file retained as brand source | `pubspec.yaml` — declaration gone with the reason inline |
| **`pushAndRemoveAllFade`** | defined `page_transitions.dart:98`, **0 call sites** | **ADOPT** | **3 call sites**, every whole-stack exit | `final_winner_screen.dart:389`, `game_screen.dart:66`, `game_screen.dart:545` |
| **`pushAndRemoveAllFadeSlide`** | 3 call sites — all of them semantic retreats using a forward transition | **REMOVE** | gone; **0** forward whole-stack pushes remain | `page_transitions.dart` — replaced by a comment explaining why no forward variant exists |
| **`AppShapes.pill`** | defined `app_shapes.dart:73`, **0 call sites**; a comment claimed it was adopted | **REMOVE + CORRECT** | gone; misleading comment fixed | `app_shapes.dart`, `animated_primary_button.dart:21-23` |
| **`MotionSprings.press`** | defined `motion_tokens.dart:113`, **0 call sites** | **REMOVE** | gone | `motion_tokens.dart` |
| **`MotionSprings.release`** | defined `motion_tokens.dart:120`, **0 call sites** | **REMOVE** | gone | `motion_tokens.dart` |

Net: **2 adopted, 4 removed, 1 comment corrected.** No artifact is left in an "exists but nobody
knows why" state.

---

## 3. Android splash

### Architecture found

| File | Role | State found |
|---|---|---|
| `AndroidManifest.xml` | activity theme `@style/LaunchTheme`, `NormalTheme` meta-data | standard Flutter wiring, correct — **not modified** |
| `values/styles.xml` | `LaunchTheme` / `NormalTheme`, parent `Theme.Light.NoTitleBar` | `NormalTheme` on `?android:colorBackground` → **white** |
| `values-night/styles.xml` | same two themes, parent `Theme.Black.NoTitleBar` | `?android:colorBackground` → **black** |
| `drawable/launch_background.xml` | layer-list | `@android:color/white`, bitmap commented out |
| `drawable-v21/launch_background.xml` | layer-list | `?android:colorBackground`, bitmap commented out |
| `drawable-*/splash_isotype.png` | branded splash mark, 5 densities, 128 dp square | **present since Fase 2A, referenced by nothing** |
| `pubspec.yaml` | — | **no `flutter_native_splash`** — the project uses the stock Flutter launch-screen mechanism |
| `build.gradle` | `minSdk = 23` | so `drawable-v21/` always wins; the base `drawable/` copy is unreachable |

### Is there a white flash? Yes — and a worse black one

The app is pinned to `themeMode: ThemeMode.light` (`main.dart:127`) and Home declares
`BufonPhase.home`, whose register is **not** dark, so its scaffold surface is
`AppColors.paper = #FAFAF7`. That is the first colour Flutter paints, on every device, regardless of
the OS theme.

The launch window resolved to something else in **both** OS themes:

| OS theme | Launch window before | Flutter's first frame | Result |
|---|---|---|---|
| Light | `#FFFFFF` (`Theme.Light.NoTitleBar`) | `#FAFAF7` | subtle white flash |
| **Dark** | **`#000000`** (`Theme.Black.NoTitleBar`, via `values-night`) | `#FAFAF7` | **black → near-white flash** |

The dark-mode case is the severe one and it was structural: the project shipped a night launch
theme for an app that has no night mode.

### Change made

1. **`values/colors.xml`** *(new)* — two colours, both measured rather than invented:
   - `bufon_splash` = **`#F9F367`**, sampled from `splash_isotype.png`'s own edge pixels; it is the
     dominant edge value in **all five** density buckets. Deliberately *not* `AppColors.butter`
     (`#F8EE67`) — the mark is an opaque square, so what hides its edge is matching the **asset**,
     not the token it was exported from.
   - `bufon_surface` = **`#FAFAF7`** = `AppColors.paper` = Flutter's actual first frame.
2. **`launch_background.xml`** (both `drawable/` and `drawable-v21/`) — layer-list of
   `@color/bufon_splash` plus the centred `@drawable/splash_isotype` bitmap. The previously
   commented-out bitmap slot is now used, by the asset that was already sitting there.
3. **`values/styles.xml`** — `NormalTheme` pinned to `@color/bufon_surface` instead of
   `?android:colorBackground`, so the window→first-frame handoff is a no-op.
4. **`values-night/styles.xml`** — **deleted.** An app that always renders its light register must
   not declare a dark launch appearance. Deleting is what makes night devices inherit the (now
   correct) light launch; keeping a night file would have required a `values-night-v31` twin to stay
   consistent, because Android ranks the `night` qualifier above the version qualifier.
5. **`values-v31/styles.xml`** *(new)* — Android 12+ draws the launch screen through the platform
   `SplashScreen` API and **ignores `windowBackground`**, so the branded launch is declared again in
   its own vocabulary via `android:windowSplashScreenBackground`.

### Asset/theme used

Existing `splash_isotype.png` (5 densities) and, on API 31+, the existing `@mipmap/ic_launcher`,
which is already the same jester on the same butter. **No new brand variant was created and no PNG
was authored, edited or regenerated.**

On API 31+ only the *background* is set. `windowSplashScreenAnimatedIcon` was deliberately left
unset: the platform masks that icon into a circle, `splash_isotype` is a full-bleed square whose hat
points reach toward the corners, and there is no emulator here to confirm the mask does not clip
them. The system's own choice of `ic_launcher` is already the right mark. This is a Stop-2
judgement — the uncertain, unverifiable half was not improvised.

### Verification actually performed

`flutter build apk --debug` **succeeded**, so AAPT2 compiled and linked every new resource. Dumping
the built APK confirms what shipped:

```
color/bufon_splash    () #fff9f367
color/bufon_surface   () #fffafaf7

style/LaunchTheme
  ()    size=1  0x01010054=@drawable/launch_background         # windowBackground
  (v31) size=2  0x01010054=@drawable/launch_background
                0x0101062c=@color/bufon_splash                 # windowSplashScreenBackground
style/NormalTheme
  ()    size=1  0x01010054=@color/bufon_surface

res/drawable-{m,h,xh,xxh,xxxh}dpi-v4/splash_isotype.png        # all 5 densities packaged
```

Two things worth reading off that dump: there is **no `-night` configuration** on either theme, which
is the dark-mode black launch being gone; and `drawable/launch_background` resolved to
`res/drawable-v21/…` only, confirming the base copy is unreachable at `minSdk 23` (it was updated
anyway so the two never disagree).

### What remains unvalidated on a real device

**The visual result is NOT verified.** Resources compile, link, package and carry the intended
values — that is a build-level fact, not a visual one. See §10.

---

## 4. Wordmark

**REMOVED from the bundle — no natural adoption site exists yet.**

`assets/brand/wordmark.png` was declared at `pubspec.yaml:78` and referenced from **zero** Dart
files. Three independent reasons blocked adoption, any one of which was sufficient:

1. **It is blocked on a decision that is not mine to make.** The asset reads **BUFON**; every string
   in the app reads **BUFÓN**. `BUFON_V1.1_VISUAL_BLUEPRINT.md` §556 records this as *"unresolved and
   needing an owner's decision"*, and lists its own adoption item **I5 as "Blocked on the
   BUFON/BUFÓN accent decision."* Shipping it would have silently answered that question.
2. **It would worsen Home's hierarchy, which the brief forbids.** The PNG is **opaque butter**
   (verified: no alpha channel, background `#F9F36A`-ish). Home's surface is Paper `#FAFAF7`; butter
   is Home's *accent*, not its ground. Adoption means a hard-edged yellow rectangle on near-white.
3. **The slot it would take is a semantic heading.** Home's headline is
   `Semantics(header: true, Text('BUFÓN', display))` — a real screen-reader landmark. An image cannot
   be a heading with text content, and the app bar already carries the identity anchor
   (`BrandMark(size: 36)`, the isotype).

**What changed:** the `pubspec.yaml` declaration is gone, with the reasoning recorded inline. That
removes ~96 KB of never-rendered payload from every install — the only cost the asset was actually
imposing.

**What did not change:** the `.png` stays in the repo as brand source material. This is the third
destination the brief allows, used narrowly and on purpose: the file is an input to a pending owner
decision and to the share-card work (Capítulo 31) that names it as a dependency. Deleting brand
source to win a tidiness point would destroy something that costs nothing to keep once it is out of
the bundle. Re-adding the line is a one-line change the moment the accent question is answered.

---

## 5. Navigation transitions

### Before

`FadePageRoute` exists because Capítulo 23 asks for it: *"las transiciones de salida/retroceso
(salir de una sala, volver a Home) usan un fade simple sin slide, para que se sientan claramente
distintas de 'avanzar en el juego'."*

| Helper | Call sites before |
|---|---|
| `pushAndRemoveAllFade` (retreat, whole stack) | **0** |
| `pushAndRemoveAllFadeSlide` (forward, whole stack) | 3 |
| `replaceFade` (retreat) | 1 — `lobby_screen.dart:111` |

Every whole-stack exit in the app used the **forward** transition, so leaving a room felt identical
to advancing a round — the exact failure the retreat route was written to fix.

### After

| Helper | Call sites after |
|---|---|
| `pushAndRemoveAllFade` | **3** |
| `pushAndRemoveAllFadeSlide` | **removed** |
| `replaceFade` | 1 (unchanged) |
| `pushFadeSlide` / `replaceFadeSlide` (forward, correctly) | 2 / 8 (unchanged) |

### Flows changed — all three are retreats by the doc's own definition

1. **`final_winner_screen.dart:389` (`_exitToHome`)** — "finishing a night". The night is over and
   the player steps out of the experience.
2. **`game_screen.dart:66` (`_navigateToHomeWithMessage`)** — "leaving a room". The player is being
   put back out of the game (kick, room lost, error).
3. **`game_screen.dart:545`** — the error placeholder's *"Volver al Inicio"*. This one was not even
   on a Bufón transition: it used a raw `MaterialPageRoute`, so abandoning a lost room animated with
   the **platform default**. It now matches every other way out of a room.

No other navigation was touched. Forward moves (`replaceFadeSlide` between game phases,
`pushFadeSlide` to Profile/Leaderboard) are semantically advances and were left alone.

### Why the forward whole-stack helper was removed rather than kept

Adopting the retreat at all three sites left `pushAndRemoveAllFadeSlide` at **zero** call sites — the
very condition WP6 exists to eliminate, newly created by WP6 itself. Clearing the entire stack only
ever happens on the way back to Home, and that is a retreat by definition, so no legitimate forward
case remained. It was deleted, with a comment where it stood so the next reader does not re-add it.

### Reduced motion

Not worsened, and structurally improved: a plain fade is **strictly less motion** than a
fade-plus-slide, so every changed exit now moves less than before at both settings. Navigation is
asserted to complete correctly under `disableAnimations: true` by a dedicated test. Stack semantics
are unchanged — the same `pushAndRemoveUntil(..., (route) => false)` contract, only the route's
transition differs. No navigation was duplicated and no game logic was touched.

---

## 6. `AppShapes.pill`

**REMOVED, and a misleading comment corrected.**

**State before.** Defined at `app_shapes.dart:73` as `static const ShapeBorder pill = StadiumBorder()`
with **zero** call sites. Worse, `animated_primary_button.dart:22` claimed
*"`AppShapes.pill` existed and had zero call sites"* in a bullet describing the button's pill shape —
which reads as *"and now it is adopted."* It never was.

**The decisive finding.** The two surfaces in this app that genuinely *are* pills —
`animated_primary_button.dart:229` and `game_progress_widgets.dart:45` — both already render a pill,
and both do it with **`AppShapes.borderRadiusFull`**. They are not ignoring the shape system; they
are using the right member of it. They draw with a `BoxDecoration`, which takes a `BorderRadius`,
and `pill` is a `ShapeBorder` — **the wrong type for both natural call sites.**

Adopting the token would have meant converting a working `BoxDecoration` into a `ShapeDecoration`
purely so a token could claim a call site: added complexity in service of a token, which is the one
thing this WP was told not to do (Stop 3). Deleted instead. `borderRadiusFull` is the pill in this
codebase, and the button's doc comment now says so.

No border radii were migrated. `radiusFull`/`borderRadiusFull` are untouched and still used.

---

## 7. `MotionSprings`

**Census: 2 tokens, both REMOVED.**

| Token | Call sites | Decision | Justification |
|---|---|---|---|
| `MotionSprings.press` | **0** | **REMOVED** | see below |
| `MotionSprings.release` | **0** | **REMOVED** | see below |

The class documented its own intended use: *"widgets that want a real physics simulation
(`SpringSimulation`) instead of a `Tween`+`Curve` — useful for gesture-driven interactions (e.g. a
draggable card) where the animation needs to react to velocity."*

**Bufón has no gesture-driven interaction at all.** A sweep of `lib/` for `SpringSimulation`,
`Draggable`, `Dismissible`, `onPanUpdate` and velocity-reactive handlers returns nothing. The only
`velocity` in the codebase belongs to `confetti_widget.dart`, which runs a hand-rolled particle
simulation over raw doubles — not a `SpringDescription`, and not something a spring preset could
express.

So the tokens had zero adoption **and** zero adoption candidate. Every animation in the app is a
declarative `Tween`+`Curve` over a known duration, which is the correct mechanism for motion that is
not reacting to a finger. Adopting these would have required **inventing a gesture interaction** —
squarely Stop 3. Removed, with a comment recording the reasoning and the fact that the values are
one `git show` away if a draggable surface is ever designed.

**Explicitly not touched:** `MotionDurations`, `MotionCurves`, `MotionScale`, `MotionPhysics`. These
were out of this WP's named scope and were not audited for adoption. **No existing curve was
replaced by a spring, and no `Curves`/`Tween`/`AnimationController` was migrated.**

---

## 8. Tests

| | |
|---|---|
| **Baseline** | **217** |
| **New (WP6)** | **3** |
| **Total** | **220 passing, 0 failing** |

New file: `test/retreat_transition_test.dart` — three tests over the exit contract.

1. `leaving the ceremony retreats to Home and clears the stack` — destination (`HomeScreen` present,
   `FinalWinnerScreen` gone) and stack (`navigator.canPop() == false`).
2. `leaving the ceremony uses the retreat route, not the forward one` — the route pushed is a
   `FadePageRoute`, not a `FadeSlidePageRoute`, captured through a `NavigatorObserver`.
3. `the exit still completes under reduced motion` — same destination and stack contract with
   `disableAnimations: true`.

**On test 2 and the "don't test implementation details" rule.** The brief allows testing a
transition's identity when *"el contrato de transición dependa de ello."* It does here: retreat
versus forward **is** the entire contract this WP adopted, and it is invisible to any
destination-level assertion. The test names the route class, not a curve, a duration or an offset.

**These tests were written before the change and failed against it** — test 2 reported
`FadeSlidePageRoute … is not an instance of FadePageRoute`, which is precisely the defect. Tests 1
and 3 passed before and after, as they should: destination and stack were never broken, only the
transition's meaning was.

**No existing test was modified.** Two pre-existing conditions are consumed rather than fixed, both
documented in the test file: the `ShareVictoryCard` overflow (out of scope by explicit instruction,
and consumed with an assertion so any *other* exception still fails), and the default 800×600 test
viewport, which puts the ceremony's CTA below the fold — the harness sets a 390×844 viewport instead.
No bug was frozen as expected behaviour.

Removals (`AppShapes.pill`, `MotionSprings`, `pushAndRemoveAllFadeSlide`) intentionally get no
tests: they were unreferenced, and `flutter analyze` proves nothing referenced them. The wordmark
removal gets none for the same reason the brief gives.

---

## 9. Analyze / test / diff

### `flutter analyze`
```
Analyzing bufon_flutter...
No issues found! (ran in 9.9s)
```

### `flutter test`
```
01:07 +220: All tests passed!
exit code: 0
```

### `git diff --check`
```
(no output) — exit 0
```

### `dart format --output=none --set-exit-if-changed <WP6 files only>`
```
Changed lib/screens/final_winner_screen.dart
Changed lib/core/theme/motion_tokens.dart
Formatted 7 files (2 changed) — exit 1
```

**This is pre-existing and was deliberately not "fixed".** Both files were already
format-dirty **at `28ae0da`**, verified by running the formatter against `git show HEAD:<file>`. The
lines the formatter wants to change are all code WP6 never touched:

- `final_winner_screen.dart` — a `ConfettiWidget(...)` call and an avatar `Text(...)`
- `motion_tokens.dart` — the four `MotionDurations` per-component constants and
  `MotionScale.celebrationOvershoot`

An earlier attempt did run the formatter over these two files. It reformatted those unrelated lines,
so that attempt was reverted and both edits were re-applied on top of the pristine `HEAD` content —
leaving each diff confined to WP6's own change. Formatting the repo's pre-existing drift is not this
WP's job, and doing it would have buried a 4-line behavioural change in unrelated churn. Every line
**WP6 added** is format-clean; the other five modified Dart files pass the check outright.

---

## 10. Manual verification required

Stated plainly: **nothing below was visually verified, and none of it is claimed to be.**

1. **Android splash on a real device or emulator — REQUIRED, NOT DONE.** No Android device or
   emulator is available in this environment. What *was* verified is a build-level fact: the APK
   compiles, links and packages the intended resources with the intended values (§3). Still to check
   on hardware:
   - the butter ground and the centred jester render as intended, and the bitmap's edge is genuinely
     invisible against `#F9F367` at each density;
   - **an OS-dark-mode device no longer launches black** — the single most important outcome here;
   - **API 31+ specifically**, where the platform draws its own splash and the mask around
     `ic_launcher` is worth eyeballing;
   - the butter → Paper handoff into Home reads as a designed launch rather than a flash.
2. **The three changed exit transitions.** Automated tests cover destination, stack, route identity
   and reduced motion. Whether the fade *feels* like a retreat is a judgement only a human on a
   device can make.
3. **No golden-test infrastructure was added**, per the brief.

No screen's layout was modified, so no before/after render comparison applies: the changed Dart is
four navigation call sites, three deletions and two comments.

---

## 11. Explicit non-goals — confirmed untouched

| Area | Confirmation |
|---|---|
| **Game logic** | Untouched. No change to vote handling, scoring, rounds, reveal staging, timers or phase transitions. The only screen edits are navigation call sites. |
| **Firebase / backend** | Untouched. No repository, service, transaction, security rule or Firestore call modified. |
| **Repositories / controllers / providers** | Untouched. |
| **Text scaling policy** | Untouched. The global `MediaQuery.withClampedTextScaling(1.0, 1.4)` band and all WP5 layout work are exactly as committed at `28ae0da`. |
| **WP4 / WP5 recovery reports** | Untouched. Both remain untracked with their original content. |
| **`Archive.zip`** | Untouched. Never opened, moved or extracted. |
| **`ShareVictoryCard`** | Not reopened. Its pre-existing overflow is *consumed* by the new test, never fixed or masked. |
| **Dependencies** | None added, removed or upgraded. `pubspec.yaml`'s only change is deleting one asset line; `pubspec.lock` is unmodified. No splash plugin was introduced. |
| **Design tokens** | No new token created. Three dead ones deleted. No colour, spacing, typography or radius value changed. |
| **iOS** | Untouched. The Android launch fix needed nothing from the shared layer, so nothing in `ios/` was modified. |
| **Repo-wide formatting** | Not run. The formatter was invoked only against files this WP modified. |

### Files changed

**Modified (11):**
```
android/app/src/main/res/drawable-v21/launch_background.xml
android/app/src/main/res/drawable/launch_background.xml
android/app/src/main/res/values/styles.xml
lib/core/theme/app_shapes.dart
lib/core/theme/motion_tokens.dart
lib/presentation/navigation/page_transitions.dart
lib/presentation/widgets/animated_primary_button.dart
lib/screens/final_winner_screen.dart
lib/screens/game_screen.dart
pubspec.yaml
```
**Deleted (1):** `android/app/src/main/res/values-night/styles.xml`
**New (3):** `android/app/src/main/res/values/colors.xml`,
`android/app/src/main/res/values-v31/styles.xml`, `test/retreat_transition_test.dart`

Total: 83 insertions, 79 deletions across the modified set. The work package **removes almost as
much as it adds**, which is what reconciliation should look like.

---

## 12. Final verdict

### **COMPLETE WITH MANUAL DEVICE VERIFICATION REQUIRED**

All five investigated areas are resolved and every artifact has an explicit destination. Analyze is
clean, 220/220 tests pass, `git diff --check` is clean, and the Android resources are verified as far
as a build can verify them — they compile, link and package with the correct values.

It is **not** rated COMPLETE for one honest reason: the Android splash is a **visual** change and no
Android device or emulator exists in this environment. Every claim made about it here is derived from
configuration and from the built APK's resource table. The XML is verified; the pixels are not. That
gap is real, it is the only one, and it is the reason for the qualifier rather than a formality.

**Commit-ready:** yes, pending the device check in §10. Nothing was committed, staged or pushed.
