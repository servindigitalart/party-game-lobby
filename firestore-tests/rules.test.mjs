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

test('player update: casting a vote is server-only (was: allowed)', async () => {
  // This test used to assert that a client could write its own `votedFor`.
  // That capability was removed with Security Hotfix B1: `votedFor` and
  // `score` are written together by the `submitVote` callable, because rules
  // cannot require two document writes to happen as one.
  await seedRoom('ABC123', baseRoom({ phase: 'voting' }), [
    basePlayer(HOST, { currentAnswer: 'algo' }),
    basePlayer(P2),
  ]);
  const db = testEnv.authenticatedContext(P2).firestore();
  await assertFails(
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

test('player update: awarding points is server-only (was: allowed +100)', async () => {
  // The +100 award used to be permitted on its own, guarded only by the
  // caller's own votedFor still being null — which a client that never voted
  // satisfied forever. That was exploit B1. No client-writable path to
  // `score` remains.
  await seedRoom('ABC123', baseRoom({ phase: 'voting' }), [
    basePlayer(HOST, { score: 0 }),
    basePlayer(P2),
  ]);
  const db = testEnv.authenticatedContext(P2).firestore();
  await assertFails(
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

// ---------------------------------------------------------------------------
// Progression is server-authoritative (Backend Infrastructure Phase 1).
//
// Every one of these is an attempt a modified client could actually make.
// ---------------------------------------------------------------------------

async function seedProfile(uid, overrides = {}) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users', uid), {
      uid,
      xp: 100,
      level: 2,
      totalGames: 3,
      totalWins: 1,
      totalVotesReceived: 5,
      unlockedAchievements: ['first_game'],
      unlockedAvatars: ['default', 'smiley'],
      selectedAvatar: 'default',
      ...overrides,
    });
  });
}

test('profile: a player cannot grant itself XP', async () => {
  await seedProfile(HOST);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertFails(updateDoc(doc(db, 'users', HOST), { xp: 999999 }));
});

test('profile: a player cannot grant itself wins or games', async () => {
  await seedProfile(HOST);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertFails(updateDoc(doc(db, 'users', HOST), { totalWins: 100 }));
  await assertFails(updateDoc(doc(db, 'users', HOST), { totalGames: 100 }));
  await assertFails(
    updateDoc(doc(db, 'users', HOST), { totalVotesReceived: 100 })
  );
});

test('profile: a player cannot grant itself a level', async () => {
  await seedProfile(HOST);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertFails(updateDoc(doc(db, 'users', HOST), { level: 99 }));
});

test('profile: a player cannot grant itself achievements or avatars', async () => {
  await seedProfile(HOST);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertFails(
    updateDoc(doc(db, 'users', HOST), {
      unlockedAchievements: ['first_game', 'twenty_wins'],
    })
  );
  await assertFails(
    updateDoc(doc(db, 'users', HOST), {
      unlockedAvatars: ['default', 'smiley', 'diamond'],
    })
  );
});

test('profile: a player cannot create its own profile', async () => {
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertFails(setDoc(doc(db, 'users', HOST), { uid: HOST, xp: 5000 }));
});

test('profile: selecting an owned avatar is allowed', async () => {
  await seedProfile(HOST);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertSucceeds(
    updateDoc(doc(db, 'users', HOST), { selectedAvatar: 'smiley' })
  );
});

test('profile: selecting an avatar the server never granted is blocked', async () => {
  await seedProfile(HOST);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertFails(
    updateDoc(doc(db, 'users', HOST), { selectedAvatar: 'diamond' })
  );
});

test('profile: equipping a title the server never granted is blocked', async () => {
  await seedProfile(HOST);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertFails(
    updateDoc(doc(db, 'users', HOST), { equippedTitleId: 'bufon_supremo' })
  );
});

test('profile: equipping a granted title is allowed, unequipping always is', async () => {
  await seedProfile(HOST);
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(
      doc(ctx.firestore(), 'users', HOST, 'unlockedTitles', 'npc_grupo'),
      { titleId: 'npc_grupo', rarity: 'common', source: 'milestone' }
    );
  });

  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertSucceeds(
    updateDoc(doc(db, 'users', HOST), { equippedTitleId: 'npc_grupo' })
  );
  await assertSucceeds(
    updateDoc(doc(db, 'users', HOST), { equippedTitleId: null })
  );
});

test('profile: a player cannot write another player profile', async () => {
  await seedProfile(P2);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertFails(
    updateDoc(doc(db, 'users', P2), { selectedAvatar: 'smiley' })
  );
});

