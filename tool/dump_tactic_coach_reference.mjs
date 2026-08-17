// Reference output from the JS tactic coach.
//
// Nothing here draws a random number, which is the point: the coach's whole
// claim is that it and the simulation cannot disagree, and it earns that by
// computing expected points EXACTLY from the two Poissons the sim samples. So
// every number below is reproducible, and a port that gets one of them wrong is
// giving different advice from the game it is advising about.
//
// The squad-shaped half (injuryCostPoints, baselineInjuryRisk) runs against the
// save the quest fixture ships, so both runtimes start from identical input.
//
//   node tool/dump_tactic_coach_reference.mjs > test/fixtures/tactic_coach_reference.json

import { readFileSync } from 'node:fs';

const me = await import('../../merge-empire-fc/src/engine/matchEngine.js');
const fm = await import('../../merge-empire-fc/src/data/formations.js');

const questRef = JSON.parse(
  readFileSync(new URL('../test/fixtures/quest_engine_reference.json', import.meta.url), 'utf8'),
);

const clone = (v) => JSON.parse(JSON.stringify(v));

const STRATS = Object.keys(me.STRATEGIES);

// Matchups spread across the ladder: level, favourite, underdog, and the two
// ends of the scale where goalRateLambda's floor and soft cap bite.
const MATCHUPS = [
  { name: 'level',        ourAtk: 60, ourDef: 60, oppAtk: 60, oppDef: 60 },
  { name: 'favourite',    ourAtk: 78, ourDef: 76, oppAtk: 54, oppDef: 55 },
  { name: 'underdog',     ourAtk: 41, ourDef: 40, oppAtk: 72, oppDef: 70 },
  { name: 'lopsided',     ourAtk: 85, ourDef: 35, oppAtk: 62, oppDef: 61 },
  { name: 'sunday',       ourAtk: 22, ourDef: 24, oppAtk: 23, oppDef: 25 },
  { name: 'championsCup', ourAtk: 96, ourDef: 95, oppAtk: 94, oppDef: 97 },
];

// Shapes the AI actually fields, by their attack share — Counter Attack's
// multiplier reads this and nothing else on the dial does.
const RATIOS = [null, 0.35, 0.402, 0.43, 0.457, 0.5];

const out = {};

// ── tacticExpectedPoints ──────────────────────────────────────────────────
out.expectedPoints = [];
for (const m of MATCHUPS) {
  for (const id of STRATS) {
    for (const opts of [
      { fraction: 1, margin: 0, oppAttackRatio: null },
      { fraction: 1, margin: 0, oppAttackRatio: 0.457 },
      { fraction: 0.25, margin: -2, oppAttackRatio: 0.402 },
      { fraction: 0.25, margin: 2, oppAttackRatio: null },
      { fraction: 0.5, margin: 1, oppAttackRatio: 0.35 },
      { fraction: 0, margin: 0, oppAttackRatio: null },
    ]) {
      out.expectedPoints.push({
        matchup: m.name, strategyId: id, ...opts,
        points: me.tacticExpectedPoints(m.ourAtk, m.ourDef, m.oppAtk, m.oppDef,
          me.STRATEGIES[id], opts),
      });
    }
  }
}

// A tactic's swing is a mean-preserving lottery, so it must be scored as the
// average of its hot and cold branches rather than at its mean. Pinning both
// tells a port which of the two it got.
out.swingBranching = (() => {
  const counter = me.STRATEGIES.counterAttack;
  return {
    scored: me.tacticExpectedPoints(73, 72, 60, 61, counter),
    atMean: me.tacticExpectedPoints(73, 72, 60, 61, { ...counter, swing: 0 }),
  };
})();

