# AGENTS.md

> Entry point for AI agents working on Bufón.
>
> This document defines how AI assistants must operate inside this repository.
>
> Read this file before making any code changes.

---

# Project

Name

Bufón

Type

Realtime multiplayer party game

Primary Platform

Flutter

Backend

Firebase

Database

Cloud Firestore

Current Phase

Private Beta

---

# Mission

Your objective is not to generate the most code.

Your objective is to improve the project while preserving:

- Stability
- Multiplayer synchronization
- Maintainability
- Observability
- Code quality

Correctness always has priority over speed.

---

# Required Reading Order

Before making any modification, read the following documents in order.

1.

docs/ai/PROJECT_CONTEXT.md

2.

docs/architecture/ARCHITECTURE.md

3.

docs/engineering/CODING_STANDARD.md

4.

docs/engineering/LOGGING.md

5.

docs/engineering/CRASHLYTICS.md

6.

docs/engineering/ANALYTICS.md

7.

docs/telemetry/TELEMETRY_SPEC.md

8.

docs/testing/BETA_READINESS.md

9.

docs/testing/TESTFLIGHT_CHECKLIST.md

10.

docs/ai/AI_OPERATING_MANUAL.md

Never skip this step.

---

# Architecture Rules

Never access Firestore directly from UI.

Never duplicate business logic.

Never duplicate repositories.

Never introduce a second implementation of an existing feature.

Prefer extending existing services.

Respect Riverpod architecture.

Keep widgets lightweight.

---

# Coding Rules

Every change should:

Compile.

Pass flutter analyze.

Pass flutter test.

Avoid regressions.

Maintain documentation.

Keep commits focused.

---

# Documentation Rules

If architecture changes:

Update:

ARCHITECTURE.md

PROJECT_CONTEXT.md

Relevant engineering documents.

Documentation is part of the implementation.

---

# Observability Rules

Every important feature should integrate with:

AppLogger

GameTelemetryService

CrashReporter

Firebase Analytics

Firebase Crashlytics

If a feature cannot be observed, it is considered incomplete.

---

# Multiplayer Rules

Bufón is a realtime multiplayer application.

Protect synchronization above everything else.

Never introduce race conditions.

Never trust client state when Firestore is the source of truth.

Room consistency has priority over animations and visual polish.

---

# Preferred Workflow

Understand

↓

Read documentation

↓

Inspect existing implementation

↓

Design solution

↓

Implement

↓

Run flutter analyze

↓

Run flutter test

↓

Update documentation

↓

Commit

Never skip validation.

---

# Commit Convention

Examples

feat: add room reconnect telemetry

fix: prevent duplicate player joins

refactor: simplify voting controller

docs: update telemetry specification

Avoid generic commit messages.

---

# Pull Request Philosophy

One concern per PR.

Do not mix:

Architecture

Refactoring

Bug fixes

UI

Telemetry

Analytics

Unless explicitly requested.

---

# Performance Principles

Prefer:

const widgets

small rebuilds

composition

immutable models

Riverpod best practices

Avoid:

deep widget trees

duplicate listeners

duplicate providers

expensive build methods

unnecessary Firestore reads

---

# Error Handling

Never ignore exceptions.

Never leave empty catch blocks.

Recover when possible.

Unexpected exceptions should reach CrashReporter.

---

# Beta Philosophy

Current priority:

Product stability

Telemetry

Crash reporting

Analytics

Testing

Not feature quantity.

---

# Definition of Success

A task is complete only if:

✓ Code compiles

✓ Analyze passes

✓ Tests pass

✓ Documentation updated (when applicable)

✓ Logging added

✓ Telemetry added

✓ Analytics considered

✓ Crash reporting considered

✓ No duplicated logic introduced

---

# Repository Philosophy

This repository should remain understandable by both humans and AI.

Clarity is preferred over cleverness.

Maintainability is preferred over speed.

Consistency is preferred over personal style.

---

# Golden Rule

When in doubt:

Stop.

Read the documentation.

Understand the architecture.

Then modify the code.