test('titles: a player cannot write its own unlockedTitles', async () => {
  await seedProfile(HOST);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertFails(
    setDoc(doc(db, 'users', HOST, 'unlockedTitles', 'bufon_supremo'), {
      titleId: 'bufon_supremo',
    })
  );
});

test('leaderboards: readable but never client-writable', async () => {
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertSucceeds(
    getDoc(doc(db, 'leaderboards', 'global_xp', 'entries', HOST))
  );
  await assertFails(
    setDoc(doc(db, 'leaderboards', 'global_xp', 'entries', HOST), { xp: 99999 })
  );
});

test('leaderboards: weekly boards are readable and never client-writable', async () => {
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertSucceeds(
    getDoc(doc(db, 'leaderboards', 'weekly_xp', '2026-W01', HOST))
  );
  await assertFails(
    setDoc(doc(db, 'leaderboards', 'weekly_xp', '2026-W01', HOST), { xp: 1 })
  );
});

test('matchCompletions: the idempotency ledger is invisible to clients', async () => {
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertFails(getDoc(doc(db, 'matchCompletions', 'ABC123')));
  await assertFails(
    setDoc(doc(db, 'matchCompletions', 'ABC123'), { status: 'completed' })
  );
});

// ---------------------------------------------------------------------------
// Voting is server-authoritative (Security Hotfix B1).
//
// The exploit: a client that never voted could replay `score + 100` on
// another player's document forever, because Firestore rules cannot require
// the paired `votedFor` write to happen with it. onMatchCompleted then
// derived votes, wins and XP from that forged score.
// ---------------------------------------------------------------------------

async function seedVotingRoom() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'rooms', 'VOTE01'), {
      code: 'VOTE01',
      hostId: HOST,
      phase: 'voting',
      currentRound: 1,
    });
    for (const id of [HOST, P2, OUTSIDER]) {
      await setDoc(doc(db, 'rooms', 'VOTE01', 'players', id), {
        id,
        name: id,
        score: 0,
        currentAnswer: 'una respuesta',
        votedFor: null,
        isOnline: true,
        isHost: id === HOST,
      });
    }
  });
}

test('B1 EXPLOIT: pumping another player score is now impossible', async () => {
  await seedVotingRoom();
  const db = testEnv.authenticatedContext(HOST).firestore();

  // The exact write that used to succeed ten times in a row.
  await assertFails(
    updateDoc(doc(db, 'rooms', 'VOTE01', 'players', P2), { score: 100 })
  );
});

test('B1: score cannot be written even alongside a legitimate vote', async () => {
  await seedVotingRoom();
  const db = testEnv.authenticatedContext(HOST).firestore();

  await assertFails(
    updateDoc(doc(db, 'rooms', 'VOTE01', 'players', P2), {
      score: 100,
      votedFor: null,
    })
  );
});

test('B1: a player cannot write score on their own document', async () => {
  await seedVotingRoom();
  const db = testEnv.authenticatedContext(HOST).firestore();

  await assertFails(
    updateDoc(doc(db, 'rooms', 'VOTE01', 'players', HOST), { score: 9999 })
  );
});

test('B1: a player can no longer write votedFor at all', async () => {
  await seedVotingRoom();
  const db = testEnv.authenticatedContext(HOST).firestore();

  // Marking yourself as having voted was the other half of the old flow.
  await assertFails(
    updateDoc(doc(db, 'rooms', 'VOTE01', 'players', HOST), { votedFor: P2 })
  );
});

test('B1: creating a player with a non-zero score is still rejected', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'rooms', 'VOTE02'), {
      code: 'VOTE02',
      hostId: HOST,
      phase: 'lobby',
      currentRound: 0,
    });
  });

  const db = testEnv.authenticatedContext(P2).firestore();
  await assertFails(
    setDoc(doc(db, 'rooms', 'VOTE02', 'players', P2), {
      id: P2,
      name: 'cheater',
      score: 5000,
      currentAnswer: null,
      votedFor: null,
    })
  );
});

test('B1: the round reset still works and grants no score', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'rooms', 'VOTE03'), {
      code: 'VOTE03',
      hostId: HOST,
      phase: 'roundResult',
      currentRound: 1,
    });
    for (const id of [HOST, P2]) {
      await setDoc(doc(db, 'rooms', 'VOTE03', 'players', id), {
        id,
        name: id,
        score: 100,
        currentAnswer: 'x',
        votedFor: P2,
        isOnline: true,
      });
    }
  });

  const db = testEnv.authenticatedContext(HOST).firestore();

  // Clearing is allowed...
  await assertSucceeds(
    updateDoc(doc(db, 'rooms', 'VOTE03', 'players', HOST), {
      currentAnswer: null,
      votedFor: null,
    })
  );

  // ...but it cannot smuggle a score change along with it.
  await assertFails(
    updateDoc(doc(db, 'rooms', 'VOTE03', 'players', P2), {
      currentAnswer: null,
      votedFor: null,
      score: 500,
    })
  );
});

