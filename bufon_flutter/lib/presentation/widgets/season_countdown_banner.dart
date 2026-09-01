// presentation/widgets/season_countdown_banner.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logging/log_category.dart';
import '../../core/telemetry/game_telemetry_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/season_providers.dart';
import '../../services/haptic_service.dart';
import '../navigation/page_transitions.dart';
import '../screens/season_details_screen.dart';

class SeasonCountdownBanner extends ConsumerWidget {
  const SeasonCountdownBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // WP20 / audit A H-1. Three independent conditions used to collapse to
    // one identical output — *not authenticated*, *no active season*, and
    // *any Firestore error* all rendered an empty box, so "the season feature
    // is off tonight" and "the season feature is broken" were the same
    // pixels, and a real failure vanished without a trace.
    //
    // Two of the three are now separated, and the third is deliberately left
    // alone:
    //
    //  1. **Not authenticated** — gone. `main()` establishes the identity
    //     before the first frame, so the read that used to be denied by
    //     `firestore.rules:213` now succeeds.
    //  2. **A genuine error** — still renders nothing, but is no longer
    //     silent: it is reported below, so it is visible in Talker and in the
    //     Crashlytics breadcrumb trail. The event name is deliberately absent
    //     from `analyticsEventMappings`, so this is an internal diagnostic
    //     and never a Firebase Analytics event. WP19's boundary is untouched.
    //  3. **No active season** — keeps rendering nothing, because that is
    //     correct. A banner announcing a season that does not exist is not an
    //     honest empty state, it is noise on the app's first screen, and the
    //     Blueprint places the banner *below* the primary CTAs precisely so it
    //     stops out-competing the brand (Capítulo 3 ley 4). Home's empty state
    //     for "no season" is the absence of the banner.
    //
    // `ref.listen` rather than a call inside the `error` branch: the branch
    // runs on every rebuild, the listener runs once per transition.
    ref.listen(currentSeasonProvider, (previous, next) {
      final error = next.error;
      if (error == null || previous?.error == error) return;
      GameTelemetryService.instance.fail(
        AppLogCategory.season,
        'season_load_failed',
        error: error,
        stackTrace: next.stackTrace,
      );
    });

    final seasonAsync = ref.watch(currentSeasonProvider);

    return seasonAsync.when(
      data: (season) {
        if (season == null || season.isEnded) {
          return const SizedBox.shrink();
        }

        final daysRemaining = season.daysRemaining;

        // The banner is a bare `GestureDetector`: nothing announced it as
        // tappable, and the name, the countdown and a chevron arrived as three
        // unrelated fragments. The decorative clock emoji is dropped from the
        // label so a screen reader does not read out "alarm clock".
        final countdown = _getCountdownText(daysRemaining).replaceAll(' ⏰', '');

        void openSeason() {
          HapticService.lightImpact();
          // WP26 / R-34, BP X2 — see `lobby_screen`.
          context.pushFadeSlide(SeasonDetailsScreen(season: season));
        }

        return Semantics(
          button: true,
          label: '${season.name}, $countdown',
          hint: 'Toca para ver los detalles de la temporada',
          // Declared on the node as well as the gesture: `excludeSemantics`
          // drops the subtree that owns the tap.
          onTap: openSeason,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: openSeason,
            child: Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    season.accent.color.withValues(alpha: 0.2),
                    season.accent.color.withValues(alpha: 0.1),
                  ],
                ),
                border: Border.all(color: season.accent.color, width: 2),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: season.accent.color.withValues(alpha: 0.3),
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
                      color: season.accent.color.withValues(alpha: 0.3),
                    ),
                    child: Icon(
                      Icons.emoji_events,
                      color: season.accent.color,
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
                  Icon(Icons.chevron_right, color: season.accent.color),
                ],
              ),
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
