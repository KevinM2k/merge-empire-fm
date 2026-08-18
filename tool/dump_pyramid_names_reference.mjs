// Reference output from the JS pyramid-names engine.
//
// A rename is a PROPAGATION — the same string lives in the pyramid, the
// fixtures, the season opponents, the table positions, last season's badges,
// the last result, an active cup run's opponents, results and scout blurbs, and
// the transfer market's pending offer and grudges. Miss one and the club is
// renamed everywhere the player can see except the one screen that still calls
// it by its old name, which is why the whole state is dumped after each rename
// rather than a summary of it.
//
// The other half is the two-phase apply. Re-applying a preset after a few
// seasons of promotion and relegation routinely asks two clubs to swap names,
// and doing that in one pass means the second rename collides with a name the
// first one just took. The swap cases below are the ones that catch it.
//
// The pyramid is synthetic rather than generated, so the collisions are exact
// and neither runtime has to agree about the name generator to agree here.
//
//   node tool/dump_pyramid_names_reference.mjs > test/fixtures/pyramid_names_reference.json

// Both are pinned: a preset id is `pyr_<now>_<random*1e6>` and lands in the save.
let NOW = 1_700_000_000_000;
Date.now = () => NOW;
let RAND = 0.123456;
Math.random = () => RAND;

const pne = await import('../../merge-empire-fc/src/engine/pyramidNamesEngine.js');
const { DIVISIONS } = await import('../../merge-empire-fc/src/data/divisions.js');

const clone = (v) => JSON.parse(JSON.stringify(v));

const DIV_IDS = DIVISIONS.map((d) => d.id);

/// Eight teams a division, named for their slot so a swap is unmistakable.
const makeState = () => {
  const leaguePyramid = {};
  for (const divId of DIV_IDS) {
    leaguePyramid[divId] = Array.from({ length: 8 }, (_, i) => ({
      name: `${divId} FC ${i}`, rating: 40 + i, form: 0,
    }));
  }
  return {
    clubName: 'Player Rovers',
    settings: {},
    progression: {
      currentDivision: 'regional_league',
      leaguePyramid,
      seasonOpponents: ['regional_league FC 0', 'regional_league FC 1'],
      seasonFixtures: [
        { homeTeam: 'Player Rovers', awayTeam: 'regional_league FC 0', played: false },
        { homeTeam: 'regional_league FC 0', awayTeam: 'regional_league FC 1', played: true },
      ],
      opponentTablePositions: { 'regional_league FC 0': 3, 'regional_league FC 1': 5 },
      lastSeasonStatus: { teams: { 'regional_league FC 0': 'promoted', 'regional_league FC 2': 'relegated' } },
      lastMatchResult: { opponentName: 'regional_league FC 0', won: true },
      cups: {
        active: {
          cupId: 'regional_cup',
          opponents: ['regional_league FC 0', 'elite_league FC 4'],
          results: [{ round: 0, opponentName: 'regional_league FC 0', won: true }],
          contexts: ['regional_league FC 0 have won four in a row.', null],
        },
        history: [],
      },
    },
    transferMarket: {
      pendingOffer: { fromTeam: 'regional_league FC 0', amount: 5000 },
      grudges: { 'regional_league FC 0': 2, 'elite_league FC 4': 1 },
    },
  };
};

const out = { divisionIds: DIV_IDS, state: makeState() };
out.constants = {
  teamNameMax: pne.TEAM_NAME_MAX,
  teamNameMin: pne.TEAM_NAME_MIN,
  maxPresets: pne.MAX_PRESETS,
};

out.allTeamNames = [...pne.allTeamNames(makeState())].sort();

// ── Validation ──────────────────────────────────────────────────────────────
out.validate = [];
for (const [label, raw, opts] of [
  ['fine', 'Northfield Athletic', {}],
  ['trimmed', '   Northfield Athletic   ', {}],
  ['tooLong', 'A club with a truly enormous and unreasonable name', {}],
  ['tooShort', 'A', {}],
  ['empty', '', {}],
  ['blank', '   ', {}],
  ['null', null, {}],
  ['profanity', 'Damn United', {}],
  ['duplicateOfPyramid', 'regional_league FC 3', {}],
  ['duplicateOfPlayerClub', 'Player Rovers', {}],
  ['sameAsCurrent', 'regional_league FC 3', { current: 'regional_league FC 3' }],
  ['currentButProfane', 'Damn United', { current: 'Damn United' }],
]) {
  out.validate.push({ label, raw, current: opts.current ?? null, ...pne.validateTeamName(makeState(), raw, opts) });
}

