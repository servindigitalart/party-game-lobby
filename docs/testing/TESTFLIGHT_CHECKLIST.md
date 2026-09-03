# TESTFLIGHT_CHECKLIST.md

> Operational checklist for every TestFlight release and every App Store submission.
>
> This checklist must be completed before submitting any build.

---

# Purpose

The objective is to guarantee that every external tester receives a stable,
observable and debuggable build — and that every App Review submission arrives
complete, honest and actually reviewable.

Skipping checklist items is not allowed.

---

# How to use this document

The document is in three parts. Work them in order.

**Part I — Build readiness (Phases 1–12).** Applies to every build, TestFlight
or App Store. This is the original checklist and is unchanged in substance.

**Part II — Submission readiness (Phases 13–21).** Applies when the build is
going to App Review, TestFlight external testing, or the App Store.

**Part III — Templates and reference.** A Review Notes skeleton to fill in, and
the short list of product facts a release owner needs when writing it.

## Two things this document keeps separate

**App Store Connect App Review Information** is attached to an **App Store
version**. **TestFlight Beta App Review Information** is attached to
**TestFlight external testing**. They are different fields in different
sections of App Store Connect, and either can be filled in without the other.

**Filling in one does not satisfy the other.** Phase 17 covers the first.
Phase 19 covers the second. Do not copy between them without reading both.

## Labels used below

| Label | Meaning |
|---|---|
| **FACT** | Established by the project's own evidence, and cited |
| **RECOMMENDATION** | A judgement call, not an external requirement |
| **ACTION** | Something the release owner must do or decide |

## What completing this checklist does and does not mean

Completing this document means the **release procedure** was followed. It does
**not** by itself mean the app is ready to ship. Phase 21 is the gate that
answers that question, and it depends on work tracked outside this file.

---

# PART I — BUILD READINESS

---

# Phase 1 — Source Control

□ Working tree clean.

□ Correct branch.

□ Latest changes pulled.

□ No merge conflicts.

□ Version committed.

□ Version tagged (release builds).

---

# Phase 2 — Quality

Run

flutter analyze

Result

□ Pass

Run

flutter test

Result

□ Pass

Run widget tests.

□ Pass

Run integration tests (future).

---

# Phase 3 — Firebase

Verify

□ Firebase initialized.

□ Firestore connected.

□ Analytics connected.

□ Crashlytics connected.

□ Authentication working.

□ Firestore Rules deployed.

□ Firestore Indexes deployed.

## Backend availability during review

**FACT.** Apple's App Review Guideline 2.1(a) instructs submitters to
"turn on your back-end service". Bufón is non-functional without Firebase:
every screen past launch depends on Firestore, and identity depends on
Anonymous Authentication.

□ Anonymous sign-in provider is **enabled** in the Firebase console.
    Evidence: Firebase → Authentication → Sign-in method → Anonymous.
    Note: the app resolves identity at launch, so if this provider is
    disabled the app starts with no identity at all.

□ App Check enforcement mode recorded for each API (enforced / unenforced).
    Evidence: Firebase → App Check → APIs, and Metrics for the review window.

□ Firestore is reachable in production, and a room can be created and joined.

□ Cloud Functions deployed and responding (`submitVote`, `onMatchCompleted`,
    receipt validation under `functions/src/purchases/`).

□ The backend will remain available for the whole review window, including
    any resubmission.

□ If the season surface is expected to render, an active `seasons` document
    exists. If it does not, confirm the absence is intentional — the banner
    renders nothing by design when there is no active season.

□ If leaderboards are expected to show entries, `/leaderboards` is populated.
    Otherwise confirm the empty state is the intended reviewer experience.

---

# Phase 4 — Telemetry

Verify

□ Structured logging.

□ Analytics events.

□ Breadcrumbs.

□ Custom Keys.

□ Session context.

□ Player context.

□ Room context.

□ Current screen.

□ Build number.

---

# Phase 5 — Multiplayer

Verify

□ Create Room

□ Join Room

□ Leave Room

