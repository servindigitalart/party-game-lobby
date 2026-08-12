// presentation/widgets/bufon_placeholder.dart

import 'package:flutter/material.dart';
import '../../core/game_copy.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/bufon_phase.dart';
import 'animated_primary_button.dart';
import 'brand_mark.dart';

/// What a Bufón screen shows when it has nothing to show.
///
/// Implements BUFON_V1.1_VISUAL_BLUEPRINT.md's `BufonPlaceholder`:
/// "`empty` / `error` / `offline` variants; brand illustration, voice copy,
/// ≤1 action". Before this existed the app hand-rolled the same
/// icon/title/body column five times, and two of those copies printed the raw
/// exception to the player.
enum BufonPlaceholderVariant {
  /// Nothing here *yet* — a state the player can change by playing.
  /// Capítulo 25 wants the brand illustration here specifically, so this is
  /// the variant that shows the isotype.
  empty,

  /// Something failed. Semantic icon rather than the mark: the brand should
  /// not be the face of a failure.
  error,

  /// Reachability, not failure — worth distinguishing because the recovery is
  /// different (wait vs. retry).
  offline,
}

class BufonPlaceholder extends StatelessWidget {
  final BufonPlaceholderVariant variant;

  /// One short line. Each call site knows its own noun ("Sin ranking todavía",
  /// "No se pudo cargar el perfil") so this is required rather than defaulted.
  final String title;

  /// Supporting sentence. Defaults to the variant's voice copy in [GameCopy].
  ///
  /// **Never pass an exception, an error code or a provider message here.**
  /// The technical detail belongs in the log, not in front of a player
  /// (Capítulo 26).
  final String? message;

  /// At most one action — Capítulo 25 caps it deliberately.
  final String? actionLabel;
  final VoidCallback? onAction;

  const BufonPlaceholder({
    super.key,
    required this.title,
    this.variant = BufonPlaceholderVariant.empty,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  /// Voice copy lives in [GameCopy] with the rest of the app's strings; the
  /// mapping lives here so `core/` never has to import a presentation enum.
  String get _defaultMessage => switch (variant) {
    BufonPlaceholderVariant.empty => GameCopy.placeholderEmpty,
    BufonPlaceholderVariant.error => GameCopy.placeholderError,
    BufonPlaceholderVariant.offline => GameCopy.placeholderOffline,
  };

  @override
  Widget build(BuildContext context) {
    final phase = context.phase;
    final scheme = Theme.of(context).colorScheme;

    // Colours come from the active register, never from the caller: the same
    // placeholder has to read correctly on Paper, on Graphite and on the
    // screens still carrying the legacy palette.
    final Widget mark = switch (variant) {
      BufonPlaceholderVariant.empty => const BrandMark(size: 64),
      BufonPlaceholderVariant.error => Icon(
        Icons.error_outline,
        size: 64,
        color: scheme.error,
      ),
      BufonPlaceholderVariant.offline => Icon(
        Icons.cloud_off,
        size: 64,
        color: phase.onSurfaceMuted,
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            mark,
            const SizedBox(height: AppSpacing.md),
            Semantics(
              header: true,
              child: Text(
                title,
                style: AppTypography.h3.copyWith(color: phase.onSurface),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message ?? _defaultMessage,
              style: AppTypography.body1.copyWith(
                color: phase.onSurfaceMuted,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AnimatedPrimaryButton(
                text: actionLabel!,
                onPressed: onAction,
                variant: PrimaryButtonVariant.outline,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
