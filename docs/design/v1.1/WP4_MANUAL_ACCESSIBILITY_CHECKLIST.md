# WP4 — Manual Accessibility Checklist (VoiceOver / TalkBack)

**Status: NOT TESTED.** No physical device was available during WP4. Nothing in this document has
been executed. Every row below is a claim to be *verified*, not a claim that has been verified.

**Do not mark a row PASS because the app compiles, because a `Semantics` node exists in the code, or
because an automated test asserts a label.** WP4 found a defect that every one of those signals
missed: `AnimatedPrimaryButton` and `GameCard` advertised `isButton` with **no tap action**, so every
primary button and every answer card was focusable and unpressable. Only activating a control with a
real screen reader proves a control works.

Companion documents: `WP4_ACCESSIBILITY_REPORT.md` (what was implemented and automatically verified),
`WP4_RECOVERY_REPORT.md` (how WP4 was recovered after the interruption).

---

## How to run this pass

**Android / TalkBack** — Settings → Accessibility → TalkBack. Navigation: swipe right/left to move
focus, **double-tap to activate**, swipe up-then-right for the reading-controls menu (use it to
navigate *by heading*).

**iOS / VoiceOver** — Settings → Accessibility → VoiceOver (triple-click the side button to toggle).
Navigation: swipe right/left to move focus, **double-tap to activate**, rotor (two-finger rotate) →
"Headings" to navigate by heading.

**Text scale**, to be run as a second pass over the same flows:
- Android: Settings → Display → Font size → maximum.
- iOS: Settings → Accessibility → Display & Text Size → Larger Text → maximum.
- The app clamps the effective scale to **1.4×** (`MediaQuery.withClampedTextScaling` in `main.dart`),
  so the maximum system setting is expected to render at 1.4×, not at the system value.

**Reduced motion**, third pass:
- Android: Settings → Accessibility → Remove animations.
- iOS: Settings → Accessibility → Motion → Reduce Motion.

Record results as **PASS / FAIL / N-A**, one column per platform. Leave **NOT TESTED** where a flow
was not reached. A FAIL must name the control and what was announced.

---

## Global checks — run once per platform

| # | Check | TalkBack | VoiceOver |
|---|---|---|---|
| G1 | Every focusable control can be **activated** by double-tap, not merely focused | NOT TESTED | NOT TESTED |
| G2 | No control is announced twice (label + child text both read) | NOT TESTED | NOT TESTED |
| G3 | No decorative emoji or glyph is read aloud as its Unicode name ("alarm clock", "clown face") | NOT TESTED | NOT TESTED |
| G4 | Heading navigation (rotor / reading controls) reaches a heading on every screen | NOT TESTED | NOT TESTED |
| G5 | Focus order follows visual order; no focus traps | NOT TESTED | NOT TESTED |
| G6 | At 1.4× no text is clipped, no CTA leaves the screen, no button loses its label | NOT TESTED | NOT TESTED |
| G7 | With reduced motion on, every screen still reaches its final state (nothing stuck mid-animation) | NOT TESTED | NOT TESTED |
| G8 | Nothing announces on a timer/frame loop (listen for 60 s on the answering screen) | NOT TESTED | NOT TESTED |
| G9 | Touch targets ≥ 48 dp on every control listed below | NOT TESTED | NOT TESTED |

---

## HOME

`lib/screens/home_screen.dart`

| # | Check | Expected | TalkBack | VoiceOver |
|---|---|---|---|---|
| H1 | Main heading | "BUFÓN" reachable via heading navigation | NOT TESTED | NOT TESTED |
| H2 | App-bar brand mark | announced once as an image ("Bufón"), not duplicated with H1 | NOT TESTED | NOT TESTED |
| H3 | Leaderboard icon button | announced with its tooltip; activates | NOT TESTED | NOT TESTED |
| H4 | Profile icon button | "Mi perfil"; activates | NOT TESTED | NOT TESTED |
| H5 | Name field | announced with its label "Tu nombre"; keyboard usable | NOT TESTED | NOT TESTED |
| H6 | Room-code field | "Código de sala"; character entry works | NOT TESTED | NOT TESTED |
| H7 | **"Crear Sala"** | announced as a button **and fires on double-tap** | NOT TESTED | NOT TESTED |
| H8 | **"Unirse a Sala"** | announced as a button **and fires on double-tap** | NOT TESTED | NOT TESTED |
| H9 | Disabled buttons while loading | announced as dimmed/disabled, do not fire | NOT TESTED | NOT TESTED |
| H10 | Season banner (if a season is live) | one node: name + countdown, no "alarm clock"; navigates on double-tap | NOT TESTED | NOT TESTED |
| H11 | 1.4× | whole screen scrolls; both CTAs reachable | NOT TESTED | NOT TESTED |

