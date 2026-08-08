// models/progression_rules.dart
//
// GENERATED FILE — DO NOT EDIT BY HAND.
// Source: shared/progression_catalog.json
// Regenerate: python3 tool/generate_catalog.py
//
// These are the *display* copy of the rules: the server is the only thing
// that grants XP, achievements, avatars or titles. The client uses them to
// draw progress toward the next unlock, so both sides must agree.

class ProgressionRule {
  const ProgressionRule({
    required this.id,
    this.requirement,
    this.condition,
    this.value = 0,
    this.xpReward = 0,
    this.achievementId,
  });

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
}

class AchievementThreshold {
  const AchievementThreshold({required this.stat, required this.value});

  /// One of totalGames, totalWins, totalVotesReceived.
  final String stat;
  final int value;
}

class ProgressionRules {
  ProgressionRules._();

  /// Match award, mirroring the server's matchXp().
  static const int matchXpBase = 10;
  static const int matchXpWinnerBonus = 25;
  static const int matchXpPerVote = 5;

  static int matchXp({required bool isWinner, required int votesReceived}) {
    return matchXpBase +
        (isWinner ? matchXpWinnerBonus : 0) +
        votesReceived * matchXpPerVote;
  }

  static const Map<String, AchievementThreshold> achievementThresholds = {
    "first_game": AchievementThreshold(stat: "totalGames", value: 1),
    "first_win": AchievementThreshold(stat: "totalWins", value: 1),
    "ten_games": AchievementThreshold(stat: "totalGames", value: 10),
    "five_wins": AchievementThreshold(stat: "totalWins", value: 5),
    "fifty_votes": AchievementThreshold(stat: "totalVotesReceived", value: 50),
    "fifty_games": AchievementThreshold(stat: "totalGames", value: 50),
    "twenty_wins": AchievementThreshold(stat: "totalWins", value: 20),
  };

  static const Map<String, ProgressionRule> achievements = {
    "first_game": ProgressionRule(id: "first_game", xpReward: 50),
    "first_win": ProgressionRule(id: "first_win", xpReward: 100),
    "ten_games": ProgressionRule(id: "ten_games", xpReward: 150),
    "five_wins": ProgressionRule(id: "five_wins", xpReward: 200),
    "fifty_votes": ProgressionRule(id: "fifty_votes", xpReward: 250),
    "night_pass_purchase": ProgressionRule(
      id: "night_pass_purchase",
      xpReward: 50,
    ),
    "fifty_games": ProgressionRule(id: "fifty_games", xpReward: 500),
    "twenty_wins": ProgressionRule(id: "twenty_wins", xpReward: 750),
  };

  static const Map<String, ProgressionRule> avatars = {
    "default": ProgressionRule(id: "default", requirement: "level", value: 1),
    "smiley": ProgressionRule(
      id: "smiley",
      requirement: "gamesPlayed",
      value: 1,
    ),
    "cool": ProgressionRule(id: "cool", requirement: "level", value: 2),
    "party": ProgressionRule(id: "party", requirement: "gamesPlayed", value: 5),
    "genius": ProgressionRule(id: "genius", requirement: "wins", value: 3),
    "devil": ProgressionRule(
      id: "devil",
      requirement: "votesReceived",
      value: 20,
    ),
    "star": ProgressionRule(id: "star", requirement: "achievement", value: 1),
    "fire": ProgressionRule(id: "fire", requirement: "wins", value: 10),
    "robot": ProgressionRule(
      id: "robot",
      requirement: "gamesPlayed",
      value: 25,
    ),
    "crown": ProgressionRule(id: "crown", requirement: "achievement", value: 1),
    "diamond": ProgressionRule(id: "diamond", requirement: "level", value: 10),
    "night_pass": ProgressionRule(
      id: "night_pass",
      requirement: "nightPass",
      value: 1,
    ),
  };

  static const Map<String, ProgressionRule> titles = {
    "npc_grupo": ProgressionRule(id: "npc_grupo", condition: "games", value: 5),
    "mitomano_certificado": ProgressionRule(
      id: "mitomano_certificado",
      condition: "votes",
      value: 10,
    ),
    "agente_caos": ProgressionRule(
      id: "agente_caos",
      condition: "votes",
      value: 50,
    ),
    "rey_drama": ProgressionRule(id: "rey_drama", condition: "wins", value: 10),
    "down_bad_pro": ProgressionRule(
      id: "down_bad_pro",
      condition: "xp",
      value: 1000,
    ),
    "viral_grupo": ProgressionRule(
      id: "viral_grupo",
      condition: "votes",
      value: 100,
    ),
    "arquitecto_desmadre": ProgressionRule(
      id: "arquitecto_desmadre",
      condition: "wins",
      value: 25,
    ),
    "corazon_roto_oficial": ProgressionRule(
      id: "corazon_roto_oficial",
      condition: "xp",
      value: 2500,
    ),
    "maestro_meme": ProgressionRule(
      id: "maestro_meme",
      condition: "votes",
      value: 250,
    ),
    "bufon_supremo": ProgressionRule(
      id: "bufon_supremo",
      condition: "leaderboardRank",
      value: 10,
    ),
    "leyenda_semanal": ProgressionRule(
      id: "leyenda_semanal",
      condition: "leaderboardRank",
      value: 3,
    ),
    "top_global": ProgressionRule(
      id: "top_global",
      condition: "leaderboardRank",
      value: 10,
    ),
    "season_champion_legendary": ProgressionRule(
      id: "season_champion_legendary",
      condition: "achievement",
      value: 0,
    ),
  };
}