□ Host disconnect

□ Player disconnect

□ Reconnect

□ Start Match

□ End Match

□ Play Again

---

# Phase 6 — UI

Verify

□ No RenderFlex overflow.

□ No clipped widgets.

□ No missing assets.

□ Safe Area respected.

□ Animations working.

□ Haptics working.

□ Sound effects working.

---

# Phase 7 — Performance

Verify

□ Launch time acceptable.

□ Room creation fast.

□ Room joining fast.

□ Firestore synchronization stable.

□ No dropped frames.

---

# Phase 8 — Crash Validation

Trigger one controlled test exception.

Confirm:

□ Crash visible in Firebase.

□ Breadcrumbs visible.

□ Custom Keys visible.

□ Stacktrace readable.

---

# Phase 9 — Analytics Validation

Confirm events appear in DebugView.

Minimum:

□ app_open

□ session_started

□ room_created

□ room_joined

□ match_started

□ match_finished

---

# Phase 10 — Versioning

Verify

□ Version number updated.

□ Build number incremented.

□ Release notes written.

## Build identifiability

**FACT.** `pubspec.yaml` has read `version: 1.0.0+1` in every tracked commit.
The build number has never been incremented, which is why no past submission
can be matched to a specific source revision after the fact.

□ `version:` in `pubspec.yaml` incremented before this build is uploaded.

□ The build number is unique and has not been uploaded before.

□ Record the git SHA this build was cut from, next to the build number.
    Evidence: note it in the release notes or the tag message.

---

# Phase 11 — Distribution

Internal

□ Uploaded

□ Processing complete

□ Install verified

External

□ Build approved

□ Testers assigned

□ Invitation sent

---

# Phase 12 — Monitoring

After release monitor

Crashlytics

Analytics

Firestore Usage

Player Feedback

Performance

for at least 24 hours.

---

# Release Notes

Every build must include:

New Features

Bug Fixes

Known Issues

Areas requiring testing

---

# Bug Reports

Every bug report should include:

Device

OS Version

Build Number

Room Code

Steps to reproduce

Expected result

Actual result

Screenshot

Video (if possible)

---

# PART II — SUBMISSION READINESS

> Work Phases 13–21 for any build going to App Review, TestFlight external
> testing, or the App Store. Skip none of them on the assumption that a
> previous submission already covered it — App Store Connect fields are
> editable, and what a past version carried is not what this one carries.

---

# Phase 13 — App Store Connect Agreements

Three states. **Keep them separate.** An active agreement is not evidence that
an in-app purchase has been submitted, and an in-app purchase sitting in
"Prepare for Submission" is not evidence that an agreement is inactive.

□ **Free Apps Agreement** status recorded.
    Evidence: App Store Connect → Business → Agreements.

□ **Paid Apps Agreement** status recorded.
    Evidence: same screen.

□ If this release includes a paid in-app purchase, the **Paid Apps Agreement**
    is active. The Free Apps Agreement does not cover a paid transaction.

□ Any pending tax, banking or contact information on the agreement resolved.

□ Agreement status recorded **separately** from the in-app purchase submission
    state captured in Phase 18. Do not infer one from the other.

---

# Phase 14 — App Version Metadata

Verify each field on the version being submitted. Use "verify" literally:
open the field and read it. Do not assume a field carries what a previous
version carried.

□ App description present, accurate, and free of placeholder text.

□ The description does not advertise features a reviewer cannot reach.
    Evidence: read the description against what the app actually exposes.

□ Keywords set.

□ Primary category set. Secondary category set or deliberately left empty.

□ Age rating questionnaire completed.

□ Support URL present, and it resolves.

□ Marketing URL present and resolving, or deliberately omitted.

□ Privacy policy URL present and resolving — see Phase 15.

□ Screenshots uploaded for every required device size.

□ App icon and required assets present.
    Note: the 1024×1024 marketing icon ships in the app bundle's asset
    catalogue; App Store Connect still requires its own upload where prompted.

□ The correct **build** is attached to the version being submitted.

