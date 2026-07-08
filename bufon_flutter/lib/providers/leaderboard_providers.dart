// providers/leaderboard_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/leaderboard_repository.dart';
import '../domain/controllers/leaderboard_controller.dart';
import '../models/leaderboard_entry.dart';
import 'game_providers.dart';

/// Leaderboard repository provider
final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return LeaderboardRepository();
});

/// Leaderboard controller provider
final leaderboardControllerProvider = Provider<LeaderboardController>((ref) {
  final repository = ref.watch(leaderboardRepositoryProvider);
  return LeaderboardController(repository: repository);
});

/// Top players provider for a specific leaderboard type
///
/// Returns list of top 50 players
final topPlayersProvider =
    FutureProvider.family<List<LeaderboardEntry>, LeaderboardType>((
      ref,
      type,
    ) async {
      final controller = ref.watch(leaderboardControllerProvider);
      return controller.fetchTopPlayers(type: type);
    });

/// User rank provider for a specific leaderboard type
///
/// Returns user's rank and stats, or null if not on leaderboard
final userRankProvider =
    FutureProvider.family<LeaderboardEntry?, (String, LeaderboardType)>((
      ref,
      params,
    ) async {
      final (uid, type) = params;
      final controller = ref.watch(leaderboardControllerProvider);
      return controller.fetchUserRank(uid: uid, type: type);
    });

/// Current user's rank provider (uses userIdProvider)
///
/// Convenience provider that automatically uses current user's ID
final currentUserRankProvider =
    FutureProvider.family<LeaderboardEntry?, LeaderboardType>((
      ref,
      type,
    ) async {
      final userId = ref.watch(userIdProvider);

      if (userId == null) {
        return null;
      }

      final controller = ref.watch(leaderboardControllerProvider);
      return controller.fetchUserRank(uid: userId, type: type);
    });

/// Current week key provider
final currentWeekKeyProvider = Provider<String>((ref) {
  final controller = ref.watch(leaderboardControllerProvider);
  return controller.getCurrentWeekKey();
});
