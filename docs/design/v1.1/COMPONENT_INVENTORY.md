# COMPONENT INVENTORY — current state, gaps, 1.1 refinement, priority

> Every reusable and semi-reusable UI unit found in `bufon_flutter/lib/`.
> Priority key: **P0** foundational · **P1** high visual impact · **P2** useful refinement ·
> **P3** optional polish.

---

## 0. Inventory summary

**FACT.** Bufón has **11 genuinely reusable components** (in `lib/presentation/widgets/` and
`lib/presentation/transitions/`), **2 duplicated private banners**, and roughly **18 recurring
patterns that are inlined into screens instead of being components**. The gap between those last two
numbers and the first is where most of the visual inconsistency lives.

| Class | Count |
|---|---|
| Shared components (`presentation/widgets`, `transitions`) | 11 |
| Private widgets duplicated across screens | 4 |
| Recurring patterns with no component | ~18 |
| Components with all five states (default/pressed/selected/disabled/loading) per Cap. 14 | **1** |

---

## 1. Shared components

### 1.1 `AnimatedPrimaryButton` — P0

**Current.** `presentation/widgets/animated_primary_button.dart` (197 L). `GestureDetector` +
`AnimationController` at `MotionDurations.pressButton` (100 ms), `Tween 1.0 → 0.95` with
`MotionCurves.compress` forward / `MotionCurves.release` reverse. Fires
`HapticFeedback.lightImpact()` + `SoundService.tap()` on tap-down. Wraps an `AnimatedContainer`
(`settleButton`, 200 ms) with a two-stop `LinearGradient` of `backgroundColor → backgroundColor@80%`,
`AppShapes.borderRadiusMd`, and `AppElevation.protagonistShadow(backgroundColor)` unless pressed or
disabled. Slots: `icon`, `text`. Params for background/text/disabled colours, width, padding.

**Visual quality.** High mechanically — the best-feeling control in the app.

**States.** default ✅ · pressed ✅ · disabled ✅ · loading ✅ · **selected ✗** (not applicable).
This is the only component that satisfies Cap. 14's five-state rule.

**Problems.**
1. **FACT.** Applies a gradient to every enabled button. Cap. 3 law 1 and Cap. 34 both forbid
   gradient as a default button treatment; Cap. 8 reserves gradient for the ceremonial layer.
2. **FACT.** Defaults `backgroundColor` to `AppColors.primary` (legacy casino red) and text/icon to
   `Colors.white`. On a Paper screen an unparameterised instance renders red-on-Paper with white
   text.
3. **FACT.** Calls `HapticFeedback.lightImpact()` directly, bypassing `HapticService` — so haptics
   can never be centrally muted or throttled (Cap. 19's "economía de haptics" is unimplementable
   from here).
4. **FACT.** `isLoading` spinner defaults to `Colors.white` regardless of the fill colour.
5. **FACT.** Not a `Semantics` button; screen readers see a `GestureDetector` with a `Text` child.
6. **FACT.** No minimum height enforced. Padding is `lg`/`md` (24/16) around a 16pt label ⇒ ~52 px,
   under `AppSpacing.buttonHeight` (56) and near the 48 dp floor only by accident.
7. **FACT.** No reduce-motion path.

**1.1 refinement.** Flat fill by default (delete the gradient); ceremonial gradient available only
via an explicit `variant: ceremonial`; route haptics through `HapticService`; derive spinner and
disabled colours from the fill rather than hardcoding; wrap in `Semantics(button: true, label: text,
enabled: !isDisabled)`; enforce `minimumSize: Size(0, AppSpacing.buttonHeight)`; adopt
`AppShapes.pill` for the primary variant so the button finally echoes the logotype (Cap. 9);
short-circuit the scale animation when `MediaQuery.disableAnimations` is true.

**Priority: P0.** Every screen's primary action flows through it, and its gradient default is
single-handedly responsible for the 16-gradient count.

---

### 1.2 `GameCard` — P0

**Current.** `game_card.dart` (182 L). Press scale to `MotionScale.pressSubtle` (0.97) over
`pressCard` (150 ms) with the same compress/release pair; a separate `pulseSelect` (1.03) pulse
fired from `didUpdateWidget` when `isSelected` flips, accompanied by `HapticFeedback.mediumImpact()`.
Selected state draws a gradient of `selectedColor → selectedColor@70%`, a 2 px focus border, a
protagonist shadow and a trailing `Icons.check_circle`. Unselected draws `AppColors.surface` with a
hairline `AppColors.border`.

