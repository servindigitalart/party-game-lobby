# MOTION AUDIT

> Every animation, transition, haptic and sound cue in `bufon_flutter/lib/`, located and assessed.

---

## 1. Inventory

### 1.1 Motion token layer

**FACT.** `lib/core/theme/motion_tokens.dart` (133 lines) defines four classes:

| Class | Contents | Consumed? |
|---|---|---|
| `MotionDurations` | `press` 120 · `pulse` 500 · `arrive` 250 · `swap` 250 · `settle` 250 · `revealStage` 800 · `celebratory` 1600; per-component `pressButton` 100, `pressCard` 150, `settleButton` 200, `settleCard` 300; 8 tier-bound constants | `pressButton`, `pressCard`, `settleButton`, `settleCard`, `pulse`, `swap` ✅ — `press`, `arrive`, `revealStage`, `celebratory` ❌ |
| `MotionCurves` | `compress` (easeIn) · `release` (easeOutBack) · `pulse` (easeInOut) · `settle` (easeInOut) | all ✅ |
| `MotionScale` | `pressStrong` .95 · `pressSubtle` .97 · `pulseSelect` 1.03 · `pulseUrgent` 1.10 · `celebrationOvershoot` 1.15 · `arriveFrom` .88 | first four ✅ — last two ❌ |
| `MotionSprings` | `press`, `release` `SpringDescription`s | ❌ entirely unused |
| `MotionPhysics` | `breathingAmplitude` .008 · `breathingPeriod` 4 s · `overshootRatio` 1.05 | ❌ entirely unused |

**INFERENCE.** The token layer is complete and correct; roughly **half** of it has never executed.
The unused half is precisely the half that would deliver the design system's most distinctive
behaviours: `Arrive` entrances, breathing protagonists, celebration overshoot, spring-driven gestures.

### 1.2 Implicit animations

| Widget | Where | Duration | Curve |
|---|---|---|---|
| `AnimatedContainer` | `animated_primary_button.dart:126` | `settleButton` 200 ms | default (linear) |
| `AnimatedContainer` | `game_card.dart:481` | `settleCard` 300 ms | `MotionCurves.settle` |
| `AnimatedSwitcher` | `timer_widget.dart:1621` | `swap` 250 ms | default |
| `AnimatedSwitcher` ×2 | `round_result_screen.dart:378`, `:421` | 420 ms | `easeOut` in / `easeIn` out, with a fade+scale 0.97→1 transition builder |
| `AnimatedOpacity` | `voting_screen.dart:1031` | 250 ms | **`opacity: 1` constant — never animates** |
| `TweenAnimationBuilder` | `game_screen.dart:554` | 350 ms | `easeOut`, opacity + scale 0.96→1.0 |
| `TweenAnimationBuilder` | `voting_screen.dart:900` | `200 + index*50` ms | `easeOut`, opacity + translate 20→0 px (staggered list entrance) |
| `TweenAnimationBuilder` | `round_result_screen.dart:215` | 650 ms | `easeOutBack`, opacity + scale 0.92→1.0 |

**FACT — bug.** `voting_screen.dart:1031` wraps its banner in `AnimatedOpacity(opacity: 1, …)` with
no state change driving it. The value never changes, so the widget never animates. The banner appears
instantly, unlike its sibling on `game_screen.dart` which does animate.

**FACT.** `voting_screen.dart:900` is the only staggered list entrance in the app, and it is good —
it is effectively the `Arrive` pattern hand-rolled, with an index-based delay.

**FACT.** Five of the eight sites use raw `Duration(milliseconds: …)` literals (350, 420, 650,
200+index*50, 250) rather than `MotionDurations`. Three of those five (350, 420, 650) do not
correspond to any tier bound in `MotionDurations`: 350 falls between Estándar (200–300) and
Dramática (600–900); 420 likewise; 650 is inside Dramática.

**INFERENCE.** The 350 ms and 420 ms values are outside every documented tier. Cap. 17 requires new
animations to justify out-of-tier numbers explicitly in the PR. These predate the token file, so
they are legacy rather than violations — but they are exactly the drift the token file was created
to stop.

### 1.3 Explicit `AnimationController`s

