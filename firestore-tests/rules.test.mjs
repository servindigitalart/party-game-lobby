// Firestore security rules tests for Bufón (Fase 2).
// Requires a Firestore emulator running on localhost:8080 (see firebase.json).
// Run with: firebase emulators:exec --only firestore "npm test" (from repo root)
// or manually: firebase emulators:start --only firestore, then `npm test` here.

import { readFileSync } from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, deleteDoc, getDoc } from 'firebase/firestore';

let testEnv;

const HOST = 'host-uid';
const P2 = 'player2-uid';
const OUTSIDER = 'outsider-uid';

function baseRoom(overrides = {}) {
  return {
    code: 'ABC123',
    hostId: HOST,
    phase: 'lobby',
    currentQuestionId: null,
    currentQuestionText: null,
    currentRound: 0,
    totalRounds: 5,
    roundStartTime: null,
    roundDuration: 90,
    createdAt: new Date().toISOString(),
    gamesPlayedToday: 0,
    adUnlocksRemaining: 0,
    nightPassExpiresAt: null,
    lastGameDate: null,
    ...overrides,
  };
}

function basePlayer(id, overrides = {}) {
  return {
    id,
    name: 'Player',
    score: 0,
    currentAnswer: null,
    votedFor: null,
    isHost: id === HOST,
    lastSeen: new Date().toISOString(),
    isOnline: true,
    ...overrides,
  };
}

async function seedRoom(roomCode, roomData, players) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'rooms', roomCode), roomData);
    for (const p of players) {
      await setDoc(doc(db, 'rooms', roomCode, 'players', p.id), p);
    }
  });
}

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-bufon',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      host: 'localhost',
      port: 8080,
    },
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
});

// --- Room create ---

test('room create: allowed when hostId is self and counters are zeroed', async () => {
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertSucceeds(setDoc(doc(db, 'rooms', 'ABC123'), baseRoom()));
});

test('room create: blocked when hostId is not the caller', async () => {
  const db = testEnv.authenticatedContext(OUTSIDER).firestore();
  await assertFails(setDoc(doc(db, 'rooms', 'ABC123'), baseRoom({ hostId: HOST })));
});

test('room create: blocked when gamesPlayedToday is not zero', async () => {
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertFails(
    setDoc(doc(db, 'rooms', 'ABC123'), baseRoom({ gamesPlayedToday: 3 })),
  );
});

// --- Room update: Night Pass fields ---

test('room update: blocked from writing nightPassExpiresAt directly', async () => {
  await seedRoom('ABC123', baseRoom(), [basePlayer(HOST)]);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertFails(
    updateDoc(doc(db, 'rooms', 'ABC123'), {
      nightPassExpiresAt: new Date().toISOString(),
    }),
  );
});

// --- Room update: hostId takeover ---

test('room update: blocked from handing hostId to a non-player (room hijack)', async () => {
  await seedRoom('ABC123', baseRoom(), [basePlayer(HOST)]);
  const db = testEnv.authenticatedContext(OUTSIDER).firestore();
  await assertFails(
    updateDoc(doc(db, 'rooms', 'ABC123'), { hostId: OUTSIDER }),
  );
});

test('room update: allowed to hand hostId to an existing player (disconnection reassignment)', async () => {
  await seedRoom('ABC123', baseRoom(), [basePlayer(HOST), basePlayer(P2)]);
  const db = testEnv.authenticatedContext(P2).firestore();
  await assertSucceeds(
    updateDoc(doc(db, 'rooms', 'ABC123'), { hostId: P2 }),
  );
});

// --- Room update: gamesPlayedToday delta ---

test('room update: blocked from resetting gamesPlayedToday to 0 without changing lastGameDate (paywall bypass)', async () => {
  await seedRoom(
    'ABC123',
    baseRoom({ gamesPlayedToday: 3, lastGameDate: '2026-01-01' }),
    [basePlayer(HOST)],
  );
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertFails(
    updateDoc(doc(db, 'rooms', 'ABC123'), { gamesPlayedToday: 0 }),
  );
});

test('room update: allowed to reset gamesPlayedToday on a real day rollover', async () => {
  await seedRoom(
    'ABC123',
    baseRoom({ gamesPlayedToday: 3, lastGameDate: '2026-01-01' }),
    [basePlayer(HOST)],
  );
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertSucceeds(
    updateDoc(doc(db, 'rooms', 'ABC123'), {
      gamesPlayedToday: 0,
      lastGameDate: '2026-01-02',
    }),
  );
});

test('room update: allowed to increment gamesPlayedToday by exactly 1', async () => {
  await seedRoom(
    'ABC123',
    baseRoom({ gamesPlayedToday: 1, lastGameDate: '2026-01-01' }),
    [basePlayer(HOST)],
  );
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertSucceeds(
    updateDoc(doc(db, 'rooms', 'ABC123'), {
      gamesPlayedToday: 2,
      lastGameDate: '2026-01-01',
    }),
  );
});

