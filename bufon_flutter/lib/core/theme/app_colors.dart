// core/theme/app_colors.dart

import 'package:flutter/material.dart';

/// BUFÓN Color Palette
/// Premium dark theme with deep red accents and gold highlights
class AppColors {
  AppColors._();

  // Background colors
  static const Color background = Color(0xFF111111);
  static const Color surface = Color(0xFF1A1A2E); // Card backgrounds
  static const Color surfaceDark = Color(0xFF16213E); // Darker surfaces
  static const Color backgroundElevated = Color(0xFF1A1A2E);
  static const Color backgroundCard = Color(0xFF16213E);
  static const Color backgroundAccent = Color(0xFF0F3460);

  // Border and divider colors
  static const Color border = Color(0xFF2A2A3E);
  static const Color divider = Color(0xFF1F1F2E);
  static const Color accent = Color(0xFF00D9FF); // Cyan accent

  // Primary colors
  static const Color primary = Color(0xFFE94560); // Deep red
  static const Color primaryLight = Color(0xFFFF6B7A);
  static const Color primaryDark = Color(0xFFB8354B);

  // Accent colors
  static const Color gold = Color(0xFFFFD700);
  static const Color goldDark = Color(0xFFFFB700);
  static const Color amber = Color(0xFFFFA500);

  // Semantic colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFE94560);
  static const Color info = Color(0xFF2196F3);

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textTertiary = Color(0xFF808080);
  static const Color textDisabled = Color(0xFF4D4D4D);

  // Special effects
  static const Color glow = Color(0xFFFF6B7A);
  static const Color shimmer = Color(0x33FFFFFF);

  // Timer colors
  static const Color timerNormal = Color(0xFF4CAF50);
  static const Color timerWarning = Color(0xFFFF9800);
  static const Color timerDanger = Color(0xFFE94560);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold, goldDark],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [background, backgroundElevated],
  );
}
