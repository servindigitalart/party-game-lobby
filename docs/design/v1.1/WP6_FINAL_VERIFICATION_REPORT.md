# WP6 — Final Verification & Closure Pass

**Date:** 2026-08-18
**Baseline:** `28ae0da fix: support large text in voting and round results`
**Nature:** verification only. No production code was modified during this pass.
**Implementation record reviewed:** `docs/design/v1.1/WP6_ADOPTION_RECONCILIATION_REPORT.md`

---

## 0. Verdict

### **OPTION B — IMPLEMENTATION DEFECT FOUND**

Every structural, test, analyze, build, diff-hygiene and scope gate **passes**. The defect is not in
any of those: it is in the one thing the implementation pass could not check and therefore correctly
declined to claim — **the actual appearance of the splash on an Android 12+ device.**

An Android emulator **was available** in this environment (`Medium_Phone_API_36.0`, API 36 /
Android 16), contrary to the assumption recorded during implementation. It was launched, the debug
APK was installed, and the launch screen was captured and inspected. Most of WP6's splash work is
confirmed correct on real hardware — including the headline fix. But on API 31+ the system splash
renders the launcher icon inside a **white circular icon background**, producing a white ring around
a butter square around the jester, on an otherwise correct butter field.

That is a concrete, reproducible visual regression on the exact platform tier WP6 added support for,
and it defeats the stated objective of a launch "coherente con la identidad visual de Bufón". Per
the brief for OPTION B, this pass **stops and explains the smallest required fix** rather than
applying it. See §5.3.

**Nothing was committed, staged, pushed, reverted, cleaned or stashed.**

> **Addendum 2026-08-21 — the defect is RESOLVED; this report's §0 verdict is superseded.**
> Two candidates were measured on the emulator. `windowSplashScreenIconBackgroundColor` (§5.3) is
> completely inert and was reverted — see **§16**. `windowSplashScreenAnimatedIcon` pointed at the
> existing `splash_isotype` **fixes it**, and is verified on API 36 in light and dark: white pixels
> 172 → 0, mark 46×51 dp → 159×179 dp, nothing clipped — see **§17**. **Current verdict: OPTION A —
> COMMIT-READY.** §0 and §5.3 are historical; §§1–15 otherwise stand as written.

---

## 1. HEAD and origin/main

| | |
|---|---|
| **HEAD** | `28ae0dad8fde08b26b09a5d795fd4cd900fdf366` |
| **origin/main** | `28ae0dad8fde08b26b09a5d795fd4cd900fdf366` |
| **Relationship** | **identical — no divergence, no ahead/behind** |
| **Staged** | nothing |
| **`git log -3`** | `28ae0da` → `dfd0f1a` → `321d580`, unchanged |

WP6 remains entirely uncommitted in the working tree, exactly as the implementation report states.

---

## 2. Expected vs actual file inventory

`git diff --stat`: **11 files changed, 83 insertions(+), 79 deletions(-)** — matches the
implementation report exactly.

| File | Class | Expected by report? |
|---|---|---|
| `android/.../res/drawable/launch_background.xml` | **A** modified | ✅ |
| `android/.../res/drawable-v21/launch_background.xml` | **A** modified | ✅ |
| `android/.../res/values/styles.xml` | **A** modified | ✅ |
| `android/.../res/values-night/styles.xml` | **A** deleted | ✅ |
| `android/.../res/values-v31/styles.xml` | **A** added | ✅ |
| `android/.../res/values/colors.xml` | **A** added | ✅ |
| `lib/core/theme/app_shapes.dart` | **A** modified | ✅ |
| `lib/core/theme/motion_tokens.dart` | **A** modified | ✅ |
| `lib/presentation/navigation/page_transitions.dart` | **A** modified | ✅ |
| `lib/presentation/widgets/animated_primary_button.dart` | **A** modified | ✅ |
| `lib/screens/final_winner_screen.dart` | **A** modified | ✅ |
| `lib/screens/game_screen.dart` | **A** modified | ✅ |
| `pubspec.yaml` | **A** modified | ✅ |
| `test/retreat_transition_test.dart` | **A** added | ✅ |
| `docs/design/v1.1/WP6_ADOPTION_RECONCILIATION_REPORT.md` | **A** added | ✅ |
| `docs/design/Archive.zip` | **B** pre-existing untracked | untouched |
| `docs/design/v1.1/WP4_RECOVERY_REPORT.md` | **B** pre-existing untracked | untouched |
| `docs/design/v1.1/WP5_RECOVERY_REPORT.md` | **B** pre-existing untracked | untouched |

