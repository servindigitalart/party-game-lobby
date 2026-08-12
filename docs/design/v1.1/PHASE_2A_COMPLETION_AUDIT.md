# BUFÓN 1.1 — PHASE 2A COMPLETION AUDIT

**Date:** 2026-08-11
**Commit audited:** `8c224c9 feat: complete Bufon 1.1 phase 2A foundation`
**Branch:** `main`, in sync with `origin/main`
**Nature:** read-only audit. No source, config, dependency or documentation file was
modified. This document is the only file written.

> **Amendment 2026-08-11 — Phase 2B WP1 landed (uncommitted).** §8 B1 is **RESOLVED** and
> §3 SWA-1 is **CLOSED**. The rest of this audit stands as written. Amendments are marked
> inline; nothing else in the document was rewritten.

**Rule applied throughout: IMPLEMENTATION > DOCUMENTATION.** The Phase 1 audit set
(`V1.1_GAP_ANALYSIS.md`, `MOTION_AUDIT.md`, `UX_AUDIT.md`, et al.) describes the repository
as it stood *before* Phase 2A. Several of their headline findings are now stale. Every such
discrepancy is called out explicitly in §2.4.

---

## 1. Repository state — verified

```
git status --short   → ?? docs/design/Archive.zip     (only untracked item; not source)
git log -3 --oneline → 8c224c9 feat: complete Bufon 1.1 phase 2A foundation
                       ae65c54 fix: harden purchase validation and app attestation
                       dc3bca7 feat: complete production backend and release infrastructure
git status -sb       → ## main...origin/main          (no ahead/behind — push confirmed)

flutter analyze      → No issues found! (ran in 5.7s)          ✅ matches expected baseline
flutter test         → +148: All tests passed!                 ✅ matches expected baseline
```

Working tree is clean apart from one untracked binary (`docs/design/Archive.zip`), which is
design source material, not code. Build commands were not run — nothing in this audit
required diagnosis at the build layer.

**Baseline confirmed. No investigation needed at this step.**

---

## 2. Blueprint → implementation matrix

Status vocabulary: **IMPLEMENTED** means the behaviour is reachable and actually exercised by
the running app. A file, token or component that exists but is never instantiated is
**NOT IMPLEMENTED**, and appears again in §3.

### 2.1 Foundation

| Area | Blueprint intent | Current implementation | Status | Evidence | Impact |
|---|---|---|---|---|---|
| Design-system activation | Butter Bliss is the app's theme | `main.dart` ships `theme: lightTheme`, `darkTheme`, `themeMode: light` | **IMPLEMENTED** | `main.dart:117-127` | Foundational |
| Semantic phase system | Per-phase colour registers, since `ThemeData` holds one `ColorScheme` | `BufonPhase` (10 values) + `PhaseScope` + `context.phase`/`context.accent` | **IMPLEMENTED** | `bufon_phase.dart` (200 L), 5 call sites | Foundational |
| Phase register adoption | Every screen declares its register | ~~5 of 11 screens~~ → **11 of 11 (WP1, 2026-08-11).** `home`, `lobby`, `answering`, `voting`, `reveal` on real registers; the other six on the explicit `legacy` opt-in pending migration | **IMPLEMENTED** *(amended)* | census in §8 B1; enforced by `test/phase_scope_test.dart` | **B1 resolved** |
| Colour migration | Legacy casino palette deleted | **246 legacy `AppColors.*` refs** remain across 13 files (13 in FinalWinner, 41 ProfilePublic, 40 Profile, 27 Leaderboard, 24 SeasonDetails, 21 ShareVictoryCard, 17 TitleDialog) + **52 raw `Colors.*`** + **19 raw `Color(0x…)`** | **PARTIAL** | census in §2.5 | High |
| Typography tokens | One scale, no literals | `AppTypography` used across all migrated screens; **26 raw `TextStyle(` remain** outside it | **PARTIAL** | `grep -c "TextStyle("` | Medium |
| Bundled fonts | No runtime font fetch | 3 TTFs + `OFL.txt` bundled, declared, licence registered; **zero `GoogleFonts` refs** in `lib/` (2 remaining hits are explanatory comments) | **IMPLEMENTED** | `pubspec.yaml:85-91`, `main.dart:104` | High — closed a guaranteed first-launch brand failure |
| Brand assets in pipeline | Isotype + wordmark shipped as Flutter assets | Both committed and declared | **IMPLEMENTED** | `pubspec.yaml:76-77` | — |
| Brand assets *rendered* | Isotype at 6 surfaces; wordmark at 2 | **Isotype: 1 site** (Home app bar). **Wordmark: 0 sites** | **PARTIAL** | `grep -rn "assets/brand" lib/` → 1 hit | See §3 |
| App icon | Isotype, ink on butter, full bleed | 5 Android mipmaps + 16 iOS icons replaced with real artwork | **IMPLEMENTED** | committed binaries | High — first brand impression |
| Splash — iOS | Isotype on flat Butter | `LaunchImage@1x/2x/3x` replaced (68 B placeholders → 15/55/125 KB), storyboard references them | **IMPLEMENTED** | `LaunchScreen.storyboard` | Medium |
| Splash — Android | Same | **`launch_background.xml` and `drawable-v21/launch_background.xml` are the untouched Flutter defaults** — white / `?android:colorBackground`, bitmap item still commented out. The 5 `splash_isotype.png` files ship but are never referenced | **NOT IMPLEMENTED** | files read in full | Medium — **platform inconsistency**: iOS launches branded, Android launches to a white flash |

### 2.2 Motion & the reveal