---

## LOBBY

`lib/screens/lobby_screen.dart`

| # | Check | Expected | TalkBack | VoiceOver |
|---|---|---|---|---|
| L1 | Heading | "Código de Sala" reachable as a heading | NOT TESTED | NOT TESTED |
| L2 | **Room code read as characters** | e.g. "A B C D 1 2", not "abcd12" as a word | NOT TESTED | NOT TESTED |
| L3 | Copy button, before copying | "Copiar código de sala" | NOT TESTED | NOT TESTED |
| L4 | Copy button, after copying | label changes to "Código copiado" | NOT TESTED | NOT TESTED |
| L5 | Copy action | double-tap actually copies | NOT TESTED | NOT TESTED |
| L6 | Player list | each player announced once; count is reachable | NOT TESTED | NOT TESTED |
| L7 | A player joining | is the change discoverable? (no live region here by design — confirm this is acceptable in practice) | NOT TESTED | NOT TESTED |
| L8 | Start button (host) | announced and fires | NOT TESTED | NOT TESTED |
| L9 | Non-host waiting state | conveyed as text, not colour alone | NOT TESTED | NOT TESTED |
| L10 | 1.4× | player list and CTA both reachable | NOT TESTED | NOT TESTED |

---

## GAME / ANSWERING

`lib/screens/game_screen.dart`

| # | Check | Expected | TalkBack | VoiceOver |
|---|---|---|---|---|
| A1 | Question is a heading | reachable via heading navigation | NOT TESTED | NOT TESTED |
| A2 | "Tu respuesta:" is a heading | reachable | NOT TESTED | NOT TESTED |
| A3 | Round indicator | "Ronda N de M" announced | NOT TESTED | NOT TESTED |
| A4 | Progress bar | percentage announced, not a bare bar | NOT TESTED | NOT TESTED |
| A5 | **Timer — announcement economy** | announces at **30 s, 10 s, 5 s only**. Listen for a full round: any per-second announcement is a FAIL | NOT TESTED | NOT TESTED |
| A6 | Timer urgency copy | readable on focus at any time | NOT TESTED | NOT TESTED |
| A7 | Answer text field | label announced; typing works with the reader on | NOT TESTED | NOT TESTED |
| A8 | Character counter | reachable; does not announce on every keystroke | NOT TESTED | NOT TESTED |
| A9 | Send button | announced and fires | NOT TESTED | NOT TESTED |
| A10 | Answer progress while pending | readable on focus, **silent** — must not announce per player | NOT TESTED | NOT TESTED |
| A11 | **"Todos respondieron"** | announced **once**, when the last answer lands | NOT TESTED | NOT TESTED |
| A12 | Host "Iniciar Votación" | announced and fires | NOT TESTED | NOT TESTED |
| A13 | 1.4× **with the keyboard raised** | body scrolls; send button reachable. This is the composition `TYPOGRAPHY_AUDIT` §7 called P0 | NOT TESTED | NOT TESTED |

---

## VOTING

`lib/screens/voting_screen.dart`

