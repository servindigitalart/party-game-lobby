// core/config/admob_config.dart

import 'package:flutter/foundation.dart';

/// The three AdMob identifiers one platform needs.
///
/// Grouped rather than kept as loose strings so a platform can never be
/// half-configured: adding a format means adding a field here, and every
/// platform is then forced to supply it.
@immutable
class AdMobIds {
  const AdMobIds({
    required this.appId,
    required this.rewardedId,
    required this.interstitialId,
  });

  /// Also declared natively — `GADApplicationIdentifier` in Info.plist and
  /// `com.google.android.gms.ads.APPLICATION_ID` in AndroidManifest.xml.
  /// The SDK reads the native value; this one exists so the pairing can be
  /// asserted from Dart.
  final String appId;

  final String rewardedId;

  /// Not shown by the game yet. Declared now so the day it is used there is
  /// nothing to look up and no second place for an id to live.
  final String interstitialId;

  AdMobIds copyWith({
    String? appId,
    String? rewardedId,
    String? interstitialId,
  }) {
    return AdMobIds(
      appId: appId ?? this.appId,
      rewardedId: rewardedId ?? this.rewardedId,
      interstitialId: interstitialId ?? this.interstitialId,
    );
  }

  /// Every id this bundle carries, for validation.
  List<String> get all => [appId, rewardedId, interstitialId];
}

/// Keys used to override an id at runtime.
///
/// Stable strings so a future Remote Config parameter can be named after
/// them without call sites changing.
class AdMobOverrideKeys {
  AdMobOverrideKeys._();

  static const String rewardedId = 'admob_rewarded_id';
  static const String interstitialId = 'admob_interstitial_id';
}

/// Single source of truth for every AdMob identifier.
///
/// ## Why this exists
///
/// The ids used to live inside AdService, with the production constants left
/// as `ca-app-pub-XXXX/YYYY` placeholders and the switch keyed on
/// `kReleaseMode`. That meant release builds requested an invalid ad unit —
/// rewarded ads never loaded, and the ad-unlock path of the monetization
/// gate was dead — while profile builds silently served test ads.
///
/// ## Build mode
///
/// Debug serves Google's official test units. **Profile and release both
/// serve production**, because a profile build is what gets handed round for
/// pre-release testing and needs to behave like the real thing. The old
/// `kReleaseMode` check put profile on test ads.
///
/// ## App id
///
/// The app id is compile-time native configuration: the SDK reads it from
/// Info.plist / AndroidManifest.xml before any Dart runs, so it cannot vary
/// by build mode. Both manifests therefore carry the **production** app id in
/// every build, which is what Google documents — a real app id paired with
/// test ad units is the supported way to test.
class AdMobConfig {
  AdMobConfig._();

  static final AdMobConfig instance = AdMobConfig._();

  /// Prefix of every id in Google's public sample account. Nothing with this
  /// prefix may ever serve in a non-debug build.
  static const String testAccountPrefix = 'ca-app-pub-3940256099942544';

  // --- Production -----------------------------------------------------------

  static const AdMobIds _productionAndroid = AdMobIds(
    appId: 'ca-app-pub-8727546001742642~7604120826',
    rewardedId: 'ca-app-pub-8727546001742642/2145844811',
    interstitialId: 'ca-app-pub-8727546001742642/9586572322',
  );

  static const AdMobIds _productionIOS = AdMobIds(
    appId: 'ca-app-pub-8727546001742642~5911765200',
    rewardedId: 'ca-app-pub-8727546001742642/4963579842',
    interstitialId: 'ca-app-pub-8727546001742642/8645739750',
  );

  // --- Google's official test units -----------------------------------------

  static const AdMobIds _testAndroid = AdMobIds(
    appId: '$testAccountPrefix~3347511713',
    rewardedId: '$testAccountPrefix/5224354917',
    interstitialId: '$testAccountPrefix/1033173712',
  );

  static const AdMobIds _testIOS = AdMobIds(
    appId: '$testAccountPrefix~1458002511',
    rewardedId: '$testAccountPrefix/1712485313',
    interstitialId: '$testAccountPrefix/4411468910',
  );

  final Map<String, String> _overrides = {};

  /// Ids for [platform] in the current build mode, with any override applied.
  ///
  /// [platform] defaults to the running platform; it is a parameter so the
  /// resolution table can be exercised for both platforms from one test run.
  AdMobIds idsFor([TargetPlatform? platform]) {
    final base = resolve(
      platform: platform ?? defaultTargetPlatform,
      isDebug: kDebugMode,
    );

    if (_overrides.isEmpty) return base;

    return base.copyWith(
      rewardedId: _overrides[AdMobOverrideKeys.rewardedId],
      interstitialId: _overrides[AdMobOverrideKeys.interstitialId],
    );
  }

  /// The resolution table itself, as a pure function.
  ///
  /// [isDebug] is a parameter rather than a direct `kDebugMode` read so both
  /// branches can be asserted from one test run. A test binary is always a
  /// debug binary, so without this the release branch — the one that costs
  /// money if it is wrong — would never be exercised.
  @visibleForTesting
  static AdMobIds resolve({
    required TargetPlatform platform,
    required bool isDebug,
  }) {
    final isAndroid = platform == TargetPlatform.android;
    return isDebug
        ? (isAndroid ? _testAndroid : _testIOS)
        : (isAndroid ? _productionAndroid : _productionIOS);
  }

  AdMobIds get ids => idsFor();

  String get appId => ids.appId;
  String get rewardedId => ids.rewardedId;
  String get interstitialId => ids.interstitialId;

  /// Applies runtime overrides, e.g. from Remote Config.
  ///
  /// Nothing reads Remote Config today. This is the seam that lets it be
  /// added later without touching AdService or any call site: fetch the
  /// values, hand them here, and the next `rewardedId` reflects them.
  ///
  /// An override that would reintroduce a Google test id outside debug is
  /// rejected, so a bad remote value cannot do what a bad constant used to.
  void applyOverrides(Map<String, String?> values) {
    values.forEach((key, value) {
      if (value == null || value.isEmpty) {
        _overrides.remove(key);
        return;
      }
      if (!kDebugMode && value.startsWith(testAccountPrefix)) {
        assert(false, 'Refused a Google test id from an override: $key');
        return;
      }
      _overrides[key] = value;
    });
  }

  /// Drops every override. Restores the compiled-in table.
  void clearOverrides() => _overrides.clear();

  /// Whether the resolved ids are safe to serve in this build.
  ///
  /// False means a non-debug build resolved to a Google test unit, which
  /// would mean serving unpaid sample ads against a real account.
  bool isSafeFor([TargetPlatform? platform]) {
    if (kDebugMode) return true;
    return !idsFor(platform).all.any((id) => id.startsWith(testAccountPrefix));
  }

  /// Ids that failed [isSafeFor], for reporting.
  List<String> unsafeIds([TargetPlatform? platform]) {
    if (kDebugMode) return const [];
    return idsFor(
      platform,
    ).all.where((id) => id.startsWith(testAccountPrefix)).toList();
  }
}