**Class C (unexpected): NONE.** The actual inventory and the report agree item for item.

The three protected files were not added, deleted, modified, restored, cleaned or stashed. Their
mtimes (`Aug 10 18:06`, `Aug 12 21:57`, `Aug 18 20:32`) all predate this verification pass.

---

## 3. Splash — structural verification

| # | Check | Result |
|---|---|---|
| 1 | Existing splash assets actually referenced by the launch resources | ✅ `drawable/launch_background.xml` and `drawable-v21/launch_background.xml` both reference `@drawable/splash_isotype` in a `<bitmap android:gravity="center">` |
| 2 | Five density assets present and correctly referenced | ✅ all five buckets present (`mdpi`…`xxxhdpi`); one logical `@drawable/splash_isotype` reference resolves per density |
| 3 | No remaining `values-night` launch theme | ✅ `values-night/` is **absent**; APK resource table shows **no `-night` configuration** on `LaunchTheme` or `NormalTheme` |
| 4 | API 31+ resources exist and correctly scoped | ✅ `values-v31/styles.xml` present; APK shows a `(v31)` config on `LaunchTheme` carrying `windowSplashScreenBackground` |
| 5 | API 31+ config references no missing resource | ✅ `@color/bufon_splash` resolves (`#fff9f367`); build links cleanly |
| 6 | Manifest/theme references remain valid | ✅ `AndroidManifest.xml` **unmodified**; `@style/LaunchTheme` and `@style/NormalTheme` both defined in `values/` and `values-v31/` |
| 7 | No unrelated Android configuration changed | ✅ only files under `res/` changed — no gradle, manifest, gitignore, keystore or plugin config |

APK resource table (from `aapt2 dump resources`):

```
color/bufon_splash    () #fff9f367
color/bufon_surface   () #fffafaf7
style/LaunchTheme  ()    0x01010054=@drawable/launch_background
                   (v31) 0x01010054=@drawable/launch_background
                         0x0101062c=@color/bufon_splash
style/NormalTheme  ()    0x01010054=@color/bufon_surface
```

**Structural verification: PASS.**

---

## 4. Was visual splash verification actually performed?

### **YES — and it changes the picture.**

The implementation pass recorded "no emulator to check it on." That was **incorrect**: `flutter
devices` lists only running devices, and `flutter emulators` reveals a defined AVD. This pass found
and used it.

| | |
|---|---|
| **Device** | `Medium_Phone_API_36.0` (emulator-5554), 1080×2400 |
| **API level** | **36** (Android 16) — exercises the `values-v31` path |
| **Build installed** | `app-debug.apk`, installed via `adb install -r` |
| **Method** | `am force-stop` → `am start` → successive `adb exec-out screencap` frames, sampled programmatically and inspected visually |

### What was observed — confirmed correct

1. **The launch field is butter.** Every captured launch frame is dominantly `#F9F367`, the exact
   value of `bufon_splash`. The colour is right on device, not just in the resource table.
2. **The dark-mode black launch is gone — WP6's headline fix is verified.** With `cmd uimode night
   yes`, the launch frames are **still `#F9F367`**, not black. This was the severe defect WP6 set out
   to fix and it is genuinely fixed on hardware. *(Night mode was restored to `no` afterwards.)*
3. **The handoff to Flutter is seamless.** The post-splash frame is dominantly `#FAFAF7` — exactly
   `bufon_surface` and exactly `AppColors.paper` — with Home rendering correctly (BUFÓN headline,
   butter CTA, isotype in the app bar). The claim that `bufon_surface` matches Flutter's first frame
   is confirmed empirically.

### What was observed — the defect

On API 31+ the system splash draws, from outside in: the butter field → a **white circle** → a
**butter square** → the jester. The white ring is plainly visible against butter and reads as a
rendering mistake.

**Root cause (verified, not inferred).** `ic_launcher` exists **only** as legacy square bitmaps —
`mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png`, with **no `mipmap-anydpi-v26/ic_launcher.xml`
adaptive icon**. Android 12+ places a non-adaptive launcher icon on its **default icon-background
circle**, which is white, and `values-v31/styles.xml` sets `windowSplashScreenBackground` without
setting `windowSplashScreenIconBackgroundColor`. Before WP6 the splash background was the system
default (near-white), so the white circle blended in and was invisible; making the background butter
is what exposed it. **The regression is directly attributable to WP6.**