□ Export compliance answered.
    Note: `ITSAppUsesNonExemptEncryption` is not currently declared in
    `Info.plist`, so App Store Connect will prompt at every upload until it is.

□ Content rights question answered.

□ All URLs in the metadata resolve. Apple's Guideline 2.1(a) requires
    "fully functional URLs" and no placeholder text.

---

# Phase 15 — Privacy and App Privacy

**FACT.** App Review Guideline 5.1.1(i) requires a privacy policy link in
**two** places: "in the App Store Connect metadata field **and** within the app
in an easily accessible manner". Both are required. One does not substitute
for the other.

**FACT.** Apple's App Privacy documentation states the App Privacy information
"is required to submit new apps and app updates to the App Store", and defines
third-party partners as "analytics tools, advertising networks, third-party
SDKs, or other external vendors whose code you've added to your app".

□ A published privacy policy exists and is reachable at a stable URL.

□ **App Store Connect privacy-policy URL** set on this version.

□ **In-app privacy-policy link** present and reachable by a user.
    Note: adding this surface is tracked separately on the roadmap as **R-23**.
    This checklist does not close R-23; it records that the requirement exists
    and must be satisfied before submission.

□ Both links actually resolve. Open them.

□ The submitted metadata matches the current published policy.

□ **App Privacy questionnaire** completed for this version.

□ Every shipped SDK enumerated before answering the questionnaire, including
    Firebase Analytics, Firebase Crashlytics, and Google Mobile Ads.

□ **Verify App Privacy disclosures against actual SDK behaviour and the
    submitted data-use declarations, including the configured Google Mobile Ads
    integration.**
    Context for this check: the app declares a production
    `GADApplicationIdentifier` and eight `SKAdNetworkItems` in `Info.plist`
    and initialises the ads SDK on every launch, while the only ad-bearing
    screen sits behind the progression gate described in Phase 18. The
    questionnaire asks what is **collected**, not what is **reached**.
    **ACTION:** determine the correct disclosure treatment deliberately.
    Do not guess, and do not answer by analogy to a previous submission.

□ Data retention and deletion behaviour described in the policy.

□ The policy explains how a user revokes consent or requests deletion.

---

# Phase 16 — Reviewer Access Plan

**Complete this phase before writing Review Notes.** Phase 17 documents the
plan; this phase decides whether there is one.

**FACT.** Bufón requires **3–8 players**. The minimum is enforced in
`room_repository.dart` — a room cannot leave the lobby phase with fewer than
three players. The maximum is enforced in the same file.

**FACT.** Bufón has **no email/password login**. Authentication is anonymous
and is resolved at launch, so a reviewer is signed in without seeing any
sign-in surface and without needing credentials.

**FACT.** A single reviewer cannot independently create a multiplayer match.
Rooms observed with one player could not start a match, because the three-player
minimum is a hard transition guard.

**FACT.** The app does not currently provide a solo, practice, demo or bot
mechanism.

**RECOMMENDATION, not an Apple requirement.** No Apple source in the project's
evidence establishes a universal practice-mode or demo-mode requirement for a
multiplayer app without a login. Apple's demo-account clause is conditioned on
the app having a login, and its built-in-demo-mode alternative is offered in
lieu of a demo account and requires Apple's prior approval. **This checklist
therefore does not assert that Apple requires a practice mode.**

**What this checklist does require:** reviewer access to the multiplayer core
experience must be explicitly addressed in the review plan. Bufón requires 3–8
players and does not currently provide a solo/practice/demo mechanism, so the
release owner must provide a legitimate reviewer-access strategy and document
it in Review Notes before submission.

□ The reviewer can reach the app's core experience.

□ The reviewer instructions explain Bufón's 3–8 player requirement.

□ The review plan does **not** assume a single reviewer can exercise a
    multiplayer match unaided.

□ Any required accounts, resources or participants are **actually available**
    before submission — not merely planned.

□ Any backend dependency is active during review. Cross-check Phase 3.

