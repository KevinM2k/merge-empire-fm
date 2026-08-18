// Reference output from the JS daily-reward engine.
//
// Everything here turns on a LOCAL day key — `toDateString()`, midnight to
// midnight in the player's own timezone — so the cases are built from local
// wall-clock components rather than epoch stamps, and both runtimes construct
// their own instants from the same calendar date. Noon, so a daylight-saving
// shift cannot move a case onto the day before.
//
// The interesting arithmetic is the streak: it continues only when the last
// claim was YESTERDAY's key, restarts at 1 otherwise, and the cycle day wraps
// 7 back to 1 independently of the streak. Those two counters are easy to
// conflate and they are not the same number — a repaired streak of forty can
// sit on cycle day 3.
//
//   node tool/dump_daily_reward_reference.mjs > test/fixtures/daily_reward_reference.json

import { readFileSync } from 'node:fs';

const dre = await import('../../merge-empire-fc/src/engine/dailyRewardEngine.js');

const questRef = JSON.parse(
  readFileSync(new URL('../test/fixtures/quest_engine_reference.json', import.meta.url), 'utf8'),
);

const clone = (v) => JSON.parse(JSON.stringify(v));

/// Local noon on a calendar date, which both runtimes can rebuild for
/// themselves. `m` is 1-based.
const AT = { y: 2026, m: 8, d: 18, h: 12 };
const at = (over = {}) => {
  const { y, m, d, h } = { ...AT, ...over };
  return new Date(y, m - 1, d, h).getTime();
};
const DAY = 24 * 60 * 60 * 1000;

const baseState = ({
  coins = 0, gems = 0, division = 'regional_league', hardMode = false,
  dailyReward = null, miniGames = null, mediaTier = 0,
} = {}) => {
  const s = clone(questRef.state);
  s.resources.fanCoins = coins;
  s.resources.gems = gems;
  s.energy = { current: 3, lastRegenAt: 0 };
  s.settings = { ...(s.settings ?? {}), hardMode };
  s.progression.currentDivision = division;
  s.clubAssets = {
    ...(s.clubAssets ?? {}),
    MEDIA: { owned: mediaTier > 0, tier: mediaTier, invested: 0, tapCount: 0 },
  };
  if (dailyReward) s.dailyReward = dailyReward;
  if (miniGames) s.miniGames = miniGames;
  return s;
};

/// Only what a claim actually writes.
const digest = (s) => ({
  dailyReward: clone(s.dailyReward ?? null),
  fanCoins: s.resources.fanCoins,
  gems: s.resources.gems,
  energy: clone(s.energy ?? null),
  shop: clone(s.shop ?? null),
  cellEnergies: (s.grid?.cells ?? []).map((c) => (c ? (c.energy ?? null) : null)),
  injured: (s.grid?.cells ?? []).map((c) => (c ? !!c.injured : null)),
});

const out = { at: AT, cycleDays: dre.CYCLE_DAYS, trainedBonusMult: dre.TRAINED_BONUS_MULT };

out.calendar = {};
for (const [day, def] of Object.entries(dre.DAILY_REWARDS)) out.calendar[day] = def;

// ── What a day is worth ─────────────────────────────────────────────────────
out.preview = [];
for (const day of [0, 1, 2, 3, 4, 5, 6, 7, 8]) {
  for (const [division, mediaTier] of [
    ['sunday_league', 0], ['regional_league', 0], ['champions_cup', 0],
    ['regional_league', 4],
  ]) {
    out.preview.push({
      day, division, mediaTier,
      preview: dre.getDailyRewardPreview(baseState({ division, mediaTier }), day),
    });
  }
}

// ── Where the player stands ─────────────────────────────────────────────────
const DR = (over = {}) => ({
  cycleDay: 0, lastClaimDayKey: null, streak: 0, longestStreak: 0,
  totalClaims: 0, lastAutoPopupDayKey: null, ...over,
});
const key = (ts) => new Date(ts).toDateString();