| Controller | File | Duration | Behaviour |
|---|---|---|---|
| `_controller` | `animated_primary_button.dart` | 100 ms | forward on tap-down (`compress`), reverse on tap-up/cancel (`release`) |
| `_controller` | `game_card.dart` | 150 ms | dual-purpose: press scale **and** selection pulse share one controller |
| `_pulseController` | `timer_widget.dart` | 500 ms | forward-then-reverse once per second under 10 s |
| `_controller` | `confetti_widget.dart` | 1.8–3 s | drives 50-particle simulation via `setState` listener |
| `_scaleController` | `final_winner_screen.dart` | 800 ms | `Curves.elasticOut` avatar entrance |
| `_glowController` | `final_winner_screen.dart` | 1500 ms | `repeat(reverse: true)`, glow alpha 0.3↔0.6 |

**FACT.** Six controllers, all correctly disposed. No leaks found.

**FACT.** `final_winner_screen.dart` uses `Curves.elasticOut` and raw 800/1500 ms values — the only
place `elasticOut` appears. `MotionCurves` has no elastic entry.

**INFERENCE.** `elasticOut` on the winner avatar is *conceptually* right (it is the "biggest spring
in the system", Cap. `BRAND PHYSICS`) but it is unregulated: `MotionScale.celebrationOvershoot`
(1.15) exists specifically for this moment and is not used, and `elasticOut` overshoots considerably
more than 1.15. The intended and actual amplitudes differ.

### 1.4 Page transitions

**FACT.** `FadeSlidePageRoute` (`page_transitions.dart`, 60 L): 250 ms, `easeInOut`, fade + 5%
upward slide, with three `BuildContext` extensions (`pushFadeSlide`, `replaceFadeSlide`,
`pushAndRemoveAllFadeSlide`).

**FACT.** Call sites — 4 using `FadeSlidePageRoute`:

| From → To | Method |
|---|---|
| Game → Voting | `replaceFadeSlide` |
| Voting → Round result | `replaceFadeSlide` |
| Game → Home (disconnect) | `pushAndRemoveAllFadeSlide` |
| Final winner → Home | `pushAndRemoveAllFadeSlide` |

**FACT.** Call sites — 7 still using `MaterialPageRoute`:

| From → To | File:line |
|---|---|
| Home → Lobby (create) | `home_screen.dart:70` |
| Home → Lobby (join) | `home_screen.dart:107` |
| Lobby → Game | `lobby_screen.dart:139` |
| Lobby → Game (phase watcher) | `lobby_screen.dart:196` |
| Lobby → Paywall | `lobby_screen.dart:156` |
| Lobby → Home (disconnect) | `lobby_screen.dart:92` |
| Round result → Game (next round) | `round_result_screen.dart:138` |
| Round result → Final winner | `round_result_screen.dart:158` |
| Season banner → Season details | `season_countdown_banner.dart:826` |
| Profile → Public profile | `profile_screen.dart:59` |

**INFERENCE.** The forward spine of the game loop is **half migrated**. Home → Lobby → Game uses the
Material default; Game → Voting → Reveal uses `Arrive`; Reveal → Game (next round) and Reveal →
Winner revert to Material. A player experiences three different transition languages inside one
session, and the *most* ceremonial transition in the product (into the Bufón of the Night) is the
generic one. Cap. 23 explicitly requires extending `FadeSlidePageRoute` to all six loop screens.

**FACT.** Cap. 23 also specifies that *backward* transitions (leaving a room, returning Home) should
be a plain fade **without** slide, to feel distinct from advancing. Today all four
`pushAndRemoveAllFadeSlide` uses apply the same fade+slide as forward motion, and
`FadeSlidePageRoute` has no fade-only variant.

### 1.5 The signature transition

**FACT.** `lib/presentation/transitions/keyhole_reveal_transition.dart` (107 L) implements the
"mirilla" — an expanding circular `ClipPath` mask with a configurable origin, correct
farthest-corner radius maths, an optional backdrop, and correct `shouldReclip`. It is documented as
the implementation of `BRAND PHYSICS`'s "el reveal como mirilla".

**FACT.** Zero call sites. It has never rendered a frame in the product.

**INFERENCE.** This is the highest-value unrealised asset in the codebase. The design system names
it as Bufón's ownable gesture, traced directly to the keyhole cut in the isotype's hat bells and to
the game's core secret-keeping mechanic. The code is written, reviewed and committed. Wiring it into
`round_result_screen.dart` is a small, contained change with a large identity return.

### 1.6 Particles

**FACT.** `ConfettiWidget`: 50 particles, per-particle velocity/rotation/size, gravity implied by
`velocityY * progress * 150`, alpha fading to 50%, drawn as rounded rects in one `CustomPainter`,
`IgnorePointer`, restart on `isActive` false→true.

**FACT.** Two invocation sites:

| Site | `isActive` gate | Duration |
|---|---|---|
| `round_result_screen.dart:206` | `_revealStage >= 2` | **1800 ms** |
| `final_winner_screen.dart:107` | `_showConfetti` (set true 300 ms after mount) | 3000 ms (default) |

**FACT.** Cap. 22 specifies 50 particles / 3 s for the round winner and 80–100 particles / 4–5 s
with gradual fade-out for the night winner.

**INFERENCE.** Both are wrong in the same direction: the round winner is 40% shorter than specified
and the night winner is not scaled up at all. The result is that the biggest celebration in the game
is visually **identical in density** to the smallest one, which flattens exactly the intensity
ladder Cap. 32 exists to protect. Fixing it is two numbers and one new parameter.

**FACT.** The palette is the retired casino set (gold/red/cyan/coral/turquoise/salmon), not Cap. 21's
weighted `[Butter 40%, Mint/Sky/Lavender/Coral 15% each]`.

**FACT.** `_controller.addListener(() => setState(() {}))` rebuilds the subtree every frame. Because
the only child is the painter and `shouldRepaint => true`, output is correct; the rebuild is
redundant work.

### 1.7 The reveal sequence

**FACT.** `round_result_screen.dart` `initState` schedules two timers:

| t | Stage | Visual | Haptic | Sound |
|---|---|---|---|---|
| 0 ms | 0 | `_WinnerSpotlight` enters (650 ms, `easeOutBack`, scale 0.92→1). Shows `Icons.visibility`, "La respuesta ganadora fue…", `display` "…" | — | — |
| 750 ms | 1 | `AnimatedSwitcher` (420 ms) swaps "…" → the winning answer in quotes | `lightImpact` | `SoundService.reveal()` (OS alert) |
| 1550 ms | 2 | icon → `theater_comedy`; second `AnimatedSwitcher` swaps "preparando el señalamiento…" → winner name at `display` + vote count; confetti fires | `celebration()` (heavy→100 ms→medium→100 ms→light) | `SoundService.celebration()` (OS alert) |

**INFERENCE — this is genuinely well-designed.** The two-stage structure with an 800 ms gap creates
real anticipation, the haptic escalates, and the copy withholds the author until stage 2. It is the
best-choreographed moment in the product.

**FACT — the defect.** The full night scoreboard (`ListView` of all players, positions, votes,
points) renders from `_revealStage == 0`, alongside the spotlight. Cap. 35 Fase 3F's acceptance
criterion is explicit: "el scoreboard no es visible hasta que termina la etapa 2 del reveal."

**INFERENCE.** A player can read the winner's identity off the scoreboard's `#1` row **before** the
reveal reaches stage 2. The 800 ms of engineered suspense is therefore spoiled by the widget sitting
directly below it. This is the clearest example in the whole audit of a screen fighting its own
design intent, and it is a ~10-line fix.

**FACT.** Cap. `EMOTIONAL JOURNEY` stage 6 prescribes a 2–3 second *silence* — no movement, no
haptic, no sound — between voting and the reveal. Today `voting_screen.dart` auto-advances 2 s after
all votes land (`_scheduleAutoResults`), and the reveal screen's own stage-0 entrance animation fires
immediately on mount. There is no engineered silence; the 2 s window is filled by a navigation
transition and a 650 ms entrance.

### 1.8 Haptics

**FACT.** `HapticService` (53 L) provides `lightImpact`, `mediumImpact`, `heavyImpact`,
`selectionClick`, `vibrate`, `success` (→ medium), `error` (→ heavy), `warning` (→ light),
`celebration` (heavy → 100 ms → medium → 100 ms → light).

**FACT.** Current coverage against Cap. 19's mandated map:

| Moment | Spec | Actual | Status |
|---|---|---|---|
| Button / navigation tap | `lightImpact` | `AnimatedPrimaryButton` tap-down ✅; Home "Unirse" ✅ (explicit); `ElevatedButton`/`OutlinedButton` elsewhere ❌ | Partial |
| Answer selection | `mediumImpact` | `GameCard.didUpdateWidget` ✅ | Done |
| Answer/vote confirmed | `mediumImpact` | `_submitAnswer`, `_vote` ✅ | Done |
| Timer under 5 s, each second | `lightImpact`, escalating | 5× identical `lightImpact` ❌ | Violates economy rule |
| Reveal stage 1 | `lightImpact` | ✅ | Done |
| Reveal stage 2 / round winner | `celebration()` | ✅ | Done |
| Night winner | `celebration()` repeated per stat | fires once at `SoundService.celebration()`; **no haptic at all** on `FinalWinnerScreen` mount | Missing |
| Error / block | `heavyImpact` via `error()` | ✅ in game/voting; ❌ in paywall, home, share failure | Partial |
| Room created / joined | `mediumImpact` | ❌ — Home fires only the button's own `lightImpact` | Missing |
| Copy room code | `selectionClick` | ✅ `lobby_screen.dart` | Done |

**FACT — architectural.** Three widgets call `HapticFeedback.*` **directly**, bypassing
`HapticService`: `animated_primary_button.dart:92`, `game_card.dart:444`, `timer_widget.dart:1538`.

**INFERENCE.** Because the three highest-frequency haptic sources bypass the service, Cap. 19's
"economía de haptics" (collapse same-type impacts within 400 ms; escalate rather than repeat) is
**structurally unimplementable** — there is no single choke point to add throttling to. There is also
no way to add a user setting to disable haptics, which matters: 20–30 minutes of a party session with
per-second buzzing under every timer is a real annoyance, and there is no settings screen to turn it
off.

**RECOMMENDATION — P1.** Route all haptics through `HapticService`, add a 400 ms same-type
coalescing window and an `enabled` flag inside it. This is a small change to one file plus three
one-line call-site edits, and it unlocks both the economy rule and a future setting.

**FACT.** `FinalWinnerScreen` fires **no haptic** on entry — it calls `SoundService.celebration()`
only. The single most emotionally significant moment in the product is silent to the hand.

### 1.9 Sound

**FACT.** `SoundService` (29 L) maps five semantic method names onto **two** OS system sounds:

```
tap()            -> SystemSoundType.click
transition()     -> SystemSoundType.click
countdownPulse() -> SystemSoundType.click
reveal()         -> SystemSoundType.alert
celebration()    -> SystemSoundType.alert
```

**FACT.** There is no audio package, no audio asset, and no volume/mute control. `SystemSound.play`
respects the OS ringer state on iOS, so on a silenced phone — the normal state at a social table —
none of it plays.

**FACT.** Cap. 20 defines a full material sound language (cardstock / wood / rubber stamp / one
metal bell), a per-moment map, a scarcity rule (the bell sounds exactly twice per round), and
nominates the reveal bell as Bufón's ownable brand sound.

**INFERENCE.** The honest position — which the design doc itself states — is that Bufón has no sound
identity yet. `SystemSoundType.alert` for both the reveal *and* the celebration means the two most
important audio moments are the same OS beep. This is not a polish gap; it is an absence.

**INFERENCE — sequencing.** Sound requires: an audio package (`audioplayers` / `just_audio` /
`soundpool`), 7 composed audio files, a mixer/priority policy, a mute setting, and a settings screen
to hold it. That is a coherent chunk of work with a hard dependency on a screen that does not exist.
**It should be scoped as its own release (1.2), not squeezed into 1.1.** Attempting it inside a
visual release risks shipping placeholder sounds, which is worse than shipping none — Cap. 20's own
scarcity logic means a mediocre bell permanently devalues the brand sound.

**RECOMMENDATION for 1.1 (P2, cheap and honest).** Do three things and stop:
1. Stop calling `alert` for both reveal and celebration — differentiate or drop one.
2. Remove `countdownPulse()`'s per-second click (it is a click 5× in 5 s on top of 5 identical
   haptics — the exact double-violation of the economy rule).
