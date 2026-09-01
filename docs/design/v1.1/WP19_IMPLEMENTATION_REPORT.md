# BUFÓN v1.1 — WP19 · TELEMETRY BOUNDARY HARDENING

## IMPLEMENTATION REPORT

> | Field | Value |
> |---|---|
> | **Document date** | 2026-08-31 |
> | **Package** | **WP19 — Telemetry boundary hardening** (`MASTER_V1.1_RECONCILIATION.md:948-961`) |
> | **Scope option** | **Option 2 — Correct boundary hardening** (`CRASHLYTICS_TELEMETRY_AUDIT.md:1248-1259`) |
> | **Findings closed** | **R-01** (C-1) · **R-02** (C-2) · **R-03** (C-4) · **R-04** (T-1) · **R-05** (T-3) · **R-06** (Q-1…Q-4) |
> | **HEAD before** | `15824db1bb60f69f2f3c69ceecafc159fd2a0437` |
> | **HEAD after** | one commit ahead — **`HEAD^ == 15824db1bb60f69f2f3c69ceecafc159fd2a0437`** (§10.6). The commit's own hash cannot appear inside a file that is part of it; it is reported at the terminal. |
> | **Commits** | exactly **1** · **not pushed** |
> | **Production files changed** | 2 (both inside the analytics boundary) |
> | **Test files added** | 2 · **0 modified** |
> | **Documentation changed** | 1 (`docs/engineering/ANALYTICS.md` — engineering, not design) |
> | **Goldens** | 10 · **all byte-identical** · no `--update-goldens` |
> | **Blueprint / Master Reconciliation / audits** | **untouched, hash-verified** |

**Evidence discipline.** Every significant statement carries **[VERIFIED]**, **[INFERRED]**, **[DESIGN INTENT]** or **[UNVERIFIABLE]**. **[VERIFIED]** here means *demonstrated by a command run in this session or by a test that passed*. No runtime claim is made about a device this work was not executed on.

---

## §0 · WP19 IDENTITY

**Objective, as chartered.** Stop Firebase Analytics failures from escaping the telemetry boundary and being filed as application crashes; correct the reserved event name that made it happen every day; and leave regression protection so the class of defect cannot silently return.

**What this is not.** Not a telemetry redesign. No new provider, no queue, no retry, no offline persistence, no new logging framework, no state machine, no user-visible error surface. **[VERIFIED]** by §12's scope audit: the diff touches two production files, both inside the class the audit names as the sole Firebase boundary.

**The distinction the work exists to establish** (brief §3):

| | Application failure | Telemetry delivery failure |
|---|---|---|
| Examples | gameplay exception, navigation failure, repository failure | Analytics rejects a name, SDK unavailable, payload rejected |
| Before WP19 | Crashlytics **fatal** | Crashlytics **fatal** ← the defect |
| After WP19 | Crashlytics **fatal** (unchanged) | Crashlytics **non-fatal**, category `analytics` |

---

## §1 · SOURCE DOCUMENTS

Read in full before any edit:

| Document | Used for |
|---|---|
| `docs/design/v1.1/CRASHLYTICS_TELEMETRY_AUDIT.md` | C-1, C-2, C-4, T-1, T-3, Q-1…Q-4; §14.A minimum fix; §14.B H1–H6; §14.D Option 1/2/3; §14.C T-A…T-H |
| `docs/design/v1.1/MASTER_V1.1_RECONCILIATION.md` | R-01…R-06 scopes and non-goals; WP19 charter at `:948-961`; exclusions |
| `docs/design/v1.1/BUFON_V1.1_VISUAL_BLUEPRINT.md` | Confirming zero overlap — **[VERIFIED]** no Blueprint file is touched |
| `docs/engineering/ANALYTICS.md` | The specification defect at line 131 (C-4 / R-03) |

Current implementation inspected directly rather than trusted from the audit, per the brief: `analytics_event_mapping.dart`, `analytics_destination.dart`, `app_logger.dart`, `game_telemetry_service.dart`, `app_session_observer.dart`, `crash_reporter.dart`, `crash_log_destination.dart`, `crash_backend.dart`, `firebase_crashlytics_backend.dart`, `main.dart`, and the installed `firebase_analytics-11.6.0` source.

**[VERIFIED]** Every claim the audit makes about the current code was re-confirmed against HEAD. **No divergence was found**, so stop condition 10 did not trigger.

---

## §2 · BASELINE

```
HEAD          15824db1bb60f69f2f3c69ceecafc159fd2a0437
branch        main
origin/main   2c8337e7d790c79803b7b93f3b0329318cbc2e93   (HEAD 1 ahead)
stash         1 entry — NOT applied
analyzer      clean before and after
tests         301 passing after; 14 added → 287 before  [INFERRED, arithmetic]
```