out.status = [];
for (const [label, dailyReward, miniGames] of [
  ['neverClaimed', null, null],
  ['freshBranch', undefined, null],
  ['claimedToday', DR({ cycleDay: 3, lastClaimDayKey: key(at()), streak: 3, totalClaims: 3 }), null],
  ['claimedYesterday', DR({ cycleDay: 3, lastClaimDayKey: key(at() - DAY), streak: 3, totalClaims: 3 }), null],
  ['wrapsPastSeven', DR({ cycleDay: 7, lastClaimDayKey: key(at() - DAY), streak: 7, totalClaims: 7 }), null],
  ['brokenStreak', DR({ cycleDay: 4, lastClaimDayKey: key(at() - 3 * DAY), streak: 4, totalClaims: 4 }), null],
  // A gap with no streak behind it is not "broken" — there is nothing to repair.
  ['gapWithNoStreak', DR({ cycleDay: 2, lastClaimDayKey: key(at() - 3 * DAY), streak: 0, totalClaims: 2 }), null],
  ['trainedToday', null, { trainingLastPlayed: at({ h: 9 }) }],
  ['trainedYesterday', null, { penaltyLastPlayed: at() - DAY }],
  ['trainedTwoDaysAgo', null, { penaltyLastPlayed: at() - 2 * DAY }],
  ['neverTrained', null, { penaltyLastPlayed: 0, trainingLastPlayed: 0 }],
  // The whack and boot-room stamps are deliberately NOT in the bonus list.
  ['whackDoesNotCount', null, { whackLastPlayed: at({ h: 9 }), bootRoomLastPlayed: at({ h: 9 }) }],
]) {
  const state = baseState({
    dailyReward: dailyReward === undefined ? null : dailyReward,
    miniGames,
  });
  if (dailyReward === undefined) delete state.dailyReward;
  const status = dre.getDailyRewardStatus(state, at());
  out.status.push({
    label, status,
    branchAfter: clone(state.dailyReward),
    canRepair: dre.canRepairStreak(state, at()),
  });
}

// ── Repairing ───────────────────────────────────────────────────────────────
out.repair = [];
for (const [label, dailyReward] of [
  ['broken', DR({ cycleDay: 4, lastClaimDayKey: key(at() - 3 * DAY), streak: 4, totalClaims: 4 })],
  ['notBroken', DR({ cycleDay: 4, lastClaimDayKey: key(at() - DAY), streak: 4, totalClaims: 4 })],
  ['neverClaimed', DR()],
  // Broken, but the player never got past day 0 — nothing to carry on from.
  ['brokenAtDayZero', DR({ cycleDay: 0, lastClaimDayKey: key(at() - 3 * DAY), streak: 2 })],
]) {
  const state = baseState({ dailyReward });
  const result = dre.repairStreak(state, at());
  out.repair.push({
    label, result,
    branchAfter: clone(state.dailyReward),
    statusAfter: dre.getDailyRewardStatus(state, at()),
  });
}

// ── Claiming ────────────────────────────────────────────────────────────────
const claimCase = (label, { dailyReward = null, doubled = false, hardMode = false,
  division = 'regional_league', miniGames = null, coins = 1000, gems = 5, cells = null } = {}) => {
  const state = baseState({ dailyReward, hardMode, division, miniGames, coins, gems });
  if (cells) state.grid.cells = cells;
  const result = dre.claimDailyReward(state, { doubled, ts: at() });
  return { label, doubled, hardMode, division, result, state: digest(state) };
};

out.claim = [];
// One claim per calendar day, by seeding yesterday's cycle day.
for (let day = 1; day <= 7; day++) {
  const prev = day === 1 ? DR() : DR({
    cycleDay: day - 1, lastClaimDayKey: key(at() - DAY), streak: day - 1, longestStreak: day - 1, totalClaims: day - 1,
  });
  out.claim.push(claimCase(`day${day}`, { dailyReward: prev }));
}
out.claim.push(claimCase('day7Doubled', {
  dailyReward: DR({ cycleDay: 6, lastClaimDayKey: key(at() - DAY), streak: 6, longestStreak: 6, totalClaims: 6 }),
  doubled: true,
}));
out.claim.push(claimCase('day1Doubled', { doubled: true }));
out.claim.push(claimCase('trainedBonus', { miniGames: { trainingLastPlayed: at({ h: 9 }) } }));
out.claim.push(claimCase('trainedBonusDoubled', {
  miniGames: { trainingLastPlayed: at({ h: 9 }) }, doubled: true,
}));
out.claim.push(claimCase('hardModeEnergy', {
  dailyReward: DR({ cycleDay: 1, lastClaimDayKey: key(at() - DAY), streak: 1, longestStreak: 1, totalClaims: 1 }),
  hardMode: true,
}));
out.claim.push(claimCase('championsCup', { division: 'champions_cup' }));
// A broken streak that was not repaired restarts at 1 — and the cycle with it.
out.claim.push(claimCase('brokenRestarts', {
  dailyReward: DR({ cycleDay: 5, lastClaimDayKey: key(at() - 4 * DAY), streak: 9, longestStreak: 12, totalClaims: 9 }),
}));
// Repaired first, so the cycle carries on where it left off.
out.claimAfterRepair = (() => {
  const state = baseState({
    dailyReward: DR({ cycleDay: 5, lastClaimDayKey: key(at() - 4 * DAY), streak: 9, longestStreak: 12, totalClaims: 9 }),
  });
  const repair = dre.repairStreak(state, at());
  const result = dre.claimDailyReward(state, { ts: at() });
  return { repair, result, state: digest(state) };
})();