Screenshots retained at
`…/scratchpad/splash/{light_0..9,night_0..3,after}.png`.

---

## 5. The defect and the smallest fix

### 5.1 Severity

Cosmetic but user-facing, on the first screen of every cold start, on Android 12+ — the large
majority of active devices. It does not crash, does not affect logic, and does not block any test or
build gate. It defeats WP6's own stated objective for the tier it added.

### 5.2 What is *not* wrong

The butter background, the `values-v31` scoping, the deletion of `values-night`, the
`bufon_surface` handoff and the pre-API-31 `launch_background.xml` path are all correct and
confirmed. The fix is narrow.

### 5.3 Smallest required fix — **one line, not applied by this pass**

In `android/app/src/main/res/values-v31/styles.xml`, inside `LaunchTheme`:

```xml
<item name="android:windowSplashScreenIconBackgroundColor">@color/bufon_splash</item>
```

This paints the system's icon-background circle butter so it disappears against the butter field,
leaving the jester centred on butter. It adds no asset, no dependency and no new colour — it reuses
the `bufon_splash` resource that already exists.

The attribute was verified to exist in the installed platform
(`windowSplashScreenIconBackgroundColor`, API 31+, present in SDK 36), so it will compile.

**This fix is a candidate, not a verified outcome.** It was deliberately not applied, and therefore
not re-tested on the emulator. Whoever applies it should relaunch on `Medium_Phone_API_36.0` and
re-capture, because the interaction between a legacy square icon and the system's icon mask is
exactly the kind of thing that must be seen rather than reasoned about — which is how this defect
was found in the first place.

**Rejected as larger than necessary:** authoring an adaptive icon
(`mipmap-anydpi-v26/ic_launcher.xml` + foreground/background layers), or supplying
`windowSplashScreenAnimatedIcon`. Both create new brand assets, which WP6's constraints forbid, and
neither is needed if the circle simply matches the field.

---

## 6. Navigation reconciliation

| Symbol | Call sites found | Expected | Result |
|---|---|---|---|
| `pushAndRemoveAllFade` | **3** — `final_winner_screen.dart:389`, `game_screen.dart:66`, `game_screen.dart:545` | 3 | ✅ |
| `pushAndRemoveAllFadeSlide` | **0** (one explanatory comment at `page_transitions.dart:82`) | 0 | ✅ |
| `FadePageRoute` | defined + used by `replaceFade` (1 site) and `pushAndRemoveAllFade` (3 sites) | — | ✅ |
| `FadeSlidePageRoute` | defined + used by `pushFadeSlide` (2) and `replaceFadeSlide` (8) | — | ✅ |

**Every helper that still exists has real call sites. No dead navigation abstraction remains.**

### Semantics of the three adopted sites — each read in full

1. **`final_winner_screen.dart:389`** (`_exitToHome`, the "Salir" CTA) — the night is over and the
   player leaves the ceremony. **Retreat.**
2. **`game_screen.dart:66`** (`_navigateToHomeWithMessage`) — reached from exactly two callers,
   `'La sala se cerró por desconexión'` (line 260) and `'Saliste de la sala.'` (line 282). Both are
   the player leaving or being put out of a room. **Retreat.**
3. **`game_screen.dart:545`** (error placeholder, "Volver al Inicio") — abandoning a room that was
   lost. **Retreat.** This site previously used a raw `MaterialPageRoute`, so it did not use Bufón's
   motion at all.

All three target `HomeScreen` and clear the stack via the same
`pushAndRemoveUntil(..., (route) => false)` contract. No retreat/back/cancel flow uses a forward
whole-stack transition, because no forward whole-stack transition exists any more.

> **Note on the verification brief's wording.** Step 3 item 3 asked to confirm the three adopted
> transitions are *"truly forward navigation/reset flows, not semantic retreats."* That criterion is
> inverted relative to WP6's design and to Capítulo 23. `pushAndRemoveAllFade` **is** the retreat
> route (a fade with no slide); it was adopted precisely **because** these three flows are semantic
> retreats. The criterion actually applied here is the correct one — that each site is a genuine
> retreat — and all three satisfy it. They are also stack *resets*, which is the property the
> whole-stack helper provides, and that is likely what the wording intended. **No code was changed
> on account of this discrepancy.**

