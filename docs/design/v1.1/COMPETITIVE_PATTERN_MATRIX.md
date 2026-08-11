# COMPETITIVE PATTERN MATRIX

> Each row is a pattern observed in an external reference, evaluated against the ten questions
> mandated by Phase 3. Answers are compressed into a single decision column with reasoning.
>
> The ten questions: 1 Does Bufón already solve this? 2 Is Bufón's version strong enough?
> 3 Is the external pattern actually better? 4 Would it strengthen Bufón's identity?
> 5 Unnecessary complexity? 6 Fits indie/social/game? 7 Works iOS + Android? 8 Scales in the
> existing architecture? 9 Preserves Bufón's identity? 10 Worth doing in 1.1?

---

## Legend

| Column | Meaning |
|---|---|
| **Already?** | Does Bufón already have this? Y / Partial / N |
| **Strong?** | If yes, is the existing implementation good enough? |
| **Better?** | Is the external pattern genuinely superior for Bufón? |
| **Identity** | + strengthens · = neutral · − dilutes |
| **Cx** | Added complexity: L / M / H |
| **Fit** | Suits an indie social party game? |
| **X-plat** | iOS + Android clean? |
| **Scales?** | Fits Riverpod + Firestore + widget architecture without rework? |
| **1.1?** | Decision |

---

## A. Structure, theming, tokens

| # | Pattern | Source | Already? | Strong? | Better? | Identity | Cx | Fit | X-plat | Scales? | 1.1? |
|---|---|---|---|---|---|---|---|---|---|---|---|
| A1 | Per-component nested style objects instead of one global `ThemeData` | Forui | N | — | **Yes** | + | M | Y | Y | Y | **YES — as `PhaseScope`** |
| A2 | Adaptive/dynamic OS colour (Material You) | LocalSend, Lichess, Obtainium | N | — | No | **−−** | L | N | Y | Y | **NO** |
| A3 | Bundled font assets rather than runtime fetch | Wonderous (6 families), Obtainium, Lichess | N | — | **Yes** | **+** | L | Y | Y | Y | **YES — P0** |
| A4 | Platform-adaptive widget sets (Material on Android, Cupertino on iOS) | flutter/samples `platform_design` | N | — | No | − | H | N | Y | N | **NO — record the decision** |
| A5 | Formal i18n pipeline (`slang`, `easy_localization`, inlang) | LocalSend, Obtainium, AppFlowy | N | — | Yes, eventually | = | M | Y | Y | Y | **NO — but centralise copy in `GameCopy` now, which is step 1** |
| A6 | Perceptually-uniform colour manipulation (`hsluv`) | Obtainium | Partial (plain HSL) | Adequate | Marginally | = | L | Y | Y | Y | **NO — irrelevant for 8 hand-tuned colours** |
| A7 | Theming CLI / codegen for tokens | Forui | N | — | No | = | M | N | Y | N | **NO — 6 hand-written token files are clearer at this size** |

**A1 reasoning.** This is the one structural idea in the entire research pass that Bufón should take.
Material exposes exactly one `ColorScheme` per `ThemeData`, and Bufón's design system is built on
per-phase colour registers (Cap. 33 assigns Butter to Lobby, Sky to answering, Lavender to voting,
Mint to victory). The repo has already discovered the workaround empirically — Home and Lobby wrap
themselves in a local `Theme(data: AppTheme.lightTheme)`. Promoting that to a named `PhaseScope`
widget that also exposes the phase accent via `InheritedWidget` removes the per-call-site
`.copyWith(color:)` tax and makes "one emotional colour per screen" mechanically enforceable rather
than a review convention.

**A2 reasoning.** Three of the five product references use dynamic OS colour, so it reads as best
practice. For Bufón it is destructive: `FIRMA VISUAL` item 1 makes Butter + Ink at maximum contrast a
permanent, non-negotiable brand signature. A palette derived from the player's wallpaper erases the
one thing Cap. 0 says must survive without the logo. Recording this as an explicit **NO** matters
precisely because the pattern is fashionable and well-reviewed.

**A4 reasoning.** Bufón already implicitly decided this — Material widgets on both platforms,
`cupertino_icons` declared and never imported. That is correct for a brand-led game: a Bufón button
should feel like Bufón, not like iOS. The risk is that someone later "improves" it by adding platform
branching. It belongs in the design system as a stated decision.