// ── suggestTactic ─────────────────────────────────────────────────────────
out.suggest = [];
for (const m of MATCHUPS) {
  for (const opts of [
    {},
    { benchCover: 0 },
    { benchCover: 1 },
    { benchCover: 2 },
    { fraction: 0.2, margin: -2 },
    { fraction: 0.2, margin: 2 },
    { fraction: 0.75, margin: 2 },
    { fraction: 0.75, margin: 2, oppAttackRatio: 0.457 },
    { fraction: 0.5, margin: 0, injuryRisk: 0.2, injuryCost: 0.4 },
    { fraction: 1, margin: 0, injuryRisk: 0.35, injuryCost: 1.2, benchCover: 4 },
  ]) {
    const r = me.suggestTactic(m.ourAtk, m.ourDef, m.oppAtk, m.oppDef, opts);
    out.suggest.push({
      matchup: m.name,
      opts: { ...opts, benchCover: opts.benchCover ?? null },
      id: r.id,
      expectedPoints: r.expectedPoints,
      thinSquad: r.thinSquad,
      heldOffSittingBack: r.heldOffSittingBack,
      ranked: r.ranked.map((e) => ({
        id: e.id, points: e.points, injuryPenalty: e.injuryPenalty,
        expectedPoints: e.expectedPoints,
      })),
    });
  }
}

// ── the squad-shaped half ─────────────────────────────────────────────────

// The reference save's lineup carries only card ids — every slot reads as MID.
// That is fine for parity but it exercises none of the position weighting, so
// the same squad is also run through a real formation's slots.
const withRealLineup = (s, formationId) => {
  s.squad.formation = formationId;
  s.squad.lineup = fm.buildDefaultLineup(formationId, s.grid.cells);
  return s;
};

const tierSquad = (tier, count) => {
  const s = clone(questRef.state);
  s.grid.cells = s.grid.cells.map((c, i) => {
    if (!c || i >= count) return null;
    const pos = c.definitionId.split('_').pop();
    return { ...c, definitionId: `player_t${tier}_${pos}` };
  });
  return s;
};

out.baselineInjuryRisk = [];
for (const divisionId of [null, 'sunday_league', 'regional_league', 'champions_cup']) {
  for (const seasons of [0, 5, 10, 14]) {
    const s = clone(questRef.state);
    for (const c of s.grid.cells) if (c) c.seasonsPlayed = seasons;
    out.baselineInjuryRisk.push({
      divisionId, seasons, risk: me.baselineInjuryRisk(s, divisionId),
    });
  }
}

// A knock's cost is almost entirely a question of who replaces him, so the
// bench depth is the variable that matters here.
out.injuryCostPoints = [];
for (const [label, state] of [
  ['refSave', clone(questRef.state)],
  ['refSave433', withRealLineup(clone(questRef.state), '4-3-3')],
  ['refSave532', withRealLineup(clone(questRef.state), '5-3-2')],
  ['bareEleven', withRealLineup(tierSquad(4, 11), '4-4-2')],
  ['deepBench', withRealLineup(tierSquad(4, 15), '4-4-2')],
  ['noLineup', (() => { const s = clone(questRef.state); s.squad.lineup = []; return s; })()],
]) {
  for (const opts of [{ fraction: 1, margin: 0 }, { fraction: 0.25, margin: -1 }]) {
    out.injuryCostPoints.push({
      label, ...opts,
      cost: me.injuryCostPoints(state, 60, 61, opts),
    });
  }
}

out.constants = {
  tacticMinBenchCover: me.TACTIC_MIN_BENCH_COVER,
  leadProtectFraction: me.LEAD_PROTECT_FRACTION,
  injuryFutureMatches: me.INJURY_FUTURE_MATCHES,
};

// The lineups the squad-shaped cases were scored against, so the Dart side runs
// on the same eleven rather than rebuilding them through its own builder.
out.lineups = {
  refSave433: fm.buildDefaultLineup('4-3-3', clone(questRef.state).grid.cells),
  refSave532: fm.buildDefaultLineup('5-3-2', clone(questRef.state).grid.cells),
  bareEleven: fm.buildDefaultLineup('4-4-2', tierSquad(4, 11).grid.cells),
  deepBench: fm.buildDefaultLineup('4-4-2', tierSquad(4, 15).grid.cells),
};

process.stdout.write(JSON.stringify(out, null, 2));
