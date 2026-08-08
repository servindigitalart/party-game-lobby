// functions/src/voting/submitVote.ts

import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import { getFirestore } from 'firebase-admin/firestore';

/**
 * Casts one vote.
 *
 * ## Why this exists
 *
 * Voting used to be a client-side Firestore transaction: the voter wrote
 * `votedFor` on their own player document and `score + 100` on the target's.
 * Firestore rules cannot express "these two writes must happen together",
 * so the score write had to be permitted on its own, guarded only by the
 * caller's own `votedFor` still being null.
 *
 * A client that simply never voted satisfied that guard forever and could
 * award +100 to anyone, unbounded. Because `onMatchCompleted` derives
 * `votesReceived` and `isWinner` from `score`, the forged score was laundered
 * into real XP, achievements, titles and leaderboard positions — signed by
 * the server. Reproduced at 10 writes → 1000 score → 85 forged XP.
 *
 * The fix is not a stricter rule. It is removing the client's ability to
 * write either field: both writes now happen here, in one Admin SDK
 * transaction, after the server has checked every precondition itself.
 *
 * ## Idempotency
 *
 * `votedFor` is the ledger. The transaction re-reads it and refuses if it is
 * already set, so a retried call, a double tap or a replayed request awards
 * nothing. Firestore transactions are atomic, so `votedFor` and `score` can
 * never disagree.
 */
export const submitVote = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesión para votar.');
  }

  const roomCode = request.data?.roomCode;
  const votedForId = request.data?.votedForId;

  if (typeof roomCode !== 'string' || typeof votedForId !== 'string') {
    throw new HttpsError('invalid-argument', 'Parámetros de voto inválidos.');
  }

  // Checked before any read: the client cannot be the source of this rule.
  if (votedForId === uid) {
    throw fail('SELF_VOTE_FORBIDDEN', 'No puedes votar por ti mismo.');
  }

  const db = getFirestore();
  const roomRef = db.collection('rooms').doc(roomCode);
  const voterRef = roomRef.collection('players').doc(uid);
  const targetRef = roomRef.collection('players').doc(votedForId);

  await db.runTransaction(async (tx) => {
    const [roomSnap, voterSnap, targetSnap] = await Promise.all([
      tx.get(roomRef),
      tx.get(voterRef),
      tx.get(targetRef),
    ]);

    if (!roomSnap.exists) {
      throw fail('ROOM_NOT_FOUND', 'La sala ya no existe.');
    }

    // Phase is server state: a client cannot vote outside the voting window
    // by lying about it, because it never tells us what the phase is.
    if (roomSnap.data()?.phase !== 'voting') {
      throw fail('INVALID_PHASE', 'La votación no está abierta.');
    }

    // Membership: the caller must actually be in this room. Their uid comes
    // from the verified auth token, never from the payload.
    if (!voterSnap.exists) {
      throw fail('VOTER_NOT_FOUND', 'No estás en esta sala.');
    }

    if (voterSnap.data()?.votedFor != null) {
      throw fail('ALREADY_VOTED', 'Ya has votado en esta ronda.');
    }

    if (!targetSnap.exists) {
      throw fail('VOTED_FOR_NOT_FOUND', 'Ese jugador no está en la sala.');
    }

    const answer = targetSnap.data()?.currentAnswer;
    if (typeof answer !== 'string' || answer.trim().length === 0) {
      throw fail(
        'VOTED_FOR_HAS_NO_ANSWER',
        'Esa persona no respondió esta ronda.'
      );
    }

    const currentScore = (targetSnap.data()?.score as number | undefined) ?? 0;

    // Both writes, one transaction. There is no state in which a vote is
    // recorded without its score, or a score without its vote.
    tx.update(voterRef, { votedFor: votedForId });
    tx.update(targetRef, { score: currentScore + VOTE_POINTS });
  });

  logger.info('Vote recorded', { roomCode, voter: uid });
  return { ok: true };
});

/** Points a single vote is worth. The only place this value is applied. */
const VOTE_POINTS = 100;

/**
 * Domain failures carry a stable code so the Flutter client can keep showing
 * the message it already shows for each case.
 */
function fail(code: string, message: string): HttpsError {
  return new HttpsError('failed-precondition', message, { code });
}