---

## B. Motion and interaction

| # | Pattern | Source | Already? | Strong? | Better? | Identity | Cx | Fit | X-plat | Scales? | 1.1? |
|---|---|---|---|---|---|---|---|---|---|---|---|
| B1 | Chainable declarative effects (`.animate().fade().scale()`) | flutter_animate; used by Wonderous, shadcn_ui | N | — | Ergonomically yes | = | M | Y | Y | Y | **NO — adopt the *idea* as one `Arrive` helper on existing tokens** |
| B2 | Staggered list entrance with per-item interval | flutter_animate `AnimateList` | **Y** (hand-rolled, voting screen) | Yes | No | + | L | Y | Y | Y | **NO — formalise the existing one instead** |
| B3 | Material motion spec transitions (container transform, shared axis, fade-through) | `animations` pkg via Obtainium | Partial (`FadeSlidePageRoute`) | Yes | No | **−** | L | Y | Y | Y | **NO — Cap. 34 forbids plain Material fades** |
| B4 | Shared-element transition between routes | LocalSend `local_hero` | N | — | **Yes** | **+** | L | Y | Y | Y | **YES — via the SDK's own `Hero`, no package** |
| B5 | State-machine character animation | Rive | N | — | Yes, uniquely | **++** | H | Y | Y | Y | **NO for 1.1 — needs vector art + an owner first** |
| B6 | Timeline vector animation from JSON | Lottie | N | — | No | = / − if stock files | M | Y | Y | Y | **NO** |
| B7 | Engine-grade particles | Flame | **Y** (`ConfettiWidget`) | Yes | No | = | H | N | Y | N | **NO** |
| B8 | Composable `EffectController` sequencing | Flame | Partial (`MotionDurations` tiers) | Adequate | Conceptually yes | = | M | Y | Y | Y | **NO — read it, don't import it** |
| B9 | Tweened numeric counters instead of snapping | Flame samples; Cap. 18 already requires it | **N** | — | **Yes** | **+** | L | Y | Y | Y | **YES — `TweenAnimationBuilder<int>`, no dependency** |
| B10 | Shimmer/skeleton loading | flutter_animate; Awesome Flutter | N | — | Partly | = | L | Y | Y | Y | **NO — Cap. 24 asks for a *branded* loader, which is better** |
| B11 | Reduce-motion honoured throughout | flutter/samples `animations` | **N** | — | **Yes** | + | L | Y | Y | Y | **YES — P0, accessibility** |
| B12 | Keep the screen awake during active play | Lichess `wakelock_plus` | **N** | — | **Yes** | = | L | Y | Y | Y | **YES — P1, adopt the package** |

**B1 reasoning — the closest call.** `flutter_animate` is genuinely good and its provenance is ideal
(gskinner authored both it and Wonderous). It is rejected for 1.1 on a single argument: Bufón's motion
problem is **adoption, not expressiveness**. `motion_tokens.dart` already defines every duration,
curve, scale and spring the design system asks for and roughly half have never executed;
`KeyholeRevealTransition` is written, reviewed and unused. Adding a second, fluent motion vocabulary
to a codebase whose first vocabulary is half-unused would create exactly the dual-system problem that
`AppColors` is currently living through. It is also 20 months since its last publish — the least
recently updated package in the research pass. Revisit in 1.2 once all six Cap. 16 behaviours are in
use and ergonomics is measurably the bottleneck.

