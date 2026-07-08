// presentation/widgets/season_countdown_banner.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/season_providers.dart';
import '../../services/haptic_service.dart';
import '../screens/season_details_screen.dart';

class SeasonCountdownBanner extends ConsumerWidget {
  const SeasonCountdownBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasonAsync = ref.watch(currentSeasonProvider);

    return seasonAsync.when(
      data: (season) {
        if (season == null || season.isEnded) {
          return const SizedBox.shrink();
        }

        final daysRemaining = season.daysRemaining;

        return GestureDetector(
          onTap: () {
            HapticService.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SeasonDetailsScreen(season: season),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(season.themeColor).withValues(alpha: 0.2),
                  Color(season.themeColor).withValues(alpha: 0.1),
                ],
              ),
              border: Border.all(color: Color(season.themeColor), width: 2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Color(season.themeColor).withValues(alpha: 0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(season.themeColor).withValues(alpha: 0.3),
                  ),
                  child: Icon(
                    Icons.emoji_events,
                    color: Color(season.themeColor),
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        season.name,
                        style: AppTypography.h3.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getCountdownText(daysRemaining),
                        style: AppTypography.body2.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Color(season.themeColor)),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _getCountdownText(int days) {
    if (days == 0) {
      return '¡Termina hoy!';
    } else if (days == 1) {
      return 'Termina en 1 día';
    } else if (days <= 7) {
      return 'Termina en $days días ⏰';
    } else {
      return 'Termina en $days días';
    }
  }
}