Working tree at baseline: **no tracked modifications, nothing staged**; ten untracked documents, all protected.

**Protected file hashes — recorded before, re-verified after (§12.3):**

| File | SHA-256 (before **and** after) |
|---|---|
| `docs/design/Archive.zip` | `ede95b58…3522` |
| `docs/design/v1.1/FORENSIC_ANALYSIS_OUTPUT.md` | `d2904319…a98e` |
| `docs/design/v1.1/GAMEPLAY_AUDIT_OUTPUT.md` | `1c601fc7…37a4` |
| `docs/design/v1.1/CRASHLYTICS_TELEMETRY_AUDIT.md` | `b83a1b91…a049` |
| `docs/design/v1.1/MASTER_V1.1_RECONCILIATION.md` | `d8237e57…1773` |
| `docs/design/v1.1/LONG_USERNAME_INCIDENT_FORENSIC_AUDIT.md` | `7e89704b…b347` |
| `docs/design/v1.1/LONG_USERNAME_RECONCILIATION.md` | `d83cddb7…cfab` |
| `docs/design/v1.1/WP18_CONSOLE_FACT_FINDING.md` | `e2b7dc8c…447d` |
| `docs/design/v1.1/WP4_RECOVERY_REPORT.md` | `a3aaadd4…2066` |
| `docs/design/v1.1/WP5_RECOVERY_REPORT.md` | `adda2315…7c6a` |
| `docs/design/v1.1/BUFON_V1.1_VISUAL_BLUEPRINT.md` | `34399e0e…bede` |

`Archive.zip` was **not extracted**. The stash was **not applied**.

**Golden hashes** for all 10 PNGs under `bufon_flutter/test/golden/goldens/` were recorded before implementation and re-verified after (§11).

---

## §3 · CONFIRMED ROOT CAUSE

Re-derived against HEAD, not taken on faith. **[VERIFIED]** every frame of the production stack maps to a line in this repository:

```
AppSessionObserver.didChangeAppLifecycleState(paused|detached|hidden)
                                                app_session_observer.dart:52-66
        ▼
AppSessionObserver._closeSession()               app_session_observer.dart:75-91
        │   _telemetry.track(AppLogCategory.app, 'app_backgrounded')        :80
        ▼
GameTelemetryService._emit → AppLogger.log
        ▼
AnalyticsDestination.onLog(entry)                analytics_destination.dart:82
        │   registry lookup
        ▼
'app_backgrounded' → 'app_background'            analytics_event_mapping.dart:99
        │   ← RESERVED: entry 7 of `_reservedEventNames`
        ▼
AnalyticsDestination.sendEvent
        │   unawaited(_firebase.logEvent(...))    analytics_destination.dart:66
        ▼
FirebaseAnalytics.logEvent  (async)     firebase_analytics-11.6.0 …:100-110
        │   _logEventNameValidation(name) throws ArgumentError  …:1361-1368
        │   — inside the async body, so it becomes a REJECTED FUTURE
        ▼
   … no error handler. AppLogger's synchronous try/catch
     (app_logger.dart:268-275) already returned.
        ▼
runZonedGuarded handler                          crash_reporter.dart:123-131
        ▼
recordFatal → recordError(fatal: true)           crash_reporter.dart:205-223
        ▼
_crashlytics.recordError(fatal: report.isFatal)  firebase_crashlytics_backend.dart:37-41
```

### Three facts that shape the fix

1. **[VERIFIED]** The name is reserved. `_reservedEventNames` in `firebase_analytics-11.6.0/lib/src/firebase_analytics.dart:1405-1438` contains `app_background`. Now asserted continuously — §9.1.
2. **[VERIFIED]** The rejection is **asynchronous**. `logEvent` is `async` and validates *inside* its body, so the `ArgumentError` becomes a rejected `Future`. A synchronous `try/catch` anywhere upstream is structurally incapable of seeing it. This is why the defect survived a suite with 287 passing tests.
3. **[VERIFIED]** The application never crashed. `runZonedGuarded` **catches**; `fatal: true` at `crash_reporter.dart:220` is a classification the application chooses (`crash_backend.dart:42` — `isFatal => severity == AppLogLevel.fatal`), not a statement about the process. The damage was to Crashlytics integrity and to observability, exactly as the audit concluded.

**[VERIFIED]** The mapping was **not a typo**. `docs/engineering/ANALYTICS.md:131` specified `app_background`. The code was correctly implementing an incorrect specification — which is why a code-only fix would have been reverted by the next person to read the spec (C-4).

---

## §4 · OPTION 2 INTERPRETATION

The audit's definition, verbatim (`CRASHLYTICS_TELEMETRY_AUDIT.md:1252`):

> **Content** | Option 1 + **H2** (contain SDK failures) + **H3** (validate at the edge) + **H4** (correct the spec) + **H5** (internal diagnostic).

