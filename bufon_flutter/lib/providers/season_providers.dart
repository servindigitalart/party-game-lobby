// providers/season_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/controllers/season_controller.dart';
import '../models/season.dart';
import '../analytics/analytics_service.dart';

final seasonControllerProvider = Provider<SeasonController>((ref) {
  return SeasonController(analytics: AnalyticsService.instance);
});

final currentSeasonProvider = StreamProvider<Season?>((ref) {
  final controller = ref.watch(seasonControllerProvider);
  return controller.watchCurrentSeason();
});

final seasonCountdownProvider = FutureProvider<Duration?>((ref) async {
  final controller = ref.watch(seasonControllerProvider);
  return controller.getSeasonCountdown();
});

final userSeasonHistoryProvider =
    FutureProvider.family<List<SeasonHistory>, String>((ref, userId) async {
      final controller = ref.watch(seasonControllerProvider);
      return controller.getUserSeasonHistory(userId);
    });

final userSeasonRankProvider = FutureProvider.family<int?, (String, String)>((
  ref,
  params,
) async {
  final (userId, seasonId) = params;
  final controller = ref.watch(seasonControllerProvider);
  return controller.getUserSeasonRank(userId, seasonId);
});
