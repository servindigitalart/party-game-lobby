# CODING_STANDARD.md

> Official engineering standards for Bufón.
>
> Every contributor and every AI assistant must follow these conventions.
>
> Consistency is more important than personal preference.

---

# General Philosophy

Write code that is:

- Simple
- Predictable
- Readable
- Testable
- Maintainable

Future maintainability always wins over clever code.

---

# Language

Use modern Dart.

Prefer null safety.

Avoid deprecated APIs.

Never suppress warnings unless absolutely necessary.

---

# File Organization

One responsibility per file.

Avoid files larger than ~500 lines whenever possible.

Split large widgets into smaller widgets.

Split large services into focused services.

---

# Naming

## Classes

PascalCase

Examples

RoomRepository

AnalyticsService

GameController

PlayerModel

---

## Variables

camelCase

Examples

playerName

roomCode

currentRound

hostId

---

## Constants

camelCase for static constants.

Avoid global constants unless truly global.

---

## File Names

snake_case.dart

Examples

room_repository.dart

analytics_service.dart

home_screen.dart

animated_primary_button.dart

---

# Widgets

Prefer StatelessWidget.

Only use StatefulWidget when local mutable state is required.

Extract reusable UI.

Never duplicate widget trees.

Keep build() methods readable.

---

# Build Methods

Avoid deeply nested widget trees.

Extract private widgets when needed.

Prefer composition.

Example

Instead of

_buildPlayerCard()

Prefer

PlayerCard()

when reusable.

---

# State Management

Riverpod is the only state management solution.

Do not introduce:

Provider

Bloc

Redux

MobX

GetX

unless explicitly approved.

---

# Providers

Providers expose state.

Providers do not contain UI.

Providers should remain lightweight.

Avoid provider chains that are difficult to understand.

---

# Controllers

Controllers coordinate actions.

Controllers validate.

Controllers trigger repositories.

Controllers never build UI.

---

# Repositories

Repositories own data access.

Repositories hide Firebase implementation details.

Repositories should expose domain methods.

Example

createRoom()

joinRoom()

leaveRoom()

instead of exposing raw Firestore operations.

---

# Firebase

Never call Firestore directly from Widgets.

Never call Firestore directly from Screens.

Always go through repositories.

---

# Analytics

Never call FirebaseAnalytics directly.

Always use AnalyticsService.

Every analytics event must have a meaningful name.

Avoid noisy analytics.

---

# Crashlytics

Never call Crashlytics directly.

Always use CrashReporter.

Every unexpected exception should be recorded.

Never record personal information.

---

# Logging

Never use print().

Never use debugPrint() for business logic.

Always use AppLogger.

Use structured logging.

Every log should answer:

Who?

What?

Where?

Result?

---

# Error Handling

Never ignore exceptions.

Never leave empty catch blocks.

Prefer domain-specific exceptions.

Unexpected errors should reach Crashlytics.

---

# Async Code

Always await asynchronous operations unless intentionally detached.

Avoid nested Futures.

Avoid callback pyramids.

Prefer async / await.

---

# Streams

Cancel every StreamSubscription.

Dispose listeners.

Avoid duplicate listeners.

Prefer one source of truth.

---

# Timers

Dispose every Timer.

Never leave periodic timers running after screen disposal.

---

# Animation Controllers

Always dispose AnimationController.

Always dispose TabController.

Always dispose TextEditingController.

Always dispose FocusNode.

---

# Models

Models should be immutable whenever possible.

Prefer copyWith().

Avoid mutable shared state.

---

# Firestore Models

Centralize serialization.

Avoid duplicated fromJson implementations.

Avoid duplicated toJson implementations.

---

# Testing

Every feature should be testable.

Bug fixes should include regression tests whenever practical.

Avoid hidden state.

Avoid side effects.

---

# Comments

Comment why.

Not what.

Bad

// increment counter

Good

// Prevent duplicate room creation during reconnect.

---

# TODOs

Use

TODO(username):

Example

TODO(emilio):

Remove legacy room migration after Beta.

---

# Commits

Keep commits focused.

Good

feat: add telemetry service

fix: prevent duplicate room joins

refactor: simplify room repository

Bad

misc changes

update

fix stuff

---

# Pull Requests

One concern per PR.

Avoid mixing:

UI

Architecture

Analytics

Bug fixes

Refactors

in the same PR.

---

# Performance

Prefer const constructors.

Avoid unnecessary rebuilds.

Avoid expensive work inside build().

Memoize when appropriate.

Reduce Firestore reads.

Batch writes.

---

# Documentation

Major architectural changes must update:

Architecture.md

Project Context

Roadmap

Relevant engineering documents

Documentation is part of the implementation.

---

# Validation Checklist

Before every commit:

- flutter analyze
- flutter test
- Verify no new warnings
- Verify no duplicated logic
- Verify documentation if architecture changed

---

# Golden Rule

Code should be understandable by another engineer in six months without additional explanation.

If the code requires extensive explanation, simplify it.