// ── Renaming ────────────────────────────────────────────────────────────────
out.rename = [];
for (const [label, oldName, newName] of [
  ['propagates', 'regional_league FC 0', 'Northfield Athletic'],
  ['untouchedElsewhere', 'elite_league FC 4', 'Kingsbridge City'],
  ['unknownTeam', 'Nobody FC', 'Northfield Athletic'],
  ['sameName', 'regional_league FC 0', 'regional_league FC 0'],
  ['emptyOld', '', 'Northfield Athletic'],
  ['emptyNew', 'regional_league FC 0', ''],
  ['nullOld', null, 'Northfield Athletic'],
]) {
  const state = makeState();
  const ok = pne.renameTeam(state, oldName, newName);
  out.rename.push({ label, oldName, newName, ok, state: clone(state) });
}

// A save with none of the optional branches must not throw on the way through.
out.renameBareState = (() => {
  const state = { progression: { leaguePyramid: { regional_league: [{ name: 'Alpha' }] } } };
  const ok = pne.renameTeam(state, 'Alpha', 'Beta');
  return { ok, state: clone(state) };
})();

// ── Applying a list ─────────────────────────────────────────────────────────
const applyCase = (label, divId, lines) => {
  const state = makeState();
  const result = pne.applyNameList(state, divId, lines);
  return {
    label, divId, lines,
    applied: result.applied,
    skipped: result.skipped,
    names: DIV_IDS.reduce((acc, id) => {
      acc[id] = state.progression.leaguePyramid[id].map((t) => t.name);
      return acc;
    }, {}),
    state: clone(state),
  };
};

out.applyNameList = [
  applyCase('renamesInPlace', 'regional_league',
    ['Northfield Athletic', 'Kingsbridge City', '', 'Ashworth Town']),
  // The swap is the case the two-phase pass exists for.
  applyCase('swapsTwoNames', 'regional_league',
    ['regional_league FC 1', 'regional_league FC 0']),
  applyCase('rotatesThree', 'regional_league',
    ['regional_league FC 1', 'regional_league FC 2', 'regional_league FC 0']),
  applyCase('unchangedIsNotApplied', 'regional_league',
    ['regional_league FC 0', 'regional_league FC 1']),
  applyCase('refusesShortProfaneAndDuplicate', 'regional_league',
    ['A', 'Damn United', 'regional_league FC 7', 'Player Rovers', 'Fine Name']),
  applyCase('refusesDuplicateWithinTheBatch', 'regional_league',
    ['Twin Town', 'Twin Town']),
  applyCase('pastTheEndOfTheDivision', 'regional_league',
    ['A Name', '', '', '', '', '', '', '', 'Ninth Name', 'Tenth Name']),
  applyCase('unknownDivision', 'not_a_division', ['Whatever United']),
  applyCase('emptyList', 'regional_league', []),
  applyCase('nullList', 'regional_league', null),
];

// ── Presets ─────────────────────────────────────────────────────────────────
out.savePreset = (() => {
  const state = makeState();
  const steps = [];
  const snap = (label, r) => steps.push({
    label, ok: r.ok, reason: r.reason ?? null,
    preset: r.preset ? clone(r.preset) : null,
    count: state.settings.customPyramids?.length ?? 0,
  });

  snap('first', pne.savePreset(state, 'My League'));
  // A different id every time, because both halves of it move.
  NOW = 1_700_000_111_000; RAND = 0.7654321;
  snap('second', pne.savePreset(state, 'Another'));
  // Same label overwrites in place rather than appending.
  pne.renameTeam(state, 'regional_league FC 0', 'Northfield Athletic');
  NOW = 1_700_000_222_000;
  snap('overwriteByLabel', pne.savePreset(state, 'My League'));
  snap('emptyLabel', pne.savePreset(state, '   '));
  snap('nullLabel', pne.savePreset(state, null));

  // Fill to the cap and try once more.
  for (let i = 0; i < 20 && (state.settings.customPyramids?.length ?? 0) < pne.MAX_PRESETS; i++) {
    NOW += 1000; RAND = (i + 1) / 100;
    pne.savePreset(state, `Filler ${i}`);
  }
  snap('full', pne.savePreset(state, 'One Too Many'));

  const ids = state.settings.customPyramids.map((p) => p.id);
  const deletedUnknown = pne.deletePreset(state, 'nope');
  const deleted = pne.deletePreset(state, ids[1]);
  return {
    steps, ids, deletedUnknown, deleted,
    afterDelete: state.settings.customPyramids.map((p) => p.id),
    presets: clone(state.settings.customPyramids),
  };
})();

