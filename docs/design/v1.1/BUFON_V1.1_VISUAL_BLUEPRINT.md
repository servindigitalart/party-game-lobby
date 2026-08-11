# BUFÓN 1.1 — VISUAL BLUEPRINT

**Status:** research and specification only. No production code was modified to produce this document.
**Baseline:** commit `ae65c54`, audited 2026-08-09/10.
**Companion documents:** `CURRENT_VISUAL_AUDIT.md` · `DESIGN_SYSTEM_AUDIT.md` ·
`COMPONENT_INVENTORY.md` · `ASSET_AUDIT.md` · `TYPOGRAPHY_AUDIT.md` · `ICONOGRAPHY_AUDIT.md` ·
`MOTION_AUDIT.md` · `UX_AUDIT.md` · `REPOSITORY_RESEARCH.md` · `COMPETITIVE_PATTERN_MATRIX.md` ·
`V1.1_GAP_ANALYSIS.md`

**Governing specification:** `bufon_flutter/BUFON_DESIGN_SYSTEM.md` v1.1. This blueprint does not
replace it. It reports where the binary has diverged from it, fills three gaps the specification does
not cover, and sequences the work.

---

## Part I — The nineteen questions

### 1. What is Bufón visually today?

**Two products in one binary.** A rigorous, brand-derived design system ("Butter Bliss": Butter `#F8EE67`
+ Ink `#191919` + Paper + Graphite + four semantic accents, each with tint/shade ramps) exists across
six complete token files, a shape system that deliberately rejects Material's z-axis in favour of
three narrative "focus layers", and a motion system with its own physics law. Two of eleven screens
use it.

The other nine screens, and the theme `MaterialApp` actually applies, are a legacy "casino nocturno"
palette: near-black `#111111`, navy cards `#1A1A2E`/`#16213E`, hot red `#E94560`, cyan `#00D9FF`,
gold `#FFD700`. Type is Plus Jakarta Sans fetched over HTTP at runtime with nothing bundled.
Illustration is OS emoji. Iconography is 37 stock Material glyphs, 8 of them thin outlines. The app
icon is the Flutter logo and the app is called `bufon_flutter`.

Bufón's two brand marks — a genuinely distinctive jester isotype with a keyhole motif, and a wordmark
in which the "O" *is* the jester's face — sit as 1 MB PNGs in `/public/`, the leftover Create React App
web root. They are not in the Flutter bundle and appear nowhere in the product.

**Bufón today is a well-designed system that has not been installed.**

### 2. What is working?

1. **The specification.** 710 lines that define an emotional target before defining rules, formalise a
   brand physics, and self-critique three of their own v1.0 decisions. This is better design authorship
   than most funded products have.
2. **Compression-and-spring touch physics.** `AnimatedPrimaryButton` and `GameCard` compress fast into
   a touch (`easeIn`) and release with overshoot (`easeOutBack`). Deliberately asymmetric. It is why
   Bufón's buttons feel unlike stock Flutter.
3. **`TimerWidget`.** Custom-painted arc, colour ramp, scale pulse, escalating copy through an
   `AnimatedSwitcher`, per-second haptic and sound, tabular figures. The only component that already
   satisfies the design system's no-single-sensory-channel rule.
4. **The two-stage reveal.** 750 ms → 1550 ms, light haptic → `celebration()`, answer withheld then
   author withheld. Genuinely well-choreographed suspense.
5. **`ConfettiWidget`.** A 50-particle simulation in one `CustomPainter`, zero dependencies.
6. **The voice.** "No presionamos, pero sí estamos juzgando." "Aquí se separa el chiste fino del crimen
   social." Specific, warm, funny, unmistakably Mexican, never cruel.
7. **The Lobby room-code card.** Butter tint, hairline, colour-tinted protagonist shadow, tabular
   display type at 32pt with wide tracking. The one piece of the app that is exactly what the design
   system describes.
8. **Spacing and typographic scale adoption.** ~95%. Invisible when right, and it is right.
9. **The token layer's documentation.** The files explain *why*, not just *what*. That is the asset most
   at risk of being lost and most worth protecting.

### 3. What is weak?

Ranked by damage to perceived quality:

1. **The app has no brand at the OS level.** Flutter's logo, Flutter's splash, the name `bufon_flutter`.
2. **The brand marks are not in the app.** Nine hundred lines of identity thinking, zero pixels shipped.
3. **The entire progression surface is unreachable.** `ProfileScreen` and `LeaderboardScreen` have zero
   inbound navigation; `ProfilePublicScreen` and `TitleSelectorDialog` are reachable only through them.
   2,285 lines of finished UI, plus XP, 12 avatars, titles, achievements, weekly/global leaderboards and
   seasons, are invisible to players. Every reward the backend grants is granted into the dark.
4. **Typography is fetched over the network.** First launch offline renders the brand in Roboto. Share
   cards can be generated — permanently — in the wrong typeface.
5. **Game phases are colour-identical.** `graphite`, `sky`, `lavender`, `mint`, `coral` have zero uses
   outside the theme file. A player cannot tell answering from voting without reading.
6. **Six sites show raw exception text to players**, including two inside the purchase flow.
7. **Accessibility is effectively absent.** One tooltip in the whole app. Zero `Semantics`. Text scaling
   and reduce-motion — two *system-level* accessibility requests — are ignored entirely.
8. **The three highest-time screens have no visual protagonist.** Answering shows the round progress
   four separate times before the player reaches the question.
9. **The reveal spoils itself.** The full scoreboard renders beside the spotlight from stage 0, so the
   `#1` row gives away the winner during the 800 ms of engineered suspense.
10. **The paywall is the least polished screen in the app** — 21 raw colour expressions, its own
    hardcoded palette, and raw exception strings at the point of payment.
11. **Emoji carry the entire illustration load.** A player's avatar is Apple's clown on iOS and Google's
    clown on Android.
12. **The declared signature gesture has never rendered.** `KeyholeRevealTransition` is written,
    reviewed, committed, and unused.

### 4. What is inconsistent?

- **Two live palettes**, 51 colour tokens, no compile-time signal about which is canonical.
- **Four colour authorities outside `AppColors`:** `AvatarRarity` (String hex), `TitleRarity` (int),
  `Season.themeColor` (unconstrained Firestore int rendered directly on Home), and a
  `_getRankColor()` returning `Colors.grey`/`Colors.brown`.
- **`gold` is retired by the specification and used in ~15 live places.**
- **Three visual languages for "progress"**: segmented bar, `LinearProgressIndicator`, `ClipRRect` XP bar.
- **Twelve `SnackBar` call sites with five different colour sources**, including `Colors.green`,
  `Colors.red.shade700`, `Colors.orange`.
- **Duplicated pairs**: two near-identical transition banners in two files (one whose animation is dead
  code — `AnimatedOpacity(opacity: 1)` with no state change); two unrelated classes both named
  `_ConfettiPainter`; two share-card generators built on two different rendering pipelines.
- **Four duplicated icon concepts**: `lock`/`lock_outline`, `check`/`check_circle`,
  `chevron_right`/`arrow_forward_ios`, `emoji_events`/`emoji_events_outlined` — and one glyph
  (`emoji_events`) carrying four different meanings.
- **Radii off the scale**: `circular(3)`, `(10)`, `(12)`, `(25)` alongside a defined 8/12/16/20/28/999.
- **Sixteen gradients** against a stated verifiable budget of two to three.
- **Three widgets bypass `HapticService`**, making the specification's haptic-economy rule
  structurally unimplementable and a future mute setting impossible.
- **The OS chrome contradicts the app**: `main.dart` forces a `#111111` navigation bar and light
  status-bar icons while Home and Lobby render on Paper.

### 5. What should Bufón 1.1 feel like?

**Like a screen-printed party game that knows exactly when to shut up.**

Five sensations, each traceable to something already in the specification:

1. **Threshold-yellow, then theatre-dark.** Butter and Ink at maximum contrast when you are *about to*
   play (Home, Lobby, the winner, share cards). Graphite with a single punctual accent when you *are*
   playing. The contrast between the two registers is the identity — not the yellow alone.
2. **One thing to look at.** Every screen has a protagonist at least 2.5× the next element. Answering is
   the question. Voting is the answers. The reveal is the reveal. Everything else is a thin edge.
3. **Physical, not decorative.** Everything compresses before it acts and releases with a little
   overshoot. Nothing fades in from nothing. Confirmed actions travel toward what receives them.
4. **Silence that earns the noise.** The reveal is preceded by stillness and followed by the only bell in
   the system. Celebration is scarce so that it lands.
5. **A face, not a trophy.** Wherever Bufón shows achievement it shows a *character* — the jester head,
   an avatar face, closed happy eyes — never a medal, a gamepad or a corporate chart arrow.

### 6. What should it NOT feel like?

- **Not Material.** No dynamic OS colour, no elevation-as-height, no default page fades, no ripple as
  the only feedback, no equal-weight card dashboard.
- **Not a SaaS product.** No minimalist neutrals, no restrained hairline aesthetic, no analytics icons.
- **Not a template.** If a screenshot could belong to any other app, the design failed.
- **Not a children's game.** No rainbow gradients, no bouncing everything, no exclamation marks
  everywhere, no cartoon outlines. The jester is warm and a little wicked, not cute.
- **Not a casino.** The current legacy palette is exactly this, and it is what 1.1 removes.
- **Not a video game.** No gamepads, no arcade sound, no HUD. Bufón is a phone in the middle of a table.
- **Not loud everywhere.** A game that celebrates constantly celebrates nothing.

### 7. What visual principles define it?

The specification's eight principles hold unchanged. This blueprint adds **three operational
principles** derived from what the audit found — rules about how the system is *maintained*, which is
where Bufón actually failed:

**A. A token that nothing consumes is not a design decision — it is a draft.**
Half the motion system, five of eight colours, the ceremonial gradient, the pill shape and the
signature transition have never executed. 1.1 is measured in adoption percentage, not in new tokens.

**B. One authority per concept, enforced at the type level where possible.**
Four colour authorities and two rarity ladders exist because nothing prevented them. Rarity becomes one
enum returning `AppColors`; season accents become a named enum, not an arbitrary int.

**C. Reachability precedes refinement.**
An ugly screen a player can reach beats a beautiful one they cannot. This deliberately inverts the
specification's own Fase 3H/3I ordering, which was written before the reachability gap was known.

### 8. What components should be redesigned?

