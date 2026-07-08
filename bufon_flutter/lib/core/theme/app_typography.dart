// core/theme/app_typography.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';

/// BUFÓN Typography System
/// Premium, readable typography with personality
class AppTypography {
  AppTypography._();

  // Headings
  static const TextStyle h1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.2,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    height: 1.3,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    height: 1.3,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );

  static const TextStyle h4 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  // Body text
  static const TextStyle body1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle body2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  // Special
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.4,
    color: AppColors.textTertiary,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.5,
  );

  static const TextStyle buttonLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: 0.5,
  );

  // Display (for big numbers, scores)
  static const TextStyle display = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.bold,
    height: 1.1,
    color: AppColors.textPrimary,
    letterSpacing: -1,
  );

  static const TextStyle displayGold = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.bold,
    height: 1.1,
    color: AppColors.gold,
    letterSpacing: -1,
  );
}
