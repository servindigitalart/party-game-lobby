# UX AUDIT — flows, states, usability, accessibility

> Verified by tracing every `Navigator` call site, every `AsyncValue.when` branch, every
> user-visible string, and every interactive control in `bufon_flutter/lib/`.

---

## 1. The information architecture as it actually exists

**FACT.** The complete navigable graph:

```
main.dart
  └─ HomeScreen ────────────────────────────────────────────┐
       ├─ SeasonCountdownBanner (only if an active season   │
       │    exists in Firestore) → SeasonDetailsScreen      │
       ├─ "Crear Sala"  → LobbyScreen (pushReplacement)     │
       └─ "Unirse a Sala" → LobbyScreen (pushReplacement)   │
                                                            │
  LobbyScreen                                               │
       ├─ "Empezar el desmadre" → GameScreen                │
       ├─ (ROOM_LOCKED) → PaywallScreen → back              │
       └─ (disconnect) → HomeScreen ──────────────────────────┘
  GameScreen   → VotingScreen
  VotingScreen → RoundResultScreen
  RoundResultScreen → GameScreen (next round) | FinalWinnerScreen
  FinalWinnerScreen → HomeScreen

  ORPHANED (no inbound navigation):
    ProfileScreen ─→ ProfilePublicScreen ─→ TitleSelectorDialog
    LeaderboardScreen
```

**FACT.** `grep -rn "ProfileScreen"` and `grep -rn "LeaderboardScreen"` return no inbound references.
`ProfilePublicScreen` is reachable only from `ProfileScreen`; `TitleSelectorDialog` only from
`ProfilePublicScreen`. All four are therefore unreachable.

**FACT — scale of the orphaned surface:** `profile_screen.dart` 616 L + `profile_public_screen.dart`
772 L + `leaderboard_screen.dart` 556 L + `title_selector_dialog.dart` 341 L = **2,285 lines** of
finished UI, backed by `ProgressionController`, `TitleController`, `LeaderboardController`,
`SeasonController`, four models, four provider files, an `onMatchCompleted` Cloud Function awarding
XP/achievements/titles, and Firestore leaderboard collections.

**INFERENCE — this is the single most consequential UX finding in the audit.** Bufón has a complete
retention economy — XP, levels, 12 unlockable avatars, titles with rarity, achievements, weekly and
global leaderboards, seasons with history badges — and a player has **no way to see any of it**.
Every reward the backend grants after a match is invisible. The unchecked item
"Add navigation to ProfileScreen from HomeScreen" in `PHASE_3B_CHECKLIST.md` is the whole gap.

**RECOMMENDATION — P0, and the first thing 1.1 should do.** Bufón needs a **navigation shell**, not
more screens. The minimum viable version:

- Home gains an `AppBar` carrying the isotype (identity, per `ASSET_AUDIT.md` §Logo placement) plus
  two actions: profile and leaderboard.
- `FinalWinnerScreen` gains a "Ver mi progreso" CTA — the moment XP was just awarded is the single
  highest-intent moment to show a profile, and it costs one button.

Rationale, in Bufón's own terms: Cap. `THE BUFÓN FEELING` layer 3 is "pertenecer, no ganar" — the
memory is *the night with this group*, not the score. Titles, avatars and season badges are precisely
the artefacts of belonging. Shipping them unreachable is shipping the economy without the emotion.

---

## 2. Missing surfaces

**FACT.** Verified absent:

| Surface | Consequence |
|---|---|
| Onboarding / how-to-play | A first-time host must infer the rules. Nothing explains rounds, voting, or that you cannot vote for yourself (which is enforced with an error message *after* you try). |
| Settings | Sound and haptics cannot be muted. A 20–30 minute session buzzes per second under every timer with no escape. |
| Auth / account | `signInAnonymously()` fires silently inside create/join. Identity is a typed name per session. **INFERENCE:** anonymous auth plus per-session name entry means the XP/level/title economy accrues to a UID the player has no way to recognise, recover, or move to a new device. |
| Pack selection | 3 named packs exist in data; the `pack` field is parsed nowhere. |
| Network / offline indicator | `ConnectionService` heartbeats, but nothing tells the player they are disconnected. They learn by being ejected to Home with a `SnackBar`. |
| Room settings | `totalRounds` (5) and `roundDuration` (90 s) are model defaults with no UI. A host cannot shorten a game. |
| Rejoin / reconnect | No rejoin flow. Losing the app mid-round appears to be unrecoverable from the UI. |
| Exit / leave room | **No back affordance on Game, Voting, or Round result.** No `AppBar` back button, no leave button, no `WillPopScope`/`PopScope` handling. |

**INFERENCE — the exit gap is a usability defect, not a polish item.** A player mid-game has no
in-app way to leave a room. On Android the system back gesture will pop the route (there is no
`PopScope` guard), landing them on a screen the app's state machine does not expect; on iOS there is
no gesture at all because these are `pushReplacement`ed roots. Either way the heartbeat keeps running
and the room keeps counting them as present. This deserves a design decision in 1.1 even if the fix
is minimal (a confirm-and-leave in an app-bar overflow).

---

## 3. State coverage

### 3.1 Loading

**FACT.** 11 bare `Center(child: CircularProgressIndicator())` full-screen loaders, plus one coloured
`CircularProgressIndicator(color: Color(0xFFE94560))` in the paywall, plus the in-button spinner.

**FACT.** Cap. 24 forbids a naked spinner on an empty background and prescribes a
"breathing jester face" for full-screen waits.

**INFERENCE.** Joining a room is the app's most anxious wait — a player has just typed a code in
front of friends and is waiting to find out if it worked. Today that moment is a grey Material
spinner. It is also the moment most likely to be *slow*, because it is a network round trip. The
highest-anxiety wait has the least brand support.

### 3.2 Empty

**FACT.** Two empty states exist: `leaderboard_screen.dart:489` (`Icons.emoji_events_outlined` 64 px,
"¡Sé el primero!", body copy) and `title_selector_dialog.dart:148`
(`Icons.military_tech_outlined` 64 px, "No tienes títulos desbloqueados").

**FACT.** Missing empty states: no achievements unlocked, no avatars unlocked beyond the default,
no season history, no players in lobby (edge), lobby with 1–2 players (handled as copy, not a state).

**FACT.** Cap. 25 requires a brand illustration (never a loose Material icon), a voice-correct
headline, and at most one action. The leaderboard state has the right *shape* — headline + body — and
the wrong *assets*. It has no action.

### 3.3 Error

**FACT.** Two designed error states (`leaderboard_screen.dart:521` with a retry action,
`profile_public_screen.dart:641`). Five raw ones:

```
game_screen.dart:522        Text('Error: $error')  (+ a "Volver al Inicio" button)
voting_screen.dart:420      Scaffold(body: Center(child: Text('Error: $error')))
lobby_screen.dart:382       Scaffold(body: Center(child: Text('Error: $error')))
round_result_screen.dart:326 Scaffold(body: Center(child: Text('Error: $error')))
profile_screen.dart:108     Center(child: Text('Error: $error'))
```

**FACT.** Six raw-exception interpolations reach the player:

| String | File |
|---|---|
| `'Error al procesar la compra: $e'` | `paywall_screen.dart:159` |
| `'Error al mostrar el anuncio: $e'` | `paywall_screen.dart:106` |
| `'Error al enviar: $e'` | `game_screen.dart:157` |
| `'Error inesperado: $e'` | `voting_screen.dart:712` |
| `'Error al compartir: $e'` | `final_winner_screen.dart:375` |
| `'$fallback: $error'` | `home_screen.dart:141` |

