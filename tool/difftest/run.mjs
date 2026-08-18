// The differential harness: whole SEASONS through the JS engines, recorded so
// the Dart port can be walked down the same path and compared at every step.
//
// See tool/difftest/README.md for what this is for and how it records it.
//
//   node tool/difftest/run.mjs > test/fixtures/season_difftest.json

import { readFileSync } from 'node:fs';
import { canonical, hashOf } from './canonical.mjs';

const FIXED_NOW = 1700000000000;
Date.now = () => FIXED_NOW;

// The unseeded stream, made reproducible — the same algorithm as
// utils/random.js, so the Dart side can drive an identical one.
let mathSeed = 1;
Math.random = () => {
  mathSeed |= 0;
  mathSeed = (mathSeed + 0x6d2b79f5) | 0;
  let t = Math.imul(mathSeed ^ (mathSeed >>> 15), 1 | mathSeed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};

const rng = await import('../../../merge-empire-fc/src/utils/random.js');
const me = await import('../../../merge-empire-fc/src/engine/matchEngine.js');
const pe = await import('../../../merge-empire-fc/src/engine/progressionEngine.js');
const qe = await import('../../../merge-empire-fc/src/engine/questEngine.js');
const fm = await import('../../../merge-empire-fc/src/data/formations.js');
const { QUEST_ACTIONS } = await import('../../../merge-empire-fc/src/data/quests.js');
const { createDefaultState } = await import('../../../merge-empire-fc/src/state/stateSchema.js');

const questRef = JSON.parse(
  readFileSync(new URL('../../test/fixtures/quest_engine_reference.json', import.meta.url), 'utf8'),
);

const clone = (v) => JSON.parse(JSON.stringify(v));

/** How many seasons one run plays. Long enough that a divergence in the season
 *  boundary has somewhere to grow, short enough to stay a fixture. */
const SEASONS = 6;

/// The save every run starts from.
///
/// A DEFAULT state, so every branch the schema writes is present — the shared
/// reference save predates several of them and `endSeason` pushes to two
/// without checking — with the reference squad dropped in, because a default
/// save's starting eleven is too weak for six seasons to go anywhere.
///
/// It is shipped in the fixture rather than rebuilt on the Dart side: whether
/// the two `createDefaultState` implementations agree is a question the schema
/// fixture already answers, and confounding it with this one would make a
/// failure here mean two things at once.
const baseState = ({ hardMode = false } = {}) => {
  const s = createDefaultState();
  const ref = clone(questRef.state);
  s.grid = ref.grid;
  s.squad = ref.squad;
  s.definitionRatios = ref.definitionRatios;
  s.progression.leaguePyramid = ref.progression.leaguePyramid;
  s.progression.currentDivision = ref.progression.currentDivision;
  s.progression.seasonCount = ref.progression.seasonCount;
  s.settings = { ...(s.settings ?? {}), hardMode };
  s.resources.fanCoins = 50_000;
  s.progression.matchesPlayed = 0;
  s.progression.matchesWon = 0;
  s.progression.matchesDrawn = 0;
  s.progression.seasonWins = 0;
  s.progression.seasonDraws = 0;
  s.progression.seasonLosses = 0;
  s.progression.seasonMatchesPlayed = 0;
  s.progression.seasonAwardedPlayed = 0;
  s.progression.trophiesTotal = 0;
  s.progression.careerWins = 0;
  s.progression.careerDraws = 0;
  s.progression.careerGoalsFor = 0;
  s.progression.lastMatchAt = 0;
  s.progression.seasonFixtures = null;
  s.careerStats = { leagueWins: 0, cupWins: 0, matchesWon: 0, totalMerges: 0 };
  s.squad.formation = '4-4-2';
  s.squad.lineup = fm.buildDefaultLineup('4-4-2', s.grid.cells);
  s.squad.strategyId = 'balanced';
  return s;
};

/// One league match, in the order the League screen runs it: simulate, count it
/// for the quests, commit the outcome at full time, resolve the match track, and
/// credit the payout on close.
const playMatch = (state) => {
  const result = me.simulateMatch(state, state.progression.currentDivision);
  pe.trackEvent(state, QUEST_ACTIONS.PLAY_MATCHES);
  if (result.won) pe.trackEvent(state, QUEST_ACTIONS.MATCH_WIN);
  me.finalizeMatchOutcome(state, result);
  qe.resolveMatchQuests(state, result);
  me.applyMatchRewards(state, result);
  return result;
};

/// Only what tells you WHAT went wrong once a hash says something did.
const resultDigest = (r) => ({
  homeGoals: r.homeGoals, awayGoals: r.awayGoals,
  won: !!r.won, drawn: !!r.drawn, isHome: !!r.isHome,
  coinsEarned: r.coinsEarned ?? 0, trophiesEarned: r.trophiesEarned ?? 0,
  opponentName: r.opponentName ?? null,
  squadRating: r.squadRating ?? null, opponentRating: r.opponentRating ?? null,
  injuryCount: r.injuryCount ?? 0,
  events: (r.events ?? []).length,
});

const seasonEndDigest = (r) => (r == null ? null : {
  outcome: r.outcome, position: r.position,
  oldDivision: r.oldDivision, newDivision: r.newDivision,
  payout: r.payout, gemsAwarded: r.gemsAwarded,
  ageing: (r.ageingReport ?? []).length,
  injuryRecovered: r.injuryReport?.recovered ?? 0,
  injuryShortened: r.injuryReport?.shortened ?? 0,
  sponsorsExpired: r.sponsorReport?.expired ?? 0,
});

const out = { fixedNow: FIXED_NOW, seasons: SEASONS, base: {}, runs: {} };
const base = out.base;

for (const [label, seed, mathSeedValue, opts] of [
  ['casual', 20250817, 1, {}],
  ['pro', 4242, 77, { hardMode: true }],
]) {
  // The base is built BEFORE the seeds are set. `createDefaultState` draws its
  // starting cards from the seeded stream, and the Dart side loads the finished
  // save rather than rebuilding it — so seeding first would leave the two
  // runtimes' streams at different positions before the first match.
  const state = baseState(opts);
  base[label] = clone(state);

  rng.setSeed(seed);
  mathSeed = mathSeedValue;
  // The schedule the run walks. Generated once here so the first season is not
  // a special case, and so both runtimes start from the identical fixture list.
  pe.ensureLeaguePyramid(state);
  pe.initSeasonOpponents(state);
  pe.generateSeasonFixtures(state);

  const steps = [];
  const seasonEnds = [];

  for (let season = 0; season < SEASONS; season++) {
    const fixtures = state.progression.seasonFixtures ?? [];
    for (let i = 0; i < fixtures.length; i++) {
      const result = playMatch(state);
      steps.push({
        season, match: i,
        hash: hashOf(state),
        result: resultDigest(result),
        // The very first match carries its whole save. A run that diverges
        // immediately has nowhere else to look, and a hash on its own says
        // nothing about what moved.
        ...(season === 0 && i === 0 ? { save: canonical(state) } : {}),
      });
    }
    const ended = pe.endSeason(state);
    seasonEnds.push({
      season,
      hash: hashOf(state),
      ended: seasonEndDigest(ended),
      // The whole save, so a hash mismatch has something to diff against.
      save: canonical(state),
    });
  }

  out.runs[label] = {
    seed, mathSeed: mathSeedValue, hardMode: !!opts.hardMode,
    steps, seasonEnds,
  };
}

process.stdout.write(JSON.stringify(out));
