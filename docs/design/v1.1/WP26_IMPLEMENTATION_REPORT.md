# BUFÓN v1.1 — WP26 · BLUEPRINT COMPLETION SWEEP

## IMPLEMENTATION REPORT

> ## ARCHIVAL HEADER
>
> This is the **WP26 implementation report**, generated from this execution — the **last code package** in the v1.1 roadmap. Every command, count and hash was run in the session that produced the commit. **No finding was omitted**, including the eight sub-items deliberately not implemented (§F).

> | Field | Value |
> |---|---|
> | **Document date** | 2026-09-01 |
> | **Package** | **WP26 — Blueprint completion sweep** — `MASTER_V1.1_RECONCILIATION.md:1046-1058` |
> | **Closed** | **R-24** · **R-26** · **R-32** · **R-34** *(routes)* · **R-38** |
> | **Already complete at HEAD** | **R-35** — a sweep finding, not work |
> | **Deferred with evidence** | R-29 · R-30 · R-31 · R-33 · R-34 *(Hero)* · R-36 · R-39 · R-40 |
> | **HEAD before** | `1bfe28290ca7295168bd9e49c02315101286a85c` (WP25) |
> | **HEAD after** | one commit ahead; **`HEAD^ == 1bfe282…`** |
> | **Commits** | exactly **1** · **not pushed** |
> | **Files** | 9 modified · 1 added · **5 deleted** |
> | **Tests** | 356 → **357** (−7 orphaned, +8 new) |
> | **Goldens** | 10 · **all byte-identical** — WP26's primary gate |
> | **`pubspec` / rules / functions** | **unchanged** |

**Evidence discipline.** **[VERIFIED]** = demonstrated by a command run in this session or by a test that passed. **[INFERRED]** = derived from verified evidence. **[UNVERIFIABLE]** = not establishable in this environment.

---

## A · VERDICT

> ## **PARTIAL — five items closed, one found already complete, eight deferred with per-item evidence.**

**The deferral principle, stated once and applied consistently:** WP26's own **Verification** line is *"Goldens green or deliberately re-baselined · full suite green · `flutter analyze` clean · **a manual pass on Home, Lobby and Paywall**."* WP21 established, with evidence, that **no device exists in this environment**. Items whose correctness can only be established by that manual pass — recolours, icon choices, new composition — **cannot be verified here**, and shipping unverifiable visual changes blind, in the final package before submission, is worse than deferring them with a written reason.

Everything WP26 could establish from static evidence and automated tests is implemented. Nothing was implemented because it "looked unfinished" (stop condition 21), and nothing from a later or blocked package was absorbed.

---

## B · BASELINE

```
HEAD          1bfe28290ca7295168bd9e49c02315101286a85c   (WP25)
HEAD^         196412c8fc673f44da285bb871cae5e964b2827b   (WP23)
HEAD^^        532d3963ac77debe021d6092b618f15e583a2f80   (WP22)
HEAD^^^       6f00a2449c7f27c1976ad63604f5f9d9fae6f3b8   (WP20)
HEAD^^^^      9f7d98ee0f7a7b86966d19c443cbcc1e54376653   (WP19)
branch        main
origin/main   2c8337e7d790c79803b7b93f3b0329318cbc2e93   (5 behind)
stash         1 entry — "old react work before syncing with M4", untouched
tests         356 passing  ← measured before any edit
analyzer      clean
working tree  no tracked modifications, nothing staged; 14 untracked protected docs
```

The expected chain `… → 9f7d98e → 6f00a24 → 532d396 → 196412c → 1bfe282` was confirmed exactly. Golden hashes recorded before any edit; re-verified in §L.

---

## C · FULL BLUEPRINT SWEEP

Every item the reconciliation lists in WP26's scope, plus every WP26-adjacent item that could have been mistaken for one. **Classified before any edit.**