**Visual quality.** Mechanically excellent; the select-pulse-plus-medium-haptic pairing is exactly
Cap. 18's "two simultaneous signals per relevant tap".

**States.** default ✅ · pressed ✅ · selected ✅ · disabled ✅ · **loading ✗**.

**Problems.**
1. **FACT.** Legacy colours only: `AppColors.surface`, `surfaceDark`, `border`, and `success`
   as the default `selectedColor`. On voting this renders navy cards on near-black.
2. **FACT.** Selected text is forced `Colors.white`; on a Mint fill (`#63D6A5`) white text is
   ~1.9 : 1 — an accessibility failure at the moment of highest emotional stakes.
3. **FACT.** Gradient on selection (same Cap. 3 violation as above).
4. **FACT.** No `Semantics`; the answer text is the only accessible signal, and the *selected*
   state is conveyed by colour + icon with no semantic flag.
5. **FACT.** Fires haptics from `didUpdateWidget`, meaning a rebuild triggered by a Firestore
   snapshot for an unrelated field can re-fire the pulse if `isSelected` toggles.
6. **INFERENCE.** No text-length strategy. Answers are capped at 100 characters
   (`game_screen.dart` `maxLength: 100`), which at `body1` 16pt on a narrow phone at 200% text
   scale will overflow the card's single `Row`.

**1.1 refinement.** Flat fill; `Semantics(button: true, selected: isSelected, label: text)`;
`onSelectedColor` param so foreground contrast is explicit (Ink on Mint, not white on Mint);
per-phase default (`lavender` in voting per Cap. 33); allow multi-line with `maxLines: 4` +
`TextOverflow.ellipsis`; route haptics through `HapticService`.

**Priority: P0.** Voting is the emotional core of the game and this is the only component on it.

---

### 1.3 `TimerWidget` — P1

**Current.** `timer_widget.dart` (197 L). Custom-painted circular arc (`_CircularTimerPainter`,
4 px stroke, round cap, −π/2 start), colour ramp `accent → warning → primaryLight` at 10 s and 5 s,
scale pulse to `MotionScale.pulseUrgent` (1.10) each second under 10 s, `HapticFeedback.lightImpact()`
+ `SoundService.countdownPulse()` each second under 5 s, `AnimatedSwitcher` (`MotionDurations.swap`)
over three escalating copy lines, seconds rendered with `AppTypography.tabular(h3)`.

**Visual quality.** The most complete component in the app. Multi-channel (colour + scale + haptic +
sound + copy) exactly as Cap. 28 requires.

**States.** normal ✅ · warning ✅ · danger ✅ · expired ⚠️ (renders `0s`; no distinct treatment).

**Problems.**
1. **FACT.** Legacy colours (`accent` cyan, `warning` orange, `primaryLight` pink-red). Cap. 4
   assigns urgency to Coral and the answering phase to Sky.
2. **FACT.** Fires an identical `lightImpact` five times in five seconds. Cap. 19's economy rule
   explicitly forbids this ("dos haptics del mismo tipo separados por menos de 400 ms se colapsan";
   the last second should escalate to `mediumImpact`).
3. **FACT.** `Icons.timer_outlined` — a thin outline icon, forbidden by Cap. 12 and Cap. 34.
4. **FACT.** No `Semantics`; a screen reader gets no time-remaining announcement, and the arc is
   invisible to it.
5. **FACT.** No reduce-motion path — the 1.10 pulse fires regardless.
6. **INFERENCE.** The arc is 40×40 with a 20px icon inside it. At that size the arc reads as
   decoration rather than as information; the number does all the work.

**1.1 refinement.** Recolour Sky → Coral; escalate the final haptic; swap to a filled timer glyph or
the custom set; add `Semantics(liveRegion: true, label: '$seconds segundos restantes')` throttled to
announce at 30/10/5; honour reduce-motion by switching pulse → colour-only; consider growing the arc
to 56–64 px so it becomes the visual carrier of urgency rather than a bullet point.

**Priority: P1.** It already works; it needs recolouring, haptic discipline and a11y — not a rebuild.

---

### 1.4 `ConfettiWidget` — P1

**Current.** `confetti_widget.dart` (166 L). 50 particles, per-particle x/velocityX/velocityY/
rotation/rotationSpeed/size (4–12 px), one `CustomPainter` drawing rounded rects, alpha fading to
50% across the run, `IgnorePointer`, default 3 s. Restarts on `isActive` false→true.

