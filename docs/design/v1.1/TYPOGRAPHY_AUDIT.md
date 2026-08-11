# TYPOGRAPHY AUDIT

> Verified against `lib/core/theme/app_typography.dart`, `pubspec.yaml`, and every text style call
> site in `lib/`.

---

## 1. Current state

**FACT.** All typography is centralised in `AppTypography` (169 lines). Two private factory
functions isolate face selection:

```
_display(...) -> GoogleFonts.plusJakartaSans(...)   // carries TODO(design-system)
_body(...)    -> GoogleFonts.plusJakartaSans(...)
```

**FACT.** Both currently resolve to the same face. The `_display` function carries an explicit
`TODO` recording that the Display face is undecided pending on-device comparison against the
logotype.

**FACT.** No fonts are bundled. `pubspec.yaml` has no `fonts:` block and `assets:` contains only
`questions.json`.

**FACT.** Centralisation is genuinely good: grep finds **zero** free-floating `TextStyle(fontSize:)`
in screen layout code. The only exceptions are (a) emoji sizing, where font family is irrelevant,
(b) `share_victory_card.dart`, which builds raw `TextStyle`s, and (c) `share_profile_card.dart`,
which builds `ui.TextStyle` with no family at all.

---

## 2. The scale

| Token | Size | Weight | Height | Tracking | Face | Uses |
|---|---|---|---|---|---|---|
| `caption` | 12 | normal | 1.4 | — | body | metadata, counters, hints |
| `body2` | 14 | normal | 1.5 | — | body | secondary copy |
| `body1` | 16 | normal | 1.5 | — | body | primary copy |
| `button` | 16 | w600 | 1.2 | +0.5 | body | button labels |
| `buttonLarge` | 18 | bold | 1.2 | +0.5 | body | (unused) |
| `h4` | 20 | w600 | 1.4 | — | body | section headers |
| `h3` | 24 | bold | 1.3 | — | display | screen/section titles |
| `h2` | 28 | bold | 1.3 | −0.3 | display | question text, prompts |
| `h1` | 32 | bold | 1.2 | −0.5 | display | winner titles |
| `display` | 48 | bold | 1.1 | −1.0 | display | "BUFÓN", room code, reveal name |
| `displayButter` | 48 | bold | 1.1 | −1.0 | display | **unused** |
| `displayGold` | 48 | bold | 1.1 | −1.0 | display | deprecated, unused |

**INFERENCE.** The scale is correct and needs no change. It follows a clean near-modular ratio,
restricts negative tracking to the three largest steps exactly as Cap. 6 requires, and is
consistently adopted. **Preserve it in full.**

**FACT.** `h4` (20pt) is produced by `_body()`, while `h3`/`h2`/`h1`/`display` use `_display()`.
**INFERENCE.** That is a defensible seam — 20pt is a UI header, not a brand moment — but it means
the moment a distinct Display face is chosen, there will be a visible face change between `h4` and
`h3` inside the same visual hierarchy. Section headers at `h4` and screen titles at `h3` appear
adjacent on Profile, Leaderboard and Round result. This should be an explicit decision, not a
surprise.

---

## 3. The runtime-fetch defect

**FACT.** `google_fonts` fetches font binaries over HTTP on first use and caches them to the device
filesystem. Its own documentation states that for released apps the recommended approach is to
settle on specific fonts and bundle them as assets, and that HTTP fetching can be disabled
entirely via configuration.

**FACT.** Bufón bundles nothing, disables nothing, and calls `GoogleFonts.plusJakartaSans` for
every one of its twelve text styles.

**INFERENCE — severity: high.** Consequences that are certain, not speculative:

1. **First launch offline renders the whole app in Roboto / SF Pro.** A party game is opened in
   bars, houses with saturated Wi-Fi, and on phones in airplane mode. The very first impression is
   the one most likely to be typographically wrong.
2. **A visible reflow on first launch online.** Text lays out in the fallback metric, then re-lays
   out when the font arrives. On the Home screen this is a 48pt headline visibly jumping.
3. **Share cards can be generated in the wrong face permanently.** `ShareVictoryCard` types
   "BUFÓN DE LA NOCHE" at 48pt; if it renders before the fetch completes, that PNG leaves the app
   and lives in a group chat forever with the brand's name in someone else's typeface.
   `ShareProfileCard` is worse — it passes no family at all, so it is *always* in the platform face.
4. **A network call at launch that App Check does not cover** and that will fail silently in
   restricted networks.
5. **A licensing/attribution obligation** that is currently unmet — the package documentation
   requires registering font licences with `LicenseRegistry`; no such registration exists in `lib/`.

**RECOMMENDATION — P0, and arguably the highest value-per-hour item in all of 1.1.**
Download the chosen faces, place them under `assets/fonts/`, declare them in `pubspec.yaml`, and
either keep `google_fonts` (it automatically prefers bundled matching assets) or drop the package
and reference the families directly. Set `GoogleFonts.config.allowRuntimeFetching = false` in
`main.dart` if the package is retained, so a missing asset fails loudly in development instead of
silently at a player's table.

