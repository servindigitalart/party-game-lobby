# BETA_READINESS.md

> Definition of Done for every Bufón Beta build.
>
> A build that does not satisfy this document must not be distributed through
> TestFlight or Google Play Internal Testing.

---

# Philosophy

A beta is not an unfinished product.

A beta is a stable product used to discover unknown issues under real-world conditions.

The purpose of beta testing is to validate behavior, not to debug obvious defects.

---

# Beta Goals

Every beta build should help answer one or more of the following questions:

- Does multiplayer remain synchronized?
- Are players able to complete matches?
- Are crashes occurring?
- Are reconnects working correctly?
- Is telemetry complete?
- Are analytics events being generated?
- Does the UI behave correctly across devices?
- Is the experience enjoyable?

If a build cannot answer at least one meaningful question, it should not be released.

---

# Build Requirements

Before releasing a build:

- Flutter analyze passes.
- Flutter test passes.
- No known fatal crashes.
- No broken navigation.
- Firebase initializes successfully.
- Firestore rules are deployed.
- Crashlytics initialized.
- Analytics initialized.
- Logging initialized.

---

# Multiplayer Validation

The following scenarios must work correctly:

Create room.

Join room.

Leave room.

Reconnect.

Host disconnects.

Host rejoins.

Player disconnects.

Player rejoins.

Room closes correctly.

Multiple players synchronize correctly.

No duplicated players.

No ghost rooms.

---

# Gameplay Validation

Verify:

Lobby works.

Countdown works.

Round transition works.

Voting works.

Results work.

Winner screen works.

Game restart works.

Return to home works.

---

# UI Validation

Verify on supported devices:

No overflow.

No clipped widgets.

No missing assets.

No broken animations.

No unreadable text.

No layout jumps.

Safe Area respected.

Dark mode (future).

Landscape behavior (if supported).

---

# Telemetry Validation

Verify:

Telemetry events generated.

Session context attached.

Performance metrics collected.

Breadcrumbs generated.

Structured logs generated.

No duplicated events.

---

# Analytics Validation

Verify:

Session events.

Room events.

Gameplay events.

Retention events.

Performance events.

No invalid parameters.

No duplicated analytics.

---

# Crashlytics Validation

Verify:

Flutter errors captured.

Platform errors captured.

Unhandled exceptions captured.

Breadcrumbs visible.

Custom Keys populated.

Fatal crashes reported.

Recoverable exceptions reported.

---

# Firestore Validation

Verify:

Indexes deployed.

Rules deployed.

Reads succeed.

Writes succeed.

Listeners reconnect.

Transactions succeed.

Offline recovery behaves correctly.

---

# Performance Validation

Measure:

App launch time.

Room creation time.

Room join time.

Round transition.

Firestore latency.

Reconnect duration.

Frame stability.

Memory usage.

CPU usage (future).

---

# Device Validation

Current supported devices:

Latest iPhone

Previous generation iPhone

Large iPhone

Android flagship

Android mid-range

Tablet (future)

Mac (future)

---

# Network Validation

Verify under:

Wi-Fi

5G

LTE

Poor connection

Temporary disconnect

Reconnect

Offline recovery

---

# Accessibility

Minimum requirements:

Readable typography.

Large touch targets.

VoiceOver compatibility (future).

Dynamic Type (future).

Color contrast.

---

# Regression Testing

Verify previously fixed issues remain fixed.

Never assume an old bug stays fixed.

Regression testing is mandatory.

---

# Known Issues

Every beta release should include:

Open issues.

Known limitations.

Workarounds.

Expected behavior.

This prevents duplicate bug reports.

---

# Tester Instructions

Every beta release must explain:

What changed.

What should be tested.

Known issues.

How to report bugs.

Expected duration.

---

# Release Criteria

A build is Beta Ready only if:

No blocking issues.

Core multiplayer works.

No reproducible crashes.

Telemetry functioning.

Crashlytics functioning.

Analytics functioning.

Firestore functioning.

Build signed successfully.

---

# Blockers

The following automatically block a release:

Firebase initialization failure.

Room synchronization failure.

Host cannot start game.

Players cannot join.

Crash on launch.

Corrupted Firestore writes.

Broken navigation.

---

# Exit Criteria

The beta phase ends when:

Crash-free sessions exceed target.

Major gameplay bugs resolved.

Reconnect reliability acceptable.

Telemetry stable.

Analytics trusted.

Testers report no blocking issues.

---

# Definition of Done

A build is considered Beta Ready when:

✓ Stable

✓ Observable

✓ Measurable

✓ Reproducible

✓ Testable

✓ Deployable

If any of these are false, the build is not ready.

---

# Golden Rule

Never ship a build because it "probably works."

Ship a build because it has been verified.