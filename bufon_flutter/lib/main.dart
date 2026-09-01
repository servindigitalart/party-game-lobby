import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'analytics/analytics_destination.dart';
import 'analytics/retention_tracker.dart';
import 'core/crash/crash_reporter.dart';
import 'core/crash/firebase_crashlytics_backend.dart';
import 'core/logging/app_logger.dart';
import 'core/logging/log_category.dart';
import 'core/security/app_check_service.dart';
import 'core/telemetry/app_session_observer.dart';
import 'core/telemetry/game_telemetry_service.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/game_providers.dart';
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

    // System UI overlay style is no longer set globally. Fase 2A gives each
    // screen a phase register (PhaseScope), and each register carries its own
    // status/navigation bar styling — a single global dark style contradicted
    // the screens that render on Paper.

    // The bundled brand fonts ship under the SIL Open Font License, which
    // requires the licence text to travel with the software. Registering it
    // here surfaces it in Flutter's own "view licences" page.
    LicenseRegistry.addLicense(_brandFontLicenses);

    // Lock to portrait mode
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // App Check before any Firebase service is touched, so the very first
    // Firestore, Functions or Storage request already carries an attestation
    // token. Activating later would leave a window of unattested traffic
    // that enforcement would reject.
    await AppCheckService.instance.activate();

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
    await RetentionTracker.instance.initialize();

    // Owns startSession/endSession from here on, so session duration tracks
    // real foreground time instead of never ending.
    AppSessionObserver().start();

    telemetry.track(
      AppLogCategory.app,
      'app_started',
      payload: await RetentionTracker.instance.readLaunchMetrics(),
    );

    // Fase 2B WP20 (R-07 / audit A C-2 + L-1). The anonymous identity is
    // established *here*, before the first frame.
    //
    // `userIdProvider` defaulted to null and was assigned in exactly two
    // places — home_screen's create-room and join-room handlers. So a clean
    // install, and every relaunch of a returning player who already had XP,
    // reached Profile, Leaderboard and the season banner with no auth
    // session. Firestore denied all three (`firestore.rules:34,172,213,227`)
    // and each surface reported a *failure* for what was only "nobody ever
    // signed in". That is the root the Apple audit hangs four findings off.
    final launchUserId = await _resolveAnonymousIdentity();

    runApp(
      ProviderScope(
        // Seeds the initial value only. `userIdProvider` stays a writable
        // `StateProvider`, so home_screen's existing assignments — which this
        // package does not touch — keep working exactly as before.
        overrides: [userIdProvider.overrideWith((ref) => launchUserId)],
        child: const MyApp(),
      ),
    );
  });
}

/// Returns the anonymous uid to open the app with, or `null` if one could not
/// be established.
///
/// `currentUser` is read first because nothing in the app ever did (audit A
/// L-1): a returning player restores the uid they already have, with no
/// network round trip and without minting a second anonymous account.
///
/// Called after `AppCheckService.activate()` on purpose, so the sign-in
/// request carries an attestation token like every other Firebase call. No
/// attestation behaviour changes.
///
/// **Deliberately never fatal.** If Anonymous Auth is disabled in the console
/// or the device is offline at launch, the app must still start. It starts
/// without an identity — exactly as it did before this change — and the
/// surfaces that need one say so honestly rather than pretending the player
/// simply has no progress yet.
Future<String?> _resolveAnonymousIdentity() async {
  final existing = FirebaseAuth.instance.currentUser?.uid;
  if (existing != null) return existing;

  try {
    return (await FirebaseAuth.instance.signInAnonymously()).user?.uid;
  } catch (error, stackTrace) {
    CrashReporter.instance.recordNonFatal(
      error,
      stackTrace: stackTrace,
      category: AppLogCategory.firebase,
      reason: 'Anonymous sign-in failed at launch',
    );
    return null;
  }
}

Stream<LicenseEntry> _brandFontLicenses() async* {
  final license = await rootBundle.loadString('assets/fonts/OFL.txt');
  yield LicenseEntryWithLineBreaks(const ['PlusJakartaSans'], license);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BUFÓN',
      debugShowCheckedModeBanner: false,
      // Fase 2A: the app's identity is the Butter Bliss system, not the
      // legacy casino theme. `themeMode` is pinned to light on purpose —
      // light and dark are not a user preference in Bufón, they are the two
      // emotional *registers* the design system defines (Capítulo 29/30:
      // Paper is "the social life around the game", Graphite is "the game
      // live"). Screens that belong to the Graphite register declare it
      // themselves through `PhaseScope`, which is the only thing allowed to
      // switch registers.
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      // Fase 2B WP4: the accessibility floor's text-scaling band.
      //
      // Capítulo 28 asks for 150–200% text support, and before this the app
      // had zero `textScaler` handling of any kind: the system scale passed
      // straight through to compositions with fixed geometry (the 80 pt
      // profile emoji, the 100/120 px leaderboard podium, the timer arc), and
      // `TYPOGRAPHY_AUDIT.md` §7 predicts a hard overflow rather than a
      // cramped layout.
      //
      // The band is the blueprint's own compromise, not a new policy: clamp to
      // 1.4 so the direction of the user's preference is always honoured and
      // the game loop never breaks, in preference to an unbounded aspiration
      // that overflows. It is deliberately *global* — a per-screen scaler
      // would have to be re-argued on every screen added.
      //
      // The floor is 1.0: shrinking type below the design scale is not an
      // accessibility win, and the Butter Bliss scale is already at its
      // legible minimum at 12 pt.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 1.0,
        maxScaleFactor: 1.4,
        child: child!,
      ),
      home: const HomeScreen(),
    );
  }
}
