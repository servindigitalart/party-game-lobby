// models/title.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/rarity.dart';

/// Type of unlock condition
enum UnlockConditionType {
  xp,
  wins,
  votes,
  games,
  leaderboardRank,
  nightPass,
  achievement,
  secret;

  String get displayName {
    switch (this) {
      case UnlockConditionType.xp:
        return 'XP Total';
      case UnlockConditionType.wins:
        return 'Victorias';
      case UnlockConditionType.votes:
        return 'Votos Recibidos';
      case UnlockConditionType.games:
        return 'Partidas Jugadas';
      case UnlockConditionType.leaderboardRank:
        return 'Ranking';
      case UnlockConditionType.nightPass:
        return 'Night Pass';
      case UnlockConditionType.achievement:
        return 'Logro';
      case UnlockConditionType.secret:
        return '???';
    }
  }
}

/// Represents a player title/badge
class BufonTitle {
  final String id;
  final String name;
  final String description;
  final Rarity rarity;
  final UnlockConditionType unlockConditionType;
  final int unlockValue;
  final bool isSecret;
  final String? achievementId; // If unlockConditionType is achievement

  const BufonTitle({
    required this.id,
    required this.name,
    required this.description,
    required this.rarity,
    required this.unlockConditionType,
    required this.unlockValue,
    this.isSecret = false,
    this.achievementId,
  });

