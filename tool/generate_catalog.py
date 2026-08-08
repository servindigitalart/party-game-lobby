#!/usr/bin/env python3
"""Generates the progression rule tables for both runtimes.

    python3 tool/generate_catalog.py

Reads shared/progression_catalog.json and writes:

  functions/src/progression/catalog.ts         (server: grants)
  bufon_flutter/lib/models/progression_rules.dart  (client: progress bars)

Only the server grants anything, so the client copy exists purely so the UI
can show how close a player is to the next unlock. Before this file the two
copies were hand-written in two languages, which meant a retuned threshold
could show a progress bar that never completes.

Both outputs are generated: edit the JSON, re-run, commit all three.
"""

import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
CATALOG = json.loads((ROOT / 'shared/progression_catalog.json').read_text())

BANNER = (
    'GENERATED FILE — DO NOT EDIT BY HAND.\n'
    'Source: shared/progression_catalog.json\n'
    'Regenerate: python3 tool/generate_catalog.py'
)


def typescript() -> str:
    xp = CATALOG['matchXp']
    return f"""// functions/src/progression/catalog.ts
//
// {BANNER.replace(chr(10), chr(10) + '// ')}

export interface AchievementRule {{
  id: string;
  xpReward: number;
}}

export type AvatarRequirement =
  | 'level'
  | 'gamesPlayed'
  | 'wins'
  | 'votesReceived'
  | 'achievement'
  | 'nightPass';

export interface AvatarRule {{
  id: string;
  requirement: AvatarRequirement;
  value: number;
  achievementId?: string;
}}

export type TitleCondition =
  | 'xp'
  | 'wins'
  | 'votes'
  | 'games'
  | 'leaderboardRank'
  | 'nightPass'
  | 'achievement'
  | 'secret';

export interface TitleRule {{
  id: string;
  condition: TitleCondition;
  value: number;
  rarity: string;
  achievementId?: string;
}}

export const MATCH_XP = {{
  base: {xp['base']},
  winnerBonus: {xp['winnerBonus']},
  perVote: {xp['perVote']},
}};

export const ACHIEVEMENTS: AchievementRule[] = {json.dumps(CATALOG['achievements'], indent=2)};

export const AVATARS: AvatarRule[] = {json.dumps(CATALOG['avatars'], indent=2)};

export const TITLES: TitleRule[] = {json.dumps(CATALOG['titles'], indent=2)};

/** Mirrors UserProfile.calculateLevel in the Dart client. */
export function calculateLevel(xp: number): number {{
  return Math.floor(Math.sqrt(xp / 100)) + 1;
}}

/** Which stat an achievement watches, and the value that unlocks it. */
export const ACHIEVEMENT_THRESHOLDS: Record<
  string,
  {{ stat: 'totalGames' | 'totalWins' | 'totalVotesReceived'; value: number }}
> = {json.dumps(CATALOG['achievementThresholds'], indent=2)};
"""


def _dart_map(entries: list, keys: list) -> str:
    rows = []
    for e in entries:
        fields = ', '.join(
            f"{k}: {json.dumps(e[k])}" for k in keys if k in e
        )
        rows.append(f"    {json.dumps(e['id'])}: ProgressionRule({fields}),")
    return '\n'.join(rows)


def dart() -> str:
    xp = CATALOG['matchXp']
    thresholds = '\n'.join(
        f"    {json.dumps(k)}: AchievementThreshold("
        f"stat: {json.dumps(v['stat'])}, value: {v['value']}),"
        for k, v in CATALOG['achievementThresholds'].items()
    )
    return f"""// models/progression_rules.dart
//
// {BANNER.replace(chr(10), chr(10) + '// ')}
//
// These are the *display* copy of the rules: the server is the only thing
// that grants XP, achievements, avatars or titles. The client uses them to
// draw progress toward the next unlock, so both sides must agree.

class ProgressionRule {{
  const ProgressionRule({{
    required this.id,
    this.requirement,
    this.condition,
    this.value = 0,
    this.xpReward = 0,
    this.achievementId,
  }});

  final String id;

  /// Avatar unlock requirement: level, gamesPlayed, wins, votesReceived,
  /// achievement, nightPass.
  final String? requirement;

  /// Title unlock condition: xp, wins, votes, games, leaderboardRank,
  /// nightPass, achievement, secret.
  final String? condition;

  final int value;
  final int xpReward;
  final String? achievementId;
}}

class AchievementThreshold {{
  const AchievementThreshold({{required this.stat, required this.value}});

  /// One of totalGames, totalWins, totalVotesReceived.
  final String stat;
  final int value;
}}

class ProgressionRules {{
  ProgressionRules._();

  /// Match award, mirroring the server's matchXp().
  static const int matchXpBase = {xp['base']};
  static const int matchXpWinnerBonus = {xp['winnerBonus']};
  static const int matchXpPerVote = {xp['perVote']};

  static int matchXp({{required bool isWinner, required int votesReceived}}) {{
    return matchXpBase +
        (isWinner ? matchXpWinnerBonus : 0) +
        votesReceived * matchXpPerVote;
  }}

  static const Map<String, AchievementThreshold> achievementThresholds = {{
{thresholds}
  }};

  static const Map<String, ProgressionRule> achievements = {{
{_dart_map(CATALOG['achievements'], ['id', 'xpReward'])}
  }};

  static const Map<String, ProgressionRule> avatars = {{
{_dart_map(CATALOG['avatars'], ['id', 'requirement', 'value', 'achievementId'])}
  }};

  static const Map<String, ProgressionRule> titles = {{
{_dart_map(CATALOG['titles'], ['id', 'condition', 'value', 'achievementId'])}
  }};
}}
"""


def main() -> None:
    targets = {
        ROOT / 'functions/src/progression/catalog.ts': typescript(),
        ROOT / 'bufon_flutter/lib/models/progression_rules.dart': dart(),
    }
    for path, content in targets.items():
        path.write_text(content)
        print(f'wrote {path.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