**INFERENCE.** Cap. 26 is unambiguous: never show raw exception text; keep technical detail in
logs/analytics only. Four of the five raw `Error: $error` screens are on the game loop, meaning a
Firestore stream error during a live match replaces the game with a Dart exception string in front of
a room full of people. Three of those five offer **no recovery action at all** — the player is stuck
on an error screen with no button.

**FACT.** Six providers swallow errors into `SizedBox.shrink()` (`season_badges_section.dart:55`,
`season_countdown_banner.dart:102`, `leaderboard_screen.dart:335`, `profile_public_screen.dart:513`
and `:524`). The UI silently disappears.

**INFERENCE.** Two opposite failure modes coexist: the loop *over*-exposes errors (raw stack text)
while the meta screens *under*-expose them (silent disappearance). Neither tells the player something
useful. Cap. 26's tone rule — never punitive, never blaming — cannot be applied to a string that is
a `FirebaseException.toString()`.

### 3.4 Offline / network

**FACT.** No offline state exists in the UI. `ConnectionService` (272 L) runs a heartbeat;
`lobby_screen.dart` runs a 30 s cleanup timer that can eject the player home with
`'La sala se cerró por desconexión'` on an orange `SnackBar`.

**INFERENCE.** From the player's perspective a network problem manifests as *being thrown out of the
game*, with an explanation delivered 500 ms after the screen has already changed
(`Future.delayed(500)` then `showSnackBar`). There is no warning, no reconnect attempt surfaced, and
no "reconnecting…" state. For a realtime multiplayer party game this is the most likely bad
experience a player will actually have.

**RECOMMENDATION — P1.** A persistent, non-blocking connection banner (Coral, one line, appears on
loss, disappears on restore) on the four loop screens. This is cheap, uses an existing service, and
converts an inexplicable ejection into an explained one.

### 3.5 Permission

**FACT.** No permission requests exist in the Flutter layer.

**INFERENCE.** Correct today — the app needs no camera, mic, contacts or notifications. Worth noting
that `firebase_messaging` is *not* a dependency, so there is no push and therefore no notification
permission prompt. If 1.1 or later adds "your friends started a game" notifications, a permission
state becomes required.

---

## 4. Usability findings on the live loop

### 4.1 Home

**FACT.** Two text fields (name, code), one filled button (Crear Sala), one outlined button (Unirse).
Both actions require the name field; only "Unirse" requires the code.

**INFERENCE — friction.** The layout implies a single form, but the name field serves both actions
and the code field only serves the second. A player who types a code and presses "Crear Sala" creates
a new room and silently discards the code they just typed. There is no visual grouping (card, panel,
or divider label) to signal that these are two paths.

**FACT.** Errors are validated on submit only: "Por favor ingresa tu nombre",
"Por favor ingresa el código de sala" as `SnackBar`s.

**INFERENCE.** `SnackBar` for field validation is the wrong affordance — it appears at the bottom of
the screen, far from the field, and disappears. `InputDecoration.errorText` exists and is themed.

**FACT.** `TextField` for the room code has `textCapitalization: TextCapitalization.characters` but
no length limit, no formatter, and no monospace/tabular treatment. Room codes are compared with
`.trim()` only.

### 4.2 Lobby

**FACT.** The best-executed screen. Room code is a genuine protagonist (Butter tint hero card,
protagonist shadow, tabular 32pt with `letterSpacing: 4`), copy affordance present with
`selectionClick` haptic, player list, dynamic waiting copy from `GameCopy`, host-gated start button
whose label doubles as the reason it is disabled.

**FACT — Cap. 18 violation.** Copy-to-clipboard shows a silent `SnackBar` ("Código copiado").
Cap. 18 explicitly requires an icon `Swap` (copy → check) plus `selectionClick`, "nunca solo un
Snackbar silencioso." The haptic is there; the visual confirmation is not.