| Priority | Component | Change |
|---|---|---|
| **P0** | `AnimatedPrimaryButton` | Flat fill (delete the default gradient), pill shape, `Semantics`, haptics via `HapticService`, enforced 56 px height, derived spinner/disabled colours, reduce-motion path |
| **P0** | `GameCard` | Flat fill, `Semantics(selected:)`, explicit `onSelectedColor` (Ink on Mint, never white), phase-default accent, multi-line with ellipsis |
| **P0** | **New:** `BufonLoader` | Breathing isotype; replaces 12 bare spinners |
| **P0** | **New:** `BufonPlaceholder` | `empty` / `error` / `offline` variants; brand illustration, voice copy, ≤1 action; replaces 5 raw error screens and 2 icon-only empties |
| **P0** | **New:** `BufonStatusPanel` | One answer/vote progress container; replaces 4 divergent inline versions |
| **P0** | **New:** `BufonPlayerRow` | Avatar + name + host/online chip; replaces 3 divergent player rows |
| **P0** | **New:** `BufonFeedback` | One toast/snackbar entry point; replaces 12 call sites with 5 colour sources |
| **P1** | `TimerWidget` | Sky → Coral ramp, escalating final haptic, filled glyph, live-region semantics, larger arc, reduce-motion |
| **P1** | `ConfettiWidget` | Brand palette, `count`/`colors` params, `AnimatedBuilder` instead of `setState`, fade tail, reduce-motion |
| **P1** | `KeyholeRevealTransition` | **Wire it in.** No code changes needed. |
| **P1** | `ShareVictoryCard` | Butter ground, Ink type, real isotype, avatar as sole protagonist, score as footnote, fix the `roundWins`/`totalScore` mislabel |
| **P1** | **New:** `PhaseBanner` | Collapses two duplicated banners; fixes the dead animation; one real `Arrive` entrance |
| **P1** | **New:** `Rarity` enum | One ladder: common→`inkSoft`, rare→`sky`, epic→`lavender`, legendary→`butter` |
| **P1** | **New:** `PhaseScope` | Per-phase theme + accent via `InheritedWidget`; removes the per-call-site `.copyWith(color:)` tax |
| **P2** | `RoundIndicator` | Correct glyph, tabular figures, pill shape, out of the app-bar title slot |
| **P2** | `GameProgressBar` | **Delete** the caption and percentage; distinguish the current segment; animate fill |
| **P2** | `SeasonCountdownBanner` | Named accent, flat, no glow, below the primary CTA, Ink text |
| **P2** | `ShareProfileCard` | Rebuild on the shared `ShareCardScaffold` widget pipeline |
| **P3** | `SeasonBadgesSection` | Fix the mis-picked icon, on-scale radius, shared `Rarity` |

### 9. What screens should be redesigned?

Full treatment in Part IV. Summary:

| Priority | Screen | Headline change |
|---|---|---|
| **P0** | Home | Navigation shell (isotype + profile + leaderboard); brand marks; grouped create/join paths |
| **P0** | Answering | Establish a protagonist: delete 3 of 4 progress read-outs; Graphite + Sky; fix the overflow risk |
| **P1** | Reveal | Gate the scoreboard behind stage 2; keyhole transition; Graphite + Butter |
| **P1** | Voting | Graphite + Lavender; single confirmation; label the player's own card |
| **P1** | Final winner | Ceremonial layer; real avatar; share CTA for everyone; night recap |
| **P1** | Paywall | Migrate to tokens entirely; no raw exceptions; Paper + Butter accent only |
| **P2** | Lobby | Avatars in the player list; copy-code icon `Swap`; leave affordance |
| **P2** | Leaderboard | Paper + Sky/Lavender; brand empty state |
| **P2** | Profile | Paper; brand illustration; entry point from the winner screen |
| **P3** | Public profile, Season details, Title selector | Migrate after the above |

### 10. What motion should be introduced?

Full system in Part III. Introduced in 1.1:

1. **`Arrive`** as a real utility (~40 lines on existing tokens), not just token values.
2. **The keyhole reveal**, wired into the round result — the brand's declared ownable gesture.
3. **Shared-element `Hero`** for the room code (Lobby → game header) and the winning answer
   (voting list → reveal spotlight).
4. **Tweened numeric counters** everywhere a number changes — currently every counter snaps.
5. **Reduce-motion paths** for all six animation sites.
6. **Fade-only backward transitions**, distinct from forward `Arrive`.
7. **Correct celebration tiers**: 50 particles / 3 s round vs. 80–100 / 4–5 s night.
8. **`Arrive` on the seven remaining `MaterialPageRoute` navigations**, including the two most
   ceremonial ones (into the next round, into the Bufón of the Night).

Explicitly *not* introduced: `flutter_animate`, Rive, Lottie, Flame. Reasoning in Part V.

### 11. What assets should be better utilised?

| Asset | Today | 1.1 |
|---|---|---|
| `BUFON-ISOTIPE.png` | Unused, in `/public/` | App icon, launch screen, Home app bar, breathing loader, share-card corner, avatar fallback |
| `BUFON-LOGO.png` | Unused, in `/public/` | Home headline (replacing typed text), share-card lockup |
| The keyhole motif | Decorative detail in an unused file | The reveal transition, the locked-content glyph, the pre-reveal visual language |
| `AppElevation.ceremonialGradient` | Zero call sites | The winner screen it was written for |
| `AppTypography.tabular()` | 2 of ~9 numeric read-outs | Every number that changes or aligns |
| `AppTypography.displayButter` | Unused | The reveal and winner screens |
| `AppShapes.pill` / `radiusFull` | Zero uses | Primary buttons, chips, status tags — the shape the logotype implies |
| `MotionSprings`, `MotionPhysics` | Unused | Breathing protagonists, gesture-driven cards |
| `AppColors.generateTint/Shade` | Unused | Deriving named season accents |
| Question packs (`DI LA NETA`, `¿QUÉ PEDO?`, `ALGUIEN DE AQUÍ`) | Parsed nowhere | Illustrated, selectable pack cards — Home's missing protagonist |
| `ConnectionService` | Heartbeat only, no UI | A connectivity banner on the loop |
| 12 avatars | Emoji, invisible in lobby/voting/scoreboard | Brand faces, shown everywhere a player appears |

### 12. What typography strategy should be used?

1. **Keep the scale unchanged** (12/14/16/20/24/28/32/48, negative tracking on the top three only).
   It is correct and ~95% adopted. Touching it is pure diff noise.
2. **Keep the two-function font seam** (`_display`/`_body`). It makes the face a one-edit decision.
3. **Bundle the fonts now — this is P0 and independent of which face wins.** Bundling Plus Jakarta Sans
   today removes a guaranteed first-launch brand failure and costs one pubspec edit either way. Set
   `allowRuntimeFetching = false` so a missing asset fails loudly in development instead of silently at
   a player's table. Register the licences.
4. **Decide the Display face on-device, not from a screenshot.** Place the wordmark PNG directly above
   `AppTypography.display` rendering "BUFÓN" and compare. The brief, read off the actual logotype file:
   heavy, warm, rounded terminals, very high x-height, tight tracking, soft joins, with some
   irregularity — closer to Cooper/Recoleta than to Poppins. Note a practical freedom: the "O" is the
   face, so no candidate has to match the hardest character. **"Keep Plus Jakarta Sans and invest the
   effort in using the wordmark asset instead" is a valid, possibly correct outcome of this test** — the
   lockup is distinctive enough that the UI face may only need to not fight it.
5. **Fix the colour coupling.** Every `AppTypography` getter hardcodes white. Migrated screens must
   `.copyWith(color:)` at every call site — 19 times in Lobby alone — and the failure mode of forgetting
   one is *invisible white text on Paper*. Resolve via `PhaseScope` + `context.text.*` extensions so new
   code is safe and legacy code keeps working.
6. **Apply `tabular()` to every number.** Cheap, and it is what stops a scoreboard column looking ragged
   and a live counter looking like it is shimmering.
7. **Handle text scaling.** Fix `game_screen.dart` with the scroll pattern already proven in
   `home_screen.dart`, and clamp the global scaler to ~1.4 so the loop stays playable while still
   honouring the user's direction of preference.
8. **Extend the voice to 100% of strings.** Errors and empty states are where warmth matters most and
   where Bufón is currently most generic. One file, one review — and it is also step one of any future
   i18n.

### 13. What iconography strategy should be used?

A **three-tier hybrid**, which is what the closest comparable app (Lichess Mobile, which ships four
custom icon fonts *alongside* two icon libraries) independently arrived at:

**Tier 1 — eight custom glyphs, shipped as one icon font.** Keyhole/secret · mask/reveal · crown ·
stamp/vote · room/table · timer · share · small jester head. Eight, not the specification's 15–20:
scope discipline matters more than coverage, and these eight cover every high-frequency,
brand-carrying concept. An icon font is preferred over SVG because every existing `Icon(...)`,
`IconTheme`, size and colour call site keeps working unchanged, and it adds no package.

**Tier 2 — Material, filled only, for generic UI verbs.** `close`, `copy`, `refresh`, `edit`, `check`,
`chevron_right`, `calendar_today`, `person`, `send`, `add`, `home`, `public`. Custom-drawing these buys
nothing. **Replace all 8 outline variants with filled siblings and consolidate the 4 duplicated pairs
— roughly an hour, and the cheapest measurable consistency win in the audit.**

**Tier 3 — brand avatar faces replacing emoji.** Twelve flat vector faces on the isotype grid: same
round nose, same closed-arc eyes, same thick smile weight, differentiated by hat, accessory and colour
rather than by expression. This is the largest identity return of any single asset investment, because
avatars appear at the two highest-emotion moments the product has and on every share card that leaves
the app. Emoji stay only as decorative punctuation inside copy strings, never as an entity.

**Fix the three semantic mis-picks:** `Icons.photo_size_select_actual` (a photo-crop icon) representing
a top-10 season finish; `Icons.sports_esports` (a gamepad) as the round counter; `Icons.military_tech`
(a military medal) for player titles — the exact opposite of "cómplice, no espectáculo".

**Add labels.** Every icon-only control gets a `tooltip` or `Semantics(label:)`. Two of the four
icon-only controls in the app are the only exit from their screen.

**Deferred with a trigger:** `material_symbols_icons` (variable weight/fill/grade axes; its
`weight: 700 · fill: 100 · rounded` combination genuinely matches the isotype) — adopt **after** the
custom eight exist, so it becomes a weight-matched fallback rather than a generic-for-generic swap.

**Rejected:** Lucide, Phosphor, Hugeicons and every other mass-adopted set. The specification is
explicit, and it is right: a set adopted by ten thousand apps differentiates nothing.

### 14. Which external repositories influenced each recommendation?