// ---------------------------------------------------------------------------
// R-20 Package 2 — host player removal and the room-scoped rejoin bar.
//
// `removedPlayerIds` is the list `joinRoom` refuses, which makes it the one
// field in the room document that must not be writable by the person it
// names. These tests are the security boundary: without them the guard is a
// client-side suggestion, and the copy that describes it would be untrue.
// ---------------------------------------------------------------------------

test('removedPlayerIds: the host may append a uid', async () => {
  await seedRoom('RM0001', baseRoom(), [basePlayer(HOST), basePlayer(P2)]);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertSucceeds(
    updateDoc(doc(db, 'rooms', 'RM0001'), { removedPlayerIds: [P2] }),
  );
});

test('removedPlayerIds: a non-host member cannot append', async () => {
  await seedRoom('RM0002', baseRoom(), [basePlayer(HOST), basePlayer(P2)]);
  const db = testEnv.authenticatedContext(P2).firestore();
  await assertFails(
    updateDoc(doc(db, 'rooms', 'RM0002'), { removedPlayerIds: [HOST] }),
  );
});

test('removedPlayerIds: an outsider cannot append', async () => {
  await seedRoom('RM0003', baseRoom(), [basePlayer(HOST), basePlayer(P2)]);
  const db = testEnv.authenticatedContext(OUTSIDER).firestore();
  await assertFails(
    updateDoc(doc(db, 'rooms', 'RM0003'), { removedPlayerIds: [P2] }),
  );
});

test('removedPlayerIds: the removed player cannot clear their own uid', async () => {
  // The attack the whole rule exists for. P2 has been removed; if they can
  // rewrite the list to [], joinRoom lets them straight back in.
  await seedRoom('RM0004', baseRoom({ removedPlayerIds: [P2] }), [
    basePlayer(HOST),
  ]);
  const db = testEnv.authenticatedContext(P2).firestore();
  await assertFails(
    updateDoc(doc(db, 'rooms', 'RM0004'), { removedPlayerIds: [] }),
  );
});

test('removedPlayerIds: not even the host may drop an existing entry', async () => {
  // Append-only. A host who could shorten the list could also be talked into
  // shortening it, and the guarantee would depend on their judgement.
  await seedRoom('RM0005', baseRoom({ removedPlayerIds: [P2, OUTSIDER] }), [
    basePlayer(HOST),
  ]);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertFails(
    updateDoc(doc(db, 'rooms', 'RM0005'), { removedPlayerIds: [P2] }),
  );
});

test('removedPlayerIds: the host may append to an existing list', async () => {
  await seedRoom('RM0006', baseRoom({ removedPlayerIds: [P2] }), [
    basePlayer(HOST),
  ]);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertSucceeds(
    updateDoc(doc(db, 'rooms', 'RM0006'), {
      removedPlayerIds: [P2, OUTSIDER],
    }),
  );
});

test('removedPlayerIds: a room written before the field existed still accepts a first removal', async () => {
  // `resource.data.get('removedPlayerIds', [])` is what makes this evaluate
  // rather than error on a document that has no such key.
  const legacy = baseRoom();
  delete legacy.removedPlayerIds;
  await seedRoom('RM0007', legacy, [basePlayer(HOST), basePlayer(P2)]);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertSucceeds(
    updateDoc(doc(db, 'rooms', 'RM0007'), { removedPlayerIds: [P2] }),
  );
});

test('removedPlayerIds: the host may remove a player and decrement the count together', async () => {
  // The shape RoomRepository.removePlayer actually writes.
  await seedRoom('RM0008', baseRoom({ playerCount: 3 }), [
    basePlayer(HOST),
    basePlayer(P2),
  ]);
  const db = testEnv.authenticatedContext(HOST).firestore();
  await assertSucceeds(
    updateDoc(doc(db, 'rooms', 'RM0008'), {
      playerCount: 2,
      removedPlayerIds: [P2],
    }),
  );
});

test('removedPlayerIds: a non-host cannot smuggle it alongside a legitimate field', async () => {
  await seedRoom('RM0009', baseRoom({ playerCount: 3 }), [
    basePlayer(HOST),
    basePlayer(P2),
  ]);
  const db = testEnv.authenticatedContext(P2).firestore();
  await assertFails(
    updateDoc(doc(db, 'rooms', 'RM0009'), {
      playerCount: 2,
      removedPlayerIds: [HOST],
    }),
  );
});