3. Add the mute/settings surface so 1.2's audio work has somewhere to land.

### 1.10 Reduce motion

**FACT.** Zero references to `MediaQuery.disableAnimations`, `accessibleNavigation`, or
`MediaQuery.of(context).platformBrightness`-style accessibility branching anywhere in `lib/`.

**FACT.** Cap. 28 requires every `Pulse`/`Reveal` to have a reduced version (simple cross-fade) when
the system requests it.

**INFERENCE.** Bufón currently runs, unconditionally: a 1.10 timer pulse every second for 10 seconds,
a 50-particle confetti storm, an `elasticOut` avatar bounce, a repeating glow, and a staggered list
entrance. For a user with vestibular sensitivity or motion sickness this is not a preference issue —
"Reduce Motion" is a system-level accessibility request the app ignores. This is the most clear-cut
accessibility failure in the audit.

**RECOMMENDATION — P0.** One helper (`context.reduceMotion`) plus guards in six places:
`ConfettiWidget` (return `SizedBox.shrink()`), `TimerWidget` (colour-only), `GameCard`/
`AnimatedPrimaryButton` (skip scale, keep colour + haptic), `FinalWinnerScreen` (static avatar),
`FadeSlidePageRoute` (fade only, no slide). Roughly 30 lines total.

---

