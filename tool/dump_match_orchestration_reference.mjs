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

// The save is ~100KB and almost none of it moves, so only what a match actually
// WRITES is recorded. The league pyramid and the discovered-player log are the
// bulk of it and neither is touched here.
// Per-card, only the fields a match can move, and only when it moved one — the
// definition and the instance id are invariant and the Dart side builds the same
// squad from the same base save.
const CARD_KEYS = ['injured', 'injuredAt', 'injuryDurationMs', 'form', 'energy',
  'energyUpdatedAt', 'stats'];

const digest = (s) => ({
  cells: Object.fromEntries((s.grid?.cells ?? []).filter(Boolean).map((c) => [
    c.instanceId,
    Object.fromEntries(CARD_KEYS.filter((k) => c[k] !== undefined).map((k) => [k, c[k]])),
  ])),
  lineup: s.squad?.lineup ?? null,
  progression: Object.fromEntries(Object.entries(s.progression ?? {})
    .filter(([k]) => k !== 'leaguePyramid' && k !== 'discoveredPlayers')),
  resources: s.resources ?? null,
  careerStats: s.careerStats ?? null,
  shop: s.shop ?? null,
  grudges: s.transferMarket?.grudges ?? null,
});

// Only the fields a re-simulation is allowed to rewrite — enough to prove the
// mutation happened without carrying a second copy of the whole match.
const resultDigest = (r) => ({
  homeGoals: r.homeGoals, awayGoals: r.awayGoals, won: r.won, drawn: r.drawn,
  coinsEarned: r.coinsEarned, injuryCount: r.injuryCount ?? null,
  injuredName: r.injuredName ?? null,
  // Cloned, not referenced: a re-simulation PUSHES to the live injuryLog, so an
  // aliased "before" would silently show the after.
  injuryLog: clone(r.injuryLog ?? null),
  hardSimInjuries: clone(r.hardSim?.injuries ?? null),
});

// One scenario: seed both streams, run `fn`, and record what came out AND what
// the save looks like afterwards. The state matters as much as the result —
// most of this function's job is bookkeeping.
const scenario = (name, seed, mathSeedValue, build, fn) => {
  rng.setSeed(seed);
  setMathSeed(mathSeedValue);
  const state = build();
  // The XI the match KICKED OFF with, shipped as input rather than rebuilt on
  // the Dart side. The lineup builder is a separate port with its own tests, and
  // letting it feed this one would confound two things at once.
  const lineupBefore = clone(state.squad?.lineup ?? null);
  const extra = fn(state);
  out[name] = {
    seed, mathSeed: mathSeedValue, lineupBefore, state: digest(state), ...extra,
  };
};

// ── simulateMatch ─────────────────────────────────────────────────────────
for (const seed of [1, 7, 12345, 987654]) {
  scenario(`easy_s${seed}`, seed, seed * 3 + 1, () => baseState(),
    (s) => ({ result: me.simulateMatch(s, 'regional_league') }));

  scenario(`hard_s${seed}`, seed, seed * 3 + 1,
    () => baseState({ settings: { hardMode: true } }),
    (s) => ({ result: me.simulateMatch(s, 'regional_league') }));
}

scenario('forceWin', 4242, 99, () => baseState(),
  (s) => ({ result: me.simulateMatch(s, 'regional_league', { forceWin: true }) }));

scenario('luckyBoot', 4242, 99, () => baseState({ shop: { luckyBootReady: true } }),
  (s) => ({ result: me.simulateMatch(s, 'regional_league') }));

scenario('grudge', 4242, 99,
  () => baseState({ transferMarket: { grudges: { regional_league_4: { boost: 6, matches: 2 } } } }),
  (s) => ({ result: me.simulateMatch(s, 'regional_league') }));

// Both sides in the drop zone in the second half of the season, which is the
// only state the relegation boost is ever applied in.
scenario('relegationZone', 555, 31,
  () => baseState({
    progression: {
      seasonMatchesPlayed: 9,
      playerTablePosition: 8,
      opponentTablePositions: { regional_league_2: 7 },
      stagnationBuffs: { regional_league: 3 },
    },
  }),
  (s) => ({ result: me.simulateMatch(s, 'regional_league') }));

// A fixture nobody has played, so the opponent's rating is rolled rather than
// read — the one seeded draw that happens before anything else.
scenario('unrolledOpponent', 20250817, 5,
  () => baseState({ progression: { seasonCount: 9, seasonOpponentRatings: {} } }),
  (s) => ({ result: me.simulateMatch(s, 'regional_league') }));

// No XI set: the ratings fall back to the healthy top eleven, and hard mode
// declines to run its segment sim at all.
scenario('noLineup', 616, 17, () => baseState({ squad: { lineup: [] } }),
  (s) => ({ result: me.simulateMatch(s, 'regional_league') }));

scenario('noLineupHard', 616, 17,
  () => baseState({ squad: { lineup: [] }, settings: { hardMode: true } }),
  (s) => ({ result: me.simulateMatch(s, 'regional_league') }));

// An old squad in the most physical division: injuries land, and in casual mode
// the sim plays the post-injury window a man down.
for (const seed of [3, 11, 29, 64]) {
  scenario(`injuryEasy_s${seed}`, seed, seed + 500, () => agedSquad(baseState()),
    (s) => ({ result: me.simulateMatch(s, 'champions_cup') }));
  scenario(`injuryHard_s${seed}`, seed, seed + 500,
    () => agedSquad(baseState({ settings: { hardMode: true } })),
    (s) => ({ result: me.simulateMatch(s, 'champions_cup') }));
}

