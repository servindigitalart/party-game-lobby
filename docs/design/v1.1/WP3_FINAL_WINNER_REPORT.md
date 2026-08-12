# BUFÓN 1.1 — PHASE 2B / WP3
# Final Winner — ceremonial experience

**Date:** 2026-08-11
**Base commit:** `1d16a72 feat: add Bufon loading and placeholder primitives`
**State:** implemented, verified, **uncommitted**
**Scope:** WP3 only. No other screen was redesigned; no dependency, Firestore rule,
Cloud Function, navigation architecture or game mechanic was touched.

---

## 1. Current-state diagnosis

`final_winner_screen.dart` before WP3 was a **single-state screen**: everything —
title, avatar, winner name, stats, buttons — mounted at once, 300 ms after which
confetti started. There was no sequence, so there was nothing to build suspense
with. Concretely:

| Finding | Evidence |
|---|---|
| Hardcoded dark surface | `Color(0xFF111111)` ×2 |
| Retired `gold` throughout | title, avatar gradient, glow, stat icons, stat values, border |
| Casino red | `AppColors.primary` in the background gradient and the avatar fill |
| A three-stop gradient the system forbids | `_buildGradientBackground` hand-rolled red→black→gold |
| Round-tier confetti at the night's peak | `ConfettiWidget(isActive: …)` took the `round` default |
| No arrival haptic | `HapticService` called only on share and exit |
| Motion outside the system | `Curves.elasticOut` (overshoots past the documented `celebrationOvershoot` 1.15) + a permanently repeating `Curves.easeInOut` glow |
| Generic Material chrome | `OutlinedButton.icon` with `Colors.white` for the exit |
| No standings | the night ended on "one name and two numbers" |
| Winner leaked to assistive tech | the off-screen `ShareVictoryCard` carried the winner's name in the semantics tree from frame 0 |

19 legacy/hardcoded colour expressions in one file. The ceremonial layer the design
system wrote *for this screen* (`AppElevation.ceremonialGradient`), the register
written for it (`BufonPhase.nightWinner`), the confetti tier written for it
(`ConfettiTier.night`) and the type token written for it
(`AppTypography.displayButter`, documented as "ready for Fase 3F/3G when
Reveal/Winner screens migrate") **all had zero call sites**.

WP3 is therefore almost entirely an *adoption* exercise: the ceremony was already
specified, just never assembled.

---

## 2. Design decisions

**The register.** `BufonPhase.nightWinner` already exists, so no phase was added
or altered. It resolves to `isDark: true`, accent **Butter**, `onAccent` Ink,
`onSurface` Paper.

**The ceremonial gradient — a documented deviation.** The register's own comment
describes a "Butter→Graphite gradient", and `AppElevation.ceremonialGradient`
suggests `Butter → Graphite`. Implemented literally, a full-Butter top band forces
**Ink** foregrounds at the top of the screen and **Paper** foregrounds below it —
on a *scrolling* surface, so the same text would change legibility as the player
scrolls. WP3 uses `ceremonialGradient(graphite, graphiteShade)` for the page and
spends **Butter as the protagonist accent** (crest, name, stat values, winner row,
primary CTA). This keeps the ceremonial layer adopted, keeps every foreground on a
predictable dark ground, and matches the register's other statement that "its own
surface is dark and its content reads as Paper on top of it". Flagged rather than
silently reinterpreted — if the intent really is a Butter top band, it needs a
non-scrolling composition and a two-zone foreground rule.

**Standings without new data.** `round_result_screen.dart` already sorts
`room.players` by score to pick the winner. WP3 adds an optional
`standings` parameter and passes that same, already-in-memory list. **No new
query, no model change, no rule change** — which is why the standings section
exists without touching the backlog's avatar/progression blocker.

**Three states, not five.** The brief's five conceptual beats map onto the same
three-stage integer the round reveal already uses, so the two moments speak one
language rather than two:

| Stage | t | Beat | What appears |
|---|---|---|---|
| 0 | 0 ms | **anticipation** | crest arrives, "EL BUFÓN DE LA NOCHE", `...` |
| 1 | 900 ms | **winner reveal + celebration** | name opens through the keyhole, `celebration()` haptic, night confetti, stats Arrive |
| 2 | 1900 ms | **standings + next actions** | standings Arrive, CTAs Arrive |

**Avatar untouched.** `winnerAvatarId` is still `'default'` for every winner.
Solving that needs the denormalisation/rules decision, which WP3 is explicitly
forbidden from making. Only the avatar's *container* was restyled (Butter disc
with a Butter protagonist shadow, replacing the gold/red gradient disc).

---

## 3. Files changed