NOW = 1_700_000_000_000; RAND = 0.123456;

out.applyPreset = (() => {
  // Saved from a pyramid whose names have since been shuffled around, which is
  // what re-applying after a few seasons actually looks like.
  const source = makeState();
  pne.applyNameList(source, 'regional_league',
    ['Alpha FC', 'Bravo FC', 'Charlie FC', 'Delta FC']);
  const saved = pne.savePreset(source, 'Set').preset;

  const cases = [];
  const run = (label, mutate) => {
    const state = makeState();
    state.settings.customPyramids = [clone(saved)];
    if (mutate) mutate(state.settings.customPyramids[0], state);
    const result = pne.applyPreset(state, state.settings.customPyramids[0].id);
    cases.push({
      label, applied: result.applied, skipped: result.skipped,
      names: DIV_IDS.reduce((acc, id) => {
        acc[id] = state.progression.leaguePyramid[id].map((t) => t.name);
        return acc;
      }, {}),
    });
  };

  run('wholePyramid', null);
  run('missingDivision', (p) => { delete p.names.regional_league; });
  run('shortList', (p) => { p.names.regional_league = ['Only One']; });
  run('longList', (p) => {
    p.names.regional_league = [...p.names.regional_league, 'Ninth', 'Tenth'];
  });
  run('blanksKeepTheCurrentName', (p) => {
    p.names.regional_league = ['Alpha FC', '', '   ', 'Delta FC'];
  });
  run('namesNotAnArray', (p) => { p.names.regional_league = 'nonsense'; });

  const unknown = pne.applyPreset(makeState(), 'nope');
  return { saved: clone(saved), cases, unknown: { applied: unknown.applied, skipped: unknown.skipped } };
})();

// ── Text ────────────────────────────────────────────────────────────────────
out.text = (() => {
  const state = makeState();
  const preset = pne.savePreset(state, 'Export Me').preset;
  const exported = pne.exportPresetText(preset);

  const parses = [];
  for (const [label, text] of [
    ['roundTrip', exported],
    ['unknownSection', '[not_a_division]\nGhost FC\n[regional_league]\nReal FC'],
    ['noHeader', 'Just A Name\nAnother'],
    ['headerOnly', '[regional_league]'],
    ['blankLinesOnly', '[regional_league]\n\n\n'],
    ['crlf', '[regional_league]\r\nAlpha\r\nBravo'],
    ['empty', ''],
    ['null', null],
    ['whitespaceAroundNames', '[regional_league]\n   Alpha   \n\tBravo\t'],
  ]) {
    parses.push({ label, text, parsed: pne.parsePresetText(text) });
  }

  // A preset with a division that has no names in it at all is not exported.
  const sparse = { names: { regional_league: ['Alpha', 'Bravo'], elite_league: ['', ''] } };
  const sparseText = pne.exportPresetText(sparse);

  const imports = [];
  const importState = makeState();
  for (const [label, text, rawLabel] of [
    ['fresh', exported, 'Imported'],
    ['overwritesByLabel', exported, 'Imported'],
    ['unparseable', 'nothing here', 'Imported'],
    ['emptyLabel', exported, '  '],
    ['sanitisesNames', '[regional_league]\n   A Very Long Name That Runs Past The Limit   \nB', 'Sanitised'],
  ]) {
    NOW += 5000; RAND = 0.5;
    const r = pne.importPresetText(importState, text, rawLabel);
    imports.push({
      label, ok: r.ok, reason: r.reason ?? null,
      preset: r.preset ? clone(r.preset) : null,
      count: importState.settings.customPyramids.length,
    });
  }

  return { exported, parses, sparseText, imports };
})();

process.stdout.write(JSON.stringify(out));
