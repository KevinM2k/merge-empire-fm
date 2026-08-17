// Seeded reference output from the JS quest engine.
//
// The state is BUILT HERE and dumped alongside the answers, so the Dart test
// feeds the port byte-identical input rather than trying to reconstruct it —
// which for a save with a squad, a lineup and a league table is most of the
// divergence risk on its own.
//
//   node tool/dump_quest_engine_reference.mjs > test/fixtures/quest_engine_reference.json

const rng = await import('../../merge-empire-fc/src/utils/random.js');
const qe = await import('../../merge-empire-fc/src/engine/questEngine.js');
const { QUEST_BANK, getQuest, resolveTarget } = await import('../../merge-empire-fc/src/data/quests.js');
const { PLAYERS } = await import('../../merge-empire-fc/src/data/players.js');
const { DIVISIONS } = await import('../../merge-empire-fc/src/data/divisions.js');
const { FORMATIONS } = await import('../../merge-empire-fc/src/data/formations.js');

const clone = (v) => JSON.parse(JSON.stringify(v));

// ── A save with a real squad, a set XI and a league in progress ─────────────

const defFor = (pos, tier) =>
  PLAYERS.find((p) => p.position === pos && p.tier === tier) ??
  PLAYERS.find((p) => p.position === pos);

const card = (i, pos, tier, extra = {}) => ({
  instanceId: `c${i}`,
  definitionId: defFor(pos, tier).id,
  seasonsPlayed: 0,
  ...extra,
});

const SQUAD = [
  card(0, 'GK', 3),
  card(1, 'DEF', 3), card(2, 'DEF', 3), card(3, 'DEF', 4), card(4, 'DEF', 3),
  card(5, 'MID', 4), card(6, 'MID', 3), card(7, 'MID', 4), card(8, 'MID', 3),
  card(9, 'FWD', 4, { seasonsPlayed: 5 }), card(10, 'FWD', 3),
  // Two on the bench, so the substitution quests are feasible.
  card(11, 'FWD', 3), card(12, 'MID', 3),
];

const formation = FORMATIONS['4-4-2'];
const lineup = formation.slots.map((s, i) => ({
  slotId: s.id,
  slotPosition: s.position,
  cardInstanceId: SQUAD[i]?.instanceId ?? null,
}));

const pyramid = {};
for (const div of DIVISIONS) {
  const mid = Math.floor((div.opponentRatingRange[0] + div.opponentRatingRange[1]) / 2);
  pyramid[div.id] = Array.from({ length: 8 }, (_, i) => ({
    name: `${div.id}_${i}`,
    rating: mid + i,
    formation: '4-4-2',
    attackRatio: 0.402,
  }));
}

const baseState = (over = {}) => clone({
  clubName: 'Test Town',
  grid: { cells: [...SQUAD, null, null] },
  squad: { lineup, formation: '4-4-2', strategyId: 'balanced', bench: [] },
  settings: { hardMode: false },
  resources: { fanCoins: 0, gems: 10, trophies: 0 },
  clubAssets: {
    TRAINING: { owned: true, tier: 6, invested: 0, tapCount: 3 },
    MERCH: { owned: false, tier: 0, invested: 0, tapCount: 0 },
    STADIUM: { owned: true, tier: 2, invested: 0, tapCount: 1 },
    MEDIA: { owned: false, tier: 0, invested: 0, tapCount: 0 },
    SPONSOR: { owned: false, tier: 0, invested: 0, tapCount: 0 },
    ACADEMY: { owned: false, tier: 0, invested: 0, tapCount: 0 },
    FANZONE: { owned: true, tier: 3, invested: 0, tapCount: 0 },
  },
  shop: {},
  boosts: {},
  stats: { penaltyRounds: 1, penaltiesScored: 2 },
  gemGrants: { questDivisionFirsts: [] },
  definitionRatios: {},
  transferMarket: { grudges: {} },
  progression: {
    currentDivision: 'regional_league',
    seasonCount: 3,
    seasonMatchesPlayed: 4,
    seasonOpponents: Array.from({ length: 7 }, (_, i) => `regional_league_${i}`),
    seasonOpponentRatings: Object.fromEntries(
      Array.from({ length: 7 }, (_, i) => [`s3_o${i}`, 44 + i]),
    ),
    leaguePyramid: pyramid,
    fixtureResults: {},
    discoveredPlayers: [],
    stagnationBuffs: {},
    opponentTablePositions: {},
    ...over,
  },
});

