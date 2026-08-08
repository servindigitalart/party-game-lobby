// functions/src/progression/services.ts
//
// Server-side progression. Every write here runs through the Admin SDK, so
// it bypasses firestore.rules by design — which is exactly why the rules can
// stay closed to clients.

// Modular entry point: with esModuleInterop the `admin.firestore.FieldValue`
// namespace shape resolves to undefined at runtime under firebase-admin v13.
import { FieldValue, Firestore } from 'firebase-admin/firestore';
import {
  ACHIEVEMENTS,
  ACHIEVEMENT_THRESHOLDS,
  AVATARS,
  TITLES,
  calculateLevel,
} from './catalog';

export interface PlayerResult {
  uid: string;
  nickname: string;
  isWinner: boolean;
  votesReceived: number;
}

export interface PlayerProgression {
  uid: string;
  xpGained: number;
  newLevel: number;
  leveledUp: boolean;
  newAchievements: string[];
  newAvatars: string[];
  newTitles: string[];
}

interface ProfileStats {
  xp: number;
  level: number;
  totalGames: number;
  totalWins: number;
  totalVotesReceived: number;
  unlockedAchievements: string[];
  unlockedAvatars: string[];
  selectedAvatar: string;
}

const DEFAULT_STATS: ProfileStats = {
  xp: 0,
  level: 1,
  totalGames: 0,
  totalWins: 0,
  totalVotesReceived: 0,
  unlockedAchievements: [],
  unlockedAvatars: ['default'],
  selectedAvatar: 'default',
};

/** Match award, mirroring ProgressionController.recordGameCompletion. */
export function matchXp(isWinner: boolean, votesReceived: number): number {
  return 10 + (isWinner ? 25 : 0) + votesReceived * 5;
}

/**
 * Applies one completed match to one player's profile.
 *
 * Stats, achievements and avatars are resolved in a single transaction: the
 * client version ran three sequential transactions, which meant a failure
 * between them left XP awarded and achievements unevaluated. Here it is all
 * or nothing.
 */
export class ProgressionService {
  constructor(private readonly db: Firestore) {}

  async applyMatch(
    player: PlayerResult
  ): Promise<Omit<PlayerProgression, 'newTitles'>> {
    const ref = this.db.collection('users').doc(player.uid);

    return this.db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const stats: ProfileStats = snap.exists
        ? { ...DEFAULT_STATS, ...(snap.data() as Partial<ProfileStats>) }
        : { ...DEFAULT_STATS };

      const previousLevel = stats.level;

      // 1. Match award.
      const gained = matchXp(player.isWinner, player.votesReceived);
      const next: ProfileStats = {
        ...stats,
        xp: stats.xp + gained,
        totalGames: stats.totalGames + 1,
        totalWins: stats.totalWins + (player.isWinner ? 1 : 0),
        totalVotesReceived: stats.totalVotesReceived + player.votesReceived,
      };

      // 2. Achievements, evaluated against the post-match stats.
      const newAchievements = AchievementService.evaluate(next);
      const achievementXp = newAchievements.reduce(
        (total, id) =>
          total + (ACHIEVEMENTS.find((a) => a.id === id)?.xpReward ?? 0),
        0
      );
      next.xp += achievementXp;
      next.unlockedAchievements = [
        ...next.unlockedAchievements,
        ...newAchievements,
      ];
      next.level = calculateLevel(next.xp);

      // 3. Avatars, which can depend on the level and achievements above.
      const newAvatars = AvatarService.evaluate(next);
      next.unlockedAvatars = [...next.unlockedAvatars, ...newAvatars];

      const payload = {
        uid: player.uid,
        xp: next.xp,
        level: next.level,
        totalGames: next.totalGames,
        totalWins: next.totalWins,
        totalVotesReceived: next.totalVotesReceived,
        unlockedAchievements: next.unlockedAchievements,
        unlockedAvatars: next.unlockedAvatars,
        selectedAvatar: next.selectedAvatar,
        lastPlayed: FieldValue.serverTimestamp(),
        ...(snap.exists
          ? {}
          : { createdAt: FieldValue.serverTimestamp() }),
      };

      // The client can never reach this branch: `allow create: if false`.
      tx.set(ref, payload, { merge: true });

      return {
        uid: player.uid,
        xpGained: gained + achievementXp,
        newLevel: next.level,
        leveledUp: next.level > previousLevel,
        newAchievements,
        newAvatars,
      };
    });
  }
}

export class AchievementService {
  static evaluate(stats: ProfileStats): string[] {
    const owned = new Set(stats.unlockedAchievements);
    return Object.entries(ACHIEVEMENT_THRESHOLDS)
      .filter(([id, rule]) => !owned.has(id) && stats[rule.stat] >= rule.value)
      .map(([id]) => id);
  }
}

