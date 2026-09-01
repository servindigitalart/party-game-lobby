// providers/progression_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/controllers/progression_controller.dart';
import '../models/user_profile.dart';
import 'game_providers.dart';

/// Progression controller provider
// Progression writes live in the onMatchCompleted Cloud Function, so this
// controller no longer needs the leaderboard or title controllers injected.
final progressionControllerProvider = Provider<ProgressionController>((ref) {
  return ProgressionController();
});

/// User profile stream provider.
///
/// **The contract, made explicit by WP20.** `null` data means *signed in, no
/// profile document written yet* — the honest empty state of a player who has
/// not finished a match. It does **not** mean "something went wrong", and no
/// consumer may render it as a failure.
///
/// A missing identity is a different thing and is deliberately still reported
/// as `null` here rather than as a stream error: `title_providers.dart:45`
/// reads this provider's `.value` and an error would be indistinguishable
/// from an empty profile there. The identity/data distinction is drawn where
/// it can be drawn correctly — at the screen, which reads `userIdProvider`
/// alongside this provider (see `profile_screen.dart`).
final userProfileStreamProvider = StreamProvider<UserProfile?>((ref) {
  final userId = ref.watch(userIdProvider);

  if (userId == null) {
    return Stream.value(null);
  }

  final controller = ref.watch(progressionControllerProvider);
  return controller.watchProfile(userId);
});

/// User profile future provider (for one-time fetch)
final userProfileFutureProvider = FutureProvider.family<UserProfile, String>((
  ref,
  uid,
) async {
  final controller = ref.watch(progressionControllerProvider);
  return controller.getOrCreateProfile(uid);
});
