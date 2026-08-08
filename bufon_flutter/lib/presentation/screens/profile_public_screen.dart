// presentation/screens/profile_public_screen.dart
import 'package:flutter/material.dart';
import '../../core/logging/log_level.dart';
import '../../core/logging/log_category.dart';
import '../../core/telemetry/game_telemetry_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../models/user_profile.dart';
import '../../models/title.dart' as bufon_title;
import '../../models/avatar.dart';
import '../../models/leaderboard_entry.dart';
import '../../providers/progression_providers.dart';
import '../../providers/leaderboard_providers.dart';
import '../../providers/game_providers.dart';
import '../../services/haptic_service.dart';
import '../dialogs/title_selector_dialog.dart';
import '../widgets/share_profile_card.dart';
import '../widgets/season_badges_section.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Premium public profile screen
///
/// Can be viewed by the user themselves or by others
/// Features:
/// - Large avatar with glow effect
/// - Equipped title
/// - Level badge
/// - XP progress
/// - Stats grid
/// - Global and weekly ranks
/// - Share button
class ProfilePublicScreen extends ConsumerStatefulWidget {
  final String userId;
  final bool isOwnProfile;

  const ProfilePublicScreen({
    super.key,
    required this.userId,
    this.isOwnProfile = false,
  });

  @override
  ConsumerState<ProfilePublicScreen> createState() =>
      _ProfilePublicScreenState();
}

