# ARCHITECTURE.md

> Technical architecture of Bufón.
>
> This document describes how the project is organized.
>
> Read this before introducing new services, repositories or state.

---

# Tech Stack

Framework

Flutter

Language

Dart

State Management

Riverpod

Backend

Firebase

Database

Cloud Firestore

Authentication

Firebase Auth

Crash Reporting

Firebase Crashlytics

Analytics

Firebase Analytics

Version Control

Git

CI/CD

Xcode Cloud (planned)

Android CI

GitHub Actions (future)

---

# High Level Architecture

The application follows a layered architecture.

UI

↓

Controllers / Providers

↓

Repositories

↓

Firebase Services

↓

Firestore

Widgets should never communicate directly with Firestore.

All business logic belongs outside the UI.

---

# Folder Structure

Current high-level organization:

lib/

core/

models/

repositories/

services/

providers/

controllers/

screens/

widgets/

analytics/

theme/

The exact implementation may evolve, but this separation should be preserved.

---

# Responsibilities

## Screens

Responsible for:

Navigation

Layout

Displaying state

Listening to Providers

Never:

Contain business logic

Contain Firestore logic

Contain analytics logic

---

## Widgets

Reusable UI components.

Should be stateless whenever possible.

Small.

Composable.

Reusable.

---

## Providers

Expose application state.

Coordinate repositories.

Should not know about UI.

---

## Controllers

Coordinate user actions.

Validate inputs.

Trigger repositories.

Trigger telemetry.

Controllers should remain lightweight.

---

## Repositories

Repositories abstract data sources.

Examples:

RoomRepository

PlayerRepository

GameRepository

Repositories own data access.

Repositories should not know about Widgets.

---

## Firebase Services

Responsible only for Firebase APIs.

Firestore

Analytics

Crashlytics

Authentication

Messaging (future)

App Check (future)

---

# Firestore

Firestore is the single source of truth.

Never duplicate room state locally.

Realtime listeners should drive UI updates.

Prefer Streams over polling.

---

# Room Lifecycle

Create Room

↓

Room Document Created

↓

Host Joins

↓

Players Join

↓

Lobby

↓

Game Starts

↓

Rounds

↓

Game Ends

↓

Room Closes

Every transition must be deterministic.

---

# State Flow

User Action

↓

Controller

↓

Repository

↓

Firestore

↓

Snapshot Listener

↓

Provider

↓

UI

The UI should react to state changes.

Never manually synchronize UI state when Firestore already provides it.

---

# Dependency Rules

Allowed:

Screen

↓

Provider

↓

Repository

↓

Service

Forbidden:

Screen → Firestore

Widget → Firestore

Widget → Analytics

Widget → Crashlytics

Screen → Repository without Provider (unless justified)

Circular dependencies.

---

# Analytics

Firebase Analytics is a destination, not a service features call.

`AnalyticsDestination` (`lib/analytics/`) consumes telemetry events from
AppLogger and translates them through a mapping registry. It is the only file
importing `firebase_analytics`.

Gameplay emits one telemetry event; Talker, CrashReporter and Firebase
Analytics all consume that same event.

Analytics must never modify business logic.

Logging must never change app behavior.

Telemetry is passive.

See docs/engineering/ANALYTICS.md.

---

# Crashlytics

`CrashReporter` (`lib/core/crash/`) is the single entry point for every error.

It talks to a `CrashBackend`; `FirebaseCrashlyticsBackend` is the first
implementation and the only file importing `firebase_crashlytics`.

Crash reporting should receive:

Unhandled exceptions

Fatal errors

Important custom keys

Important breadcrumbs

Custom keys come from AppLogger's context providers and breadcrumbs from
telemetry events, so features contribute both without calling CrashReporter.

Never send personal information.

See docs/engineering/CRASHLYTICS.md.

---

# Telemetry

`GameTelemetryService` (`lib/core/telemetry/`) is the single source of truth
for gameplay telemetry.

Meaningful gameplay actions emit one `TelemetryEvent` through it. The event is
handed to `AppLogger`, which fans it out to every registered
`AppLogDestination`. Telemetry does not own a separate dispatcher.

Controllers, repositories and services call GameTelemetryService.

They never call Talker, Firebase Analytics or Crashlytics directly.

GameTelemetryService owns Session Context and registers it with AppLogger, so
every log entry inherits session, room and device information automatically.

See docs/telemetry/TELEMETRY_SPEC.md.

---

# Logging

Logging should exist at every architectural layer.

Example:

UI

↓

Controller

↓

Repository

↓

Firebase

Every important transition should be traceable.

---

# Navigation

Navigation should remain predictable.

Screens should receive only the data they need.

Avoid global mutable state.

---

# Performance

Avoid rebuilding complete screens.

Prefer small Consumers.

Prefer immutable models.

Prefer const widgets.

Minimize Firestore reads.

Batch writes whenever possible.

---

# Error Handling

Repositories return domain errors.

Controllers decide recovery.

UI displays friendly messages.

Unexpected exceptions should reach Crashlytics.

---

# Scalability Goals

The architecture should comfortably support:

100+ screens

Multiple game modes

Seasonal events

Offline improvements

Cloud Functions

AI-powered features

Without major rewrites.

---

# Golden Rule

If a feature requires bypassing the architecture,
the architecture should be improved,
not ignored.