// test/rarity_ladder_test.dart

import 'dart:io';

import 'package:bufon_flutter/core/theme/app_colors.dart';
import 'package:bufon_flutter/core/theme/rarity.dart';
import 'package:bufon_flutter/models/avatar.dart';
import 'package:bufon_flutter/models/title.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fase 2B WP17 — F6: titles and avatars share one rarity ladder.
///
/// They used to carry a four-tier enum each: same tiers, same Spanish labels,
/// three of four colours different, and neither accessor returning a `Color`
/// — `TitleRarity.color` was an `int`, `AvatarRarity.color` a `String` hex
/// that Profile converted with `int.parse('0xFF' + s.substring(1))`.
void main() {
  String read(String path) => File(path).readAsStringSync();

  group('one ladder', () {
    test('neither content model declares a rarity ladder of its own', () {
      expect(
        read('lib/models/title.dart'),
        isNot(contains('enum TitleRarity')),
      );
      expect(
        read('lib/models/avatar.dart'),
        isNot(contains('enum AvatarRarity')),
      );
    });

    test('the tiers and their order are unchanged', () {
      // Order is load-bearing beyond presentation: the title selector sorts
      // by it, legendary first.
      expect(Rarity.values, [
        Rarity.common,
        Rarity.rare,
        Rarity.epic,
        Rarity.legendary,
      ]);
    });

    test('titles and avatars type their rarity as the same enum', () {
      // Shared ownership, not two ladders that happen to agree: the values
      // on both models are drawn from `Rarity.values` itself.
      for (final title in Titles.all) {
        expect(Rarity.values, contains(title.rarity));
      }
      for (final avatar in Avatars.all) {
        expect(Rarity.values, contains(avatar.rarity));
      }
      // A legendary title and a legendary avatar are now the same object.
      final legendaryTitle = Titles.all.firstWhere(
        (t) => t.rarity == Rarity.legendary,
      );
      final legendaryAvatar = Avatars.all.firstWhere(
        (a) => a.rarity == Rarity.legendary,
      );
      expect(legendaryTitle.rarity, same(legendaryAvatar.rarity));
      expect(legendaryTitle.rarity.color, legendaryAvatar.rarity.color);
    });
  });

  group('colour', () {
    test('each tier resolves to its Butter Bliss token', () {
      // Blueprint line 485 and COMPONENT_INVENTORY §4 both prescribe exactly
      // this mapping. Asserted against `AppColors` rather than against hex
      // literals, so the ladder cannot drift away from the palette.
      expect(Rarity.common.color, AppColors.inkSoft);
      expect(Rarity.rare.color, AppColors.sky);
      expect(Rarity.epic.color, AppColors.lavender);
      expect(Rarity.legendary.color, AppColors.butter);
    });

    test('no tier still carries the retired gold', () {
      // Both old ladders ended in #FFD700. Capítulo 5 retired gold, and F6 is
      // named for removing its last live uses.
      for (final rarity in Rarity.values) {
        expect(rarity.color, isNot(AppColors.gold));
      }
    });

    test('Profile no longer parses a rarity colour out of a string', () {
      expect(
        read('lib/presentation/screens/profile_screen.dart'),
        isNot(contains('rarity.color.substring')),
      );
    });
  });

  group('labels', () {
    test('the Spanish labels are unchanged', () {
      expect(Rarity.common.displayName, 'Común');
      expect(Rarity.rare.displayName, 'Raro');
      expect(Rarity.epic.displayName, 'Épico');
      expect(Rarity.legendary.displayName, 'Legendario');
    });
  });

  group('serialization', () {
    // The stored representation is `rarity.name`, and the catalogues below
    // are the real ones the app ships — no invented fixtures.
    test('a title round-trips through its persisted form', () {
      final source = Titles.all.firstWhere((t) => t.rarity == Rarity.epic);
      final json = source.toJson();

      expect(json['rarity'], 'epic');
      expect(BufonTitle.fromJson(json).rarity, Rarity.epic);
    });

    test('an avatar round-trips through its persisted form', () {
      final source = Avatars.all.firstWhere((a) => a.rarity == Rarity.rare);
      final json = source.toJson();

      expect(json['rarity'], 'rare');
      expect(Avatar.fromJson(json).rarity, Rarity.rare);
    });

    test('every stored tier string still parses on both models', () {
      // The four strings already in Firestore. If any stopped resolving, the
      // documents holding it would silently fall back to `common`.
      for (final stored in const ['common', 'rare', 'epic', 'legendary']) {
        final title = Titles.all.first.toJson()..['rarity'] = stored;
        final avatar = Avatars.all.first.toJson()..['rarity'] = stored;

        expect(BufonTitle.fromJson(title).rarity.name, stored);
        expect(Avatar.fromJson(avatar).rarity.name, stored);
      }
    });
  });
}
