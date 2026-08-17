// Seeded reference output from the JS season boundary.
//
// endSeason is the highest-stakes function in the game: it settles the table,
// moves the whole pyramid, pays out, ages the squad, sweeps and redraws the
// quest track and draws the next campaign — and most of its bugs have been
// ORDERING bugs, which only a full before-and-after comparison catches.
//
//   node tool/dump_season_end_reference.mjs > test/fixtures/season_end_reference.json

import { readFileSync } from 'node:fs';

const rng = await import('../../merge-empire-fc/src/utils/random.js');
const pe = await import('../../merge-empire-fc/src/engine/progressionEngine.js');

const questRef = JSON.parse(
  readFileSync(new URL('../test/fixtures/quest_engine_reference.json', import.meta.url), 'utf8'),
);

const clone = (v) => JSON.parse(JSON.stringify(v));

const TIME_KEYS = new Set(['startedAt', 'endedAt', 'lastMatchAt', 'injuredAt',
  'energyUpdatedAt', 'claimedAt', 'scoredAt', 'activatedAt', 'signedSeason']);
const stripTimes = (v) => {
  if (Array.isArray(v)) return v.map(stripTimes);
  if (v && typeof v === 'object') {
    const out = {};
    for (const [k, val] of Object.entries(v)) out[k] = TIME_KEYS.has(k) ? null : stripTimes(val);
    return out;
  }
  return v;
};

const baseState = (over = {}) => {
  const s = clone(questRef.state);
  s.prestige = { level: 0, incomeMultiplier: 1, totalTrophies: 0, points: 0 };
  s.careerStats = { leagueWins: 0, cupWins: 0 };
  s.club = {};
  s.boosts = {};
  s.gemGrants = { tutorialGranted: false, divisionFirsts: [], cupFirsts: [],
    firstPrestigeDone: false, chlTitleThisRun: false, questDivisionFirsts: [] };
  s.progression.cups = { active: null, history: [], availableThisSeason: true };
  s.progression.seasonHistory = [];
  s.progression.divisionsUnlocked = ['sunday_league', 'amateur_cup', 'regional_league'];
  s.progression.stagnationBuffs = {};
  s.progression.seasonAwardedPlayed = 14;
  s.progression.seasonMatchesPlayed = 14;
  Object.assign(s.progression, over);
  return s;
};

const out = {};

// Champion, mid-table and relegated, plus the top flight and the bottom rung.
const SCENARIOS = {
  promoted: { seasonWins: 13, seasonDraws: 1 },
  midTable: { seasonWins: 6, seasonDraws: 3 },
  relegated: { seasonWins: 0, seasonDraws: 1 },
  bottomDivision: { currentDivision: 'sunday_league', seasonWins: 0, seasonDraws: 0 },
  topFlightChampion: { currentDivision: 'champions_cup', seasonWins: 14, seasonDraws: 0 },
  topFlightMid: { currentDivision: 'champions_cup', seasonWins: 6, seasonDraws: 2 },
  stagnating: { seasonWins: 6, seasonDraws: 3, stagnationBuffs: { regional_league: 9 } },
};