| # | Check | Expected | TalkBack | VoiceOver |
|---|---|---|---|---|
| V1 | Heading | "¿Cuál es la respuesta más chistosa?" reachable as a heading | NOT TESTED | NOT TESTED |
| V2 | Question restated | announced once, not duplicated with V1 | NOT TESTED | NOT TESTED |
| V3 | **Each answer card is a button and fires** | double-tap registers the vote. This is the control the app-wide tap-action defect broke | NOT TESTED | NOT TESTED |
| V4 | Own answer | "Tu respuesta: … No puedes votar por ti mismo." and **not** offered as a button | NOT TESTED | NOT TESTED |
| V5 | Selected answer | selected state announced, not colour alone | NOT TESTED | NOT TESTED |
| V6 | Cards after voting | announced as disabled | NOT TESTED | NOT TESTED |
| V7 | Prompt while un-voted | "Toca una respuesta para votar" readable, **never announced spontaneously** | NOT TESTED | NOT TESTED |
| V8 | **"¡Voto enviado!"** | announced **once**, when the vote registers | NOT TESTED | NOT TESTED |
| V9 | Vote progress bar | percentage reachable; does not announce per vote | NOT TESTED | NOT TESTED |
| V10 | 1.4× | ⚠️ **Known limitation** — see `WP4_ACCESSIBILITY_REPORT.md` §10.1. Record what actually happens on device; this is the measurement that decides how urgent the fix is | NOT TESTED | NOT TESTED |

---

## ROUND RESULT

`lib/screens/round_result_screen.dart`

| # | Check | Expected | TalkBack | VoiceOver |
|---|---|---|---|---|
| R1 | **Reveal is not spoiled** | before stage 2 (≈1.55 s) the winner's name must **not** be reachable or announced anywhere, including the scoreboard | NOT TESTED | NOT TESTED |
| R2 | **Winner announcement** | "&lt;name&gt;, N votos recibidos" announced **once**, as the reveal completes | NOT TESTED | NOT TESTED |
| R3 | Winning answer | readable after the keyhole opens | NOT TESTED | NOT TESTED |
| R4 | "Marcador de la noche" | reachable as a heading, only after stage 2 | NOT TESTED | NOT TESTED |
| R5 | Scoreboard rows | each row one node: position, name, score | NOT TESTED | NOT TESTED |
| R6 | Next-round button (host) | announced and fires | NOT TESTED | NOT TESTED |
| R7 | Non-host waiting state | conveyed as text | NOT TESTED | NOT TESTED |
| R8 | Reduced motion | reveal still completes and still announces R2 | NOT TESTED | NOT TESTED |
| R9 | Confetti | silent — must not appear in the semantics tree | NOT TESTED | NOT TESTED |
| R10 | 1.4× | ⚠️ **Known limitation** — see §10.1. Record device behaviour | NOT TESTED | NOT TESTED |

---

## FINAL WINNER

`lib/screens/final_winner_screen.dart` — WP3 territory, untouched by WP4. Verify it was not regressed.

| # | Check | Expected | TalkBack | VoiceOver |
|---|---|---|---|---|
| F1 | Winner name and score | announced coherently, not as fragments | NOT TESTED | NOT TESTED |
| F2 | Avatar | not double-announced with the name | NOT TESTED | NOT TESTED |
| F3 | Share CTA | announced and fires, for winners **and** non-winners | NOT TESTED | NOT TESTED |
| F4 | Home / play-again exits | announced and fire | NOT TESTED | NOT TESTED |
| F5 | Confetti and ceremonial motion | silent; reduced motion honoured | NOT TESTED | NOT TESTED |
| F6 | Share card export | still produces a correct PNG with the reader on | NOT TESTED | NOT TESTED |
| F7 | 1.4× | ⚠️ `ShareVictoryCard` has a known 470 px pre-existing overflow (WP3). Do not attribute it to WP4 | NOT TESTED | NOT TESTED |

---

## PROFILE

`lib/presentation/screens/profile_screen.dart`