**FACT.** Player rows use a default `CircleAvatar` with the first letter of the name — the 12-avatar
system is not shown here. `PHASE_3B_CHECKLIST.md` lists "Add avatar emoji to LobbyScreen player list"
as unchecked.

**INFERENCE.** The lobby is where a player's chosen avatar would first pay off socially ("that's me")
and where it is absent. Same for `VotingScreen` and `FinalWinnerScreen`'s scoreboard, both also
listed unchecked.

**FACT.** No way to leave a lobby other than being disconnected.

### 4.3 Answering (`GameScreen`)

**FACT.** Composes, in a non-scrolling `Column`: `GameProgressBar`, `TimerWidget`, question card,
optional transition banner, "Tu respuesta:" label, 3-line `TextField` with a 100-char counter, send
button, `Spacer`, status container with a second progress bar and two lines of copy, optional host
button. Plus a `RoundIndicator` in the app-bar title.

**INFERENCE — hierarchy failure.** Five blocks compete: the question (h2, gradient, shadow) should
dominate but the timer sits above it with its own colour, pulse and copy, and the progress
information appears **four times** (`RoundIndicator` in the app bar, `GameProgressBar` segments,
`GameProgressBar` caption "Ronda N de M", `GameProgressBar` percentage) before the player even reads
the question. Cap. 3 law 4 requires one element at ≥2.5× the second largest; this screen has no
protagonist.

**INFERENCE — overflow risk (high).** `Spacer` inside a non-scrolling `Column` with a raised keyboard
and large text scale produces a negative-flex overflow. `home_screen.dart` already carries the fix
pattern (`LayoutBuilder` + `SingleChildScrollView` + `ConstrainedBox`, added in commit `7c9bd74` for
this exact class of bug).

**FACT.** After submitting, the answer field is replaced by a confirmation card showing the player's
own answer. Good — it answers "did it send?" without a modal, per Cap. 27.

**FACT.** No way to edit or retract an answer. `ALREADY_ANSWERED` is handled as an error, so the
constraint exists but is never communicated before the player tries.

### 4.4 Voting

**FACT.** Answers are shuffled deterministically with `Random(room.code.hashCode)` and players with
empty answers are removed. Self-voting is prevented by `canVote` (`player.id != userId`), so the
player's own card renders **disabled** rather than hidden.

**INFERENCE.** Rendering your own answer as a greyed-out card is arguably better than hiding it (you
can see your joke among the others) but it is not explained. A player sees one card they cannot tap
and gets no reason why. A one-line label ("Tu respuesta") would close the loop.

**FACT.** Confirmation is triple-signalled: a `SnackBar` ("¡Voto registrado!"), an inline banner, and
a colour change on the status container — plus the `GameCard` pulse and check icon. Cap. 27 says small
successes use silent inline confirmation, "nunca un modal ni un Snackbar de pantalla completa."

**INFERENCE.** Four simultaneous confirmations for one action is over-communication that dilutes the
one signal that matters (the card itself changing). It also puts a `SnackBar` on screen during the
2 s auto-advance window, so it can be interrupted mid-appearance by a navigation.

**FACT.** The question is re-shown in a small tinted italic echo below an `h2` prompt
("¿Cuál es la respuesta más chistosa?"), so the prompt is larger than the question it refers to.

### 4.5 Reveal (`RoundResultScreen`)

**FACT.** The staged reveal is well-built (see `MOTION_AUDIT.md` §1.7). The full night scoreboard is
co-visible from stage 0.

**INFERENCE — the suspense is self-defeating.** The `#1` row of the scoreboard reveals the winner
before the spotlight does. This is the clearest instance in the audit of one widget cancelling
another's design intent.

**FACT.** Round winner is computed by round votes; the scoreboard is sorted by cumulative score. Two
different orderings on one screen, unlabelled.

**FACT.** The host advances with a bare `ElevatedButton` ("Soltar la siguiente" / "Coronar al BUFÓN")
— the only primary action in the loop that is *not* an `AnimatedPrimaryButton`, so it has no press
physics, no haptic and no sound.