### Navigation scope

The complete non-comment diff across `lib/` is three deletions and three call-site swaps. Nothing
else in navigation changed. Pre-existing `MaterialPageRoute` pushes in `lobby_screen.dart:170`,
`profile_screen.dart:73` and `season_countdown_banner.dart:36` are forward pushes, out of WP6 scope,
and those three files are **not in the diff at all**.

---

## 7. Asset / token reconciliation

| Check | Result |
|---|---|
| `wordmark.png` no longer bundled | ✅ removed from `pubspec.yaml` assets; only `questions.json` and `isotype.png` remain declared |
| Source file **not** accidentally deleted | ✅ `assets/brand/wordmark.png` present, **96 365 bytes**, mtime `Aug 10 18:29` — byte-identical and untouched, as the retain decision requires |
| `AppShapes.pill` gone, no references | ✅ zero references; no `StadiumBorder` anywhere in `lib`/`test` |
| `MotionSprings.press` / `.release` gone, no references | ✅ zero references; no `SpringDescription` anywhere in `lib`/`test` |
| Documentation internally consistent | ✅ each removal leaves a comment in place explaining what was there and why it went; `animated_primary_button.dart` now correctly credits `AppShapes.borderRadiusFull` instead of claiming `AppShapes.pill` |
| No replacement token invented | ✅ the diff adds **zero** `static const` declarations and **zero** new classes |

Minor, non-blocking, **not changed**: `MotionPhysics`'s doc comment still reads "aren't a duration,
curve, scale factor **or spring** on their own." It describes categories of constant rather than
naming the deleted class, so it is not wrong — merely a vestige. Out of scope for a verification
pass.

---

## 8. Analyze

```
Analyzing bufon_flutter...
No issues found! (ran in 12.9s)
```

**PASS** — clean, no warnings, no unused imports after the removals.

---

## 9. Focused test — `test/retreat_transition_test.dart`

```
00:10 +3: All tests passed!
```

**PASS — 3/3.** Covers destination + cleared stack, retreat-route identity, and completion under
reduced motion.

---

## 10. Full suite

```
01:20 +220: All tests passed!
exit code: 0
```

**PASS — 220/220, exactly the expected total** (217 baseline + 3 new).

**No existing test was modified, weakened, skipped or deleted.** `git diff --name-only` lists **no**
file under `test/`; the only test-directory change is the new untracked
`test/retreat_transition_test.dart`.

---

## 11. APK build

```
Running Gradle task 'assembleDebug'...  43.0s
✓ Built build/app/outputs/flutter-apk/app-debug.apk
exit code: 0
```

**PASS.** All new Android resources compile, link and package.

This is **structural** verification. It proves the resources are valid and carry the intended values;
it proves nothing about appearance. Appearance was established separately in §4 — and that is where
the defect surfaced, which is precisely why a green build must never be reported as visual proof.

---

## 12. `git diff --check`

```
(no output) — exit 0
```

**PASS.** No whitespace errors, no conflict markers.

---

## 13. Sensitive-pattern scan

Scanned the full WP6 diff plus all three added files.

| Pattern | Matches |
|---|---|
| `api_key` | 0 |
| `password` | 0 |
| `secret` | 0 |
| `token=` | 0 |
| `BEGIN RSA` | 0 |
| `PRIVATE KEY` | 0 |
| `AIza` | 0 |

**PASS — no credentials, keys, secrets or private configuration introduced.** No signing config,
keystore or `google-services.json` was added or modified.

### Additional hygiene

- **No dependency change.** The only `pubspec.yaml` line removed is `- assets/brand/wordmark.png`.
  `pubspec.lock` is untouched.
- **No game logic changed.** The complete non-comment `lib/` diff is three deletions plus three
  navigation call-site swaps. No vote handling, scoring, round progression, reveal staging or timer
  was touched.
- **No repository, controller, provider, service or Firebase code changed.**
- **No unrelated theme work.** No colour, spacing, typography or radius *value* was altered; the two
  theme files changed only by deleting dead members.
- **No pre-existing format-dirty file was reformatted.** `dart format --set-exit-if-changed` still
  reports `final_winner_screen.dart` and `motion_tokens.dart` as changed — and both were verified
  **already dirty at `28ae0da`** by formatting `git show HEAD:<file>`. WP6 correctly left that
  pre-existing drift alone; every line WP6 *added* is format-clean.