| Recommendation | Influenced by | What was observed |
|---|---|---|
| Bundle fonts as assets | **Wonderous**, **Obtainium**, **Lichess Mobile** | All three bundle font families; none runtime-fetch typography for a design-led app |
| Treat the launch screen as a design surface | **Wonderous** | Ships `flutter_native_splash` |
| Texture as a first-class asset category | **Wonderous** | Maintains `assets/images/_common/texture/` |
| One-giant-element composition | **Wonderous** | Its entire visual approach; proof the law yields distinctiveness, not awkwardness |
| Custom icon font + library hybrid | **Lichess Mobile** | Ships 4 custom icon fonts alongside `material_symbols_icons` + `cupertino_icons` |
| `wakelock_plus` during active phases | **Lichess Mobile** | Keeps the screen awake during play; Bufón has a 90 s answering phase on a table |
| Audio architecture for 1.2 | **Lichess Mobile** | 6 bundled sound-theme directories + the minimal `sound_effect` package |
| Variable-axis Material Symbols (deferred) | **Lichess Mobile** | `material_symbols_icons ^4.2960.0` |
| Shared-element transitions | **LocalSend** | `local_hero`; Bufón can use the SDK's own `Hero` |
| **Rejecting** dynamic OS colour | **LocalSend**, **Lichess**, **Obtainium** | All three adopt it; it would erase Butter + Ink |
| Per-component nested styling → `PhaseScope` | **Forui** | Nested style objects instead of one global `ThemeData` |
| Ecosystem tool consensus (animate + svg + icon lib) | **flutter-shadcn-ui** | Its dependency block names all three of Bufón's open questions |
| **Rejecting** the `animations` package | **Obtainium** | Faithful Material motion is exactly what Cap. 34 forbids |
| `hsluv` noted but unneeded | **Obtainium** | Perceptual colour manipulation; irrelevant for 8 hand-tuned hex values |
| Stock M3 as a negative control | **Obtainium** | A well-liked utility that looks like default Material — the ceiling Bufón must clear |
| `Arrive` helper instead of a package | **flutter_animate** (rejected) | `AnimateList` + chainable effects; the idea, not the dependency |
| **Rejecting** Rive for 1.1 | **rive 0.14.11** | State machines are the one thing Bufón can't hand-code — but it needs vector art and an authoring owner first |
| **Rejecting** Lottie | **lottie 3.5.1** | Weaker interactivity than Rive; baked colours; stock files are a brand liability |
| **Rejecting** a game engine | **Flame 1.38.0** | Bufón is a synchronised form, not a simulation |
| Tweened numeric counters | **Flame samples** / game-feel craft | Games never snap a score; Cap. 18 already requires it and Bufón does it nowhere |
| Reduce-motion pattern | **flutter/samples `animations`** | The canonical reference for correct implementation |
| **Rejecting** platform-adaptive widgets | **flutter/samples `platform_design`** | A Bufón button should feel like Bufón on both platforms |
| **Rejecting** template kits | **GetWidget / Flutter-UI-Kit** | Solve a breadth problem Bufón doesn't have; produce the template look Cap. 34 forbids |
| i18n flagged as future work | **AppFlowy**, **LocalSend**, **Obtainium** | All three run formal localisation pipelines; Bufón hardcodes Spanish |
| Guard against dependency accretion | **Awesome Flutter** | An index optimises for discovery, which is how apps accrete packages |

### 15. Which dependencies should actually be adopted?

**Two.** Both clear the same bar: they do something Bufón cannot reasonably do in ~100 lines of its own
code.

| Package | Priority | Justification |
|---|---|---|
| **`wakelock_plus`** | P1 | A platform capability, not implementable in Dart. The phone must not sleep during a 90-second answering phase while it sits on a table. Lichess ships it for the identical reason. |
| **`flutter_svg`** | P1, **conditional** | Only if the isotype ships as SVG. Because the mark is flat single-ink geometry, reproducing it as a `CustomPainter` is genuinely competitive — it gives runtime colour and free path animation with zero package weight, at the cost of one non-trivial file. **Decide the asset format first, then the package.** |

**INFERENCE.** Bufón's UI dependency footprint today is two packages, one of which
(`cupertino_icons`) is never imported. Ending 1.1 with three is a deliberate position, and it means
essentially every improvement in this blueprint is achievable with code the project already owns.

### 16. Which should remain reference-only?

| Package / project | Status | Reason |
|---|---|---|
| `flutter_animate` | **Defer to 1.2** | Bufón's motion problem is adoption, not expressiveness: half of `motion_tokens.dart` has never executed and the keyhole transition is unused. Adding a second motion vocabulary to a half-unused first one repeats the two-palette mistake. Also the least recently published package in this research pass (~20 months). Revisit once all six named behaviours are in use. |
| `rive` | **Defer to 1.2+** | The one uniquely-enabling tool here — a state-machine jester that reacts to game state. Blocked on: vector isotype, drawn avatars, and someone owning Rive authoring. Buying a camera before there is anything to photograph. |
| `lottie` | **Reject** | Timeline-only, colours baked at export, and its cheap-stock-asset advantage is precisely a brand liability. |
| `flame` | **Reject** | Bufón has no simulation, no world, no sprites, no collision. Two rendering paradigms to replace a working 166-line painter. |
| `forui`, `shadcn_ui`, `getwidget` | **Reject** | Minimalist/neutral or generic-template aesthetics against a screen-printed, maximum-contrast brand; and Bufón needs ~16 components, not 40–1000. |
| `animations` | **Reject** | Faithful Material motion is what Cap. 34 forbids. |
| `dynamic_color`, `dynamic_system_colors`, `yaru` | **Reject** | Would erase `FIRMA VISUAL` item 1. |
| `lucide_icons_flutter` | **Reject** | Cap. 34: a mass-adopted set differentiates nothing. |
| `material_symbols_icons` | **Defer, P2** | Adopt after the custom 8 exist, as a weight-matched fallback. |
| `flutter_spinkit` | **Reject** | A prettier generic spinner is still generic; Cap. 24 wants a branded wait. |
| `auto_size_text`, `gap`, `flextras`, `hsluv` | **Reject** | Convenience, not capability. |
| `sound_effect` | **Defer to 1.2** | With bundled audio and a settings screen to mute it. |
| AppFlowy, Lichess, Obtainium (code) | **Reference only** | AGPL-3.0 / GPL-3.0. Patterns and package choices are observable facts; code is not reusable. |

### 17. What are the highest-impact changes?

See the ranked Top 10 in Part VI. The four that dominate:

1. **Give Bufón a brand at the OS level** (icon, splash, name, bundled fonts, isotype in-app). It is the
   first, most frequent and most permanent impression, and today it belongs to Flutter.
2. **Make the progression surface reachable.** One app bar and one CTA unlock 2,285 lines of finished UI
   and the entire retention economy.
3. **Recolour the live game loop to distinct phase registers.** Realises the specification's central
   emotional device and is the single largest visual change available.
4. **Establish one protagonist per screen** — mostly by *deleting* duplicate read-outs, which makes it
   cheap and immediately visible.

### 18. What should be implemented first?

**In this order, and the order matters:**

**Step 0 — safety net (before any recolour).** Add golden tests for the six core components. Fase 3B's
own acceptance criterion required them and none exist. Without them, a 3E–3G recolour is a blind
change across nine screens.

**Step 1 — the OS-level brand.** App icon, launch screen, app name, bundled fonts, isotype into
`assets/brand/`. A day at most, and it changes the first thing every player sees.

**Step 2 — reachability.** Home app bar with the isotype plus profile and leaderboard actions; a
"Ver mi progreso" CTA on the winner screen. This is the highest total product impact in 1.1.

**Step 3 — the Quadrant-1 batch** (see `V1.1_GAP_ANALYSIS.md` §4). Fourteen items, none over ~3 hours:
gate the scoreboard behind reveal stage 2, recolour confetti, fix the celebration tiers, real winner
avatar, share CTA for everyone, delete three duplicate progress read-outs, winner haptic, wire the
keyhole transition, swap the outline icons, `wakelock_plus`, tooltips. This batch alone moves perceived
quality more than any single large piece of work.

**Step 4 — foundation.** `PhaseScope`, the five new primitives, `AnimatedPrimaryButton` and `GameCard`
fixes, the `Rarity` and season-accent consolidations, copy centralisation into `GameCopy`.

**Step 5 — the accessibility package.** `Semantics`, tooltips, reduce-motion, text-scale handling,
`inkMuted`, the `game_screen` scroll fix. Roughly a day, and it moves the app from unusable with
assistive technology to usable.

**Step 6 — Fase 3E/3F/3G.** Recolour and re-hierarchy the three live-game screens and the winner, on
top of the goldens from Step 0.

**Step 7 — paywall migration and the share-card redesign.**

**Rationale for putting the small batch (Step 3) before the big recolour (Step 6):** it front-loads
visible improvement, it is nearly risk-free, and it gives the recolour work a cleaner target.

### 19. What should be explicitly deferred?

| Deferred | To | Trigger to revisit |
|---|---|---|
| Audio identity (7 composed sounds, playback package, mixer, mute) | **1.2** | A settings screen exists. Shipping placeholder sounds is worse than none — Cap. 20's scarcity logic means a mediocre bell permanently devalues the brand sound. |
| Rive character animation | **1.2+** | Vector isotype + drawn avatars exist, and someone owns Rive authoring |
| `flutter_animate` | **1.2** | All six Cap. 16 behaviours are in use and ergonomics is measurably the bottleneck |
| Pack selection UI | **1.2** | Content expands past 20 questions — the UI would otherwise advertise the shallowness |
| Onboarding / how-to-play | **1.2** | Needed before an acquisition push, not before beta |
| Settings beyond a mute toggle | **1.2** | — |
| Fase 3H/3I (profile + leaderboard recolour) | **1.2** | After Step 2 makes them reachable. Reachability precedes refinement. |
| The engineered 2–3 s pre-reveal silence | **1.2** | It changes `_scheduleAutoResults` timing, which is synchronisation-adjacent. `AGENTS.md`: room consistency outranks polish. Treat as gameplay work with telemetry. |
| QR-code room joining | **1.2** | Strong fit (players are co-located) but outranked |
| Night recap / best-answer surface | **1.2** | High value; needs a design pass, not just a recolour |
| Tablet, landscape, foldable layouts | — | Portrait-locked by deliberate design |
| i18n pipeline | — | Centralising copy in `GameCopy` in 1.1 is step one |
| Account recovery for anonymous progression | — | Real risk, but backend scope |
| Deleting the CRA web shell | — | Touches build config; out of scope for a visual release |
| Custom icon font + brand avatars **if design capacity is absent** | 1.2 | Do the 1-hour filled-icon swap instead. **Do not** substitute a third-party icon library as a shortcut. |

---

## Part II — Visual identity

### Brand language

**Visual personality.** The court jester: the one who can tell the king the truth because he wraps it in
wit. Complicit, warm, confident, a little wicked. Never cruel, never childish, never corporate-cheerful.

