// presentation/widgets/season_badges_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/season_providers.dart';
import '../../models/season.dart';

class SeasonBadgesSection extends ConsumerWidget {
  final String userId;

  const SeasonBadgesSection({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(userSeasonHistoryProvider(userId));

    return historyAsync.when(
      data: (history) {
        if (history.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Text(
                'Historial de Temporadas',
                style: AppTypography.h3.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final season = history[index];
                  return _buildSeasonCard(season);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSeasonCard(SeasonHistory season) {
    Color rankColor;
    IconData rankIcon;

    if (season.rank == 1) {
      rankColor = AppColors.gold;
      rankIcon = Icons.workspace_premium;
    } else if (season.rank <= 10) {
      rankColor = AppColors.primary;
      rankIcon = Icons.photo_size_select_actual;
    } else if (season.rank <= 100) {
      rankColor = AppColors.accent;
      rankIcon = Icons.stars;
    } else {
      rankColor = AppColors.textSecondary;
      rankIcon = Icons.emoji_events;
    }

    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rankColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(rankIcon, color: rankColor, size: 36),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Puesto #${season.rank}',
              style: AppTypography.body2.copyWith(
                color: rankColor,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              season.seasonName,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${season.totalXp} XP',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
