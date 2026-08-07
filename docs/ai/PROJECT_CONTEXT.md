# PROJECT_CONTEXT.md

> Single source of truth for AI assistants working on Bufón.
>
> Read this document BEFORE making any code changes.

---

# Project

Name:

Bufón

Platform:

Flutter

Current Stage:

Private Beta

Architecture:

Flutter + Riverpod + Firebase

Primary Target:

iOS (TestFlight)

Secondary Targets:

Android

Future Targets:

macOS

---

# What is Bufón?

Bufón is a real-time multiplayer party game.

Players create or join a room using a short room code.

One player becomes the Host.

The Host controls the game progression.

The game consists of multiple social rounds where players vote, answer prompts and interact in real time.

Firestore is the source of truth.

The application must feel instant, lightweight and fun.

---

# Core Principles

Priority order:

1. Stability
2. Reliability
3. Fast room synchronization
4. Great UX
5. Beautiful UI

Never sacrifice stability for new features.

---

# Development Philosophy

Prefer:

Small PRs

Small commits

Small services

Small widgets

Composition over inheritance.

Avoid unnecessary abstractions.

Avoid premature optimization.

Every feature should be easy to remove.

---

# AI Rules

Before writing code:

Understand the existing architecture.

Reuse existing services whenever possible.

Avoid duplicate logic.

Never introduce a second implementation of an existing feature.

Prefer extending the current architecture.

---

# Code Quality

Every code change must:

Compile.

Pass flutter analyze.

Pass flutter test.

Avoid breaking existing behavior.

---

# State Management

State management:

Riverpod

Do not introduce:

Provider

Bloc

Redux

MobX

GetX

unless explicitly requested.

---

# Backend

Backend:

Firebase

Services currently used:

Firestore

Firebase Analytics

Firebase Crashlytics

Firebase Authentication

Future:

Cloud Functions

Remote Config

App Check

---

# Networking

Firestore is the source of truth.

Realtime listeners are preferred over polling.

Avoid unnecessary reads.

Avoid unnecessary writes.

Prefer batched writes whenever possible.

---

# Room System

A room has:

roomCode

host

players

gameState

settings

createdAt

updatedAt

Players can:

Join

Leave

Reconnect

Host can:

Start game

Advance rounds

Close room

Room synchronization is critical.

Never introduce race conditions.

---

# Telemetry Philosophy

Everything important should be observable.

Important events should generate:

Structured logs

Analytics events

Crashlytics breadcrumbs

Crashlytics custom keys

Never log sensitive information.

---

# Logging Philosophy

Logs are first-class citizens.

Every important action should explain:

Who

What

When

Why

Result

Logs should help reproduce bugs.

---

# Error Philosophy

Never swallow exceptions silently.

Recover when possible.

Crash loudly only when recovery is impossible.

Every unexpected exception should reach Crashlytics.

---

# Performance Philosophy

Avoid rebuilding entire screens.

Prefer granular widgets.

Avoid unnecessary Firestore listeners.

Avoid duplicated streams.

Avoid duplicated providers.

---

# UI Philosophy

Simple.

Friendly.

Minimal.

Responsive.

Consistent spacing.

Consistent typography.

Consistent animations.

Avoid visual noise.

---

# Testing Philosophy

Every new feature should be testable.

Prefer deterministic behavior.

Avoid hidden state.

Avoid random side effects.

---

# Beta Goals

During beta we want to discover:

Crashes

Synchronization bugs

Room lifecycle bugs

Reconnect issues

Performance problems

Unexpected disconnects

Memory leaks

Edge cases

NOT new visual designs.

---

# Things AI Should Never Break

Firebase initialization

Room synchronization

Firestore schema

Navigation

Analytics

Crashlytics

Room creation

Room joining

Host flow

Player flow

---

# Preferred Workflow

Understand feature

Locate existing implementation

Reuse services

Implement

Analyze

Test

Review

Document

Commit

---

# Documentation

Before implementing a significant feature, verify whether documentation already exists inside:

docs/

If documentation exists:

Read it first.

If documentation does not exist:

Create it.

---

# Golden Rule

Bufón is a multiplayer application.

Correct synchronization is always more important than adding another feature.