**Shapes.** Three, closed vocabulary, all traceable to the isotype:
- **Perfect circle** — avatars, badges, the timer arc, the keyhole. Echoes the head.
- **Pill (full radius)** — primary buttons, chips, status tags. Echoes the letterforms. *Currently used
  nowhere; adopting it is one of the clearest identity wins available.*
- **Super-rounded rectangle (20–28)** — cards, modals, the question and answer surfaces.
- **Never** square corners on anything interactive.

**Contrast.** Binary, not graded. Either clearly light (Paper/Butter) or clearly dark (Graphite).
Nothing in the mid-luminance band — which is exactly where the legacy `#1A1A2E` sits, and why it must go.

**Texture.** Almost none. The isotype is one flat ink. If any texture is introduced (P3), it is a
barely-perceptible paper grain on Paper surfaces only, never on Graphite, never behind text.

**Composition.** One protagonist occupying 40–60% of the screen height; everything else compressed to
thin bands at the edges. Never equal-weight cards distributed evenly — that is a dashboard, and a
dashboard is what Cap. 34 forbids.

**Whitespace.** Generous around the protagonist, tight everywhere else. Whitespace is how the protagonist
is declared, not a uniform gutter.

**Visual density.** Low. Bufón is read from across a table by four to eight people looking over one
person's shoulder. Every element must survive that viewing distance. This is why deleting the three
duplicate progress read-outs is a *design* decision, not tidying.

### Colour strategy

**Audit first.** Two live palettes, 51 tokens, four authorities outside `AppColors`, a retired `gold`
used in ~15 places, and five of the eight brand colours with zero uses in any screen.

**The palette needs no change.** The eight Butter Bliss colours with tint/shade ramps are correct,
documented, contrast-verified for the three primary pairs, and derived from the mark. 1.1 changes
**adoption**, not values, plus two additions and two consolidations:

| Role | Token | Where |
|---|---|---|
| Primary / brand | `butter` | Buttons and accents on light screens; ceremonial ground |
| Text on light | `ink` | All body and display type on Paper/Butter |
| **Secondary text on light** | **`inkMuted` ≈ `#5C574C` — NEW** | Replaces `inkSoft` for body text. `inkSoft` on Paper is ≈3.0 : 1, which **fails AA at 16pt**; it stays for hairlines, disabled fills and icon washes. |
| Light surface | `paper`, `paperTint`, `paperLine` | Home, Lobby, Profile, Leaderboard, Paywall |
| Dark surface | `graphite`, `graphitePlus1` | Answering, Voting, Reveal, Winner |
| Text on dark | `paper` | Never inverted pure black |
| Success | `mint` | Answer sent, vote registered, round winner |
| Error / tension | `coral` | Errors, limits, timer danger |
| Social presence | `sky` | Online state, answers arriving, the answering phase |
| Mystery | `lavender` | Voting only — never monetisation |
| Winner | `butter` + `mint` on `graphite`, ceremonial gradient | Round and night winner |
| **Rarity** | **one ladder — NEW** | common `inkSoft` · rare `sky` · epic `lavender` · legendary `butter`. Replaces two divergent non-brand ladders and retires the last live uses of `gold`. |
| **Season accent** | **named enum — NEW** | `lavender` / `sky` / `mint` / `coral`, resolved client-side. Replaces an unconstrained Firestore int that can currently inject any hue into Home. `generateTint`/`generateShade` finally get a job. |
| Player colours | **deliberately none** | Players are identified by avatar face and name. Assigning per-player colours would create a fifth authority and collide with the semantic accents. |

**Phase registers**, per Cap. 33 — the change that makes the palette *readable*:

| Phase | Ground | Accent | Feeling |
|---|---|---|---|
| Home | Paper | Butter | "Something is about to happen" |
| Lobby | Paper | Butter | "We're about to start" |
| Answering | Graphite | **Sky** | "Just me and my wit against the clock" |
| Voting | Graphite | **Lavender** | "I'm judging in secret" |
| Reveal | Graphite → Butter | Butter | "The curtain opens" |
| Round winner | Graphite | **Mint** + confetti | "Momentary victory" |
| Night winner | Ceremonial Butter/Graphite | Butter | "This is going to be a screenshot" |
| Profile / Leaderboard | Paper | Sky / Lavender | "Where do I stand" |
| Paywall | Paper | Butter **only** | "Here's the option, no pressure" |

**Hard rules.** One protagonist accent per screen. Never `coral` and `mint` in the same component.
Text on Butter is always Ink, never white. Gradients only at the ceremonial layer. And — the
specification is explicit and correct here — **monetisation gets no emotional colour**: asking for
money with "mystery" would be manipulative.

### Typography strategy

Covered in Question 12. In one line: **keep the scale, keep the seam, bundle the fonts now, decide the
Display face on-device with "keep it" as a valid answer, fix the colour coupling, make every number
tabular, handle text scale, extend the voice to every string.**

### Iconography strategy

Covered in Question 13. In one line: **eight custom brand glyphs as one icon font, filled Material for
generic verbs, twelve drawn avatar faces replacing emoji, three semantic mis-picks fixed, labels
everywhere, no mass-adopted library.**

### Logo strategy

**FACT — where logos appear today: nowhere.** Both marks are unbundled PNGs in the CRA web root.

**Where they should appear:**

| Surface | Mark | Treatment |
|---|---|---|
| App icon | Isotype | Ink on Butter, full-bleed, no white padding |
| Launch screen | Isotype | Centred on flat Butter, so splash → Home is continuous rather than a white flash into cream |
| Home app bar | Isotype, small | The identity anchor of the navigation shell |
| Home headline | Wordmark | Replaces typed "BUFÓN" — the lockup *is* the type |
| Loading states | Isotype | Breathing (scale 1.0 ↔ 1.008, 4 s, `easeInOut`), replacing 12 bare spinners |
| Reveal transition | Keyhole motif | The expanding circular mask — the motif becomes a physics |
| Share cards | Isotype, small, fixed corner | Never centred, never competing with the content |
| Winner screen | Wordmark, ceremonial | The one place it may be large |
| Avatar fallback | Isotype | Instead of `'🤡'` |
| Locked content | Keyhole glyph | Instead of `Icons.lock` |

**Should the mark become part of navigation identity?** Yes — the Home app bar. But **not** on the
game-loop screens. Cap. 3 wants one protagonist per screen, and during play the protagonist is the
question, the answers or the reveal. A persistent logo would compete. The brand lives in geometry and
motion during play, and in the mark at the thresholds. That asymmetry is deliberate and it is
`FIRMA VISUAL` item 5's logic applied to placement.

**Should pack logos become visual anchors?** Yes. Three named packs already exist as content and are
invisible as product. Illustrated pack cards would give Home the protagonist it lacks, create a
legitimate home for new illustration, give the host a pre-game decision, and offer a monetisation
surface that reads better than a blocked room. **Conditional on content expansion** — pack UI would
otherwise advertise that 20 questions is four games before repeats.

**Should the main mark have animated states?** Yes, three, and all three are achievable without Rive:
*breathing* (idle/loading), *opening* (the keyhole reveal), *stamping* (a compress-and-release
overshoot at the winner moment, reusing `MotionScale.celebrationOvershoot`). Rive becomes worth
considering only if a fourth, reactive state — a jester that responds to game events — is wanted.

**Unresolved and needing an owner's decision:** the wordmark reads **BUFON**; all copy reads **BUFÓN**.
Either the accent is deliberately dropped in the lockup (defensible — it would collide with the hat) or
the mark predates the naming. This determines whether the wordmark asset can ever replace typed text,
so it must be recorded in Cap. 2 before the Home headline is changed.

---

## Part III — Motion system

**The law (unchanged, already implemented in two components).** Compression and spring. Everything
compresses before it acts and releases with a small excess when it does. Compression is fast
(`easeIn`); release is slower with overshoot (`easeOutBack`). Never symmetric, never linear.

### Microinteraction — 100–150 ms

| Trait | Specification |
|---|---|
| Style | Scale compression; never opacity or colour alone |
| Duration | `pressButton` 100 ms · `pressCard` 150 ms |
| Easing | `compress` in, `release` out (asymmetric) |
| Transform | Scale only: 0.95 buttons, 0.97 cards; confirmed actions overshoot to 1.03–1.05 |
| Technique | Existing `AnimationController` + `Transform.scale`. **Not** `flutter_animate`. |
| Haptic | Yes — `lightImpact` on tap, `mediumImpact` on confirm, **via `HapticService`** |
| Sound | 1.2 (wood "clac" on tap, stamp on confirm) |
| Reduce motion | Skip the scale; keep colour and haptic |

**Covers:** button press, card press, answer selection, vote, toggle, chip.
**Gap:** seven controls have only Material's default ripple. Replace them with `AnimatedPrimaryButton`
(needs a `secondary` variant) so the host's most-repeated action — advancing the round, five times a
game — feels like the same product as submitting an answer.

### Navigation — 200–300 ms

| Trait | Specification |
|---|---|
| Style | **Forward** = `Arrive` (fade + 5% upward slide + scale from 0.88). **Backward** = fade only, no slide, no scale. |
| Duration | 250 ms (`MotionDurations.arrive`) |
| Easing | `release` forward; plain `easeOut` backward |
| Technique | Existing `FadeSlidePageRoute` + a new fade-only reverse variant |
| Shared element | `Hero` for the room code (Lobby → game header) and the winning answer (voting list → reveal spotlight). SDK `Hero`; no `local_hero`. |
| Haptic | No — navigation is not a touch response |
| Sound | No |
| Reduce motion | Fade only |

**Gap:** 7 of 11 navigations still use `MaterialPageRoute`, including the two most ceremonial (into the
next round, into the Bufón of the Night). No backward variant exists.

### Game feedback — 200–800 ms

| Trait | Specification |
|---|---|
| Style | Multi-channel, always: colour **and** motion **and** haptic. Never colour alone. |
| Duration | `settle` 250 ms for counters and containers; `revealStage` 800 ms per reveal stage |
| Easing | `settle` for value changes; `easeOut` family for the keyhole opening (an unveiling, not a spring) |
| Transform | Counters tween their **value**, not their position. Consumed elements travel toward their destination rather than vanishing in place. |
| Technique | `AnimatedSwitcher` for text swaps · `TweenAnimationBuilder<int>` for numbers · `KeyholeRevealTransition` for the reveal |
| Haptic | Yes — escalating, coalesced under 400 ms |
| Sound | 1.2 (card flip stage 1, bell stage 2) |
| Reduce motion | Cross-fade instead of masking; no pulse |