## 2. Motion maturity assessment

| Aspect | Score /10 | Evidence |
|---|---|---|
| Token layer quality | 9 | Complete, documented, tier-bounded, brand-derived |
| Token adoption | 5 | ~half unused; 5 raw duration literals remain, 3 out-of-tier |
| Microinteraction quality | 8 | Real asymmetric compress/release physics on button and card |
| Game-feedback quality | 7 | Two-stage reveal is excellent; spoiled by a co-visible scoreboard |
| Navigation coherence | 4 | 4 `Arrive` vs. 7 Material; no distinct backward transition |
| Celebration ladder | 4 | Round and night celebrations are visually identical density |
| Signature gesture | 0 | Keyhole transition built, never used |
| Haptic coverage | 6 | Good vocabulary, 4 gaps, economy rule unimplementable, no mute |
| Sound | 2 | Two OS beeps for five semantic events; honest absence |
| Reduce motion | 0 | Not implemented at all |
| **Overall** | **5** | |

---

## 3. Proposed 1.1 motion work, ranked by return per unit of effort

| # | Change | Effort | Impact | Priority |
|---|---|---|---|---|
| 1 | Wire `KeyholeRevealTransition` into the reveal | Low | **Very high** — this is the brand's gesture | **P1** |
| 2 | Gate the scoreboard behind `_revealStage >= 2` | Very low | **Very high** — restores 800 ms of engineered suspense | **P1** |
| 3 | Recolour confetti to the Cap. 21 palette | Very low | High | **P1** |
| 4 | Scale night confetti to 80–100 / 4–5 s | Very low | High — restores the intensity ladder | **P1** |
| 5 | Implement reduce-motion guards | Low | High (accessibility) | **P0** |
| 6 | Migrate the 7 remaining `MaterialPageRoute`s to `Arrive` | Low | High — one transition language | **P1** |
| 7 | Add a fade-only backward variant to `FadeSlidePageRoute` | Very low | Medium | P2 |
| 8 | Route haptics through `HapticService`; add coalescing + `enabled` | Low | Medium-high | **P1** |
| 9 | Add `celebration()` haptic to `FinalWinnerScreen` mount | Very low | Medium | **P1** |
| 10 | Fix the dead `AnimatedOpacity` in the voting banner | Very low | Low-medium | P2 |
| 11 | Replace 5 raw duration literals with tokens | Low | Low (hygiene, prevents drift) | P2 |
| 12 | Adopt `Arrive` (`arriveFrom` 0.88 + fade) for banners, cards, list items | Medium | Medium-high | P2 |
| 13 | Implement breathing on protagonist elements (`MotionPhysics`) | Medium | Medium — Cap. `BRAND PHYSICS` "nada está quieto" | P2 |
| 14 | Engineer the 2–3 s pre-reveal silence | Medium (touches auto-advance timing) | High conceptually, **multiplayer-sync risk** | P3 |
| 15 | Full audio identity | High | High | **Defer to 1.2** |

**Note on #14.** `AGENTS.md` states "Room consistency has priority over animations and visual
polish." The pre-reveal silence requires changing `_scheduleAutoResults`' 2 s window, which is a
synchronisation-adjacent timer. It should be treated as gameplay work with telemetry, not as motion
polish, and it is correctly the lowest-priority motion item despite its conceptual importance.

---

## 4. Motion behaviours that must be preserved

1. **Asymmetric compress/release** on every touch. It is implemented, it is correct, and it is the
   reason Bufón's buttons feel different from stock Flutter.
2. **The two-stage reveal timing** (750 ms / 1550 ms with escalating haptic). Fix what surrounds it;
   do not retime it.
3. **The `GameCard` select pulse + `mediumImpact` pairing.** Cap. 18's two-simultaneous-signals rule,
   already satisfied.
4. **`TimerWidget`'s multi-channel urgency** (colour + scale + copy swap + haptic). The only
   component that already satisfies Cap. 28's no-single-channel rule.
5. **The staggered voting-list entrance.** It is `Arrive` before `Arrive` existed; formalise it,
   don't remove it.
6. **The `ConfettiWidget` engine.** Recolour and parameterise; do not replace with a package.
