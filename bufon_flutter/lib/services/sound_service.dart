import 'package:flutter/services.dart';

/// Minimal native sound cues for game feel.
///
/// Uses Flutter's built-in system sounds to avoid adding an audio dependency
/// before the core loop is playtested.
class SoundService {
  SoundService._();

  static Future<void> tap() async {
    await SystemSound.play(SystemSoundType.click);
  }

  static Future<void> transition() async {
    await SystemSound.play(SystemSoundType.click);
  }

  static Future<void> reveal() async {
    await SystemSound.play(SystemSoundType.alert);
  }

  static Future<void> countdownPulse() async {
    await SystemSound.play(SystemSoundType.click);
  }

  static Future<void> celebration() async {
    await SystemSound.play(SystemSoundType.alert);
  }
}