□ Review Notes contain the necessary instructions. Cross-check Phase 17.

□ The reviewer is not expected to discover hidden setup requirements.

□ A reviewer-access strategy has been chosen and written down:
    `[PROVIDE REVIEWER ACCESS METHOD]`

□ If the strategy needs participants or resources, they are named and
    confirmed available:
    `[PROVIDE TEST RESOURCE / PARTICIPANTS IF REQUIRED]`

□ If the chosen strategy requires a product mechanism that does not exist
    today, record it as a **future action** and do not submit against an
    assumed mechanism.
    Note: any solo/practice/demo/bot mechanism is a product change tracked on
    the roadmap. It is out of scope for this checklist, which is documentation
    only and introduces no mechanism.

□ **A note on the app's own copy.** The Home screen already states the player
    requirement to the user before they commit to a room. Confirm the reviewer
    will see it, and do not treat it as a substitute for Review Notes.

---

# Phase 17 — App Review Information and Review Notes

**This is App Store Connect → the app version → App Review Information.**
It is **not** the TestFlight section. Phase 19 covers that.

□ Review contact name, phone number and email present and monitored.

□ **Sign-in required** toggle set correctly.
    **FACT:** Bufón has no login, so no demo account is applicable.

□ **Demo account: record the justification, not credentials.** State in the
    notes that the app has no login and that anonymous authentication signs the
    reviewer in at launch, so no demo account is needed. An empty field with no
    explanation reads as an omission; an explained one reads as deliberate.

□ **Never enter fabricated credentials, placeholder accounts that look real,
    or an access method that does not exist.**

□ Review Notes written, covering every item in the Appendix A skeleton:
    launch, whether login is required, how anonymous authentication works,
    how to reach core gameplay, the 3-player minimum, the 8-player maximum,
    what the reviewer should do, what they should expect to see, backend
    prerequisites, any special review resources, IAP instructions, and any
    limitation preventing the reviewer from independently exercising
    multiplayer.

□ Notes are concise and accurate. They describe the app as it is, not as
    intended.

□ Notes explain the multiplayer limitation **plainly**, including that a
    single reviewer cannot start a match unaided, and what the reviewer should
    do instead.

□ IAP explanation included. Cross-check Phase 18.

□ Attachment added if a walkthrough, diagram or recording would help.

□ Notes re-read against the actual build being submitted.

□ Confirm this content was entered in **App Review Information**, and not in
    TestFlight Beta App Review Information by mistake.
    Evidence: note which App Store Connect screen it was entered on.

---

# Phase 18 — In-App Purchase Reviewability (`night_pass_12h`)

**FACT.** Apple's Guideline 2.1(b): "If you offer in-app purchases in your app,
make sure they are complete, up-to-date, visible to the reviewer and functional.
If any configured in-app purchase items cannot be found or reviewed in your app,
explain the reason in your review notes."

**FACT — the current product state.** The paywall that hosts `night_pass_12h`
is presented from a single place, and only when starting a game throws
`ROOM_LOCKED`. That is thrown only after a room has used its three daily
matches, and each of those matches requires at least three players. Reaching
the in-app purchase therefore requires the multiplayer progression path.

**This is not a defect and must not be described as one.** The purchase is
configured and functional; the point is that a single reviewer following the
normal path will not naturally arrive at it. The review plan must therefore
either make the item reviewable, or clearly explain why the reviewer cannot
reach it through the normal single-reviewer path.

□ **Explain in App Review Notes how `night_pass_12h` can be reviewed, or
    explain the legitimate reason it cannot be reached through the normal
    single-reviewer path.**

□ Confirm the in-app purchase **product identifier** on the App Store Connect
    record matches the identifier the app requests.
    Evidence: App Store Connect → the app → In-App Purchases.

□ **IAP submission status** recorded (e.g. Prepare for Submission / Waiting for
    Review / Approved). Recorded **separately** from the agreement status in
    Phase 13.

□ The in-app purchase is **attached to the correct app and the correct
    version** being submitted.

