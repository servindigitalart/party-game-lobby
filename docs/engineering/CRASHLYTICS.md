# CRASHLYTICS.md

> Crash reporting specification for Bufón.
>
> A crash report without context is considered an incomplete bug report.
>
> Every crash must provide enough information to reproduce the issue.

---

# Philosophy

Crashlytics is not only for crashes.

It is the central system for understanding unexpected behavior during production and beta testing.

Every unexpected exception should produce enough information to reconstruct the player's session.

---

# Goals

The crash reporting system must answer:

- Who crashed?
- Where did the crash happen?
- What was happening?
- What room was active?
- What game state existed?
- What action triggered the failure?
- Can we reproduce it?

---

# Architecture

Application

↓

CrashReporter

↓

CrashBackend

↓

Firebase Crashlytics

↓

Firebase Console

No Widget should communicate directly with Firebase Crashlytics.

Only CrashReporter owns crash reporting, and only the backend owns
Crashlytics. Firebase is the first backend, not the architecture — see
"Implementation" below.

---

# CrashReporter

Every crash must pass through a centralized service.

Example API

recordError()

recordFatal()

recordWarning()

recordFlutterError()

recordPlatformError()

The rest of the application never talks directly to Firebase.

---

# Error Types

Fatal

Application terminated.

Example

Uncaught exception.

---

Recoverable

Operation failed.

Application continues.

Example

Firestore write failed.

---

Unexpected

Logic reached an impossible state.

Should be investigated.

---

Ignored

Known platform issues.

Must be documented.

---

# Custom Keys

Every report should automatically include:

Session ID

Player ID

Player Name

Room Code

Host ID

Current Screen

Current Route

Current Round

Current Question

Current Game State

Player Count

Platform

OS Version

App Version

Build Number

Locale

Timezone

Network Status

Firebase UID

These keys should be automatically maintained by GameTelemetryService.

---

# Breadcrumbs

Every important action should generate a breadcrumb.

Examples

App Opened

Home Opened

Room Created

Room Joined

Lobby Ready

Host Started Match

Round Started

Player Submitted Vote

Winner Calculated

Player Disconnected

Reconnect Attempt

Reconnect Success

Room Closed

Crash

The goal is to reconstruct the last minutes before failure.

---

# Context

Every report should include:

Current Screen

Current Feature

Repository

Controller

Provider

Current Match

Current Round

Current Timer

Current Players

Current Host

Current Network

---

# Firestore Context

If the crash is related to Firestore include:

Collection

Document

Operation

Latency

Retry Count

Snapshot Active

Offline Cache

Pending Writes

---

# Networking Context

Include:

Connection Type

Offline

Reconnect Count

Connection Quality

Latency

---

# Device Context

Automatically include:

Platform

Model

OS Version

Screen Size

Locale

Timezone

App Version

Build Number

---

# User Context

Only include information useful for debugging.

Allowed

Player Name

Player ID

Host

Room Code

Forbidden

Passwords

Email

Authentication Tokens

Payment Information

Private Messages

---

# Fatal Errors

Fatal crashes must always include:

Stack Trace

Breadcrumbs

Session Context

Device Context

Current Screen

Last Action

Current Room

Current Round

Build Information

---

# Non Fatal Errors

Recoverable errors should also be recorded when they represent bugs.

Examples

Firestore transaction failed

Snapshot unexpectedly closed

Repository inconsistency

Animation state corruption

Room synchronization failure

---

# Flutter Errors

Capture:

FlutterError.onError

PlatformDispatcher.instance.onError

runZonedGuarded

These should all delegate to CrashReporter.

---

# Categorization

Every report should belong to one category.

UI

Navigation

Firebase

Firestore

Networking

Room

Voting

Gameplay

Analytics

Monetization

Ads

Purchases

System

Unknown

---

# Severity

Critical

Major

Minor

Informational

Severity helps prioritize bug fixing.

---

# Attachments

Future versions may attach:

Structured logs

Telemetry timeline

Network diagnostics

Performance metrics

Never attach personal information.

---

# Beta Builds

Beta builds should capture additional information.

Verbose breadcrumbs

Additional debug keys

Feature Flags

Experimental Features

Debug Overlay State

