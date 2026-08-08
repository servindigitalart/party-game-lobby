import 'dart:io';

import 'package:bufon_flutter/core/config/admob_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// AdMob ids are the one class of constant that is invisible until it costs
/// money: a wrong one means either no revenue or serving Google's sample
/// inventory against a real account, and neither shows up in a smoke test.
///
/// These assertions run against the compiled-in tables, so they hold for
/// whatever build mode the suite runs in.
void main() {
  const testPrefix = AdMobConfig.testAccountPrefix;
  const productionAccount = 'ca-app-pub-8727546001742642';

  final config = AdMobConfig.instance;

  tearDown(config.clearOverrides);

  group('production table', () {
    // Resolution depends on kDebugMode, which the test binary controls, so
    // the tables are asserted directly rather than through idsFor().
    test('no id is a leftover placeholder', () {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        for (final id in config.idsFor(platform).all) {
          expect(id, isNot(contains('XXXX')), reason: id);
          expect(id, isNot(contains('YYYY')), reason: id);
          expect(id, matches(RegExp(r'^ca-app-pub-\d+[~/]\d+$')), reason: id);
        }
      }
    });

    test('Android and iOS never share an id', () {
      final android = config.idsFor(TargetPlatform.android).all;
      final ios = config.idsFor(TargetPlatform.iOS).all;
      expect(android.toSet().intersection(ios.toSet()), isEmpty);
    });

    test('an app id is an app id and a unit id is a unit id', () {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        final ids = config.idsFor(platform);
        // AdMob uses ~ for app ids and / for ad units. Swapping them fails
        // silently at runtime.
        expect(ids.appId, contains('~'));
        expect(ids.rewardedId, contains('/'));
        expect(ids.interstitialId, contains('/'));
      }
    });
  });

  group('build mode', () {
    // resolve() takes isDebug as a parameter precisely so the release branch
    // can be asserted here. A test binary is always a debug binary.
    test('DEBUG resolves to Google test units on both platforms', () {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        final ids = AdMobConfig.resolve(platform: platform, isDebug: true);
        for (final id in ids.all) {
          expect(id, startsWith(testPrefix), reason: '$platform $id');
        }
      }
    });

    test('RELEASE resolves to production units on both platforms', () {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        final ids = AdMobConfig.resolve(platform: platform, isDebug: false);
        for (final id in ids.all) {
          expect(id, startsWith(productionAccount), reason: '$platform $id');
          expect(id, isNot(startsWith(testPrefix)), reason: '$platform $id');
        }
      }
    });

    test('RELEASE ships exactly the ids AdMob issued', () {
      final android = AdMobConfig.resolve(
        platform: TargetPlatform.android,
        isDebug: false,
      );
      expect(android.appId, androidAppId);
      expect(android.rewardedId, 'ca-app-pub-8727546001742642/2145844811');
      expect(android.interstitialId, 'ca-app-pub-8727546001742642/9586572322');

      final ios = AdMobConfig.resolve(
        platform: TargetPlatform.iOS,
        isDebug: false,
      );
      expect(ios.appId, iosAppId);
      expect(ios.rewardedId, 'ca-app-pub-8727546001742642/4963579842');
      expect(ios.interstitialId, 'ca-app-pub-8727546001742642/8645739750');
    });

    test('debug and release tables share no id at all', () {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        final debug = AdMobConfig.resolve(
          platform: platform,
          isDebug: true,
        ).all.toSet();
        final release = AdMobConfig.resolve(
          platform: platform,
          isDebug: false,
        ).all.toSet();
        expect(debug.intersection(release), isEmpty);
      }
    });

    test('isSafeFor is true for every platform in this build', () {
      expect(config.isSafeFor(TargetPlatform.android), isTrue);
      expect(config.isSafeFor(TargetPlatform.iOS), isTrue);
      expect(config.unsafeIds(TargetPlatform.android), isEmpty);
      expect(config.unsafeIds(TargetPlatform.iOS), isEmpty);
    });
  });

  group('remote overrides', () {
    test('an override replaces the rewarded id without touching the rest', () {
      final before = config.idsFor(TargetPlatform.iOS);

      config.applyOverrides({
        AdMobOverrideKeys.rewardedId: 'ca-app-pub-8727546001742642/1111111111',
      });

      final after = config.idsFor(TargetPlatform.iOS);
      expect(after.rewardedId, 'ca-app-pub-8727546001742642/1111111111');
      expect(after.appId, before.appId);
      expect(after.interstitialId, before.interstitialId);
    });

    test('clearing restores the compiled-in table', () {
      final original = config.idsFor(TargetPlatform.android).rewardedId;
      config.applyOverrides({
        AdMobOverrideKeys.rewardedId: 'ca-app-pub-8727546001742642/2222222222',
      });
      config.clearOverrides();
      expect(config.idsFor(TargetPlatform.android).rewardedId, original);
    });

    test('an empty or null override is dropped rather than applied', () {
      final original = config.idsFor(TargetPlatform.iOS).rewardedId;
      config.applyOverrides({AdMobOverrideKeys.rewardedId: ''});
      expect(config.idsFor(TargetPlatform.iOS).rewardedId, original);
      config.applyOverrides({AdMobOverrideKeys.rewardedId: null});
      expect(config.idsFor(TargetPlatform.iOS).rewardedId, original);
    });
  });

  group('native configuration matches Dart', () {
    // The SDK reads the app id from the native manifests before any Dart
    // runs, so a mismatch between these files and the table above is
    // undetectable at runtime — the app just initializes against the wrong
    // AdMob application.
    test('Info.plist carries the production iOS app id', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains(iosAppId));
      expect(plist, isNot(contains(testPrefix)));
    });

    test('AndroidManifest carries the production Android app id', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains(androidAppId));
      expect(manifest, isNot(contains(testPrefix)));
    });
  });
}

/// Declared here rather than read from AdMobConfig so the native files are
/// checked against the literal AdMob issued, not against whatever the Dart
/// table currently says. A single typo would otherwise satisfy both sides.
const String iosAppId = 'ca-app-pub-8727546001742642~5911765200';
const String androidAppId = 'ca-app-pub-8727546001742642~7604120826';
