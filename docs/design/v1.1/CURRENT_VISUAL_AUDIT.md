# CURRENT VISUAL AUDIT — Bufón, as of 2026-08-09

> Scope: what Bufón **actually looks and feels like today**, verified file by file against the
> repository at commit `ae65c54`. No production code was modified to produce this document.
>
> Evidence labels used throughout this document set:
> **FACT** = observed in this repository · **REFERENCE** = observed in an external project ·
> **INFERENCE** = reasoned conclusion · **RECOMMENDATION** = proposed 1.1 direction.

---

## 0. Executive statement

**FACT.** Bufón is not visually incomplete — it is visually **bifurcated**. Two complete design
systems ship side by side in the same binary:

1. A rigorous, documented, brand-derived system ("Butter Bliss") defined across
   `app_colors.dart`, `app_typography.dart`, `app_spacing.dart`, `app_shapes.dart`,
   `app_elevation.dart`, `motion_tokens.dart` and `app_theme.dart` — 4 of its 6 token files are
   complete and internally consistent.
2. A legacy "casino nocturno" theme (dark navy `#1A1A2E`, hot red `#E94560`, cyan `#00D9FF`,
   gold `#FFD700`) that `main.dart` still applies globally as `AppTheme.legacyTheme`.

**FACT.** Exactly **two** of eleven user-facing screens have migrated to the new system
(`home_screen.dart`, `lobby_screen.dart`), and they do it by locally overriding `Theme` rather
than by the app adopting `lightTheme`/`darkTheme` globally.

**INFERENCE.** The perceived-quality ceiling today is not set by missing design thinking — the
design thinking is unusually far ahead of most indie projects. It is set by **adoption**: the
system exists, and 82% of the app has not been wired to it.

---

## 1. Screen and surface inventory

Discovered by enumerating `lib/screens/`, `lib/presentation/screens/`, `lib/presentation/dialogs/`
and tracing every `Navigator` call site.

### 1.1 Core game loop — `lib/screens/` (6 screens)

| # | Screen | File | Theme register | Reachable from |
|---|---|---|---|---|
| 1 | Home | `home_screen.dart` (247 L) | **Butter Bliss light** (local `Theme` override) | app root (`main.dart`) |
| 2 | Lobby | `lobby_screen.dart` (385 L) | **Butter Bliss light** (local `Theme` override) | Home (create/join) |
| 3 | Answering ("game") | `game_screen.dart` (596 L) | Legacy casino | Lobby, Round result |
| 4 | Voting | `voting_screen.dart` (469 L) | Legacy casino | Game |
| 5 | Round result / Reveal | `round_result_screen.dart` (467 L) | Legacy casino | Voting |
| 6 | Final winner | `final_winner_screen.dart` (391 L) | Legacy casino + hardcoded `#111111` | Round result |

### 1.2 Meta / progression — `lib/presentation/screens/` (5 screens)

| # | Screen | File | Theme register | Reachable from |
|---|---|---|---|---|
| 7 | Profile | `profile_screen.dart` (616 L) | Legacy casino | **nothing — orphaned** |
| 8 | Public profile | `profile_public_screen.dart` (772 L) | Legacy casino | Profile only (∴ orphaned) |
| 9 | Leaderboard | `leaderboard_screen.dart` (556 L) | Legacy casino | **nothing — orphaned** |
| 10 | Season details | `season_details_screen.dart` (343 L) | Legacy casino | `SeasonCountdownBanner` on Home |
| 11 | Paywall | `paywall_screen.dart` (367 L) | **No tokens at all** — raw hex | Lobby (`MonetizationException`) |

### 1.3 Dialogs (1)

| # | Surface | File | Reachable from |
|---|---|---|---|
| 12 | Title selector | `title_selector_dialog.dart` (341 L) | Public profile only (∴ orphaned) |

### 1.4 The reachability finding

**FACT.** `grep -rn "ProfileScreen" lib` and `grep -rn "LeaderboardScreen" lib` return **zero**
inbound references outside their own definitions. `HomeScreen` renders only: a season banner, a
title, a tagline, a name field, "Crear Sala", a divider, a code field, "Unirse a Sala". There is no
app bar, no navigation drawer, no bottom navigation, no profile affordance.