This additional context should be disabled in Release builds.

---

# Privacy

Bufón follows the principle of minimum required information.

Collect only information required for debugging.

Never collect personal conversations.

Never collect payment information.

Never collect authentication secrets.

---

# Integration

CrashReporter integrates with:

Firebase Crashlytics

GameTelemetryService

AppLogger

AnalyticsService

FeatureFlags

Debug Overlay

Each service contributes context.

---

# Validation

Before every release verify:

CrashReporter initialized.

Flutter errors captured.

Platform errors captured.

Fatal errors captured.

Recoverable errors captured.

Custom Keys populated.

Breadcrumbs generated.

No sensitive information recorded.

---

# Future Improvements

Crash grouping

Automatic issue fingerprinting

Export diagnostics

Session replay metadata

Offline crash queue

Crash dashboard

---

# Implementation

`lib/core/crash/` is the concrete implementation of this specification.

Files

crash_reporter.dart

crash_backend.dart

firebase_crashlytics_backend.dart

crash_log_destination.dart

`package:firebase_crashlytics` is imported by exactly one file,
`firebase_crashlytics_backend.dart`. Adding Sentry, Bugsnag or Datadog means
writing a sibling of that class and changing the one line in `main.dart` that
constructs it.

## Public API

initialize() · guard() · attachBackend()

recordError() · recordFatal() · recordNonFatal() · recordAssertion() ·
recordFlutterError()

setUser() · clearUser()

setCustomKey() · removeCustomKey()

log()

## Categorization and Severity

CrashReporter reuses `AppLogCategory` and `AppLogLevel` rather than declaring
parallel crash-only enums, matching the decision recorded in
docs/telemetry/TELEMETRY_SPEC.md. The category list in this document is
covered by `AppLogCategory` (`ui` and `unknown` were added for it). Severity
maps as:

fatal, critical → Critical

error → Major

warning → Minor

info, debug, trace → Informational

## Custom Keys

Keys are not set by hand. CrashReporter reads `AppLogger.currentContext` — the
merged output of every attached context provider — and pushes the difference
to the backend before every report and breadcrumb. Today that means
GameTelemetryService's Session Context and device context; a future
Authentication or Performance provider is picked up with no change here.

Keys are refreshed on every breadcrumb, so a native crash the Dart layer never
observes still carries the room, session and screen the player was in.

Manual keys go through `setCustomKey(CrashKeyDomain, name, value)` and become
`domain_name`. The domain enum (session, room, player, game, device, network,
build, firebase, ui) is what stops the key list from sprawling.

## Breadcrumbs

Breadcrumbs are not instrumented separately. `CrashLogDestination` listens to
AppLogger and forwards:

Telemetry event, any level → breadcrumb

Plain log, WARNING and above → breadcrumb

TRACE / DEBUG / INFO without a telemetry event → ignored

ERROR and CRITICAL → non-fatal report

FATAL → fatal report

Every event GameTelemetryService already emits therefore becomes a breadcrumb
for free. Instrumenting a feature for breadcrumbs means adding telemetry to
it, never calling CrashReporter directly.

## Fatality

Framework errors arriving on `FlutterError.onError` are recorded as
**non-fatal**. The previous implementation used
`recordFlutterFatalError`, which marked every layout overflow as a crash and
distorted crash-free-sessions. Only `PlatformDispatcher.onError` and the
guarded zone produce fatal reports.

## Startup ordering

`initialize()` installs the global handlers before Firebase starts and buffers
reports (capped at 100) until `attachBackend()` flushes them. Failures during
Firebase initialization — previously unreported, because the handlers were
installed after it — are now captured.

## Not yet implemented

Device model, screen size and timezone context (no device_info dependency).

App version and build number (no build-metadata dependency); their keys exist
and populate automatically once a provider supplies them.

Firestore and networking context blocks; the keys are available through
`setCustomKey(CrashKeyDomain.network, ...)` but nothing populates them yet.

Beta-only verbose keys and feature flags.

Offline crash queue beyond what the Crashlytics SDK already does.

---

# Golden Rule

Every crash should be reproducible from its report.

If an engineer cannot understand why the application crashed using the available information,

the crash reporting system is incomplete.