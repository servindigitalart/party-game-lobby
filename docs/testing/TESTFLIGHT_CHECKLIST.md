# TESTFLIGHT_CHECKLIST.md

> Operational checklist for every TestFlight release.
>
> This checklist must be completed before submitting any build.

---

# Purpose

The objective is to guarantee that every external tester receives a stable,
observable and debuggable build.

Skipping checklist items is not allowed.

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

# Exit Criteria

A TestFlight build is considered successful only if:

No critical crashes.

No multiplayer blockers.

Telemetry functioning.

Analytics functioning.

Crashlytics functioning.

Meaningful tester feedback received.

---

# Golden Rule

Never ask testers to discover problems that engineering could have detected before shipping the build.