**INFERENCE.** Roughly **2,285 lines** of finished progression, avatar, title, achievement and
leaderboard UI — plus the entire XP/level/season economy behind it — is **unreachable by a
player**. This matches the unchecked item "Add navigation to ProfileScreen from HomeScreen" in
`bufon_flutter/PHASE_3B_CHECKLIST.md`.

**INFERENCE.** This is the single largest UX gap in the product, and it is not a visual problem —
it is a missing navigation shell. Every visual improvement to those five screens has zero player
impact until the shell exists.

### 1.5 Surfaces that do not exist

**FACT.** Verified absent by grep across `lib/`:

- **Onboarding / first-run / how-to-play** — no matches for `onboarding`, `tutorial`, `cómo jugar`.
- **Settings / preferences** — no settings screen; sound and haptics cannot be turned off.
- **Auth UI** — `signInAnonymously()` is called silently inside `_createRoom`/`_joinRoom`. There is
  no sign-in surface, no account, no identity beyond a typed display name.
- **Pack / category selection** — `assets/questions.json` contains 20 questions across **3 named
  packs** (`DI LA NETA` ×8, `¿QUÉ PEDO?` ×6, `ALGUIEN DE AQUÍ` ×6). `QuestionService` reads only
  `id` and `text`; the `pack` field is parsed nowhere and surfaced nowhere.
- **Night Pass surface** — Night Pass exists as an IAP and a room field, but has no screen of its
  own; it appears only as a purchase option inside the paywall.
- **Permission states** — no permission prompts of any kind exist in the Flutter layer.
- **Network / offline state** — `ConnectionService` runs a heartbeat, but no UI communicates
  connectivity. A disconnected player learns about it via a `SnackBar` after being ejected home.

---

## 2. State coverage per surface

**FACT.** Loading / empty / error states, counted across the whole app:

| State type | Implementation found | Count |
|---|---|---|
| Loading (full screen) | bare `Center(child: CircularProgressIndicator())` | 11 |
| Loading (in button) | `AnimatedPrimaryButton.isLoading` → white 20×20 spinner | 1 component |
| Empty state | `leaderboard_screen.dart:489`, `title_selector_dialog.dart:148` | 2 |
| Error state (designed) | `leaderboard_screen.dart:521`, `profile_public_screen.dart:641` | 2 |
| Error state (raw text) | `Scaffold(body: Center(child: Text('Error: $error')))` | 5 |
| Silent failure | `error: (_, __) => const SizedBox.shrink()` | 6 |

**FACT.** Six providers swallow errors into `SizedBox.shrink()` (`season_badges_section.dart:55`,
`season_countdown_banner.dart:102`, `leaderboard_screen.dart:335`,
`profile_public_screen.dart:513` and `:524`). The affected UI simply vanishes.

**INFERENCE.** A player whose season data fails to load sees the Home screen without a season
banner and has no way to know anything failed. This is not a visual bug but it reads as one:
the screen looks different for reasons the player cannot attribute.

---

## 3. Colour reality check

**FACT.** `AppColors` declares 24 Butter Bliss tokens and 27 legacy tokens plus 3 legacy gradients.

**FACT.** Butter Bliss token usage outside `app_colors.dart` and `app_theme.dart`:

| Token | Uses in screens/widgets |
|---|---|
| `ink` | 9 |
| `butterShade` | 5 |
| `inkSoft` | 4 |
| `butter` | 3 |
| `butterTint` | 3 |
| `paperLine` | 2 |
| `paper`, `paperTint`, `graphite`, `graphitePlus1`, `mint`, `mintTint`, `coral`, `sky`, `lavender` | **0** |

All 26 of those uses are in `home_screen.dart` (6) and `lobby_screen.dart` (19), plus one in
`app_typography.dart`.

**INFERENCE.** The design system's central emotional device — Cap. 4's "one emotional colour per
phase" and Cap. 33's Sky/Lavender/Mint/Graphite phase registers — is **entirely unrealised**. The
dark "live game" register (Cap. 29) exists only as an unused `ColorScheme` in `app_theme.dart`.
A player currently cannot tell Answering from Voting by colour, because both are the same legacy
navy with red accents.

**FACT.** 26 raw `Color(0xFF…)` literals live outside `app_colors.dart`. `paywall_screen.dart`
alone contains 21 raw colour expressions including `Color(0xFF1A1A2E)`, `Color(0xFF16213E)`,
`Color(0xFFE94560)`, `Colors.green`, `Colors.red.shade700`.

