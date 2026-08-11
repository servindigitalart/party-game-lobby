// presentation/screens/leaderboard_screen.dart
import 'package:flutter/material.dart';
import '../../core/telemetry/game_telemetry_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/bufon_phase.dart';
import '../../models/leaderboard_entry.dart';
import '../../models/avatar.dart';
import '../../providers/leaderboard_providers.dart';
import '../../providers/game_providers.dart';
import '../../services/haptic_service.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    GameTelemetryService.instance.transition('leaderboard');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weekKey = ref.watch(currentWeekKeyProvider);

    // Fase 2B WP1: authored against `AppTheme.legacyTheme`, still painting
    // legacy dark surfaces. Fase 2A made `lightTheme` the app theme and a
    // pushed route does not inherit the pusher's `Theme`, so the app-bar
    // title, back arrow, action icons and unstyled `Text` resolved to Ink on
    // dark. `BufonPhase.legacy` is the documented opt-in that restores the
    // theme this screen was written for. Migration boundary marker: replace
    // with `BufonPhase.leaderboard` when this screen moves to Paper.
    final content = Scaffold(
      appBar: AppBar(
        title: const Text('Rankings'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              HapticService.lightImpact();
              // Refresh all leaderboards
              ref.invalidate(topPlayersProvider);
              ref.invalidate(userRankProvider);
            },
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Week indicator for weekly leaderboards
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            color: AppColors.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Semana $weekKey',
                  style: AppTypography.body2.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            labelStyle: AppTypography.body1.copyWith(
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: AppTypography.body2,
            tabs: const [
              Tab(text: 'Global'),
              Tab(text: 'Esta Semana'),
              Tab(text: 'Más Caótico'),
            ],
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLeaderboard(LeaderboardType.globalXp),
                _buildLeaderboard(LeaderboardType.weeklyXp),
                _buildLeaderboard(LeaderboardType.weeklyVotes),
              ],
            ),
          ),
        ],
      ),
    );

    return PhaseScope(phase: BufonPhase.legacy, child: content);
  }

  Widget _buildLeaderboard(LeaderboardType type) {
    final currentUserId = ref.watch(userIdProvider);
    final topPlayersAsync = ref.watch(topPlayersProvider(type));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(topPlayersProvider(type));
        if (currentUserId != null) {
          ref.invalidate(userRankProvider((currentUserId, type)));
        }
      },
      child: topPlayersAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return _buildEmptyState(type);
          }

          return Column(
            children: [
              // Top 3 podium (if we have enough entries)
              if (entries.length >= 3) _buildPodium(entries.take(3).toList()),

              // User's rank card (if not in top 50)
              if (currentUserId != null)
                _buildUserRankCard(currentUserId, type),

              // Rest of the leaderboard
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final isCurrentUser = entry.uid == currentUserId;
                    final isTop3 = index < 3;

                    return _buildLeaderboardRow(
                      entry: entry,
                      type: type,
                      isCurrentUser: isCurrentUser,
                      isTop3: isTop3,
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(error.toString()),
      ),
    );
  }

  Widget _buildPodium(List<LeaderboardEntry> top3) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          if (top3.length >= 2) _buildPodiumPlace(top3[1], 2, Colors.grey),
          // 1st place
          _buildPodiumPlace(top3[0], 1, Colors.amber),
          // 3rd place
          if (top3.length >= 3) _buildPodiumPlace(top3[2], 3, Colors.brown),
        ],
      ),
    );
  }

  Widget _buildPodiumPlace(LeaderboardEntry entry, int place, Color color) {
    final avatar = Avatars.all.firstWhere(
      (a) => a.id == entry.avatarId,
      orElse: () => Avatars.all.first,
    );

    final height = place == 1 ? 120.0 : 100.0;
    final iconSize = place == 1 ? 48.0 : 40.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown for 1st place
        if (place == 1) const Text('👑', style: TextStyle(fontSize: 32)),
        if (place == 1) const SizedBox(height: AppSpacing.xs),

        // Avatar
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color, width: 3),
          ),
          child: Center(
            child: Text(avatar.emoji, style: const TextStyle(fontSize: 32)),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),

        // Nickname
        SizedBox(
          width: 80,
          child: Text(
            entry.nickname,
            style: AppTypography.body2.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),

        // Podium
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: color, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getMedalIcon(place), color: color, size: iconSize),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '#$place',
                style: AppTypography.h3.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getMedalIcon(int place) {
    switch (place) {
      case 1:
        return Icons.emoji_events;
      case 2:
        return Icons.military_tech;
      case 3:
        return Icons.workspace_premium;
      default:
        return Icons.star;
    }
  }

  Widget _buildUserRankCard(String userId, LeaderboardType type) {
    final userRankAsync = ref.watch(userRankProvider((userId, type)));

    return userRankAsync.when(
      data: (entry) {
        if (entry == null || entry.rank == null || entry.rank! <= 50) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            border: Border.all(color: AppColors.primary, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(
                '#${entry.rank}',
                style: AppTypography.h3.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Icon(Icons.person, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu Posición',
                      style: AppTypography.body2.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${entry.getStatValue(type)} ${type.statLabel}',
                      style: AppTypography.body1.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildLeaderboardRow({
    required LeaderboardEntry entry,
    required LeaderboardType type,
    required bool isCurrentUser,
    required bool isTop3,
  }) {
    final avatar = Avatars.all.firstWhere(
      (a) => a.id == entry.avatarId,
      orElse: () => Avatars.all.first,
    );

    final statValue = entry.getStatValue(type);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser
              ? AppColors.primary
              : isTop3
              ? _getTop3Color(entry.rank!)
              : Colors.transparent,
          width: isCurrentUser || isTop3 ? 2 : 0,
        ),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 40,
            child: Text(
              '#${entry.rank}',
              style: AppTypography.h3.copyWith(
                color: isTop3
                    ? _getTop3Color(entry.rank!)
                    : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isTop3
                  ? _getTop3Color(entry.rank!).withValues(alpha: 0.2)
                  : AppColors.background,
            ),
            child: Center(
              child: Text(avatar.emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Nickname and level
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.nickname,
                        style: AppTypography.body1.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'TÚ',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Nivel ${entry.level}',
                  style: AppTypography.body2.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Stat value
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$statValue',
                style: AppTypography.h3.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                type.statLabel,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getTop3Color(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey;
      case 3:
        return Colors.brown;
      default:
        return AppColors.textPrimary;
    }
  }

  Widget _buildEmptyState(LeaderboardType type) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '¡Sé el primero!',
              style: AppTypography.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Juega partidas para aparecer en el ranking ${type.displayName}',
              style: AppTypography.body1.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Error al cargar',
              style: AppTypography.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No se pudo cargar el ranking. Intenta de nuevo.',
              style: AppTypography.body1.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(topPlayersProvider);
                ref.invalidate(userRankProvider);
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