**Visual quality.** Solid engine. Zero dependencies.

**Problems.**
1. **FACT.** Palette is hardcoded to the retired casino set: gold `#FFD700`, red `#E94560`, cyan
   `#00D9FF`, coral `#FF6B6B`, turquoise `#4ECDC4`, salmon `#FFA07A`. Cap. 21 specifies
   `[Butter 40%, Mint, Sky, Lavender, Coral 15% each]`.
2. **FACT.** `_controller.addListener(() => setState(() {}))` rebuilds the whole subtree ~60×/s.
   With `shouldRepaint => true` this repaints correctly but rebuilds unnecessarily.
   **INFERENCE.** Cheap today (the painter is the only child) but it is the kind of thing that
   becomes a jank source once the winner screen gains more animated siblings.
3. **FACT.** Particles that pass the bottom are `continue`d, not culled — the list stays at 50.
4. **FACT.** No density parameter. Cap. 22 asks for 50 (round) vs. 80–100 (night).
5. **FACT.** No reduce-motion path. Particle storms are a known vestibular trigger.
6. **FACT.** `round_result_screen.dart` passes `duration: 1800ms`; Cap. 22 specifies 3 s for a round
   winner. The final winner screen uses the 3 s default where Cap. 22 asks for 4–5 s.

**1.1 refinement.** Accept `colors` and `count` params defaulted to the Cap. 21 weighted palette and
Cap. 22 densities; drive the painter with an `AnimatedBuilder` instead of `setState`; add a
`fadeOut` tail; return `SizedBox.shrink()` when `disableAnimations` is set.

**Priority: P1.** Recolouring alone converts the biggest emotional moment in the game from
"generic celebration" to "Bufón celebration" for a handful of lines.

---

### 1.5 `RoundIndicator` — P2

**Current.** `game_progress_widgets.dart:557`. Pill-ish container (`radiusMd`), `AppColors.surface`
fill, hairline border, `Icons.sports_esports`, `"Ronda "` + current in `AppColors.primary` bold +
`"/total"`.

**Problems.** **FACT.** Legacy colours. **FACT.** `Icons.sports_esports` is a gamepad — semantically
wrong for a social party game and specifically named in the design doc's audit as generic Material.
**FACT.** No tabular figures on the round number. **FACT.** Placed in `AppBar.title`, which puts a
progress read-out in the position reserved for identity.

**1.1 refinement.** Replace the gamepad with the custom "round"/mask glyph; tabular figures;
`radiusFull` pill per Cap. 9; move it out of the app-bar title slot so the app bar can carry the
isotype instead (see `ASSET_AUDIT.md` §Logo placement).

**Priority: P2.**

---

### 1.6 `GameProgressBar` — P2

**Current.** `game_progress_widgets.dart:606`. `totalRounds` segments, 6 px tall, `circular(3)`,
filled `AppColors.primary` when completed-or-current, `surfaceDark` otherwise, plus a
"Ronda N de M" caption and a percentage.

**Problems.** **FACT.** Legacy colours. **FACT.** Shows *both* a segmented bar *and* "Ronda N de M"
*and* a percentage — three encodings of one fact, directly under a `RoundIndicator` in the app bar
that encodes it a fourth time. **FACT.** No animation on segment fill (Cap. 18 asks for a `Settle`
on every counter increment). **FACT.** `isCompleted || isCurrent` means the current round renders
identically to a finished one — the player cannot see where they are.

**1.1 refinement.** Delete the percentage and the caption (the segments *are* the message); give the
current segment a distinct treatment (Sky fill vs. Ink-tinted completed); animate fill with
`MotionDurations.settle`; drop the duplicate `RoundIndicator`.

**Priority: P2** — but the *deletion* half is P1, because removing three redundant read-outs
directly serves Cap. 3 law 4 on the two worst-hierarchy screens.

---

### 1.7 `SeasonCountdownBanner` — P2

**Current.** `season_countdown_banner.dart` (117 L). `GestureDetector` → `SeasonDetailsScreen` via
`MaterialPageRoute`; `HapticService.lightImpact()`. Gradient from `Season.themeColor@20% → @10%`,
2 px border in `themeColor`, coloured `BoxShadow` blur 10, 48 px circle holding
`Icons.emoji_events`, name in `h3`, countdown copy, `Icons.chevron_right`.