| File | Change |
|---|---|
| `lib/screens/final_winner_screen.dart` | Rewritten presentation: register, ceremonial gradient, 3-stage sequence, keyhole reveal, night confetti, arrival haptic, standings, CTA hierarchy, semantics. Share flow, telemetry and exit navigation **byte-for-byte preserved** |
| `lib/screens/round_result_screen.dart` | +1 argument (`standings: sortedPlayers`) and `List.from` → spread so the list carries its element type |
| `test/final_winner_test.dart` | **New** — 10 regression tests |

No other file was modified. No new token, component, dependency or motion
vocabulary was introduced.

---

## 4. Existing systems reused

| System | Use | Call sites before → after |
|---|---|---|
| `BufonPhase.nightWinner` | the register | **0 → 1** |
| `AppElevation.ceremonialGradient` | page ground | 0 reachable → **1** |
| `ConfettiTier.night` | celebration | **0 → 1** |
| `AppTypography.displayButter` | winner name | **0 → 1** |
| `KeyholeRevealTransition` | winner reveal | 1 (round result) → **2** |
| `HapticService.celebration()` | arrival | 1 → **2** |
| `MotionDurations` / `MotionCurves` / `MotionScale` | all motion | reused |
| `AppShapes` / `AppSpacing` / `AppElevation.protagonistShadow` | shape + focus | reused |
| `reduced_motion.dart` (`context.motion`, `context.reduceMotion`) | reduced paths | reused |
| `AnimatedPrimaryButton` | both CTAs | reused (replaces a raw `OutlinedButton`) |
| `AppTypography.tabular` | stat and score figures | reused |

**New code added to the design system: none.**

---

## 5. Motion

Every duration and curve is a token; `grep "Curves\."` in the file returns only a
comment. `MotionCurves.reveal` (added in the recovery continuation) and
`MotionDurations.revealStage` were already present, so **no motion token was
added**.

- **Crest arrival** — `Tween(MotionScale.arriveFrom → 1.0)` over
  `MotionDurations.revealStage` with `MotionCurves.release`. Replaces
  `Curves.elasticOut`, which the motion audit flagged for overshooting past the
  documented ceiling.
- **Winner reveal** — `KeyholeRevealTransition` driven by a controller on
  `MotionDurations.revealStage` with `MotionCurves.reveal`, backdrop
  `graphiteShade`, centre origin.
- **Late content** (stats, standings, actions) — one shared `_Arrive` helper:
  fade + 32 px rise over `MotionDurations.arrive` with `MotionCurves.settle`,
  identical to the round reveal's scoreboard entrance.
- **Removed:** the permanently repeating glow controller. The brief asks for a
  sequence rather than many simultaneous animations, and a forever-pulsing glow
  is exactly the "ambient element breathing" the design system forbids.

At most two things animate at once, and each stage hands off to the next.

---

## 6. Confetti

`ConfettiTier.night` — 90 particles over 4.5 s against the round winner's 50 over
3 s. Neither the count nor the duration was modified; no second confetti
implementation exists. It starts at stage 1, with the reveal, not on mount.

**Reduced motion** is handled by `ConfettiWidget` itself (it returns
`SizedBox.shrink()` when `context.reduceMotion`), so WP3 added no mechanism. The
render confirms the storm disappears while the ceremony survives intact.

---

## 7. Haptics

`HapticService.celebration()` (heavy → 100 ms → medium → 100 ms → light) already
existed and is now fired at the winner-arrival moment. **No dependency was added.**

It fires from the stage-1 `Timer` callback, not from `build`, so a rebuild cannot
repeat it — the same guard the round reveal uses. It is deliberately *not*
suppressed under reduced motion: a haptic is not motion, and for a player who
cannot see the confetti it is the celebration.

Tests never touch hardware: `HapticService` goes through `SystemChannels.platform`,
which is inert in the widget-test binding, so no abstraction or injection was
needed.

---

## 8. Share behaviour

**Unchanged, by instruction.** `_shareVictoryCard` — the `RepaintBoundary` capture,
temp-file write, `Share.shareXFiles` call, telemetry and failure copy — is
byte-for-byte what it was. The CTA was restyled only: it is now
`AnimatedPrimaryButton` in the register's accent, sharing the app's press physics
and semantics.

**The gate is preserved.** Sharing is still winner-only. Ungating it is a two-line
presentation change with no backend work (every viewer already holds the name,
votes and score the card renders, and the card is built from props), but it changes
*who can do what*, and §8 of the brief says to preserve current functionality and
leave expansion to the dedicated share work. The exact change is recorded in §14.

---

## 9. Accessibility

No regressions, and three improvements. Full WP4 was **not** attempted.

- **Winner identity is announced, and only once.** The name is a plain `Text`, so
  it reads normally; the avatar carries a single `'Avatar del Bufón de la noche'`
  label with `excludeSemantics: true`, which stops the emoji being read out as a
  character and stops it duplicating the name.