for (const [label, over] of Object.entries(SCENARIOS)) {
  rng.setSeed(1234);
  const state = baseState(over);
  // A veteran, an injured player and a sponsored one, so ageing, the injury
  // head start and the sponsor expiry are all exercised.
  state.grid.cells[0].seasonsPlayed = 14;
  state.grid.cells[1].seasonsPlayed = 9;
  state.grid.cells[2].injured = true;
  state.grid.cells[2].injuredAt = 0;
  state.grid.cells[2].injuryDurationMs = 60 * 1000;
  state.grid.cells[3].injured = true;
  state.grid.cells[3].injuredAt = 0;
  state.grid.cells[3].injuryDurationMs = 90 * 60 * 1000;
  state.grid.cells[4].sponsor = { name: 'Old Deal', multiplier: 1.2, signedSeason: 1 };
  state.grid.cells[5].sponsor = { name: 'New Deal', multiplier: 1.2, signedSeason: 4 };
  state.grid.cells[6].form = 3;
  state.grid.cells[7].form = -2;

  const result = pe.endSeason(state);

  out[label] = {
    result: {
      outcome: result.outcome, position: result.position,
      oldDivision: result.oldDivision, newDivision: result.newDivision,
      payout: result.payout, gemsAwarded: result.gemsAwarded,
      ageingReport: result.ageingReport,
      injuryReport: result.injuryReport, sponsorReport: result.sponsorReport,
    },
    progression: stripTimes(clone({
      currentDivision: state.progression.currentDivision,
      seasonCount: state.progression.seasonCount,
      seasonMatchesPlayed: state.progression.seasonMatchesPlayed,
      seasonAwardedPlayed: state.progression.seasonAwardedPlayed,
      seasonWins: state.progression.seasonWins,
      seasonDraws: state.progression.seasonDraws,
      seasonLosses: state.progression.seasonLosses,
      seasonComplete: state.progression.seasonComplete,
      divisionsUnlocked: state.progression.divisionsUnlocked,
      stagnationBuffs: state.progression.stagnationBuffs,
      seasonHistory: state.progression.seasonHistory,
      lastSeasonPayout: state.progression.lastSeasonPayout,
      lastSeasonStatus: state.progression.lastSeasonStatus,
      leagueTrophies: state.progression.leagueTrophies,
      wonChampionsCup: state.progression.wonChampionsCup,
      leaguePyramid: state.progression.leaguePyramid,
      seasonOpponents: state.progression.seasonOpponents,
      seasonOpponentRatings: state.progression.seasonOpponentRatings,
      seasonFixtures: state.progression.seasonFixtures,
    })),
    coins: state.resources.fanCoins,
    gems: state.resources.gems,
    careerStats: clone(state.careerStats),
    quests: stripTimes(clone(state.quests)),
    cards: stripTimes(state.grid.cells.filter(Boolean).map((c) => ({
      instanceId: c.instanceId, seasonsPlayed: c.seasonsPlayed,
      injured: !!c.injured, injuryDurationMs: c.injuryDurationMs ?? null,
      sponsor: c.sponsor ?? null, form: c.form ?? 0,
    }))),
  };
}

// ── Prestige ────────────────────────────────────────────────────────────────
rng.setSeed(99);
{
  const state = baseState({ currentDivision: 'champions_cup', wonChampionsCup: true });
  state.resources.trophies = 42;
  state.club = { lookPacks: ['pack_legend', 'pack_retired'], lookItems: ['hat:tophat', 'hair:slick'],
    cupLooksWon: ['regional_cup'], managerAvatar: { hat: 'diamond', style: 'slick', build: 'broad' } };
  state.clubAssets.FANZONE = { owned: true, tier: 8, invested: 0, tapCount: 0 };
  state.boosts = { vipActive: true, vipPrestigeLevel: 0, vipExpiresAt: 999 };
  state.settings.autoTierActions = { 1: 'sell', 2: 'sell' };
  const result = pe.performPrestige(state);
  out.prestige = {
    result: { ok: result.ok, gemsAwarded: result.gemsAwarded, level: result.level,
      multiplier: result.multiplier },
    coins: state.resources.fanCoins,
    gems: state.resources.gems,
    trophies: state.resources.trophies,
    prestige: clone(state.prestige),
    club: { lookPacks: state.club.lookPacks, lookItems: state.club.lookItems,
      cupLooksWon: state.club.cupLooksWon,
      managerAvatarHat: state.club.managerAvatar.hat,
      managerAvatarStyle: state.club.managerAvatar.style },
    autoTierActions: clone(state.settings.autoTierActions),
    boosts: clone(state.boosts),
    gemGrants: clone(state.gemGrants),
    careerStats: clone(state.careerStats),
    progression: {
      currentDivision: state.progression.currentDivision,
      divisionsUnlocked: state.progression.divisionsUnlocked,
      wonChampionsCup: state.progression.wonChampionsCup,
      seasonCount: state.progression.seasonCount,
      leaguePyramid: state.progression.leaguePyramid,
      leagueTrophies: state.progression.leagueTrophies,
      stagnationBuffs: state.progression.stagnationBuffs,
      cups: state.progression.cups,
    },
    gridEmpty: state.grid.cells.every((c) => c == null),
    gridLength: state.grid.cells.length,
  };
}

rng.setSeed(99);
{
  const state = baseState();
  out.prestigeRefused = clone(pe.performPrestige(state));
}

process.stdout.write(JSON.stringify(out));
