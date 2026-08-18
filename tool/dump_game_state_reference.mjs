// Reference output from the JS game state — the two resets in particular.
//
// These are the functions with the worst failure mode in the codebase. The JS
// comments they carry read like a list of things that went wrong in production:
// a full reset that took the player's gem balance, a soft reset that zeroed the
// lifetime counters so the next signed-in boot overwrote a real leaderboard
// standing with them, a preserved gem ledger that re-armed every one-time faucet
// so resetting became the farm. Every one of those is a paying player losing
// something they paid for.
//
// So the whole state is compared, before and after, on a save that carries one
// of everything: purchases, gems, a gem ledger, look packs, a manager avatar
// wearing things a fresh save cannot justify, achievements, career totals, a
// prestige level, a leaderboard identity and a squad with a legendary in it.
//
//   node tool/dump_game_state_reference.mjs > test/fixtures/game_state_reference.json

import { readFileSync } from 'node:fs';

const FIXED_NOW = 1700000000000;
Date.now = () => FIXED_NOW;

// The default state rolls its starting squad off the seeded stream, so it is
// pinned — otherwise every reset would produce a different eleven.
const rng = await import('../../merge-empire-fc/src/utils/random.js');
const gs = await import('../../merge-empire-fc/src/state/gameState.js');

const questRef = JSON.parse(
  readFileSync(new URL('../test/fixtures/quest_engine_reference.json', import.meta.url), 'utf8'),
);

const clone = (v) => JSON.parse(JSON.stringify(v));

const DEFAULT_SEED = 20250818;

/// A save carrying one of everything a reset has to make a decision about.
const richSave = () => {
  const s = clone(questRef.state);
  s.version = 7;
  s.createdAt = FIXED_NOW - 90 * 24 * 60 * 60 * 1000;
  s.lastSeen = FIXED_NOW - 60 * 1000;
  s.resources = { fanCoins: 250000, gems: 37, trophies: 12, matchRevenue: 0 };
  s.energy = { current: 4, lastRegenAt: FIXED_NOW - 60000 };
  s.boosts = { incomeBoostActive: false, incomeBoostEndsAt: 0, vipActive: false, vipExpiresAt: 0 };
  s.settings = { locale: 'fr', hardMode: true, sfx: false, regionCode: 'FR' };
  s.shop = {
    purchasedIds: ['vip_pass', 'starter_pack', 'energy_director', 'style_vault', 'coin_pile', 'remove_ads'],
    vipExpiresAt: FIXED_NOW + 20 * 24 * 60 * 60 * 1000,
    totalSpent: 4299,
    energyUpgraded: true,
    freeScoutReady: true,
    luckyBootReady: true,
    scoutVoucherTier: 5,
  };
  s.gemUnlocks = ['auto_tier_gem', 'extra_slot'];
  s.gemGrants = {
    tutorialGranted: true,
    tutorialBackfilled: true,
    divisionFirsts: ['amateur_cup', 'regional_league'],
    cupFirsts: ['regional_cup'],
    firstPrestigeDone: true,
    chlTitleThisRun: true,
  };
  s.dailyReward = {
    cycleDay: 5, lastClaimDayKey: 'Mon Aug 17 2026', streak: 19,
    longestStreak: 22, totalClaims: 41, lastAutoPopupDayKey: 'Mon Aug 17 2026',
  };
  s.prestige = { level: 3, totalPrestiges: 3, lastPrestigeAt: FIXED_NOW - 1000 };
  s.careerStats = { leagueWins: 6, cupWins: 2, matchesWon: 143, totalMerges: 512, hardModeWins: 21 };
  s.stats = {
    ...(s.stats ?? {}),
    maxCoinsReached: 990000, resetCount: 2, everHadLegendaryAtReset: false,
    maxSeasonsAtReset: 4, everResetFromTopDivision: false, maxPrestigeLevelAtReset: 1,
    totalMerges: 512, penaltiesScored: 60,
  };
  s.club = {
    ...(s.club ?? {}),
    lookPacks: ['pack_summer', 'pack_neon'],
    lookItems: ['emote:robot', 'hat:cap', 'hair:braids'],
    cupLooksWon: ['outfit:tracksuit'],
    // Every value here is one the catalogue KNOWS. An unrecognised one falls
    // back to a random pick inside `normalizeAvatar`, and the point of this case
    // is what the sanitiser takes away rather than what it invents.
    managerAvatar: {
      build: 'regular', outfit: 'suit', style: 'mullet', beard: 'moustache',
      hat: 'cap', face: 'none', ball: 'classic',
      hair: '#1a1410', skin: '#c68642', skinShade: '#cf9f77',
    },
    kitPrimaryColor: 'humbug',
  };
  s.tutorial = { done: true, step: 9 };
  s.leaderboard = {
    playerId: 'player-abc-123', authUid: 'uid-xyz', authProvider: 'google',
    accountName: 'The Gaffer', lastSubmittedAt: FIXED_NOW - 5000,
    careerSeeded: true, anonymousLinked: true, rankingsVisible: false,
    optOutApplied: true, metaClubName: 'Northern Legion FC',
    allTimeRepairDone: true, cloudSyncToken: 'tok', cloudSyncMs: 999,
  };
  s.progression = {
    ...s.progression,
    currentDivision: 'champions_cup',
    seasonCount: 11,
    achievements: [
      { id: 'first_win', unlockedAt: 1000, count: 1 },
      { id: 'merge_to_legend', unlockedAt: 2000, count: 1 },
    ],
    discoveredPlayers: ['player_t8_fwd', 'player_t7_mid'],
    playerFoundCounts: { player_t8_fwd: 3, player_t7_mid: 1 },
    leagueTrophies: [{ name: 'Champions Cup', cup: true }],
    careerWins: 143, careerDraws: 51, careerGoalsFor: 620, careerBackfillDone: true,
    seasonWins: 5, seasonDraws: 2, seasonLosses: 1,
  };
  // A legendary on the grid, which is what `everHadLegendaryAtReset` reads.
  s.grid = clone(s.grid);
  s.grid.cells[0] = { instanceId: 'legend', definitionId: 'player_t8_fwd', seasonsPlayed: 3 };
  s.autoTier = { rules: { 1: 'sell', 2: 'sell' } };
  return s;
};

