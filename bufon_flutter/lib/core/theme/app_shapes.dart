// core/theme/app_shapes.dart

import 'package:flutter/material.dart';
import 'app_spacing.dart';

/// BUFÓN Shape System — implements BUFON_DESIGN_SYSTEM.md v1.1, Capítulos
/// 9 (Shapes), 10 (Corners) and 11 (Borders). The design doc itself says
/// these three chapters "deben leerse como una sola unidad" — this file is
/// that unit: what shapes exist, how rounded they are, and how they're
/// separated when color contrast alone isn't enough.
///
/// Radius values are *derived from*, not duplicated from, [AppSpacing] —
/// `cardRadius`/`buttonRadius` remain the single source of truth for those
/// two sizes; this file only adds the steps the doc calls for that
/// `AppSpacing` didn't have (xs, sm, xl, full).
class AppShapes {
  AppShapes._();

  // ---------------------------------------------------------------------
  // Corners (Capítulo 10)
  // ---------------------------------------------------------------------

  static const double radiusXs = 8; // chips pequeños, badges inline
  static const double radiusSm = 12; // inputs de texto, tooltips
  static const double radiusMd = AppSpacing.buttonRadius; // 16 — botones
  static const double radiusLg = AppSpacing.cardRadius; // 20 — tarjetas
  static const double radiusXl = 28; // modales, tarjetas hero
  static const double radiusFull = 999; // pastillas, avatares, círculos

  static const BorderRadius borderRadiusXs = BorderRadius.all(
    Radius.circular(radiusXs),
  );
  static const BorderRadius borderRadiusSm = BorderRadius.all(
    Radius.circular(radiusSm),
  );
  static const BorderRadius borderRadiusMd = BorderRadius.all(
    Radius.circular(radiusMd),
  );
  static const BorderRadius borderRadiusLg = BorderRadius.all(
    Radius.circular(radiusLg),
  );
  static const BorderRadius borderRadiusXl = BorderRadius.all(
    Radius.circular(radiusXl),
  );
  static const BorderRadius borderRadiusFull = BorderRadius.all(
    Radius.circular(radiusFull),
  );

  // ---------------------------------------------------------------------
  // Borders (Capítulo 11)
  // ---------------------------------------------------------------------

  /// Passive separation (default border thickness).
  static const double borderWidthHairline = AppSpacing.hairline;

  /// Active selection/focus state — never more than one active border per
  /// component (Capítulo 11).
  static const double borderWidthFocus = 2;

  static Border hairlineBorder(Color color) =>
      Border.all(color: color, width: borderWidthHairline);

  static Border focusBorder(Color color) =>
      Border.all(color: color, width: borderWidthFocus);

  // ---------------------------------------------------------------------
  // Shapes (Capítulo 9) — composed helpers for the three closed shape
  // vocabularies the doc defines. Prefer these over building
  // RoundedRectangleBorder/BorderRadius ad hoc in a widget.
  // ---------------------------------------------------------------------

  // `pill` (a `StadiumBorder`) lived here and had zero call sites for its
  // whole life. The two surfaces that genuinely *are* pills — the primary
  // button and the round-progress chip — both draw themselves with a
  // `BoxDecoration`, which takes a `BorderRadius`, not a `ShapeBorder`; they
  // use [borderRadiusFull] and always did. Converting either to a
  // `ShapeDecoration` purely so a token could claim a call site is added
  // complexity in service of a token, so the token is gone instead.
  // [borderRadiusFull] is the pill in this codebase.

  /// Tarjeta de contenido estándar — modales/pantalla completa usan [heroCard].
  static RoundedRectangleBorder card({Color? borderColor}) =>
      RoundedRectangleBorder(
        borderRadius: borderRadiusLg,
        side: borderColor != null
            ? BorderSide(color: borderColor, width: borderWidthHairline)
            : BorderSide.none,
      );

  /// Tarjeta hero / modal — pregunta activa, ganador, diálogos grandes.
  static RoundedRectangleBorder heroCard({Color? borderColor}) =>
      RoundedRectangleBorder(
        borderRadius: borderRadiusXl,
        side: borderColor != null
            ? BorderSide(color: borderColor, width: borderWidthHairline)
            : BorderSide.none,
      );

  /// Botón estándar.
  static RoundedRectangleBorder button() =>
      const RoundedRectangleBorder(borderRadius: borderRadiusMd);
}