**Problems.** **FACT.** Every colour comes from an unconstrained Firestore int (see
`DESIGN_SYSTEM_AUDIT.md` §6). **FACT.** Gradient + coloured glow + 2 px border + trophy icon +
chevron on a component that sits **above the wordmark** on Home — it out-competes the brand for
attention on the app's first screen. **FACT.** `h3` (24pt) for the season name vs. `display` (48pt)
for "BUFÓN" is only 2× — borderline against Cap. 3 law 4. **FACT.** Uses `AppColors.textPrimary`
(white) on a Paper screen; only survives because the season gradient is dark enough — a light
`themeColor` would make it invisible.

**1.1 refinement.** Constrain to a named `SeasonAccent`; flatten to `accentTint` fill + hairline;
drop the glow; move below the primary CTA (a season is context, not the reason you opened the app);
Ink text.

**Priority: P2** (P1 if seasons ship as a marketing surface in 1.1).

---

### 1.8 `SeasonBadgesSection` — P3

**Current.** `season_badges_section.dart` (123 L). Horizontal 140 px-tall list of 120 px cards,
`circular(12)` (off-scale), rank-derived colour and icon: `#1 → gold + Icons.workspace_premium`,
`≤10 → primary + Icons.photo_size_select_actual`, `≤100 → accent + Icons.stars`, else
`textSecondary + Icons.emoji_events`.

**Problems.** **FACT.** `Icons.photo_size_select_actual` is a photo-cropping icon used to represent
a top-10 season finish — almost certainly a mis-pick. **FACT.** Off-scale radius. **FACT.** Legacy
colours. **FACT.** Empty and error both collapse to `SizedBox.shrink()`.

**1.1 refinement.** Fix the icon; move to `radiusLg`; map rank tiers to the shared `Rarity` ladder;
give it a real empty state.

**Priority: P3** — it lives inside an unreachable screen. Fix the navigation first.

---

### 1.9 `ShareVictoryCard` — P1

**Current.** `share_victory_card.dart` (306 L). A 600×800 `RepaintBoundary` widget rendered
off-screen at `left/top: -10000` and captured at `pixelRatio: 3.0`. Contents: three-stop background
gradient, a static `_ConfettiPainter` (deterministic `i*37 % width` positions, `shouldRepaint =>
false`), a radial gold glow, `'👑'` at 80pt, `'BUFÓN DE LA NOCHE'` at 48pt gold with a 20 px gold
shadow and `letterSpacing: 4`, a 220 px gold-gradient avatar circle with a 50 px blur / 15 px spread
glow holding the avatar **emoji** at 120pt, the player name at 42pt, a stats box, an italic
`'🎭 Maestro del caos y rey del drama 🎭'`, and a `'BUFÓN'` text watermark at 28pt gold.

**Visual quality.** This is the artefact that leaves the app and lands in a WhatsApp group — the
single highest-leverage brand surface Bufón has. Today it is the *least* on-brand thing in the repo.

**Problems.**
1. **FACT.** Entirely gold/red casino palette. Cap. 31 mandates a full-bleed **Butter** background
   ("nunca Graphite — debe verse alegre incluso fuera de contexto").
2. **FACT.** The wordmark is *typed text* in the ambient font, not the actual logotype asset.
   **INFERENCE.** With `google_fonts` runtime fetching, a share card generated before the font
   downloads renders "BUFÓN" in Roboto — the brand's name in someone else's typeface, permanently,
   in a screenshot that outlives the session.
3. **FACT.** Protagonist is ambiguous: crown emoji, 48pt title, 220 px avatar and 42pt name all
   compete. Cap. 31 is explicit that for a night-winner card the protagonist is the **avatar**, with
   the score "diminuto, casi una nota al pie". The current card gives the stats a bordered box of
   equal weight.
4. **FACT.** `roundWins` is fed `widget.totalScore` from `final_winner_screen.dart:311` and labelled
   "Rondas" — the card says "N Rondas" where N is a point total.
5. **FACT.** Avatar is an emoji, so the card's face is Apple's or Google's artwork, not Bufón's.
6. **FACT.** Only one card type exists. Cap. 31 v1.1 specifies four distinct compositions (night
   winner / best answer / profile streak / leaderboard position) and explicitly calls a single
   template insufficient.

