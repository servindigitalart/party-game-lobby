import 'package:flutter/services.dart';

/// Service for providing haptic feedback throughout the app
class HapticService {
  /// Light impact - for subtle interactions (button taps, selections)
  static Future<void> lightImpact() async {
    await HapticFeedback.lightImpact();
  }

  /// Medium impact - for important interactions (votes, submissions)
  static Future<void> mediumImpact() async {
    await HapticFeedback.mediumImpact();
  }

  /// Heavy impact - for significant events (winning, errors)
  static Future<void> heavyImpact() async {
    await HapticFeedback.heavyImpact();
  }

  /// Selection click - for scrolling through items
  static Future<void> selectionClick() async {
    await HapticFeedback.selectionClick();
  }

  /// Vibrate pattern - for celebrations
  static Future<void> vibrate() async {
    await HapticFeedback.vibrate();
  }

  /// Success feedback - medium impact for positive actions
  static Future<void> success() async {
    await mediumImpact();
  }

  /// Error feedback - heavy impact for errors
  static Future<void> error() async {
    await heavyImpact();
  }

  /// Warning feedback - light impact for warnings
  static Future<void> warning() async {
    await lightImpact();
  }

  /// Celebration feedback - multiple impacts for winning
  static Future<void> celebration() async {
    await heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await lightImpact();
  }
}
