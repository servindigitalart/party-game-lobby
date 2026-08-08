import 'package:bufon_flutter/core/logging/app_log_destination.dart';
import 'package:bufon_flutter/core/logging/app_log_entry.dart';
import 'package:bufon_flutter/core/logging/app_logger.dart';
import 'package:bufon_flutter/core/logging/log_level.dart';
import 'package:bufon_flutter/core/security/app_check_service.dart';
import 'package:bufon_flutter/core/telemetry/game_telemetry_service.dart';
import 'package:bufon_flutter/core/telemetry/telemetry_event.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _Recorder implements AppLogDestination {
  final List<TelemetryEvent> events = [];

  @override
  void onLog(AppLogEntry entry) {
    final event = entry.telemetryEvent;
    if (event != null) events.add(event);
  }

  int countOf(String name) => events.where((e) => e.name == name).length;
  TelemetryEvent named(String name) => events.firstWhere((e) => e.name == name);
}

void main() {
  late _Recorder recorder;

  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() {
    GameTelemetryService.instance.init();
    recorder = _Recorder();
    AppLogger.instance.registerDestination(recorder);
  });

  tearDown(() => AppLogger.instance.unregisterDestination(recorder));

  group('provider selection', () {
    // A test binary is always a debug binary, so these assert the debug
    // branch. The release branch is asserted by construction below.
    test('debug builds use the debug providers', () {
      expect(kDebugMode, isTrue, reason: 'test binaries run in debug');
      expect(AppCheckService.appleProvider, AppleProvider.debug);
      expect(AppCheckService.androidProvider, AndroidProvider.debug);
    });

    test('the non-debug Apple provider falls back to DeviceCheck', () {
      // App Attest needs iOS 14 and this app deploys to iOS 13. Plain
      // `appAttest` would fail to mint a token on iOS 13 and, under
      // enforcement, lock those users out entirely.
      expect(
        AppleProvider.appAttestWithDeviceCheckFallback,
        isNot(AppleProvider.appAttest),
      );
      expect(
        AppleProvider.values,
        contains(AppleProvider.appAttestWithDeviceCheckFallback),
      );
    });

    test(
      'the non-debug Android provider is Play Integrity, never SafetyNet',
      () {
        // The plugin still exposes a deprecated SafetyNet value, so this
        // guards our choice rather than the SDK's surface: SafetyNet is
        // retired and would mint tokens Firebase rejects.
        expect(
          AppCheckService.androidProviderFor(isDebug: false),
          AndroidProvider.playIntegrity,
        );
        expect(
          AppCheckService.androidProviderFor(isDebug: true),
          AndroidProvider.debug,
        );
      },
    );

    test('the non-debug Apple provider is the fallback variant', () {
      expect(
        AppCheckService.appleProviderFor(isDebug: false),
        AppleProvider.appAttestWithDeviceCheckFallback,
      );
      expect(
        AppCheckService.appleProviderFor(isDebug: true),
        AppleProvider.debug,
      );
    });
  });

  group('activation', () {
    test('activates once and reports which providers were used', () async {
      var calls = 0;
      final service = AppCheckService.withActivator(({
        required appleProvider,
        required androidProvider,
      }) async {
        calls++;
      });

      await service.activate();

      expect(calls, 1);
      expect(service.isActivated, isTrue);
      expect(recorder.countOf('app_check_activated'), 1);

      final event = recorder.named('app_check_activated');
      expect(event.payload['apple_provider'], isNotNull);
      expect(event.payload['android_provider'], isNotNull);
    });

    test('is idempotent: a second activate does nothing', () async {
      var calls = 0;
      final service = AppCheckService.withActivator(({
        required appleProvider,
        required androidProvider,
      }) async {
        calls++;
      });

      await service.activate();
      await service.activate();
      await service.activate();

      // Activating twice throws inside the plugin on some platforms, and a
      // hot restart is enough to reach this path twice.
      expect(calls, 1);
      expect(recorder.countOf('app_check_activated'), 1);
    });

    test('a failure never propagates and never blocks startup', () async {
      final service = AppCheckService.withActivator(({
        required appleProvider,
        required androidProvider,
      }) async {
        throw StateError('no Play Services on this device');
      });

      // An emulator without Play Services, a jailbroken device or a
      // misconfigured console must not stop the game from starting.
      await expectLater(service.activate(), completes);
      expect(service.isActivated, isFalse);
    });

    test('a failure is a warning breadcrumb, not a crash report', () async {
      final service = AppCheckService.withActivator(({
        required appleProvider,
        required androidProvider,
      }) async {
        throw StateError('attestation unavailable');
      });

      await service.activate();

      final event = recorder.named('app_check_activation_failed');
      // Simulators cannot attest; one crash report per launch would bury
      // every real bug in the beta.
      expect(event.severity, AppLogLevel.warning);
      expect(event.status, TelemetryStatus.failed);
    });

    test('a failed activation can be retried', () async {
      var shouldFail = true;
      var calls = 0;
      final service = AppCheckService.withActivator(({
        required appleProvider,
        required androidProvider,
      }) async {
        calls++;
        if (shouldFail) throw StateError('transient');
      });

      await service.activate();
      expect(service.isActivated, isFalse);

      shouldFail = false;
      await service.activate();

      expect(calls, 2);
      expect(service.isActivated, isTrue);
    });
  });
}