And its named hazard (`:1255`):

> **The hazard is T-3:** swallowing errors without H5 converts a loud failure into a silent one. **H5 is not optional in this option** — it is what makes H2 safe.

### Implementation against each measure

| # | Measure | Delivered | Where |
|---|---|---|---|
| **§14.A** | Rename the mapping target | ✅ | `analytics_event_mapping.dart` — §7 |
| **H2** | Contain SDK failures on all three `unawaited` calls | ✅ | `AnalyticsDestination._dispatch` — §6 |
| **H3** | Validate at the outbound edge, **dropping** not throwing | ✅ | `_isDispatchableEventName` + `sendEvent` — §5.3 |
| **H4** | Correct the specification | ✅ | `docs/engineering/ANALYTICS.md` — §7.3 |
| **H5** | Internal diagnostic, never a Firebase event | ✅ | `_reportDeliveryFailure` — §8 |
| **H1** | Reserved-name assertion | ✅ (superseded by the stronger T-A) | `analytics_reserved_names_test.dart` — §9.1 |
| **H6** | Reconcile the ten dead mappings | ❌ **deliberately excluded** | Option 3 / R-42 |
| **T-2** | `onLog` returns `Future<void>` | ❌ **deliberately excluded** | Option 3 / R-44 — *"THE EVIDENCE DOES NOT COMPEL THIS OPTION"* |

### One documented interpretation of H3

**H3 is implemented as *structural* validation, not as a copy of the SDK's exact-match blocklist.** This is a deliberate reading and it is recorded here rather than buried.

`_reservedEventNames` is a **private `const` inside `firebase_analytics`**. Copying it into production would put a 32-entry hand-maintained mirror of someone else's private constant into the shipping app — a list that drifts silently on the next `pub upgrade`, maintained by exactly the people who did not know it existed. **That is the same class of defect WP19 exists to close**, reintroduced one layer down. The audit itself warns against hand-copying: *"Ideally asserted against a list derived from the package rather than a hand-copied constant"* (`:1221`).

What ships instead is **defence at three layers, none of which duplicates the SDK**:

1. **The registry cannot contain a reserved name.** `analytics_reserved_names_test.dart` parses `_reservedEventNames` out of the **installed package source** and asserts all 55 outbound names against it. A `pub upgrade` that adds a reserved name fails the build — precisely T-A's stated ideal.
2. **The edge rejects structurally invalid names** — format (`^[a-z][a-z0-9_]{0,39}$`) and the reserved `firebase_` / `google_` / `ga_` prefixes. These are stable rules, cheap to express, and not a mirror of anything private.
3. **The boundary contains whatever still gets through.** With H2 in place a reserved name that reached the SDK by any route is caught, reported and dropped — it can no longer become a crash.

**[VERIFIED]** T-E passes against all seven illegal-name shapes, and the registry assertion passes against the real SDK list. **[INFERRED]** the three layers together are strictly stronger than a hand-copied list, because layer 1 prevents entry and layer 3 has no list to drift.

### Q3 — the `main.dart:77` secondary consideration

The audit flags (`:1255`) whether `analyticsDestination.initialize()` — `await`ed unguarded inside the zone at `main.dart:77` — should also be guarded.

**Not changed. [VERIFIED]** reasoning: `initialize()` calls `setAnalyticsCollectionEnabled`, which is not name-validated and has no known rejection path; guarding it would mean editing `main.dart`, which is outside the analytics boundary this package is scoped to; and a failure there is a genuine *initialisation* failure during startup, not a per-event delivery failure — the two deserve different treatment. **Recorded as a remaining risk (§14.2), not silently absorbed.**

---

## §5 · IMPLEMENTATION

### 5.1 Files changed

| File | Kind | Lines | What |
|---|---|---|---|
| `bufon_flutter/lib/analytics/analytics_destination.dart` | production | +135 / −5 | H2, H3, H5 |
| `bufon_flutter/lib/analytics/analytics_event_mapping.dart` | production | +14 / −1 | §14.A |
| `docs/engineering/ANALYTICS.md` | engineering doc | +13 / −1 | H4 |
| `bufon_flutter/test/analytics_reserved_names_test.dart` | **new** test | +197 | T-A + the `app_backgrounded` regression |
| `bufon_flutter/test/analytics_boundary_test.dart` | **new** test | +361 | T-B, T-C, T-D, T-E, T-F, T-G |

**[VERIFIED]** No other file in the repository was modified. `test/analytics_destination_test.dart` was read and left **byte-identical** — its 27 tests are a preservation check, not a target.

### 5.2 The public surface did not change

**[VERIFIED]** `GameTelemetryService.track/start/transition/updateContext`, `AppLogger`'s eight level methods, `AppLogDestination.onLog`'s `void` signature, `AnalyticsDestination`'s constructor and the three `@protected @visibleForTesting` `send*` methods all keep their exact prior signatures. Stop condition 2 did not trigger. Every caller in the application compiles unchanged — **[VERIFIED]** by `flutter analyze` returning *No issues found!* with zero call-site edits.