const out = { state: baseState() };

// ── questContext ────────────────────────────────────────────────────────────
rng.setSeed(1);
{
  const ctx = qe.questContext(baseState(), 'match');
  out.questContextMatch = clone(ctx);
  out.questContextSeason = clone(qe.questContext(baseState(), 'season'));
}

// ── rollableQuests / rollQuests, seeded ─────────────────────────────────────
for (const [label, seed, scope] of [
  ['matchA', 4242, 'match'],
  ['matchB', 99, 'match'],
  ['seasonA', 4242, 'season'],
  ['seasonB', 7, 'season'],
]) {
  rng.setSeed(seed);
  const state = baseState();
  out[`rollable_${label}`] = qe.rollableQuests(state, scope).map((d) => d.id);
  rng.setSeed(seed);
  const state2 = baseState();
  out[`roll_${label}`] = clone(qe.rollQuests(state2, scope, 3));
  out[`recent_${label}`] = clone(state2.quests.recent);
}

// ── The full match track roll, and the season track roll ────────────────────
rng.setSeed(31337);
{
  const state = baseState();
  out.matchTrack = clone(qe.rollMatchQuests(state, 's3_m4'));
  out.matchTrackAgain = clone(qe.rollMatchQuests(state, 's3_m4'));
}
rng.setSeed(31337);
{
  const state = baseState();
  out.seasonTrack = clone(qe.rollSeasonQuests(state, 3));
  out.seasonBaselines = clone(state.quests.seasonBaselines);
}

// ── evaluateMatchQuest across a battery of results ──────────────────────────

const goal = (minute, team, scorerInstanceId = null) =>
  ({ type: 'goal', minute, team, scorerInstanceId });