**Gaps:** every counter snaps. The timer fires five identical `lightImpact`s in five seconds instead of
escalating. The keyhole transition has never rendered. **And the reveal spoils itself** — the scoreboard
is co-visible from stage 0, so the `#1` row gives the winner away during the suspense the screen exists
to create. That last one is a ~10-line fix and it is the single best motion change in 1.1.

### Reward — 600–900 ms

| Trait | Specification |
|---|---|
| Style | Arrive compressed, release with overshoot, then settle. Numbers count up rather than appearing. |
| Duration | 600–900 ms per element, staged |
| Easing | `release` |
| Transform | Scale 0.88 → 1.05 → 1.0, plus a value tween |
| Technique | Custom `AnimationController` staging. **No** Lottie, **no** Rive in 1.1. |
| Haptic | Yes — `mediumImpact` per revealed element |
| Sound | 1.2 |
| Reduce motion | Static, with the final value shown |
| **Blocked on** | These moments live on unreachable screens. **Reachability first.** |

**Covers:** XP gain, level-up, achievement unlock, avatar unlock, title unlock, Night Pass activation.

### Celebration — 1200–2000 ms

| Trait | Specification |
|---|---|
| Style | The biggest spring in the system, deliberately scarce |
| Duration | Round winner 3 s · Night winner 4–5 s with staged elements and a gradual fade-out |
| Easing | `release` at `celebrationOvershoot` 1.15 — **not** `elasticOut`, which overshoots well past the token and is currently unregulated |
| Transform | Ceremonial gradient ground (`AppElevation.ceremonialGradient`, the only sanctioned gradient), confetti, avatar scale-in, staged stats |
| Particles | 50 for a round · 80–100 for the night |
| Technique | Existing `ConfettiWidget` + `AppElevation.ceremonialGradient` |
| Haptic | `celebration()` — repeated per revealed stat on the night winner. **Currently the winner screen fires no haptic at all.** |
| Sound | 1.2 — the bell, exactly twice per round, never elsewhere |
| Reduce motion | No particles; a static ceremonial ground and a scale-free entrance |

**Gap and why it matters.** Round and night celebrations are currently *visually identical in density*
(50 particles both, 1.8 s vs. 3 s). The three-tier ladder exists to keep "big" feeling big, and it is
flattened. Fixing it is two numbers and one parameter.

### Motion rules

1. Every animation maps to one of six names — Press, Pulse, Arrive, Reveal, Swap, Settle — or justifies
   a seventh in the PR.
2. No raw `Duration(milliseconds: …)`. Five sites still have them; two (350 ms, 420 ms) sit outside
   every documented tier.
3. Nothing fades in from nothing. Entrances start compressed at 0.88.
4. Protagonist-layer elements breathe (1.0 ↔ 1.008 over 4 s). Ambient-layer elements never do — the
   stillness is what makes the breathing legible.
5. Waiting states are "coiled, not dead": very low amplitude, very slow.
6. Reduce motion is honoured everywhere. Non-negotiable.
7. Every relevant tap fires at least two simultaneous signals.
8. No animation is added purely because a surface looks static. The specification's third principle is
   that silence is part of the rhythm.

---

## Part IV — Screen by screen

Format: **CURRENT** → **PROBLEM** → **OPPORTUNITY** → **REFERENCE** → **PROPOSED** → **PRIORITY** →
**DEPENDENCIES**. No implementation code, by instruction.

### 1. Home

**CURRENT.** Butter Bliss light register via a local `Theme` override. Season banner, "BUFÓN" typed at
`display` 48 in Ink, tagline in `inkSoft`, name field, Butter "Crear Sala" (`AnimatedPrimaryButton`),
divider, code field, outlined "Unirse a Sala". `LayoutBuilder` + scroll (the only screen with a
small-screen strategy). No app bar. No navigation to anything but the lobby.

**PROBLEM.** (a) No route to Profile or Leaderboard — 2,285 lines unreachable. (b) The headline is typed
text, not the wordmark, and is rendered in a runtime-fetched font. (c) The season banner sits *above*
the brand with a gradient, a coloured glow and a 2 px border, out-competing it on the app's first
screen, in a colour supplied by an unconstrained Firestore int. (d) Two paths (create / join) read as
one form: typing a code then pressing "Crear Sala" silently discards it. (e) Validation errors appear as
`SnackBar`s far from the fields. (f) `inkSoft` tagline fails AA at 16pt. (g) The OS navigation bar is
forced to `#111111` under a Paper screen.

**OPPORTUNITY.** This is the brand's front door and its navigation shell in one screen.

**REFERENCE.** Wonderous (one dominant focal element; bundled fonts). Lichess (app-bar identity + icon
actions). Deliberately **not** bottom navigation — see `COMPETITIVE_PATTERN_MATRIX.md` D5.

**PROPOSED.** App bar carrying the small isotype with profile and leaderboard actions. Wordmark asset as
the headline. Tagline in `inkMuted`. Season banner demoted below the primary CTA, flat, named accent.
Two visually grouped paths — a Butter "Crear Sala" panel and a secondary "Unirse" panel with the code
field — so the discard cannot happen silently. Field-level `errorText`. `SystemUiOverlayStyle` resolved
per register. Later (1.2, content-gated): illustrated pack cards as the visual protagonist.

**PRIORITY: P0.**
**DEPENDENCIES.** Bundled fonts · isotype + wordmark assets · `PhaseScope` · `inkMuted` · named season
accent.

---

### 2. Lobby

**CURRENT.** The best screen. Room code as a genuine protagonist (Butter-tint hero card, `radiusXl`,
hairline, colour-tinted protagonist shadow, tabular display at 32pt, tracking 4), copy affordance with
`selectionClick`, `GameCopy` waiting line, player list, host-gated start whose label states why it is
disabled.

**PROBLEM.** (a) Player rows use a default `CircleAvatar` with a name initial — the 12-avatar system is
invisible exactly where it would first pay off socially. (b) Copy-to-clipboard shows a silent
`SnackBar`; Cap. 18 explicitly requires an icon `Swap` to a check. (c) No way to leave a lobby. (d)
`Colors.orange` / `Colors.red` snackbars. (e) `inkSoft` label contrast. (f) No online/presence
indication despite a running heartbeat.

**OPPORTUNITY.** Cap. `EMOTIONAL JOURNEY` stage 3 wants "complicidad naciente" — each arriving player
should feel like an event. Today a name appears in a list.

**REFERENCE.** LocalSend (device-presence lists). Lichess (`Hero`-style continuity between screens).

**PROPOSED.** `BufonPlayerRow` with the real avatar face, a Sky presence dot and a Butter host pill. Each
arrival enters with `Arrive` + `mediumImpact`. Copy button swaps its icon to a check. Room code becomes
a `Hero` that flies into the game header. Overflow menu with leave-room. `BufonFeedback` replaces the
raw snackbars.

