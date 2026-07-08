// providers/progression_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/controllers/progression_controller.dart';
import '../models/user_profile.dart';
import 'game_providers.dart';
import 'leaderboard_providers.dart';
import 'title_providers.dart';

/// Progression controller provider
final progressionControllerProvider = Provider<ProgressionController>((ref) {
  final leaderboardController = ref.watch(leaderboardControllerProvider);
  final titleController = ref.watch(titleControllerProvider);
  return ProgressionController(
    leaderboardController: leaderboardController,
    titleController: titleController,
  );
});

/// User profile stream provider
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
