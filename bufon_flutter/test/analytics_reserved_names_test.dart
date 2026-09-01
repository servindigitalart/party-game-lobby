// test/analytics_reserved_names_test.dart
//
// WP19 · T-A — the assertion whose absence let the defect ship.
//
// `analytics_event_mapping.dart` used to map `app_backgrounded` onto
// `app_background`, which is entry 7 of Firebase's reserved event names. The
// existing suite already checked length and snake_case, so the malformed
// mapping passed every test in the repository while `logEvent` rejected it on
// every single backgrounding in production.
//
// The blocklist here is **parsed out of the installed SDK**, not hand-copied.
// That is the whole point: a hand-copied constant drifts the moment
// `firebase_analytics` is upgraded, and would have to be maintained by exactly
// the people who did not know the list existed. Read from the package source,
// an upgrade that adds a reserved name fails the build instead.

import 'dart:convert';
import 'dart:io';

import 'package:bufon_flutter/analytics/analytics_event_mapping.dart';
import 'package:bufon_flutter/core/logging/log_category.dart';
import 'package:bufon_flutter/core/logging/log_level.dart';
import 'package:bufon_flutter/core/telemetry/telemetry_context.dart';
import 'package:bufon_flutter/core/telemetry/telemetry_event.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locates `firebase_analytics`' own source through the package config the
/// test runner is already using, so no path is hard-coded to a version.
File _firebaseAnalyticsSource() {
  final configFile = File('.dart_tool/package_config.json');
  expect(
    configFile.existsSync(),
    isTrue,
    reason:
        '.dart_tool/package_config.json is missing — run `flutter pub get`. '
        'This test must never pass by being unable to find the SDK.',
  );

  final config =
      jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final packages = (config['packages'] as List<dynamic>).cast<Map<String, dynamic>>();
  final entry = packages.firstWhere(
    (p) => p['name'] == 'firebase_analytics',
    orElse: () => throw StateError(
      'firebase_analytics is not in package_config.json — the analytics '
      'boundary cannot be validated against the SDK that implements it.',
    ),
  );

  // Trailing slashes matter: `Uri.resolve` replaces the last segment of a
  // path that does not end in one, which silently drops the version folder.
  String asDirectory(String uri) => uri.endsWith('/') ? uri : '$uri/';

  final root = configFile.parent.uri.resolve(
    asDirectory(entry['rootUri'] as String),
  );
  final lib = root.resolve(asDirectory('${entry['packageUri']}'));
  final source = File.fromUri(lib.resolve('src/firebase_analytics.dart'));

  expect(
    source.existsSync(),
    isTrue,
    reason:
        'Expected the SDK source at ${source.path}. If firebase_analytics '
        'moved this file, this test must be repointed — not deleted.',
  );
  return source;
}

/// The SDK's own `_reservedEventNames`, read from its source.
Set<String> _reservedEventNames() {
  final source = _firebaseAnalyticsSource().readAsStringSync();

  final block = RegExp(
    r'const\s+List<String>\s+_reservedEventNames\s*=\s*<String>\[(.*?)\];',
    dotAll: true,
  ).firstMatch(source);

  expect(
    block,
    isNotNull,
    reason:
        'Could not find `_reservedEventNames` in the installed SDK. The list '
        'may have been renamed or restructured; repoint this parser rather '
        'than replacing it with a hand-copied constant.',
  );

  final names = RegExp("'([a-z0-9_]+)'")
      .allMatches(block!.group(1)!)
      .map((m) => m.group(1)!)
      .toSet();

  // A parser that silently matched nothing would make every assertion below
  // vacuous, which is precisely the shape of failure this file exists to stop.
  expect(
    names.length,
    greaterThan(20),
    reason: 'Parsed only ${names.length} reserved names — the parser is broken',
  );
  return names;
}

TelemetryEvent _event(
  String name, {
  required TelemetryStatus status,
  Map<String, dynamic> payload = const {},
}) => TelemetryEvent(
  id: 'id',
  name: name,
  category: AppLogCategory.app,
  severity: AppLogLevel.info,
  status: status,
  timestamp: DateTime(2026),
  context: const TelemetryContext.empty(),
  payload: payload,
);

/// Every name the registry can put on the wire: success names, the
/// `resolveName` outputs, and the `failureName` values.
Set<String> _outboundNames() {
  // The one resolver in the registry keys off `to_phase`; driving every phase
  // through it enumerates its outputs without reaching into a private symbol.
  const phases = ['answering', 'voting', 'roundResult', 'finalWinner', ''];

  final names = <String>{};
  for (final entry in analyticsEventMappings.entries) {
    for (final phase in phases) {
      for (final status in [
        TelemetryStatus.succeeded,
        TelemetryStatus.recovered,
        TelemetryStatus.failed,
        TelemetryStatus.timeout,
      ]) {
        final resolved = entry.value.resolve(
          _event(entry.key, status: status, payload: {'to_phase': phase}),
        );
        if (resolved != null) names.add(resolved);
      }
    }
  }
  return names;
}

void main() {
  test('the SDK blocklist is readable and still contains app_background', () {
    final reserved = _reservedEventNames();

    // Anchors the parser against the exact name that caused the production
    // crash. If this ever fails, the SDK changed and the rest of the file
    // needs a human, not a green tick.
    expect(reserved, contains('app_background'));
    expect(reserved, contains('session_start'));
  });

  test('no outbound analytics name is reserved by Firebase', () {
    final reserved = _reservedEventNames();
    final outbound = _outboundNames();

    expect(
      outbound.length,
      greaterThan(40),
      reason: 'The registry enumeration collapsed; assertions would be vacuous',
    );

    final collisions = outbound.intersection(reserved);
    expect(
      collisions,
      isEmpty,
      reason:
          'Reserved Firebase event name(s) in analyticsEventMappings: '
          '$collisions. logEvent rejects these with an ArgumentError.',
    );
  });

  test('no outbound analytics name uses a reserved prefix', () {
    for (final name in _outboundNames()) {
      for (final prefix in const ['firebase_', 'google_', 'ga_']) {
        expect(
          name.startsWith(prefix),
          isFalse,
          reason: '"$name" uses the reserved "$prefix" prefix',
        );
      }
    }
  });

  test('app_backgrounded never resolves to the reserved app_background', () {
    // Read from the real registry, not from a fixture that could drift away
    // from production independently.
    final mapping = analyticsEventMappings['app_backgrounded'];
    expect(mapping, isNotNull, reason: 'the lifecycle mapping was removed');

    final resolved = mapping!.resolve(
      _event('app_backgrounded', status: TelemetryStatus.succeeded),
    );

    expect(resolved, isNot('app_background'));
    expect(resolved, 'app_backgrounded');
    expect(_reservedEventNames(), isNot(contains(resolved)));
  });

  test('app_resumed still resolves to app_foreground', () {
    // WP19 deliberately did not touch this one: `app_foreground` is not
    // reserved, it has been arriving in GA4 since launch, and renaming it
    // would break reporting continuity for an event that works.
    final resolved = analyticsEventMappings['app_resumed']!.resolve(
      _event('app_resumed', status: TelemetryStatus.succeeded),
    );
    expect(resolved, 'app_foreground');
  });
}
