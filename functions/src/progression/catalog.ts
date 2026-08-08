// functions/src/progression/catalog.ts
//
// GENERATED FILE — DO NOT EDIT BY HAND.
// Source: shared/progression_catalog.json
// Regenerate: python3 tool/generate_catalog.py

export interface AchievementRule {
  id: string;
  xpReward: number;
}

export type AvatarRequirement =
  | 'level'
  | 'gamesPlayed'
  | 'wins'
  | 'votesReceived'
  | 'achievement'
  | 'nightPass';

export interface AvatarRule {
  id: string;
  requirement: AvatarRequirement;
  value: number;
  achievementId?: string;
}

export type TitleCondition =
  | 'xp'
  | 'wins'
  | 'votes'
  | 'games'
  | 'leaderboardRank'
  | 'nightPass'
  | 'achievement'
  | 'secret';

export interface TitleRule {
  id: string;
  condition: TitleCondition;
  value: number;
  rarity: string;
  achievementId?: string;
}

export const MATCH_XP = {
  base: 10,
  winnerBonus: 25,
  perVote: 5,
};

export const ACHIEVEMENTS: AchievementRule[] = [
  {
    "id": "first_game",
    "xpReward": 50
  },
  {
    "id": "first_win",
    "xpReward": 100
  },
  {
    "id": "ten_games",
    "xpReward": 150
  },
  {
    "id": "five_wins",
    "xpReward": 200
  },
  {
    "id": "fifty_votes",
    "xpReward": 250
  },
  {
    "id": "night_pass_purchase",
    "xpReward": 50
  },
  {
    "id": "fifty_games",
    "xpReward": 500
  },
  {
    "id": "twenty_wins",
    "xpReward": 750
  }
];

export const AVATARS: AvatarRule[] = [
  {
    "id": "default",
    "requirement": "level",
    "value": 1
  },
  {
    "id": "smiley",
    "requirement": "gamesPlayed",
    "value": 1
  },
  {
    "id": "cool",
    "requirement": "level",
    "value": 2
  },
  {
    "id": "party",
    "requirement": "gamesPlayed",
    "value": 5
  },
  {
    "id": "genius",
    "requirement": "wins",
    "value": 3
  },
  {
    "id": "devil",
    "requirement": "votesReceived",
    "value": 20
  },
  {
    "id": "star",
    "requirement": "achievement",
    "value": 1
  },
  {
    "id": "fire",
    "requirement": "wins",
    "value": 10
  },
  {
    "id": "robot",
    "requirement": "gamesPlayed",
    "value": 25
  },
  {
    "id": "crown",
    "requirement": "achievement",
    "value": 1
  },
  {
    "id": "diamond",
    "requirement": "level",
    "value": 10
  },
  {
    "id": "night_pass",
    "requirement": "nightPass",
    "value": 1
  }
];

export const TITLES: TitleRule[] = [
  {
    "id": "npc_grupo",
    "condition": "games",
    "value": 5,
    "rarity": "common"
  },
  {
    "id": "mitomano_certificado",
    "condition": "votes",
    "value": 10,
    "rarity": "common"
  },
  {
    "id": "agente_caos",
    "condition": "votes",
    "value": 50,
    "rarity": "rare"
  },
  {
    "id": "rey_drama",
    "condition": "wins",
    "value": 10,
    "rarity": "rare"
  },
  {
    "id": "down_bad_pro",
    "condition": "xp",
    "value": 1000,
    "rarity": "rare"
  },
  {
    "id": "viral_grupo",
    "condition": "votes",
    "value": 100,
    "rarity": "rare"
  },
  {
    "id": "arquitecto_desmadre",
    "condition": "wins",
    "value": 25,
    "rarity": "epic"
  },
  {
    "id": "corazon_roto_oficial",
    "condition": "xp",
    "value": 2500,
    "rarity": "epic"
  },
  {
    "id": "maestro_meme",
    "condition": "votes",
    "value": 250,
    "rarity": "epic"
  },
  {
    "id": "bufon_supremo",
    "condition": "leaderboardRank",
    "value": 10,
    "rarity": "legendary"
  },
  {
    "id": "leyenda_semanal",
    "condition": "leaderboardRank",
    "value": 3,
    "rarity": "legendary"
  },
  {
    "id": "top_global",
    "condition": "leaderboardRank",
    "value": 10,
    "rarity": "legendary"
  },
  {
    "id": "season_champion_legendary",
    "condition": "achievement",
    "value": 0,
    "rarity": "legendary"
  }
];

/** Mirrors UserProfile.calculateLevel in the Dart client. */
export function calculateLevel(xp: number): number {
  return Math.floor(Math.sqrt(xp / 100)) + 1;
}

/** Which stat an achievement watches, and the value that unlocks it. */
export const ACHIEVEMENT_THRESHOLDS: Record<
  string,
  { stat: 'totalGames' | 'totalWins' | 'totalVotesReceived'; value: number }
> = {
  "first_game": {
    "stat": "totalGames",
    "value": 1
  },
  "first_win": {
    "stat": "totalWins",
    "value": 1
  },
  "ten_games": {
    "stat": "totalGames",
    "value": 10
  },
  "five_wins": {
    "stat": "totalWins",
    "value": 5
  },
  "fifty_votes": {
    "stat": "totalVotesReceived",
    "value": 50
  },
  "fifty_games": {
    "stat": "totalGames",
    "value": 50
  },
  "twenty_wins": {
    "stat": "totalWins",
    "value": 20
  }
};
