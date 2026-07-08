// models/avatar.dart

/// Rarity levels for avatars
enum AvatarRarity {
  common,
  rare,
  epic,
  legendary;

  String get displayName {
    switch (this) {
      case AvatarRarity.common:
        return 'Común';
      case AvatarRarity.rare:
        return 'Raro';
      case AvatarRarity.epic:
        return 'Épico';
      case AvatarRarity.legendary:
        return 'Legendario';
    }
  }

  String get color {
    switch (this) {
      case AvatarRarity.common:
        return '#CCCCCC'; // Gray
      case AvatarRarity.rare:
        return '#4A9EFF'; // Blue
      case AvatarRarity.epic:
        return '#B24AFF'; // Purple
      case AvatarRarity.legendary:
        return '#FFD700'; // Gold
    }
  }
}

/// Unlock requirement types
enum UnlockRequirement {
  level,
  achievement,
  gamesPlayed,
  wins,
  votesReceived,
  nightPass;

  String describe(int value) {
    switch (this) {
      case UnlockRequirement.level:
        return 'Alcanza nivel $value';
      case UnlockRequirement.achievement:
        return 'Desbloquea logro';
      case UnlockRequirement.gamesPlayed:
        return 'Juega $value partidas';
      case UnlockRequirement.wins:
        return 'Gana $value partidas';
      case UnlockRequirement.votesReceived:
        return 'Recibe $value votos';
      case UnlockRequirement.nightPass:
        return 'Compra Night Pass';
    }
  }
}

/// Represents an unlockable avatar
class Avatar {
  final String id;
  final String name;
  final String emoji; // Avatar representation
  final AvatarRarity rarity;
  final UnlockRequirement requirementType;
  final int requirementValue;
  final String? achievementId; // If requirementType is achievement

  const Avatar({
    required this.id,
    required this.name,
    required this.emoji,
    required this.rarity,
    required this.requirementType,
    required this.requirementValue,
    this.achievementId,
  });

  factory Avatar.fromJson(Map<String, dynamic> json) {
    return Avatar(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      rarity: AvatarRarity.values.firstWhere(
        (r) => r.name == json['rarity'],
        orElse: () => AvatarRarity.common,
      ),
      requirementType: UnlockRequirement.values.firstWhere(
        (r) => r.name == json['requirementType'],
      ),
      requirementValue: json['requirementValue'] as int,
      achievementId: json['achievementId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'rarity': rarity.name,
      'requirementType': requirementType.name,
      'requirementValue': requirementValue,
      if (achievementId != null) 'achievementId': achievementId,
    };
  }

  String get unlockDescription {
    if (requirementType == UnlockRequirement.achievement &&
        achievementId != null) {
      return 'Desbloquea logro: $achievementId';
    }
    return requirementType.describe(requirementValue);
  }

  Avatar copyWith({
    String? id,
    String? name,
    String? emoji,
    AvatarRarity? rarity,
    UnlockRequirement? requirementType,
    int? requirementValue,
    String? achievementId,
  }) {
    return Avatar(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      rarity: rarity ?? this.rarity,
      requirementType: requirementType ?? this.requirementType,
      requirementValue: requirementValue ?? this.requirementValue,
      achievementId: achievementId ?? this.achievementId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Avatar && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Avatar(id: $id, name: $name, emoji: $emoji)';
}

/// Predefined avatars
class Avatars {
  // Common avatars (unlocked by default or low requirements)
  static const defaultAvatar = Avatar(
    id: 'default',
    name: 'Bufón Clásico',
    emoji: '🤡',
    rarity: AvatarRarity.common,
    requirementType: UnlockRequirement.level,
    requirementValue: 1,
  );

  static const smiley = Avatar(
    id: 'smiley',
    name: 'Sonriente',
    emoji: '😊',
    rarity: AvatarRarity.common,
    requirementType: UnlockRequirement.gamesPlayed,
    requirementValue: 1,
  );

  static const cool = Avatar(
    id: 'cool',
    name: 'Cool',
    emoji: '😎',
    rarity: AvatarRarity.common,
    requirementType: UnlockRequirement.level,
    requirementValue: 2,
  );

  // Rare avatars
  static const party = Avatar(
    id: 'party',
    name: 'Fiestero',
    emoji: '🥳',
    rarity: AvatarRarity.rare,
    requirementType: UnlockRequirement.gamesPlayed,
    requirementValue: 5,
  );

  static const genius = Avatar(
    id: 'genius',
    name: 'Genio',
    emoji: '🤓',
    rarity: AvatarRarity.rare,
    requirementType: UnlockRequirement.wins,
    requirementValue: 3,
  );

  static const devil = Avatar(
    id: 'devil',
    name: 'Diablillo',
    emoji: '😈',
    rarity: AvatarRarity.rare,
    requirementType: UnlockRequirement.votesReceived,
    requirementValue: 20,
  );

  // Epic avatars
  static const star = Avatar(
    id: 'star',
    name: 'Estrella',
    emoji: '⭐',
    rarity: AvatarRarity.epic,
    requirementType: UnlockRequirement.achievement,
    requirementValue: 1,
    achievementId: 'ten_games',
  );

  static const fire = Avatar(
    id: 'fire',
    name: 'Fuego',
    emoji: '🔥',
    rarity: AvatarRarity.epic,
    requirementType: UnlockRequirement.wins,
    requirementValue: 10,
  );

  static const robot = Avatar(
    id: 'robot',
    name: 'Robot',
    emoji: '🤖',
    rarity: AvatarRarity.epic,
    requirementType: UnlockRequirement.gamesPlayed,
    requirementValue: 25,
  );

  // Legendary avatars
  static const crown = Avatar(
    id: 'crown',
    name: 'Corona Real',
    emoji: '👑',
    rarity: AvatarRarity.legendary,
    requirementType: UnlockRequirement.achievement,
    requirementValue: 1,
    achievementId: 'twenty_wins',
  );

  static const diamond = Avatar(
    id: 'diamond',
    name: 'Diamante',
    emoji: '💎',
    rarity: AvatarRarity.legendary,
    requirementType: UnlockRequirement.level,
    requirementValue: 10,
  );

  static const nightPassAvatar = Avatar(
    id: 'night_pass',
    name: 'Luna VIP',
    emoji: '🌙',
    rarity: AvatarRarity.legendary,
    requirementType: UnlockRequirement.nightPass,
    requirementValue: 1,
  );

  /// Get all avatars
  static List<Avatar> get all => [
    defaultAvatar,
    smiley,
    cool,
    party,
    genius,
    devil,
    star,
    fire,
    robot,
    crown,
    diamond,
    nightPassAvatar,
  ];

  /// Get avatar by ID
  static Avatar? getById(String id) {
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get avatars by rarity
  static List<Avatar> getByRarity(AvatarRarity rarity) {
    return all.where((a) => a.rarity == rarity).toList();
  }
}