- **Two headers added** — "EL BUFÓN DE LA NOCHE" and "Cómo terminó la noche" are
  `Semantics(header: true)`, so a screen reader can navigate the ceremony.
- **Standings never depend on colour.** Each row announces
  `'Puesto N, <name>, <score> puntos'`; the winner's tint is redundant with the
  position number and the bolded score.
- **Stats announce as a phrase** (`'4 Votos'`) rather than a bare number next to a
  bare label.
- **A real leak was closed.** The off-screen `ShareVictoryCard` sits at
  `left: -10000` — invisible, but still in the widget *and semantics* trees. It
  carried the winner's name from frame 0, so a screen-reader user could reach the
  answer during anticipation. It is now mounted only from stage 1, a full stage
  before the share button can be pressed. This is the same class of defect as the
  scoreboard leak, found because WP3 gave the screen its first widget tests.
- **Buttons** keep meaningful labels ("Compartir victoria", "Salir") through
  `AnimatedPrimaryButton`'s existing semantics.

---

## 10. Responsive verification

Rendered and inspected at **390×844** and **360×800**; the test suite additionally
asserts layout at **360×800**. The ceremony is a `SingleChildScrollView`, so its
own content cannot overflow vertically; what a narrow phone threatens is
horizontal clipping, which was checked directly.

| Width | Result |
|---|---|
| 360×800 | No clipping. Crest, 48 pt name, stats, four standings rows and CTAs all render; the scroll view measures exactly 360 px. |
| 390×844 | Full ceremony visible without scrolling to reach the primary CTA. |
| 400×900 | Verified during earlier WP renders at this size; same composition with more headroom. |

Long names are handled by `Text` wrapping in the reveal and
`TextOverflow.ellipsis` in the standings rows. No device-specific layout was
introduced.

---

## 11. Tests

```
flutter analyze → No issues found! (5.8s)
flutter test    → +171: All tests passed!   (161 pre-existing + 10 new)
```

No existing test was removed, weakened or modified.

`test/final_winner_test.dart` covers all eight required cases:

1. the screen declares `BufonPhase.nightWinner`;
2. stage 0 exposes neither the winner nor the standings;
3. stage 1 reveals the name **through** `KeyholeRevealTransition`, with the mask's
   `progress` asserted above 0 — and the standings still absent at that moment;
4. `ConfettiTier.night` is the tier in use, and it is active;
5. standings and every player row appear only after the reveal;
6. reduced motion leaves the confetti mounted and "active" but painting nothing,
   while the winner and standings survive;
7. the exit CTA is always present once actions arrive, for winner and non-winner;
   the winner additionally gets the share CTA;
8. no raw exception text renders.

Plus a narrow-width layout test. The tests pump in *steps*, because a single large
pump fires a timer and paints the same frame, leaving controllers at elapsed zero.

---

## 12. Visual verification

Five stages plus a narrow-width variant were rendered to PNG through a temporary
harness (bundled fonts loaded) and inspected directly. **The harness and its output
were deleted afterwards** — no golden files were added.

| Render | Result |
|---|---|
| **A — pre-reveal** | Butter crest on the ceremonial gradient, "EL BUFÓN DE LA NOCHE", withheld `...`. No name, no standings. |
| **B — winner reveal** | The keyhole is unmistakable: "Sofía" is visibly clipped by the expanding circular mask against the `graphiteShade` backdrop. |
| **C — celebration** | Night confetti in the brand palette, visibly denser than the round tier, over the fully revealed name. |
| **D — standings** | Winner dominant; "Cómo terminó la noche" below with the winner's row tinted Butter and the rest muted; Butter primary CTA. |
| **E — reduced motion** | Identical composition, **zero particles**. Ceremony fully preserved. |
| **F — 360×800** | No clipping, no overflow, hierarchy intact. |

Against the acceptance standard: the winner reads as the protagonist immediately
(largest type, only accent-coloured name, crest above it); the reveal has real
suspense (900 ms of withheld identity, then an 800 ms mask); the celebration is
clearly stronger than the round result (90 vs 50 particles, 4.5 s vs 3 s, plus the
escalating haptic); no casino palette survives; no generic Material control
remains; typography is the bundled brand face throughout.

One bug was caught by this step and fixed: the ceremonial gradient initially
painted only behind the content, because the `Stack` shrink-wrapped its scrolling
child under the Scaffold's loose constraints. `fit: StackFit.expand` corrects it.

