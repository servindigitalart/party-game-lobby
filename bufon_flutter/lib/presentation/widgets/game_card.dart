import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class GameCard extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isDisabled;
  final Widget? trailing;
  final Color? selectedColor;

  const GameCard({
    super.key,
    required this.text,
    this.onTap,
    this.isSelected = false,
    this.isDisabled = false,
    this.trailing,
    this.selectedColor,
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
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
      _controller.forward().then((_) => _controller.reverse());
      HapticFeedback.mediumImpact();
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
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.isDisabled ? null : widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isSelected
                ? _pulseAnimation.value
                : _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: widget.isSelected
                    ? LinearGradient(
                        colors: [
                          widget.selectedColor ?? AppColors.success,
                          (widget.selectedColor ?? AppColors.success)
                              .withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: widget.isSelected
                    ? null
                    : (widget.isDisabled
                          ? AppColors.surfaceDark
                          : AppColors.surface),
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(
                  color: widget.isSelected
                      ? (widget.selectedColor ?? AppColors.success)
                      : AppColors.border,
                  width: widget.isSelected ? 2 : 1,
                ),
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: (widget.selectedColor ?? AppColors.success)
                              .withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.text,
                      style: widget.isSelected
                          ? AppTypography.body1.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            )
                          : AppTypography.body1.copyWith(
                              color: widget.isDisabled
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                            ),
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    widget.trailing!,
                  ],
                  if (widget.isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 24,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
