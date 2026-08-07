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

Firebase Crashlytics

↓

Firebase Console

No Widget should communicate directly with Firebase Crashlytics.

Only CrashReporter owns Crashlytics.

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

# Golden Rule

Every crash should be reproducible from its report.

If an engineer cannot understand why the application crashed using the available information,

the crash reporting system is incomplete.