□ **First non-consumable requirement:** the first non-consumable in-app
    purchase must be submitted together with a new app version. Confirm the
    version and the purchase are submitted together.

□ Paid Apps Agreement active — cross-check Phase 13, and do not treat this as
    proven by the purchase's own state.

□ Localised display name, description and price tier set.

□ Review screenshot and review notes for the in-app purchase itself provided.

□ Final sandbox / review test of the purchase performed, and the result
    recorded.
    Evidence: sandbox account used, date, and outcome.

□ Server-side receipt validation confirmed working for the build being
    submitted.

---

# Phase 19 — TestFlight Beta App Review Information

**This is the TestFlight section, and it is not App Review Information.**
Completing this phase does **not** satisfy Phase 17.

□ Determine whether TestFlight is on this release's path at all.
    **ACTION:** internal testing, external testing, both, or neither.
    This decides whether the rest of this phase applies.

□ Build uploaded.

□ Build processing complete.

□ Correct build selected for the intended tester group.

□ **Internal testing.** Team members only. Beta App Review approval is not
    required to begin internal testing.

□ **External testing.** Requires the first build to be approved by App Review
    for TestFlight before external testers can be invited. Plan for that
    review time.

□ **Beta App Review Information** completed: contact details, and beta review
    notes written **specifically for TestFlight**.

□ Beta review notes cover reviewer access and the 3–8 player requirement in
    their own words. Do not assume the App Store version's notes are visible
    here.

□ Sign-in information for beta review set correctly.
    **FACT:** no login exists, so no demo account applies. State it.

□ Test information and "What to Test" written for testers.

□ Testers assigned and invitations sent.

□ Tester access verified — at least one tester has installed and launched the
    build.

□ Backend available for the duration of the beta. Cross-check Phase 3.

□ Confirm nothing entered here was intended for App Review Information.

---

# Phase 20 — Physical-Device Validation

**This remains a separate prerequisite and is not satisfied by documentation.**
No amount of checklist completion substitutes for running the app on real
hardware. This phase is deliberately not marked complete by this checklist.

□ Complete physical-device validation before final release sign-off.

□ Release build installed on a factory-clean physical device.

□ Installed app name reads **Bufón** on iOS.

□ Installed app name reads **Bufón** on Android.

□ Clean-state reviewer journey captured end to end.

□ Three-device gameplay pass, including one device backgrounded mid-answering
    and mid-voting, with the round still advancing.

□ An exit path exists from every stream-error screen.

□ Assistive-technology pass executed against the manual accessibility
    checklist. Do not mark a row pass because the app compiles.

□ Results recorded, with device model and OS version.

Note: this work is tracked on the roadmap as its own package and currently has
its own blockers. Do not record it as done here on the strength of simulator or
emulator runs.

---

# Phase 21 — Final Release-Blocker Gate

Complete this phase last. It is the gate that answers "can we ship", and it
depends on work tracked outside this file. Consult the Master Reconciliation
for the authoritative status of each item.

□ Phases 1–20 complete for this build.

□ **Physical-device validation** complete (Phase 20).

□ **Privacy surface** requirement satisfied — App Store Connect URL and the
    in-app link (Phase 15). Tracked on the roadmap as **R-23**.

□ **Final ranking and ceremony truthfulness** resolved, or explicitly accepted
    as shipping unchanged. Tracked as **WP24**, which is blocked on decision
    **PD-4**.

□ **Reviewer-access strategy** chosen, available, and documented (Phase 16).

□ Every other still-open dependency in the Master Reconciliation reviewed and
    either closed or consciously accepted.

□ No conditional-behaviour mechanism has been introduced — no feature flags,
    remote config, allowlists, identity gates, hidden activation, or build-mode
    feature differences.
    **ACTION, open:** `docs/architecture/FEATURE_FLAGS.md` is currently a
    0-byte file. Decide whether it should exist at all, given that the absence
    of feature flags is a defensible position worth stating rather than
    leaving as an empty file. This decision is not made by this checklist.

□ Release owner signs off, with date and build number.