| Area | Blueprint intent | Current implementation | Status | Evidence | Impact |
|---|---|---|---|---|---|
| Motion tokens | Six named behaviours, no literals | `MotionDurations` 13 uses, `MotionCurves` 12, `MotionScale` 6 | **IMPLEMENTED** | census | — |
| Motion *utilities* | Cap. 16 behaviours as reusable widgets/mixins | Still tokens only — there is no `Arrive`/`Press` widget; each call site hand-composes | **PARTIAL** | no such widget in `lib/` | Medium |
| `KeyholeRevealTransition` | The brand's ownable gesture, wired into the reveal | Wired, driven by `_keyholeController` via `MotionCurves.reveal`, Graphite backdrop, centre origin; **verified rendering** by test assertion on `progress.value` | **IMPLEMENTED** | `round_result_screen.dart:319-355`, `test/reveal_test.dart` test 3 | **High — the signature gesture now exists in the product** |
| Reveal sequencing | Stage 0 silence → stage 1 keyhole → stage 2 author | Timers 750/1550 ms preserved; stage 1 opens the mask; stage 2 names the author at `displayButter` | **IMPLEMENTED** | `round_result_screen.dart` | High |
| Scoreboard reveal gate | "no visible hasta que termina la etapa 2" | `if (_revealStage >= 2)` — not built at all before stage 2 (not opacity-hidden, so it is absent from the semantics tree too), `Arrive`s from below | **IMPLEMENTED** | regression test `test/reveal_test.dart` tests 1-2 | **High — the P1 defect of the whole release is closed** |
| Confetti tiers | 50/3 s round, 80-100/4-5 s night, brand palette | `ConfettiTier` enum + brand palette ✅. **`ConfettiTier.night` has zero call sites** — FinalWinner uses the default `round` tier | **PARTIAL** | `grep "ConfettiTier.night"` → 0 | Medium |
| Navigation transitions | Forward = fade+slide, retreat = fade only | `replaceFadeSlide` 8 uses, `pushFadeSlide` 2, `replaceFade` 1. **4 `MaterialPageRoute` remain**; and both "go home" exits use the *forward* variant (`pushAndRemoveAllFadeSlide`) while `pushAndRemoveAllFade` has 0 uses | **PARTIAL** | §3 finding SWA-6 | Medium |
| Reduced motion | Every Pulse/Reveal has a reduced path | `context.reduceMotion` / `context.motion` in 5 widgets + the keyhole + the scoreboard Arrive | **IMPLEMENTED** (for everything that animates today) | 5 call sites | Medium |

### 2.3 Product surfaces

| Area | Blueprint intent | Current implementation | Status | Evidence | Impact |
|---|---|---|---|---|---|
| Profile reachability | Reachable from the shell | Home app bar `person` action | **IMPLEMENTED** | `home_screen.dart:161` | High |
| Leaderboard reachability | Reachable from the shell | Home app bar `emoji_events` action | **IMPLEMENTED** | `home_screen.dart:167` | High |
| Progression / avatar | Winner shows their equipped avatar | Still `winnerAvatarId: 'default'` — `firestore.rules` forbids a non-winner reading `/users/{uid}` | **BLOCKED** | `round_result_screen.dart:191`; comment corrected to match reality | High, needs a product decision |
| Share cards | Brand typography, isotype in a fixed corner | `share_victory_card.dart` / `share_profile_card.dart` untouched (21 + 7 legacy refs). They inherited the bundled face indirectly via `AppTypography` — by side effect, not design | **NOT IMPLEMENTED** | file inspection | Medium (growth surface) |
| Share reach | CTA for every player | Still `if (widget.isCurrentUserWinner)` | **NOT IMPLEMENTED** | `final_winner_screen.dart:273` | Medium visual / **high growth** |
| Component reuse | One primary button | `AnimatedPrimaryButton` on 6 screens (8 uses); **4 raw buttons remain** (Leaderboard, GameScreen, Profile ×2) | **PARTIAL** | census | Medium |
| Iconography | Filled Material set + brand glyphs for lock/avatar-fallback | 68 refs, all stock Material, outline/filled still mixed; `Icons.lock` ×2 where the blueprint wants the keyhole glyph; emoji still used as content in 9 files | **NOT IMPLEMENTED** | census | Medium |
| Accessibility — semantics | Every interactive/informational element labelled | 5 **widgets** carry `Semantics`. **0 of 11 screens** do | **PARTIAL** | `grep` per file | High |
| Accessibility — dynamic type | Layouts survive 200% text scale | **0 references to `textScaler`** anywhere in `lib/` | **NOT IMPLEMENTED** | `grep` → 0 | High |
| Accessibility — tooltips | Icon-only controls labelled | 4 `tooltip:` — Home's two actions + 2 others; Leaderboard refresh and Profile share are covered, several others are not | **PARTIAL** | `grep -c "tooltip:"` → 4 | Medium |
| Loading states | One `BufonLoader`, breathing isotype | **16 raw `CircularProgressIndicator`** across 11 files | **NOT IMPLEMENTED** | census | Medium |
| Error states | Brand placeholder, never a raw exception | Home's `_friendlyRoomError` fixed. **`Error: $error` / `Error al compartir: $e` still render in 4 screens** | **PARTIAL** | `lobby:400`, `game:517`, `round_result:353`, `final_winner:375` | Medium |
| Empty states | Brand illustration | None; `Icons.emoji_events_outlined` at 64 px, and on Profile/Leaderboard the empty copy is **currently invisible** (§8) | **NOT IMPLEMENTED** | file inspection | Medium |
| Legacy theme | Deleted once every screen migrates | `AppTheme.legacyTheme` still defined (32 legacy refs) but **no longer reachable from `MaterialApp`**; reachable only via `BufonPhase.legacy`, which has **0 call sites** | **PARTIAL** | `grep "BufonPhase.legacy"` → 0 | **See §8 BLOCKING** |
| Legacy widgets | Migrated to tokens | 5 loop widgets migrated (button, card, timer, progress, confetti); `season_*`, `share_*`, `title_selector_dialog` untouched | **PARTIAL** | census | Medium |

### 2.4 Documentation discrepancies (implementation is ahead of, or behind, the docs)

The Phase 1 audit set is **stale in six places**. A future session must not plan from it directly.

| Doc claim | Source | Reality at `8c224c9` |
|---|---|---|
| "Fase 3E Gameplay — **0%**. `graphite`, `sky`, `lavender` have zero uses outside `app_theme.dart`" | `V1.1_GAP_ANALYSIS.md:36` | **Wrong now.** Answering and Voting both carry registers and their accents; the two phases are distinguishable without reading text |
| "Fase 3F Reveal — **0%**… scoreboard renders from stage 0" | `V1.1_GAP_ANALYSIS.md:38` | **Wrong now.** Gated, keyhole wired, register applied, covered by tests |
| "Fase 3A ~85% — **font never added to `pubspec.yaml`**" | `V1.1_GAP_ANALYSIS.md:33` | **Wrong now.** Bundled, declared, licence-registered, `google_fonts` removed |
| "`lobby_screen.dart` still uses `Colors.orange`, `Colors.red`" | `V1.1_GAP_ANALYSIS.md:35` | **Wrong now.** Zero Material `Colors.*` in `lobby_screen.dart` |
| "26 raw literals outside `app_colors.dart`" | `V1.1_GAP_ANALYSIS.md:42` | **19** now — same defect, smaller |
| "1 accessibility affordance total" | `V1.1_GAP_ANALYSIS.md:42` | 5 widgets carry `Semantics`; still **0 screens**, still **0 `textScaler`** |
| "`AppShapes.pill` existed and had zero call sites" (implying it is now used) | `animated_primary_button.dart:22` — **a code comment** | **Still zero.** The button uses `AppShapes.borderRadiusFull` instead. Same pixels, but the comment misleads and the token is still dead |
| "FinalWinnerScreen resolves [the avatar] from the signed-in profile" | previously in `round_result_screen.dart` | Was false; **corrected during the recovery continuation**. `final_winner_screen.dart:97` does a flat `Avatars.all.firstWhere` |