**1.1 refinement.** Butter ground, Ink type, real isotype PNG in a fixed corner, avatar as sole
protagonist, score as a footnote, fix the `roundWins` mislabel, bundle the display font before
shipping any card, and add the **"best answer of the night"** card — Cap. 31 correctly identifies it
as the most shareable variant because the joke *is* the content.

**Priority: P1.** Highest brand-reach-per-line-of-code in the entire codebase.

---

### 1.10 `ShareProfileCard` — P2

**Current.** `share_profile_card.dart` (261 L). Same 600×800 output but built with a raw
`PictureRecorder` + `Canvas` + `ParagraphBuilder` rather than a widget tree. Dark grey gradient, a
40 px dot grid, `'BUFÓN'` at 48pt gold, a gold rule, a gold-gradient avatar circle, a level pill,
an optional title box coloured by `TitleRarity`, XP, an emoji stat line, a CTA and a watermark.

**Problems.** **FACT.** Two different rendering strategies for two cards that should look like
siblings — one widget-based, one canvas-based; every visual fix must be made twice, in two
languages. **FACT.** `_buildTextParagraph` passes no `fontFamily`, so this card *always* renders in
the platform default regardless of `google_fonts`. **FACT.** 15 raw colour literals. **FACT.** Same
gold/grey casino identity. **FACT.** Layout is absolute-positioned (`yOffset` arithmetic) and will
clip on long titles.

**1.1 refinement.** Rebuild on the same `RepaintBoundary` widget pipeline as the victory card and
extract a shared `ShareCardScaffold` (Butter ground, isotype corner, generous negative space,
one protagonist slot) so Cap. 31's four variants are four compositions over one chassis.

**Priority: P2** — it serves an unreachable screen, but the shared chassis is P1 work that this
consumes for free.

---

### 1.11 `KeyholeRevealTransition` — P1

**Current.** `keyhole_reveal_transition.dart` (107 L). `AnimatedWidget` + `ClipPath` +
`CustomClipper` expanding a circular mask from a configurable `origin` to the farthest-corner
radius, with an optional backdrop colour. Correct `shouldReclip`. Well documented.

