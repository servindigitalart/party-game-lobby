import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Round progress indicator showing current round and total rounds
class RoundIndicator extends StatelessWidget {
  final int currentRound;
  final int totalRounds;

  const RoundIndicator({
    super.key,
    required this.currentRound,
    required this.totalRounds,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sports_esports, color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Ronda ',
            style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            '$currentRound',
            style: AppTypography.body1.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '/$totalRounds',
            style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Progress bar for game completion
class GameProgressBar extends StatelessWidget {
  final int currentRound;
  final int totalRounds;

  const GameProgressBar({
    super.key,
    required this.currentRound,
    required this.totalRounds,
  });

  @override
  Widget build(BuildContext context) {
    final progress = currentRound / totalRounds;

    return Column(
      children: [
        Row(
          children: List.generate(totalRounds, (index) {
            final isCompleted = index < currentRound;
            final isCurrent = index == currentRound - 1;

            return Expanded(
              child: Container(
                margin: EdgeInsets.only(
                  right: index < totalRounds - 1 ? AppSpacing.xs : 0,
                ),
                height: 6,
                decoration: BoxDecoration(
                  color: isCompleted || isCurrent
                      ? AppColors.primary
                      : AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ronda $currentRound de $totalRounds',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: AppTypography.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