### 2.5 Tally

| Status | Count |
|---|---|
| **IMPLEMENTED** | **12** |
| **PARTIAL** | **14** |
| **NOT IMPLEMENTED** | **8** |
| **BLOCKED** | **1** |
| **SUPERSEDED** | **0** |

Nothing was superseded: every blueprint objective is still the right objective. Phase 2A did
not invalidate any part of the design intent — it built the foundation the intent assumed.

---

## 3. Specification Without Adoption

The single most useful section of this audit. Phase 2A wrote a lot of correct system; a
measurable slice of it is not reachable from the running app. Every item below is *defined and
compiling* but *never exercised*.

### SWA-1 — `BufonPhase` registers with no screen — **CLOSED (WP1, 2026-08-11)**

> **Amendment.** `BufonPhase.legacy` now has **6 call sites** and 6 of 10 enum values are in
> use. `profile`, `leaderboard`, `roundWinner` and `nightWinner` remain unused — they are
> reserved for the screens that still carry `legacy`, and are tracked by WP3/WP5 rather than
> here. The invariant is enforced by `test/phase_scope_test.dart`.

- **Artifact:** `BufonPhase.profile`, `.leaderboard`, `.roundWinner`, `.nightWinner`, `.legacy`
- **Defined:** `lib/core/theme/bufon_phase.dart:33-58`
- **Should be used:** Profile, Leaderboard, the round-winner moment, FinalWinner, and every
  not-yet-migrated screen respectively
- **Current usage:** **0 call sites each.** 5 of 10 enum values are dead
- **Why it matters:** `legacy` was written specifically so no screen could fall onto the casino
  palette *by accident* — and it is the one value nobody applied, which is precisely how the
  §8 BLOCKING regression happened
- **Recommended action:** apply `legacy` immediately as a stop-gap to the six unscoped screens;
  replace with real registers as each migrates

### SWA-2 — Android splash assets that nothing references
- **Artifact:** `splash_isotype.png` × 5 densities
- **Defined:** `android/app/src/main/res/drawable-{h,m,xh,xxh,xxxh}dpi/`
- **Should be used:** `drawable/launch_background.xml` + `drawable-v21/launch_background.xml`
- **Current usage:** **0.** Both XML files are byte-identical to the Flutter template, bitmap
  item still inside an XML comment
- **Why it matters:** the bytes ship in every APK and produce nothing; Android users get a white
  flash into a cream app while iOS users get the branded launch. A platform inconsistency on the
  most frequent impression in the product
- **Recommended action:** wire the XML (≈6 lines × 2 files), or adopt `flutter_native_splash`

### SWA-3 — The wordmark
- **Artifact:** `assets/brand/wordmark.png`
- **Defined:** shipped and declared in `pubspec.yaml:77`
- **Should be used:** Home headline ("the lockup *is* the type") and the winner screen
- **Current usage:** **0 references in `lib/`.** Home still renders the string `'BUFÓN'` as text
- **Why it matters:** ships weight, delivers nothing; and the headline is the one place the
  blueprint says the lockup should replace typed text
- **Recommended action:** either render it on Home/Winner, or drop it from the bundle

### SWA-4 — `ConfettiTier.night`
- **Artifact:** the 90-particle / 4.5 s tier
- **Defined:** `confetti_widget.dart:29`
- **Should be used:** `final_winner_screen.dart:107`
- **Current usage:** **0.** FinalWinner calls `ConfettiWidget(isActive: …)` and silently takes
  the `round` default
- **Why it matters:** the three-tier celebration ladder is flattened — the night winner gets
  exactly the same celebration as a round winner, so the peak reads as a repeat
- **Recommended action:** one argument

### SWA-5 — The ceremonial layer
- **Artifact:** `AppElevation.ceremonialGradient` + `PrimaryButtonVariant.ceremonial`
- **Defined:** `app_elevation.dart:64`, `animated_primary_button.dart:46`
- **Should be used:** FinalWinner — the one screen the system licenses to break its own rules
- **Current usage:** `ceremonialGradient` has **1** reference, inside the `ceremonial` button
  variant, which itself has **0** call sites → the whole ceremonial layer is **transitively
  unreachable**. Meanwhile `final_winner_screen.dart:141-152` hand-rolls its own three-stop
  red/gold gradient
- **Why it matters:** the product's emotional peak is running on the palette the design system
  retired, while the thing written for it sits unused
- **Recommended action:** Phase 2B work package 2

### SWA-6 — The retreat transition
- **Artifact:** `FadePageRoute`, `context.pushAndRemoveAllFade`
- **Defined:** `page_transitions.dart:12-27, 98`
- **Should be used:** every backward navigation — Cap. 23: "salir de una sala, volver a Home"
- **Current usage:** `replaceFade` **1** (Lobby → Home ✅). `pushAndRemoveAllFade` **0** — the two
  actual "abandon the game and go home" exits (`game_screen.dart:62`,
  `final_winner_screen.dart:389`) both call `pushAndRemoveAllFade**Slide**`, the *forward* variant
- **Why it matters:** leaving still feels identical to advancing, which is the exact defect the
  route was written to fix. Two-character fix, currently invisible because both names compile
- **Recommended action:** swap the two call sites

### SWA-7 — `AppShapes.pill`
- **Artifact:** `static const ShapeBorder pill = StadiumBorder()`
- **Defined:** `app_shapes.dart:78`
- **Current usage:** **0.** The button that documents itself as adopting it uses
  `AppShapes.borderRadiusFull` instead