test('room update: blocked from jumping gamesPlayedToday by more than 1', async () => {
  await seedRoom(
    'ABC123',
    baseRoom({ gamesPlayedToday: 1, lastGameDate: '2026-01-01' }),
    [basePlayer(HOST)],
  );
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertFails(
    updateDoc(doc(db, 'rooms', 'ABC123'), { gamesPlayedToday: 99 }),
  );
});

// --- Room update: adUnlocksRemaining delta ---

test('room update: blocked from setting adUnlocksRemaining to an arbitrary large value', async () => {
  await seedRoom('ABC123', baseRoom({ adUnlocksRemaining: 0 }), [basePlayer(HOST)]);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertFails(
    updateDoc(doc(db, 'rooms', 'ABC123'), { adUnlocksRemaining: 999 }),
  );
});

test('room update: allowed to grant one ad unlock (+1)', async () => {
  await seedRoom('ABC123', baseRoom({ adUnlocksRemaining: 0 }), [basePlayer(HOST)]);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertSucceeds(
    updateDoc(doc(db, 'rooms', 'ABC123'), { adUnlocksRemaining: 1 }),
  );
});

test('room update: allowed to consume one ad unlock (-1)', async () => {
  await seedRoom('ABC123', baseRoom({ adUnlocksRemaining: 1 }), [basePlayer(HOST)]);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertSucceeds(
    updateDoc(doc(db, 'rooms', 'ABC123'), { adUnlocksRemaining: 0 }),
  );
});

// --- Player create ---

test('player create: allowed to create your own doc with score 0', async () => {
  await seedRoom('ABC123', baseRoom(), []);
  const db = testEnv.authenticatedContext(P2).firestore();
  await assertSucceeds(
    setDoc(doc(db, 'rooms', 'ABC123', 'players', P2), basePlayer(P2)),
  );
});

test('player create: blocked from creating a doc for someone else', async () => {
  await seedRoom('ABC123', baseRoom(), []);
  const db = testEnv.authenticatedContext(OUTSIDER).firestore();
  await assertFails(
    setDoc(doc(db, 'rooms', 'ABC123', 'players', P2), basePlayer(P2)),
  );
});

test('player create: blocked from joining with a non-zero starting score', async () => {
  await seedRoom('ABC123', baseRoom(), []);
  const db = testEnv.authenticatedContext(P2).firestore();
  await assertFails(
    setDoc(doc(db, 'rooms', 'ABC123', 'players', P2), basePlayer(P2, { score: 500 })),
  );
});

// --- Player update: answers ---

test('player update: allowed to submit your own answer once', async () => {
  await seedRoom('ABC123', baseRoom({ phase: 'answering' }), [
    basePlayer(HOST),
  ]);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertSucceeds(
    updateDoc(doc(db, 'rooms', 'ABC123', 'players', HOST), {
      currentAnswer: 'una respuesta chistosa',
    }),
  );
});

test('player update: blocked from overwriting an already-submitted answer', async () => {
  await seedRoom('ABC123', baseRoom({ phase: 'answering' }), [
    basePlayer(HOST, { currentAnswer: 'ya respondí' }),
  ]);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertFails(
    updateDoc(doc(db, 'rooms', 'ABC123', 'players', HOST), {
      currentAnswer: 'cambio de opinión',
    }),
  );
});

test('player update: blocked from writing another player\'s answer', async () => {
  await seedRoom('ABC123', baseRoom({ phase: 'answering' }), [
    basePlayer(HOST),
    basePlayer(P2),
  ]);
  const db = testEnv.authenticatedContext(P2).firestore();
  await assertFails(
    updateDoc(doc(db, 'rooms', 'ABC123', 'players', HOST), {
      currentAnswer: 'inyectada por otro jugador',
    }),
  );
});

// --- Player update: votes ---

test('player update: allowed to cast your own vote for someone else', async () => {
  await seedRoom('ABC123', baseRoom({ phase: 'voting' }), [
    basePlayer(HOST, { currentAnswer: 'algo' }),
    basePlayer(P2),
  ]);
  const db = testEnv.authenticatedContext(P2).firestore();
  await assertSucceeds(
    updateDoc(doc(db, 'rooms', 'ABC123', 'players', P2), { votedFor: HOST }),
  );
});

test('player update: blocked from voting for yourself', async () => {
  await seedRoom('ABC123', baseRoom({ phase: 'voting' }), [basePlayer(HOST)]);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertFails(
    updateDoc(doc(db, 'rooms', 'ABC123', 'players', HOST), { votedFor: HOST }),
  );
});

test('player update: blocked from voting twice', async () => {
  await seedRoom('ABC123', baseRoom({ phase: 'voting' }), [
    basePlayer(HOST, { votedFor: P2 }),
    basePlayer(P2),
  ]);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertFails(
    updateDoc(doc(db, 'rooms', 'ABC123', 'players', HOST), { votedFor: P2 }),
  );
});

// --- Player update: score ---

