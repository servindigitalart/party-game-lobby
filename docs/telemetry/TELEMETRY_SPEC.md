# TELEMETRY_SPEC.md

> Unified telemetry specification for Bufón.
>
> Telemetry is the central nervous system of the application.
>
> Every meaningful action inside the game should become observable through a
> single pipeline.

---

# Philosophy

Telemetry is not logging.

Telemetry is not analytics.

Telemetry is not crash reporting.

Telemetry is the unified event stream from which all observability systems are built.

One event.

Multiple destinations.

---

# Objectives

Telemetry should answer:

What happened?

Who did it?

Where?

When?

How long did it take?

Was it successful?

Can we reproduce it?

Can we measure it?

---

# High Level Architecture

Application

↓

GameTelemetryService

↓

TelemetryEvent

↓

────────────────────────────────────────

Talker

CrashReporter

AnalyticsService

Performance Monitor

Future Session Replay

Future Debug Overlay

────────────────────────────────────────

Every system consumes the same event.

No feature should emit duplicated events.

---

# Single Event Philosophy

A feature should emit exactly one event.

Example

Player joins room

↓

GameTelemetryService.track()

↓

Talker

↓

Firebase Analytics

↓

Crashlytics Breadcrumb

↓

Performance Timeline

↓

Future Replay

The feature itself should not know where the event goes.

---

# Core Components

GameTelemetryService

TelemetryEvent

TelemetryContext

TelemetryDispatcher

TelemetryDestination

EventFactory

---

# Event Lifecycle

Action

↓

TelemetryEvent Created

↓

Context Attached

↓

Timestamp Added

↓

Dispatch

↓

Destinations

↓

Stored

---

# TelemetryEvent

Every event contains:

Event ID

Timestamp

Category

Action

Status

Duration

Severity

Session Context

Payload

Metadata

---

# Session Context

Automatically attached:

Session ID

Room Code

Player ID

Player Name

Host ID

Current Round

Current Question

Current Screen

Game State

Platform

OS Version

Device Model

Locale

Timezone

App Version

Build Number

Network Status

Battery Level (future)

Memory Usage (future)

---

# Categories

Application

Authentication

Room

Lobby

Gameplay

Voting

Round

Networking

Firestore

Analytics

Crashlytics

Performance

Ads

Purchases

UI

Animation

System

Developer

---

# Status

Started

Succeeded

Failed

Cancelled

Retried

Timeout

Recovered

Ignored

---

# Severity

Trace

Debug

Info

Warning

Error

Critical

Fatal

---

# Destinations

Current

Talker

Firebase Analytics

Firebase Crashlytics

Future

BigQuery

Grafana

Session Replay

Developer Overlay

Remote Dashboard

---

# Performance Tracking

Every event may include:

Start Time

End Time

Duration

Network Latency

Firestore Reads

Firestore Writes

Retries

Animation Time

Frame Time

---

# Correlation IDs

Every related event shares the same correlation ID.

Example

Create Room

↓

Firestore Write

↓

Snapshot Received

↓

Lobby Opened

↓

Players Joined

↓

Match Started

Entire flow can be reconstructed.

---

# Event Naming

Use snake_case.

Examples

room_created

player_joined

host_changed

match_started

vote_submitted

round_finished

room_closed

Never abbreviate.

---

# Payload Rules

Payloads should contain only feature-specific data.

Shared information belongs in Session Context.

Bad

room_code

host

player

platform

inside every payload.

Good

Payload

vote_target

vote_type

Shared context handled automatically.

---

# Sampling

Never sample:

Errors

Crashes

Warnings

Room lifecycle

Gameplay

May sample:

Debug telemetry

Performance metrics

Verbose traces

Sampling rules should be configurable.

---

# Privacy

Never transmit:

Passwords

Tokens

Emails

Phone numbers

Payment information

Private messages

Personal contacts

Telemetry is gameplay-oriented.

---

# Offline Support

Telemetry should survive temporary disconnects.

Queue events.

Retry automatically.

Preserve timestamps.

Maintain ordering whenever possible.

---

# Failure Strategy

Telemetry failures must never affect gameplay.

If Analytics fails

↓

Game continues.

If Crashlytics fails

↓

Game continues.

If Logging fails

↓

Game continues.

Telemetry is passive.

---

# Debug Overlay

Future builds may display:

Current Session

Room Code

Round

FPS

Firestore Latency

Network

Current Event

Queue Size

Last Error

Current Provider Updates

This overlay must never ship enabled in production.

---

# Session Timeline

A complete session should look like:

App Open

↓

Session Started

↓

Room Created

↓

Players Joined

↓

Lobby Ready

↓

Match Started

↓

Round 1

↓

Voting

↓

Reveal

↓

Winner

↓

Play Again

↓

Session End

This timeline should be reconstructable from telemetry alone.

---

# Integration Rules

Features never communicate directly with:

Talker

Firebase Analytics

Crashlytics

BigQuery

Future dashboards

Everything goes through GameTelemetryService.

---

# Validation

Before merging a feature verify:

Meaningful events exist.

Duplicate events do not exist.

Payload is minimal.

Session Context is attached.

Errors generate telemetry.

Performance metrics are correct.

No sensitive information exists.

---

# Future Extensions

Live telemetry dashboard

Heatmaps

Session replay

Latency visualization

Realtime developer console

Cloud diagnostics

Automatic anomaly detection

AI-assisted bug clustering

Predictive crash detection

---

# Golden Rule

Every important gameplay action should produce exactly one telemetry event.

From that single event, every observability system should receive the information it needs.

Never emit the same event twice.