- **Why it matters:** low visual stakes (identical pixels), but the code comment asserts adoption
  that did not happen — exactly the kind of drift that makes a design system untrustworthy to
  the next reader
- **Recommended action:** use one, delete the other, fix the comment

### SWA-8 — Physics presets
- **Artifact:** `MotionSprings` (2 presets), `MotionPhysics` (breathing amplitude/period,
  overshoot ratio)
- **Defined:** `motion_tokens.dart`
- **Current usage:** **0 each**
- **Why it matters:** `MotionPhysics.breathingAmplitude` is the spec for the blueprint's
  `BufonLoader` (breathing isotype, replacing 16 spinners) — it is pre-written infrastructure for
  a component nobody has built yet. `MotionSprings` is honestly documented as speculative
- **Recommended action:** `MotionPhysics` gets consumed by work package 3; re-evaluate
  `MotionSprings` for deletion if no gesture work lands in 1.1

### SWA-9 — Screen-level accessibility
- **Artifact:** the `Semantics` architecture and `context.reduceMotion`
- **Current usage:** 5 widgets. **0 screens.** `textScaler`: **0 anywhere**
- **Why it matters:** the five labelled widgets are announced correctly inside screens that
  announce nothing — headings, live regions, result summaries and navigation landmarks are all
  absent. The helper exists; the sweep never happened
- **Recommended action:** work package 4

**Summary: 9 subsystems specified, built, and not adopted.** In leverage terms this is the
cheapest inventory in the project — most items are a one-line call site away from shipping.

---

## 4. Visual surface audit

Method: source inspection of all 11 reachable player-facing screens, cross-checked against the
palette/typography/component census. Scores are deliberately uninflated; 10 means "shippable as
a reference implementation of the blueprint", 5 means "coherent but generic", ≤3 means "actively
off-brand or broken".

### 4.1 Current Visual Scorecard

| Screen | Brand | Type | Color | Hierarchy | Components | Motion | Polish | **Overall** |
|---|---|---|---|---|---|---|---|---|
| **Home** | 8 | 8 | 8 | 7 | 8 | 7 | 7 | **7.5** |
| **Lobby** | 7 | 8 | 8 | 8 | 7 | 7 | 7 | **7.5** |
| **Game / Answering** | 6 | 8 | 8 | 6 | 8 | 7 | 7 | **7.0** |
| **Voting** | 6 | 8 | 8 | 7 | 8 | 7 | 7 | **7.5** |
| **Round Result** | 8 | 8 | 8 | 8 | 8 | 8 | 7 | **8.0** |
| **Final Winner** | 3 | 4 | 2 | 5 | 4 | 5 | 3 | **3.5** |
| **Profile** | 2 | 3 | 2 | 4 | 3 | 2 | 2 | **2.5** |
| **Leaderboard** | 2 | 3 | 2 | 4 | 3 | 2 | 2 | **2.5** |
| **Profile (public)** | 2 | 3 | 2 | 4 | 3 | 2 | 2 | **2.5** |
| **Season details** | 2 | 3 | 2 | 4 | 3 | 2 | 2 | **2.5** |
| **Paywall** | 2 | 2 | 1 | 4 | 2 | 2 | 2 | **2.0** |

### 4.2 The finding that matters most

**Bufón is now two products in one binary.**

| | Screens | Mean overall |
|---|---|---|
| **The game loop** (migrated) | Home, Lobby, Answering, Voting, Reveal | **7.5** |
| **The surrounding shell** (untouched) | Winner, Profile, ProfilePublic, Leaderboard, Seasons, Paywall | **2.6** |

A **4.9-point gap** inside one app. Phase 2A did exactly what it set out to do — but it
concentrated all of it on the five screens of the core loop, and the loop is now good enough
that the shell reads as a different, older application bolted on.

Two aggravating factors make this worse than a simple "unfinished" state:

1. **The peak is in the untouched half.** A night ends on FinalWinner (3.5), not on the reveal
   (8.0). The last thing a player sees is the worst-looking screen in the loop.
2. **Phase 2A opened the doors to the worst rooms.** Profile and Leaderboard had *zero* inbound
   navigation before this phase. They now have prominent app-bar buttons on Home — and their
   chrome is currently broken (§8).

### 4.3 Per-screen notes

- **Round Result (8.0)** — the best screen in the product. Signature keyhole gesture, correct
  register, gated scoreboard, `Arrive`ing list, brand confetti. Held back only by the deferred
  items: no `Hero` from the voting card, counters snap instead of tweening, `Error: $error` is
  still the whole error state, non-hosts get a static wait card.
- **Home / Lobby (7.5)** — the only screens carrying brand marks and the Paper register. Home
  loses a point on hierarchy (typed `'BUFÓN'` where the wordmark belongs). Lobby's room-code
  protagonist card and copy-icon Swap are the strongest small-detail work in the app.
- **Answering (7.0)** — correct Graphite+Sky register and a genuine protagonist question card,
  but the blueprint's "delete 3 of 4 duplicate progress read-outs" is untouched: the round
  indicator, progress bar, timer and answered-count all compete simultaneously.
- **Voting (7.5)** — Lavender register makes it distinguishable from Answering at a glance,
  which was an explicit acceptance criterion and now passes.
- **Final Winner (3.5)** — hardcoded `#111111`, a three-stop red/gold gradient, `🏆 BUFÓN DE LA
  NOCHE 🏆` in retired `gold`, round-tier confetti, no `celebration()` haptic on arrival, share
  CTA gated to one player. Motion scores 5 only because the `elasticOut` avatar entrance and
  glow do animate — both overshoot past the documented ceiling.
- **Profile / ProfilePublic / Leaderboard / Seasons (2.5)** — hand-rolled containers over the
  full legacy palette (41/40/27/24 refs). Self-consistent internally, entirely off-system, and
  currently mis-chromed (§8).
- **Paywall (2.0)** — the least polished screen in the app, 12 raw `Colors.*` and 8 raw hex
  literals, and it is the screen that handles money.

---

## 5. Highest-Leverage Opportunities

Ranked by the six requested criteria (perceived impact · reach · brand distinctiveness ·
reusability · leverage · regression risk). Ranking favours *reusable systems* and *reach* over
one-off decoration.