out.claimTwice = (() => {
  const state = baseState();
  const first = dre.claimDailyReward(state, { ts: at() });
  const second = dre.claimDailyReward(state, { ts: at({ h: 22 }) });
  return { first, second, state: digest(state) };
})();

// A whole week, claimed a day at a time, to pin the cycle AND the streak.
out.wholeWeek = (() => {
  const state = baseState();
  const days = [];
  for (let i = 0; i < 9; i++) {
    const ts = at() + i * DAY;
    const r = dre.claimDailyReward(state, { ts });
    days.push({ i, day: r.day, streak: r.streak, coins: r.coins, gems: r.gems, energy: r.energy });
  }
  return { days, branch: clone(state.dailyReward), fanCoins: state.resources.fanCoins, gems: state.resources.gems };
})();

// ── The two calendar entries nothing currently uses ─────────────────────────
// `freeScout` and `healOne` are still supported end to end, so a day can pick
// either back up with no new plumbing. Exercised by swapping day 4 out.
out.unusedRewards = (() => {
  const original = dre.DAILY_REWARDS[4];
  dre.DAILY_REWARDS[4] = { coinsMult: 1, freeScout: true, healOne: true };
  const cells = clone(questRef.state.grid.cells);
  cells[0] = { ...cells[0], injured: true, injuredAt: 1, injuryDurationMs: 100 };
  cells[1] = { ...cells[1], injured: true, injuredAt: 1, injuryDurationMs: 100 };
  cells[2] = { ...cells[2], injured: true, injuredAt: 1, injuryDurationMs: 100 };

  const single = (() => {
    const state = baseState({
      dailyReward: DR({ cycleDay: 3, lastClaimDayKey: key(at() - DAY), streak: 3, longestStreak: 3, totalClaims: 3 }),
    });
    state.grid.cells = clone(cells);
    const result = dre.claimDailyReward(state, { ts: at() });
    return { result, state: digest(state) };
  })();
  const doubled = (() => {
    const state = baseState({
      dailyReward: DR({ cycleDay: 3, lastClaimDayKey: key(at() - DAY), streak: 3, longestStreak: 3, totalClaims: 3 }),
    });
    state.grid.cells = clone(cells);
    const result = dre.claimDailyReward(state, { doubled: true, ts: at() });
    return { result, state: digest(state) };
  })();
  const nobodyInjured = (() => {
    const state = baseState({
      dailyReward: DR({ cycleDay: 3, lastClaimDayKey: key(at() - DAY), streak: 3, longestStreak: 3, totalClaims: 3 }),
    });
    const result = dre.claimDailyReward(state, { ts: at() });
    return { result, state: digest(state) };
  })();

  const preview = dre.getDailyRewardPreview(baseState(), 4);
  dre.DAILY_REWARDS[4] = original;
  return { preview, single, doubled, nobodyInjured, cells };
})();

// ── The popup gate ──────────────────────────────────────────────────────────
out.popup = (() => {
  const state = baseState();
  const first = dre.shouldAutoShowPopup(state, at());
  const second = dre.shouldAutoShowPopup(state, at({ h: 20 }));
  const tomorrow = dre.shouldAutoShowPopup(state, at({ d: 19 }));
  const claimed = baseState({
    dailyReward: DR({ cycleDay: 1, lastClaimDayKey: key(at()), streak: 1, totalClaims: 1 }),
  });
  const afterClaim = dre.shouldAutoShowPopup(claimed, at());
  return { first, second, tomorrow, afterClaim, branch: clone(state.dailyReward),
    claimedBranch: clone(claimed.dailyReward) };
})();

out.streakChip = [
  { label: 'none', streak: dre.getDailyStreak(baseState()) },
  { label: 'running', streak: dre.getDailyStreak(baseState({ dailyReward: DR({ streak: 12 }) })) },
  { label: 'nullState', streak: dre.getDailyStreak(null) },
  { label: 'emptyState', streak: dre.getDailyStreak({}) },
];

process.stdout.write(JSON.stringify(out));
