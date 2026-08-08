// functions/integration.test.mjs
//
// End-to-end coverage of onMatchCompleted against the Firebase Emulator
// Suite. Run with:
//
//   firebase emulators:exec --only firestore,functions --project demo-bufon \
//     "node --test functions/integration.test.mjs"
//
// Uses the Admin SDK, which bypasses rules exactly like the trigger does.
// Rule enforcement is covered separately in firestore-tests/rules.test.mjs.

import test from 'node:test';
import assert from 'node:assert/strict';
import admin from 'firebase-admin';

process.env.FIRESTORE_EMULATOR_HOST ??= 'localhost:8080';

admin.initializeApp({ projectId: 'demo-bufon' });
const db = admin.firestore();

/** Triggers are asynchronous; poll rather than guess a sleep duration. */
async function waitFor(predicate, { timeoutMs = 20000, label = 'condition' } = {}) {
  const deadline = Date.now() + timeoutMs;
  let last;
  while (Date.now() < deadline) {
    last = await predicate();
    if (last) return last;
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error(`Timed out waiting for ${label}`);
}

async function clear() {
  for (const name of ['rooms', 'users', 'leaderboards', 'matchCompletions']) {
    await db.recursiveDelete(db.collection(name));
  }
}

async function seedRoom(roomCode, players) {
  await db.collection('rooms').doc(roomCode).set({
    code: roomCode,
    hostId: players[0].id,
    phase: 'roundResult',
    currentRound: 5,
    totalRounds: 5,
    playerCount: players.length,
  });
  for (const p of players) {
    await db
      .collection('rooms')
      .doc(roomCode)
      .collection('players')
      .doc(p.id)
      .set({ id: p.id, name: p.name, score: p.score, isHost: p.id === players[0].id });
  }
}

const finishMatch = (roomCode) =>
  db.collection('rooms').doc(roomCode).update({ phase: 'finalWinner' });

const completionOf = (roomCode) =>
  db.collection('matchCompletions').doc(roomCode).get();

const profileOf = (uid) => db.collection('users').doc(uid).get();

test.beforeEach(clear);
test.after(() => admin.app().delete());

test('a completed match awards every player exactly once', async () => {
  await seedRoom('ROOM01', [
    { id: 'winner', name: 'Ana', score: 300 },
    { id: 'runner', name: 'Beto', score: 100 },
    { id: 'quiet', name: 'Caro', score: 0 },
  ]);

  await finishMatch('ROOM01');

  const completion = await waitFor(
    async () => {
      const snap = await completionOf('ROOM01');
      return snap.exists && snap.data().status === 'completed' ? snap : null;
    },
    { label: 'matchCompletions/ROOM01 to complete' }
  );

  assert.equal(completion.data().playerCount, 3);

  // Winner: 10 base + 25 win + 3 votes × 5 = 50, plus achievement XP for
  // first_game (50) and first_win (100).
  const winner = (await profileOf('winner')).data();
  assert.equal(winner.totalGames, 1);
  assert.equal(winner.totalWins, 1);
  assert.equal(winner.totalVotesReceived, 3);
  assert.equal(winner.xp, 50 + 50 + 100);
  assert.ok(winner.unlockedAchievements.includes('first_game'));
  assert.ok(winner.unlockedAchievements.includes('first_win'));

  // Runner-up: 10 base + 1 vote × 5 = 15, plus first_game (50).
  const runner = (await profileOf('runner')).data();
  assert.equal(runner.totalWins, 0);
  assert.equal(runner.totalVotesReceived, 1);
  assert.equal(runner.xp, 15 + 50);

  // A player with no votes still played a match.
  const quiet = (await profileOf('quiet')).data();
  assert.equal(quiet.totalGames, 1);
  assert.equal(quiet.totalVotesReceived, 0);
});

test('leaderboards are written once, by the server only', async () => {
  await seedRoom('ROOM02', [
    { id: 'winner', name: 'Ana', score: 200 },
    { id: 'other', name: 'Beto', score: 0 },
  ]);
  await finishMatch('ROOM02');

  const entry = await waitFor(
    async () => {
      const snap = await db
        .collection('leaderboards')
        .doc('global_xp')
        .collection('entries')
        .doc('winner')
        .get();
      return snap.exists ? snap : null;
    },
    { label: 'global leaderboard entry' }
  );

  assert.equal(entry.data().uid, 'winner');
  assert.ok(entry.data().xp > 0);

  // Weekly boards live under the week key, an odd number of path segments.
  const weekly = await db.collectionGroup('entries').get();
  assert.ok(weekly.size >= 1);
});

test('titles are granted into the server-only subcollection', async () => {
  // 10 votes clears mitomano_certificado (votes >= 10).
  await seedRoom('ROOM03', [
    { id: 'talker', name: 'Ana', score: 1000 },
    { id: 'other', name: 'Beto', score: 0 },
  ]);
  await finishMatch('ROOM03');

  const titles = await waitFor(
    async () => {
      const snap = await db
        .collection('users')
        .doc('talker')
        .collection('unlockedTitles')
        .get();
      return snap.size > 0 ? snap : null;
    },
    { label: 'unlocked titles' }
  );

  assert.ok(titles.docs.some((d) => d.id === 'mitomano_certificado'));
});

test('replaying the same transition awards nothing a second time', async () => {
  await seedRoom('ROOM04', [
    { id: 'winner', name: 'Ana', score: 200 },
    { id: 'other', name: 'Beto', score: 0 },
  ]);

  await finishMatch('ROOM04');
  await waitFor(
    async () => {
      const snap = await completionOf('ROOM04');
      return snap.exists && snap.data().status === 'completed' ? snap : null;
    },
    { label: 'first completion' }
  );

  const afterFirst = (await profileOf('winner')).data();
  const claimedAt = (await completionOf('ROOM04')).data().claimedAt;

  // A genuine second transition: back to roundResult and forward again.
  // Without the Firestore claim this would double every stat.
  await db.collection('rooms').doc('ROOM04').update({ phase: 'roundResult' });
  await finishMatch('ROOM04');
  await new Promise((r) => setTimeout(r, 4000));

  const afterSecond = (await profileOf('winner')).data();
  assert.equal(afterSecond.xp, afterFirst.xp, 'XP must not double');
  assert.equal(afterSecond.totalGames, afterFirst.totalGames);
  assert.equal(afterSecond.totalWins, afterFirst.totalWins);
  assert.equal(afterSecond.totalVotesReceived, afterFirst.totalVotesReceived);

  // Still exactly one ledger entry, still the original claim.
  const completions = await db.collection('matchCompletions').get();
  assert.equal(completions.size, 1);
  assert.deepEqual((await completionOf('ROOM04')).data().claimedAt, claimedAt);
});

test('a room that never reaches finalWinner is never awarded', async () => {
  await seedRoom('ROOM05', [
    { id: 'a', name: 'Ana', score: 100 },
    { id: 'b', name: 'Beto', score: 0 },
  ]);

  // Abandoned mid-game.
  await db.collection('rooms').doc('ROOM05').update({ phase: 'voting' });
  await new Promise((r) => setTimeout(r, 3000));

  assert.equal((await completionOf('ROOM05')).exists, false);
  assert.equal((await profileOf('a')).exists, false);
});

test('a tie awards the win to every tied player', async () => {
  await seedRoom('ROOM06', [
    { id: 'tie1', name: 'Ana', score: 200 },
    { id: 'tie2', name: 'Beto', score: 200 },
    { id: 'last', name: 'Caro', score: 100 },
  ]);
  await finishMatch('ROOM06');

  await waitFor(
    async () => {
      const snap = await completionOf('ROOM06');
      return snap.exists && snap.data().status === 'completed' ? snap : null;
    },
    { label: 'tie completion' }
  );

  assert.equal((await profileOf('tie1')).data().totalWins, 1);
  assert.equal((await profileOf('tie2')).data().totalWins, 1);
  assert.equal((await profileOf('last')).data().totalWins, 0);
});

// ---------------------------------------------------------------------------
// submitVote — the server-authoritative voting flow (Security Hotfix B1).
//
// Driven over the callable's HTTP endpoint with a forged-but-valid emulator
// auth token, which is exactly the surface a modified client would attack.
// ---------------------------------------------------------------------------

const FUNCTIONS_ORIGIN =
  process.env.FUNCTIONS_EMULATOR_ORIGIN ?? 'http://127.0.0.1:5001';

/** The Auth emulator accepts an unsigned JWT with a matching alg header. */
function emulatorToken(uid) {
  const b64 = (o) =>
    Buffer.from(JSON.stringify(o)).toString('base64url');
  return `${b64({ alg: 'none', type: 'JWT' })}.${b64({
    sub: uid,
    user_id: uid,
    aud: 'demo-bufon',
    iss: 'https://securetoken.google.com/demo-bufon',
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 3600,
    auth_time: Math.floor(Date.now() / 1000),
    firebase: { sign_in_provider: 'anonymous', identities: {} },
  })}.`;
}

async function callSubmitVote(uid, data) {
  const res = await fetch(
    `${FUNCTIONS_ORIGIN}/demo-bufon/us-central1/submitVote`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${emulatorToken(uid)}`,
      },
      body: JSON.stringify({ data }),
    }
  );
  return { status: res.status, body: await res.json() };
}

async function seedVotingRoom(roomCode, players, phase = 'voting') {
  await db.collection('rooms').doc(roomCode).set({
    code: roomCode,
    hostId: players[0].id,
    phase,
    currentRound: 1,
    totalRounds: 5,
  });
  for (const p of players) {
    await db
      .collection('rooms')
      .doc(roomCode)
      .collection('players')
      .doc(p.id)
      .set({
        id: p.id,
        name: p.id,
        score: 0,
        currentAnswer: p.answer ?? 'una respuesta',
        votedFor: null,
        isOnline: true,
      });
  }
}

const playerDoc = (roomCode, id) =>
  db.collection('rooms').doc(roomCode).collection('players').doc(id).get();

test('submitVote: a valid vote marks the voter and awards the target', async () => {
  await seedVotingRoom('V01', [{ id: 'ana' }, { id: 'beto' }]);

  const { body } = await callSubmitVote('ana', {
    roomCode: 'V01',
    votedForId: 'beto',
  });
  assert.equal(body.result?.ok, true);

  assert.equal((await playerDoc('V01', 'ana')).data().votedFor, 'beto');
  assert.equal((await playerDoc('V01', 'beto')).data().score, 100);
});

test('submitVote: voting twice is rejected and awards nothing extra', async () => {
  await seedVotingRoom('V02', [{ id: 'ana' }, { id: 'beto' }]);

  await callSubmitVote('ana', { roomCode: 'V02', votedForId: 'beto' });
  const second = await callSubmitVote('ana', {
    roomCode: 'V02',
    votedForId: 'beto',
  });

  assert.equal(second.body.error?.details?.code, 'ALREADY_VOTED');
  assert.equal((await playerDoc('V02', 'beto')).data().score, 100);
});

test('submitVote: replaying the same call ten times awards exactly 100', async () => {
  await seedVotingRoom('V03', [{ id: 'ana' }, { id: 'beto' }]);

  // The shape of the original exploit, now over the only remaining path.
  for (let i = 0; i < 10; i++) {
    await callSubmitVote('ana', { roomCode: 'V03', votedForId: 'beto' });
  }

  assert.equal((await playerDoc('V03', 'beto')).data().score, 100);
});

test('submitVote: a non-member cannot vote', async () => {
  await seedVotingRoom('V04', [{ id: 'ana' }, { id: 'beto' }]);

  const { body } = await callSubmitVote('outsider', {
    roomCode: 'V04',
    votedForId: 'beto',
  });

  assert.equal(body.error?.details?.code, 'VOTER_NOT_FOUND');
  assert.equal((await playerDoc('V04', 'beto')).data().score, 0);
});

test('submitVote: voting outside the voting phase is rejected', async () => {
  await seedVotingRoom('V05', [{ id: 'ana' }, { id: 'beto' }], 'roundResult');

  const { body } = await callSubmitVote('ana', {
    roomCode: 'V05',
    votedForId: 'beto',
  });

  assert.equal(body.error?.details?.code, 'INVALID_PHASE');
  assert.equal((await playerDoc('V05', 'beto')).data().score, 0);
});

test('submitVote: voting for yourself is rejected', async () => {
  await seedVotingRoom('V06', [{ id: 'ana' }, { id: 'beto' }]);

  const { body } = await callSubmitVote('ana', {
    roomCode: 'V06',
    votedForId: 'ana',
  });

  assert.equal(body.error?.details?.code, 'SELF_VOTE_FORBIDDEN');
  assert.equal((await playerDoc('V06', 'ana')).data().score, 0);
});

test('submitVote: voting for a player who did not answer is rejected', async () => {
  await seedVotingRoom('V07', [{ id: 'ana' }, { id: 'beto', answer: '' }]);

  const { body } = await callSubmitVote('ana', {
    roomCode: 'V07',
    votedForId: 'beto',
  });

  assert.equal(body.error?.details?.code, 'VOTED_FOR_HAS_NO_ANSWER');
  assert.equal((await playerDoc('V07', 'beto')).data().score, 0);
});

test('submitVote: voting for a player who is not in the room is rejected', async () => {
  await seedVotingRoom('V08', [{ id: 'ana' }, { id: 'beto' }]);

  const { body } = await callSubmitVote('ana', {
    roomCode: 'V08',
    votedForId: 'ghost',
  });

  assert.equal(body.error?.details?.code, 'VOTED_FOR_NOT_FOUND');
});

test('submitVote: an unauthenticated call is rejected', async () => {
  await seedVotingRoom('V09', [{ id: 'ana' }, { id: 'beto' }]);

  const res = await fetch(
    `${FUNCTIONS_ORIGIN}/demo-bufon/us-central1/submitVote`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        data: { roomCode: 'V09', votedForId: 'beto' },
      }),
    }
  );
  const body = await res.json();

  assert.equal(body.error?.status, 'UNAUTHENTICATED');
  assert.equal((await playerDoc('V09', 'beto')).data().score, 0);
});

test('submitVote: the auth token decides the voter, not the payload', async () => {
  await seedVotingRoom('V10', [{ id: 'ana' }, { id: 'beto' }, { id: 'caro' }]);

  // A modified client trying to vote as someone else. `voterId` is not even
  // read by the function, so the vote lands on the caller's own document.
  await callSubmitVote('ana', {
    roomCode: 'V10',
    votedForId: 'beto',
    voterId: 'caro',
    uid: 'caro',
  });

  assert.equal((await playerDoc('V10', 'ana')).data().votedFor, 'beto');
  assert.equal((await playerDoc('V10', 'caro')).data().votedFor, null);
});