**Problems.** **FACT.** Zero call sites. It is the design system's declared *ownable gesture*
(`BRAND PHYSICS`: "el reveal como mirilla", derived from the keyhole cut in the isotype's hat tips)
and it has never rendered a frame.

**1.1 refinement.** Wire it into `round_result_screen.dart` as the stage-1→stage-2 reveal, driven by
an `AnimationController` over `MotionDurations.revealStage` (800 ms) with an `easeOut`-family curve,
`origin: Alignment.center`, `backdropColor: AppColors.graphite`. Add a reduce-motion fallback to a
cross-fade.

**Priority: P1.** Highest identity-per-effort ratio in the motion layer: the code is already
written and reviewed.

---

## 2. Duplicated private widgets

| Widget | Locations | Problem |
|---|---|---|
| `_TransitionBanner` | `game_screen.dart:541` | Gold-tinted, `TweenAnimationBuilder` scale-fade 350 ms |
| `_VoteTransitionBanner` | `voting_screen.dart:1023` | Green-tinted, `AnimatedOpacity` fixed at `opacity: 1` — **never animates** |
| `_WinnerSpotlight` | `round_result_screen.dart:331` | Gold gradient hero card; the only reveal component |
| `_ConfettiPainter` | `confetti_widget.dart:324` **and** `share_victory_card.dart:1439` | Two unrelated classes, same name, different behaviour |

**RECOMMENDATION (P1).** Collapse the two banners into one shared `PhaseBanner` component with a
`tone` (info/waiting/success/tension) resolved from the phase accent, and give it one real entrance
(`Arrive`: scale from `MotionScale.arriveFrom` 0.88 + fade, `MotionDurations.arrive` 250 ms). This
removes a live bug (the voting banner's dead animation) and one duplicated file.

---

## 3. Patterns with no component (the real inconsistency source)

**FACT.** Each of these is re-implemented inline, multiple times, with divergent styling:

| # | Pattern | Inline occurrences | Divergence observed |
|---|---|---|---|
| 1 | Status / progress container | 4 (game, voting ×2, lobby) | different fills, borders, tint alphas |
| 2 | Full-screen loader | 11 | all bare `CircularProgressIndicator`, one coloured `#E94560` |
| 3 | Empty state | 2 | 64 px Material icon + h2 + body |
| 4 | Error state | 7 | 2 designed, 5 raw `Text('Error: $error')` |
| 5 | Player row | 3 (lobby `ListTile`, round result `ListTile`, leaderboard row) | 3 different avatar treatments |
| 6 | Avatar presentation | 6 | 80/96/100/120 px emoji, 3 different circle treatments |
| 7 | Stat tile (icon + value + label) | 4 | `final_winner`, both share cards, profile |
| 8 | Rarity chip / badge | 3 | two colour ladders, both non-brand |
| 9 | Snackbar | 12 | 5 different `backgroundColor` sources incl. `Colors.green`, `Colors.red.shade700`, `Colors.orange` |
| 10 | Section header | 5 | `h3`, `h4`, and `h4.copyWith(bold)` used interchangeably |
| 11 | Question display | 3 (game gradient card, voting tinted echo, none in reveal) | gradient vs. tint vs. absent |
| 12 | Copy-to-clipboard | 1 (lobby) | `IconButton` + silent `SnackBar`; Cap. 18 requires an icon `Swap` to a check |
| 13 | XP / level bar | 2 (profile, public profile) | different radii |
| 14 | Tab bar | 3 (profile 2 tabs, leaderboard 3 tabs, all raw Material `TabBar`) | legacy indicator colour |
| 15 | Sliver header | 2 (season details, public profile) | both hand-rolled |
| 16 | Offer / price card | 2 (paywall) | equal weight, no recommended state |
| 17 | Countdown text | 2 (banner, season details) | different thresholds and emoji use |
| 18 | Locked/unlocked item tile | 3 (avatars, achievements, titles) | 3 different lock treatments |

**INFERENCE.** Twelve `SnackBar` call sites with five colour sources is the clearest single measure
of the system's adoption gap. `AppTheme` already themes `SnackBar` correctly in
`lightTheme`/`darkTheme`; screens override it anyway because they were written before the theme
existed and because the legacy theme is what's applied.

**RECOMMENDATION (P0).** Build exactly five primitives in 1.1 and delete the inline versions:

1. `BufonStatusPanel` — the answer/vote progress container (covers #1).
2. `BufonLoader` — Cap. 24's "breathing isotype" instead of a spinner (covers #2).
3. `BufonPlaceholder` — one component with `empty` / `error` / `offline` variants, brand
   illustration slot, voice-correct copy, at most one action (covers #3, #4).
4. `BufonPlayerRow` — avatar + name + host/online chip + trailing slot (covers #5, #6 partially).
5. `BufonFeedback.show(context, tone)` — one snackbar/toast entry point reading tone from the phase
   accent (covers #9).

Five components remove roughly 30 inline implementations. That is the highest
consistency-per-effort trade available.

---

## 4. Rarity: a specific consolidation

**FACT.** Two divergent ladders, neither brand-aligned:

| Rarity | `AvatarRarity.color` (String) | `TitleRarity.color` (int) | In Butter Bliss? |
|---|---|---|---|
| common | `#CCCCCC` | `0xFFB3B3B3` | No |
| rare | `#4A9EFF` | `0xFF2196F3` | No (Sky is `#6BC8FF`) |
| epic | `#B24AFF` | `0xFF9C27B0` | No (Lavender is `#9C8CFF`) |
| legendary | `#FFD700` | `0xFFFFD700` | No — `gold` is **retired** by Cap. 5 |

**RECOMMENDATION (P1).** One `Rarity` enum returning `Color` from `AppColors`:
common → `inkSoft` · rare → `sky` · epic → `lavender` · legendary → `butter`. This retires the last
two live uses of the deleted `gold` concept and makes "legendary" the brand's own colour — which is
strictly better storytelling than gold, because Butter *is* the mark.

---

## 5. Priority roll-up

| Priority | Components |
|---|---|
| **P0** | `AnimatedPrimaryButton`, `GameCard`, + the five new primitives (§3) |
| **P1** | `TimerWidget`, `ConfettiWidget`, `KeyholeRevealTransition` (wire it), `ShareVictoryCard`, `PhaseBanner` consolidation, `Rarity` consolidation |
| **P2** | `RoundIndicator`, `GameProgressBar`, `SeasonCountdownBanner`, `ShareProfileCard` |
| **P3** | `SeasonBadgesSection` |

**Cross-cutting P0 for every component:** `Semantics`, a reduce-motion path, and haptics routed
through `HapticService`. These three are cheap per component and currently absent from all of them.
