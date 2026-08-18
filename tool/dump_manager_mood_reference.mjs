// Reference output from the JS manager mood, plus the two small data tables
// that ship alongside it: the Play Games achievement map and the kit palette.
//
// The mood thresholds are the whole point. They are deliberately identical to
// the ones the match popup uses to pick Coach Colin's post-match line, so a port
// that is one goal out anywhere has the walker celebrating a result Colin has
// just called unacceptable — which is worse than no reaction at all. The draw
// scoring is the fiddly half: it is an EDGE built from a rating gap, the ground,
// and whether the game swung, with `led && trailed` cancelling out on purpose.
//
// The gesture rota is pinned as a whole because it carries a rule a test has to
// enforce: a gesture marked as a celebration may only ever carry `elated` and
// `pleased` weights. The robot dance having a neutral weight is what put three
// actions' worth of joy on the screen after a 2-2 the manager was sick about.
//
//   node tool/dump_manager_mood_reference.mjs > test/fixtures/manager_mood_reference.json

const mm = await import('../../merge-empire-fc/src/data/managerMood.js');
const { PGS_ACHIEVEMENT_IDS } = await import('../../merge-empire-fc/src/data/pgsAchievements.js');
const kp = await import('../../merge-empire-fc/src/data/kitPalette.js');
const { LOOK_PACKS } = await import('../../merge-empire-fc/src/data/managerAvatar.js');

const NOW = 1700000000000;
const out = { now: NOW, moods: mm.MOODS, freshMs: mm.FRESH_MS };

// ── The gesture rota ────────────────────────────────────────────────────────
out.gestures = mm.GESTURES.map((g) => ({
  id: g.id, ms: g.ms, weight: g.weight,
  stops: !!g.stops, fullTime: g.fullTime !== false, celebration: !!g.celebration,
}));
out.gestureIds = mm.GESTURE_IDS;
out.gestureGapMs = mm.GESTURE_GAP_MS;
out.ballPlays = mm.BALL_PLAYS;

// ── A draw, scored on its edge ──────────────────────────────────────────────
out.moodForDraw = [];
for (const ratingGap of [-20, -8, -7, -6, -3, 0, 3, 6, 7, 8, 20]) {
  for (const isHome of [true, false, null]) {
    for (const [led, trailed] of [[false, false], [true, false], [false, true], [true, true]]) {
      out.moodForDraw.push({
        ratingGap, isHome, led, trailed,
        mood: mm.moodForDraw({ ratingGap, isHome, led, trailed }),
      });
    }
  }
}
// Nothing passed at all, which is what a save with no draw context has.
out.moodForDrawBare = mm.moodForDraw();
out.moodForDrawNaN = mm.moodForDraw({ ratingGap: NaN });

// ── A scoreline ─────────────────────────────────────────────────────────────
out.moodForScore = [];
for (const margin of [-5, -2, -1, 0, 1, 2, 3, 4, null]) {
  for (const [label, opts] of [
    ['won', { won: true }],
    ['wonWithSilverware', { won: true, trophiesEarned: 1 }],
    ['drawn', { drawn: true }],
    ['drawnAwayToBetterSide', { drawn: true, ratingGap: 10, isHome: false }],
    ['drawnPeggedBackAtHome', { drawn: true, isHome: true, led: true }],
    ['lost', {}],
  ]) {
    out.moodForScore.push({ margin, label, opts, mood: mm.moodForScore(margin, opts) });
  }
}
// No options object at all.
out.moodForScoreBare = [null, -3, 0, 3].map((margin) => ({
  margin, mood: mm.moodForScore(margin),
}));

// ── The mood off a save ─────────────────────────────────────────────────────
const result = (over = {}) => ({
  won: false, drawn: false, isHome: true, ourGoals: 1, theirGoals: 1,
  playedAt: NOW, ...over,
});

