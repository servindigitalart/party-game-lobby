// presentation/dialogs/title_selector_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../models/title.dart';
import '../../providers/title_providers.dart';
import '../../providers/game_providers.dart';
import '../../services/haptic_service.dart';

class TitleSelectorDialog extends ConsumerWidget {
  const TitleSelectorDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlockedTitlesAsync = ref.watch(userUnlockedTitlesProvider);
    final equippedTitle = ref.watch(equippedTitleProvider);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.military_tech,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Selecciona un Título',
                      style: AppTypography.h3.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      HapticService.lightImpact();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            // Title list
            Flexible(
              child: unlockedTitlesAsync.when(
                data: (unlockedTitles) {
                  if (unlockedTitles.isEmpty) {
                    return _buildEmptyState();
                  }

                  // Get unlocked title IDs
                  final unlockedIds = unlockedTitles
                      .map((ut) => ut.titleId)
                      .toSet();

                  // Filter to only show unlocked titles
                  final availableTitles = Titles.all
                      .where((title) => unlockedIds.contains(title.id))
                      .toList();

                  // Sort by rarity (legendary first)
                  availableTitles.sort((a, b) {
                    const rarityOrder = {
                      TitleRarity.legendary: 0,
                      TitleRarity.epic: 1,
                      TitleRarity.rare: 2,
                      TitleRarity.common: 3,
                    };
                    return rarityOrder[a.rarity]!.compareTo(
                      rarityOrder[b.rarity]!,
                    );
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    shrinkWrap: true,
                    itemCount: availableTitles.length + 1, // +1 for "no title"
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // Option to remove title
                        return _buildTitleOption(
                          context,
                          ref,
                          null,
                          equippedTitle == null,
                        );
                      }

                      final title = availableTitles[index - 1];
                      return _buildTitleOption(
                        context,
                        ref,
                        title,
                        equippedTitle?.id == title.id,
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      'Error al cargar títulos',
                      style: AppTypography.body1.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.military_tech_outlined,
              size: 64,
              color: AppColors.textSecondary.withAlpha((0.5 * 255).toInt()),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No tienes títulos desbloqueados',
              style: AppTypography.body1.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Juega más partidas para desbloquear títulos',
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

  Widget _buildTitleOption(
    BuildContext context,
    WidgetRef ref,
    BufonTitle? title,
    bool isEquipped,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            HapticService.mediumImpact();
            final controller = ref.read(titleControllerProvider);
            final userId = ref.read(userIdProvider);

            if (userId == null) return;

            if (title == null) {
              // Unequip title
              await controller.unequipTitle(uid: userId);
            } else {
              // Equip title
              await controller.equipTitle(uid: userId, titleId: title.id);
            }

            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isEquipped
                  ? AppColors.primary.withAlpha((0.1 * 255).toInt())
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isEquipped
                    ? AppColors.primary
                    : title != null
                    ? Color(title.rarity.color)
                    : AppColors.textSecondary,
                width: isEquipped ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: title != null
                        ? Color(
                            title.rarity.color,
                          ).withAlpha((0.2 * 255).toInt())
                        : AppColors.textSecondary.withAlpha(
                            (0.2 * 255).toInt(),
                          ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    title == null ? Icons.close : Icons.military_tech,
                    color: title != null
                        ? Color(title.rarity.color)
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                ),

                const SizedBox(width: AppSpacing.md),

                // Title info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null) ...[
                        Text(
                          title.name,
                          style: AppTypography.body1.copyWith(
                            color: Color(title.rarity.color),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title.rarity.displayName,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Sin título',
                          style: AppTypography.body1.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'No mostrar ningún título',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Equipped badge
                if (isEquipped)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'EQUIPADO',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
