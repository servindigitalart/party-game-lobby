// providers/title_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/controllers/title_controller.dart';
import '../models/title.dart';
import 'game_providers.dart';
import 'progression_providers.dart';

/// Title controller provider
final titleControllerProvider = Provider<TitleController>((ref) {
  return TitleController();
});

/// User's unlocked titles stream provider
final userUnlockedTitlesProvider = StreamProvider<List<UnlockedTitle>>((ref) {
  final userId = ref.watch(userIdProvider);

  if (userId == null) {
    return Stream.value([]);
  }

  final controller = ref.watch(titleControllerProvider);
  return controller.watchUserTitles(userId);
});

/// User's unlocked titles future provider (one-time fetch)
final userUnlockedTitlesFutureProvider =
    FutureProvider.family<List<UnlockedTitle>, String>((ref, uid) async {
      final controller = ref.watch(titleControllerProvider);
      return controller.getUnlockedTitles(uid);
    });

/// Check if user has specific title unlocked
final hasTitleUnlockedProvider = FutureProvider.family<bool, (String, String)>((
  ref,
  params,
) async {
  final (uid, titleId) = params;
  final controller = ref.watch(titleControllerProvider);
  return controller.hasTitleUnlocked(uid: uid, titleId: titleId);
});

/// Get user's equipped title (from profile)
final equippedTitleProvider = Provider<BufonTitle?>((ref) {
  final profile = ref.watch(userProfileStreamProvider).value;

  if (profile?.equippedTitleId == null) {
    return null;
  }

  return Titles.getById(profile!.equippedTitleId!);
});

/// Get user's next unlockable titles
final nextUnlockableTitlesProvider =
    FutureProvider.family<List<BufonTitle>, String>((ref, uid) async {
      final profile = await ref.watch(userProfileFutureProvider(uid).future);
      final controller = ref.watch(titleControllerProvider);

      return controller.getNextUnlockableTitles(
        uid: uid,
        profile: profile,
        limit: 3,
      );
    });

/// All available titles (static)
final allTitlesProvider = Provider<List<BufonTitle>>((ref) {
  return Titles.all;
});

/// Titles by rarity
final titlesByRarityProvider = Provider.family<List<BufonTitle>, TitleRarity>((
  ref,
  rarity,
) {
  return Titles.getByRarity(rarity);
});