**FACT.** 16 `Gradient(` construction sites exist across 11 files. `BUFON_DESIGN_SYSTEM.md`
Cap. 3 law 1 states the verifiable target is "as máximo 2-3 resultados".

---

## 4. Typography reality check

**FACT.** `app_typography.dart` routes both `_display()` and `_body()` to
`GoogleFonts.plusJakartaSans`. The `_display` function carries an explicit
`TODO(design-system)` noting the Display face is undecided.

**FACT.** `pubspec.yaml` `flutter.assets` contains exactly one entry: `assets/questions.json`.
There is **no `fonts:` section** and no bundled `.ttf`/`.otf` anywhere in the repository.

**REFERENCE.** `google_fonts` fetches font files over HTTP at runtime by default and caches them
on the device filesystem; the package's own guidance for released apps is to settle on specific
fonts and bundle them as assets.

**INFERENCE — high severity.** On a cold first launch with no or slow network — a realistic
condition for a party game opened at a bar, a house with saturated Wi-Fi, or a phone in airplane
mode — Bufón renders its entire type system in the **platform default face** (Roboto / SF Pro).
The one screen that is supposed to look most like the brand (Home, with `display` 48pt "BUFÓN")
is the screen most exposed to this. This is a production-grade brand defect, not a nicety.

**FACT.** The typography scale itself (12/14/16/20/24/28/32/48) is coherent, centralised, and used
consistently: 100% of text styles in `lib/screens/` and `lib/presentation/` derive from
`AppTypography`. There are no free-floating `TextStyle(fontSize: …)` calls in screen code except
inside the two share-card generators and emoji sizing.

**FACT.** `AppTypography.tabular()` exists and is applied in exactly two places: `TimerWidget`'s
seconds readout and the Lobby room code. Score displays, XP counters and round counters do not
use it.

---

## 5. Motion reality check

See `MOTION_AUDIT.md` for the full inventory. Headlines:

**FACT.** `motion_tokens.dart` is a complete, documented motion vocabulary (durations, curves,
scale factors, spring descriptions, brand physics constants). Three widgets consume it:
`AnimatedPrimaryButton`, `GameCard`, `TimerWidget`.

**FACT.** `KeyholeRevealTransition` — the "mirilla" transition that `BUFON_DESIGN_SYSTEM.md`
identifies as Bufón's *ownable gesture*, derived from the keyhole cut in the isotype's hat tips —
is fully implemented in `lib/presentation/transitions/keyhole_reveal_transition.dart` and has
**zero call sites**.

**FACT.** Unused motion tokens: `MotionDurations.arrive`, `.revealStage`, `.celebratory`, `.press`;
`MotionScale.arriveFrom`, `.celebrationOvershoot`; all of `MotionSprings`; all of `MotionPhysics`
(breathing amplitude/period, overshoot ratio).

**FACT.** `FadeSlidePageRoute` is used for 4 navigations. `MaterialPageRoute` is still used for 7,
including Home → Lobby, Lobby → Game, Round result → Game, and Round result → Final winner — i.e.
**the entire forward spine of the game loop still uses the default Material transition.**

---

## 6. What is genuinely good today

Recording this precisely matters as much as recording the gaps, because 1.1 must not destroy it.

1. **FACT.** `AnimatedPrimaryButton` implements real asymmetric press physics: forward on tap-down
   with `MotionCurves.compress`, reverse with `MotionCurves.release` (`easeOutBack`), plus haptic
   and sound on tap-down. This is better game feel than most shipped indie Flutter apps.
2. **FACT.** `TimerWidget` is a custom-painted circular arc with a colour ramp (accent → warning →
   danger), a scale pulse under 10s, escalating urgency copy swapped through an `AnimatedSwitcher`,
   per-second haptic + sound under 5s, and tabular figures. It is the most complete component in
   the app.
3. **FACT.** `ConfettiWidget` is a self-contained 50-particle simulation with gravity, per-particle
   velocity and rotation, drawn in one `CustomPainter` — no dependency, good performance shape.
4. **FACT.** The two-stage reveal in `round_result_screen.dart` (750 ms → 1550 ms, light haptic →
   `celebration()`, `AnimatedSwitcher` between "…" and the answer, then between "preparando" and
   the author) is a genuinely well-timed dramatic device.