export class AvatarService {
  static evaluate(stats: ProfileStats): string[] {
    const owned = new Set(stats.unlockedAvatars);
    const achievements = new Set(stats.unlockedAchievements);

    return AVATARS.filter((avatar) => {
      if (owned.has(avatar.id)) return false;
      switch (avatar.requirement) {
        case 'level':
          return stats.level >= avatar.value;
        case 'gamesPlayed':
          return stats.totalGames >= avatar.value;
        case 'wins':
          return stats.totalWins >= avatar.value;
        case 'votesReceived':
          return stats.totalVotesReceived >= avatar.value;
        case 'achievement':
          return avatar.achievementId
            ? achievements.has(avatar.achievementId)
            : false;
        // Granted by verifyNightPass, never by playing.
        case 'nightPass':
          return false;
      }
    }).map((avatar) => avatar.id);
  }
}

/**
 * Titles live in their own subcollection rather than on the profile, so they
 * are written after the profile transaction commits.
 */
export class TitleService {
  constructor(private readonly db: Firestore) {}

  async evaluate(uid: string): Promise<string[]> {
    const profileSnap = await this.db.collection('users').doc(uid).get();
    if (!profileSnap.exists) return [];
    const stats = {
      ...DEFAULT_STATS,
      ...(profileSnap.data() as Partial<ProfileStats>),
    };

    const unlockedSnap = await this.db
      .collection('users')
      .doc(uid)
      .collection('unlockedTitles')
      .get();
    const owned = new Set(unlockedSnap.docs.map((d) => d.id));
    const achievements = new Set(stats.unlockedAchievements);

    const newly = TITLES.filter((title) => {
      if (owned.has(title.id)) return false;
      switch (title.condition) {
        case 'xp':
          return stats.xp >= title.value;
        case 'wins':
          return stats.totalWins >= title.value;
        case 'votes':
          return stats.totalVotesReceived >= title.value;
        case 'games':
          return stats.totalGames >= title.value;
        case 'nightPass':
          return achievements.has('night_pass_purchase');
        case 'achievement':
          return title.achievementId
            ? achievements.has(title.achievementId)
            : false;
        // Rank titles are awarded by the season finalizer, which is the only
        // place a rank is authoritative. Secret titles have no rule yet.
        case 'leaderboardRank':
        case 'secret':
          return false;
      }
    });

    if (newly.length === 0) return [];

    const batch = this.db.batch();
    for (const title of newly) {
      batch.set(
        this.db
          .collection('users')
          .doc(uid)
          .collection('unlockedTitles')
          .doc(title.id),
        {
          titleId: title.id,
          rarity: title.rarity,
          source: 'milestone',
          unlockedAt: FieldValue.serverTimestamp(),
        }
      );
    }
    await batch.commit();

    return newly.map((t) => t.id);
  }
}

/**
 * Leaderboard entries.
 *
 * Paths keep the shape the client reads: a collection reference must have an
 * odd number of path segments, so weekly entries live at
 * `leaderboards/<type>/<week>/<uid>`.
 */
export class LeaderboardService {
  constructor(private readonly db: Firestore) {}

  static weekKey(now: Date): string {
    const target = new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())
    );
    // ISO-8601 week: Thursday decides the year.
    const day = (target.getUTCDay() + 6) % 7;
    target.setUTCDate(target.getUTCDate() - day + 3);
    const firstThursday = new Date(Date.UTC(target.getUTCFullYear(), 0, 4));
    const week =
      1 +
      Math.round(
        (target.getTime() - firstThursday.getTime()) / (7 * 24 * 3600 * 1000)
      );
    return `${target.getUTCFullYear()}-W${String(week).padStart(2, '0')}`;
  }

  async apply(
    player: PlayerResult,
    progression: Omit<PlayerProgression, 'newTitles'>,
    now: Date
  ): Promise<void> {
    const profileSnap = await this.db.collection('users').doc(player.uid).get();
    const profile = {
      ...DEFAULT_STATS,
      ...(profileSnap.data() as Partial<ProfileStats>),
    };
    const week = LeaderboardService.weekKey(now);
    const batch = this.db.batch();

    const identity = {
      uid: player.uid,
      nickname: player.nickname,
      avatarId: profile.selectedAvatar,
      level: profile.level,
      updatedAt: FieldValue.serverTimestamp(),
    };

    batch.set(
      this.db
        .collection('leaderboards')
        .doc('global_xp')
        .collection('entries')
        .doc(player.uid),
      { ...identity, xp: profile.xp },
      { merge: true }
    );

    const weekly: Array<[string, Record<string, unknown>]> = [
      ['weekly_xp', { xp: increment(progression.xpGained) }],
      ['weekly_wins', { totalWins: increment(player.isWinner ? 1 : 0) }],
      ['weekly_votes', { totalVotes: increment(player.votesReceived) }],
    ];

    for (const [type, stat] of weekly) {
      batch.set(
        this.db
          .collection('leaderboards')
          .doc(type)
          .collection(week)
          .doc(player.uid),
        { ...identity, ...stat },
        { merge: true }
      );
    }

    await batch.commit();
  }
}

function increment(by: number): FieldValue {
  return FieldValue.increment(by);
}