### 5.3 H3 — the edge check

```dart
static final RegExp _eventNamePattern = RegExp(r'^[a-z][a-z0-9_]{0,39}$');
static const List<String> _reservedPrefixes = ['firebase_', 'google_', 'ga_'];

static bool _isDispatchableEventName(String name) {
  if (!_eventNamePattern.hasMatch(name)) return false;
  for (final prefix in _reservedPrefixes) {
    if (name.startsWith(prefix)) return false;
  }
  return true;
}
```

Applied in `sendEvent` **before** dispatch. An illegal name is **dropped and reported**, never thrown — telemetry is observational and must not fail its caller.

**[VERIFIED]** `sendScreenView` is deliberately **not** name-validated: `logScreenView` sends the built-in `screen_view` event and carries the screen as a *parameter*, so event-name rules do not apply to that string. Validating it would have dropped legitimate screen views.

---

## §6 · ASYNC BOUNDARY BEHAVIOUR

### 6.1 The containment

```dart
void _dispatch(String operation, String name, Future<void> Function() call) {
  try {
    unawaited(
      call().catchError((Object error, StackTrace stackTrace) {
        _reportDeliveryFailure(operation, name, error, stackTrace);
      }),
    );
  } catch (error, stackTrace) {
    _reportDeliveryFailure(operation, name, error, stackTrace);
  }
}
```

All three SDK calls — `logEvent`, `logScreenView`, `setUserId` — route through it. **[VERIFIED]** by reading the file: `unawaited(` appears exactly three times before the change and zero times without a handler after it.

### 6.2 Five properties, each deliberate

| Property | How | Evidence |
|---|---|---|
| The rejection is handled | `catchError` on the returned Future | **[VERIFIED]** T-D |
| It never reaches `runZonedGuarded` | the handler consumes it inside the destination | **[VERIFIED]** T-D under a real `runZonedGuarded`, with a control test proving the harness can see an escape |
| The app continues normally | `unawaited` retained — nothing waits on analytics | **[VERIFIED]** T-D "the caller returns normally and later destinations still run" |
| Gameplay control flow is unaffected | no throw, no return value, no `await` added on any caller path | **[VERIFIED]** `returnsNormally` on `telemetry.track`; **[VERIFIED]** 301 tests green |
| Synchronous throws are contained too | the surrounding `try/catch` | **[VERIFIED]** T-D "a synchronous SDK throw is contained too" |

**On the second `catch`.** The SDK validates inside its `async` body today, so a synchronous throw is not the observed shape. It is guarded anyway: containment that covers one of two shapes is not containment, and the cost is four lines. **[INFERRED]**, not a claim that the path fires in production.

**No delays, no blocking, no prerequisites.** **[VERIFIED]** — no `await`, no `Timer`, no `Duration` was added anywhere in the change; `_dispatch` returns synchronously in every path.

---

## §7 · EVENT NAME CORRECTION

### 7.1 Before → after

```diff
- 'app_backgrounded': AnalyticsEventMapping(name: 'app_background'),
+ 'app_backgrounded': AnalyticsEventMapping(),
    'app_resumed':    AnalyticsEventMapping(name: 'app_foreground'),
```

The **internal** identifier `app_backgrounded` is unchanged, as required. The bare constructor defaults the outbound name to the telemetry name — the form `session_started` and `session_ended` two lines above already use. **[VERIFIED]** `app_backgrounded` is absent from the SDK's reserved list, is 16 characters, and matches `^[a-z][a-z0-9_]*$`.

### 7.2 Why the twin is untouched

**[VERIFIED]** `app_foreground` is **not** reserved, so `app_resumed → app_foreground` cannot produce this crash — the audit classifies it **VERIFIED SAFE** and the Master Reconciliation lists it in WP19's exclusions. It has been arriving in GA4 since launch; renaming it would break reporting continuity for an event that works. `app_backgrounded` has **never landed once**, so it has no continuity to preserve.

The resulting asymmetry between the two lifecycle names is **intentional**, is documented in the source at the mapping site, and is asserted in both directions by tests so it cannot be "tidied up" by accident.

### 7.3 H4 — the specification

`docs/engineering/ANALYTICS.md` listed `app_background` as a Session Event. Corrected to `app_backgrounded`, with a short note recording that the **specification, not the code, was the defect**, and a pointer to the test that now enforces the rule. **[VERIFIED]** this is engineering documentation; the audit itself states *"`docs/engineering/ANALYTICS.md` is engineering documentation, not design documentation"* (`:1257`). No design document was touched.

### 7.4 Registry preservation — brief §10