**PRIORITY: P2** for polish, **P1** for avatars (they unblock the avatar economy's visibility).
**DEPENDENCIES.** Avatar assets · `BufonPlayerRow` · `Arrive` · `BufonFeedback` · `Hero`.

---

### 3. Answering (`GameScreen`)

**CURRENT.** Legacy casino. `RoundIndicator` in the app-bar title, `GameProgressBar`, `TimerWidget`,
question in a red-gradient card with a coloured shadow, optional gold transition banner, "Tu respuesta:",
3-line `TextField` with a 100-char counter, send button, `Spacer`, status container with a second
progress bar and two lines of copy, optional host button.

**PROBLEM.** (a) **No protagonist** — five blocks compete, and round progress is displayed **four times**
before the player reaches the question. (b) **Real overflow risk**: `Spacer` in a non-scrolling `Column`
with a raised keyboard and large text scale. (c) Legacy palette; indistinguishable from Voting. (d)
Gradient question card violates the flat-by-default law. (e) `Error al enviar: $e` shown to players. (f)
Answer sending is confirmed by a `SnackBar` **and** a full card. (g) No way to leave. (h) The screen can
sleep mid-round.

**OPPORTUNITY.** This is where a player is being funny under pressure. The question and the clock are the
only two things that matter.

**REFERENCE.** Wonderous (one giant element, everything else a thin edge). Lichess (`wakelock_plus`
during active play).

**PROPOSED.** Graphite ground, **Sky** accent. The question becomes the protagonist: flat Graphite+1
card, `radiusXl`, `h2`→`h1` scale, 40–50% of screen height. The timer becomes the only other emphasis —
a larger arc in Sky→Coral, top-right. **Delete** `RoundIndicator` from the app bar, and delete
`GameProgressBar`'s caption and percentage; keep only the segmented bar as a 6 px band under the app bar.
The status panel compresses to one line with a tweened count. `SingleChildScrollView` +
`ConstrainedBox`, matching the fix already proven in `home_screen.dart`. Inline-only confirmation.
`wakelock_plus` for the phase. Overflow leave.

**PRIORITY: P0** (overflow + hierarchy) / **P1** (recolour).
**DEPENDENCIES.** `PhaseScope` · goldens · `BufonStatusPanel` · `GameCard`/button fixes · tweened
counters · `wakelock_plus`.

---

### 4. Voting

**CURRENT.** Legacy casino. `RoundIndicator`, `GameProgressBar`, `h2` prompt, a smaller tinted italic
echo of the question, optional green banner (whose `AnimatedOpacity` is dead code), staggered list of
`GameCard`s with the player's own card disabled, status container, host CTA.

**PROBLEM.** (a) The prompt is larger than the question it refers to. (b) Visually identical to
Answering. (c) Four simultaneous confirmations for one vote (SnackBar + banner + container colour +
card pulse), and the SnackBar can be interrupted mid-appearance by the 2 s auto-advance. (d) White text
on a Mint selected card ≈1.9 : 1 at the highest-stakes moment. (e) The player's own disabled card is
unexplained. (f) `Error inesperado: $e`. (g) The dead banner animation. (h) Selected cards use a
gradient. (i) No `Semantics(selected:)`.

**OPPORTUNITY.** Cap. `EMOTIONAL JOURNEY` stage 5: "estoy juzgando en secreto". This should be the
quietest, most deliberate screen in the game — and the one where Lavender finally earns its place.

**REFERENCE.** Wonderous (compressed chrome, dominant content). LocalSend (`Hero` continuity into the
next screen).

**PROPOSED.** Graphite ground, **Lavender** accent — so a screenshot of Voting is unmistakably not
Answering. The answer cards *are* the protagonist: flat, `radiusLg`, generous vertical rhythm, no
gradient, Ink-on-Lavender when selected. The question sits above as a small Lavender-tinted label; the
`h2` prompt is deleted (the cards make the question obvious). The player's own card is labelled
"Tu respuesta" and visually muted rather than merely disabled. One confirmation only — the card itself.
`PhaseBanner` replaces the dead banner. The selected card becomes a `Hero` into the reveal spotlight.
Deliberately no urgency motion: this is the coiled-not-dead register.

**PRIORITY: P1.**
**DEPENDENCIES.** `PhaseScope` · `GameCard` fix · `PhaseBanner` · `Hero` · goldens.

---

### 5. Reveal (`RoundResultScreen`)

**CURRENT.** Legacy casino. Gold-gradient `_WinnerSpotlight` entering over 650 ms `easeOutBack`, two
staged `AnimatedSwitcher`s at 750 ms and 1550 ms with escalating haptics, confetti at stage 2 (1800 ms),
**and the full night scoreboard rendered from stage 0**, a "Marcador de la noche" header, and a bare
`ElevatedButton` for the host.

**PROBLEM.** (a) **The screen spoils its own reveal** — the scoreboard's `#1` row identifies the winner
during the 800 ms of engineered suspense. Fase 3F's acceptance criterion states this explicitly and it
is unmet. (b) The signature keyhole transition, written for exactly this moment, is unused. (c) Two
different sortings on one screen (round votes vs. cumulative score), unlabelled. (d) `gold` — a retired
colour — on a gradient card. (e) Confetti at 1.8 s instead of 3 s, in the casino palette. (f) The host's
advance button is the only primary action in the loop with no press physics, haptic or sound. (g)
Non-hosts get a static card with no indication of how long they will wait. (h) `Error: $error` as the
entire error state, with no recovery action.

**OPPORTUNITY.** This is the emotional peak of every round — the moment the specification says Bufón
exists to produce. It is currently 80% right and undermined by one widget.

**REFERENCE.** Wonderous (staged dramatic reveals). Flame samples (never snap a number). The keyhole
motif from Bufón's own isotype.

**PROPOSED.** Graphite → Butter, in two stages. Stage 0: the spotlight alone, nothing else on screen —
this is the silence. Stage 1: the winning answer opens through the **keyhole mask** (`revealStage`
800 ms, `easeOut`, origin centre, Graphite backdrop), arriving via `Hero` from the voting card. Stage 2:
the author's name at `displayButter`, `celebration()` haptic, 50 particles for 3 s in the brand palette.
**Only then** does the scoreboard `Arrive` from below, with tweened score values and a label clarifying
that it is cumulative. Host CTA becomes `AnimatedPrimaryButton`. Non-hosts see a coiled waiting state.
`BufonPlaceholder` for errors.

**PRIORITY: P1** — and the scoreboard gate is the highest-return single change in the release.
**DEPENDENCIES.** `KeyholeRevealTransition` wiring · `Hero` · tweened counters · confetti fix ·
`displayButter` · `PhaseScope` · `BufonPlaceholder` · goldens.

---

### 6. Final winner

**CURRENT.** Hardcoded `#111111`, three-stop gradient of legacy red/gold, `elasticOut` avatar entrance,
repeating glow, 3 s confetti, `🏆 BUFÓN DE LA NOCHE 🏆` in gold, avatar emoji at 96pt in a gold-gradient
circle, name at `h1`, two stats, share CTA (winner only), outlined exit.

**PROBLEM.** (a) **The winner's real avatar is never shown** — `round_result_screen.dart:162` hardcodes
`'default'`, so every winner in the game wears the same clown. Fase 3G's criterion is explicit. (b) The
share CTA is gated to the winner, cutting the reach of the app's only viral surface by up to 87% in an
8-player room — and the person most likely to share a Bufón moment is often the friend who found it
funniest. (c) **No haptic fires at all** on the app's emotional peak. (d) `AppElevation.ceremonialGradient`
— written for this screen — is unused; the screen hand-rolls its own gradient instead. (e) Retired `gold`
throughout, plus a hardcoded `#111111`. (f) Confetti is not scaled to the night tier. (g) `elasticOut`
overshoots well past `celebrationOvershoot` 1.15. (h) `Error al compartir: $e`. (i) No scoreboard, no
recap, no "best answer of the night" — the night ends with one name and two numbers, when the
specification says the memory is *what happened*, not who won.

**OPPORTUNITY.** The most screenshot-able moment in the product, and the one place the ceremonial layer
is licensed to break the system's own rules.

**REFERENCE.** Wonderous (full-bleed ceremonial composition). Bufón's own Cap. 31 (four share-card
compositions; the avatar is the protagonist for a winner card, with the score as a footnote).

**PROPOSED.** `AppElevation.ceremonialGradient(butter, graphite)` as the ground. The winner's **real**
avatar face is the sole protagonist, arriving with `release` at 1.15 overshoot. Wordmark asset instead of
the emoji-bracketed typed title. Stats tiny and tabular. `celebration()` on entry, repeated per revealed
stat. 80–100 particles over 4–5 s with a fade tail. **Share CTA visible to every player.** A night recap
below the fold surfacing the funniest answers of the session — the highest-value content addition in 1.1.
"Ver mi progreso" CTA, which is also the P0 reachability fix.

**PRIORITY: P1** (P0 for the progress CTA and the real avatar).
**DEPENDENCIES.** Avatar assets · wordmark · `ceremonialGradient` · confetti params · share-card
redesign · navigation shell.

---

### 7. Paywall

**CURRENT.** No tokens at all. `Color(0xFF1A1A2E)` scaffold, `Color(0xFF16213E)` app bar,
`Color(0xFFE94560)` spinner, `Colors.green` / `Colors.red.shade700` snackbars, 21 raw colour
expressions, two equal-weight offer cards, a full-screen spinner replacing the whole screen while
loading, and **two raw exception strings shown during a payment flow**.

**PROBLEM.** The only screen where Bufón asks for money is the least polished screen in the app, and it
leaks stack-trace text at the point of purchase. Cap. 4 forbids giving monetisation an emotional colour;
Cap. 33 asks for "directo, sin fricción visual"; Cap. 34 forbids manufactured urgency; Cap. 26 forbids
raw exceptions. Two equal-weight cards also violate the one-protagonist law.

**OPPORTUNITY.** Trust is a visual property. A player deciding whether to spend money reads polish as
safety.

**REFERENCE.** Deliberately **not** the equal-weight card dashboards in Obtainium/AppFlowy. Wonderous's
hierarchy discipline.

**PROPOSED.** Paper ground, Ink text, **Butter as the only accent** — no emotional colour, exactly as
Cap. 4 requires. One recommended option as the protagonist (the Night Pass), the ad option present but
secondary. Honest, plain copy in Bufón's voice, no countdowns, no scarcity language. `BufonLoader`
instead of a screen-replacing spinner. All errors through `GameCopy` with the technical detail in
telemetry only. `heavyImpact` on a blocked action, per Cap. 19's currently-missing entry.

**PRIORITY: P1** — high, because it is both the least polished screen and the one handling money.
**DEPENDENCIES.** `PhaseScope` · `BufonLoader` · `BufonFeedback` · `GameCopy` centralisation.

---

### 8. Leaderboard · 9. Profile · 10. Public profile · 11. Season details · 12. Title selector

**CURRENT.** All legacy casino. All unreachable except Season details (via the Home banner). Between
them: 3 raw `TabBar`s with legacy indicators, 2 hand-rolled sliver headers, 2 empty states using 64 px
Material icons, 2 designed error states, 6 error branches collapsing to `SizedBox.shrink()`, two
divergent rarity ladders, `Colors.grey`/`Colors.brown` rank colours, `Icons.photo_size_select_actual`
representing a top-10 finish, and 4 XP/level bars in 2 styles.

**PROBLEM.** The proximate problem is not that they are ugly — it is that **players cannot reach them**.
Recolouring an unreachable screen changes nothing a player experiences.

**OPPORTUNITY.** The specification's own emotional thesis is "pertenecer, no ganar" — the memory is the
night with this group, not the score. Titles, avatars and season badges are precisely the artefacts of
belonging, and they are all here.

**REFERENCE.** Lichess (a deep meta layer reachable from a shallow shell). Wonderous (illustrated
states). Cap. 25 (brand illustration, voice, ≤1 action).

**PROPOSED, in two steps.**
**Step 1 (P0, 1.1): make them reachable** and fix only what is cheap and functional — one `Rarity`
ladder, `BufonPlaceholder` for the empty and error states, the mis-picked icon, `BufonFeedback` for
snackbars, `tooltip`s on the icon-only controls. Leave the casino palette in place for now; it is
consistent with the rest of the unmigrated app, which is less jarring than a half-migrated meta layer.
**Step 2 (1.2): Fase 3H/3I** — Paper register, Sky/Lavender accents, brand illustration, proper
composition.

**PRIORITY: P0** for reachability · **P1** for the cheap functional fixes · **P2/P3** for the recolour.
**DEPENDENCIES.** Navigation shell · `Rarity` · `BufonPlaceholder` · `BufonFeedback`.

---

## Part V — What NOT to do

### Visual trends that do not fit Bufón

| Trend | Why not |
|---|---|
| **Dynamic OS colour / Material You** | Three of the five product references use it. It would erase `FIRMA VISUAL` item 1 — Butter + Ink at maximum contrast — which the specification makes permanent. The most dangerous item on this list precisely because it is fashionable and well-reviewed. |
| **Glassmorphism / frosted blur** | Requires mid-luminance translucency, which Cap. 3 law 2 forbids outright. Also the "tech premium" register Cap. 20 explicitly excludes. |
| **Neumorphism** | Depends on soft grey double shadows. Bufón's shadows are colour-tinted and its palette has no mid-greys. |
| **Gradient-heavy "Web3" aesthetics** | 16 gradients already exist against a stated budget of 2–3. |
| **Dark-mode-only** | Cap. 29/30 make light and dark *emotional registers*, not preferences. Losing Paper loses half the identity. |
| **Bento-box card grids** | Equal-weight tiles are the inverse of one-protagonist-per-screen. |
| **Oversized rounded "friendly app" everything** | Cap. 6's own self-critique: the Fredoka/Baloo/Poppins look is the uniform of a thousand apps. |
| **AI-generated illustration** | Cannot hold the isotype's exact stroke weight, corner radius and expression grammar across a set. Cap. 13 requires each illustration to read as a visual relative of the mark. |
| **Skeleton shimmer loaders** | Cap. 24 asks for a *branded* wait (the breathing isotype). A shimmer is a better generic, and generic is the problem. |
| **Countdown-timer urgency in monetisation** | Cap. 34 forbids it explicitly. |

### Components that should NOT be copied

- **Forui / shadcn_ui component sets.** Minimalist, neutral, low-contrast, desktop-first. Adopting them
  would make Bufón look competent and anonymous. Steal Forui's *theming architecture*, not its widgets.