// The last fixture of the season closes it.
scenario('seasonCloses', 88, 88,
  () => baseState({ progression: { seasonMatchesPlayed: 13 } }),
  (s) => ({ result: me.simulateMatch(s, 'regional_league') }));

// ── settlement ────────────────────────────────────────────────────────────
for (const [name, over, div] of [
  ['settleEasy', {}, 'regional_league'],
  ['settleHard', { settings: { hardMode: true } }, 'regional_league'],
]) {
  for (const seed of [2, 19]) {
    scenario(`${name}_s${seed}`, seed, seed * 7, () => baseState(over), (s) => {
      const result = me.simulateMatch(s, div);
      me.finalizeMatchOutcome(s, result);
      // Second call must be a no-op — it is reachable from both the popup's
      // full-time hook and from applyMatchRewards.
      me.finalizeMatchOutcome(s, result);
      me.applyMatchRewards(s, result);
      me.applyMatchRewards(s, result);
      return { result };
    });
  }
}

// A forced win and a forced defeat, so the form update takes both branches.
scenario('settleWin', 4242, 99, () => baseState(), (s) => {
  const result = me.simulateMatch(s, 'regional_league', { forceWin: true });
  me.applyMatchRewards(s, result);
  return { result };
});

// applyMatchRewards on its own settles everything — it finalizes first.
scenario('rewardsOnly', 77, 7, () => baseState(), (s) => {
  const result = me.simulateMatch(s, 'regional_league');
  me.applyMatchRewards(s, result);
  return { result };
});

// ── reSimulateRemainder ───────────────────────────────────────────────────
for (const [name, over] of [
  ['resimEasy', {}],
  ['resimHard', { settings: { hardMode: true } }],
]) {
  for (const [seed, fromMinute, strategyId] of [
    [5, 45, 'allOutAttack'],
    [5, 20, 'parkTheBus'],
    [5, 80, 'counterAttack'],
    [13, 45, 'highPress'],
    [13, 89, 'balanced'],
  ]) {
    scenario(`${name}_s${seed}_m${fromMinute}_${strategyId}`, seed, seed * 11,
      () => baseState(over), (s) => {
        const result = me.simulateMatch(s, 'regional_league');
        const before = resultDigest(result);
        const { newEvents } = me.reSimulateRemainder(
          result, fromMinute, strategyId, result.homeGoals, result.awayGoals, s,
        );
        return { before, result, newEvents };
      });
  }
}

// A tactic change cancels an injury whose minute has not been reached yet, then
// re-rolls the remainder at the new tactic's rate.
for (const seed of [3, 11, 29]) {
  scenario(`resimCancelsInjury_s${seed}`, seed, seed + 500,
    () => agedSquad(baseState()), (s) => {
      const result = me.simulateMatch(s, 'champions_cup');
      const before = resultDigest(result);
      const { newEvents } = me.reSimulateRemainder(
        result, 10, 'parkTheBus', result.homeGoals, result.awayGoals, s,
      );
      return { before, result, newEvents };
    });
}

// The event-cup path: strength is a fixed external rating, never the club squad.
for (const strategyId of ['balanced', 'allOutAttack', 'parkTheBus']) {
  scenario(`resimFixedRating_${strategyId}`, 31337, 3,
    () => baseState(), (s) => {
      const result = {
        divisionId: 'regional_league', isCup: true, fixedRating: true,
        anonymousPlayers: true, squadRating: 74, isHome: true,
        effOppAttackRating: 70, effOppDefenceRating: 71, opponentRating: 70,
        addedTime: 3, homeGoals: 0, awayGoals: 0, events: [], injuryLog: [],
      };
      const { newEvents } = me.reSimulateRemainder(result, 0, strategyId, 0, 0, s);
      return { result, newEvents };
    });
}

// A cup tie cannot end level, so a draw goes to penalties inside the re-sim.
scenario('resimCupShootout', 909, 13, () => baseState({ settings: { hardMode: false } }),
  (s) => {
    const result = {
      divisionId: 'regional_league', isCup: true, isHome: true,
      squadRating: 60, effOppAttackRating: 60, effOppDefenceRating: 61,
      opponentRating: 60, addedTime: 2, homeGoals: 1, awayGoals: 1,
      events: [], injuryLog: [], oppAttackRatio: 0.45,
    };
    // Past the final whistle, so nothing more is scored and the tie is still
    // level — which is the only way to reach the shootout branch.
    const { newEvents } = me.reSimulateRemainder(result, 92, 'balanced', 1, 1, s);
    return { result, newEvents };
  });

// ── _hardLiveRatings ──────────────────────────────────────────────────────
scenario('hardLive', 3, 503, () => agedSquad(baseState({ settings: { hardMode: true } })),
  (s) => {
    const result = me.simulateMatch(s, 'champions_cup');
    const at = {};
    for (const minute of [0, 20, 45, 70, 90]) {
      at[minute] = me._hardLiveRatings(result, minute, s, 'balanced');
      at[`minutesPlayed_${minute}`] = clone(result.hardSim.minutesPlayed);
    }
    return { result, at };
  });

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