| ID | Blueprint | State at HEAD | Class | Owner | Evidence · reason if not WP26 |
|---|---|---|---|---|---|
| **R-24** | audit A M-1 | `NSAllowsArbitraryLoads` present, `Info.plist:31-35` | **C** | WP26 | ✅ Implemented — §E.1 |
| **R-26** | audit A L-2, M-3 | 4 files, zero reachable callers | **C** | WP26 | ✅ Implemented — §E.2 |
| **R-29** | BP X9 | `grep -c wakelock pubspec.yaml` → **0** | **E** | WP26, deferred | **[VERIFIED]** not in the pub cache → needs a network `pub get`; behaviour is screen-wake, **device-only** |
| **R-30** | BP P6, Part IV §7 | Paywall on **raw hex literals** (20 colour expressions), not even `AppColors` | **C→deferred** | WP26, deferred | Its own verification is *"a manual pass on … Paywall"*. A full recolour of the money screen, unseen |
| **R-31** | BP F4 | 0 `@Deprecated` in `app_colors.dart` | **I** | **Conflict — §F.3** | Annotating is *designed* to make `flutter analyze` noisy (*"let `flutter analyze` produce a burndown"*) and WP26's Verification requires *"`flutter analyze` clean"*. **186+ call sites** |
| **R-32** | BP F7 | `season.dart:9` raw `int themeColor`, painted directly | **C** | WP26 | ✅ Implemented — §E.3 |
| **R-33** | BP I7, I8 | 5 outline icons + 3 mis-picks | **I** | WP26, deferred | The reconciliation names the *problems*, never the *replacements*. Picking icons is design authority. 3 of 7 are inside the deferred paywall; 1 is golden-covered and deferred by its own source comment |
| **R-34** *(routes)* | BP X2 | 3 raw `MaterialPageRoute` | **C** | WP26 | ✅ Implemented — §E.4 |
| **R-34** *(Hero)* | BP X3, X4 | 0 `Hero(` | **C→deferred** | WP26, deferred | Cross-route `Hero` interacting with the custom transition language is a motion judgement verifiable only by watching it |
| **R-35** | BP X6 | **`animated_primary_button.dart:193` and `timer_widget.dart:130` both call `context.motion(full:…, reduced: 1.0)`** | **A** | — | **ALREADY COMPLETE.** §C.1 |
| **R-36** | BP X10, P1, Q8 | 5 plain buttons (profile screens), 1 spinner, no `phase_banner.dart` | **C→deferred** | WP26, deferred | `PhaseBanner` is a new primitive collapsing two banners — composition. The buttons are on the five screens still on `BufonPhase.legacy`, whose *"feedback moves with the package that recolours them"* |
| **R-38** | BP P8, P9 | no `errorText`; own-card label only inside a `Semantics` string | **C** | WP26 | ✅ Implemented — §E.5 |
| **R-39** | BP P10, P12 | 15 raw `Duration(milliseconds:)`; both phase enums coexist | **C→deferred** | WP26, deferred | The 15 values have no matching tokens; naming new tiers is design authority, and BP line 1041 forbids unifying the two press values. The enum rename is a broad rename the brief forbids |
| **R-40** | BP F8, I10 | no `AppOpacity`/`AppIconSize`; `ShareProfileCard` on its own pipeline | **C→deferred** | WP26, deferred | Token scales with no adopters are speculative; the card rebuild is composition, unverifiable without rendering |
| **R-27** | BP G5 | `winnerAvatarId: 'default'` | **D** | **PD-10** | Explicitly excluded by WP26; decision-blocked |
| **R-28** | BP I5 | headline still typed `'BUFÓN'` | **D** | **PD-11** | Explicitly excluded by WP26; decision-blocked |
| **R-41** | BP G13 / K-3 | `RoundIndicator` retained | **F** | ratification | WP26 excludes it: *"ratification, not work"*. *"Do not 'fix' it silently in either direction."* |
| **R-46** | BP I6, I9, I11, I12, G15, G16, P13 | absent | **G** | post-v1.1 | WP26's exclusion: *"Everything in R-46 (BP's own 1.2 deferrals)"* |
| **R-43** | — | absent | **G** | post-v1.1, **PD-7/PD-8/R-17** | Not in WP26's scope at all |
| **R-12** *(eviction)* | — | below-2 deletion stands | **D** | product | WP25: *"R-12's eviction policy is a product judgement"* |
| **R-23** *(legal)* | — | absent | **E** | **WP18 → R-15** | All twelve WP18 facts uncollected (WP21) |
| **R-19** | — | last-round `votesReceived` | **H** | unclaimed | Not in WP26's scope |
| **WP24** | — | — | **D** | **PD-4** | Blocked |
| **WP21** | — | — | **F** | validation | Blocked on device + WP18 facts |

### C.1 · R-35 was already complete — a genuine sweep finding

**[VERIFIED]** The reconciliation records R-35 as `PARTIALLY COMPLETE` with the evidence *"(5 consumer sites; `AnimatedPrimaryButton` and `TimerWidget` are **not** among them)"*. At HEAD both **are**:

```
animated_primary_button.dart:193   scale: context.motion(full: _scaleAnimation.value, reduced: 1.0)
timer_widget.dart:130              scale: context.motion(full: scale, reduced: 1.0)
```

and `reduced_motion.dart:36-37` defines `T motion<T>({required T full, required T reduced}) => reduceMotion ? reduced : full;`.