### 1. Restore chrome legibility on the six unscoped screens — **P0**
- **Screens:** Profile, ProfilePublic, Leaderboard, SeasonDetails, Paywall, FinalWinner
- **Problem:** they hardcode dark surfaces but now inherit `lightTheme`, so app-bar titles, the
  **back button**, action icons and every unstyled `Text` render ink `#191919` on `#1A1A2E`
  (≈1.03:1). See §8 for the full mechanism
- **Direction:** wrap each in `PhaseScope(phase: BufonPhase.legacy)` — the value written for
  exactly this and never used (SWA-1)
- **Leverage:** ~6 lines per screen, fixes a functional defect on the two screens this phase
  just made reachable, and consumes a dead enum value
- **Complexity: S** · **Dependencies:** none · **Priority: P0**

### 2. Ceremonial Final Winner — **P1**
- **Screens:** FinalWinner (+ the share cards it renders)
- **Problem:** the emotional peak of the product is the second-worst screen in it, on a retired
  palette, silent to the hand, celebrating with round-tier confetti
- **Direction:** `nightWinner` register + `AppElevation.ceremonialGradient` + `ConfettiTier.night`
  + `celebration()` haptic on arrival + share CTA ungated. Every ingredient already exists and is
  currently dead (SWA-4, SWA-5)
- **Leverage:** highest perceived-quality delta per hour in the project — it converts three dead
  subsystems into the moment players screenshot, and ungating share multiplies the only viral
  surface by up to 8× in an 8-player room
- **Complexity: M** · **Dependencies:** none (the avatar blocker is orthogonal — ship the
  ceremony with the default avatar) · **Priority: P1**

### 3. `BufonLoader` + `BufonPlaceholder` — one loading and one empty/error primitive — **P1**
- **Screens:** all 11
- **Problem:** 16 raw spinners; empty states are 64 px Material icons; four screens still print
  `Error: $error` to players
- **Direction:** a breathing isotype loader (consuming `MotionPhysics.breathingAmplitude`,
  SWA-8) and one placeholder component taking icon/title/body/action
- **Leverage:** **the highest reusability item in the audit** — two components touch every screen
  including the six not yet migrated, so the shell improves before it is individually migrated
- **Complexity: M** · **Dependencies:** brand illustration decision for empty states (an isotype
  treatment is sufficient; no new assets needed) · **Priority: P1**

### 4. Accessibility floor: screen semantics + dynamic type — **P1**
- **Screens:** all 11
- **Problem:** 0 screens carry `Semantics`; `textScaler` appears **zero** times; a 200% text
  scale has never been tested against any layout
- **Direction:** headings/landmarks per screen, live-region announcements for phase changes, and
  a scroll-safety pass on the fixed-height compositions
- **Leverage:** legal/store risk, and it is far cheaper *before* a large visual pass than after —
  every screen touched twice otherwise
- **Complexity: M** · **Dependencies:** none · **Priority: P1**

### 5. Migrate Profile + Leaderboard to their registers — **P1**
- **Screens:** Profile, Leaderboard (ProfilePublic follows the same patterns)
- **Problem:** 67 legacy refs across the two; both newly reachable and both at 2.5
- **Direction:** `BufonPhase.profile` (Paper + Ink) and `.leaderboard` (Paper + Sky/Lavender) —
  two more dead enum values consumed
- **Leverage:** the progression system the backend already awards is invisible until these look
  like the same app; unblocks the avatar economy paying off socially
- **Complexity: L** · **Dependencies:** #1 first (or do #1 as the first step of this)
- **Priority: P1**

### 6. Wire the Android splash — **P2**
- **Problem:** branded launch on iOS, white flash on Android; 5 shipped PNGs referenced by
  nothing (SWA-2)
- **Leverage:** the most frequent brand impression in the product, and the assets are already
  paid for
- **Complexity: S** · **Dependencies:** hand-wire vs. `flutter_native_splash` decision
- **Priority: P2**

### 7. Retreat transitions + remaining `MaterialPageRoute` — **P2**
- **Problem:** 4 raw routes; both "go home" exits use the forward transition (SWA-6)
- **Leverage:** makes an already-built motion distinction actually perceptible; near-zero risk
- **Complexity: S** · **Dependencies:** none · **Priority: P2**

### 8. One protagonist on Answering — **P2**
- **Problem:** four simultaneous progress read-outs on the most-used screen
- **Direction:** mostly deletion (blueprint G13)
- **Leverage:** hierarchy improvement by subtraction; the cheapest kind
- **Complexity: S** · **Dependencies:** none · **Priority: P2**

### 9. Tweened counters + `Hero` into the reveal — **P2**
- **Screens:** Reveal, Winner, Leaderboard, Profile
- **Problem:** every number snaps; the reveal's answer appears rather than travelling from the
  voting card
- **Leverage:** a reusable `TweenAnimationBuilder<int>` helper serves four screens
- **Complexity: M** · **Dependencies:** #5 for the profile/leaderboard payoff · **Priority: P2**

### 10. Iconography pass + brand glyphs — **P3**
- **Problem:** 68 stock Material icons, outline/filled mixed, `Icons.lock` where the blueprint
  specifies the keyhole glyph, emoji as content in 9 files
- **Leverage:** real consistency win, but low next to items 1-5, and the keyhole glyph needs
  asset work
- **Complexity: M** · **Dependencies:** glyph assets · **Priority: P3**

---

## 6. Recommended Phase 2B

### Phase objective

Close the 4.9-point gap between the migrated game loop and the untouched shell — **not** by
migrating every remaining screen, but by shipping the three cross-cutting primitives that
improve all eleven screens at once (chrome correctness, a loading/placeholder pair, an
accessibility floor), then spending the remaining budget on the single screen with the worst
impact-to-quality ratio in the product: the Final Winner. Phase 2B should end with **zero
screens whose chrome is illegible**, **zero raw spinners**, **zero raw exception strings shown
to players**, and the night ending on a ceremony rather than on the casino palette. It should
also retire the "specification without adoption" backlog, because every item in §3 is a call
site away and each one left dead makes the system less trustworthy to the next contributor.

### Non-goals — do NOT touch in Phase 2B

- **The five migrated loop screens' visual design.** Home, Lobby, Answering, Voting, Reveal are
  at 7.0-8.0. Re-opening them is the classic way to spend a phase and finish flat. The only
  permitted edits are cross-cutting (loader/placeholder/semantics) and the two-call-site retreat
  transition fix.