**FACT.** Non-hosts see a static card: "Siguiente ronda… El host trae la siguiente carta." No
indication of how long they will wait.

### 4.6 Final winner

**FACT.** Hardcoded `Color(0xFF111111)` background, three-stop gradient, `elasticOut` avatar
entrance, repeating glow, 3 s confetti, `🏆 BUFÓN DE LA NOCHE 🏆` in gold, avatar emoji at 96pt,
name at `h1`, two stats, share CTA, exit CTA.

**FACT — three defects:**
1. `round_result_screen.dart:162` passes `winnerAvatarId: 'default'` — **the winner's actual equipped
   avatar is never shown.** Every winner in the game wears the clown. Fase 3G's acceptance criterion
   is explicitly "el ganador se corona con su avatar equipado real."
2. The share CTA renders only `if (widget.isCurrentUserWinner)`. Fase 3G requires "un CTA de
   compartir visible para cualquier jugador, no solo el ganador."
3. No haptic fires on entry (see `MOTION_AUDIT.md` §1.8).

**INFERENCE.** Defect 2 is a growth bug, not just a UX one: the person most likely to share a Bufón
victory card is often *not* the winner — it is the friend who found it funny. Gating the app's only
viral surface to one of 3–8 players cuts its reach by up to 87%.

**FACT.** There is no scoreboard, no "best answer of the night", no per-player recap. The night ends
with one name and two numbers.

**INFERENCE.** Cap. `THE BUFÓN FEELING` says the memory is "what happened", not "who won".
The final screen currently delivers only "who won". The single highest-value *content* addition to
1.1 is a night recap that surfaces the funniest answers — which the room document already contains.

### 4.7 Paywall

**FACT.** Fully unmigrated: `Color(0xFF1A1A2E)` scaffold, `Color(0xFF16213E)` app bar,
`Color(0xFFE94560)` spinner, `Colors.green` success snackbar, `Colors.red.shade700` error snackbar,
21 raw colour expressions, zero design tokens.

**FACT.** Two raw-exception strings shown to the player during a **payment flow**.

**FACT.** Full-screen `CircularProgressIndicator` replaces the entire screen while loading.

**INFERENCE.** The paywall is the only screen where a player is asked for money and it is the least
polished screen in the app. Cap. 33 assigns it "Paper o Graphite, directo, sin fricción visual",
Cap. 4 explicitly forbids using an emotional colour for monetisation, and Cap. 34 forbids manufactured
urgency. The current screen is neither on-brand nor trustworthy-looking, and exposing a raw exception
at the point of purchase is the worst possible place for it.

---

## 5. Accessibility

**FACT.** Complete accessibility inventory of the app:

| Feature | Count |
|---|---|
| `tooltip` | **1** (`profile_screen.dart:53`) |
| `Semantics` widgets | **0** |
| `semanticLabel` arguments | **0** |
| `excludeSemantics` | **0** |
| `MediaQuery.textScaler` handling | **0** |
| `MediaQuery.disableAnimations` handling | **0** |
| `accessibleNavigation` handling | **0** |
| Focus management / `FocusTraversal` | **0** |

**FACT.** Cap. 28 requires: AA contrast on real pairs, no state communicated by colour alone, ≥48 dp
targets, `textScaler` support at 150–200%, and reduce-motion support.

**Assessment against each:**