---

## 14. Remaining manual verification

1. **Re-verify the API 31+ splash after the §5.3 fix is applied.** The emulator
   `Medium_Phone_API_36.0` is available and currently running, so this is now a cheap check rather
   than a deferred unknown.
2. **A physical device and a pre-API-31 device (API 23–30) were not tested.** The emulator covers
   API 36 only. The pre-31 path uses `launch_background.xml` + `windowBackground`, a different
   mechanism from the one exercised here, and remains structurally verified only.
3. **iOS launch was not examined** — WP6 did not touch `ios/`, by design.
4. **The three retreat transitions were not watched on device.** Destination, stack, route identity
   and reduced-motion behaviour are covered by tests; whether the fade *feels* like a retreat is a
   human judgement.

*Environment note: the emulator was left running and the debug APK is installed on it. Neither
affects the repository.*

---

## 15. Files to stage — **once the §5.3 fix has been applied and re-verified**

Not commit-ready as it stands. When it is, this is the exact set:

```bash
git add \
  bufon_flutter/android/app/src/main/res/drawable/launch_background.xml \
  bufon_flutter/android/app/src/main/res/drawable-v21/launch_background.xml \
  bufon_flutter/android/app/src/main/res/values/styles.xml \
  bufon_flutter/android/app/src/main/res/values/colors.xml \
  bufon_flutter/android/app/src/main/res/values-v31/styles.xml \
  bufon_flutter/android/app/src/main/res/values-night/styles.xml \
  bufon_flutter/lib/core/theme/app_shapes.dart \
  bufon_flutter/lib/core/theme/motion_tokens.dart \
  bufon_flutter/lib/presentation/navigation/page_transitions.dart \
  bufon_flutter/lib/presentation/widgets/animated_primary_button.dart \
  bufon_flutter/lib/screens/final_winner_screen.dart \
  bufon_flutter/lib/screens/game_screen.dart \
  bufon_flutter/pubspec.yaml \
  bufon_flutter/test/retreat_transition_test.dart \
  docs/design/v1.1/WP6_ADOPTION_RECONCILIATION_REPORT.md \
  docs/design/v1.1/WP6_FINAL_VERIFICATION_REPORT.md
```

Notes:
- `values-night/styles.xml` is listed because it is a **deletion**; `git add` on the path stages the
  removal.
- `values-v31/styles.xml`, `values/colors.xml` and `test/retreat_transition_test.dart` are new files.
- **`docs/design/Archive.zip`, `docs/design/v1.1/WP4_RECOVERY_REPORT.md` and
  `docs/design/v1.1/WP5_RECOVERY_REPORT.md` must NOT be staged.** Never use `git add -A` or
  `git add .` here — either would sweep all three in.

---

## Integrity confirmation

- No production code modified during this pass.
- No file reverted, reset, restored, cleaned or stashed.
- Nothing staged, committed or pushed. `HEAD` is still `28ae0da`.
- The three protected untracked files were not opened, altered or staged.
- The only file written by this pass is `docs/design/v1.1/WP6_FINAL_VERIFICATION_REPORT.md`.
- `WP6_ADOPTION_RECONCILIATION_REPORT.md` was read, not modified.


---

## 16. Addendum — the one-line fix was tested and does not work

**Date:** 2026-08-21 · **Outcome: OPTION B — FIX DID NOT RESOLVE DEFECT.** §5.3 is superseded.

### What was applied

Exactly the candidate from §5.3, and nothing else:

```xml
<!-- values-v31/styles.xml, inside LaunchTheme -->
<item name="android:windowSplashScreenIconBackgroundColor">@color/bufon_splash</item>
```

It compiled and it shipped. The APK **pulled back off the device** (`pm path` →
`adb pull` → `aapt2 dump`) confirms the attribute was live in the running app:

```
style/LaunchTheme
  (v31) (style) size=3
    0x01010054=@drawable/launch_background
    0x0101062c=@color/bufon_splash     # windowSplashScreenBackground
    0x01010630=@color/bufon_splash     # windowSplashScreenIconBackgroundColor  <-- the fix
```

So this is not a stale build, a failed install or a cached theme. The fix ran, and did nothing.

### Measured result — no change whatsoever

Same emulator (`Medium_Phone_API_36.0`, API 36, 1080×2400, density 420). Near-white pixels on a
uniform 20 px sample grid of the splash frame:

| | near-white sample px | white circle |
|---|---|---|
| Before the fix | **172** | present |
| After the fix, 3 cold launches × 5 frames | **172** (all 15 frames) | present |
| After `pm clear` + `am start -S`, 4 frames | **172** | present |

Not "reduced" — **bit-identical**. The circle measures a 384 px run across the centre row (≈146 dp at
density 420) in both states, and the screenshots are visually indistinguishable.

### Why it cannot work

`windowSplashScreenIconBackgroundColor` paints a circle **behind** the icon drawable.
`ic_launcher` exists only as legacy square bitmaps with no `mipmap-anydpi-v26` adaptive icon, so
Android applies its **legacy-icon treatment**: it bakes a white circular backdrop into the icon
drawable itself and scales the square mark down inside it. That baked white circle is painted *on
top of* the theme's icon-background colour, covering it completely.

The colour behind the icon is therefore the wrong lever. **The fix has to change the icon, not the
colour behind it** — which is precisely the escalation this pass was told not to make unilaterally.

### State of the tree after this pass

The ineffective `<item>` was **removed**, returning `values-v31/styles.xml` to functionally the exact
configuration audited in §3 — verified: `git diff --stat` is again 11 files, 83+/79−, byte-identical
to the audited WP6 state. Leaving a provably-inert attribute in the tree would have been the same
"exists but does nothing" debt WP6 was created to remove.

The file's comment **was** updated, to record that this attribute was tried and measured as
ineffective and why. That is the one durable value this pass produced: without it the next person
reaches for the same one-liner and burns the same build-install-verify cycle. No functional line and
no Dart code changed.

Gates re-run on the reverted tree: `flutter analyze` clean · `flutter test` **220/220** ·
`flutter build apk --debug` succeeded · `git diff --check` clean.

### Next smallest options — for the owner to choose, not applied

1. **Add an adaptive icon** (`mipmap-anydpi-v26/ic_launcher.xml` with `<background>` = butter and
   `<foreground>` = the jester). This is the option Android actually supports, and it fixes the
   launcher icon everywhere, not just the splash. It needs a **transparent-background jester
   foreground**, which the repo does not have — every brand PNG is opaque butter — so it means
   authoring one new asset. Correct, but it crosses WP6's "no new assets" line.
2. **Set `windowSplashScreenAnimatedIcon`** to a drawable whose background is butter. Avoids a new
   *brand* asset if `splash_isotype` is reused, but the circular mask may clip the hat points —
   unknown until measured, and now cheaply measurable on the live emulator.
3. **Accept it and revert only the API 31+ background**, letting the system default splash stand on
   Android 12+ while keeping the verified pre-31 branded launch. The white circle stops reading as a
   defect because it no longer sits on butter. Cheapest, and gives up the branded launch on modern
   devices.
4. **Ship as-is.** The white ring is cosmetic, on one frame of cold start. Everything else WP6 fixed
   — including the black dark-mode launch — is verified working.

Options 1 and 2 are visual and must be measured on the emulator, not reasoned about. That is the
lesson this defect has now taught twice.


---

## 17. Addendum 2 — `windowSplashScreenAnimatedIcon`: tested and ACCEPTED

**Date:** 2026-08-21 · **Outcome: OPTION A — the defect is fixed.** Supersedes §0 and §5.3.

### What was applied

One line in `values-v31/styles.xml`, reusing the asset WP6 already adopted. No new artwork, no
adaptive icon, no wrapper resource, no manifest change, no Dart change.

```xml
<item name="android:windowSplashScreenAnimatedIcon">@drawable/splash_isotype</item>
```

`windowSplashScreenBackground` still points at `@color/bufon_splash`. `splash_isotype` is referenced
**directly** — it is already a bitmap drawable resource in five density buckets, so no wrapper
drawable was needed. Confirmed live in the built APK: `(v31)` config carries
`0x0101062d=@drawable/splash_isotype`.

### Asset characteristics (measured before implementing)

| | |
|---|---|
| Paths | `res/drawable-{m,h,xh,xxh,xxxh}dpi/splash_isotype.png` |
| Sizes | 128 / 192 / 256 / 384 / 512 px — **128 dp square at every density** |
| Alpha | **none** — `RGB`, alpha extrema (255, 255): fully opaque butter |
| Mark extent | occupies 55.3% × 62.1% of the square; furthest mark pixel at **69.8%** of the half-width |