**[INFERRED]** The audit's grep looked for `context.reduceMotion`; these two sites use `context.motion`, the sibling helper in the same file. Both are reduce-motion-aware. **WP26 correctly did nothing here** — re-implementing it would have been work invented from a stale assessment.

---

## D · WP26-OWNED ITEMS — the authoritative list

> **Scope** `wakelock_plus` (R-29) · paywall migration (R-30) · legacy-palette deprecation annotations (R-31) · `SeasonAccent` enum (R-32) · icon sweep and mis-picks (R-33) · navigation completion incl. `Hero` (R-34) · reduce-motion on the button and timer (R-35) · remaining plain buttons, spinner, `PhaseBanner` (R-36) · field-level validation and the visible own-card label (R-38) · duration tokens and the phase-enum rename (R-39) · opacity/icon scales and the share-card pipeline (R-40) · ATS (R-24) · dead-file removal (R-26).

Thirteen items. **Five implemented, one already complete, seven deferred** (R-34 counted once in the list but split in §C).

---

## E · IMPLEMENTATION

### E.1 · R-24 — the app-wide ATS exemption

**Before.** `ios/Runner/Info.plist:31-35` carried `NSAppTransportSecurity → NSAllowsArbitraryLoads → true`, disabling App Transport Security for the whole app.

**Requirement.** audit A M-1: *"Nothing in the codebase appears to need it — all traffic is Firebase HTTPS."* R-24: **"Verify before removing."** Non-goal: *"do not scope-narrow to domains without first proving nothing needs the exemption."*

**Verification performed. [VERIFIED]** across `lib/`: zero `http://`, zero `Uri.parse`, zero `HttpClient`, zero `localhost`/`10.0.2.2`/`127.0.0.1`, zero `useEmulator`, and **zero hard-coded URLs of any scheme**. The app issues no request of its own; everything goes through the Firebase and AdMob SDKs over HTTPS.

**Change.** The four-line dictionary removed entirely — full removal, not a domain narrowing, as the non-goal requires.

**After.** ATS applies. **[VERIFIED]** by test.

> ⚠️ **One residual, device-only. [UNVERIFIABLE here.]** audit A's premise covers the app's own traffic; it does not cover **AdMob creatives**, which are third-party web content rendered by `google_mobile_ads`. Google's current documented position is that AdMob does not require the exemption, and the app's own traffic is provably clean — but *"rewarded ads still render"* is observable only on a device. **This must be checked in WP21's device pass before submission.** Reverting is a four-line restoration if it fails.

### E.2 · R-26 — four compiled files with no reachable caller

**Before. [VERIFIED]** by grep, before deleting anything:

| File | Referenced by |
|---|---|
| `lib/providers/ad_providers.dart` | **nothing at all** |
| `lib/providers/monetization_providers.dart` | one **comment** in `game_providers.dart:20` |
| `lib/domain/controllers/monetization_controller.dart` | `monetization_providers.dart` (itself dead) + its own test |
| `lib/services/local_storage_service.dart` | the two dead files above + the same test |

A closed component with one test and no entry point.

**Change.** All four deleted, plus `test/monetization_controller_test.dart` (7 tests), which tested only the removed code. **`MonetizationException` was checked first and lives in `core/exceptions.dart`** — it is used by `lobby_screen` and is untouched.

**After. [VERIFIED]** `flutter analyze` clean and the full suite green with the files gone — which is the proof that the callers really were absent. Removing the controller also removes audit A **M-3**'s latent swallowed-exception path.

**[VERIFIED]** audit A's caveat is honoured: these are **not** hidden features (*"Reporting them as concealment would be wrong"*), and nothing here is presented as 5.6 remediation.

### E.3 · R-32 — `SeasonAccent`

**Before.** `Season.themeColor` was a bare `int` read from Firestore and handed straight to `Color(...)` at **11 call sites** across the Home banner and the season details screen. A season document could put any ARGB value on the app's first screen. Nothing checked, because there was nothing to check against.

**Change.** A new `lib/core/theme/season_accent.dart` — four named accents (`lavender`/`sky`/`mint`/`coral`) resolving their own colours from `AppColors`, with `SeasonAccent.fromThemeColor(int)` matching the four exactly and **falling back to `lavender` for anything else**. `Season` gains `SeasonAccent get accent`; both consumers now read `season.accent.color`.

**Shaped after `Rarity`** (`rarity.dart`), which WP17 built for the identical problem — a stored value turned into a colour at the call site, replaced by a theme-layer enum. Two models already import it, so the layering is precedented, not new.

