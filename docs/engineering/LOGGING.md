# LOGGING.md

> Official logging specification for Bufón.
>
> Logging is considered a first-class engineering system.
>
> Every important action inside the application must be observable.

---

# Philosophy

Logs are not debugging tools.

Logs are part of the product.

A complete log should allow an engineer to reconstruct an entire multiplayer session without reproducing the issue.

Logs exist to answer:

- What happened?
- Why did it happen?
- Who triggered it?
- What was the application state?
- What happened immediately before?
- Was the operation successful?

---

# Logging Layers

The application produces logs at multiple layers.

UI

↓

Controllers

↓

Repositories

↓

Firebase Services

↓

Platform

↓

Crashlytics

Each layer provides different context.

---

# Log Levels

Use only the following levels.

TRACE

Very detailed information.

Only enabled during development.

---

DEBUG

Useful information for developers.

Disabled in production.

---

INFO

Normal application events.

Examples:

Room created

Player joined

Vote submitted

Round started

Host transferred

---

WARNING

Unexpected but recoverable situations.

Examples:

Reconnect

Missing optional field

Slow network

Retry

---

ERROR

Operation failed.

Application continues running.

Examples:

Firestore write failed

Analytics event rejected

Snapshot listener cancelled

---

CRITICAL

Severe failure. Application is in a degraded state but does not require
termination.

Examples:

Room state corrupted but recoverable

Repeated Firestore transaction failures

---

FATAL

Application cannot continue safely.

Crash expected.

Must always reach Crashlytics.

---

# Log Structure

Every log should contain:

Timestamp

Level

Category

Action

Result

Context

Message

Example

INFO

Room

CreateRoom

Success

RoomCode=ABCD12

Host=John

Duration=134ms

---

# Categories

Every log belongs to one category.

App

Navigation

Authentication

Room

Player

Round

Voting

Firestore

Firebase

Analytics

Crashlytics

Networking

Performance

Ads

Purchases

Audio

Animation

System

---

# Session Context

Every log automatically inherits the current session.

Current Session includes:

Session ID

Player ID

Player Name

Room Code

Host ID

Current Round

Current Question

Game State

App Version

Build Number

Platform

OS Version

Device Model

Locale

Timezone

Network Status

No log should manually duplicate this information.

---

# Navigation Logging

Every screen transition should generate an INFO log.

Example

Home

↓

Lobby

↓

Voting

↓

Winner

↓

Results

This makes it possible to reconstruct the user journey.

---

# User Actions

Every meaningful user action should generate an INFO log.

Examples

Create Room

Join Room

Leave Room

Start Match

Vote

Reveal

Play Again

Reconnect

Disconnect

Copy Room Code

Share Invite

---

# Firestore Logging

Every repository operation should log:

Collection

Document

Operation

Latency

Result

Retries

Examples

Read

Write

Update

Delete

Transaction

Batch

Snapshot

---

# Performance Logging

Important operations should measure execution time.

Examples

Firestore reads

Firestore writes

Room creation

Room join

Round transition

Winner calculation

Animations over 300ms

---

# Network Logging

Record:

Connection lost

Connection restored

Offline mode

Retry count

Timeout

Snapshot interruption

---

# Error Logging

Every unexpected exception should include:

Exception Type

Message

Stack Trace

Operation

Current Screen

Current Session

Repository

Platform

Errors should never disappear silently.

---

# Privacy

Never log:

Passwords

Authentication tokens

Email addresses

Phone numbers

Payment information

Personal conversations

Only log information necessary for debugging.

---

# Production Logging

Production logs should prioritize:

Errors

Warnings

Important business events

Development-only logs should remain disabled.

---

# Debug Logging

Development builds may enable:

Verbose Firestore logs

Widget lifecycle logs

Provider updates

Performance timing

These should never affect release performance.

---

# Log Ownership

Every major feature must define:

What events it logs

Which level it uses

What context it requires

Features without observability are considered incomplete.

---

# Integration

AppLogger (`lib/core/logging/app_logger.dart`) is the concrete implementation
of this specification, backed internally by Talker. No other layer of the
application may import Talker directly — only AppLogger knows it exists, so
the underlying engine can change without touching call sites.

Current categories implemented (`lib/core/logging/log_category.dart`): App,
Navigation, Room, Player, Gameplay, Voting, Firestore, Firebase, Analytics,
Crashlytics, Network, Performance, System. This is a minimum set; the
categories above (Authentication, Round, Ads, Purchases, Audio, Animation,
Networking) will be added as their owning features are implemented.

The logging system will integrate with:

Talker

Firebase Crashlytics

Firebase Analytics

GameTelemetryService

Debug Overlay

Future Export Logs feature

The logging API should remain independent of the implementation.

---

# Validation

Before merging any feature, verify:

Important actions are logged.

Errors are logged.

No sensitive information is logged.

Logs remain readable.

No duplicate logs exist.

---

# Golden Rule

If a multiplayer issue cannot be reconstructed from the logs,
the logging system is incomplete.