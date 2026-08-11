// presentation/widgets/brand_mark.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_shapes.dart';

/// The Bufón isotype, as a widget.
///
/// Until Fase 2A the mark existed only as a 1 MB PNG in `/public` — the
/// leftover Create React App web root — so it was outside the Flutter asset
/// pipeline and the shipped app contained no pixels of its own identity
/// (see docs/design/v1.1/ASSET_AUDIT.md). This is the single place the asset
/// path is written.
///
/// The artwork is a flat two-ink mark on its own Butter ground, so it is
/// rendered as-is rather than tinted: Capítulo 2 describes it as "una sola
/// tinta sólida, sin degradados, sin sombras" on Butter, and recolouring a
/// raster would fight that. The rounded clip keeps it consistent with
/// Capítulo 9's "cero esquinas rectas".
class BrandMark extends StatelessWidget {
  /// Rendered edge length in logical pixels.
  final double size;

  /// Corner rounding. Defaults to a circle, echoing the head shape the mark
  /// already is (Capítulo 9: "círculo perfecto … ecoa la cabeza del bufón").
  final BorderRadius? borderRadius;

  const BrandMark({super.key, this.size = 32, this.borderRadius});

  /// Square with the design system's card rounding — used where the mark sits
  /// inside a composition rather than acting as an avatar.
  const BrandMark.rounded({super.key, this.size = 32})
    : borderRadius = AppShapes.borderRadiusLg;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Bufón',
      image: true,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(size / 2),
        child: Image.asset(
          'assets/brand/isotype.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          // The mark is decorative repetition of the label above; excluding
          // it from the semantics tree avoids a double announcement.
          excludeFromSemantics: true,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