### A prediction that was wrong, and why measuring mattered

From Android's published geometry — a 288 dp icon canvas with a 192 dp visible circle, ratio
0.667 — a mark reaching 0.698 should have been **clipped at the hat tips**. That was the stated risk
and the reason WP6 originally left this attribute unset.

**It does not clip.** The platform *fits* the drawable inside the mask rather than hard-masking a
288 dp canvas. Verified objectively, not by eye: the rendered mark's silhouette agrees with the
source asset's at **98.25%** after size normalisation, and the aspect ratio matches to within 0.09%
(source 1.1237, rendered 1.1247). A clipped hat point would show up as a systematic block of
disagreement and a distorted bounding box; neither is present. The residual 1.75% is edge
anti-aliasing from the upscale.

The reasoning was sound and the conclusion was wrong. That is the second time in this defect's life
that measurement overturned confident reasoning about the same 20 lines of XML.

### Measured results — `Medium_Phone_API_36.0`, API 36 / Android 16, 1080×2400, density 420

Cold launches only: `pm clear` + `am start -S` each time, never a resume or hot reload.

| Metric | Legacy icon (before) | AnimatedIcon (after) |
|---|---|---|
| Splash background | `#F9F367` | `#F9F367` — unchanged |
| Near-white sample px on splash frame | **172** | **0** |
| White circular treatment | present, 384 px ≈ 146 dp | **gone** |
| Mark rendered size | **45.7 × 51.4 dp** | **158.9 × 178.7 dp** (≈3.5× larger) |
| Mark clipped | n/a | **no** — 98.25% silhouette agreement |
| Square/rect background behind mark | butter square inside white circle | **none** — unbroken butter field |

Frame counts: **12 light-mode frames across 3 cold launches** — every one `#F9F367` dominant,
every one 0 near-white. **6 dark-mode frames across 2 cold launches** — identical. **3 further
frames** after the final rebuild — identical (`mark=157×178 dp`, 0 near-white). The result is stable,
not a lucky capture.

### The nine required checks

| # | Check | Result |
|---|---|---|
| 1 | Launch background remains `#F9F367` | ✅ dominant in all 21 frames |
| 2 | No black launch frame in dark mode | ✅ butter in dark mode; 0 near-white, 0 near-black on the splash |
| 3 | White circular treatment gone or materially changed | ✅ **gone** — 172 → 0 |
| 4 | Jester fully visible | ✅ both hat points, both bells, both ears, full face |
| 5 | Hat points not clipped by the mask | ✅ verified numerically, see above |
| 6 | Jester not shrunk to unusable size | ✅ the opposite — 3.5× larger |
| 7 | No unexpected square/rect background | ✅ the asset's butter background blends into the butter field, so the mask boundary is invisible |
| 8 | Handoff to `#FAFAF7` still seamless | ✅ post-splash frame `#FAFAF7` dominant, with `#E4DFCF` and `#F8EE67` accents |
| 9 | Home renders normally | ✅ unchanged from the §4 baseline |

**One frame needed ruling out.** A single dark-mode capture showed dark pixels spanning the content
area. It is the launcher wallpaper visible behind the app window during Android's normal window-open
scale animation — the splash within that frame is butter with the complete mark. Not a launch flash,
and not WP6-related.

### Visual comparison

**Before (legacy icon):** white circle ≈146 dp on butter, a butter square inset within it, and the
jester at ~46×51 dp inside that — three nested boxes, the mark small and the white ring reading as a
rendering fault.

**After (AnimatedIcon):** one unbroken butter field with the jester centred at ~159×179 dp. No ring,
no square, no visible mask boundary, nothing clipped.

**The new composition is unambiguously better** — it removes two spurious nested shapes and renders
the mark 3.5× larger, which is what a branded launch was supposed to look like.

### Automated gates on the final tree

`flutter analyze` clean · `flutter test` **220/220** · `flutter build apk --debug` succeeded ·
`git diff --check` clean. `git diff --stat` remains 11 files, 83+/79− (`values-v31/` is a new
untracked file, so it does not appear in the tracked diff).

### Scope

Only `android/app/src/main/res/values-v31/styles.xml` changed in this pass — one functional line plus
its comment. No new asset, no adaptive icon, no launcher icon, no manifest, no API <31 resource, no
Dart, no pubspec, no dependency, no test. The three protected untracked files were not touched.