| # | Check | Expected | TalkBack | VoiceOver |
|---|---|---|---|---|
| P1 | App-bar title | "Perfil" names the route | NOT TESTED | NOT TESTED |
| P2 | Share icon button | "Ver perfil público"; fires | NOT TESTED | NOT TESTED |
| P3 | Current avatar | "Avatar actual: &lt;name&gt;" — the **name**, never the emoji | NOT TESTED | NOT TESTED |
| P4 | XP progress bar | "Progreso al nivel N" + "X de Y XP" | NOT TESTED | NOT TESTED |
| P5 | Stat tiles | "Partidas: 12" as one node, not "12" then "Partidas" | NOT TESTED | NOT TESTED |
| P6 | Tabs | "Avatares" / "Logros" announced as tabs; switching works | NOT TESTED | NOT TESTED |
| P7 | **Avatar tile, unlocked** | name + rarity + "seleccionado" when selected; **fires** and changes the avatar | NOT TESTED | NOT TESTED |
| P8 | **Avatar tile, locked** | "…, bloqueado" + hint; fires and opens the requirements dialog | NOT TESTED | NOT TESTED |
| P9 | Rarity | announced as a word — the colour dot alone is a FAIL | NOT TESTED | NOT TESTED |
| P10 | Achievement, unlocked | "…, desbloqueado, …" and **not** offered as a button (it has no action) | NOT TESTED | NOT TESTED |
| P11 | Achievement, locked | "…, bloqueado, …" + hint; fires | NOT TESTED | NOT TESTED |
| P12 | 1.4× | ⚠️ **Highest-risk screen** — the only one with no scroll view; its header is a fixed `Column` above a `TabBarView`. Check the header does not squeeze the grid away | NOT TESTED | NOT TESTED |

---

## PUBLIC PROFILE

`lib/presentation/screens/profile_public_screen.dart`

| # | Check | Expected | TalkBack | VoiceOver |
|---|---|---|---|---|
| Q1 | Avatar | "Avatar: &lt;name&gt;" — WP4 repaired this label; it previously referenced a field that does not exist | NOT TESTED | NOT TESTED |
| Q2 | Level badge | "Nivel N" announced | NOT TESTED | NOT TESTED |
| Q3 | Equipped title | announced when present | NOT TESTED | NOT TESTED |
| Q4 | XP / stats grid | each stat coherent, not fragmented | NOT TESTED | NOT TESTED |
| Q5 | Rank sections | global and weekly ranks announced with their meaning | NOT TESTED | NOT TESTED |
| Q6 | Season badges | announced or correctly excluded as decorative | NOT TESTED | NOT TESTED |
| Q7 | **"Compartir perfil"** | one node, announced as a button, **fires** | NOT TESTED | NOT TESTED |
| Q8 | 1.4× | 140 px avatar circle and 64 pt emoji do not clip | NOT TESTED | NOT TESTED |

---

## LEADERBOARD

`lib/presentation/screens/leaderboard_screen.dart`

| # | Check | Expected | TalkBack | VoiceOver |
|---|---|---|---|---|
| B1 | App-bar title | "Rankings" names the route | NOT TESTED | NOT TESTED |
| B2 | Refresh icon button | "Actualizar rankings"; fires | NOT TESTED | NOT TESTED |
| B3 | Tabs | "Global" / "Esta Semana" announced; switching works | NOT TESTED | NOT TESTED |
| B4 | **Podium places** | "Puesto 1, &lt;name&gt;" as one node — not crown, emoji, name, medal, "#1" as five fragments | NOT TESTED | NOT TESTED |
| B5 | **Leaderboard rows** | "Puesto N, &lt;name&gt;[, tú], nivel N, X &lt;stat&gt;" as one node | NOT TESTED | NOT TESTED |
| B6 | Own row | includes "tú" — the highlight colour alone is a FAIL | NOT TESTED | NOT TESTED |
| B7 | Top-3 rank | conveyed by the spoken position, not by border colour alone | NOT TESTED | NOT TESTED |
| B8 | Empty state | "¡Sé el primero!" announced | NOT TESTED | NOT TESTED |
| B9 | 1.4× | podium (80 px wide, 100–120 px tall, single-line nicknames) does not clip badly | NOT TESTED | NOT TESTED |

---

## SEASON DETAILS

`lib/presentation/screens/season_details_screen.dart`

| # | Check | Expected | TalkBack | VoiceOver |
|---|---|---|---|---|
| S1 | Season name | reachable as a heading | NOT TESTED | NOT TESTED |
| S2 | Countdown | "Termina en N días" announced without the clock emoji | NOT TESTED | NOT TESTED |
| S3 | Urgency (≤ 7 days) | conveyed by words — the red tint alone is a FAIL | NOT TESTED | NOT TESTED |
| S4 | "Recompensas" | reachable as a heading | NOT TESTED | NOT TESTED |
| S5 | Reward cards | "Top 1: Título Legendario Permanente" as one node | NOT TESTED | NOT TESTED |
| S6 | "Clasificación Actual" | reachable as a heading | NOT TESTED | NOT TESTED |
| S7 | Season rows | "Puesto N, &lt;name&gt;[, tú][, primer lugar], X XP" as one node | NOT TESTED | NOT TESTED |
| S8 | Back navigation | reachable and fires | NOT TESTED | NOT TESTED |
| S9 | 1.4× | no clipping in the hero or the rows | NOT TESTED | NOT TESTED |