  factory BufonTitle.fromJson(Map<String, dynamic> json) {
    return BufonTitle(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      rarity: Rarity.values.firstWhere(
        (r) => r.name == json['rarity'],
        orElse: () => Rarity.common,
      ),
      unlockConditionType: UnlockConditionType.values.firstWhere(
        (t) => t.name == json['unlockConditionType'],
        orElse: () => UnlockConditionType.xp,
      ),
      unlockValue: json['unlockValue'] as int? ?? 0,
      isSecret: json['isSecret'] as bool? ?? false,
      achievementId: json['achievementId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'rarity': rarity.name,
      'unlockConditionType': unlockConditionType.name,
      'unlockValue': unlockValue,
      'isSecret': isSecret,
      if (achievementId != null) 'achievementId': achievementId,
    };
  }

  /// Get unlock requirement text
  String get unlockRequirementText {
    if (isSecret) return '???';

    switch (unlockConditionType) {
      case UnlockConditionType.xp:
        return 'Alcanza $unlockValue XP';
      case UnlockConditionType.wins:
        return 'Gana $unlockValue partidas';
      case UnlockConditionType.votes:
        return 'Recibe $unlockValue votos';
      case UnlockConditionType.games:
        return 'Juega $unlockValue partidas';
      case UnlockConditionType.leaderboardRank:
        return 'Alcanza el top $unlockValue';
      case UnlockConditionType.nightPass:
        return 'Activa Night Pass';
      case UnlockConditionType.achievement:
        return 'Desbloquea el logro requerido';
      case UnlockConditionType.secret:
        return '???';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BufonTitle && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'BufonTitle(id: $id, name: $name, rarity: ${rarity.name})';
}

/// User's unlocked title
class UnlockedTitle {
  final String titleId;
  final DateTime unlockedAt;
  final String source; // 'achievement', 'leaderboard', 'milestone'

  const UnlockedTitle({
    required this.titleId,
    required this.unlockedAt,
    required this.source,
  });

  factory UnlockedTitle.fromJson(Map<String, dynamic> json, String titleId) {
    return UnlockedTitle(
      titleId: titleId,
      unlockedAt: (json['unlockedAt'] as Timestamp).toDate(),
      source: json['source'] as String? ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {'unlockedAt': Timestamp.fromDate(unlockedAt), 'source': source};
  }

  @override
  String toString() => 'UnlockedTitle(id: $titleId, source: $source)';
}

/// Predefined titles
class Titles {
  Titles._();

  static const List<BufonTitle> all = [
    // Common titles - Entry level
    BufonTitle(
      id: 'npc_grupo',
      name: 'NPC del Grupo',
      description: 'El que siempre está pero nadie nota',
      rarity: Rarity.common,
      unlockConditionType: UnlockConditionType.games,
      unlockValue: 5,
    ),
    BufonTitle(
      id: 'mitomano_certificado',
      name: 'Mitómano Certificado',
      description: 'Especialista en inventar historias',
      rarity: Rarity.common,
      unlockConditionType: UnlockConditionType.votes,
      unlockValue: 10,
    ),

    // Rare titles - Mid level
    BufonTitle(
      id: 'agente_caos',
      name: 'Agente del Caos',
      description: 'Maestro en crear desmadre',
      rarity: Rarity.rare,
      unlockConditionType: UnlockConditionType.votes,
      unlockValue: 50,
    ),
    BufonTitle(
      id: 'rey_drama',
      name: 'Rey del Drama',
      description: 'Todo es un evento para ti',
      rarity: Rarity.rare,
      unlockConditionType: UnlockConditionType.wins,
      unlockValue: 10,
    ),
    BufonTitle(
      id: 'down_bad_pro',
      name: 'Down Bad Profesional',
      description: 'En el fondo del barranco emocional',
      rarity: Rarity.rare,
      unlockConditionType: UnlockConditionType.xp,
      unlockValue: 1000,
    ),
    BufonTitle(
      id: 'viral_grupo',
      name: 'Viral del Grupo',
      description: 'Tus respuestas son legendarias',
      rarity: Rarity.rare,
      unlockConditionType: UnlockConditionType.votes,
      unlockValue: 100,
    ),

    // Epic titles - High level
    BufonTitle(
      id: 'arquitecto_desmadre',
      name: 'Arquitecto del Desmadre',
      description: 'Planificas el caos con precisión',
      rarity: Rarity.epic,
      unlockConditionType: UnlockConditionType.wins,
      unlockValue: 25,
    ),
    BufonTitle(
      id: 'corazon_roto_oficial',
      name: 'Corazón Roto Oficial',
      description: 'Experto en dramas románticos',
      rarity: Rarity.epic,
      unlockConditionType: UnlockConditionType.xp,
      unlockValue: 2500,
    ),
    BufonTitle(
      id: 'maestro_meme',
      name: 'Maestro del Meme',
      description: 'Todo lo conviertes en meme',
      rarity: Rarity.epic,
      unlockConditionType: UnlockConditionType.votes,
      unlockValue: 250,
    ),

    // Legendary titles - Top tier
    BufonTitle(
      id: 'bufon_supremo',
      name: 'Bufón Supremo',
      description: 'El más caótico de todos',
      rarity: Rarity.legendary,
      unlockConditionType: UnlockConditionType.leaderboardRank,
      unlockValue: 10,
    ),
    BufonTitle(
      id: 'leyenda_semanal',
      name: 'Leyenda Semanal',
      description: 'Dominaste el ranking semanal',
      rarity: Rarity.legendary,
      unlockConditionType: UnlockConditionType.leaderboardRank,
      unlockValue: 3,
    ),
    BufonTitle(
      id: 'top_global',
      name: 'Top 10 Global',
      description: 'Entre los mejores del mundo',
      rarity: Rarity.legendary,
      unlockConditionType: UnlockConditionType.leaderboardRank,
      unlockValue: 10,
    ),

    // Seasonal titles - Legendary (from season rewards)
    BufonTitle(
      id: 'season_champion_legendary',
      name: '👑 Campeón de Temporada',
      description: '¡Primer lugar en la temporada competitiva!',
      rarity: Rarity.legendary,
      unlockConditionType: UnlockConditionType.achievement,
      unlockValue: 0,
      isSecret: true,
      achievementId: 'season_rank_1',
    ),
  ];

  /// Get title by ID
  static BufonTitle? getById(String id) {
    try {
      return all.firstWhere((title) => title.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get titles by rarity
  static List<BufonTitle> getByRarity(Rarity rarity) {
    return all.where((title) => title.rarity == rarity).toList();
  }

  /// Get common titles
  static List<BufonTitle> get common => getByRarity(Rarity.common);

  /// Get rare titles
  static List<BufonTitle> get rare => getByRarity(Rarity.rare);

  /// Get epic titles
  static List<BufonTitle> get epic => getByRarity(Rarity.epic);

  /// Get legendary titles
  static List<BufonTitle> get legendary => getByRarity(Rarity.legendary);
}