/// A save with nothing on it — the other end of every branch.
const bareSave = () => {
  const s = clone(questRef.state);
  delete s.shop;
  delete s.gemUnlocks;
  delete s.gemGrants;
  delete s.dailyReward;
  delete s.prestige;
  delete s.careerStats;
  delete s.club;
  delete s.leaderboard;
  delete s.settings;
  s.resources = { fanCoins: 10, gems: 0, trophies: 0 };
  return s;
};

// `definitionRatios` is drawn from the UNSEEDED stream in both runtimes — it is
// a per-install randomisation of each card's ATK/DEF split, not a value the port
// has to reproduce. It is stripped from every comparison here, and what the
// tests assert about it instead is the PROPERTY: a reset regenerates it.
const stripRatios = (v) => {
  const out = { ...v };
  delete out.definitionRatios;
  return out;
};

const out = { fixedNow: FIXED_NOW, seed: DEFAULT_SEED };

/// The default state both runtimes start a reset from, shipped so a difference
/// in the SCHEMA cannot masquerade as a difference in the reset.
rng.setSeed(DEFAULT_SEED);
{
  const { createDefaultState } = await import('../../merge-empire-fc/src/state/stateSchema.js');
  out.defaultState = stripRatios(createDefaultState());
}

/// gameState holds its save in a module-level variable that only `loadState`
/// sets, so each case is run through a fresh localStorage.
const runReset = (label, save, fn) => {
  const store = {};
  globalThis.localStorage = {
    getItem: (k) => (k in store ? store[k] : null),
    setItem: (k, v) => { store[k] = String(v); },
    removeItem: (k) => { delete store[k]; },
  };
  store['mergeEmpireFC_save'] = JSON.stringify(save);
  rng.setSeed(DEFAULT_SEED);
  gs.loadState();
  const after = fn();
  return {
    label,
    before: clone(save),
    after: stripRatios(clone(after)),
    stored: { ...store },
  };
};

out.resets = [];
for (const [label, save, fn] of [
  ['softRich', richSave(), () => gs.resetState()],
  ['softRichReplayTutorial', richSave(), () => gs.resetState({ replayTutorial: true })],
  ['softBare', bareSave(), () => gs.resetState()],
  ['fullRich', richSave(), () => gs.fullResetState()],
  ['fullRichKeepTutorial', richSave(), () => gs.fullResetState({ replayTutorial: false })],
  ['fullBare', bareSave(), () => gs.fullResetState()],
]) {
  out.resets.push(runReset(label, save, fn));
}

// A soft reset, then a full one on the result: the second must not undo what the
// first preserved, which is the shape a player who resets twice actually hits.
out.softThenFull = (() => {
  const store = {};
  globalThis.localStorage = {
    getItem: (k) => (k in store ? store[k] : null),
    setItem: (k, v) => { store[k] = String(v); },
    removeItem: (k) => { delete store[k]; },
  };
  store['mergeEmpireFC_save'] = JSON.stringify(richSave());
  rng.setSeed(DEFAULT_SEED);
  gs.loadState();
  const soft = stripRatios(clone(gs.resetState()));
  const full = stripRatios(clone(gs.fullResetState()));
  return { soft, full, stored: { ...store } };
})();

process.stdout.write(JSON.stringify(out));