**After.** **[VERIFIED]** `grep themeColor` in both consumers → **0**. The stored value survives `toFirestore` untouched — R-32's non-goal (*"does not require a Firestore schema change — resolve client-side"*) is honoured. Four tests, including one that feeds the existing fixture's `0xFF7C4DFF` and proves it can no longer reach the screen.

### E.4 · R-34 (routes) — the navigation language

**Before. [VERIFIED]** three live `MaterialPageRoute`s against sixteen adopted fade-slide sites: `lobby_screen.dart:176` (paywall), `profile_screen.dart:92` (public profile), `season_countdown_banner.dart:75` (season details).

**Change.** All three now use `context.pushFadeSlide`, the extension already in `page_transitions.dart`. **No router package** — BP line 1037.

**After. [VERIFIED]** zero raw `MaterialPageRoute` in `lib/`, asserted by a test that strips comments before grepping (several files discuss the old routes in prose).

**The `Hero` half is deferred** — §F.5.

### E.5 · R-38 — the silently discarded room code, and the own-card label

**(a) The code field.** R-38's scope cites **BP Part IV §1(d)**: *"typing a code then pressing 'Crear Sala' silently discards it."*

**Before.** Pressing "Crear Sala" with a code typed created a *new* room and dropped the code with no message — the button behaved as though the field were empty.

**Change.** That one case now sets `errorText` on the code field, explaining it and pointing at "Unirse a Sala", and clears as soon as the field is edited.

> **Scope note, and a course correction made during implementation.** The first attempt also moved the **empty-name** and **empty-code** guards from `BufonFeedback` to `errorText`, on the strength of BP §1(e) (*"Validation errors appear as `SnackBar`s far from the fields"*). That broke three tests in two files, and reading them showed why: **WP11 deliberately adopted `BufonFeedback` as Home's single reporting path**, and `registered_feedback_adoption_test` uses exactly those two guards as its *probe* of that path — its own comments say so. R-38's scope cites **(d)**, not (e). The change was narrowed to the case R-38 actually names; **WP11's shipped decision and all three tests stand untouched.** Relitigating an adopted decision in the final package would have been out of scope.

**(b) The own card.** BP **P9**. **Before**, the viewer's own answer card was muted and unvotable with no visible explanation — the only text saying why lived inside a `Semantics` string, so a **sighted** player was told nothing. **After**, it renders `"Tu respuesta: …"`.

**[VERIFIED]** `accessibility_test.dart`'s existing assertion was re-pointed at the new string — exact match, reading the constant, so it cannot drift. That is the same test, strengthened: it now proves the label as well as the answer.

---

## F · DEFERRED / BLOCKED ITEMS

Each with the reason WP26 did **not** implement it.

### F.1 · R-29 — `wakelock_plus`

**[VERIFIED]** `grep -c wakelock pubspec.yaml` → 0, and the package is **not in the local pub cache**, so adopting it requires a network `pub get` that rewrites `pubspec.lock` and adds native platform config. Its behaviour — the screen not sleeping during a round — is **device-observable only**, and WP21 proved no device exists here. Gate **S6** authorises exactly this one dependency, so the *authorisation* is not the obstacle; **verifiability is**.

**[INFERRED]** Its premise is also partly mitigated: WP23 shortened the answering round from 90 s to 60 s.

### F.2 · R-30 — the paywall

**[VERIFIED]** worse than the reconciliation recorded: the screen uses **raw hex literals** (`Color(0xFF1A1A2E)`, `Color(0xFFE94560)`, `Color(0xFF0F3460)`, `Color(0xFFFFD700)`) plus `Colors.white`/`grey`/`green`/`red` — 20 colour expressions, and **no `AppColors` reference at all**.

R-30 is a full recolour *and* a hierarchy change (*"one recommended option as protagonist"*). Its own verification is **the manual Paywall pass**. Doing it blind on the money screen, in the last package, is the change most likely to look wrong and least likely to be caught.

### F.3 · R-31 — legacy-palette deprecation · **a documented conflict**

R-31's scope: *"annotate, do not delete — **let `flutter analyze` produce a burndown**."*
WP26's Verification: *"**`flutter analyze` clean**."*

**These cannot both hold.** Annotating is *designed* to make the analyzer report every remaining use, and `flutter analyze` exits non-zero on `info` diagnostics. **[VERIFIED]** the burndown would be large: `AppColors.primary` **48** uses, `textSecondary` **43**, `textPrimary` **29**, `surface` **23**, `gold` **24**, `background` **13** — **180+** before counting the rest.

**Reported, not resolved** (stop condition: an authoritative conflict). The owner's call is whether WP26's "analyze clean" gate is suspended for the burndown, or the burndown waits.

### F.4 · R-33 — icons