**B4 reasoning.** Two Bufón moments are natural shared-element transitions and both reinforce the
brand's narrative of continuity: the **room code** travelling from Lobby's hero card into the game
header (it stays the same object, so it should move, not vanish), and the **winning answer card**
travelling from its position in the voting list into the reveal spotlight (Cap. `BRAND PHYSICS`:
an element that is *consumed* "se contrae viajando hacia el contador o destino que lo recibe,
implicando continuidad, no borrado"). Both source and destination are known, so Flutter's built-in
`Hero` suffices — `local_hero` exists to solve the case where they are not.

**B9 reasoning.** Cap. 18 already mandates this and Bufón implements it nowhere: the answered-count,
vote count, round scores and XP all snap instantly. It is one of the cheapest perceived-quality wins
available and it is validated both by the design doc and by generic game-feel craft.

---

## C. Iconography and illustration

| # | Pattern | Source | Already? | Strong? | Better? | Identity | Cx | Fit | X-plat | Scales? | 1.1? |
|---|---|---|---|---|---|---|---|---|---|---|---|
| C1 | Custom icon font for domain glyphs + library for generic UI | Lichess (4 custom fonts + `material_symbols_icons`) | N | — | **Yes** | **++** | M | Y | Y | Y | **YES — 8 custom glyphs, P1** |
| C2 | Hand-authored SVG icon set in a shared `_common/icons/` folder | Wonderous + `flutter_svg` | N | — | Equivalent | + | M | Y | Y | Y | **Alternative to C1 — icon font preferred (preserves `IconTheme`, no dep)** |
| C3 | Adopt a popular third-party icon library wholesale | shadcn_ui → `lucide_icons_flutter`; Phosphor | N | — | No | **−** | L | Y | Y | Y | **NO — Cap. 34 explicitly** |
| C4 | Variable-axis Material Symbols (weight/fill/grade/optical size) | Lichess `material_symbols_icons` 4.2960.0 | N | — | **Yes** for the long tail | + | L | Y | Y | Y | **P2 — after the custom 8 exist** |
| C5 | Filled/bold icons only, never thin outline | Cap. 12; corroborated by Lichess's heavy custom glyphs | Partial (8 of 37 are outline) | No | **Yes** | **+** | L | Y | Y | Y | **YES — P1, ~1 hour** |
| C6 | Texture as a first-class asset category | Wonderous `assets/images/_common/texture/` | N | — | Yes, mildly | + | L | Y | Y | Y | **P3 — Paper surfaces only, easy to overdo** |
| C7 | Emoji as entity representation (avatars, achievements) | — (Bufón's own choice) | **Y** | **No** | — | **−−** | — | — | Y | — | **REPLACE — P1, 12 brand faces** |

**C1 reasoning.** Lichess Mobile ships four custom icon fonts *alongside* two icon libraries. It does
not treat this as a choice — domain concepts get bespoke glyphs, generic UI verbs get library glyphs.
That is direct external validation of Cap. 12's hybrid position, from a Flutter app at far greater
scale and maturity. An icon font is preferred over SVG for Bufón because it keeps every existing
`Icon(...)`, `IconTheme`, size and colour call site working unchanged, and adds no package.

**C7 reasoning — the most consequential row in this matrix.** Bufón's avatars are OS emoji, so a
player's identity is Apple's clown on iOS and Google's clown on Android — two different faces for the
same person, and neither is Bufón's. `FIRMA VISUAL` item 2 names "a circular form substituted by a
face" as a permanent brand device and item 3 names closed-arc happy eyes as the *only* sanctioned
expression grammar. Emoji satisfy neither, and they appear at the two highest-emotion moments the
product has (your avatar, the winner's avatar) plus on every share card that leaves the app. Twelve
flat vector faces on the isotype grid is the highest identity return of any single asset investment
available.

---

## D. Composition and hierarchy

| # | Pattern | Source | Already? | Strong? | Better? | Identity | Cx | Fit | X-plat | Scales? | 1.1? |
|---|---|---|---|---|---|---|---|---|---|---|---|
| D1 | One dominant focal element, everything else compressed to thin edges | Wonderous; Cap. 3 law 4 | Partial (Home, Lobby, Winner pass; Game, Voting, Reveal fail) | No | **Yes** | **++** | M | Y | Y | Y | **YES — P1, the highest-leverage visual change** |
| D2 | Full-bleed hero imagery as the screen's ground | Wonderous | N | — | Yes, if art existed | + | M | Y | Y | Y | **P2 — depends on pack artwork existing** |
| D3 | Dashboard-style equal-weight card grid | Obtainium, AppFlowy, generic M3 | Partial (paywall, leaderboard) | No | No | **−** | L | N | Y | Y | **NO — actively avoid; Cap. 34 "dashboard"** |
| D4 | Sliver/collapsing headers | Lichess, Bufón's own season + public profile screens | Partial | Adequate | = | = | M | Y | Y | Y | **P3** |
| D5 | Bottom navigation as the app shell | generic M3 | N | — | Yes, for reachability | = | L | Y | Y | Y | **Consider — see reasoning** |
| D6 | Distinct backward vs. forward transition language | Cap. 23 | **N** | — | **Yes** | + | L | Y | Y | Y | **YES — P2, fade-only reverse variant** |

**D1 reasoning.** The three screens where a player spends ~70% of session time — Answering, Voting,
Reveal — all fail the hierarchy law. Answering shows the round progress **four separate times**
(`RoundIndicator` in the app bar, `GameProgressBar` segments, its caption, its percentage) before the
player reaches the question. Reveal shows the full scoreboard beside the spotlight, spoiling its own
suspense. The fix is mostly **deletion**, which makes it cheap, low-risk and immediately visible.
Wonderous is the proof that the law produces a distinctive product rather than an awkward one.

**D5 reasoning — a real tension worth stating.** Bufón needs a navigation shell (`UX_AUDIT.md` §1:
2,285 lines of progression UI are unreachable). Bottom navigation is the obvious, well-understood
Material solution — and `AppTheme` already themes `NavigationBar` in anticipation. But a persistent
bottom bar is also the single most "generic app" element that could be added, and it would sit under
the game loop where Cap. 3 wants nothing. **Recommendation: an app-bar-based shell on Home only**
(isotype + two icon actions), with `FinalWinnerScreen` gaining a progress CTA. That solves
reachability without putting a chrome bar under the game. Revisit bottom navigation only if the meta
layer grows past three destinations.

---

## E. States, errors, waits

| # | Pattern | Source | Already? | Strong? | Better? | Identity | Cx | Fit | X-plat | Scales? | 1.1? |
|---|---|---|---|---|---|---|---|---|---|---|---|
| E1 | Branded loading mark instead of a spinner | Cap. 24; Wonderous | **N** (11 bare spinners) | No | **Yes** | **+** | L | Y | Y | Y | **YES — P1** |
| E2 | Spinner library (`flutter_spinkit`) | Lichess | N | — | No | **−** | L | Y | Y | Y | **NO — a fancier generic spinner is still generic** |
| E3 | Illustrated empty states with one action | Cap. 25 | Partial (2 states, Material icons, no action) | No | **Yes** | + | M | Y | Y | Y | **YES — P1** |
| E4 | Never surface raw exception text | Cap. 26 | **N** (6 sites) | No | **Yes** | + | L | Y | Y | Y | **YES — P0** |
| E5 | Persistent non-blocking connectivity banner | LocalSend, Lichess (`connectivity_plus`) | **N** | — | **Yes** | = | L | Y | Y | Y | **YES — P1, uses the existing `ConnectionService`** |
| E6 | Fit-to-space dynamic text (`auto_size_text`) | Lichess | N | — | Marginally | = | L | Y | Y | Y | **NO — `maxLines` + ellipsis + `FittedBox` suffice** |
| E7 | In-app changelog rendered from a bundled markdown asset | LocalSend | N | — | Nice-to-have | = | L | Y | Y | Y | **P3** |

---

## F. Sharing and growth

| # | Pattern | Source | Already? | Strong? | Better? | Identity | Cx | Fit | X-plat | Scales? | 1.1? |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F1 | Off-screen `RepaintBoundary` → PNG → share sheet | Bufón's own; Wonderous ships `screenshot` | **Y** | Mechanically yes, visually no | — | **−** today | L | Y | Y | Y | **REDESIGN — P1** |
| F2 | Multiple share-card compositions per content type | Cap. 31 v1.1 | **N** (one template) | No | **Yes** | **++** | M | Y | Y | Y | **YES — P1: winner card + best-answer card** |
| F3 | Share CTA available to every participant, not only the winner | — | **N** (gated to winner) | No | **Yes** | + | L | Y | Y | Y | **YES — P1, one line** |
| F4 | QR code for joining | LocalSend `pretty_qr_code`, Lichess `qr_flutter` | N | — | Yes, for in-person joins | + | L | **Y — very** | Y | Y | **P2 — strong fit, see reasoning** |

**F2/F3 reasoning.** The share card is the only artefact that leaves Bufón and reaches non-players,
and today it is the least on-brand thing in the repo (casino gold/red, typed wordmark in a
runtime-fetched font, four elements competing for protagonist, `roundWins` mislabelled with a point
total). Cap. 31 v1.1 explicitly identifies the **best-answer-of-the-night** card as the most shareable
variant, because the joke *is* the content — and Bufón's room document already holds every answer.
Gating the existing card to the winner alone cuts its reach by up to 87% in an 8-player room, and the
person most likely to share a Bufón moment is often the friend who found it funniest, not the winner.

**F4 reasoning.** Bufón is played by people **in the same room**, which is exactly the case where a QR
code beats reading a 4-character code aloud across a table. Both reference apps that involve
in-person device pairing ship a QR package. It is a genuine, cheap usability win with a clean brand
fit (a QR rendered in Ink on Butter with the isotype in the centre eye is a strong visual). Deferred
to P2 only because reachability, errors and accessibility outrank it.

---

## G. Patterns to actively avoid

| # | Anti-pattern | Where it appears | Why it is wrong for Bufón |
|---|---|---|---|
| G1 | Dynamic OS colour | LocalSend, Lichess, Obtainium | Erases `FIRMA VISUAL` item 1 (Butter + Ink) |
| G2 | Stock Material 3 as the finished look | Obtainium, `material_3_demo` | Cap. 34; correct for a utility, fatal for an emotional product |
| G3 | Template/kit widget libraries | GetWidget, Flutter-UI-Kit | Cap. 34 "template look"; adds a 4th colour authority |
| G4 | Minimalist SaaS component systems | Forui, shadcn_ui | Restrained + neutral is the opposite of screen-printed + high-contrast |
| G5 | Stock Lottie animations from a library | Lottie ecosystem | Fastest possible route to looking like every other app |
| G6 | A game engine for a non-simulation product | Flame | Two rendering paradigms to replace a working 166-line painter |
| G7 | Fancier generic spinners | `flutter_spinkit` | Cap. 24 wants a *branded* wait, not a prettier neutral one |
| G8 | Plain Material fade/shared-axis transitions | `animations` pkg | Cap. 34 forbids fades without scale/spring |
| G9 | Mass-adopted icon sets (Lucide/Phosphor/Feather) | shadcn_ui, industry default | Cap. 34; differentiates nothing |
| G10 | Platform-adaptive widget branching | `platform_design` | A Bufón button should feel like Bufón on both platforms |
| G11 | Equal-weight card dashboards | Obtainium, AppFlowy, current paywall | Violates Cap. 3 law 4; reads corporate |

---

## H. Decision summary

**Adopt as dependencies (2):**

| Package | Priority | Justification | Evidence |
|---|---|---|---|
| `wakelock_plus` | P1 | Platform capability, not implementable in Dart; 90 s answering phase on a table | Lichess ships it for the same reason |
| `flutter_svg` | P1 *conditional* | Only if the isotype ships as SVG; skip if it becomes a `CustomPainter` | Wonderous + shadcn_ui both ship it |

**Adapt as Bufón's own code (6):**

1. `PhaseScope` — per-phase nested theming (from Forui's architecture).
2. `Arrive` helper — ~40 lines on existing `MotionDurations`/`MotionScale` (instead of
   `flutter_animate`).
3. Custom 8-glyph icon font + Material filled fallback (from Lichess's hybrid model).
4. 12 brand avatar faces replacing emoji (from `FIRMA VISUAL` items 2–3).
5. `Hero` shared-element transitions for room code and winning answer (idea from `local_hero`).
6. Tweened numeric counters (from game-feel craft; already mandated by Cap. 18).

**Reject (11):** `flutter_animate` (defer 1.2), `rive` (defer 1.2+), `lottie`, `flame`, `forui`,
`shadcn_ui`, `getwidget`, `animations`, `dynamic_color`/`dynamic_system_colors`,
`lucide_icons_flutter`, `flutter_spinkit`.

**Defer with a named trigger (3):**

| Item | Trigger to revisit |
|---|---|
| `material_symbols_icons` | After the custom 8 glyphs exist — then it becomes a weight-matched fallback rather than a generic swap |
| `rive` | Once the isotype + 12 avatars exist as vectors **and** someone owns Rive authoring |
| `sound_effect` + audio assets | 1.2, alongside a settings screen to mute it (Lichess's model) |

**INFERENCE.** The strongest conclusion from this matrix is how little Bufón needs from outside. Of
roughly 45 patterns evaluated, two justify a dependency, six justify writing Bufón's own version, and
eleven are actively harmful. The project's design specification is ahead of most of the references
it was asked to study; what it lacks is not ideas but wiring.