*(Emoji and Material icons render as placeholder glyphs in `flutter test` — the
harness loads the brand text font but not the platform emoji/icon fonts. A harness
artifact with no product meaning; it appeared in WP2's renders too.)*

---

## 13. Before → after

| Metric | Before | After |
|---|---|---|
| **Final Winner visual score** | **3.5 / 10** | **7.5 / 10** |
| Legacy/hardcoded colour expressions in the file | **19** | **0** |
| `ConfettiTier.night` call sites | 0 | **1** |
| `BufonPhase.nightWinner` call sites | 0 | **1** |
| `AppElevation.ceremonialGradient` reachable use | 0 | **1** |
| `AppTypography.displayButter` call sites | 0 | **1** |
| Raw `Curves.*` in the file | 2 | **0** |
| Arrival haptic | none | `celebration()` at reveal |
| Reveal stages | 1 (everything at once) | **3** |
| Final standings | none | present, gated behind the reveal |
| Share CTA | winner-only, raw `OutlinedButton` exit | winner-only (unchanged), both CTAs on `AnimatedPrimaryButton` |
| Widget tests covering this screen | **0** | **10** |

**Why 7.5 and not higher.** The screen is now on-system, sequenced and ceremonial,
but three things the blueprint asks of it are still absent and are not WP3's to
fix: every winner still wears the same default avatar (blocked on a security
decision); there is no night recap or "best answer of the night" (the blueprint
defers this to 1.2 as the highest-value content addition); and the share card the
screen produces is itself still un-migrated — and, as found below, clipped. An 8+
needs at least the avatar.

---

## 14. Remaining limitations

1. **Every winner wears the same avatar.** `winnerAvatarId` is hardcoded
   `'default'` at the call site because `firestore.rules` forbids a non-winner
   reading `/users/{uid}`. Unblocking needs a product decision (denormalise the
   equipped avatar onto the room's player document, or relax the rule). Explicitly
   out of scope.
2. **Share is still winner-only.** The ungate is two lines in `_buildActions` —
   drop the `if (widget.isCurrentUserWinner)` guard and pick the share text by
   that flag instead (a non-winner must not post "¡Soy el Bufón de la Noche!").
   No backend work. Left for the share work package.
3. **CTAs appear at 1.9 s.** A player cannot leave during the ceremony. This is
   deliberate — the round reveal withholds its scoreboard for 1.55 s on the same
   principle — but it is a real trade-off worth watching in playtest.
4. **The ceremonial gradient is the dark half of the pair** (see §2). If the
   design intent is a genuine Butter top band, the composition needs to stop
   scrolling and adopt a two-zone foreground rule.
5. **No `Hero` from the round reveal into the ceremony.** The blueprint suggests
   one; it is listed with the reveal's other deferred items.
6. **Counters still snap.** Votes and points appear at their final value rather
   than tweening (blueprint G8). A shared tween helper serves four screens and is
   better done once, elsewhere.

---

## 15. Discovered — documented, not fixed

**⚠ `ShareVictoryCard` renders clipped, and always has.**

`share_victory_card.dart` declares `Container(width: 600, height: 800)` while its
own content column needs roughly **1270 px**. It overflows its own frame by
**470 px** — independent of screen size, and true before WP3 touched anything.
Because the card is captured through a `RepaintBoundary` at exactly that declared
size, **every victory card ever shared has been missing its bottom ~470 px**, which
is where the stats and the brand footer sit.

This surfaced only now because WP3 gave the screen its first widget tests; no test
had ever mounted it. It is a defect in the share card's own layout, and §8 of the
brief forbids redesigning that file, so it is reported rather than fixed. The
tests consume this one known exception explicitly (`drain()`), so any *other*
exception still fails the suite.

**Belonging to other work packages:**

- `lib/presentation/widgets/share_victory_card.dart` is still fully legacy —
  `AppColors.background`/`backgroundCard`, a retired-`gold` radial glow, its own
  hand-rolled confetti painter. Share work package.
- Exiting the ceremony uses `pushAndRemoveAllFadeSlide` — the *forward* transition
  — where Capítulo 23 wants a retreat fade. `pushAndRemoveAllFade` exists and has
  zero call sites (audit SWA-6). Retreat-transition work package; explicitly
  excluded here.
- `SoundService.celebration()` fires on mount, one stage before the visual
  celebration it belongs to. Moving it to stage 1 would tighten the ceremony, but
  audio pacing was not in WP3's brief.

---

## 16. Explicitly NOT implemented

Profile, Leaderboard, Home, Lobby, Answering and Voting redesigns · WP4
accessibility architecture · global retreat transitions · the iconography system ·
progression/avatar backend or rules changes · the share-card architecture (and the
clipping defect above) · tweened counters · `Hero` into the ceremony · night recap
/ best-answer-of-the-night · any new dependency, animation package, phase, motion
token or component.

---

*No commit, no push, nothing staged.*
