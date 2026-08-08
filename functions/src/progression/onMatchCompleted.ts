// functions/src/progression/onMatchCompleted.ts

import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions';
import { FieldValue, Firestore, getFirestore } from 'firebase-admin/firestore';
import {
  LeaderboardService,
  PlayerResult,
  ProgressionService,
  TitleService,
} from './services';

/**
 * Awards progression when a room reaches `finalWinner`.
 *
 * ## Why a trigger and not a callable
 *
 * A callable would let a client decide when — and how often — progression
 * runs, and with what numbers. The trigger reads the room document that
 * Firestore rules already control, so the only thing a client can influence
 * is the game state itself, which the room rules already guard.
 *
 * ## Idempotency
 *
 * Firestore triggers are at-least-once: the same transition can be delivered
 * more than once, and a retried function invocation is normal. Progression
 * increments XP and win counts, so a second run would double them.
 *
 * Written against the v2 API: firebase-functions v7 removed
 * `functions.config()`, which the emulator's v1 runtime calls while loading
 * a v1 trigger, so v1 triggers cannot execute at all under this version.
 *
 * The guard is a `matchCompletions/{roomCode}` document claimed inside a
 * transaction with `create`, which fails if the document already exists.
 * That is atomic in Firestore and survives process restarts, unlike the
 * in-memory set the client used. The claim is written *before* any award, so
 * a crash mid-way leaves the match claimed and un-retried: a partially
 * applied progression is preferable to a doubled one, and the claim document
 * records what happened for a manual replay.
 */
export const onMatchCompleted = onDocumentUpdated(
  'rooms/{roomCode}',
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const roomCode = event.params.roomCode;

    if (before?.phase === 'finalWinner' || after?.phase !== 'finalWinner') {
      return;
    }

    const db = getFirestore();
    const claimRef = db.collection('matchCompletions').doc(roomCode);

    const claimed = await db.runTransaction(async (tx) => {
      const existing = await tx.get(claimRef);
      if (existing.exists) return false;
      tx.create(claimRef, {
        roomCode,
        eventId: event.id,
        claimedAt: FieldValue.serverTimestamp(),
        status: 'processing',
      });
      return true;
    });

    if (!claimed) {
      logger.info('Match already processed, skipping', { roomCode });
      return;
    }

    try {
      const players = await readPlayers(db, roomCode);

      if (players.length === 0) {
        await claimRef.update({ status: 'skipped_no_players' });
        return;
      }

      const progression = new ProgressionService(db);
      const titles = new TitleService(db);
      const leaderboards = new LeaderboardService(db);
      const now = new Date();

      const results = [];
      for (const player of players) {
        // Sequential on purpose: these are separate players but they share
        // leaderboard documents, and a batch of parallel transactions on the
        // same documents just means contention and retries.
        const applied = await progression.applyMatch(player);
        const newTitles = await titles.evaluate(player.uid);
        await leaderboards.apply(player, applied, now);
        results.push({ ...applied, newTitles });
      }

      await claimRef.update({
        status: 'completed',
        completedAt: FieldValue.serverTimestamp(),
        playerCount: players.length,
        // A compact record of what each player actually received, so a
        // dispute can be answered without replaying the match.
        awards: results.map((r) => ({
          uid: r.uid,
          xpGained: r.xpGained,
          newLevel: r.newLevel,
          achievements: r.newAchievements,
          avatars: r.newAvatars,
          titles: r.newTitles,
        })),
      });

      logger.info('Progression applied', {
        roomCode,
        playerCount: players.length,
      });
    } catch (error) {
      // The match itself stands; only the awards failed. The claim stays so
      // a retry cannot double-award, and `status` says why.
      logger.error('Progression failed', {
        roomCode,
        error: error instanceof Error ? error.message : String(error),
      });
      await claimRef.update({
        status: 'failed',
        failedAt: FieldValue.serverTimestamp(),
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }
);

/**
 * Builds each player's result from the room's own data.
 *
 * `score` is the only trustworthy vote total: `submitVoteTransaction` adds
 * 100 per vote under rules that forbid a client writing its own score, and
 * `votedFor` is cleared every round.
 */
async function readPlayers(
  db: Firestore,
  roomCode: string
): Promise<PlayerResult[]> {
  const snap = await db
    .collection('rooms')
    .doc(roomCode)
    .collection('players')
    .get();

  const players = snap.docs.map((doc) => {
    const data = doc.data();
    return {
      uid: doc.id,
      nickname: (data.name as string | undefined) ?? 'Jugador',
      score: (data.score as number | undefined) ?? 0,
    };
  });

  if (players.length === 0) return [];

  const topScore = Math.max(...players.map((p) => p.score));

  return players.map((p) => ({
    uid: p.uid,
    nickname: p.nickname,
    // Ties award the win to everyone tied, rather than to whichever
    // document Firestore happened to return first.
    isWinner: p.score > 0 && p.score === topScore,
    votesReceived: Math.floor(p.score / 100),
  }));
}