const RESULTS = {
  routineWin: {
    won: true, drawn: false, homeGoals: 2, awayGoals: 0, isHome: true,
    injuryCount: 0, subsUsed: 0, strategyChanged: false,
    finalStrategy: 'balanced', strategiesUsed: ['balanced'],
    effectiveSquadRating: 60, effectiveOppRating: 50,
    ourDefenceRating: 60, effOppAttackRating: 50,
    events: [goal(20, 'home', 'c9'), goal(70, 'home', 'c10')],
  },
  comebackAwayThriller: {
    won: true, drawn: false, homeGoals: 3, awayGoals: 2, isHome: false,
    injuryCount: 1, subsUsed: 2, subbedOnIds: ['c11'], strategyChanged: true,
    finalStrategy: 'allOutAttack',
    strategiesUsed: ['balanced', 'highPress', 'allOutAttack'],
    coachAskedFor: ['parkTheBus'], followedCoachSuggestion: false,
    effectiveSquadRating: 55, effectiveOppRating: 65,
    ourDefenceRating: 50, effOppAttackRating: 66,
    events: [
      goal(5, 'away'), goal(30, 'away'),
      goal(44, 'home', 'c9'), goal(47, 'home', 'c9'),
      goal(89, 'home', 'c11'),
      { type: 'injury', minute: 60 },
      { type: 'no_sub', minute: 60 },
    ],
  },
  hatTrickRout: {
    won: true, drawn: false, homeGoals: 4, awayGoals: 1, isHome: true,
    injuryCount: 0, subsUsed: 3, strategyChanged: false,
    finalStrategy: 'counterAttack', strategiesUsed: ['counterAttack'],
    effectiveSquadRating: 70, effectiveOppRating: 48,
    ourDefenceRating: 68, effOppAttackRating: 45,
    events: [
      goal(3, 'home', 'c9'), goal(12, 'home', 'c9'), goal(40, 'home', 'c9'),
      goal(55, 'away'), goal(80, 'home', 'c0'),
    ],
  },
  goallessDraw: {
    won: false, drawn: true, homeGoals: 0, awayGoals: 0, isHome: false,
    injuryCount: 0, subsUsed: 0, strategyChanged: false,
    finalStrategy: 'parkTheBus', strategiesUsed: ['parkTheBus'],
    effectiveSquadRating: 50, effectiveOppRating: 60,
    ourDefenceRating: 45, effOppAttackRating: 62,
    events: [],
  },
  heavyDefeat: {
    won: false, drawn: false, homeGoals: 1, awayGoals: 4, isHome: true,
    injuryCount: 2, subsUsed: 1, strategyChanged: true,
    finalStrategy: 'balanced', strategiesUsed: ['balanced', 'allOutAttack'],
    coachAskedFor: ['parkTheBus', 'balanced'], followedCoachSuggestion: true,
    effectiveSquadRating: 48, effectiveOppRating: 72,
    ourDefenceRating: 40, effOppAttackRating: 74,
    events: [
      goal(10, 'away'), goal(22, 'away'), goal(35, 'home', 'c3'),
      goal(60, 'away'), goal(85, 'away'), { type: 'injury', minute: 15 },
    ],
  },
  defenderWinner: {
    won: true, drawn: false, homeGoals: 1, awayGoals: 0, isHome: false,
    injuryCount: 0, subsUsed: 2, subbedOnIds: ['c12'], strategyChanged: false,
    finalStrategy: 'highPress', strategiesUsed: ['highPress'],
    coachAskedFor: ['balanced'], followedCoachSuggestion: false,
    effectiveSquadRating: 52, effectiveOppRating: 58,
    ourDefenceRating: 48, effOppAttackRating: 60,
    events: [goal(88, 'home', 'c3')],
  },
};

const evalState = baseState();
out.results = clone(RESULTS);
out.evaluate = {};
for (const [name, result] of Object.entries(RESULTS)) {
  const row = {};
  for (const def of QUEST_BANK.filter((d) => d.scope === 'match')) {
    for (const divIdx of [0, 3, 6]) {
      const target = resolveTarget(def, divIdx);
      row[`${def.id}@${divIdx}`] =
        !!qe.evaluateMatchQuest(evalState, def, target, result);
    }
  }
  out.evaluate[name] = row;
}

// ── liveMatchQuestStatus, walked through a match ────────────────────────────
out.live = {};
for (const [name, result] of Object.entries(RESULTS)) {
  const row = {};
  for (const minute of [0, 15, 16, 46, 60, 89, 90]) {
    const fired = (result.events ?? []).filter((e) => (e.minute ?? 0) <= minute);
    const partial = qe.partialMatchResult(result, fired, minute);
    for (const def of QUEST_BANK.filter((d) => d.scope === 'match')) {
      const target = resolveTarget(def, 3);
      row[`${def.id}@${minute}`] =
        qe.liveMatchQuestStatus(evalState, def, target, partial);
    }
  }
  out.live[name] = row;
}

// ── partialMatchResult itself ───────────────────────────────────────────────
out.partials = {};
for (const [name, result] of Object.entries(RESULTS)) {
  out.partials[name] = {};
  for (const minute of [0, 46, 90]) {
    const fired = (result.events ?? []).filter((e) => (e.minute ?? 0) <= minute);
    const p = qe.partialMatchResult(result, fired, minute);
    out.partials[name][minute] = {
      homeGoals: p.homeGoals, awayGoals: p.awayGoals,
      injuryCount: p.injuryCount, won: p.won, drawn: p.drawn,
      minute: p.minute, duration: p.duration,
    };
  }
}