- **GetWidget / Flutter-UI-Kit templates.** Designed to look good in a gallery screenshot, which
  optimises for generic appeal — the precise inverse of Cap. 0's recognisability test.
- **The `animations` package's Material transitions.** Faithful Material motion is what Cap. 34 forbids.
- **`flutter_spinkit`.** A prettier generic spinner is still generic.
- **Stock Lottie files.** The fastest possible route to looking like every other app that used the same
  free asset.
- **Material `NavigationBar` under the game loop.** `AppTheme` already themes it, which makes it
  tempting. A persistent chrome bar under the reveal competes with the protagonist.
- **Bufón's own `ShareVictoryCard` composition.** It should be redesigned, not extended. Building the
  other three Cap. 31 card types on the current casino chassis would triple the problem.

### Unnecessary dependencies

`flutter_animate` (adoption is the bottleneck, not ergonomics) · `rive` (no vector art yet) · `lottie` ·
`flame` · `forui` · `shadcn_ui` · `getwidget` · `animations` · `dynamic_color` /
`dynamic_system_colors` / `yaru` · `lucide_icons_flutter` · `flutter_spinkit` · `auto_size_text` ·
`gap` / `flextras` / `extra_alignments` / `sized_context` · `hsluv` · `flutter_native_splash` (native
config edits are a one-time task).

**The standing rule.** A new UI package must do something Bufón cannot reasonably do in ~100 lines of
its own code. Bufón's UI dependency footprint today is two packages, one unused. That leanness is an
asset.

### Excessive animation to avoid

- Animating everything. Cap. 1 principle 3: silence is part of the rhythm, and it is what makes the
  reveal land.
- Confetti for anything below a round win. Cap. 22 is explicit; scarcity is the whole mechanism.
- Breathing on ambient-layer elements. Stillness is what makes the protagonist's breathing visible.
- Parallax, scroll-driven effects, and continuous background motion. Bufón is read from across a table;
  ambient movement is noise at that distance.
- Filling the pre-reveal silence "so players aren't bored". `RHYTHM SYSTEM` names this as the exact
  failure mode to guard against.
- Repeating the same haptic more than twice without escalating. Currently violated five times in five
  seconds by the timer.
- Ringing the bell (once audio exists) anywhere but the reveal and the celebration.

### Over-designed screens to avoid

Any screen with two protagonists. Any screen with a decorative background behind text. Any screen with
more than one accent colour dominant. Any screen restating the same fact more than once — Answering
currently states round progress four times.

### Visual clutter to eliminate

`GameProgressBar`'s caption and percentage (redundant with its own segments) · `RoundIndicator` in the
app bar (redundant with the bar) · Voting's `h2` prompt (redundant with the cards) · three of Voting's
four vote confirmations · the second question echo on Voting · the Season banner's simultaneous
gradient + glow + border + trophy + chevron · the winner screen's emoji brackets around a typed title.

### Generic Material patterns to avoid

Default `MaterialPageRoute` transitions (7 remain) · ripple as the only press feedback (7 controls) ·
bare `CircularProgressIndicator` (12) · default `SnackBar` styling (12 sites, 5 colour sources) ·
Material elevation as a z-axis metaphor (`AppElevation` correctly rejects it; the legacy theme still uses
`elevation: 4/8/16`) · outline icons (8) · `ListTile` defaults for player rows · raw `TabBar` with a
Material indicator (3).

### What would make Bufón look like a template

A widget-kit component set · stock Lottie · a mass-adopted icon library · Poppins/Fredoka/Baloo ·
equal-weight card grids · a gradient on every button · dynamic OS colour · a generic bottom nav with
generic icons.

### What would make Bufón look like corporate SaaS

Neutral greys as content backgrounds · thin hairline minimalism · `Icons.trending_up` and chart
metaphors · restrained radii · sentence-case neutral copy ("No hay datos", "Error al cargar") ·
equal-weight offer cards on the paywall · a settings-style dashboard for progression.

### What would make Bufón look like a children's game

Rainbow palettes · everything bouncing · thick cartoon outlines · exclamation marks everywhere ·
Comic-adjacent type · googly open eyes (Cap. `FIRMA VISUAL` item 3 permits **only** closed happy arcs) ·
arcade sound effects · confetti on every interaction. The jester is warm and a little wicked, not cute —
that distinction is the whole brand.

### Unnecessary architectural changes

- **Do not** restructure Riverpod, the repository layer, or Firestore access for visual work. `AGENTS.md`
  is explicit that room consistency outranks polish.
- **Do not** introduce a router package (`go_router` etc.) as part of a visual release. The imperative
  `Navigator` works; a router migration is a separate concern with real regression risk on a live
  multiplayer loop.
- **Do not** change the auto-advance timers (`_scheduleAutoVoting`, `_scheduleAutoResults`) for
  aesthetic reasons. They are synchronisation-adjacent. The pre-reveal silence is deferred for exactly
  this reason.
- **Do not** delete the legacy palette in one commit. Deprecate it, migrate call sites, let
  `flutter analyze` produce a burndown.
- **Do not** unify the two press durations (100/150 ms) or the two press scales (0.95/0.97). They were
  tuned separately; `motion_tokens.dart` documents why.
- **Do not** rewrite `ConfettiWidget`, `TimerWidget`, `KeyholeRevealTransition` or the reveal staging.
  Recolour, parameterise and wire. The mechanisms are correct.
- **Do not** add platform-adaptive widget branching. A Bufón button should feel like Bufón on both
  platforms.

---

## Part VI — Prioritised roadmap

Estimates are relative. **VI** = visual impact, **CX** = implementation complexity, **R** = risk,
**Dep** = new package required.

### Foundation

