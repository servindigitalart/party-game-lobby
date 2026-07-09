import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'analytics/analytics_service.dart';
import 'core/theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    options: const FirebaseOptions(
      apiKey: 'AIzaSyDOfzM0SsG8i3WSkbydigwZtDsHhwFXodk',
      authDomain: 'funpartygame18.firebaseapp.com',
      projectId: 'funpartygame18',
      storageBucket: 'funpartygame18.firebasestorage.app',
      messagingSenderId: '252719014233',
      appId: '1:252719014233:web:467db7942406be9581ec48',
      measurementId: 'G-3CPS02W1VS',
    ),
  );

  // Initialize Mobile Ads SDK
  await MobileAds.instance.initialize();

  // Initialize Analytics
  await AnalyticsService.instance.initialize();
  await AnalyticsService.instance.logAppOpened();
  await AnalyticsService.instance.logSessionStarted();

  runApp(const ProviderScope(child: MyApp()));
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
