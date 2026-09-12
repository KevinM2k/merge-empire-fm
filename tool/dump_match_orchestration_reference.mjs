// Seeded reference output from the JS match orchestration — the outer half of
// matchEngine.js.
//
// This is the biggest single function in the game and almost all of its risk is
// ORDERING: it draws the opponent's rating, the injury rolls, the swing, the AI
// rotation plan, the segment goals and then the whole event feed off one shared
// stream, and a port that gets every formula right still comes out wrong if it
// draws them in a different sequence. So whole matches are compared, not
// functions.
//
// ── Both generators are pinned ─────────────────────────────────────────────
// The engine mixes the seeded stream with bare Math.random (team attribution,
// xG, the per-match save/tackle counts), and the split is load-bearing — see
// the header of engine/match_events.dart. Math.random is therefore replaced
// with a SECOND mulberry32 here, and the Dart side runs the same stream through
// the same injection points, so the unseeded half is comparable too.
//
// Date.now is pinned for the same reason: every stamp the match writes is then
// a fixed number both runtimes can agree on rather than something to blank out.
//
//   node tool/dump_match_orchestration_reference.mjs > test/fixtures/match_orchestration_reference.json

import { readFileSync } from 'node:fs';

const FIXED_NOW = 1700000000000;
Date.now = () => FIXED_NOW;

