// presentation/screens/season_details_screen.dart
import 'package:flutter/material.dart';
import '../../core/logging/log_category.dart';
import '../../core/telemetry/game_telemetry_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/bufon_phase.dart';
import '../widgets/bufon_loader.dart';
import '../widgets/bufon_placeholder.dart';
import '../../models/season.dart';
import '../../providers/leaderboard_providers.dart';
import '../../providers/game_providers.dart';
import '../../models/leaderboard_entry.dart';

class SeasonDetailsScreen extends ConsumerStatefulWidget {
  final Season season;

  const SeasonDetailsScreen({super.key, required this.season});

  @override
  ConsumerState<SeasonDetailsScreen> createState() =>
      _SeasonDetailsScreenState();
}

class _SeasonDetailsScreenState extends ConsumerState<SeasonDetailsScreen> {
  final _telemetry = GameTelemetryService.instance;

  @override
  void initState() {
    super.initState();
    _telemetry.transition('season_details');
    _telemetry.track(
      AppLogCategory.season,
      'season_viewed',
      payload: {
        'season_id': widget.season.id,
        'days_remaining': widget.season.daysRemaining,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final leaderboardAsync = ref.watch(
      topPlayersProvider(LeaderboardType.globalXp),
    );
    final userId = ref.watch(userIdProvider);

    // Fase 2B WP1: authored against `AppTheme.legacyTheme`, still painting
    // legacy dark surfaces. Fase 2A made `lightTheme` the app theme and a
    // pushed route does not inherit the pusher's `Theme`, so the app-bar
    // title, back arrow and unstyled `Text` resolved to Ink on dark.
    // `BufonPhase.legacy` is the documented opt-in that restores the theme
    // this screen was written for. Migration boundary marker.
    final content = Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.season.name),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          _buildSeasonHeader(),
          _buildRewardsSection(),
          _buildLeaderboardSection(leaderboardAsync, userId),
        ],
      ),
    );

    return PhaseScope(phase: BufonPhase.legacy, child: content);
  }

  Widget _buildSeasonHeader() {
    final daysRemaining = widget.season.daysRemaining;

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(widget.season.themeColor).withValues(alpha: 0.3),
              Color(widget.season.themeColor).withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Color(widget.season.themeColor), width: 2),
        ),
        child: Column(
          children: [
            Icon(
              Icons.emoji_events,
              color: Color(widget.season.themeColor),
              size: 64,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.season.name,
              style: AppTypography.h1.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              daysRemaining > 0
                  ? 'Termina en $daysRemaining día${daysRemaining != 1 ? 's' : ''}'
                  : '¡Temporada finalizada!',
              style: AppTypography.h3.copyWith(
                color: daysRemaining <= 7
                    ? AppColors.error
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardsSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recompensas',
              style: AppTypography.h2.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildRewardCard(
              rank: 'Top 1',
              reward: 'Título Legendario Permanente',
              icon: Icons.workspace_premium,
              color: AppColors.gold,
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildRewardCard(
              rank: 'Top 10',
              reward: 'Marco Animado Exclusivo',
              icon: Icons.photo_size_select_actual,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildRewardCard(
              rank: 'Top 100',
              reward: 'Insignia de la Temporada',
              icon: Icons.stars,
              color: AppColors.accent,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardCard({
    required String rank,
    required String reward,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rank,
                  style: AppTypography.body1.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reward,
                  style: AppTypography.body2.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardSection(
    AsyncValue<List<LeaderboardEntry>> leaderboardAsync,
    String? userId,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Clasificación Actual',
              style: AppTypography.h2.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            leaderboardAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return const BufonPlaceholder(
                    title: 'Todavía no hay clasificación',
                  );
                }

                return Column(
                  children: entries.take(100).map((entry) {
                    final rank = entry.rank;
                    final isCurrentUser = entry.uid == userId;
                    final isTop1 = rank == 1;
                    final isTop10 = rank != null && rank <= 10;
                    final isTop100 = rank != null && rank <= 100;

                    Color? highlightColor;
                    if (isTop1) {
                      highlightColor = AppColors.gold;
                    } else if (isTop10) {
                      highlightColor = AppColors.primary;
                    } else if (isTop100) {
                      highlightColor = AppColors.accent;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isCurrentUser
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              highlightColor?.withValues(alpha: 0.5) ??
                              AppColors.border,
                          width: isCurrentUser ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              '#$rank',
                              style: AppTypography.h3.copyWith(
                                color: highlightColor ?? AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          if (isTop1)
                            const Icon(
                              Icons.workspace_premium,
                              color: AppColors.gold,
                              size: 24,
                            ),
                          if (isTop1) const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              entry.nickname,
                              style: AppTypography.body1.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: isCurrentUser
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          Text(
                            '${entry.xp} XP',
                            style: AppTypography.body2.copyWith(
                              color: highlightColor ?? AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: BufonLoader()),
              ),
              error: (_, __) => const BufonPlaceholder(
                variant: BufonPlaceholderVariant.error,
                title: 'No se pudo cargar la clasificación',
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}
