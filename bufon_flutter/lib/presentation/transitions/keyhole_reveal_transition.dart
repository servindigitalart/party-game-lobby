import 'package:flutter/material.dart';

/// BUFÓN "Mirilla" reveal — implements BUFON_DESIGN_SYSTEM.md v1.1,
/// `BRAND PHYSICS`: "el reveal como mirilla".
///
/// The isotype's jester hat ends in two small circles with a keyhole cut
/// into them — a deliberate detail meaning "this holds a secret until it
/// decides to reveal it", which is literally the game's voting/reveal
/// mechanic. This widget turns that detail into a real transition: instead
/// of a generic cross-fade, [child] is revealed through an expanding
/// circular mask, as if a keyhole were physically opening over hidden
/// content.
///
/// This is standalone infrastructure — nothing wires it into a screen yet.
/// A future Reveal integration would drive [progress] with an
/// `AnimationController` (a `Curves.easeOut`-family curve suits an
/// "opening" motion better than the compress/release spring pairing used
/// for touch feedback elsewhere in the system, since this isn't a touch
/// response — it's a narrative unveiling) and wrap the hidden content:
///
/// ```dart
/// KeyholeRevealTransition(
///   progress: controller, // Animation<double>, 0.0 closed -> 1.0 fully open
///   child: RoundResultCard(...),
/// )
/// ```
class KeyholeRevealTransition extends AnimatedWidget {
  /// Drives the mask: 0.0 is fully closed (nothing of [child] visible),
  /// 1.0 is fully open (the circular mask has grown past every corner, so
  /// [child] renders exactly as it would unclipped).
  final Animation<double> progress;

  /// The hidden content being revealed.
  final Widget child;

  /// Where the "keyhole" opens from. Defaults to the center, matching the
  /// design doc's "se expande desde el centro"; a specific reveal moment
  /// (e.g. opening from a winner's avatar position) can override this.
  final Alignment origin;

  /// Optional color shown behind the mask while it's still closing/opening
  /// (e.g. Graphite, to match a dark Reveal backdrop). Left transparent by
  /// default so this stays reusable without presuming a specific screen's
  /// background — the caller decides.
  final Color? backdropColor;

  const KeyholeRevealTransition({
    super.key,
    required this.progress,
    required this.child,
    this.origin = Alignment.center,
    this.backdropColor,
  }) : super(listenable: progress);

  @override
  Widget build(BuildContext context) {
    final value = progress.value.clamp(0.0, 1.0);

    // Sizes to [child] rather than forcing expansion. The original
    // `StackFit.expand` meant this could only be used where an unbounded
    // parent gave it a definite size, which is why Fase 2A had to relax it to
    // wire the transition into the reveal card — the reveal's content is a
    // variable-height answer inside a Column. The backdrop still covers the
    // full painted area via Positioned.fill.
    return Stack(
      children: [
        if (backdropColor != null)
          Positioned.fill(child: ColoredBox(color: backdropColor!)),
        ClipPath(
          clipper: _KeyholeClipper(progress: value, origin: origin),
          child: child,
        ),
      ],
    );
  }
}

class _KeyholeClipper extends CustomClipper<Path> {
  final double progress;
  final Alignment origin;

  _KeyholeClipper({required this.progress, required this.origin});

  @override
  Path getClip(Size size) {
    final center = origin.alongSize(size);
    final radius = _maxRadiusFrom(center, size) * progress;
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  /// Distance from [center] to the farthest corner of [size] — the radius
  /// at which the circular mask fully covers the widget, so `progress ==
  /// 1.0` reveals `child` exactly as if it weren't clipped at all.
  double _maxRadiusFrom(Offset center, Size size) {
    final corners = <Offset>[
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    var maxDistance = 0.0;
    for (final corner in corners) {
      final distance = (corner - center).distance;
      if (distance > maxDistance) maxDistance = distance;
    }
    return maxDistance;
  }

  @override
  bool shouldReclip(covariant _KeyholeClipper oldClipper) {
    return oldClipper.progress != progress || oldClipper.origin != origin;
  }
}
