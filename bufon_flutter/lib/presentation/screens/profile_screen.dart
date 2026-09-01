// presentation/screens/profile_screen.dart
import 'package:flutter/material.dart';
import '../../core/logging/log_category.dart';
import '../../core/telemetry/game_telemetry_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/bufon_phase.dart';
import '../widgets/bufon_feedback.dart';
import '../widgets/bufon_loader.dart';
import '../widgets/bufon_placeholder.dart';
import '../../models/achievement.dart';
import '../../models/avatar.dart';
import '../../providers/progression_providers.dart';
import '../../providers/game_providers.dart';
import '../../services/haptic_service.dart';
import 'profile_public_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    GameTelemetryService.instance.transition('profile');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileStreamProvider);

    // WP20: the two reasons this screen can have nothing to show are not the
    // same reason, and used to render identically. `main()` now establishes
    // the anonymous identity before the first frame, so a null id here means
    // sign-in actually failed — a failure — while a null *profile* under a
    // real id means the player simply has not finished a match yet.
    final hasIdentity = ref.watch(userIdProvider) != null;

    // Fase 2B WP1: this screen was authored against `AppTheme.legacyTheme`
    // and paints legacy dark surfaces directly, but Fase 2A made
    // `lightTheme` the app theme — and a pushed route does not inherit the
    // pushing screen's `Theme`, so everything left to the ambient theme
    // (app-bar title, back arrow, action icons, unstyled `Text`) resolved to
    // Ink on those dark surfaces. `BufonPhase.legacy` is the documented
    // opt-in for exactly this state: it restores the theme the screen was
    // written for, unchanged. It is a migration boundary marker, not an
    // endorsement — replace it with `BufonPhase.profile` when this screen
    // migrates to the Paper register.
    final content = Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Ver perfil público',
            onPressed: () {
              final userId = ref.read(userIdProvider);
              // WP20 / audit A C-2 §4: this `if` had no `else`. With no
              // identity the tap produced nothing at all — no navigation, no
              // message, no haptic — which reads as a broken control rather
              // than as an unavailable one.
              if (userId == null) {
                BufonFeedback.show(
                  context,
                  'Todavía no podemos abrir tu perfil público. '
                  'Inténtalo de nuevo en un momento.',
                );
                return;
              }
              HapticService.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ProfilePublicScreen(userId: userId, isOwnProfile: true),
                ),
              );
            },
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            // Signed in, no profile document yet: the first-run state of
            // every player, and the state a reviewer on a clean install is
            // in. Capítulo 25's `empty` variant — the one that shows the
            // isotype — with copy that says what to do about it.
            if (hasIdentity) {
              return const BufonPlaceholder(
                title: 'Tu perfil empieza aquí',
                message:
                    'Juega tu primera partida y aquí aparecerán tu nivel, '
                    'tus avatares y tus logros.',
              );
            }
            // No identity. That is a real failure and keeps saying so.
            return _buildIdentityError();
          }

          return Column(
            children: [
              // Profile header with level and XP
              _buildProfileHeader(profile),

              // Tabs
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                tabs: const [
                  Tab(text: 'Avatares'),
                  Tab(text: 'Logros'),
                ],
              ),

              // Tab views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAvatarsTab(profile),
                    _buildAchievementsTab(profile),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: BufonLoader()),
        // A stream failure is a genuine backend failure and must not be
        // laundered into an empty state. It keeps the error variant, and
        // gains the retry the leaderboard's equivalent already had.
        error: (error, stack) => _buildIdentityError(),
      ),
    );

    return PhaseScope(phase: BufonPhase.legacy, child: content);
  }

  /// The failure placeholder, shared by the two states that really are
  /// failures: no identity, and a profile stream that errored.
  ///
  /// The exception is deliberately not a parameter — it was never rendered,
  /// and taking it would invite rendering it (Capítulo 26). It already
  /// reaches Crashlytics through the layer that raised it.
  Widget _buildIdentityError() {
    return BufonPlaceholder(
      variant: BufonPlaceholderVariant.error,
      title: 'No se pudo cargar el perfil',
      actionLabel: 'Reintentar',
      onAction: () => ref.invalidate(userProfileStreamProvider),
    );
  }

  Widget _buildProfileHeader(dynamic profile) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Selected Avatar. The emoji on its own reaches a screen reader as
          // an unpronounceable glyph, so the node carries the avatar's real
          // name and the emoji is excluded.
          Semantics(
            label:
                'Avatar actual: '
                '${Avatars.getById(profile.selectedAvatar)?.name ?? 'Bufón'}',
            image: true,
            excludeSemantics: true,
            child: Text(
              Avatars.getById(profile.selectedAvatar)?.emoji ?? '🤡',
              style: const TextStyle(fontSize: 80),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Level Badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Nivel ${profile.level}',
              style: AppTypography.h3.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // XP Progress Bar
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${profile.xp} XP',
                    style: AppTypography.body1.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Siguiente: ${profile.xpForNextLevel} XP',
                    style: AppTypography.body1.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // A bare `LinearProgressIndicator` announces nothing at all,
              // which makes the fill — the entire point of the bar — visible
              // only to sighted users.
              Semantics(
                label: 'Progreso al nivel ${profile.level + 1}',
                value: '${profile.xp} de ${profile.xpForNextLevel} XP',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: profile.levelProgress,
                    minHeight: 12,
                    backgroundColor: AppColors.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStat('Partidas', profile.totalGames.toString()),
              _buildStat('Victorias', profile.totalWins.toString()),
              _buildStat('Votos', profile.totalVotesReceived.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    // Value and label are two sibling `Text` nodes; unmerged, a screen reader
    // reads "12" and "Partidas" as unrelated fragments.
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.h2.copyWith(
              color: AppColors.primary,
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

  Widget _buildAvatarsTab(dynamic profile) {
    final allAvatars = Avatars.all;

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.8,
      ),
      itemCount: allAvatars.length,
      itemBuilder: (context, index) {
        final avatar = allAvatars[index];
        final isUnlocked = profile.hasAvatar(avatar.id);
        final isSelected = profile.selectedAvatar == avatar.id;

        return _buildAvatarCard(avatar, isUnlocked, isSelected, profile);
      },
    );
  }

  Widget _buildAvatarCard(
    Avatar avatar,
    bool isUnlocked,
    bool isSelected,
    dynamic profile,
  ) {
    void handleTap() {
      if (isUnlocked && !isSelected) {
        _selectAvatar(avatar.id);
      } else if (!isUnlocked) {
        _showAvatarRequirements(avatar);
      }
    }

    // One node per tile. The tile is a real button built from a
    // `GestureDetector`, so nothing announced it as actionable, and both of
    // its states were carried purely by colour, opacity, a rarity dot and a
    // lock glyph — none of which reach a screen reader.
    return Semantics(
      button: true,
      selected: isSelected,
      // Declared on the node too: `excludeSemantics` drops the subtree that
      // owns the gesture.
      onTap: handleTap,
      label: [
        'Avatar ${avatar.name}',
        avatar.rarity.displayName,
        if (!isUnlocked) 'bloqueado' else if (isSelected) 'seleccionado',
      ].join(', '),
      hint: isUnlocked
          ? (isSelected ? null : 'Toca para elegir este avatar')
          : 'Toca para ver cómo desbloquearlo',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              // Rarity indicator
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: avatar.rarity.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Avatar
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: isUnlocked ? 1.0 : 0.3,
                      child: Text(
                        avatar.emoji,
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      avatar.name,
                      style: AppTypography.caption.copyWith(
                        color: isUnlocked
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isUnlocked)
                      const Icon(
                        Icons.lock,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                  ],
                ),
              ),

              // Selected checkmark
              if (isSelected)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementsTab(dynamic profile) {
    final allAchievements = Achievements.all;

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.2,
      ),
      itemCount: allAchievements.length,
      itemBuilder: (context, index) {
        final achievement = allAchievements[index];
        final isUnlocked = profile.hasAchievement(achievement.id);

        return _buildAchievementCard(achievement, isUnlocked);
      },
    );
  }

  Widget _buildAchievementCard(Achievement achievement, bool isUnlocked) {
    // `button` tracks the real affordance: `onTap` does nothing once the
    // achievement is unlocked, so announcing an unlocked card as a button
    // would promise an action that does not exist. Locked/unlocked was
    // otherwise conveyed only by opacity, border colour and a lock glyph.
    // Only actionable while locked, so the action is declared only then —
    // matching `button`, and matching what `onTap` actually does.
    final VoidCallback? handleTap = isUnlocked
        ? null
        : () => _showAchievementRequirements(achievement);

    return Semantics(
      button: !isUnlocked,
      label: [
        'Logro ${achievement.name}',
        isUnlocked ? 'desbloqueado' : 'bloqueado',
        achievement.description,
        '${achievement.xpReward} XP',
      ].join(', '),
      hint: isUnlocked ? null : 'Toca para ver cómo desbloquearlo',
      onTap: handleTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: handleTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isUnlocked
                ? AppColors.surface
                : AppColors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUnlocked
                  ? AppColors.accent.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Opacity(
                opacity: isUnlocked ? 1.0 : 0.3,
                child: Text(
                  achievement.icon,
                  style: const TextStyle(fontSize: 40),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                achievement.name,
                style: AppTypography.body1.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isUnlocked
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                achievement.description,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '+${achievement.xpReward} XP',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!isUnlocked)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xs),
                  child: Icon(
                    Icons.lock,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectAvatar(String avatarId) async {
    HapticService.mediumImpact();

    try {
      final userId = ref.read(userIdProvider);
      if (userId == null) return;

      final controller = ref.read(progressionControllerProvider);
      await controller.selectAvatar(uid: userId, avatarId: avatarId);

      if (mounted) {
        HapticService.success();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Avatar seleccionado: ${Avatars.getById(avatarId)?.name ?? ''}',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      // A deliberate player action that failed: reported, not just shown.
      GameTelemetryService.instance.fail(
        AppLogCategory.progression,
        'avatar_select_failed',
        error: e,
        stackTrace: stackTrace,
        payload: {'avatar_id': avatarId},
      );

      HapticService.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No se pudo equipar el avatar. Inténtalo de nuevo.',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
          ),
        );
      }
    }
  }

  void _showAvatarRequirements(Avatar avatar) {
    HapticService.lightImpact();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          avatar.name,
          style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(avatar.emoji, style: const TextStyle(fontSize: 60)),
            const SizedBox(height: AppSpacing.md),
            Text(
              avatar.name,
              style: AppTypography.body2.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: avatar.rarity.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                avatar.rarity.displayName,
                style: AppTypography.caption.copyWith(
                  color: avatar.rarity.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showAchievementRequirements(Achievement achievement) {
    HapticService.lightImpact();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          achievement.name,
          style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(achievement.icon, style: const TextStyle(fontSize: 60)),
            const SizedBox(height: AppSpacing.md),
            Text(
              achievement.description,
              style: AppTypography.body1.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Recompensa: +${achievement.xpReward} XP',
                style: AppTypography.body1.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
