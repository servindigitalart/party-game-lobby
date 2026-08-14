import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_elevation.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/bufon_phase.dart';
import '../../core/theme/motion_tokens.dart';
import '../../core/theme/reduced_motion.dart';
import '../../services/haptic_service.dart';

/// A selectable answer card — the only component on the Voting screen, and
/// therefore the component that carries the emotional core of the game.
///
/// Fase 2A changes, all from BUFON_DESIGN_SYSTEM.md:
/// - **Flat fill by default** (Capítulo 3 ley 1). The selected state used to
///   draw a gradient.
/// - **Register-aware surfaces** instead of the legacy navy: it now reads
///   the ambient `colorScheme`, so the same card is correct on Graphite
///   during play and on Paper anywhere else.
/// - **Legible selected text.** Selected text was forced to `Colors.white`;
///   on Mint (`#63D6A5`) that measures ≈1.9:1. Capítulo 5 is explicit that
///   text over a pale brand colour is Ink. [onSelectedColor] makes the
///   foreground an explicit decision rather than an assumption.
/// - **Semantics** carrying the *selected* state, which previously existed
///   only as colour plus an icon.
/// - **Multi-line answers.** Answers are capped at 100 characters upstream;
///   a single-line `Row` clipped them at large text scales.
/// - **Haptics through [HapticService]** and a **reduce-motion** path.
///
/// The press/pulse mechanism is untouched: compress fast, release with
/// overshoot, and a separate confirm pulse on selection (`BRAND PHYSICS`).
class GameCard extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isDisabled;
  final Widget? trailing;
  final Color? selectedColor;

  /// Foreground used while selected. Defaults to Ink, which is legible on
  /// every pale brand accent (Butter, Mint, Sky, Lavender).
  final Color? onSelectedColor;

  /// Announced instead of [text] when the raw text is not a useful
  /// description on its own.
  final String? semanticLabel;

  const GameCard({
    super.key,
    required this.text,
    this.onTap,
    this.isSelected = false,
    this.isDisabled = false,
    this.trailing,
    this.selectedColor,
    this.onSelectedColor,
    this.semanticLabel,
  });

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: MotionDurations.pressCard,
      vsync: this,
    );
    // BRAND PHYSICS "Compresión y Resorte" (see BUFON_DESIGN_SYSTEM.md):
    // the tactile press feedback compresses fast and releases with a small
    // overshoot, asymmetric on purpose.
    _scaleAnimation = Tween<double>(begin: 1.0, end: MotionScale.pressSubtle)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: MotionCurves.compress,
            reverseCurve: MotionCurves.release,
          ),
        );
    // The selection-confirm pulse is driven by didUpdateWidget calling
    // forward() then reverse() back-to-back, not by direct touch — it
    // keeps the symmetric Pulse curve (Capítulo 16), not compress/release.
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: MotionScale.pulseSelect,
    ).animate(CurvedAnimation(parent: _controller, curve: MotionCurves.pulse));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(GameCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward().then((_) {
        if (mounted) _controller.reverse();
      });
      HapticService.mediumImpact();
    }
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null && !widget.isDisabled) {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap != null && !widget.isDisabled) {
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null && !widget.isDisabled) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final phase = context.phase;
    final scheme = Theme.of(context).colorScheme;

    final selectedFill = widget.selectedColor ?? phase.accent;
    final selectedForeground = widget.onSelectedColor ?? AppColors.ink;
    final restingForeground = widget.isDisabled
        ? phase.onSurfaceMuted
        : phase.onSurface;

    return Semantics(
      button: widget.onTap != null,
      enabled: !widget.isDisabled,
      selected: widget.isSelected,
      label: widget.semanticLabel ?? widget.text,
      // Fase 2B WP4: re-declared because `excludeSemantics` drops the subtree
      // that owns the gesture. Without it every answer in the voting round was
      // a focusable button that a screen reader could not press — the core
      // loop was unplayable with assistive technology.
      onTap: widget.isDisabled ? null : widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.isDisabled ? null : widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final target = widget.isSelected
                ? _pulseAnimation.value
                : _scaleAnimation.value;
            return Transform.scale(
              scale: context.motion(full: target, reduced: 1.0),
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: MotionDurations.settleCard,
            curve: MotionCurves.settle,
            constraints: const BoxConstraints(minHeight: AppSpacing.xxl),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? selectedFill
                  : (widget.isDisabled
                        ? scheme.surface
                        : scheme.surfaceContainerHighest),
              borderRadius: AppShapes.borderRadiusLg,
              border: widget.isSelected
                  ? AppShapes.focusBorder(selectedFill)
                  : AppShapes.hairlineBorder(scheme.outline),
              boxShadow: widget.isSelected
                  ? AppElevation.protagonistShadow(selectedFill)
                  : AppElevation.ambient,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    widget.text,
                    // Answers run to 100 characters; at large accessibility
                    // text scales a single line clipped them silently.
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body1.copyWith(
                      color: widget.isSelected
                          ? selectedForeground
                          : restingForeground,
                      fontWeight: widget.isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  widget.trailing!,
                ],
                if (widget.isSelected) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.check_circle, color: selectedForeground, size: 24),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
