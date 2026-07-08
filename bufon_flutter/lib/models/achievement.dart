// models/achievement.dart

/// Represents an unlockable achievement in the game
class Achievement {
  final String id;
  final String name;
  final String description;
  final String unlockCondition;
  final int xpReward;
  final String icon; // Emoji or icon identifier

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.unlockCondition,
    required this.xpReward,
    required this.icon,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      unlockCondition: json['unlockCondition'] as String,
      xpReward: json['xpReward'] as int,
      icon: json['icon'] as String? ?? '🏆',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'unlockCondition': unlockCondition,
      'xpReward': xpReward,
      'icon': icon,
    };
  }

  Achievement copyWith({
    String? id,
    String? name,
    String? description,
    String? unlockCondition,
    int? xpReward,
    String? icon,
  }) {
    return Achievement(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      unlockCondition: unlockCondition ?? this.unlockCondition,
      xpReward: xpReward ?? this.xpReward,
      icon: icon ?? this.icon,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Achievement &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Achievement(id: $id, name: $name, xp: $xpReward)';
}

/// Predefined achievements
class Achievements {
  static const firstGame = Achievement(
    id: 'first_game',
    name: 'Primera Partida',
    description: 'Juega tu primera partida',
    unlockCondition: 'totalGames >= 1',
    xpReward: 50,
    icon: '🎮',
  );

  static const firstWin = Achievement(
    id: 'first_win',
    name: 'Primera Victoria',
    description: 'Gana tu primera partida',
    unlockCondition: 'totalWins >= 1',
    xpReward: 100,
    icon: '🏆',
  );

  static const tenGames = Achievement(
    id: 'ten_games',
    name: 'Veterano',
    description: 'Juega 10 partidas',
    unlockCondition: 'totalGames >= 10',
    xpReward: 150,
    icon: '⭐',
  );

  static const fiveWins = Achievement(
    id: 'five_wins',
    name: 'Campeón',
    description: 'Gana 5 partidas',
    unlockCondition: 'totalWins >= 5',
    xpReward: 200,
    icon: '👑',
  );

  static const fiftyVotes = Achievement(
    id: 'fifty_votes',
    name: 'Popular',
    description: 'Recibe 50 votos',
    unlockCondition: 'totalVotesReceived >= 50',
    xpReward: 250,
    icon: '💖',
  );

  static const nightPassPurchase = Achievement(
    id: 'night_pass_purchase',
    name: 'Pase Nocturno',
    description: 'Compra el Night Pass',
    unlockCondition: 'hasNightPass == true',
    xpReward: 50,
    icon: '🌙',
  );

  static const fiftyGames = Achievement(
    id: 'fifty_games',
    name: 'Leyenda',
    description: 'Juega 50 partidas',
    unlockCondition: 'totalGames >= 50',
    xpReward: 500,
    icon: '🔥',
  );

  static const twentyWins = Achievement(
    id: 'twenty_wins',
    name: 'Maestro',
    description: 'Gana 20 partidas',
    unlockCondition: 'totalWins >= 20',
    xpReward: 750,
    icon: '💎',
  );

  /// Get all achievements
  static List<Achievement> get all => [
    firstGame,
    firstWin,
    tenGames,
    fiveWins,
    fiftyVotes,
    nightPassPurchase,
    fiftyGames,
    twentyWins,
  ];

  /// Get achievement by ID
  static Achievement? getById(String id) {
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
}
