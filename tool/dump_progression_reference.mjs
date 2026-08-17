// Seeded reference output from the JS progression engine, for the Dart port to
// reproduce exactly.
//
// This is the differential test for the whole league layer: the pyramid it
// builds, the promotion/relegation shuffle, the fixture schedule and both kinds
// of table. Every scenario resets the shared seed first, so the numbers pin the
// RNG draw order as well as the arithmetic — the two things most likely to
// drift in a port and least likely to be caught by an assertion written by
// hand.
//
//   node tool/dump_progression_reference.mjs > test/fixtures/progression_reference.json

const rng = await import('../../merge-empire-fc/src/utils/random.js');
const prog = await import('../../merge-empire-fc/src/engine/progressionEngine.js');
const { DIVISIONS } = await import('../../merge-empire-fc/src/data/divisions.js');

const clone = (v) => JSON.parse(JSON.stringify(v));

/** A pyramid with a full, predictable complement in every division. */
const fullPyramid = () => {
  const out = {};
  for (const div of DIVISIONS) {
    const mid = Math.floor((div.opponentRatingRange[0] + div.opponentRatingRange[1]) / 2);
    out[div.id] = Array.from({ length: 8 }, (_, i) => ({
      name: `${div.id}_${i}`,
      rating: mid + i,
      formation: '4-4-2',
      attackRatio: 0.402,
    }));
  }
  return out;
};

const baseState = (over = {}) => ({
  clubName: 'Test Town',
  progression: {
    currentDivision: 'regional_league',
    seasonCount: 1,
    seasonMatchesPlayed: 0,
    seasonAwardedPlayed: 0,
    seasonWins: 0,
    seasonDraws: 0,
    seasonLosses: 0,
    leaguePyramid: null,
    seasonOpponents: [],
    seasonOpponentRatings: {},
    seasonFixtures: null,
    fixtureResults: {},
    ...over,
  },
});

const out = {};

// ── A pyramid built from nothing ────────────────────────────────────────────
rng.setSeed(4242);
{
  const state = baseState();
  out.freshPyramid = clone(prog.ensureLeaguePyramid(state));
}

// ── Legacy opponents carried into the player's league ───────────────────────
rng.setSeed(909);
{
  const state = baseState({
    seasonOpponents: Array.from({ length: 7 }, (_, i) => `Old Rival ${i}`),
    seasonOpponentRatings: { s1_o0: 61, s1_o3: 55 },
  });
  out.legacyCarryPyramid = clone(prog.ensureLeaguePyramid(state));
}

// ── A season-end shuffle across the whole ladder ────────────────────────────
rng.setSeed(31337);
{
  const state = baseState({ leaguePyramid: fullPyramid() });
  const statuses = {};
  prog.shufflePyramid(state, null, { statuses });
  out.shuffled = clone(state.progression.leaguePyramid);
  out.shuffledStatuses = clone(statuses);
}

// ── The same shuffle with the player's own division held back ───────────────
rng.setSeed(31337);
{
  const state = baseState({ leaguePyramid: fullPyramid() });
  prog.shufflePyramid(state, 'regional_league', {
    recentlyMoved: new Set(['regional_league_0']),
  });
  out.shuffledSkippingPlayerDivision = clone(state.progression.leaguePyramid);
}

// ── Season setup: opponents, ratings and the full 56-fixture schedule ───────
rng.setSeed(777);
{
  const state = baseState({ leaguePyramid: fullPyramid() });
  prog.initSeasonOpponents(state);
  out.seasonOpponents = clone(state.progression.seasonOpponents);
  out.seasonOpponentRatings = clone(state.progression.seasonOpponentRatings);
  out.seasonFixtures = clone(state.progression.seasonFixtures);
}

// ── The same schedule a season later, so the home/away flip is pinned too ───
rng.setSeed(777);
{
  const state = baseState({ leaguePyramid: fullPyramid(), seasonCount: 4 });
  prog.initSeasonOpponents(state);
  out.seasonFixturesSeason4 = clone(state.progression.seasonFixtures);
}

// ── The player's own table, part-way through a campaign ─────────────────────
rng.setSeed(555);
{
  const state = baseState({ leaguePyramid: fullPyramid() });
  prog.initSeasonOpponents(state);
  state.progression.seasonAwardedPlayed = 6;
  state.progression.seasonMatchesPlayed = 6;
  state.progression.seasonWins = 4;
  state.progression.seasonDraws = 1;
  state.progression.fixtureResults = {
    s1_m0: { homeGoals: 3, awayGoals: 1 },
    s1_m1: { homeGoals: 0, awayGoals: 2 },
    s1_m2: { homeGoals: 2, awayGoals: 2 },
    s1_m3: { homeGoals: 1, awayGoals: 0 },
    s1_m4: { homeGoals: 4, awayGoals: 2 },
    s1_m5: { homeGoals: 2, awayGoals: 0 },
  };
  out.leagueTable = clone(prog.buildLeagueTable(state));
  out.leagueTablePositions = clone(state.progression.opponentTablePositions);
  out.leagueTablePlayerPosition = state.progression.playerTablePosition;
  out.leagueTableTablePos = clone(state.progression.tablePos);
}

// ── The legacy fabricated table, for saves predating the schedule ───────────
rng.setSeed(555);
{
  const state = baseState({
    leaguePyramid: fullPyramid(),
    seasonOpponents: Array.from({ length: 7 }, (_, i) => `Rival ${i}`),
    seasonOpponentRatings: { s1_o0: 61, s1_o2: 44, s1_o5: 52 },
    seasonAwardedPlayed: 9,
    seasonWins: 5,
    seasonDraws: 2,
  });
  out.fabricatedTable = clone(prog.buildLeagueTable(state));
}

// ── A league the player isn't in ────────────────────────────────────────────
rng.setSeed(1010);
{
  const state = baseState({ leaguePyramid: fullPyramid(), seasonMatchesPlayed: 9 });
  out.pyramidTableElite = clone(prog.buildPyramidTable(state, 'elite_league'));
  out.pyramidTableSunday = clone(prog.buildPyramidTable(state, 'sunday_league'));
  // Drawing the same league twice must give the same table, and must not have
  // moved the shared stream on.
  out.pyramidTableEliteAgain = clone(prog.buildPyramidTable(state, 'elite_league'));
  out.streamAfterPyramidTables = Array.from({ length: 4 }, () => rng.random());
}

process.stdout.write(JSON.stringify(out));
