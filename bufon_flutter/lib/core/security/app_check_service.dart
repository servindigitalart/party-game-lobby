// core/security/app_check_service.dart

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import '../logging/log_category.dart';
import '../logging/log_level.dart';
import '../telemetry/game_telemetry_service.dart';

/// Attests that Firebase traffic comes from a genuine build of this app.
///
/// App Check mints a short-lived token from a platform attestation service
/// and attaches it to every Firestore, Functions and Storage request. Once
/// enforcement is switched on in the Firebase console, requests without a
/// valid token are rejected — which is what stops a script with the API key
/// (the key is in the repo, as it must be) from talking to the backend at
/// all.
///
/// ## Providers
///
/// | Build              | iOS                                | Android        |
/// |--------------------|------------------------------------|----------------|
/// | Debug              | Debug provider                     | Debug provider |
/// | Profile / Release  | App Attest → DeviceCheck fallback  | Play Integrity |
///
/// Profile is deliberately grouped with release: a profile build is what
/// gets handed round before a release and has to behave like the real thing.
///
/// ## Enforcement
///
/// Nothing here enables enforcement. That is a console setting, per service,
/// and switching it from Monitor to Enforce requires **no code change** —
/// the client already sends tokens either way. See
/// docs/engineering/APP_CHECK.md.
class AppCheckService {
  AppCheckService._({AppCheckActivator? activator}) : _activator = activator;

  static final AppCheckService instance = AppCheckService._();

  /// An instance driven by [activator] instead of the real plugin.
  ///
  /// The seam is a function rather than a fake `FirebaseAppCheck`: the
  /// plugin class cannot be constructed without a live Firebase app, so a
  /// test that wanted one would have to boot Firebase to assert which
  /// provider gets chosen.
  @visibleForTesting
  factory AppCheckService.withActivator(AppCheckActivator activator) =>
      AppCheckService._(activator: activator);

  final AppCheckActivator? _activator;
  final GameTelemetryService _telemetry = GameTelemetryService.instance;

  bool _isActivated = false;

  /// Whether activation has run and succeeded.
  bool get isActivated => _isActivated;

  /// Provider used on Apple platforms for the current build mode.
  ///
  /// `appAttestWithDeviceCheckFallback` rather than plain `appAttest`
  /// because App Attest needs iOS 14 and this app deploys to iOS 13. On a
  /// device that cannot attest, the SDK falls back to DeviceCheck by itself
  /// instead of failing to produce a token — which, under enforcement,
  /// would lock those users out of the game entirely.
  static AppleProvider get appleProvider =>
      appleProviderFor(isDebug: kDebugMode);

  /// The Apple table as a pure function.
  ///
  /// [isDebug] is a parameter rather than a `kDebugMode` read so the
  /// release choice can be asserted from a test binary, which is always a
  /// debug binary.
  @visibleForTesting
  static AppleProvider appleProviderFor({required bool isDebug}) => isDebug
      ? AppleProvider.debug
      : AppleProvider.appAttestWithDeviceCheckFallback;

  /// Provider used on Android for the current build mode.
  static AndroidProvider get androidProvider =>
      androidProviderFor(isDebug: kDebugMode);

  /// The Android table as a pure function. See [appleProviderFor].
  @visibleForTesting
  static AndroidProvider androidProviderFor({required bool isDebug}) =>
      isDebug ? AndroidProvider.debug : AndroidProvider.playIntegrity;

  /// Activates App Check.
  ///
  /// Must be called after `Firebase.initializeApp()` and before the first
  /// use of Firestore, Functions or Storage, so that the very first request
  /// already carries a token.
  ///
  /// Idempotent: repeated calls after a successful activation do nothing.
  /// Activating twice throws inside the plugin on some platforms, and a
  /// hot restart is enough to reach this path twice.
  ///
  /// Never throws. If attestation cannot be set up — an emulator without
  /// Play Services, a jailbroken device, a misconfigured console — the app
  /// still starts. While the console is in Monitor mode that costs nothing;
  /// once it is in Enforce mode those requests fail on their own, and the
  /// failure telemetry emitted here is what explains why.
  Future<void> activate() async {
    if (_isActivated) return;

    try {
      final activate = _activator ?? _defaultActivator;
      await activate(
        appleProvider: appleProvider,
        androidProvider: androidProvider,
      );

      _isActivated = true;

      _telemetry.track(
        AppLogCategory.firebase,
        'app_check_activated',
        payload: {
          'apple_provider': appleProvider.name,
          'android_provider': androidProvider.name,
        },
      );
    } catch (error, stackTrace) {
      // Warning, not error: on a simulator or an emulator without Play
      // Services this is expected, and a crash report per launch would be
      // pure noise. It is still in the breadcrumb trail, so a wave of
      // permission-denied after enforcement is switched on has an
      // explanation sitting right before it.
      _telemetry.fail(
        AppLogCategory.firebase,
        'app_check_activation_failed',
        error: error,
        stackTrace: stackTrace,
        severity: AppLogLevel.warning,
      );
    }
  }

  /// Resets activation state. Tests only.
  @visibleForTesting
  void resetForTest() => _isActivated = false;

  static Future<void> _defaultActivator({
    required AppleProvider appleProvider,
    required AndroidProvider androidProvider,
  }) {
    return FirebaseAppCheck.instance.activate(
      appleProvider: appleProvider,
      androidProvider: androidProvider,
    );
  }
}

/// Performs the platform activation. Exists so the provider choice can be
/// asserted without a live Firebase app.
typedef AppCheckActivator =
    Future<void> Function({
      required AppleProvider appleProvider,
      required AndroidProvider androidProvider,
    });
