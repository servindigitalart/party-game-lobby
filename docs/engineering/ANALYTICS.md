# ANALYTICS.md

> Product analytics specification for Bufón.
>
> Analytics exists to improve the game.
>
> Every event collected must answer a real business or gameplay question.

---

# Philosophy

Analytics should explain player behavior.

Analytics is not a logging system.

Analytics is not Crashlytics.

Analytics measures user behavior over time.

Logging explains what happened.

Crashlytics explains why something failed.

Analytics explains how people use the game.

---

# Goals

Analytics should answer questions like:

How many players create rooms?

How many players successfully join?

How many matches actually start?

How many matches finish?

How long does a match last?

Where do players abandon the game?

Which screens have the highest exit rate?

How often do reconnects happen?

How many players return tomorrow?

Which features are never used?

---

# Event Design Principles

Events should be:

Meaningful

Small

Consistent

Stable

Avoid noisy events.

Every event should exist for a reason.

---

# Naming Convention

Events use snake_case.

Examples

app_open

room_created

room_joined

match_started

match_finished

vote_submitted

player_disconnected

player_reconnected

host_changed

---

# Event Categories

Application

Session

Rooms

Gameplay

Rounds

Voting

Networking

Monetization

Sharing

Retention

Errors

Performance

---

# Session Events

app_open

app_background

app_foreground

session_started

session_ended

These events help understand retention.

---

# Room Events

room_created

room_creation_failed

room_joined

room_join_failed

room_closed

room_expired

room_reconnected

room_left

room_full

---

# Gameplay Events

match_started

match_finished

round_started

round_finished

question_revealed

winner_declared

game_abandoned

game_restarted

---

# Voting Events

vote_submitted

vote_changed

vote_timeout

vote_skipped

---

# Player Events

player_joined

player_left

player_disconnected

player_reconnected

host_transferred

host_left

---

# Sharing Events

invite_shared

room_code_copied

invite_link_opened

---

# Monetization Events

ad_loaded

ad_failed

reward_received

purchase_started

purchase_completed

purchase_cancelled

subscription_started

subscription_restored

---

# Error Events

Analytics should never replace Crashlytics.

Only record business-impacting failures.

Examples

room_creation_failed

match_sync_failed

network_timeout

firestore_permission_denied

---

# Parameters

Every event should include only relevant parameters.

Avoid unnecessary metadata.

---

# Standard Parameters

Whenever applicable include:

session_id

player_id

room_code

host_id

game_mode

round

question

player_count

platform

app_version

build_number

network_status

---

# Performance Parameters

Some events should include:

latency_ms

retry_count

snapshot_count

connection_type

---

# Timing Metrics

Measure:

Time to create room

Time to join room

Time until match starts

Round duration

Vote duration

Match duration

Reconnect duration

Loading duration

---

# Funnels

Analytics should support funnels.

Example

App Open

↓

Home

↓

Create Room

↓

Lobby

↓

Players Join

↓

Start Match

↓

Match Finish

↓

Play Again

This identifies where users abandon.

---

# Retention

Track:

Day 1

Day 7

Day 30

Average sessions

Matches per session

Average players per room

---

# Gameplay Metrics

Important KPIs include:

Average room size

Average rounds

Average session duration

Average match duration

Reconnect rate

Disconnect rate

Completion rate

Win rate

Tie rate

---

# Networking Metrics

Track:

Reconnect attempts

Reconnect success

Snapshot failures

Firestore retries

Offline sessions

---

# Feature Adoption

Every major feature should expose adoption metrics.

Examples

Hints

Special Modes

Seasonal Events

Future AI Features

Power Ups

---

# Experimentation

Analytics should support future A/B testing.

Events should remain stable.

Parameters may evolve.

---

# Privacy

Never collect:

Passwords

Emails

Phone numbers

Payment information

Private messages

Collect only anonymous gameplay information.

---

# Validation

Before release verify:

Events are correctly named.

No duplicate events.

No noisy events.

Parameters are valid.

Sensitive information is excluded.

---

# Future Metrics

Average waiting time before game starts

Average room lifetime

Host abandonment rate

Player retention by invitation source

Most common reconnect scenarios

Most abandoned screen

Most common fatal error before exit

---

# Success Metrics

The analytics implementation is considered successful if it allows the team to answer product questions without changing application code.

---

# Integration

AnalyticsService

↓

Firebase Analytics

↓

BigQuery (future)

↓

Dashboards

↓

Business Decisions

---

# Golden Rule

Never collect data because it "might be useful".

Every analytics event must answer a real product, engineering or business question.