**[VERIFIED]** 5 outline icons and 3 mis-picks remain. The reconciliation names the **problems** — *"`Icons.military_tech` for player titles, `Icons.photo_size_select_actual` for a top-10 season finish, `Icons.sports_esports` as the round counter"* — and **never names the replacements**. Choosing them is design authority WP26 does not hold, and BP forbids the shortcut (*"do not substitute a third-party icon library"*).

Two further reasons: **3 of the 7** outline icons are inside R-30's deferred paywall, and `Icons.sports_esports` sits in `RoundIndicator`, which is **golden-covered** (`round_indicator.png`) and whose own source comment already records it as *"Known, deliberately deferred"*.

### F.5 · R-34 (Hero)

The two proposed flights — the room code from Lobby into the game header, and the winning answer from the voting card into the reveal spotlight — cross routes that already run bespoke fade-slide and keyhole transitions. Whether a `Hero` reads correctly against those is a motion judgement settled by watching it, not by a test.

### F.6 · R-36 — buttons, spinner, `PhaseBanner`

**[VERIFIED]** the 5 plain buttons are all on `profile_screen` / `profile_public_screen`, which `bufon_component_primitives_test` explicitly holds out: *"The five screens still on `BufonPhase.legacy` remain outside: **their feedback moves with the package that recolours them**."* That package is R-30's, deferred. `PhaseBanner` is a new primitive collapsing two existing banners — composition.

**[VERIFIED]** `animated_primary_button.dart:245`'s spinner was left alone, as R-36's non-goal requires.

### F.7 · R-39 — duration tokens and the phase-enum rename

**[VERIFIED]** 15 raw `Duration(milliseconds:)` outside `motion_tokens.dart`. They have **no matching tokens**, so adopting them means *naming new motion tiers* — design authority — and BP line 1041 forbids unifying the two press values, so they cannot simply collapse. The `GamePhase`/`BufonPhase` rename is a broad rename across the app, which the brief's no-opportunistic-refactoring rule forbids.

### F.8 · R-40 — token scales and `ShareProfileCard`

`AppOpacity`/`AppIconSize` with no adopters would be speculative scaffolding. The `ShareProfileCard` rebuild is composition on an exported artefact that cannot be inspected here, and BP's *"it should be redesigned, not extended"* constrains the chassis.

---

## G · PRODUCT DECISIONS STILL OPEN

| PD | Question | Blocks |
|---|---|---|
| **PD-1** | Round duration | **Decided and shipped by WP23** (60 s) |
| **PD-2** | Should voting have a visible clock? | A present-but-silent voter still holds voting open |
| **PD-4** | The tie-breaker, and which layer moves | **WP24 entirely** |
| **PD-7 / PD-8** | What "El más aburrido" means; its tie/tone policy | **R-43** |
| **PD-9** | Corpus size and the scope of repeat-avoidance | Shapes R-14/R-18; WP23 shipped 100 / per-room |
| **PD-10** | How the winner's equipped avatar reaches the ceremony | **R-27** — a BP **P0** |
| **PD-11** | BUFON or BUFÓN in the wordmark | **R-28** |
| **PD-12** | Single-device reviewability | **Answered at WP20.5** — (c) Practice Mode + (a) + (d); not built |
| **PD-13** | The username contract | Candidate **R-47** |
| **R-12 policy** | Below-2-active room deletion | Raised by WP25 |
| **R-20 posture** | UGC moderation | Gated on R-21 |
| **R-31 gate** | Burndown vs. "analyze clean" | **New — §F.3** |
| **R-41** | Ratify or revert `RoundIndicator` | Informational |
| **R-33 icons** | Which glyphs replace the three mis-picks | **New — §F.4** |

---

## H · VALIDATION-ONLY ITEMS

* **WP21 — clean-state reproducibility capture.** **BLOCKED**, two independent reasons: no factory-clean device, and WP18's twelve console facts uncollected. Manual gates **M1**, **M2**, **M4**, **M5**, **M8** remain owed.
* **WP18 — console fact-finding.** No code. Gates **E1**, and now also R-23's remaining half.
* **R-41 — `RoundIndicator` ratification.** VERIFY ONLY.
* **New, added by this package:** the **AdMob-under-ATS** check (§E.1) belongs in WP21's device pass.

---

## I · POST-V1.1 ITEMS

**R-42** (dead analytics registry entries) · **R-43** ("El más aburrido") · **R-44** (`AppLogDestination.onLog`'s async contract) · **R-45** (server-anchored timing and server-authoritative advancement) · **R-46** (BP's own 1.2 deferrals: I6, I9, I11, I12, G15, G16, P13).

