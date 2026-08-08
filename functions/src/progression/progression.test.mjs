// functions/src/progression/progression.test.mjs
//
// Covers the pure reward logic, which is now the authority for XP, levels
// and unlocks. Run with: npm run build && node --test lib/progression/
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  AchievementService,
  AvatarService,
  LeaderboardService,
  matchXp,
} from '../../lib/progression/services.js';
import { calculateLevel } from '../../lib/progression/catalog.js';

const baseStats = (over = {}) => ({
  xp: 0,
  level: 1,
  totalGames: 0,
  totalWins: 0,
  totalVotesReceived: 0,
  unlockedAchievements: [],
  unlockedAvatars: ['default'],
  selectedAvatar: 'default',
  ...over,
});

test('match XP matches the client formula', () => {
  assert.equal(matchXp(false, 0), 10);
  assert.equal(matchXp(true, 0), 35);
  assert.equal(matchXp(false, 3), 25);
  assert.equal(matchXp(true, 3), 50);
});

test('level curve matches UserProfile.calculateLevel', () => {
  assert.equal(calculateLevel(0), 1);
  assert.equal(calculateLevel(99), 1);
  assert.equal(calculateLevel(100), 2);
  assert.equal(calculateLevel(400), 3);
  assert.equal(calculateLevel(2500), 6);
});

test('achievements unlock on their threshold and never twice', () => {
  const first = AchievementService.evaluate(
    baseStats({ totalGames: 1, totalWins: 1 })
  );
  assert.ok(first.includes('first_game'));
  assert.ok(first.includes('first_win'));

  const again = AchievementService.evaluate(
    baseStats({
      totalGames: 1,
      totalWins: 1,
      unlockedAchievements: ['first_game', 'first_win'],
    })
  );
  assert.deepEqual(again, []);
});

test('night_pass_purchase is never awarded by playing', () => {
  const unlocked = AchievementService.evaluate(
    baseStats({ totalGames: 999, totalWins: 999, totalVotesReceived: 999 })
  );
  assert.ok(!unlocked.includes('night_pass_purchase'));
});

test('avatars unlock from level, games, wins, votes and achievements', () => {
  assert.ok(AvatarService.evaluate(baseStats({ totalGames: 1 })).includes('smiley'));
  assert.ok(AvatarService.evaluate(baseStats({ level: 2 })).includes('cool'));
  assert.ok(AvatarService.evaluate(baseStats({ totalWins: 3 })).includes('genius'));
  assert.ok(
    AvatarService.evaluate(baseStats({ totalVotesReceived: 20 })).includes('devil')
  );
});

test('the night pass avatar is never awarded by playing', () => {
  const unlocked = AvatarService.evaluate(
    baseStats({ level: 99, totalGames: 999, totalWins: 999, totalVotesReceived: 999 })
  );
  assert.ok(!unlocked.includes('night_pass'));
});

test('an already owned avatar is not re-awarded', () => {
  const unlocked = AvatarService.evaluate(
    baseStats({ totalGames: 1, unlockedAvatars: ['default', 'smiley'] })
  );
  assert.ok(!unlocked.includes('smiley'));
});

test('week key is ISO-8601 and stable across a week', () => {
  // 2026-01-05 is a Monday, 2026-01-11 the Sunday of the same ISO week.
  const monday = LeaderboardService.weekKey(new Date('2026-01-05T00:00:00Z'));
  const sunday = LeaderboardService.weekKey(new Date('2026-01-11T23:59:00Z'));
  assert.equal(monday, sunday);
  assert.match(monday, /^\d{4}-W\d{2}$/);

  const nextMonday = LeaderboardService.weekKey(new Date('2026-01-12T00:00:00Z'));
  assert.notEqual(monday, nextMonday);
});