5. **FACT.** `GameCopy` has a real, consistent, funny voice in Spanish
   ("No presionamos, pero sí estamos juzgando", "Aquí se separa el chiste fino del crimen social").
6. **FACT.** The Lobby room-code block is the single best-executed piece of visual design in the
   app: `butterTint` fill, `butterShade` hairline, `AppElevation.protagonistShadow`, `radiusXl`,
   tabular display type at 32pt with `letterSpacing: 4`. It is exactly what Cap. 3 law 4 asks for.
7. **FACT.** `AppShapes` and `AppElevation` deliberately reject Material's z-axis elevation model
   in favour of a three-layer narrative focus model, and document why. That is real design-system
   authorship, not theme configuration.

---

## 7. What is weak

| # | Finding | Evidence | Severity |
|---|---|---|---|
| 1 | Brand marks appear nowhere in the app | `BUFON-ISOTIPE.png`/`BUFON-LOGO.png` live in `public/`, not in `pubspec.yaml` assets | Critical |
| 2 | App icon is the stock Flutter logo | `ios/…/Icon-App-1024x1024@1x.png` verified visually | Critical |
| 3 | App name is `bufon_flutter` / `Bufon Flutter` | `AndroidManifest.xml:7`, `Info.plist:10` | Critical |
| 4 | Progression surface unreachable | zero inbound refs to `ProfileScreen`/`LeaderboardScreen` | Critical |
| 5 | Fonts fetched at runtime, no bundle | `pubspec.yaml` has no `fonts:` | High |
| 6 | Game phases are colour-identical | `mint`/`sky`/`lavender`/`graphite` unused in screens | High |
| 7 | Raw exceptions shown to players | 6 sites interpolate `$e`/`$error` into UI strings | High |
| 8 | No accessibility affordances | 1 `tooltip` total; 0 `Semantics`, 0 `textScaler`, 0 reduce-motion | High |
| 9 | Paywall is fully unmigrated | 21 raw colour expressions, own hardcoded dark palette | High |
| 10 | Loop uses default Material transitions | 7 `MaterialPageRoute` call sites on the forward spine | Medium |
| 11 | Confetti palette is the retired casino palette | `confetti_widget.dart:266-276` | Medium |
| 12 | Winner avatar hardcoded | `round_result_screen.dart:162` passes `'default'` | Medium |
| 13 | Share CTA gated to the winner only | `final_winner_screen.dart:273` | Medium |
| 14 | Rarity colours defined twice, divergently | `avatar.dart:24` (String hex) vs `title.dart:31` (int) | Medium |
| 15 | Scoreboard competes with the reveal | scoreboard renders at `_revealStage == 0` | Medium |
| 16 | Empty states use bare Material icons | `Icons.emoji_events_outlined` 64px, `Icons.military_tech_outlined` 64px | Medium |
| 17 | Packs exist in data but not in product | `pack` field parsed nowhere | Medium |
| 18 | Emoji carry the entire illustration load | 12 avatars, all achievements, all share cards | Medium |
| 19 | 16 gradients vs. a stated budget of 2–3 | grep `Gradient(` | Low |
| 20 | Three widgets bypass `HapticService` | direct `HapticFeedback.*` in button/card/timer | Low |

---

## 8. What is inconsistent

**FACT — the same concept rendered three different ways:**

- *Progress*: `GameProgressBar` (segmented bar) on Game/Voting, `LinearProgressIndicator` in the
  answer/vote counters on the same screens, and a third `ClipRRect`+`LinearProgressIndicator` XP
  bar in Profile. Three visual languages for "how far along".
- *Confirmation*: Game screen confirms an answer with a full-width mint-tinted card + 48px check
  icon; Voting confirms a vote with a `SnackBar` **and** an inline banner **and** a colour change on
  the progress container. Round result confirms nothing.
- *Rarity*: `AvatarRarity.color` returns `'#CCCCCC'|'#4A9EFF'|'#B24AFF'|'#FFD700'` as a
  **String**; `TitleRarity.color` returns `0xFFB3B3B3|0xFF2196F3|0xFF9C27B0|0xFFFFD700` as an
  **int**. Neither routes through `AppColors`. Grey, blue, purple and gold appear nowhere in the
  Butter Bliss palette.