| Cap. 28 requirement | Status | Evidence |
|---|---|---|
| AA contrast | **Partial fail** | `inkSoft` on Paper/butterTint ≈ 3.0:1 at 16pt body (fails AA normal). White on Mint in a selected `GameCard` ≈ 1.9:1. |
| No colour-only state | **Mostly pass** | `TimerWidget` uses colour+scale+copy+haptic ✅. `GameCard` selected uses colour+border+icon ✅. But: host chip is colour+label ✅; disabled `GameCard` is colour-only ❌; error snackbars are colour+text ✅. |
| ≥48 dp targets | **Pass by inheritance** | All icon-only controls use Material `IconButton` (48 dp default). `AnimatedPrimaryButton` is ~52 px by padding accident, not by constraint. |
| `textScaler` 150–200% | **Fail** | Zero handling; `game_screen.dart` will overflow (see §4.3). |
| Reduce motion | **Fail** | Zero handling; confetti, pulses, elastic bounce and glow all unconditional. |

**INFERENCE.** Two of five requirements fail outright and one partially. The two outright failures
(text scaling, reduce motion) are *system-level accessibility requests the app ignores* — a
qualitatively different category from "could be more accessible."

**INFERENCE — screen reader.** With zero `Semantics`, a VoiceOver/TalkBack user encounters:
`AnimatedPrimaryButton` as an unlabelled gesture region, `GameCard` as text with no selected state,
the timer as a decorative arc with a number, four icon-only controls with no labels (including the
only exit from the paywall and the title dialog), and no live-region announcement of round changes.
The game is not playable non-visually today. Given that Bufón is a *social, spoken* game where a
phone is passed around a table, non-visual play is not a fringe case.

**RECOMMENDATION — P0 accessibility package for 1.1 (small, bounded, high value):**

1. `Semantics(button: true, label:, enabled:)` on `AnimatedPrimaryButton`.
2. `Semantics(button: true, selected:, label:)` on `GameCard`.
3. `tooltip:` on all four icon-only controls.
4. `Semantics(liveRegion: true)` on `TimerWidget`, announcing at 30/10/5 s only.
5. `context.reduceMotion` helper + guards in six animation sites.
6. `game_screen.dart` scroll fix + global `textScaler` clamp to 1.4.
7. Add `inkMuted` (≈`#5C574C`) and repoint body-text uses of `inkSoft` to it.
8. Pass explicit `onSelectedColor: AppColors.ink` for `GameCard` selected text.

Items 1–4 and 7–8 are roughly 40 lines total. Items 5–6 are roughly 40 more. This is a day of work
that moves the app from "not usable with assistive technology" to "usable".

---

## 6. Interaction feedback coverage

**FACT.** Controls with no press feedback at all (no scale, no haptic, no sound):

| Control | File |
|---|---|
| `ElevatedButton` "Soltar la siguiente" / "Coronar al BUFÓN" | `round_result_screen.dart:292` |
| `ElevatedButton` "Volver al Inicio" (error state) | `game_screen.dart:524` |
| `ElevatedButton` "Reintentar" | `leaderboard_screen.dart:544` |
| `OutlinedButton.icon` "Salir" | `final_winner_screen.dart:285` (haptic on tap, no press scale) |
| Paywall offer cards | `paywall_screen.dart` |
| Leaderboard rows | `leaderboard_screen.dart` |
| Profile avatar/achievement tiles | `profile_screen.dart` |

**FACT.** Cap. 15: "Ningún tap 'muere en silencio': todo control interactivo tiene al menos un estado
de press visible."

**INFERENCE.** Material's default ink ripple provides *some* feedback on the `ElevatedButton`s, so
these are not literally silent — but they are silent in Bufón's language (no compression, no haptic,
no sound), which means the app's most important host action (advancing the round, 5× per game) feels
like a different product than its answer-submit button.

**RECOMMENDATION — P1.** Replace every `ElevatedButton`/`OutlinedButton` on the loop with
`AnimatedPrimaryButton` (which will need a `variant: secondary` for outlined cases). One component,
one feel.

---

## 7. Copy and tone

**FACT.** `GameCopy` covers ~6 dynamic strings + 4 constants, all excellent. Roughly two thirds of
player-visible strings live inline in screens and are tonally neutral.