test('player update: allowed for the voter to award exactly +100 to the voted-for player', async () => {
  await seedRoom('ABC123', baseRoom({ phase: 'voting' }), [
    basePlayer(HOST, { score: 0 }),
    basePlayer(P2),
  ]);
  const db = testEnv.authenticatedContext(P2).firestore();
  await assertSucceeds(
    updateDoc(doc(db, 'rooms', 'ABC123', 'players', HOST), { score: 100 }),
  );
});

test('player update: blocked from awarding yourself points', async () => {
  await seedRoom('ABC123', baseRoom({ phase: 'voting' }), [
    basePlayer(HOST, { score: 0 }),
  ]);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertFails(
    updateDoc(doc(db, 'rooms', 'ABC123', 'players', HOST), { score: 100 }),
  );
});

test('player update: blocked from awarding an arbitrary (non +100) score jump', async () => {
  await seedRoom('ABC123', baseRoom({ phase: 'voting' }), [
    basePlayer(HOST, { score: 0 }),
    basePlayer(P2),
  ]);
  const db = testEnv.authenticatedContext(P2).firestore();
  await assertFails(
    updateDoc(doc(db, 'rooms', 'ABC123', 'players', HOST), { score: 999999 }),
  );
});

test('player update: blocked from awarding a second +100 to a different target after already voting', async () => {
  // P2 already voted for HOST (score already awarded in that same original
  // transaction). A malicious client now tries a second, separate call
  // awarding +100 to a third player without going through submitVoteTransaction.
  const P3 = 'player3-uid';
  await seedRoom('ABC123', baseRoom({ phase: 'voting' }), [
    basePlayer(HOST, { score: 100 }),
    basePlayer(P2, { votedFor: HOST }),
    basePlayer(P3, { score: 0 }),
  ]);
  const db = testEnv.authenticatedContext(P2).firestore();
  await assertFails(
    updateDoc(doc(db, 'rooms', 'ABC123', 'players', P3), { score: 100 }),
  );
});

test('player update: a same-value replay of an already-cast vote does not slip through another rule branch', async () => {
  await seedRoom('ABC123', baseRoom({ phase: 'voting' }), [
    basePlayer(HOST, { votedFor: P2 }),
    basePlayer(P2),
  ]);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertFails(
    updateDoc(doc(db, 'rooms', 'ABC123', 'players', HOST), { votedFor: P2 }),
  );
});

// --- Player update: round reset ---

test('player update: allowed to clear another player\'s round fields during roundResult', async () => {
  await seedRoom('ABC123', baseRoom({ phase: 'roundResult' }), [
    basePlayer(HOST, { currentAnswer: 'algo', votedFor: P2 }),
    basePlayer(P2),
  ]);
  const db = testEnv.authenticatedContext(P2).firestore();
  await assertSucceeds(
    updateDoc(doc(db, 'rooms', 'ABC123', 'players', HOST), {
      currentAnswer: null,
      votedFor: null,
    }),
  );
});

test('player update: blocked from clearing another player\'s answer outside roundResult (griefing)', async () => {
  await seedRoom('ABC123', baseRoom({ phase: 'answering' }), [
    basePlayer(HOST, { currentAnswer: 'algo' }),
    basePlayer(P2),
  ]);
  const db = testEnv.authenticatedContext(P2).firestore();
  await assertFails(
    updateDoc(doc(db, 'rooms', 'ABC123', 'players', HOST), {
      currentAnswer: null,
      votedFor: null,
    }),
  );
});

test('player update: blocked from clearing an outsider\'s round fields (not a room member)', async () => {
  await seedRoom('ABC123', baseRoom({ phase: 'roundResult' }), [
    basePlayer(HOST, { currentAnswer: 'algo' }),
  ]);
  const db = testEnv.authenticatedContext(OUTSIDER).firestore();
  await assertFails(
    updateDoc(doc(db, 'rooms', 'ABC123', 'players', HOST), {
      currentAnswer: null,
      votedFor: null,
    }),
  );
});

// --- Player delete ---

test('player delete: allowed by a current room member (cleanupDisconnectedPlayers)', async () => {
  await seedRoom('ABC123', baseRoom(), [basePlayer(HOST), basePlayer(P2)]);
  const db = testEnv.authenticatedContext(P2).firestore();
  await assertSucceeds(deleteDoc(doc(db, 'rooms', 'ABC123', 'players', HOST)));
});

test('player delete: blocked for someone who was never in the room', async () => {
  await seedRoom('ABC123', baseRoom(), [basePlayer(HOST)]);
  const db = testEnv.authenticatedContext(OUTSIDER).firestore();
  await assertFails(deleteDoc(doc(db, 'rooms', 'ABC123', 'players', HOST)));
});

// --- Sanity: unauthenticated is always blocked ---

test('unauthenticated: cannot read or write rooms', async () => {
  await seedRoom('ABC123', baseRoom(), [basePlayer(HOST)]);
  const db = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, 'rooms', 'ABC123')));
});
