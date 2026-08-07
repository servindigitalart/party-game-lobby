import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'analytics/analytics_destination.dart';
import 'analytics/analytics_service.dart';
import 'core/crash/crash_reporter.dart';
import 'core/crash/firebase_crashlytics_backend.dart';
import 'core/logging/app_logger.dart';
import 'core/logging/log_category.dart';
import 'core/telemetry/game_telemetry_service.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';

void main() {
  // Everything runs inside the guarded zone so unhandled asynchronous
  // errors — including any raised while Firebase itself is starting —
  // reach CrashReporter. ensureInitialized() must run inside it so the
  // binding and the zone match.
  CrashReporter.instance.guard(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Structured logging must be ready before any other service starts,
    // so every subsequent init step can be logged.
    AppLogger.instance.init();

    // Installs FlutterError.onError and PlatformDispatcher.onError, and
    // starts buffering. Deliberately before Firebase: the backend is not
    // available yet, but failures from here on are captured and flushed
    // once it is.
    CrashReporter.instance.initialize();

    // Telemetry owns Session Context, so it must be wired into AppLogger
    // before anything else produces an event or a log line. Its events
    // become crash breadcrumbs automatically.
    final telemetry = GameTelemetryService.instance;
    telemetry.init();

    // Set system UI overlay style for dark theme
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF111111),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    // Lock to portrait mode
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Crashlytics is usable now; this flushes anything buffered above.
    await CrashReporter.instance.attachBackend(FirebaseCrashlyticsBackend());

    // Firebase Analytics is just another destination: register it and it
    // starts receiving telemetry events with no gameplay code involved.
    final analyticsDestination = AnalyticsDestination();
    await analyticsDestination.initialize();
    AppLogger.instance.registerDestination(analyticsDestination);

    // Initialize Mobile Ads SDK
    await MobileAds.instance.initialize();

    // The session opens only once the analytics destination is listening;
    // emitting earlier would keep the crash breadcrumb but silently drop the
    // session and launch events, which are the base of every retention
    // funnel. Crash context is unaffected — device context is already set by
    // telemetry.init() above, and there is no room yet at this point.
    await AnalyticsService.instance.initialize();
    telemetry.startSession();
    telemetry.track(
      AppLogCategory.app,
      'app_started',
      payload: await AnalyticsService.instance.readLaunchMetrics(),
    );

    runApp(const ProviderScope(child: MyApp()));
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BUFÓN',
      debugShowCheckedModeBanner: false,
      // Fase 3A: AppTheme.darkTheme now means the new Butter Bliss dark
      // theme (unused until screens migrate, see BUFON_DESIGN_SYSTEM.md
      // Capítulo 35). The app keeps running on the untouched legacy theme
      // here until then.
      theme: AppTheme.legacyTheme,
      home: const HomeScreen(),
    );
  }
}
