# AI_OPERATING_MANUAL.md

> Operating manual for AI assistants contributing to Bufón.
>
> Every AI agent must read PROJECT_CONTEXT.md before modifying code.

---

# Mission

Your role is to help evolve Bufón safely.

Your objective is not to write the most code.

Your objective is to improve the project while preserving stability.

---

# Before Writing Code

Always:

Read PROJECT_CONTEXT.md

Read ARCHITECTURE.md

Read CODING_STANDARD.md

Read the feature being modified.

Search for existing implementations.

Understand the flow before proposing changes.

Never assume.

---

# Preferred Workflow

Understand

↓

Locate existing implementation

↓

Plan

↓

Implement

↓

Analyze

↓

Test

↓

Document

↓

Commit

Never skip steps.

---

# Modification Rules

Prefer extending existing code.

Avoid rewriting entire files.

Avoid duplicate implementations.

Avoid introducing unnecessary abstractions.

Respect current architecture.

---

# Commit Philosophy

One logical change.

One commit.

One purpose.

Bad

"misc updates"

Good

feat: add telemetry service

fix: prevent duplicate room joins

refactor: simplify room repository

---

# Testing Requirements

Before considering work complete:

flutter analyze

flutter test

Verify no regressions

If architecture changed

↓

Update documentation

---

# Documentation

Whenever architecture changes:

Update

ARCHITECTURE.md

PROJECT_CONTEXT.md

Relevant engineering documents

Documentation is part of the implementation.

---

# Refactoring Rules

Refactor only when:

Complexity decreases.

Readability improves.

Behavior remains identical.

Never refactor unrelated code.

---

# Performance

Prefer:

const widgets

small rebuilds

Riverpod selectors

immutable models

Avoid:

duplicate listeners

duplicate providers

nested rebuilds

unnecessary Firestore reads

---

# Error Handling

Never hide exceptions.

Never ignore failures.

Unexpected exceptions should reach CrashReporter.

---

# Logging

Every meaningful feature should produce structured logs.

Never use print().

Never leave debugging statements in production.

---

# Analytics

Analytics exists to answer business questions.

Do not create analytics events without purpose.

---

# Crashlytics

Every fatal error should include:

Context

Breadcrumbs

Custom Keys

Stacktrace

---

# Telemetry

Every important gameplay action should emit one telemetry event.

Never duplicate telemetry.

---

# Firestore

Repositories own Firestore.

Widgets never communicate directly with Firestore.

---

# UI

Maintain visual consistency.

Respect spacing tokens.

Respect typography.

Respect animation system.

---

# Multiplayer

Synchronization always has higher priority than visuals.

Never risk consistency for animation.

---

# Beta Philosophy

The goal of beta is learning.

Prefer observability over adding features.

---

# Code Review Checklist

Before finishing verify:

Architecture respected

No duplicated logic

No dead code

No TODOs forgotten

Tests pass

Documentation updated

---

# Golden Rule

If you are uncertain,

stop,

read the documentation,

understand the existing implementation,

then continue.