import 'package:bufon_flutter/models/achievement.dart';
import 'package:bufon_flutter/models/avatar.dart';
import 'package:bufon_flutter/models/progression_rules.dart';
import 'package:bufon_flutter/models/title.dart';
import 'package:flutter_test/flutter_test.dart';

/// The presentation catalogs (`Achievements`, `Avatars`, `Titles`) still
/// carry their own thresholds because they are also the UI's source of names,
/// descriptions and emoji. `ProgressionRules` is generated from
/// shared/progression_catalog.json, which is what the server grants from.
///
/// These tests are the seam between them: if someone retunes a value in one
/// place and not the other, the app would draw a progress bar the server
/// never completes. Now it fails here instead.
void main() {
  group('generated rules match the presentation catalog', () {
    test('every achievement exists on both sides with the same XP reward', () {
      for (final achievement in Achievements.all) {
        final rule = ProgressionRules.achievements[achievement.id];
        expect(rule, isNotNull, reason: 'missing rule for ${achievement.id}');
        expect(
          rule!.xpReward,
          achievement.xpReward,
          reason: '${achievement.id} xpReward drifted',
        );
      }
      expect(
        ProgressionRules.achievements.length,
        Achievements.all.length,
        reason: 'the shared catalog has achievements the app does not show',
      );
    });

    test('every avatar requirement matches', () {
      for (final avatar in Avatars.all) {
        final rule = ProgressionRules.avatars[avatar.id];
        expect(rule, isNotNull, reason: 'missing rule for ${avatar.id}');
        expect(
          rule!.requirement,
          avatar.requirementType.name,
          reason: '${avatar.id} requirement type drifted',
        );
        expect(
          rule.value,
          avatar.requirementValue,
          reason: '${avatar.id} requirement value drifted',
        );
      }
      expect(ProgressionRules.avatars.length, Avatars.all.length);
    });

    test('every title unlock condition matches', () {
      for (final title in Titles.all) {
        final rule = ProgressionRules.titles[title.id];
        expect(rule, isNotNull, reason: 'missing rule for ${title.id}');
        expect(
          rule!.condition,
          title.unlockConditionType.name,
          reason: '${title.id} condition drifted',
        );
        expect(
          rule.value,
          title.unlockValue,
          reason: '${title.id} unlock value drifted',
        );
      }
      expect(ProgressionRules.titles.length, Titles.all.length);
    });
  });

  group('match award agrees with the server', () {
    // Mirrors functions/src/progression/services.ts matchXp(), which is
    // generated from the same JSON and covered by its own node test.
    test('the formula matches the server award', () {
      expect(ProgressionRules.matchXp(isWinner: false, votesReceived: 0), 10);
      expect(ProgressionRules.matchXp(isWinner: true, votesReceived: 0), 35);
      expect(ProgressionRules.matchXp(isWinner: false, votesReceived: 3), 25);
      expect(ProgressionRules.matchXp(isWinner: true, votesReceived: 3), 50);
    });

    test('achievement thresholds only watch real profile stats', () {
      const stats = {'totalGames', 'totalWins', 'totalVotesReceived'};
      for (final entry in ProgressionRules.achievementThresholds.entries) {
        expect(
          stats.contains(entry.value.stat),
          isTrue,
          reason: '${entry.key} watches unknown stat ${entry.value.stat}',
        );
        expect(entry.value.value, greaterThan(0));
      }
    });
  });
}
