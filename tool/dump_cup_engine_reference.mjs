// Seeded reference output from the JS cup engine.
//
// Both halves are RNG-heavy and order-sensitive: the bracket is a weighted draw
// per round out of the whole pyramid, and a tie samples goals, injuries and a
// shootout off the shared stream. A port can get every formula right and still
// be wrong if it draws its numbers in a different order.
//
// The save is the one the quest fixture ships, so both runtimes start from
// byte-identical input.
//
//   node tool/dump_cup_engine_reference.mjs > test/fixtures/cup_engine_reference.json

import { readFileSync } from 'node:fs';

const rng = await import('../../merge-empire-fc/src/utils/random.js');
const ce = await import('../../merge-empire-fc/src/engine/cupEngine.js');

const questRef = JSON.parse(
  readFileSync(new URL('../test/fixtures/quest_engine_reference.json', import.meta.url), 'utf8'),
);

const clone = (v) => JSON.parse(JSON.stringify(v));

// Wall-clock stamps are the one thing the two runtimes cannot agree on, so they
// are blanked on both sides rather than compared. The tests that care about
// them assert their SHAPE separately.
const TIME_KEYS = new Set(['startedAt', 'endedAt', 'lastMatchAt', 'injuredAt', 'energyUpdatedAt']);
const stripTimes = (v) => {
  if (Array.isArray(v)) return v.map(stripTimes);
  if (v && typeof v === 'object') {
    const out = {};
    for (const [k, val] of Object.entries(v)) out[k] = TIME_KEYS.has(k) ? null : stripTimes(val);
    return out;
  }
  return v;
};

/// A squad good enough to actually lift a cup — the reference save's own is a
/// 27-rated Regional side, and the bracket draws from the top of the pyramid,
/// so it loses in the first round on every seed tried.
const withStrongSquad = (s) => {
  for (const c of s.grid.cells) {
    if (!c) continue;
    const pos = c.definitionId.split('_').pop();
    c.definitionId = `player_t8_${pos}`;
  }
  return s;
};

const baseState = (over = {}) => {
  const s = clone(questRef.state);
  s.prestige = { level: 0 };
  s.careerStats = { leagueWins: 0, cupWins: 0 };
  s.club = {};
  s.progression.cups = { active: null, history: [], availableThisSeason: true };
  Object.assign(s.progression, over);
  return s;
};

const out = {};

// ── Which cup, and whether it can be entered ────────────────────────────────
out.cupForDivision = {};
out.cupAvailable = {};
for (const div of ['sunday_league', 'amateur_cup', 'regional_league',
  'national_league', 'elite_league', 'continental', 'champions_cup']) {
  const state = baseState({ currentDivision: div });
  out.cupForDivision[div] = ce.cupForDivision(state)?.id ?? null;
  out.cupAvailable[div] = ce.cupAvailable(state);
}

// ── The bracket draw ────────────────────────────────────────────────────────
out.brackets = {};
for (const [label, seed, div] of [
  ['regionalA', 4242, 'regional_league'],
  ['regionalB', 77, 'regional_league'],
  ['worldCup', 9, 'champions_cup'],
]) {
  rng.setSeed(seed);
  const state = baseState({ currentDivision: div });
  const active = ce.startCup(state);
  out.brackets[label] = {
    active: stripTimes(clone(active)),
    availableAfter: ce.cupAvailable(state),
  };
}

// ── A whole run and the one-shot path — RETIRED ─────────────────────────────
// A tie is decided by the Dart port's positional sim, which the JS does not
// have, so the simulated runs that were dumped here moved to
// test/support/positional_scenarios.dart and `dart run
// tool/dump_positional_golden.dart`. The draw and the Lucky Boot never simulate
// a match and stay pinned against the JS.

// ── The Lucky Boot is spent by the PREPARE, not the commit ──────────────────
rng.setSeed(4242);
{
  const state = baseState({ currentDivision: 'regional_league' });
  state.shop.luckyBootReady = true;
  ce.startCup(state);
  const prepared = ce.prepareCupRound(state);
  out.luckyBoot = {
    opponentRating: prepared.opponentRating,
    stillReady: !!state.shop.luckyBootReady,
  };
  rng.setSeed(4242);
  const plain = baseState({ currentDivision: 'regional_league' });
  ce.startCup(plain);
  out.luckyBoot.plainRating = ce.prepareCupRound(plain).opponentRating;
}

process.stdout.write(JSON.stringify(out));