// The unseeded stream, made reproducible. Same algorithm as utils/random.js so
// the Dart test can drive an identical one.
let mathSeed = 1;
Math.random = () => {
  mathSeed |= 0;
  mathSeed = (mathSeed + 0x6d2b79f5) | 0;
  let t = Math.imul(mathSeed ^ (mathSeed >>> 15), 1 | mathSeed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};
const setMathSeed = (s) => { mathSeed = s; };

const rng = await import('../../merge-empire-fc/src/utils/random.js');
const me = await import('../../merge-empire-fc/src/engine/matchEngine.js');
const fm = await import('../../merge-empire-fc/src/data/formations.js');

const questRef = JSON.parse(
  readFileSync(new URL('../test/fixtures/quest_engine_reference.json', import.meta.url), 'utf8'),
);

const clone = (v) => JSON.parse(JSON.stringify(v));

// The reference save carries no match counters at all, and `undefined++` is NaN
// — so they are seeded here rather than discovered as a divergence later.
const baseState = (over = {}) => {
  const s = clone(questRef.state);
  s.progression.matchesPlayed = 12;
  s.progression.matchesWon = 5;
  s.progression.matchesDrawn = 3;
  s.progression.seasonWins = 2;
  s.progression.seasonDraws = 1;
  s.progression.seasonLosses = 1;
  s.progression.seasonAwardedPlayed = 4;
  s.progression.trophiesTotal = 0;
  s.progression.lastMatchAt = FIXED_NOW - 600000;
  s.progression.careerWins = 5;
  s.progression.careerDraws = 3;
  s.progression.careerGoalsFor = 14;
  s.careerStats = { leagueWins: 0, cupWins: 0, matchesWon: 5, totalMerges: 0 };
  s.squad.formation = '4-4-2';
  s.squad.lineup = fm.buildDefaultLineup('4-4-2', s.grid.cells);
  s.squad.strategyId = 'balanced';
  // Deep-merge only what the scenarios actually override.
  for (const [k, v] of Object.entries(over)) {
    if (v && typeof v === 'object' && !Array.isArray(v) && s[k] && typeof s[k] === 'object') {
      Object.assign(s[k], v);
    } else {
      s[k] = v;
    }
  }
  return s;
};

/// A squad old enough that injuries actually land, in the most physical league.
const agedSquad = (s) => {
  for (const c of s.grid.cells) if (c) c.seasonsPlayed = 14;
  s.progression.currentDivision = 'champions_cup';
  s.squad.lineup = fm.buildDefaultLineup(s.squad.formation, s.grid.cells);
  return s;
};

const out = { fixedNow: FIXED_NOW };

// ── what the JS is still the reference for ──────────────────────────────────
// The simulated-match scenarios that used to be dumped here were RETIRED when
// the Dart port's positional sim took over the scoreline: the JS still draws two
// Poissons, so it stopped describing a whole match. Those scenarios now live in
// test/support/positional_scenarios.dart and their golden is written by
// `dart run tool/dump_positional_golden.dart`. What remains here never simulates
// a match — the default XI, the formation ranking and the cooldowns — and stays
// pinned against the JS.
out.baseLineup = fm.buildDefaultLineup('4-4-2', baseState().grid.cells);

// ── bestFormationForFixture ───────────────────────────────────────────────
const tierSquad = (tier, count) => {
  const s = baseState();
  s.grid.cells = s.grid.cells.map((c, i) => {
    if (!c || i >= count) return null;
    return { ...c, definitionId: `player_t${tier}_${c.definitionId.split('_').pop()}` };
  });
  return s;
};

out.bestFormation = [];
for (const [label, build] of [
  ['refSave', () => baseState()],
  ['refSaveHome', () => baseState({ progression: { seasonMatchesPlayed: 5 } })],
  ['bareEleven', () => tierSquad(4, 11)],
  ['strong', () => tierSquad(8, 15)],
  ['unrolled', () => baseState({ progression: { seasonCount: 9, seasonOpponentRatings: {} } })],
  ['attackTactic', () => baseState({ squad: { strategyId: 'allOutAttack' } })],
]) {
  rng.setSeed(1);
  setMathSeed(1);
  const state = build();
  const best = me.bestFormationForFixture(state, { divisionId: 'regional_league' });
  out.bestFormation.push({ label, formationId: best.formationId, points: best.points, lineup: best.lineup });
}

// ── cooldowns ─────────────────────────────────────────────────────────────
out.cooldowns = [];
for (const [label, build] of [
  ['ready', () => baseState()],
  ['justPlayed', () => baseState({ progression: { lastMatchAt: FIXED_NOW } })],
  ['vip', () => baseState({ progression: { lastMatchAt: FIXED_NOW }, boosts: { vipActive: true, vipExpiresAt: FIXED_NOW + 60000 } })],
  ['vipExpired', () => baseState({ progression: { lastMatchAt: FIXED_NOW }, boosts: { vipActive: true, vipExpiresAt: FIXED_NOW - 1 } })],
  ['freeWindow', () => baseState({ progression: { lastMatchAt: FIXED_NOW }, boosts: { matchCooldownFreeUntil: FIXED_NOW + 60000 } })],
  ['seasonComplete', () => baseState({ progression: { seasonComplete: true } })],
  ['thinLineup', () => baseState({ squad: { lineup: [{ slotId: 'gk', slotPosition: 'GK', cardInstanceId: 'c0' }, { slotId: 'rb', slotPosition: 'DEF', cardInstanceId: null }] } })],
  ['championsCup', () => baseState({ progression: { currentDivision: 'champions_cup', lastMatchAt: FIXED_NOW } })],
]) {
  const state = build();
  const row = {
    label,
    effectiveCooldownMs: me.effectiveCooldownMs(state),
    canPlayMatch: me.canPlayMatch(state),
    matchCooldownRemaining: me.matchCooldownRemaining(state),
  };
  me.startMatchCooldown(state);
  row.afterStart = {
    lastMatchAt: state.progression.lastMatchAt,
    canPlayMatch: me.canPlayMatch(state),
  };
  out.cooldowns.push(row);
}

// startMatchCooldown only ever pushes the clock later, and survives a state with
// no progression at all.
out.cooldownFloor = (() => {
  const s = baseState({ progression: { lastMatchAt: FIXED_NOW + 999999 } });
  me.startMatchCooldown(s);
  return { lastMatchAt: s.progression.lastMatchAt };
})();

process.stdout.write(JSON.stringify(out));
