// Seeded reference output from the JS previewFixture.
//
// It is pure rating arithmetic — home advantage, stagnation, the relegation
// boost, the Lucky Boot and a grudge, layered in a particular order — which is
// exactly the sort of thing that drifts a point or two between two languages
// and quietly changes which quests get handed out.
//
//   node tool/dump_fixture_preview_reference.mjs > test/fixtures/fixture_preview_reference.json

const me = await import('../../merge-empire-fc/src/engine/matchEngine.js');
const ref = JSON.parse(
  (await import('node:fs')).readFileSync(
    new URL('../test/fixtures/quest_engine_reference.json', import.meta.url), 'utf8'),
);

const clone = (v) => JSON.parse(JSON.stringify(v));
const base = () => clone(ref.state);

const out = { scenarios: {}, fixtureIsHome: {}, attackRatio: {} };

const SCENARIOS = {
  plain: (s) => s,
  awayLeg: (s) => { s.progression.seasonMatchesPlayed = 9; return s; },
  unrolledOpponent: (s) => { s.progression.seasonOpponentRatings = {}; return s; },
  luckyBoot: (s) => { s.shop.luckyBootReady = true; return s; },
  grudge: (s) => {
    s.transferMarket.grudges = { regional_league_4: { boost: 3 } };
    return s;
  },
  stagnation: (s) => {
    s.progression.stagnationBuffs = { regional_league: 5 };
    return s;
  },
  bothRelegationZones: (s) => {
    s.progression.seasonMatchesPlayed = 9;
    s.progression.playerTablePosition = 8;
    s.progression.opponentTablePositions = { regional_league_2: 8 };
    return s;
  },
  championsCup: (s) => {
    s.progression.currentDivision = 'champions_cup';
    s.progression.stagnationBuffs = { champions_cup: 9 };
    return s;
  },
  proMode: (s) => { s.settings.hardMode = true; return s; },
  noLineup: (s) => { s.squad.lineup = []; return s; },
  emptySquad: (s) => { s.grid.cells = []; return s; },
};

for (const [name, mutate] of Object.entries(SCENARIOS)) {
  const p = me.previewFixture(mutate(base()));
  out.scenarios[name] = p === null ? null : clone(p);
}

for (const season of [1, 3, 7]) {
  for (let m = 0; m < 14; m++) {
    out.fixtureIsHome[`${season}|${m}`] = me.fixtureIsHome(season, m % 7, m);
  }
}

const ratioState = base();
out.attackRatio.known = me.getOpponentAttackRatio(ratioState, 'regional_league_3');
out.attackRatio.unknown = me.getOpponentAttackRatio(ratioState, 'Nobody FC');
const legacy = base();
legacy.progression.leaguePyramid.regional_league[0] = {
  name: 'Legacy FC', rating: 50, attackBias: 1.5,
};
out.attackRatio.legacyBias = me.getOpponentAttackRatio(legacy, 'Legacy FC');
const noPyramid = base();
delete noPyramid.progression.leaguePyramid;
out.attackRatio.noPyramid = me.getOpponentAttackRatio(noPyramid, 'regional_league_3');

process.stdout.write(JSON.stringify(out));