**Weight discipline.** Only three weights are actually used (`normal` 400, `w600`, `bold` 700).
Bundling three weights of two families is 6 files, typically ~150–250 KB total for a Latin subset —
negligible against the current 2 MB of unused brand PNGs sitting in `public/`.

---

## 4. The Display face decision

**FACT.** `BUFON_DESIGN_SYSTEM.md` Cap. 6 records a v1.0 self-critique: Fredoka / Baloo 2 /
Poppins ExtraBold were rejected as "the de-facto uniform of any friendly rounded app". The revised
selection criteria are: (1) rounded terminals, (2) naturally tight tracking even in UI sizes,
(3) some irregularity of character that separates it from the geometric-perfect vocabulary of
Poppins/Futura/Century Gothic.

**FACT — from the logotype file itself.** The wordmark's letterforms are ultra-bold, very high
x-height, heavily rounded terminals, tight but not touching, with visibly *soft* joins (the B's
bowls, the U's shoulder) rather than pure circles-and-rectangles construction. The "O" is not
present as a letter at all — it is the face — which means **no typeface will ever have to match the
hardest character.** That is a meaningful practical freedom.

**INFERENCE.** The brief is: a heavy, warm, rounded, slightly editorial display face — closer to
Cooper Black / Recoleta / Obviously-Fat than to Poppins. Not a "stencil" face despite Cap. 6's
speculation; the mark has no stencil breaks.

**RECOMMENDATION — process, not a pick.** Do not choose the Display face from a screenshot. Set up
one screen (Home) with the wordmark PNG placed directly above `AppTypography.display` rendering the
word "BUFÓN", and compare candidates on-device at real size. Three concrete starting candidates that
satisfy all three criteria and have permissive licences suitable for bundling:

| Candidate | Why it fits | Risk |
|---|---|---|
| **Bricolage Grotesque** (variable, OFL) | Genuinely irregular, tight, contemporary, has real character; variable so one file covers weights | Not rounded — may read too editorial |
| **Fraunces** (variable, OFL) with `SOFT` + `WONK` axes high | The `SOFT` axis literally rounds terminals; `WONK` supplies the asked-for irregularity | Serif; would be a bold departure |
| **Nunito / Baloo 2** ExtraBold | Closest metric match to the lockup | Exactly the "generic friendly" trap Cap. 6 rejects |

**INFERENCE.** Honest assessment: the *safest* outcome is that the on-device test concludes the
lockup is distinctive enough on its own and the Display face only needs to not fight it — in which
case keeping Plus Jakarta Sans for Display and investing the effort in **using the wordmark asset
where the brand needs to speak** is a better trade than a font hunt. That should be an allowed
outcome of the test, not a failure of it.

**RECOMMENDATION.** Whatever is chosen, **bundle it first, choose second.** Bundling Plus Jakarta
Sans today removes the runtime-fetch defect immediately and costs nothing if the face later changes
— it is a one-line pubspec edit either way.

---

## 5. The colour-coupling defect

**FACT.** Every `AppTypography` getter hardcodes a colour:
`h1`–`h3`, `body1`, `display` → `AppColors.textPrimary` (white);
`body2` → `textSecondary`; `caption` → `textTertiary`; `h4` → `textPrimary`.

**FACT.** `app_theme.dart` compensates for the new themes with
`.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)` and documents why.

**INFERENCE.** That compensation only reaches text that flows through `Theme.of(context).textTheme`.
Screens call `AppTypography.h4` **directly**, so they get white and must `.copyWith(color:)` every
time. `lobby_screen.dart` does this at 19 call sites. The failure mode of forgetting one is
**invisible white text on Paper** — silent, easy to miss in review, and only visible on the exact
screens 1.1 is migrating.

**RECOMMENDATION — P0.** Pick one of two exits, and pick it before migrating any more screens:

- **(a)** Drop the hardcoded colours (`color: null`) and require every consumer to supply colour, or
  migrate consumers to `Theme.of(context).textTheme`. Correct, but a large mechanical diff and it
  breaks every unmigrated legacy screen at once.
- **(b) Preferred:** keep the getters as-is, but add the `PhaseScope` wrapper proposed in
  `DESIGN_SYSTEM_AUDIT.md` §5 and expose `context.text.h4` extension getters that resolve colour
  from the active register. New/migrated code uses the extension; legacy code keeps working
  untouched; the burndown is visible.

---

## 6. Tabular figures

**FACT.** `AppTypography.tabular(TextStyle)` applies `FontFeature.tabularFigures()`.

**FACT.** Applied in exactly two places: `TimerWidget`'s `${remainingSeconds}s` and the Lobby room
code.

**FACT.** Not applied to: player scores (`'${player.score} pts'`, round result), vote counts
(`'$votesReceived votos recibidos'`), the final winner's stat values (`h2`), XP totals, level
numbers, round counters, leaderboard positions, or season XP.

**INFERENCE.** Every one of those is a number that changes while the player is looking at it, or
sits in a vertically aligned column. Proportional digits make scoreboard columns ragged and make
live counters shimmer. Cap. 6 names this explicitly as a "premium feel" breaker.

**RECOMMENDATION — P1, near-zero cost.** Apply `tabular()` to every numeric read-out. This is a
mechanical change with a disproportionate perceived-quality return, and it is the kind of detail
that separates a shipped indie product from a polished one.

---

## 7. Text scaling

**FACT.** Zero references to `MediaQuery.textScaler`, `textScaleFactor`, or any accessibility text
sizing in `lib/`.

**FACT.** Fixed non-scaling sizes exist at: emoji 80pt (`profile_screen.dart:129`), 96pt
(`final_winner_screen.dart:211`), 100pt and 120pt (share cards), plus a 220 px and 180 px avatar
circle, a 200 px glow container, a 140 px season card, and a 40×40 timer arc.

**INFERENCE — concrete failure prediction.** `game_screen.dart` composes, in a **non-scrolling**
`Column`: `GameProgressBar` + `TimerWidget` + question card (`h2` 28pt, up to ~4 lines) + optional
transition banner + label + 3-line `TextField` with a character counter + send button + `Spacer` +
status container + optional host button. At iOS "Larger Text" 200% with the keyboard raised on a
5.4" device this cannot fit. `Spacer` inside an overflowing `Column` produces a negative-flex
overflow, i.e. the yellow-and-black stripes.

`voting_screen.dart` is safer (its list is `Expanded`) but its `GameCard` rows are single-`Row`,
single-line, and will clip long answers at large scales.

**RECOMMENDATION — P0 for `game_screen.dart`, P1 elsewhere.**
- Wrap `game_screen.dart`'s body in a `SingleChildScrollView` + `ConstrainedBox(minHeight:)` — the
  exact pattern `home_screen.dart` already uses (added in commit `7c9bd74` for the same class of
  bug). This is a proven in-repo fix.
- Clamp the global scaler in `MaterialApp.builder` to a sane band
  (`TextScaler.linear(clamp(scale, 1.0, 1.4))`) so the game loop stays playable while still
  honouring the user's preference direction — Cap. 28 asks for 150–200% support, and an honest
  compromise that never breaks the loop is better than an aspiration that overflows.
- Give `GameCard` `maxLines: 4` + ellipsis.

---

## 8. Voice and copy typography

**FACT.** `GameCopy` (46 lines) carries a genuinely distinctive Mexican-neutral voice with rotating
variants: "No presionamos, pero sí estamos juzgando.", "Alguien todavía está cocinando una
estupidez.", "Aquí se separa el chiste fino del crimen social.", "Empezar el desmadre",
"Soltar la siguiente", "Coronar al BUFÓN".

**FACT.** That voice covers: lobby waiting, answer progress, answer waiting, vote progress, vote
waiting, and four constants. It does **not** cover: any error message, any empty state, any loading
state, any button outside the two migrated screens, any paywall copy, or any snackbar.

**FACT.** Neutral-form copy still in the product: "Por favor ingresa tu nombre", "Error al crear
sala", "Escribe una respuesta", "Ya has votado", "No puedes votar por ti mismo",
"Error al procesar la compra: $e", "No hay datos"-class empty states, "Error al cargar".

**INFERENCE.** The voice is one of Bufón's strongest existing assets and it is applied to
roughly a third of the strings a player will read in a session. Errors and empty states are exactly
where a brand's warmth is most valuable and where Bufón is most generic — a player who hits an error
currently meets a completely different product.

**RECOMMENDATION — P1, low cost, high emotional return.** Extend `GameCopy` to own **every**
player-visible string: errors, empties, loaders, buttons, paywall. One file, one voice, one review.
Cap. 26's rule — never show a raw exception, never blame the player — becomes enforceable the
moment all copy lives in one place.

---

## 9. Typography summary

| Item | Verdict |
|---|---|
| Scale (12→48) | **Keep unchanged.** Correct and adopted. |
| Centralisation | **Keep.** Best-adopted part of the design system. |
| Font seam (`_display`/`_body`) | **Keep.** Clean, single-point-of-change. |
| Runtime fetching | **Fix now (P0).** Bundle the faces. |
| Display face identity | **Test on device (P1).** Allow "keep Plus Jakarta" as a valid outcome. |
| Hardcoded colours in getters | **Fix (P0).** Silent-invisible-text failure mode. |
| Tabular figures | **Extend to all numbers (P1).** Cheap, disproportionate return. |
| Text scaling | **Fix `game_screen.dart` (P0)**, clamp globally, then broaden. |
| Copy voice coverage | **Extend to 100% of strings (P1).** |
