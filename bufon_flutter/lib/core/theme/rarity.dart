// core/theme/rarity.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';

/// How rare a title or an avatar is — the app's one rarity ladder.
///
/// There were two. `TitleRarity` returned an `int` (`0xFFB3B3B3`,
/// `0xFF2196F3`, `0xFF9C27B0`, `0xFFFFD700`) and `AvatarRarity` returned a
/// `String` hex (`#CCCCCC`, `#4A9EFF`, `#B24AFF`, `#FFD700`) — the same four
/// tiers with the same Spanish labels, disagreeing on three of four colours,
/// in two types neither of which is a `Color`. `DESIGN_SYSTEM_AUDIT.md` §6
/// counts both among the four colour authorities living outside `AppColors`.
///
/// **The colours are the brand's, not Material's.** Blueprint Capítulo 5's
/// colour table (line 485) and `COMPONENT_INVENTORY.md` §4 both prescribe the
/// same mapping — common `inkSoft`, rare `sky`, epic `lavender`, legendary
/// `butter` — and give the reason: gold was retired by Capítulo 5, and making
/// legendary Butter says more than gold does, because Butter *is* the mark.
/// Roadmap item F6 is named for that consequence: "retires the last live uses
/// of `gold`". Neither old ladder had a single Butter Bliss value in it.
///
/// Shaped after [BufonPhase]: an enum in the theme layer that resolves its own
/// colours from [AppColors], so a caller states meaning and the design system
/// answers with a `Color`. Callers no longer parse anything — the two hex
/// formats above were being converted at the call site, one of them by
/// `int.parse('0xFF' + s.substring(1))`.
///
/// The value names are load-bearing: titles and avatars persist and read this
/// through `rarity.name`, so `common`/`rare`/`epic`/`legendary` are the
/// stored strings and cannot be renamed without a Firestore migration.
enum Rarity {
  common,
  rare,
  epic,
  legendary;

  String get displayName => switch (this) {
    Rarity.common => 'Común',
    Rarity.rare => 'Raro',
    Rarity.epic => 'Épico',
    Rarity.legendary => 'Legendario',
  };

  Color get color => switch (this) {
    Rarity.common => AppColors.inkSoft,
    Rarity.rare => AppColors.sky,
    Rarity.epic => AppColors.lavender,
    Rarity.legendary => AppColors.butter,
  };
}