**Do not treat the completion of this checklist as release readiness.** The
checklist being complete means the procedure was followed. Readiness is the
state of the items above.

---

# PART III — TEMPLATES AND REFERENCE

---

# Appendix A — Review Notes skeleton

Fill every bracketed placeholder with a real value before submitting. Delete
any line that does not apply, rather than leaving it blank. **Do not invent
credentials, accounts, or an access method that does not exist.**

```
ABOUT BUFÓN
Bufón is a party game played by a group of people together, each on their
own phone.

SIGNING IN
No account or login is required. The app signs each device in anonymously
at launch. There is no username, email or password, so no demo account is
provided.

HOW TO REACH THE GAMEPLAY
1. Launch the app.
2. Enter a name and tap "Crear Sala" to create a room, or enter a room code
   and tap "Unirse" to join one.
3. The room shows a code that other players use to join.
4. The game starts once enough players have joined.

PLAYER REQUIREMENT — PLEASE READ
Bufón requires a minimum of 3 players and a maximum of 8, each on a separate
device. This is enforced by the app: a room with fewer than 3 players cannot
start a match. The Home screen states this requirement before a room is
created.

This means a single reviewer working alone cannot start a match unaided.

HOW TO REVIEW THE MULTIPLAYER EXPERIENCE
[PROVIDE REVIEWER ACCESS METHOD]
[PROVIDE TEST RESOURCE / PARTICIPANTS IF REQUIRED]

BACKEND
The app requires its backend (Firebase) to function. It is active and will
remain active for the duration of review. Please contact us if any screen
fails to load.

IN-APP PURCHASE — night_pass_12h
[EXPLAIN HOW THE REVIEWER CAN REACH AND TEST THE PURCHASE, OR EXPLAIN WHY IT
CANNOT BE REACHED ON THE NORMAL SINGLE-REVIEWER PATH]
For context: the purchase is offered when a room reaches its daily match
limit, which requires completed multiplayer matches, which in turn require
at least 3 players.

WHAT YOU SHOULD SEE
[DESCRIBE THE EXPECTED SCREENS AND OUTCOMES FOR THE PATH YOU HAVE PROVIDED]

CONTACT
[PROVIDE NAME]
[PROVIDE EMAIL]
[PROVIDE PHONE]
```

---

# Appendix B — Product facts a release owner needs

Short reference so these do not have to be re-derived at submission time. Each
is established in the project's audit and reconciliation documents.

| Fact | Detail |
|---|---|
| Player range | **3 minimum, 8 maximum.** Both enforced in `room_repository.dart` |
| Match start | A room cannot leave the lobby phase below 3 players |
| Authentication | **Anonymous only.** No email, password or credential UI exists anywhere in the app. Identity is resolved at launch |
| Solo play | **Does not exist.** No practice, demo, bot or simulation path |
| Paywall trigger | Presented only when starting a game throws `ROOM_LOCKED`, i.e. after a room's three daily matches |
| IAP reachability | `night_pass_12h` therefore sits behind 3 players × 3 completed matches |
| Ads | Google Mobile Ads initialises at launch; the ad-bearing screen is behind the same gate |
| Privacy surface | **No in-app privacy or terms link exists today.** Tracked as R-23 |
| Season banner | Renders nothing when there is no active season. That is the intended empty state, not a failure |
| Leaderboards | An empty board and a failed load are visually identical by design; disambiguate in the console, not the app |
| Build number | `pubspec.yaml` has never been incremented past `1.0.0+1` |

---

# Exit Criteria

A TestFlight build is considered successful only if:

No critical crashes.

No multiplayer blockers.

Telemetry functioning.

Analytics functioning.

Crashlytics functioning.

Meaningful tester feedback received.

An App Store submission is considered ready to send only if Phase 21 is
complete and signed off.

---

# Golden Rule

Never ask testers to discover problems that engineering could have detected
before shipping the build.

The same rule applies to App Review. Never ask a reviewer to discover a setup
requirement that the Review Notes could have stated.