---

## PAYWALL

`lib/presentation/screens/paywall_screen.dart`

| # | Check | Expected | TalkBack | VoiceOver |
|---|---|---|---|---|
| W1 | Title | "¡Ya jugaron 3 partidas hoy!" reachable as a heading | NOT TESTED | NOT TESTED |
| W2 | Close button | "Cerrar"; **fires** — it is the only exit | NOT TESTED | NOT TESTED |
| W3 | **"Ver Anuncio" card** | "Ver Anuncio, Desbloquea 1 partida más" as one node; announced as a button; **fires** | NOT TESTED | NOT TESTED |
| W4 | **"Night Pass" card** | "Night Pass, 12 horas ilimitadas • $10 MXN" as one node; **fires** | NOT TESTED | NOT TESTED |
| W5 | Price | read intelligibly (check how "•" and "$10 MXN" are spoken) | NOT TESTED | NOT TESTED |
| W6 | Premium star | not read as a stray glyph | NOT TESTED | NOT TESTED |
| W7 | Loading state | cards announced as disabled; do not fire | NOT TESTED | NOT TESTED |
| W8 | Purchase/ad result | success and failure are announced, not only shown in a snackbar | NOT TESTED | NOT TESTED |
| W9 | 1.4× | both option cards fully readable; nothing clipped | NOT TESTED | NOT TESTED |

> W8 is a **known gap**: results surface through `ScaffoldMessenger` snackbars, which are announced
> by the platform but were not designed as accessible confirmations. Verify on device before deciding
> whether it needs work.

---

## TITLE SELECTOR DIALOG

`lib/presentation/dialogs/title_selector_dialog.dart`

| # | Check | Expected | TalkBack | VoiceOver |
|---|---|---|---|---|
| T1 | Dialog opening | focus moves into the dialog; content behind is not reachable | NOT TESTED | NOT TESTED |
| T2 | Dialog title | "Selecciona un Título" announced | NOT TESTED | NOT TESTED |
| T3 | Close button | "Cerrar"; fires | NOT TESTED | NOT TESTED |
| T4 | **Title options** | "&lt;name&gt;, &lt;rarity&gt;[, equipado]" as one node; announced as a button; **fires and equips** | NOT TESTED | NOT TESTED |
| T5 | "Sin título" option | "Sin título, no mostrar ningún título"; fires and unequips | NOT TESTED | NOT TESTED |
| T6 | Equipped state | announced as selected — the border and the "EQUIPADO" badge alone are a FAIL | NOT TESTED | NOT TESTED |
| T7 | Rarity | announced as a word, not conveyed by colour | NOT TESTED | NOT TESTED |
| T8 | Empty state | "No tienes títulos desbloqueados" announced | NOT TESTED | NOT TESTED |
| T9 | Failure path | the "No pudimos cambiar tu título" snackbar reaches the reader | NOT TESTED | NOT TESTED |
| T10 | Dismissal | focus returns sensibly to the profile screen | NOT TESTED | NOT TESTED |

---

## Sign-off

WP4's original acceptance criterion 4 — *"manual pass with TalkBack/VoiceOver through one full
round"* (`PHASE_2A_COMPLETION_AUDIT.md:552`) — is satisfied only when the HOME → LOBBY → ANSWERING →
VOTING → ROUND RESULT → FINAL WINNER path is completed end to end on **both** platforms with no
open FAIL.

| Field | Value |
|---|---|
| Tester | — |
| Date | — |
| Android device / OS / TalkBack version | — |
| iOS device / OS version | — |
| App commit | — |
| Full round completed with TalkBack | **NOT TESTED** |
| Full round completed with VoiceOver | **NOT TESTED** |
| Second pass at maximum text size | **NOT TESTED** |
| Third pass with reduced motion | **NOT TESTED** |
| Open FAILs | — |
| Verdict | **PENDING — no device available during WP4** |
