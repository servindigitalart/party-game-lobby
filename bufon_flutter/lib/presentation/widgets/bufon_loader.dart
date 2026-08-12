// presentation/widgets/bufon_loader.dart

import 'package:flutter/material.dart';
import '../../core/theme/motion_tokens.dart';
import '../../core/theme/reduced_motion.dart';
import 'brand_mark.dart';

/// Bufón's wait — implements BUFON_V1.1_VISUAL_BLUEPRINT.md, "Loading states:
/// Isotype, breathing (scale 1.0 ↔ 1.008, 4 s, `easeInOut`)".
///
/// The blueprint rejects both alternatives explicitly: `flutter_spinkit`
/// because "a prettier generic spinner is still generic", and skeleton
/// shimmer because "a shimmer is a better generic, and generic is the
/// problem". What Capítulo 24 asks for is a *branded* wait, and the brand's
/// own idle motion is breathing.
///
/// The three numbers are not chosen here — they come from
/// [MotionPhysics.breathingAmplitude], [MotionPhysics.breathingPeriod] and
/// [MotionCurves.pulse], which were written for exactly this component and
/// had no call sites until now. If the breath needs tuning after a playtest,
/// the lever is those tokens, not this widget.
///
/// Deliberately not a mini animation framework: no colour, curve, duration or
/// child parameters. A loader that can be customised per call site stops
/// being one loading language.
class BufonLoader extends StatefulWidget {
  /// Edge length of the mark in logical pixels. The only visual knob, because
  /// a section loader and a full-screen loader genuinely differ in size.
  final double size;

  /// Overrides the announced label where "Cargando" is not specific enough.
  final String? semanticLabel;

  const BufonLoader({super.key, this.size = 48, this.semanticLabel});

  /// Compact inline wait — a row, a card, a list section.
  const BufonLoader.small({super.key, this.semanticLabel}) : size = 32;

  @override
  State<BufonLoader> createState() => _BufonLoaderState();
}

class _BufonLoaderState extends State<BufonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _breath;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: MotionPhysics.breathingPeriod,
      vsync: this,
    );
    // Symmetric, because nothing is being loaded or released — the element is
    // simply alive (Capítulo 16, Pulse).
    _breath = Tween<double>(
      begin: 1.0,
      end: 1.0 + MotionPhysics.breathingAmplitude,
    ).animate(CurvedAnimation(parent: _controller, curve: MotionCurves.pulse));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Capítulo 28. Read here rather than in `build` so the ticker is actually
    // stopped, not merely ignored — a running ticker that paints nothing is
    // still a frame callback every vsync for as long as the wait lasts.
    if (context.reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mark = BrandMark(size: widget.size);

    return Semantics(
      label: widget.semanticLabel ?? 'Cargando',
      // A single static label, not a live region: a wait should be announced
      // once when focused, never re-announced on every frame of the breath.
      // `excludeSemantics` also swallows BrandMark's own 'Bufón' label, which
      // would otherwise double-announce.
      excludeSemantics: true,
      child: context.reduceMotion
          ? mark
          : ScaleTransition(scale: _breath, child: mark),
    );
  }
}