class _ProfilePublicScreenState extends ConsumerState<ProfilePublicScreen>
    with SingleTickerProviderStateMixin {
  final _telemetry = GameTelemetryService.instance;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();

    _telemetry.transition('profile_public');

    final currentUserId = ref.read(userIdProvider);
    _telemetry.track(
      AppLogCategory.ui,
      'profile_viewed',
      payload: {
        'is_own_profile': currentUserId == widget.userId,
        'has_title': false, // Will update when profile loads
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileFutureProvider(widget.userId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: profileAsync.when(
        data: (profile) => _buildProfileContent(profile),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(error.toString()),
      ),
    );
  }

  Widget _buildProfileContent(UserProfile profile) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(profile),
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.lg),
                _buildAvatarSection(profile),
                const SizedBox(height: AppSpacing.lg),
                _buildTitleSection(profile),
                const SizedBox(height: AppSpacing.xl),
                _buildLevelSection(profile),
                const SizedBox(height: AppSpacing.xl),
                _buildStatsGrid(profile),
                const SizedBox(height: AppSpacing.xl),
                _buildRanksSection(profile),
                const SizedBox(height: AppSpacing.xl),
                // Season Badges History
                SeasonBadgesSection(userId: widget.userId),
                const SizedBox(height: AppSpacing.xl),
                _buildShareButton(profile),
                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(UserProfile profile) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.background,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withValues(alpha: 0.3),
                AppColors.background,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(UserProfile profile) {
    final avatar = Avatars.all.firstWhere(
      (a) => a.id == profile.selectedAvatar,
      orElse: () => Avatars.all.first,
    );

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow effect
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),

          // Avatar circle
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.gold],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Text(avatar.emoji, style: const TextStyle(fontSize: 64)),
            ),
          ),

          // Level badge
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.gold],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.5),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Text(
                'Nivel ${profile.level}',
                style: AppTypography.body1.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection(UserProfile profile) {
    if (profile.equippedTitleId == null) {
      if (widget.isOwnProfile) {
        return _buildNoTitleEquipped();
      }
      return const SizedBox.shrink();
    }

    final title = bufon_title.Titles.getById(profile.equippedTitleId!);
    if (title == null) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(title.rarity.color).withValues(alpha: 0.2),
                Color(title.rarity.color).withValues(alpha: 0.1),
              ],
            ),
            border: Border.all(color: Color(title.rarity.color), width: 2),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Color(title.rarity.color).withValues(alpha: 0.3),
                blurRadius: 15,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                title.name,
                style: AppTypography.h2.copyWith(
                  color: Color(title.rarity.color),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                title.description,
                style: AppTypography.body2.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        if (widget.isOwnProfile) ...[
          const SizedBox(height: AppSpacing.md),
          TextButton.icon(
            onPressed: () => _showTitleSelector(profile),
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Cambiar Título'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ],
    );
  }

  Widget _buildNoTitleEquipped() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Sin título equipado',
            style: AppTypography.body1.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          ElevatedButton.icon(
            onPressed: () => _showTitleSelector(null),
            icon: const Icon(Icons.add),
            label: const Text('Seleccionar Título'),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelSection(UserProfile profile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'XP',
                style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
              ),
              Text(
                '${profile.xp} / ${profile.xpForNextLevel}',
                style: AppTypography.body1.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: profile.levelProgress,
              backgroundColor: AppColors.backgroundCard,
              valueColor: AlwaysStoppedAnimation(AppColors.gold),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${profile.xpToNextLevel} XP para nivel ${profile.level + 1}',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(UserProfile profile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm),
            child: Text('Estadísticas', style: AppTypography.h3),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  label: 'Victorias',
                  value: '${profile.totalWins}',
                  icon: Icons.emoji_events,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildStatCard(
                  label: 'Votos',
                  value: '${profile.totalVotesReceived}',
                  icon: Icons.favorite,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  label: 'Partidas',
                  value: '${profile.totalGames}',
                  icon: Icons.games,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildStatCard(
                  label: '% Victoria',
                  value: '${profile.winRate.toStringAsFixed(0)}%',
                  icon: Icons.trending_up,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
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
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.h2.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRanksSection(UserProfile profile) {
    final globalRankAsync = ref.watch(
      userRankProvider((widget.userId, LeaderboardType.globalXp)),
    );
    final weeklyRankAsync = ref.watch(
      userRankProvider((widget.userId, LeaderboardType.weeklyXp)),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm),
            child: Text('Rankings', style: AppTypography.h3),
          ),
          const SizedBox(height: AppSpacing.md),
          globalRankAsync.when(
            data: (entry) => _buildRankCard(
              label: 'Ranking Global',
              rank: entry?.rank,
              icon: Icons.public,
              color: AppColors.gold,
            ),
            loading: () => _buildRankCardLoading('Ranking Global'),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpacing.md),
          weeklyRankAsync.when(
            data: (entry) => _buildRankCard(
              label: 'Ranking Semanal',
              rank: entry?.rank,
              icon: Icons.calendar_today,
              color: AppColors.primary,
            ),
            loading: () => _buildRankCardLoading('Ranking Semanal'),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildRankCard({
    required String label,
    required int? rank,
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
          Icon(icon, color: color, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.body2.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rank != null ? '#$rank' : 'Sin ranking',
                  style: AppTypography.h2.copyWith(
                    color: rank != null ? color : AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankCardLoading(String label) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            label,
            style: AppTypography.body1.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton(UserProfile profile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.gold],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _shareProfile(profile),
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.share, color: Colors.white, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Compartir Perfil',
                style: AppTypography.h3.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
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
              'Error al cargar perfil',
              style: AppTypography.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error,
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

  Future<void> _showTitleSelector(UserProfile? profile) async {
    HapticService.lightImpact();

    await showDialog(
      context: context,
      builder: (context) => const TitleSelectorDialog(),
    );
  }

  Future<void> _shareProfile(UserProfile profile) async {
    HapticService.mediumImpact();

    try {
      // Show loading indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Generando imagen...'),
            ],
          ),
          duration: Duration(seconds: 2),
          backgroundColor: AppColors.primary,
        ),
      );

      // Get equipped title if any
      bufon_title.BufonTitle? equippedTitle;
      if (profile.equippedTitleId != null) {
        equippedTitle = bufon_title.Titles.getById(profile.equippedTitleId!);
      }

      // Get avatar
      final avatar = Avatars.all.firstWhere(
        (a) => a.id == profile.selectedAvatar,
        orElse: () => Avatars.all.first,
      );

      // Generate PNG image
      final imageBytes = await ShareProfileCard.generateImage(
        avatar: avatar,
        level: profile.level,
        xp: profile.xp,
        totalWins: profile.totalWins,
        totalVotesReceived: profile.totalVotesReceived,
        totalGames: profile.totalGames,
        equippedTitle: equippedTitle,
      );

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/bufon_profile_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(imageBytes);

      // Share file
      await Share.shareXFiles([
        XFile(file.path),
      ], text: '¡Mira mi perfil en BUFÓN! 🎭');

      _telemetry.track(
        AppLogCategory.ui,
        'profile_shared',
        payload: {
          'has_title': profile.equippedTitleId != null,
          'level': profile.level,
        },
      );

      // Clean up
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (e, stackTrace) {
      // Sharing goes through the OS share sheet and fails for reasons
      // outside the app (cancelled, no storage), so it stays a warning.
      _telemetry.fail(
        AppLogCategory.ui,
        'profile_share_failed',
        error: e,
        stackTrace: stackTrace,
        severity: AppLogLevel.warning,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al compartir: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