| # | Item | VI | CX | R | Dep | Notes |
|---|---|---|---|---|---|---|
| F1 | Bundle fonts; disable runtime fetching; register licences | **HIGH** | LOW | LOW | No | Removes a guaranteed first-launch brand failure |
| F2 | Add `inkMuted`; repoint body text off `inkSoft` | MED | LOW | LOW | No | Fixes an AA failure on the two migrated screens |
| F3 | `PhaseScope` + `context.text.*` extensions | MED | MED | LOW | No | Structural; removes the invisible-white-text failure mode |
| F4 | Deprecate the legacy palette (annotate, don't delete) | LOW | LOW | **LOW** | No | Gives a live burndown count for free |
| F5 | Golden tests for the 6 core components | LOW | MED | LOW | No | **Do before any recolour.** Fase 3B's own unmet criterion |
| F6 | One `Rarity` enum on `AppColors` | MED | LOW | LOW | No | Retires the last live uses of `gold` |
| F7 | Named `SeasonAccent` enum; retire the raw Firestore int | MED | LOW | MED | No | Closes an unconstrained colour injection into Home |
| F8 | Opacity + icon-size scales | LOW | LOW | LOW | No | Hygiene |
| F9 | Centralise all copy in `GameCopy`; eliminate 6 raw-exception strings | MED | LOW | LOW | No | Also step one of any future i18n |
| F10 | Five primitives: `BufonLoader`, `BufonPlaceholder`, `BufonStatusPanel`, `BufonPlayerRow`, `BufonFeedback` | **HIGH** | MED | LOW | No | Removes ~30 inline implementations |
| F11 | `AnimatedPrimaryButton` + `GameCard` refits | **HIGH** | MED | LOW | No | Flat fill, pill, semantics, contrast, reduce motion |

### Identity

| # | Item | VI | CX | R | Dep | Notes |
|---|---|---|---|---|---|---|
| I1 | App icon from the isotype | **HIGH** | LOW | LOW | No | The first impression; currently the Flutter logo |
| I2 | Launch screen: Butter + isotype | **HIGH** | LOW | LOW | No | Removes a white flash into cream |
| I3 | Rename to "Bufón" (both platforms) | MED | LOW | LOW | No | Testers cannot find the app today |
| I4 | Move brand marks into `assets/brand/`; produce vector | **HIGH** | LOW | LOW | **Maybe** `flutter_svg` — or a `CustomPainter` | Decide format first |
| I5 | Isotype in the Home app bar; wordmark as the headline | **HIGH** | LOW | LOW | No | Blocked on the BUFON/BUFÓN accent decision |
| I6 | 8 custom brand glyphs as one icon font | **HIGH** | MED | LOW | No | **Design-led** |
| I7 | Replace 8 outline icons with filled; consolidate 4 duplicate pairs | MED | LOW | LOW | No | ~1 hour; cheapest consistency win in the audit |
| I8 | Fix 3 semantic icon mis-picks | LOW | LOW | LOW | No | |
| I9 | 12 brand avatar faces replacing emoji | **HIGH** | **HIGH** | MED | No | **Design-led**; largest identity return |
| I10 | Share-card redesign (Butter, isotype, avatar protagonist) + best-answer card | **HIGH** | MED | LOW | No | The only artefact reaching non-players |
| I11 | Pack artwork + selection UI | **HIGH** | **HIGH** | MED | No | **Gate on content expansion** |
| I12 | Paper grain texture | LOW | LOW | MED | No | P3; easy to overdo |

### Interaction

| # | Item | VI | CX | R | Dep | Notes |
|---|---|---|---|---|---|---|
| X1 | `Arrive` helper (~40 lines on existing tokens) | MED | LOW | LOW | No | Instead of `flutter_animate` |
| X2 | Migrate 7 `MaterialPageRoute`s to `Arrive` | MED | LOW | LOW | No | One transition language |
| X3 | Fade-only backward variant | LOW | LOW | LOW | No | Cap. 23 |
| X4 | `Hero` for room code and winning answer | MED | MED | LOW | No | SDK `Hero`, no package |
| X5 | Route all haptics via `HapticService`; add coalescing + `enabled` | MED | LOW | LOW | No | Makes Cap. 19's economy rule implementable at all |
| X6 | Reduce-motion guards (6 sites) | LOW visual / **HIGH** a11y | LOW | LOW | No | A system-level request currently ignored |
| X7 | `Semantics` + tooltips across all controls | LOW visual / **HIGH** a11y | LOW | LOW | No | |
| X8 | `game_screen` scroll fix + global textScaler clamp | MED | LOW | LOW | No | Pattern already proven in `home_screen.dart` |
| X9 | `wakelock_plus` during active phases | LOW visual / **HIGH** UX | LOW | LOW | **Yes** | Prevents sleep mid-round |
| X10 | Replace 7 plain buttons with `AnimatedPrimaryButton` (secondary variant) | MED | LOW | LOW | No | Includes the host's most-repeated action |
| X11 | Copy-code icon `Swap` to a check | LOW | LOW | LOW | No | Cap. 18 explicitly |

### Game feel

| # | Item | VI | CX | R | Dep | Notes |
|---|---|---|---|---|---|---|
| G1 | **Gate the scoreboard behind reveal stage 2** | **HIGH** | LOW | LOW | No | Restores 800 ms of engineered suspense |
| G2 | Wire `KeyholeRevealTransition` into the reveal | **HIGH** | LOW | LOW | No | The brand's declared ownable gesture; code exists |
| G3 | Recolour confetti to the Cap. 21 palette | MED | LOW | LOW | No | 15 minutes |
| G4 | Celebration tiers: 50/3 s round, 80–100/4–5 s night | MED | LOW | LOW | No | Restores a flattened ladder |
| G5 | Real winner avatar (`'default'` → equipped) | **HIGH** | LOW | LOW | No | Every winner currently wears the same clown |
| G6 | Share CTA for all players | MED visual / **HIGH** growth | LOW | LOW | No | One line; up to 8× reach |
| G7 | `celebration()` haptic on the winner screen | MED | LOW | LOW | No | The peak is currently silent to the hand |
| G8 | Tween all numeric counters | MED | LOW | LOW | No | Cap. 18; currently zero |
| G9 | Fase 3E: Answering → Graphite + Sky | **HIGH** | MED | LOW | No | After F5 goldens |
| G10 | Fase 3E: Voting → Graphite + Lavender | **HIGH** | MED | LOW | No | Makes the phases distinguishable at a glance |
| G11 | Fase 3F: Reveal → Graphite + Butter, `displayButter` | **HIGH** | MED | LOW | No | |
| G12 | Fase 3G: Winner → `ceremonialGradient` | **HIGH** | MED | LOW | No | |
| G13 | Establish one protagonist on Answering (delete 3 read-outs) | **HIGH** | LOW | LOW | No | Mostly deletion, hence cheap |
| G14 | Timer refit (Coral ramp, escalating haptic, bigger arc, semantics) | MED | LOW | LOW | No | |
| G15 | Night recap / best answer of the night | **HIGH** | **HIGH** | MED | No | Defer to 1.2; highest-value content addition |
| G16 | Engineered 2–3 s pre-reveal silence | MED | MED | **HIGH** | No | Touches sync timing — treat as gameplay work |

### Polish

| # | Item | VI | CX | R | Dep | Notes |
|---|---|---|---|---|---|---|
| P1 | Replace 12 spinners with `BufonLoader` | MED | LOW | LOW | No | |
| P2 | Brand empty states (Cap. 25) | MED | MED | LOW | No | Needs illustration assets |
| P3 | Brand error states; no raw exceptions | MED | LOW | LOW | No | Includes the purchase flow |
| P4 | Connectivity banner on the loop | LOW visual / **HIGH** UX | LOW | LOW | No | Uses the existing `ConnectionService` |
| P5 | Resolve `SystemUiOverlayStyle` per register | LOW | LOW | LOW | No | OS chrome currently contradicts Paper screens |
| P6 | Paywall migration | MED | MED | LOW | No | Least polished screen; handles money |
| P7 | Leave-room affordance + `PopScope` | LOW visual / MED UX | LOW | MED | No | Players are currently trapped mid-game |
| P8 | Field-level validation on Home | LOW | LOW | LOW | No | |
| P9 | Label the player's own disabled voting card | LOW | LOW | LOW | No | |
| P10 | Replace 5 raw duration literals with tokens | LOW | LOW | LOW | No | |
| P11 | Fix the dead `AnimatedOpacity` | LOW | LOW | LOW | No | |
| P12 | Rename the colliding phase schemes | LOW | LOW | LOW | No | Repo hygiene |
| P13 | Fase 3H/3I recolour | MED | MED | LOW | No | **After** reachability. Defer to 1.2. |

### Release sequencing

| Wave | Contents | Gate to exit |
|---|---|---|
| **0** | F5 goldens · F4 deprecation | Goldens pass for 6 components |
| **1** | I1 I2 I3 I4 F1 | App installs as "Bufón" with its own icon and splash; no runtime font fetch |
| **2** | Navigation shell (I5 + winner progress CTA) | Profile and Leaderboard reachable in ≤2 taps from Home |
| **3** | G1 G2 G3 G4 G5 G6 G7 G13 I7 I8 X9 X11 | 12 quick wins; each ≤3 h; no regression in goldens |
| **4** | F2 F3 F6 F7 F9 F10 F11 X1 X5 X10 | Five primitives live; ~30 inline implementations deleted |
| **5** | X6 X7 X8 P3 P4 P5 | Reduce motion and text scale honoured; zero raw exceptions |
| **6** | G8 G9 G10 G11 G12 G14 X2 X3 X4 | Answering vs. Voting distinguishable without reading text |
| **7** | P6 I10 P1 P2 P7 P8 P9 P10 P11 P12 | Paywall on tokens; share cards on brand |
| **1.2** | I6 I9 I11 G15 G16 P13 · audio · Rive · `flutter_animate` · onboarding · settings | — |

---

## Part VII — Executive summary

### Current maturity

| Dimension | Score | Reasoning |
|---|---|---|
| **Visual maturity** | **4 / 10** | An excellent token layer adopted by 2 of 11 screens; two live palettes; the app icon is Flutter's |
| **UX maturity** | **4 / 10** | The core loop is legible and well instrumented, but 2,285 lines of progression UI are unreachable, there is no onboarding, no settings, no exit from the loop, and 6 sites leak raw exceptions |
| **Motion maturity** | **5 / 10** | Real brand physics, a complete token vocabulary, an excellent staged reveal and a working particle engine — but half the tokens have never executed, the signature transition is unused, 7 navigations use the Material default, and reduce-motion is ignored entirely |
| **Design-system maturity** | **6 / 10** | The specification and token layer are 9/10 work; the wiring is 3/10. Roughly 2.6 of 10 planned phases complete |
| **Brand identity maturity** | **3 / 10** | A genuinely distinctive, well-reasoned identity — a keyhole-bearing jester whose face *is* a letter — that appears literally nowhere in the shipped app |

**The one-sentence diagnosis.** Bufón's problem is not taste, ambition or design thinking — all three
are above the level of most indie products. It is **distance between the specification and the binary**,
and 1.1 should be measured in adoption percentage rather than in new design ideas.

### Top 10 changes for 1.1, ranked by perceived-quality gain

| # | Change | Why it is ranked here | Effort |
|---|---|---|---|
| **1** | **Ship the brand at the OS level** — isotype app icon, Butter launch screen, rename to "Bufón", bundle the fonts | The first, most frequent and most permanent impression currently belongs to Flutter. Everything else in this list is downstream of a player being able to find and recognise the app. Bundling the fonts additionally removes a guaranteed first-launch brand failure, and share cards stop escaping in the wrong typeface. | 1 day |
| **2** | **Make the progression surface reachable** — Home app bar with profile + leaderboard, "Ver mi progreso" on the winner screen | One app bar and one CTA unlock 2,285 lines of finished UI plus the entire XP/avatar/title/achievement/leaderboard/season economy. Highest total product impact per hour available. Rewards granted invisibly are rewards not granted. | 1–2 days |
| **3** | **Gate the reveal's scoreboard behind stage 2** | A ~10-line change that restores 800 ms of deliberately engineered suspense at the emotional peak of every round. The screen currently spoils its own best moment. Highest impact-to-effort ratio in the entire audit. | 30 min |
| **4** | **Recolour the live loop into distinct phase registers** — Graphite + Sky for answering, Graphite + Lavender for voting, Graphite + Butter for the reveal, ceremonial for the winner | Realises the specification's central emotional device. A player would be able to tell which phase they are in with the sound off and without reading a word — the actual test Cap. 4 sets. Also retires the casino palette from where players spend most of their time. | 3–5 days |
| **5** | **Establish one protagonist per screen**, mostly by deleting — three of four progress read-outs on Answering, the redundant prompt and three of four confirmations on Voting | Cap. 3 law 4 is the specification's most important rule and it fails on the three screens that consume ~70% of session time. Because the fix is largely deletion, it is cheap, low-risk and immediately visible. | 1–2 days |
| **6** | **Wire the keyhole reveal transition** | The design system names this Bufón's *ownable gesture*, traced from the keyhole cut in the isotype's hat to the game's secret-keeping mechanic. The code is written, documented and committed — and has never rendered a frame. Nothing else in the codebase converts so directly into distinctiveness. | 2–3 h |
| **7** | **Replace emoji avatars with 12 brand faces** | A player's identity is currently Apple's clown on iOS and Google's clown on Android. Avatars appear at the two highest-emotion moments the product has and on every card that leaves the app. This is the largest identity return of any single asset investment — and the one item on this list that genuinely requires design capacity. | 3–5 days |
| **8** | **Fix the winner screen's three broken promises** — the real equipped avatar, a share CTA for every player, and a `celebration()` haptic | Every winner currently wears the same default clown; the app's only viral surface is gated to one of 3–8 players (and the person most likely to share is often not the winner); and the emotional peak of the entire session is silent to the hand. Three small fixes on the most screenshot-able screen. | 1 h |
| **9** | **Accessibility package** — `Semantics`, tooltips, reduce-motion, text-scale handling, `inkMuted`, `game_screen` overflow fix | The app has one tooltip in total and ignores two *system-level* accessibility requests. It is not currently playable with assistive technology, which matters for a spoken social game passed around a table. It also removes a live overflow risk on the most-used screen. | 1–2 days |
| **10** | **Five component primitives + the copy sweep** — `BufonLoader`, `BufonPlaceholder`, `BufonStatusPanel`, `BufonPlayerRow`, `BufonFeedback`, and every string through `GameCopy` | Removes ~30 inline implementations, 12 bare spinners, 5 raw error screens, 12 snackbar call sites with 5 colour sources, and all 6 raw exception strings. Converts the app's strongest existing asset — its voice — from ⅓ coverage to full coverage, including the errors and empty states where warmth matters most. | 2–3 days |

**Just outside the top 10:** the 1-hour outline-icon sweep (cheapest consistency win in the audit),
`wakelock_plus` (the screen sleeps mid-round today), the share-card redesign plus a best-answer card,
tweened numeric counters, and the connectivity banner.

### Two dependencies, and only two

`wakelock_plus` (a platform capability, not implementable in Dart) and — conditionally, only if the
isotype ships as SVG rather than as a `CustomPainter` — `flutter_svg`. Of roughly 45 external patterns
evaluated across 15 repositories, two justify a dependency, six justify writing Bufón's own version, and
eleven are actively harmful to the brand. The project's design specification is ahead of most of the
references it was asked to study.

---

**NOTHING IN THIS BLUEPRINT HAS BEEN IMPLEMENTED.** This document set is research, audit and
specification only. The repository's production code, assets, configuration and dependencies are
unchanged.