**[VERIFIED]** None was touched.

---

## J · PRESERVATION AUDIT

| Package | Guarantee | Intact? | Evidence |
|---|---|---|---|
| **WP19** | `AnalyticsDestination` boundary, reserved-name handling, event registry, Crashlytics severity | ✅ | `lib/analytics/**` and `lib/core/crash/**` absent from the diff; the 55 outbound names unchanged; gates **A4/T-A**, **S2** unaffected |
| **WP20** | Launch identity; Profile/Leaderboard/Season empty-vs-error | ✅ | `main.dart`, `progression_providers.dart`, `leaderboard_screen.dart` untouched. `profile_screen.dart` changed **one navigation call**; its WP20 empty/error branches are byte-unchanged, and `launch_empty_states_test` passes |
| **WP20** | Installed app identity | ✅ | `AndroidManifest.xml` untouched; `Info.plist` changed **only** the ATS dictionary — `CFBundleDisplayName`/`CFBundleName` = **Bufón**, bundle id, signing all untouched |
| **WP22** | Eligibility, voting completion, sole-answerer, zero-answer, idempotency, stale timers | ✅ | `player.dart`, `room_repository.dart`, `game_screen.dart` untouched; all 15 `loop_stall_test` tests pass |
| **WP23** | Room-scoped history, host reassignment, corpus loading, transactional advance, 60 s, legacy 90 s | ✅ | `room.dart` changed **only** by R-32's `accent` getter and a doc comment; `question_service.dart`, `assets/questions.json` untouched; all 19 `question_repetition_test` tests pass |
| **WP25** | `RoomExit`, Android back, presence, host presence, connection banner, explicit leave | ✅ | `room_exit.dart`, `connection_banner.dart`, `connection_service.dart` untouched. `lobby_screen`/`voting_screen` changed only at a route call and the own-card text; all 13 `room_exit_test` tests pass |

**[VERIFIED]** by the full suite: every test from every prior package passes unchanged.

---

## K · TESTS

| | |
|---|---|
| **Baseline (measured)** | **356** |
| **Removed** | **−7** — `monetization_controller_test.dart`, which tested only the code R-26 deleted |
| **Added** | **+8** — `blueprint_sweep_test.dart` |
| **Final** | **357** passing, 0 failed, 0 skipped |
| **`flutter analyze`** | **No issues found!** |
| **`git diff --check`** | clean |

### K.1 · `test/blueprint_sweep_test.dart` — 8 tests

| Group | Test | Fails pre-WP26 because |
|---|---|---|
| R-32 | the four accents resolve to themselves | `SeasonAccent` did not exist |
| R-32 | **an unrecognised int cannot reach the screen as itself** | `0xFF7C4DFF` — the value the existing fixture carries — was painted onto Home verbatim |
| R-32 | every resolved colour is a design-system colour | the constraint did not exist |
| R-32 | `Season` exposes the constrained accent, not the raw int | and still round-trips the stored value, per the non-goal |
| R-38 | **pressing "Crear Sala" with a code typed says so** | it was silently discarded |
| R-38 | the message clears as soon as the field is edited | — |
| R-34 | no screen builds a raw `MaterialPageRoute` | three did. Comment-stripped before grepping |
| R-24 | `Info.plist` carries no blanket exemption | it did |

**[VERIFIED]** No test was weakened, skipped or exception-suppressed. **No `tester.takeException()` was added.** The two source-level assertions follow the shape `bufon_component_primitives_test`'s `adoption` group already established for exactly this kind of claim.

### K.2 · The one existing test touched

`accessibility_test.dart`'s *"the loop still renders with animations disabled"* asserted `find.text('Una respuesta graciosa')` — the viewer's own answer, which R-38(b) now prefixes. The assertion reads `GameCopy.yourAnswerLabel` and matches the full new string **exactly**, so it is strictly stronger than before: it proves the label as well as the answer, and cannot drift from the copy.

### K.3 · One comment reworded, not a test weakened

`bufon_component_primitives_test`'s *"every adopted screen builds no SnackBar of its own"* greps the **source text** of five screens. A doc comment written in this package used that word to explain why the code does *not* use one, and tripped the grep. **The comment was reworded; the test was not touched.**

---

## L · GOLDENS — WP26's primary gate