// ── applyMatchToSeasonQuests: counters and streaks ──────────────────────────
rng.setSeed(31337);
{
  const state = baseState();
  qe.rollSeasonQuests(state, 3);
  const steps = [];
  for (const name of ['routineWin', 'comebackAwayThriller', 'goallessDraw', 'heavyDefeat', 'defenderWinner']) {
    qe.applyMatchToSeasonQuests(state, RESULTS[name]);
    steps.push({
      after: name,
      streaks: clone(state.quests.streaks),
      tally: clone(state.quests.seasonTally),
      track: clone(state.quests.season),
    });
  }
  out.seasonAccumulation = steps;
}

// ── resolveMatchQuests, league and cup ──────────────────────────────────────
for (const [label, extra] of [['league', {}], ['cup', { isCup: true }]]) {
  rng.setSeed(31337);
  const state = baseState();
  qe.rollMatchQuests(state, 's3_m4');
  qe.rollSeasonQuests(state, 3);
  const rows = qe.resolveMatchQuests(state, { ...RESULTS.hatTrickRout, ...extra });
  out[`resolve_${label}`] = {
    rows: clone(rows),
    coins: state.resources.fanCoins,
    activeAfter: clone(state.quests.match.active),
    fixtureKeyAfter: state.quests.match.fixtureKey ?? null,
  };
}

// ── Rerolling ───────────────────────────────────────────────────────────────
rng.setSeed(555);
{
  const state = baseState();
  qe.rollSeasonQuests(state, 3);
  const before = state.quests.season.map((c) => c.id);
  const first = qe.rerollQuests(state);
  const second = qe.rerollQuests(state);
  const third = qe.rerollQuests(state);
  out.reroll = {
    before,
    first: clone(first),
    second: clone(second),
    third: clone(third),
    gemsAfter: state.resources.gems,
    freeUsed: state.quests.seasonFreeRerollsUsed,
    track: state.quests.season.map((c) => c.id),
  };
}

// ── Targets, progress and the season fit ────────────────────────────────────
out.questTargets = {};
for (const def of QUEST_BANK) {
  for (const divIdx of [0, 3, 6]) {
    out.questTargets[`${def.id}@${divIdx}`] =
      qe.questTarget(def, baseState(), divIdx);
  }
}

out.fitsInSeason = {};
for (const def of QUEST_BANK.filter((d) => d.scope === 'season')) {
  for (const [left, soFar] of [[14, 0], [4, 0], [4, 2], [1, 0], [0, 0]]) {
    const target = resolveTarget(def, 3);
    out.fitsInSeason[`${def.id}|${left}|${soFar}`] =
      qe.fitsInSeason(def, target, soFar, left);
  }
}

// ── The capstone ────────────────────────────────────────────────────────────
rng.setSeed(31337);
{
  const state = baseState();
  qe.rollSeasonQuests(state, 3);
  for (const inst of state.quests.season) {
    inst.completed = true;
    inst.progress = inst.target;
  }
  const claims = state.quests.season.map((inst) => clone(qe.claimQuest(state, inst.id)));
  out.capstone = {
    claims: claims.map((c) => ({ ok: c.ok, coins: c.granted?.coins ?? 0, capstone: c.capstone ?? null })),
    gems: state.resources.gems,
    ledger: clone(state.gemGrants.questDivisionFirsts),
    // A second run must pay nothing.
    again: clone(qe.checkDivisionCapstone(state)),
  };
}

// ── Sweeping ────────────────────────────────────────────────────────────────
rng.setSeed(31337);
{
  const state = baseState();
  qe.rollSeasonQuests(state, 3);
  state.quests.season[0].completed = true;
  state.quests.season[0].progress = state.quests.season[0].target;
  out.sweep = {
    result: clone(qe.sweepUnclaimedSeasonQuests(state)),
    coins: state.resources.fanCoins,
    unclaimedAfter: qe.unclaimedCount(state),
  };
}

process.stdout.write(JSON.stringify(out));