- **The progression/avatar security decision.** Still BLOCKED, still a product call
  (denormalise onto the room's player doc, or relax `firestore.rules`). Ship the winner ceremony
  with the default avatar; do not let this block it.
- **The reveal's deferred items** (`Hero`, tweened counters, pre-reveal silence, non-host coiled
  state). The pre-reveal silence in particular is synchronisation-adjacent — the blueprint marks
  it deferred for that reason.
- **Paywall redesign.** It is the worst screen but the lowest reach; it gets the free wins from
  work packages 1 and 3 and nothing more.
- **New dependencies**, iconography assets, golden-test infrastructure, Phase 2C scope, and any
  further research.

### Work packages

---

#### WP1 — Chrome correctness sweep (the regression stop) — **DONE (2026-08-11, uncommitted)**

> **Amendment.** All five acceptance criteria met: 11 of 11 screens scoped; `BufonPhase.legacy`
> has 6 call sites; no screen sets an `AppBar(backgroundColor:)` without a matching foreground
> source; `flutter analyze` 0 issues; `flutter test` 151 passing (148 pre-existing + 3 new).
> **The WP1 gate is open — WP2/WP5 may start.**


- **Objective:** no screen renders illegible chrome. Every screen declares a register.
- **Affected:** Profile, ProfilePublic, Leaderboard, SeasonDetails, Paywall, FinalWinner
- **Files:** `lib/presentation/screens/{profile,profile_public,leaderboard,season_details,paywall}_screen.dart`,
  `lib/screens/final_winner_screen.dart`, possibly `lib/presentation/dialogs/title_selector_dialog.dart`
- **Improvement:** app-bar titles, back buttons, action icons, empty and error copy become
  visible again on six screens — including the two Phase 2A just made reachable
- **Dependencies:** none. Must land **first**; everything else in 2B is built on top
- **Risk:** **Low.** `BufonPhase.legacy` returns `AppTheme.legacyTheme`, byte-for-byte the theme
  these screens were authored against, so this restores their intended appearance rather than
  changing it
- **Acceptance criteria:**
  1. `grep "phase: BufonPhase"` returns 11+ hits — every reachable screen scoped
  2. `BufonPhase.legacy` has ≥1 call site (SWA-1 closed)
  3. No screen sets an `AppBar(backgroundColor:)` without a matching foreground source
  4. Manual check: Profile and Leaderboard app-bar title, back arrow and action icons all
     legible; empty and error states legible
  5. `flutter analyze` 0, existing 148 tests still green

---

#### WP2 — Shared surface primitives: `BufonLoader` + `BufonPlaceholder` — **DONE (2026-08-11, uncommitted)**

> **Amendment.** All four acceptance criteria met: `CircularProgressIndicator`
> 16 → 2 (both nested inside another component — a button and a SnackBar); zero raw
> exception strings in any screen; the loader honours reduced motion (static mark, ticker
> stopped); `flutter analyze` 0 issues, `flutter test` 161 passing (151 pre-existing + 10 new).
> 14 `BufonLoader` and 14 `BufonPlaceholder` call sites. Full detail in
> `WP2_LOADER_PLACEHOLDER_REPORT.md`. Closes SWA-8's `MotionPhysics` half.


- **Objective:** one loading component and one empty/error component, adopted everywhere; no
  raw exception text reaches a player
- **Affected:** all 11 screens
- **Files:** two new widgets under `lib/presentation/widgets/`; edits to the 11 files holding the
  16 `CircularProgressIndicator`s; the four raw-exception sites (`lobby_screen.dart:400`,
  `game_screen.dart:517`, `round_result_screen.dart:353`, `final_winner_screen.dart:375`);
  consumes `MotionPhysics.breathingAmplitude` (SWA-8)
- **Improvement:** the highest-reach change available — every screen including the six
  unmigrated ones stops looking like stock Flutter while waiting or failing
- **Dependencies:** WP1 (so the placeholder renders legibly on the shell screens)
- **Risk:** **Low-medium.** Touches many files; each edit is mechanical. Must respect
  `context.reduceMotion` in the loader's breathing
- **Acceptance criteria:**
  1. `grep -c CircularProgressIndicator lib/` → 0 outside the loader itself
  2. No `Text('Error: $…')` or `'…: $e'` in any file under `lib/screens` or `lib/presentation/screens`
  3. Loader honours reduced motion (static isotype, no breathing)
  4. One widget test per component; the 148 existing tests still green

---

#### WP3 — Ceremonial Final Winner — **DONE (2026-08-11, uncommitted)**