| Golden | SHA-256 (before **and** after) |
|---|---|
| `animated_primary_button_disabled.png` | `ec40727fb2b572fc…` |
| `animated_primary_button_outline.png` | `ee377c92f90f5164…` |
| `animated_primary_button_solid.png` | `f9b8fd0c1bcc3de4…` |
| `game_card_disabled.png` | `194cc647580090dc…` |
| `game_card_resting.png` | `506317e562202dbb…` |
| `game_card_selected.png` | `a0425c3352d5a5ec…` |
| `game_progress_bar_midgame.png` | `2c6180cc5c8be984…` |
| `round_indicator.png` | `3963fdb76d7a20ca…` |
| `timer_widget_normal.png` | `f271e1d84bd3a989…` |
| `timer_widget_urgent.png` | `d5912349ab2080d8…` |

**[VERIFIED] All ten byte-identical.** No golden-regeneration command of any form was run, and none needed re-baselining — WP26's stop condition (*"if a golden changes and the change is not explainable in one sentence, stop"*) never engaged.

**[INFERRED]** This is a *consequence of the deferral principle*, not luck: every deferred item (R-30 recolour, R-33 icons, R-36 buttons, R-40 scales) is precisely the kind that would have moved a golden.

---

## M · SCOPE AUDIT

| Item | Changed? | Evidence |
|---|---|---|
| **WP19 telemetry** | **NO** | `lib/analytics/**`, `lib/core/crash/**`, `lib/core/telemetry/**` absent from the diff |
| **WP20 launch identity** | **NO** | `main.dart` untouched; `Info.plist` changed only the ATS dictionary |
| **WP22 stall logic** | **NO** | `player.dart`, `room_repository.dart`, `game_screen.dart` untouched |
| **WP23 question/timer** | **NO** | `question_service.dart`, `assets/questions.json` untouched; `room.dart` only gained R-32's getter |
| **WP25 exit/presence** | **NO** | `room_exit.dart`, `connection_banner.dart`, `connection_service.dart` untouched |
| Scoring · XP · ranking · tie-breaking | **NO** | no scoring path in the diff; **PD-4 not consumed** |
| Username limit · UGC | **NO** | PD-13, R-20 |
| Practice Mode | **NO** | not implemented, not referenced |
| **Firestore Rules** | **NO** | `firestore.rules` untouched — gate **S4** |
| **Cloud Functions** | **NO** | `functions/` untouched |
| **3-player minimum** | **NO** | guard untouched |
| **8-player maximum** | **NO** | guard untouched |
| **Dependencies** | **NO** | `pubspec.yaml` / `pubspec.lock` unchanged — gate **S6**; R-29 deferred |
| Goldens | **NO** | §L |
| **Blueprint** | **NO** | hash-verified |
| **Master Reconciliation** | **NO** | hash-verified |

**[VERIFIED] No stop condition triggered by an implemented item.** Stop condition 2 (an authoritative conflict) **did** fire for R-31 and is reported rather than resolved (§F.3).

---

## N · GIT

```
starting HEAD : 1bfe28290ca7295168bd9e49c02315101286a85c   (WP25)
message       : fix: complete v1.1 blueprint sweep
HEAD^         : 1bfe28290ca7295168bd9e49c02315101286a85c
```

**Files in the commit:**

```
M  bufon_flutter/ios/Runner/Info.plist
M  bufon_flutter/lib/core/game_copy.dart
A  bufon_flutter/lib/core/theme/season_accent.dart
M  bufon_flutter/lib/models/season.dart
M  bufon_flutter/lib/presentation/screens/profile_screen.dart
M  bufon_flutter/lib/presentation/screens/season_details_screen.dart
M  bufon_flutter/lib/presentation/widgets/season_countdown_banner.dart
M  bufon_flutter/lib/screens/home_screen.dart
M  bufon_flutter/lib/screens/lobby_screen.dart
M  bufon_flutter/lib/screens/voting_screen.dart
D  bufon_flutter/lib/domain/controllers/monetization_controller.dart
D  bufon_flutter/lib/providers/ad_providers.dart
D  bufon_flutter/lib/providers/monetization_providers.dart
D  bufon_flutter/lib/services/local_storage_service.dart
M  bufon_flutter/test/accessibility_test.dart
A  bufon_flutter/test/blueprint_sweep_test.dart
D  bufon_flutter/test/monetization_controller_test.dart
A  docs/design/v1.1/WP26_IMPLEMENTATION_REPORT.md
```

**[VERIFIED]** Exactly one commit. **No amend, no rebase, no squash, no reset, no stash, no clean, no force push.** History intact through five ancestors to WP19.

---

## O · PUSH

> ## **NOT PUSHED.**

**[VERIFIED]** `origin/main` remains `2c8337e7d790c79803b7b93f3b0329318cbc2e93`. **Seven** commits are local-only: `15824db`, `9f7d98e`, `6f00a24`, `532d396`, `196412c`, `1bfe282`, and this one.

---

## P · RELEASE READINESS SNAPSHOT