out.derive = [];
for (const [label, state, at] of [
  ['noState', null, NOW],
  ['noProgression', {}, NOW],
  ['noResult', { progression: { seasonWins: 0, seasonDraws: 0, seasonLosses: 0 } }, NOW],
  ['freshWin', { progression: { lastMatchResult: result({ won: true, ourGoals: 4, theirGoals: 0 }) } }, NOW],
  ['freshNarrowLoss', { progression: { lastMatchResult: result({ ourGoals: 1, theirGoals: 2 }) } }, NOW],
  ['freshHiding', { progression: { lastMatchResult: result({ ourGoals: 0, theirGoals: 4 }) } }, NOW],
  ['freshDraw', { progression: { lastMatchResult: result({ drawn: true }) } }, NOW],
  // Just inside the window, and a millisecond outside it.
  ['justFresh', { progression: { lastMatchResult: result({ won: true }) } }, NOW + mm.FRESH_MS],
  ['justStale', { progression: { lastMatchResult: result({ won: true }), seasonWins: 9, seasonDraws: 0, seasonLosses: 1 } }, NOW + mm.FRESH_MS + 1],
  // The stamp can come off the result or off the progression branch.
  ['stampOnProgression', { progression: { lastMatchAt: NOW, lastMatchResult: result({ won: true, playedAt: undefined }) } }, NOW],
  ['noStampAnywhere', { progression: { lastMatchResult: result({ won: true, playedAt: 0 }), seasonWins: 5, seasonDraws: 1, seasonLosses: 1 } }, NOW],
  // Season form, once no result is fresh.
  ['titleForm', { progression: { seasonWins: 8, seasonDraws: 1, seasonLosses: 1 } }, NOW],
  ['midTable', { progression: { seasonWins: 4, seasonDraws: 2, seasonLosses: 4 } }, NOW],
  ['relegationForm', { progression: { seasonWins: 0, seasonDraws: 2, seasonLosses: 8 } }, NOW],
  ['tooEarlyToTell', { progression: { seasonWins: 0, seasonDraws: 0, seasonLosses: 2 } }, NOW],
  // A score string rather than goal counts, which is the older shape.
  ['scoreStringHome', { progression: { lastMatchResult: { score: '3–0', isHome: true, won: true, playedAt: NOW } } }, NOW],
  ['scoreStringAway', { progression: { lastMatchResult: { score: '0–3', isHome: false, won: true, playedAt: NOW } } }, NOW],
  ['unreadableScore', { progression: { lastMatchResult: { score: 'nil-nil', playedAt: NOW } } }, NOW],
]) {
  out.derive.push({ label, at, ...mm.deriveMood(state, at) });
}

// ── Picking a gesture ───────────────────────────────────────────────────────
// A save that owns every emote, one that owns none, and the free-for-all a
// caller with no state to hand gets.
const EMOTE_IDS = LOOK_PACKS.flatMap((p) => p.items).filter((k) => k.startsWith('emote:'));
const OWNS_EVERYTHING = { club: { lookItems: EMOTE_IDS } };
const OWNS_NOTHING = { club: { lookItems: [] } };

out.pickGesture = [];
for (const mood of mm.MOODS) {
  for (const [stateLabel, state] of [
    ['noState', null], ['ownsNothing', OWNS_NOTHING], ['ownsEverything', OWNS_EVERYTHING],
  ]) {
    for (const fullTime of [false, true]) {
      // Up to and INCLUDING 1: a roll of exactly 1 never goes negative, so it
      // falls through the loop to the last of the pool.
      for (let i = 0; i <= 10; i++) {
        const roll = i / 10;
        out.pickGesture.push({
          mood, stateLabel, fullTime, roll,
          id: mm.pickGesture(mood, () => roll, state, { fullTime })?.id ?? null,
        });
      }
    }
  }
}

// The exclude list is a filter, not a reroll — and it is ignored when it would
// leave nothing at all.
out.pickGestureExcluded = [];
for (const [label, mood, exclude] of [
  ['oneExcluded', 'crushed', ['handsonhead']],
  ['mostExcluded', 'crushed', ['handsonhead', 'armsfolded', 'handsonhips', 'point', 'checkwatch']],
  ['allExcluded', 'crushed', mm.GESTURE_IDS],
  ['excludingNothingRelevant', 'elated', ['handsonhead']],
]) {
  for (const roll of [0, 0.5, 0.99]) {
    out.pickGestureExcluded.push({
      label, mood, exclude, roll,
      id: mm.pickGesture(mood, () => roll, null, { exclude })?.id ?? null,
    });
  }
}

out.getGesture = {};
for (const id of [...mm.GESTURE_IDS, 'not_a_gesture', '']) {
  out.getGesture[id] = mm.getGesture(id)?.id ?? null;
}
out.getGestureNull = mm.getGesture(null)?.id ?? null;

out.nextGestureDelay = [];
for (const mood of [...mm.MOODS, 'not_a_mood']) {
  for (const roll of [0, 0.5, 1]) {
    out.nextGestureDelay.push({ mood, roll, ms: mm.nextGestureDelay(mood, () => roll) });
  }
}

out.pickBallPlay = [];
for (const mood of [...mm.MOODS, 'not_a_mood']) {
  for (let i = 0; i < 20; i++) {
    const roll = i / 20;
    out.pickBallPlay.push({ mood, roll, play: mm.pickBallPlay(mood, () => roll) });
  }
}

// ── The two tables that ship alongside ──────────────────────────────────────
out.pgsAchievementIds = PGS_ACHIEVEMENT_IDS;

out.kit = { defaultColor: kp.DEFAULT_KIT_COLOR, patterns: kp.KIT_PATTERNS, rows: [] };
for (const kit of [
  ...Object.keys(kp.KIT_PATTERNS), '#ff0000', '#abc', 'not_a_kit', '', null, undefined, 42,
]) {
  out.kit.rows.push({
    kit: kit ?? null,
    solid: kp.kitSolidColor(kit),
    stripes: kp.kitStripes(kit),
    swatch: kp.kitSwatchCss(kit),
  });
}

process.stdout.write(JSON.stringify(out));