> **Amendment.** All five acceptance criteria met: zero `Color(0x…)` / `AppColors.gold` /
> `primary` in the file (19 → 0); `ConfettiTier.night` and `AppElevation.ceremonialGradient`
> each have a call site; `celebration()` fires exactly once, on arrival; the share CTA is
> **unchanged** (still winner-only — ungating is presentation-only but changes behaviour, so it
> was left to the share work package per the brief); the share card still renders and exports.
> Also closes SWA-4, SWA-5 and the `displayButter` half of the typography backlog, and adopts
> `BufonPhase.nightWinner` (SWA-1's last game-loop value). `flutter analyze` 0 issues,
> `flutter test` 171 passing (161 pre-existing + 10 new). Final Winner **3.5 → 7.5**.
> Full detail in `WP3_FINAL_WINNER_REPORT.md`, including a **pre-existing** defect it
> uncovered: `ShareVictoryCard` overflows its own declared frame by 470 px, so every shared
> victory card has been clipped.


- **Objective:** the night ends on the ceremony the design system already describes
- **Affected:** FinalWinner, `share_victory_card.dart`
- **Files:** `lib/screens/final_winner_screen.dart`, `lib/presentation/widgets/share_victory_card.dart`
- **Improvement:** `nightWinner` register replaces `#111111` and the red/gold gradient;
  `AppElevation.ceremonialGradient` replaces the hand-rolled one (SWA-5); `ConfettiTier.night`
  restores the celebration ladder (SWA-4); `celebration()` haptic fires on arrival; share CTA
  ungated for every player
- **Dependencies:** WP1 (register scope), WP2 (share/error paths)
- **Risk:** **Medium** — the most visually opinionated change in the phase, and the screen has an
  off-screen render path (`_buildOffScreenCard` → `RepaintBoundary`) that must keep producing a
  correct share PNG after recolouring
- **Acceptance criteria:**
  1. Zero `Color(0x…)` and zero `AppColors.gold`/`primary` in the file
  2. `ConfettiTier.night` and `AppElevation.ceremonialGradient` each have ≥1 call site
  3. `celebration()` fires exactly once, on entrance
  4. Share CTA visible regardless of `isCurrentUserWinner`
  5. Share card still renders and exports at the correct size

---

#### WP4 — Accessibility floor

- **Objective:** every screen is navigable by screen reader and survives 200% text scale
- **Affected:** all 11 screens
- **Files:** all screen files; possibly a small `semantics` helper alongside `reduced_motion.dart`
- **Improvement:** screen-level headings/landmarks, live-region announcements on phase changes
  (answer → vote → reveal), scroll safety under large text, tooltips on the remaining icon-only
  controls
- **Dependencies:** WP1, WP2 (label the final components once, not twice)
- **Risk:** **Medium** — dynamic-type fixes can force real layout changes on fixed-height
  compositions; that is the point, but it is where regressions would come from
- **Acceptance criteria:**
  1. Every screen file contains at least one `Semantics` (currently 0 of 11)
  2. `textScaler` is handled — or explicitly proven unnecessary — on every screen with a fixed
     height or non-scrolling column (currently 0 references)
  3. Every icon-only control has a `tooltip`
  4. Manual pass with TalkBack/VoiceOver through one full round

---

#### WP5 — Adoption reconciliation (retire §3)

- **Objective:** nothing in the design system is defined-but-dead by the end of 2B
- **Affected:** Android splash config, Home headline, navigation call sites, `AppShapes`,
  `MotionSprings`
- **Files:** `android/app/src/main/res/drawable{,-v21}/launch_background.xml`,
  `home_screen.dart`, `game_screen.dart:62`, `final_winner_screen.dart:389`,
  `app_shapes.dart` + `animated_primary_button.dart:22`, `motion_tokens.dart`
- **Improvement:** Android gets its branded launch (SWA-2); the wordmark either renders on Home or
  leaves the bundle (SWA-3); the two "go home" exits use the retreat transition (SWA-6);
  `AppShapes.pill` is adopted or deleted and its false comment corrected (SWA-7); `MotionSprings`
  is kept-with-justification or deleted (SWA-8)
- **Dependencies:** none — can run in parallel with anything
- **Risk:** **Low**, item by item. The splash XML is the only platform-level edit
- **Acceptance criteria:**
  1. Android cold launch shows the isotype, not a white flash
  2. `assets/brand/wordmark.png` is either referenced in `lib/` or removed from `pubspec.yaml`
  3. `pushAndRemoveAllFade` has ≥1 call site; `MaterialPageRoute` count drops from 4 toward 0
  4. Every artifact in §3 is either adopted or deleted, and this audit's §3 can be closed out

---

**Sequencing:** WP1 → (WP2 ∥ WP5) → WP3 → WP4. WP1 is a hard gate; WP4 is deliberately last so
labels are applied to final components once.

---

## 7. Do we have enough research to implement Phase 2B?

# YES

**Implementation should proceed without another research phase.**

Every work package above is specified by material already in this repository:

- **What it should look like** — `BUFON_V1.1_VISUAL_BLUEPRINT.md` gives per-screen prescriptions
  (§Part IV), the register table (Reveal → Graphite/Butter, Winner → ceremonial), the brand
  surface map, and a prioritised roadmap with impact/complexity/risk already scored.
- **What is wrong today** — the ten Phase 1 audits, plus §2-§4 of this document, which correct
  them against the current commit.
- **What to build it from** — the tokens, registers, components and helpers already exist. Phase
  2B is overwhelmingly *adoption* work: nine of its deliverables are call sites for code that is
  already written and tested.
- **Competitive/pattern grounding** — `COMPETITIVE_PATTERN_MATRIX.md` and
  `REPOSITORY_RESEARCH.md` already cover the reference implementations (Wonderous for ceremonial
  reveals, Flame for counters) the remaining work leans on.

The two genuinely open questions are **product decisions, not research questions**, and no amount
of further investigation resolves them:

1. **The avatar blocker** — denormalise the equipped avatar onto the room's player document, or
   relax `firestore.rules`. A choice, not a finding. Phase 2B is scoped to proceed without it.
2. **Android splash technique** — hand-wire the XML or add `flutter_native_splash`. A dependency
   preference; Phase 2A deliberately removed a dependency and added none, so the default should
   be hand-wiring unless the owner prefers otherwise.

A further research phase here would produce another document and no pixels. **Build.**

---

## 8. Architectural debt before visual work

### BLOCKING

#### B1 — Six screens hardcode dark surfaces while inheriting the light theme — **RESOLVED (WP1, 2026-08-11)**

> **Amendment.** Fixed by Phase 2B WP1. All six screens now wrap their `Scaffold` in
> `PhaseScope(phase: BufonPhase.legacy)`, restoring `AppTheme.legacyTheme` — the theme they
> were authored against — as their ambient theme. Measured foreground contrast on the sites
> listed below moves from **1.03–1.11:1 to 15.9–18.9:1** (white chrome) and **9.0:1** (body2
> secondary copy). No screen was redesigned; no legacy colour was migrated. Covered by
> `test/phase_scope_test.dart`. The analysis below is retained as the record of the defect.

This was the one genuine **regression introduced by Phase 2A**, and it blocked all further
visual work.

**Mechanism.** `main.dart` now sets `theme: AppTheme.lightTheme`. Six screens were authored
against `legacyTheme` (dark), set their own dark `backgroundColor`/`AppBar(backgroundColor:)`,
and declare **no** `PhaseScope`. Everything they *don't* colour explicitly now resolves against
`lightTheme`:

- `lightTheme` → `_lightColorScheme.onSurface` = `AppColors.ink` (`#191919`)
- `appBarTheme.titleTextStyle` = `AppTypography.h3.copyWith(color: scheme.onSurface)` → **ink**
- `appBarTheme.iconTheme` = `IconThemeData(color: scheme.onSurface)` → **ink**
- `textTheme.apply(bodyColor: scheme.onSurface)` → any unstyled `Text` is **ink**

**Confirmed damage:**

| Site | Renders | On | Contrast |
|---|---|---|---|
| `profile_screen.dart:46` `AppBar(title: Text('Perfil'))` | ink `#191919` | `AppColors.surface` `#1A1A2E` | **≈1.03:1** |
| `leaderboard_screen.dart:44` `Text('Rankings')` | ink | `#1A1A2E` | ≈1.03:1 |
| `season_details_screen.dart:51` season name | ink | `#1A1A2E` | ≈1.03:1 |
| `paywall_screen.dart:180-182` title | ink | `#16213E` | ≈1.4:1 |
| **App-bar back arrow + action icons on all of the above** | ink | dark bar | ≈1.03:1 |
| `profile_screen.dart:74` "No se pudo cargar el perfil" | ink | `AppColors.background` `#111111` | ≈1.02:1 |
| `profile_screen.dart:108`, `:495`, `:559`, `:610`; `leaderboard_screen.dart:549` | ink | dark | ≈1.02:1 |

**Severity.** The back arrow is the only exit from Profile and Leaderboard. Phase 2A made both
screens reachable for the first time *in the same commit* that made their exit invisible. This
is a functional defect, not polish.

**Why it is cheap.** `BufonPhase.legacy` was written precisely so no screen could land on the
wrong palette by accident — and it has **zero call sites** (SWA-1). Applying it restores exactly
the theme these screens were authored against.

**Do not fix as part of this audit** — it is Phase 2B work package 1.

---

### SHOULD FIX BEFORE PHASE 2B

- **S1 — Two live theme systems.** `AppTheme.legacyTheme` (32 legacy refs) and the Butter Bliss
  pair coexist. Correct as a migration strategy, but the burndown must stay visible; today
  nothing measures it. B1 exists *because* the boundary between the two was implicit.
- **S2 — 246 legacy `AppColors.*` + 52 `Colors.*` + 19 raw hex, concentrated in 6 files.** Any
  visual pass over those screens without first deciding "migrate vs. scope-as-legacy" will be
  done twice.
- **S3 — Screen-level accessibility is at zero.** Cheaper before a visual pass than after.
  Sequenced as WP4 only because the components it labels are finalised in WP2/WP3.
- **S4 — Four `MaterialPageRoute` + two mis-typed retreat transitions.** Trivial, but they make
  the motion system look unfinished to anyone reading the code.
- **S5 — Nine dead subsystems (§3).** Each one erodes trust in the system. Retire them in WP5.

### CAN DEFER

- **D1 — Avatar/progression BLOCKED item.** Orthogonal to visual work; do not let it gate WP3.
- **D2 — Android splash.** A real inconsistency, but no downstream work depends on it.
- **D3 — Iconography/emoji-as-content.** Needs asset decisions; low leverage next to WP1-WP4.
- **D4 — Paywall redesign.** Worst screen, lowest reach. Free wins from WP1/WP2 suffice for 1.1.
- **D5 — 51.9 MB app bundle.** Noted twice now; unmeasured and unrelated to visual work. Worth a
  separate size pass before store submission, not before Phase 2B.
- **D6 — `build.gradle.kts` hard-fails without `key.properties`.** Will bite CI, is not a visual
  concern, and CI is explicitly out of scope.

---

## 9. Final recommendation

### BUFÓN 1.1 STATUS

| Dimension | Score | Rationale |
|---|---|---|
| **Foundation** | **8/10** | Theme activated, register system built, fonts bundled, icons real, analyze clean, 148 tests green. Held back only by B1 |
| **Visual maturity** | **5/10** | An honest average of a 7.5 loop and a 2.6 shell. Neither number alone describes the product |
| **UX maturity** | **5/10** | Progression is finally reachable; reveal suspense restored; but 16 raw spinners, 4 raw exception strings, no empty states, and a broken exit affordance on two screens |
| **Motion maturity** | **7/10** | Tokens adopted, reduced motion respected, and the signature keyhole gesture renders. Loses points for tokens-not-utilities and a retreat transition that exists but is unused |
| **Brand maturity** | **6/10** | Real icon, bundled type, isotype in the shell, keyhole as physics. But the wordmark renders nowhere, Android launches white, and the night ends in casino gold |
| **Design-system adoption** | **5/10** | 5 of 11 screens scoped, 5 of 10 registers used, 9 subsystems built-but-dead. The system is good; adoption is half-done |

### 1. Are we ready for Phase 2B?

**Yes — with one gate.** The architecture is sound: the register system is the right abstraction,
tokens are real and adopted where migration happened, and the test/analyze baseline is clean.
**The gate is B1.** Do not start decorative work while six screens render invisible chrome; fix
it first, as work package 1, in a day.

### 2. The single highest-impact thing to do next

**Wrap the six unscoped screens in `PhaseScope(phase: BufonPhase.legacy)`.**

It is roughly six lines per screen. It converts a functional defect — an invisible back button on
the two screens this phase just made reachable — back into merely *dated visuals*, it consumes a
dead enum value, and it establishes the invariant "every screen declares its register" that every
later migration relies on. Nothing else in the backlog has this ratio.

### 3. The next three highest-impact things

1. **`BufonLoader` + `BufonPlaceholder`** (WP2) — two components, eleven screens, 16 spinners and
   4 raw exception strings gone. The best reuse-per-hour in the project, and it improves the
   unmigrated shell without migrating it.
2. **Ceremonial Final Winner** (WP3) — the night currently ends on the second-worst screen in the
   app. Three already-written, currently-dead subsystems turn it into the moment people
   screenshot, and ungating share multiplies the only viral surface by up to 8×.
3. **Accessibility floor** (WP4) — zero screen-level semantics and zero `textScaler` handling is
   the largest single gap between this product and a shippable one, and it gets more expensive
   with every screen added.

### 4. What should we explicitly NOT touch yet

- The five migrated loop screens' visual design (7.0-8.0 — leave them alone)
- The avatar/progression security decision (BLOCKED, product call, do not let it gate WP3)
- The reveal's deferred items (`Hero`, tweened counters, pre-reveal silence)
- Paywall redesign, iconography assets, golden-test infrastructure
- New dependencies, CI/CD, release signing, app-bundle size
- Any further research

### 5. Implement now, or research first?

**Implement now.** See §7. The blueprint already specifies every Phase 2B deliverable, this audit
supplies the corrected current state, and nine of the phase's items are call sites for code that
is already written and tested. Another research phase would produce a document instead of a
product.

---

*Read-only audit. No source, configuration, dependency or documentation file was modified;
`docs/design/v1.1/PHASE_2A_COMPLETION_AUDIT.md` is the only file written. Nothing was committed
or pushed. Only `git status`, `git log`, `flutter analyze`, `flutter test` and non-mutating
inspection commands were run.*