**No percentage is offered.** The reconciliation's own model refuses one, and inventing one here would be worse now that six packages have moved.

### P.1 · The eleven release blockers (`:1250`) — status

| Blocker | Owner | Status |
|---|---|---|
| **A C-2** → R-07 | WP20 | ✅ **CLOSED** — `6f00a24` |
| **C C-1** → R-01 | WP19 | ✅ **CLOSED** — `9f7d98e` |
| **C C-2** → R-02 | WP19 | ✅ **CLOSED** |
| **C C-4** → R-03 | WP19 | ✅ **CLOSED** |
| **C T-1** → R-04 | WP19 | ✅ **CLOSED** |
| **C T-3** → R-05 | WP19 | ✅ **CLOSED** |
| **C Q-1…Q-4** → R-06 | WP19 | ✅ **CLOSED** |
| **B G-1F** → R-08 | WP22 | ✅ **CLOSED** — `532d396` |
| **B G-1G+G-1H** → R-09 | WP22 | ✅ **CLOSED** |
| **A M-4** → R-25 (checklist) | process | ❌ **OPEN** — a process gate, gate **S8** |
| **WP18** → R-15 | external | ❌ **OPEN** — all twelve facts uncollected |

**Nine of eleven closed in code. The two open ones need no code** — one is a checklist edit, the other a console session.

### P.2 · Conditional blockers

| Item | Status |
|---|---|
| **R-10** voting bound | ✅ sweep variant shipped (WP22) |
| **R-11** exit paths | ✅ **CLOSED** (WP25) |
| **R-12** room destruction | ⚠️ **PARTIAL** — `inactive` fixed; the eviction policy is a product judgement |
| **R-20** Guideline 1.2 | ❌ **OPEN** — decision, gated on R-21 |
| **R-21** reviewer observability | ⚠️ **DEFINED** at WP20.5 (PD-12 = (c)+(a)+(d)); **not built** |

### P.3 · Gates that cannot be closed from this machine

**[VERIFIED]** **M1**, **M2** (installed name, visually) · **M4** (clean-state journey) · **M5** (three-device pass) · **M8** (exit from every error screen — WP25 made it *testable*, not *tested*) · **M9** (assistive technology — never executed) · **E1…E7** (all external) · **S9** (version never incremented — `1.0.0+1` still) · and now the **AdMob-under-ATS** check (§E.1).

### P.4 · The honest summary

The code-side v1.1 remediation is **substantially complete**: every gameplay and telemetry release blocker is closed, the loop cannot stall, the launch is honest, exits exist, and questions do not repeat. **What remains is overwhelmingly not code** — one console session, one checklist, a handful of product decisions, and a device.

---

## Q · NEXT ACTIONS

```
WP18 ∥ WP19 ✅ → WP20 ✅ → WP21 ❌ blocked
WP22 ✅ ─┬→ WP23 ✅
         └→ WP25 ⚠️ partial
PD-4 ────→ WP24 ❌ blocked
WP26 ✅ partial   ← the last code package
```

**In priority order, per the Master Reconciliation:**

1. **Execute WP18's console protocol.** No code. It is the last open release blocker that can be discharged by a person at a keyboard, it gates **E1**, **PD-12**, R-23's remaining half, and — per WP21 — it is *the harder of that package's two blockers*. **E-09** (is Anonymous Auth enabled?) would confirm WP20 works on a real device at all.
2. **Close R-25 / gate S8** — add review notes, demo provisioning and a reviewer walkthrough to `docs/testing/TESTFLIGHT_CHECKLIST.md`. No code; the eleventh blocker.
3. **Re-run WP21** once a clean device exists — including the new AdMob-under-ATS check and gates M1/M2/M4/M5/M8/M9.
4. **Increment the version** — gate **S9**, never satisfied; `1.0.0+1` is indistinguishable from the rejected build.
5. **Decide the open product questions** — **PD-4** (unblocks WP24), **PD-2**, **PD-9**, **PD-13**, **R-12**'s eviction policy, **R-20**'s posture, **R-31**'s analyze-gate conflict (§F.3), **R-33**'s icon choices, and **R-41**'s ratification.
6. **Then, if wanted:** the eight deferred WP26 items (§F), each of which needs either a device, a dependency, or a design call — and **Practice Mode**, decided in principle at WP20.5 and gated on R-20 plus WP20 (the latter now satisfied).

**Not started:** WP24. Practice Mode not implemented. Nothing pushed.

---

*WP26 PARTIAL — FIVE ITEMS CLOSED, ONE ALREADY COMPLETE, EIGHT DEFERRED WITH EVIDENCE — ONE COMMIT — NOT PUSHED*