**FACT.** Tonally off-brand strings currently shipping: "Por favor ingresa tu nombre",
"Error al crear sala", "Error al unirse", "Escribe una respuesta", "Ya has votado",
"No puedes votar por ti mismo", "Jugador no encontrado", "Error al cargar",
"No se pudo cargar el perfil", "No hay jugadores en la sala", "Sala no encontrada",
"Error al procesar la compra: $e".

**INFERENCE.** Cap. 2 states the voice problem is coverage, not quality — and that remains exactly
true. The fix is mechanical: move every string into `GameCopy`, review once.

---

## 8. UX maturity assessment

| Dimension | Score /10 | Basis |
|---|---|---|
| Core loop clarity | 7 | The 5-phase loop is legible and auto-advances sensibly |
| Information architecture | 2 | Whole meta layer unreachable; no shell; no exit from the loop |
| State coverage | 4 | 11 bare loaders, 2 empty states, 5 raw error screens, 6 silent failures |
| Error handling (player-facing) | 3 | 6 raw exception strings; 3 error screens with no recovery action |
| Feedback quality | 7 | Excellent where `AnimatedPrimaryButton`/`GameCard` are used; absent elsewhere |
| Onboarding | 0 | Does not exist |
| Accessibility | 2 | 1 tooltip; two system-level requests ignored |
| Copy voice coverage | 4 | Strong voice on ~1/3 of strings |
| Responsive resilience | 4 | Home fixed; `game_screen` at real overflow risk |
| **Overall** | **4** | |

---

## 9. UX priorities for 1.1

| # | Change | Priority | Why |
|---|---|---|---|
| 1 | Navigation shell (app bar + profile + leaderboard entry) | **P0** | Unlocks 2,285 lines and the entire retention economy |
| 2 | "Ver mi progreso" CTA on the winner screen | **P0** | Highest-intent moment; one button |
| 3 | Route all copy through `GameCopy`; eliminate 6 raw exception strings | **P0** | Cap. 26; trust, especially in the purchase flow |
| 4 | Accessibility package (§5 items 1–8) | **P0** | Two ignored system requests; ~1 day |
| 5 | `game_screen.dart` scroll fix + global textScaler clamp | **P0** | Real overflow risk on the most-used screen |
| 6 | Gate the scoreboard behind reveal stage 2 | **P1** | Restores the game's best moment |
| 7 | Real winner avatar + share CTA for all players | **P1** | Fixes a growth bug and a broken promise of the avatar system |
| 8 | `BufonPlaceholder` (empty/error/offline) + `BufonLoader` | **P1** | Replaces 11 spinners, 5 raw error screens, 2 icon empties |
| 9 | Connection banner on the four loop screens | **P1** | The most likely real bad experience |
| 10 | Avatars in lobby / voting / scoreboard | **P1** | Makes the avatar economy visible where it pays off socially |
| 11 | Pack selection on Home/Lobby | **P1** | Gives Home a protagonist; needs content expansion alongside |
| 12 | Leave-room affordance + `PopScope` guard | **P1** | Players are currently trapped mid-game |
| 13 | Reduce the four duplicate progress read-outs to one | **P1** | Directly serves the hierarchy law on the worst screen |
| 14 | Field-level validation instead of `SnackBar` on Home | P2 | Standard form practice; `errorText` already themed |
| 15 | Copy-code icon `Swap` to a check | P2 | Cap. 18, explicitly named |
| 16 | Label the player's own disabled voting card | P2 | Closes an unexplained interaction |
| 17 | Night recap ("best answer of the night") | P2 | Cap. `THE BUFÓN FEELING`; the memory is *what happened* |
| 18 | Onboarding / how-to-play | P2 | Needed before any acquisition push, not before beta |
| 19 | Settings screen (mute sound/haptics) | P2 | Prerequisite for the 1.2 audio work |
| 20 | Account recovery for anonymous progression | P3 | Real risk, but backend scope, not visual scope |