- *Corner radii*: `AppShapes` defines 8/12/16/20/28/999. Screens still hand-roll
  `BorderRadius.circular(12)` (`season_badges_section.dart:753`, `season_countdown_banner.dart:845`,
  `season_details_screen.dart`), `circular(16)`, `circular(20)`, `circular(25)`, `circular(10)`,
  `circular(3)`.
- *Banners*: `_TransitionBanner` (game screen, gold) and `_VoteTransitionBanner` (voting screen,
  green) are two near-identical private widgets in two files with different colours and different
  entrance animations (`TweenAnimationBuilder` scale-fade vs. `AnimatedOpacity` at constant 1.0 —
  the latter never actually animates).

---

## 9. Composition and hierarchy

**FACT.** Measured against Cap. 3 law 4 ("one element ≥ 2.5× the second largest"):

| Screen | Protagonist | Passes? |
|---|---|---|
| Home | "BUFÓN" at 48pt | **Yes** |
| Lobby | Room code at 32pt in a shadowed hero card | **Yes** |
| Game | Question card (h2, 28pt, gradient) vs. timer vs. progress bar vs. answer field vs. counter | **No** — 5 competing blocks |
| Voting | Prompt (h2) + question echo + N answer cards + status container | **No** |
| Round result | Winner spotlight *and* full scoreboard simultaneously | **No** |
| Final winner | 180px avatar circle | **Yes** |
| Profile | Avatar emoji at 80pt | Borderline — tabs immediately compete |
| Leaderboard | List; no protagonist | **No** — by nature a dashboard |
| Paywall | Two equal-weight offer cards | **No** |

**INFERENCE.** The three screens where a player spends ~70% of session time (Game, Voting, Round
result) are precisely the three that fail the hierarchy law. This is the highest-leverage visual
finding in the audit: it is not about colour or type, it is about **what the screen makes you look
at**.

---

## 10. Responsive / device behaviour

**FACT.** `main.dart` locks orientation to portrait only.
**FACT.** `home_screen.dart` uses `LayoutBuilder` + `SingleChildScrollView` + `ConstrainedBox` —
the only screen with an explicit small-screen strategy (added by commit `7c9bd74`, "fix Home layout
overflow").
**FACT.** `game_screen.dart` uses `Spacer()` inside a non-scrolling `Column`; `voting_screen.dart`
and `round_result_screen.dart` use `Expanded` + list. `final_winner_screen.dart` scrolls.
**FACT.** No breakpoints, no `MediaQuery` size branching, no tablet layout anywhere.

**INFERENCE.** `game_screen.dart` is the highest overflow risk: a fixed `TimerWidget`, a fixed
question card, a 3-line `TextField` with counter, a send button, a status container and a possible
host button all compete for one non-scrolling viewport. On a small device with a raised keyboard
and 200% text scale it cannot fit.

---

## 11. Platform / OS chrome

**FACT.** `main.dart` sets a global `SystemUiOverlayStyle` with light status-bar icons and a
`systemNavigationBarColor` hardcoded to `Color(0xFF111111)`.
**INFERENCE.** Home and Lobby now render on Paper (`#FAFAF7`) while the system navigation bar is
still forced to near-black and status-bar icons are still forced to light-on-dark. On the two
migrated screens the OS chrome contradicts the app. `AppTheme._build` does set
`systemOverlayStyle` per brightness in `appBarTheme`, but Home has no `AppBar`, so it never
applies there.

---

## 12. Verdict

| Dimension | Score /10 | Basis |
|---|---|---|
| Visual maturity | **4** | Excellent tokens; 2/11 screens adopt them; stock app icon |
| UX maturity | **4** | Loop works and is instrumented; whole meta layer unreachable; no onboarding/settings |
| Motion maturity | **5** | Real physics + tokens + confetti + timer; signature transition unused; 7 default routes |
| Design-system maturity | **6** | Unusually rigorous doc and token layer; adoption ~18% |
| Brand identity maturity | **3** | Strong, distinctive marks that appear literally nowhere in the app |

**INFERENCE.** Bufón's problem is not taste and not ambition. It is **distance between the
specification and the binary**. Version 1.1 should be measured in adoption percentage, not in new
design ideas.