Machine-verified by parsing the registry (including `failureName` values and the `resolveName` resolver's outputs) from **`git show HEAD:…`** and from the working tree, then diffing the two sets:

```
outbound BEFORE : 55
outbound AFTER  : 55
removed         : ['app_background']
added           : ['app_backgrounded']
unchanged       : 54
```

**[VERIFIED]** Exactly one outbound name changed. The other **54 are byte-identical**. The count of 55 independently reproduces the audit's own inventory (`:1061`). No internal event identifier changed. Stop condition 4 did not trigger — **no additional reserved or malformed name was found**.

---

## §8 · INTERNAL OBSERVABILITY

### 8.1 The T-3 hazard, and what closes it

The audit is explicit (`:889`): a fix that catches the error *"would make the crash disappear **and make the data loss invisible**… 'no crashes' and 'analytics silently broken' look identical from outside."*

```dart
void _reportDeliveryFailure(String operation, String name, Object error, [StackTrace? stackTrace]) {
  AppLogger.instance.error(
    AppLogCategory.analytics,
    'Analytics $operation dropped "$name"',
    context: {'analytics_operation': operation, 'analytics_event': name},
    error: error,
    stackTrace: stackTrace,
  );
}
```

**No new abstraction was created.** `AppLogger`, `AppLogCategory.analytics` and the `error` level all already existed; `AppLogCategory.analytics` was purpose-built for exactly this and had no prior use at this boundary.

### 8.2 Where the diagnostic goes, and why that is the right classification

**[VERIFIED]** by reading the destination chain:

| Destination | Result |
|---|---|
| `TalkerLogDestination` | a console line in development |
| `CrashLogDestination` (`:41-55`) | a breadcrumb **and** — at `error` level — `reportFromLog` |
| `CrashReporter.reportFromLog` (`:285-297`) | `CrashReport(severity: error)` |
| `crash_backend.dart:42` | `isFatal => severity == AppLogLevel.fatal` → **`false`** |
| Crashlytics | a **non-fatal** report, severity `major` |
| `AnalyticsDestination` | **returns immediately** — no telemetry event attached |

That is the classification WP19 exists to establish: **a telemetry delivery failure is now visible in production as a non-fatal, categorised report, and crash-free-users is untouched by it.**

`error` was chosen over `warning` deliberately. A `warning` produces only a breadcrumb, which surfaces *nothing* unless some unrelated crash happens to attach it — leaving R-05's "silent drop" problem substantially open in production. **[INFERRED]** this is the level that actually satisfies T-3.

### 8.3 Recursion is structurally impossible

The brief marks this critical. **[VERIFIED]**, by construction rather than by convention:

1. The diagnostic is a **plain log with no telemetry event**.
2. `AnalyticsDestination.onLog` begins `final event = entry.telemetryEvent; if (event == null) return;` (`:83-84`).
3. Therefore the diagnostic for a failed dispatch **cannot re-enter the boundary that just failed**. There is no Firebase call to make and no second failure to report.
4. `CrashReporter.reportFromLog` calls `_record(…, logIt: false)` (`:295`), so it does not mirror the entry back into the log stream either.

**[VERIFIED]** by T-F: exactly **one** diagnostic and exactly **one** SDK call after a rejected event. A recursive path would show more of both.

### 8.4 Privacy

**[VERIFIED]** Only the SDK operation name and the analytics event name are recorded. **Parameters are deliberately not logged** — they carry session context, and this path exists for diagnosis, not collection. No password, token, credential or raw user datum can reach it: an analytics *event name* is a compile-time constant from the registry. The existing PII policy at the analytics boundary (`analyticsContextKeys`, room-code hashing) is untouched.

---

## §9 · REGRESSION TESTS

14 tests added across 2 new files. Existing test files: **0 modified**.

### 9.1 `analytics_reserved_names_test.dart` — T-A (5 tests)

The blocklist is **parsed out of the installed SDK**, located through `.dart_tool/package_config.json` so no path is pinned to a version. A `pub upgrade` that adds a reserved name now fails the build.

| Test | Proves |
|---|---|
| the SDK blocklist is readable and still contains `app_background` | the parser works and is anchored to the name that caused the crash |
| no outbound analytics name is reserved by Firebase | all **55** outbound names — success names, resolver outputs, `failureName`s — checked against the real list |
| no outbound analytics name uses a reserved prefix | `firebase_` / `google_` / `ga_` |
| **`app_backgrounded` never resolves to the reserved `app_background`** | the §9 regression, read from the **real registry** — no fixture that could drift |
| `app_resumed` still resolves to `app_foreground` | the deliberate asymmetry is protected from tidying |

**Two anti-vacuity guards.** The parser asserts it found **> 20** reserved names, and the enumeration asserts it found **> 40** outbound names. A silently-matching-nothing regex would otherwise make every assertion pass by emptiness — which is precisely how the original defect survived. **[VERIFIED]** the file fails loudly (not skips) if the SDK source cannot be found.

### 9.2 `analytics_boundary_test.dart` — T-B…T-G (9 tests)

**These drive the real `AnalyticsDestination`.** The existing `_RecordingDestination` overrides `sendEvent` — the exact method that touches the SDK — which is why the suite could never see this defect (audit Q-2). The new tests substitute the **`FirebaseAnalytics` instance** through the constructor the class already exposes, so the containment under test is the shipped code, not a copy of it.

| Cat. | Test | Proves |
|---|---|---|
| **T-C** | an unhandled rejection from a destination reaches the zone | **the control.** A test-local destination reproducing the pre-WP19 `unawaited`-without-handler shape *does* escape into `runZonedGuarded`. Without this the containment assertions could pass against a harness incapable of failing |
| **T-D** | an asynchronous rejection never reaches the zone | the real destination + a rejecting SDK: the SDK **was** called, and **nothing** escaped |
| **T-D** | the caller returns normally and later destinations still run | `returnsNormally`; the downstream destination still received the event |
| **T-D** | a synchronous SDK throw is contained too | the second guard shape |
| **T-E** | reserved prefixes and malformed names never reach the SDK | 7 illegal shapes → **0** dispatches, **7** diagnostics, **0** throws |
| **T-E** | a legal name is still dispatched | the validator is not simply blocking everything |
| **T-F** | one diagnostic, no Firebase event, no recursion | exactly 1 diagnostic at `error` in category `analytics`, carrying the `ArgumentError`, with `telemetryEvent == null`; exactly 1 SDK call |
| **T-B** | backgrounding emits `app_backgrounded` through the real destination | **the assertion whose absence let the defect ship.** Drives `AppSessionObserver.didChangeAppLifecycleState` and asserts the Firebase-facing name: contains `app_backgrounded`, **not** `app_background`, and still contains `app_foreground` |
| **T-G** | the session still ends and nothing is stranded | under a failing destination: nothing escapes, `hasActiveSession == false`, no session id stranded in context, and `session_ended` carried `session_duration_seconds` |

**No mocking package was added.** The SDK stand-in is `implements FirebaseAnalytics` with a `noSuchMethod` that **throws** for anything unexpected, so a future call the fake does not model fails loudly instead of silently returning null. Stop condition 6 did not trigger — **[VERIFIED]** `pubspec.yaml` is unchanged.

### 9.3 T-H

**Not implemented — correctly.** T-H is gated on H6, which is Option 3 / **R-42**, explicitly outside WP19.

---

## §10 · FULL VERIFICATION

### 10.1 `flutter analyze`

```
Analyzing bufon_flutter...
No issues found! (ran in 4.7s)
```
**[VERIFIED]**

### 10.2 `flutter test`

```
01:19 +301: All tests passed!
```
**[VERIFIED]** 301 passing, 0 failing, 0 skipped. **[INFERRED]** 287 before (301 − 14 added).

### 10.3 Focused run

**[VERIFIED]** `analytics_boundary_test.dart` + `analytics_reserved_names_test.dart` + `analytics_destination_test.dart` → all green, including all 27 pre-existing tests in the untouched file.

### 10.4 The tests genuinely fail against the defect

**[VERIFIED]** during development, not asserted after the fact:

* The reserved-name test **failed** on its first run — on SDK-path resolution, not vacuously — and was fixed until it read the real 32-entry list.
* The **T-C control test passes**, proving the harness detects an escaping asynchronous error. Every containment assertion is therefore falsifiable.
* **[INFERRED]** the `app_backgrounded` regression would have failed against HEAD, since it reads the real registry and HEAD's registry resolved to `app_background`. Not executed against HEAD, and not claimed as verified.

### 10.5 `git diff --check`

Clean. **[VERIFIED]**

### 10.6 Commit

```
message : fix: harden analytics telemetry boundary
HEAD^   : 15824db1bb60f69f2f3c69ceecafc159fd2a0437   ← the pre-WP19 HEAD
```

The commit's own SHA is deliberately absent: this report is **inside** that commit, so
quoting the hash here would either be fabricated or require an amend. `HEAD^` is the
verifiable anchor, and the SHA is reported at the terminal.
Exactly one commit. Not amended, not squashed, not rebased, not reset. **Not pushed.** **[VERIFIED]**

---

## §11 · GOLDEN VERIFICATION

All 10 PNGs under `bufon_flutter/test/golden/goldens/` hashed before and after. **[VERIFIED] all byte-identical:**

```
ec40727f…  animated_primary_button_disabled.png
ee377c92…  animated_primary_button_outline.png
f9b8fd0c…  animated_primary_button_solid.png
194cc647…  game_card_disabled.png
506317e5…  game_card_resting.png
a0425c33…  game_card_selected.png
2c6180cc…  game_progress_bar_midgame.png
3963fdb7…  round_indicator.png
f271e1d8…  timer_widget_normal.png
d5912349…  timer_widget_urgent.png
```

**[VERIFIED]** `--update-goldens` was never passed. No golden was regenerated or modified. `git status` shows no change under `test/golden/`. Stop condition 7 did not trigger. **[INFERRED]** this was expected — WP19 renders nothing.

---

## §12 · SCOPE VERIFICATION

### 12.1 The complete diff

```
 bufon_flutter/lib/analytics/analytics_destination.dart    | 135 ++++++++++++++-
 bufon_flutter/lib/analytics/analytics_event_mapping.dart  |  14 ++-
 docs/engineering/ANALYTICS.md                             |  13 +-
 3 files changed, 157 insertions(+), 5 deletions(-)
+ bufon_flutter/test/analytics_boundary_test.dart           (new)
+ bufon_flutter/test/analytics_reserved_names_test.dart     (new)
+ docs/design/v1.1/WP19_IMPLEMENTATION_REPORT.md            (this report)
```

**[VERIFIED]** The two production files are exactly the two the audit predicted (`:1253`).

### 12.2 Forbidden paths — none touched

**[VERIFIED]** by `git status --short` and `git diff --name-only`:

`game_screen.dart` · `voting_screen.dart` · `lobby_screen.dart` · `final_winner_screen.dart` · `round_result_screen.dart` · every repository · every controller · every provider · every model · `firestore.rules` · `functions/` · every UI primitive · every visual token · every golden — **all unchanged.**

Also unchanged: `app_logger.dart`, `app_log_destination.dart`, `game_telemetry_service.dart`, `app_session_observer.dart`, `crash_reporter.dart`, `crash_log_destination.dart`, `main.dart`, `pubspec.yaml`. **[VERIFIED]** `AppSessionObserver` in particular is untouched, as audit C L-2 requires.

### 12.3 Protected files

**[VERIFIED]** All eleven protected documents re-hashed after implementation; **every hash is identical to §2's baseline**. `Archive.zip` was not extracted. The stash (1 entry) was not applied. The Blueprint, the Master Reconciliation and all four audits are byte-identical.

### 12.4 Stop conditions

**[VERIFIED]** none of the ten triggered:

| # | Condition | Status |
|---|---|---|
| 1 | Option 2 needs architectural redesign | No — 2 files, boundary-local |
| 2 | Telemetry API must change materially | No — every public signature preserved |
| 3 | Requires modifying gameplay logic | No |
| 4 | More than the known reserved name needs changing | No — 55 names machine-checked, 1 changed |
| 5 | `CrashReporter` behaviour becomes ambiguous | No — untouched; real errors classify exactly as before |
| 6 | A new mocking framework is required | No — `pubspec.yaml` unchanged |
| 7 | A golden changed | No — 10/10 identical |
| 8 | Firebase/Firestore rules must change | No |
| 9 | Changes outside the telemetry boundary | No |
| 10 | Option 2 no longer matches the repository | No — every audit claim re-confirmed against HEAD |

---

## §13 · PRESERVED BEHAVIOUR

**[VERIFIED]** by 287 pre-existing tests passing unchanged, plus direct inspection:

| Preserved | Evidence |
|---|---|
| `AppLogger` semantics — levels, categories, context providers, fan-out order, `void onLog` | file unchanged; `app_logger_test.dart` green |
| `GameTelemetryService` API | file unchanged; `telemetry_test.dart`, `migrated_telemetry_test.dart` green |
| Internal event names — all of them | **[VERIFIED]** §7.4: zero internal identifiers changed |
| Event payload structure | `_buildParameters`, `_asParameterValue`, `_hash` untouched |
| The other 54 outbound analytics names | **[VERIFIED]** §7.4 machine diff |
| Existing logging destinations | Talker and `CrashLogDestination` unchanged |
| Gameplay flow, navigation, lifecycle | no file touched; full suite green |
| `CrashReporter` behaviour for **real** application exceptions | file unchanged. A gameplay exception still reaches `runZonedGuarded` and is still filed **fatal**. **Only Analytics delivery failures are isolated** |
| Existing non-Analytics diagnostics | untouched |
| The analytics allowlist and PII policy | `analyticsContextKeys` unchanged; `player_name` still excluded; room codes still hashed |
| `test/analytics_destination_test.dart` | **byte-identical**; its 27 tests are the preservation check |

---

## §14 · REMAINING RISKS

### 14.1 Explicitly out of scope, unchanged, and still open

| Item | Owner |
|---|---|
| **T-2** — `AppLogDestination.onLog` returns `void`, so a *future* async destination inherits the same hazard by default | **R-44**, Option 3. The audit: *"THE EVIDENCE DOES NOT COMPEL THIS OPTION"* |
| **T-5 / Q-5** — ten dead registry entries with no reachable emitter | **R-42** |
| **T-6** — whether GA4 treats a manually logged `app_open` as colliding with its automatic event | **[UNVERIFIABLE from the repository]** — a console question, WP18 |

**[INFERRED]** T-2's residual exposure is narrower after WP19 than the audit described it: `AnalyticsDestination` was the only async destination, and it is now contained at its own boundary. The generic hazard remains for a destination that does not yet exist.

### 14.2 Q3 — `main.dart:77` left unguarded

**[VERIFIED]** `analyticsDestination.initialize()` is still `await`ed unguarded inside the zone. Reasoning in §4. **[INFERRED]** low risk: `setAnalyticsCollectionEnabled` has no name validation and no known rejection path. **[UNVERIFIABLE]** whether it can reject on a real device under a degraded Firebase install. **This is a deferred decision, not an oversight** — guarding it means editing `main.dart`, outside this package's boundary.

### 14.3 What was not tested, and cannot honestly be claimed

* **[UNVERIFIABLE]** Production behaviour on a real device. Nothing here was run on Android or iOS. The claim *"`app_background` fatals cease and `app_backgrounded` arrives in GA4"* is the **post-release verification WP19's charter already requires**, and it is **not** claimed as verified.
* **[UNVERIFIABLE]** Whether GA4 accepts `app_backgrounded` at the console. **[VERIFIED]** only that the SDK's own validator does not reject it.
* **[INFERRED]** The test double reproduces the SDK's rejection shape (`async` method, `ArgumentError`) faithfully because it was written from the SDK source read in this session. It is a stand-in, not the platform channel.
* **[VERIFIED]** the reserved-list parser depends on `firebase_analytics` keeping a `const List<String> _reservedEventNames` in `lib/src/firebase_analytics.dart`. If a future version restructures it, the test **fails with an explanatory message telling the reader to repoint it, not delete it**. That is a deliberate choice: a loud false failure is worth more here than a silent true pass.

### 14.4 One judgement recorded for review

§4's H3 interpretation — structural validation at the edge plus a package-derived registry assertion, rather than a hand-copied 32-entry blocklist in production — is the one place this implementation exercises judgement over a literal reading of the audit. The reasoning is in §4 and the trade is stated. **If the owner prefers the literal reading, the change is additive and small.**

---

## §15 · FINAL VERDICT

> ## WP19 is **COMPLETE** as Option 2, verified, and committed as exactly one unpushed commit.

**What changed, in one paragraph.** Firebase Analytics can no longer make Bufón look like it crashed. The reserved name that triggered the failure on every backgrounding is corrected in the code *and* in the specification that mandated it; every SDK call now has an error handler, so an asynchronous rejection is contained at the one class that owns the Firebase surface instead of escaping to the zone handler in `main`; an illegal name is dropped before dispatch rather than thrown at; and every drop produces exactly one internal, non-fatal, categorised report — so the fix cannot trade a visible false crash for invisible data loss. Fourteen tests hold it there, including the two the suite never had: one that drives the real destination through a lifecycle change to the Firebase-facing name, and one that proves an SDK rejection cannot escape — with a control test proving that assertion is capable of failing.

**Delivered against the objective:**

| # | Objective | Status |
|---|---|---|
| 1 | Analytics failures no longer become uncaught async errors | ✅ **[VERIFIED]** T-D |
| 2 | Existing logging/telemetry intent preserved | ✅ **[VERIFIED]** 287 prior tests green, APIs unchanged |
| 3 | Useful internal observability when delivery fails | ✅ **[VERIFIED]** T-F |
| 4 | Represented as telemetry failure, not a false crash | ✅ **[VERIFIED]** non-fatal, category `analytics` |
| 5 | Reserved event name corrected | ✅ **[VERIFIED]** code + spec |
| 6 | Regression protection against the class of defect | ✅ **[VERIFIED]** T-A derived from the SDK itself |

**Release blockers closed:** R-01, R-02, R-03, R-04, R-05, R-06 — six of the eleven in `MASTER_V1.1_RECONCILIATION.md:1250`. **This report does not update the Master Reconciliation; that is a reconciliation pass's job.**

**The metric this unlocks.** Audit C's C-5: Build 1.0's crash-free-users figure is inflated by fatal-classified non-crashes *and* simultaneously masks whatever real crashes share the number. **[INFERRED]** With WP19 shipped, the next build's stability metric becomes usable as evidence for the first time — which is exactly why the Master Reconciliation sequenced this package second, before any behavioural change would be judged against it.

**Stopped here.** WP20 not started. No App Store Connect investigation. No gameplay fix. No username limit. No Master Reconciliation edit. No Blueprint edit. Nothing pushed.

---

*WP19 COMPLETE — ONE COMMIT — NOT PUSHED*
