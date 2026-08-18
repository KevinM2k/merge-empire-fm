// Reference output from the JS Deadline Day news ticker.
//
// The strip is rebuilt on every League re-render, so the whole feature depends
// on being deterministic: the same state at the same instant has to produce the
// same three lines, or the rumours reshuffle under the player's eyes mid-read.
// Everything is drawn from a stream seeded off the window, or off an hour bucket
// through the build-up, and the draw ORDER is what a port gets wrong — the
// outsider-name pass alone takes forty-eight numbers before a single rumour is
// picked.
//
// The sessions here are hand-authored rather than played out through the
// deadline-day engine. The ticker only reads a handful of listing fields, and
// writing them by hand is what makes the awkward cases reachable: a listing id
// that hashes to an undisclosed fee, a session left over from LAST night's
// window, an evening where nothing was done at all.
//
//   node tool/dump_deadline_news_reference.mjs > test/fixtures/deadline_news_reference.json

const FIXED_NOW = 1700000000000; // 2023-11-14T22:13:20Z
Date.now = () => FIXED_NOW;

const dn = await import('../../merge-empire-fc/src/engine/deadlineNewsEngine.js');
const { DIVISIONS } = await import('../../merge-empire-fc/src/data/divisions.js');

const clone = (v) => JSON.parse(JSON.stringify(v));

const HOUR = 60 * 60 * 1000;
const WINDOW_START = FIXED_NOW - 10 * 60 * 1000; // opened ten minutes ago

/// A listing the ticker can read. The ids are chosen so both fee variants are
/// exercised — `_undisclosed` is an FNV-1a hash of the id, mod 3.
const listing = (over = {}) => ({
  listingId: 'dd_a', kind: 'signing', status: 'live', marquee: false,
  playerName: 'Ada Striker', fromTeam: 'Northern Legion FC', price: 12500,
  matches: 0, spawnAt: WINDOW_START, expiresAt: FIXED_NOW + 5 * 60 * 1000,
  ...over,
});

const makeState = ({ session = null, history = [], squad = true, pyramid = true, opponents = true } = {}) => {
  const leaguePyramid = {};
  if (pyramid) {
    for (const d of DIVISIONS) {
      leaguePyramid[d.id] = Array.from({ length: 8 }, (_, i) => ({ name: `${d.id} FC ${i}` }));
    }
  }
  return {
    clubName: 'Player Rovers',
    grid: {
      cells: squad
        ? [
            { definitionId: 'player_t3_fwd', displayName: 'Rico Blaze' },
            { definitionId: 'player_t3_mid', displayName: 'Milo Pivot' },
            null,
            { definitionId: 'player_t2_def', customName: 'The Wall' },
          ]
        : [null, null],
    },
    progression: {
      currentDivision: 'regional_league',
      seasonOpponents: opponents ? ['Fallback Rovers', 'Fallback City'] : [],
      leaguePyramid: pyramid ? leaguePyramid : undefined,
    },
    deadlineDay: { session: session ?? { startedAt: 0, windowStart: 0, listings: [], done: false }, history },
  };
};

const out = { fixedNow: FIXED_NOW, windowStart: WINDOW_START, newsLines: dn.NEWS_LINES };

// ── Which phase ─────────────────────────────────────────────────────────────
out.phase = [];
for (const [label, live, history, at] of [
  ['liveWins', true, [], FIXED_NOW],
  ['noHistory', false, [], FIXED_NOW],
  ['tonight', false, [{ windowStart: WINDOW_START, endedAt: WINDOW_START + HOUR }], FIXED_NOW],
  ['yesterday', false, [{ windowStart: WINDOW_START - 24 * HOUR, endedAt: WINDOW_START - 23 * HOUR }], FIXED_NOW],
  ['tomorrow', false, [{ windowStart: WINDOW_START, endedAt: WINDOW_START + HOUR }], FIXED_NOW + 24 * HOUR],
  // windowStart falsy falls through to endedAt, which is what an older banked
  // window has instead.
  ['noWindowStart', false, [{ windowStart: 0, endedAt: FIXED_NOW }], FIXED_NOW],
]) {
  out.phase.push({ label, live, at, phase: dn.deadlineNewsPhase(makeState({ history }), live, at) });
}

// ── The build-up ────────────────────────────────────────────────────────────
// Seeded on the hour bucket, so the same hour is the same three rumours and the
// next hour is a different three.
out.buildup = [];
for (const [label, opts, stateOpts] of [
  ['bare', {}, {}],
  ['withClub', { clubName: 'Player Rovers' }, {}],
  ['withOpener', { clubName: 'Player Rovers', opener: { key: 'event.news.buildup.opens', params: { at: '6:00 pm' } } }, {}],
  ['noSquad', { clubName: 'Player Rovers' }, { squad: false }],
  ['noPyramid', { clubName: 'Player Rovers' }, { pyramid: false }],
  ['nothingAtAll', { clubName: '' }, { squad: false, pyramid: false }],
  // No pyramid AND no season opponents: every rumour that names a club is
  // unusable, and the filler line is the only thing keeping the strip full.
  ['noTeamsAtAll', { clubName: 'Player Rovers' }, { squad: false, pyramid: false, opponents: false }],
]) {
  for (const at of [FIXED_NOW, FIXED_NOW + HOUR, FIXED_NOW + 5 * HOUR]) {
    out.buildup.push({
      label, at,
      lines: dn.deadlineHeadlines(makeState(stateOpts), { ...opts, nowMs: at }),
    });
  }
}

// The same instant twice is the same strip — the point of the whole design.
out.buildupStable = (() => {
  const state = makeState();
  const a = dn.deadlineHeadlines(state, { clubName: 'Player Rovers', nowMs: FIXED_NOW });
  const b = dn.deadlineHeadlines(state, { clubName: 'Player Rovers', nowMs: FIXED_NOW });
  return { same: JSON.stringify(a) === JSON.stringify(b), lines: a };
})();

// ── Live ────────────────────────────────────────────────────────────────────
const liveSession = (listings, over = {}) => ({
  startedAt: WINDOW_START, windowStart: WINDOW_START, done: false, listings, ...over,
});

out.live = [];
for (const [label, session] of [
  ['nothingYet', liveSession([])],
  ['oneOnTheTable', liveSession([listing()])],
  ['threeOnTheTable', liveSession([
    listing({ listingId: 'dd_a', spawnAt: WINDOW_START + 1000 }),
    listing({ listingId: 'dd_b', kind: 'bid', playerName: 'Milo Pivot', spawnAt: WINDOW_START + 2000 }),
    listing({ listingId: 'dd_c', kind: 'loan', playerName: 'Kit Loanee', matches: 4, spawnAt: WINDOW_START + 3000 }),
  ])],
  ['marqueeAndLoanOut', liveSession([
    listing({ listingId: 'dd_d', marquee: true, spawnAt: WINDOW_START + 1000 }),
    listing({ listingId: 'dd_e', kind: 'loanOut', playerName: 'The Wall', matches: 6, spawnAt: WINDOW_START + 2000 }),
  ])],
  ['doneDealsOutrankTalks', liveSession([
    listing({ listingId: 'dd_f', status: 'accepted', price: 30000 }),
    listing({ listingId: 'dd_g', kind: 'bid', status: 'accepted', price: 44000 }),
    listing({ listingId: 'dd_h', spawnAt: WINDOW_START + 9000 }),
  ])],
  // A session left over from LAST night, on a night the player has not opened
  // the screen yet. Rebroadcasting those would be reporting business that did
  // not happen tonight.
  ['lastNightsSession', liveSession(
    [listing({ listingId: 'dd_i', status: 'accepted' })],
    { windowStart: WINDOW_START - 24 * HOUR, startedAt: WINDOW_START - 24 * HOUR },
  )],
  ['finishedSession', liveSession([listing({ listingId: 'dd_j', status: 'accepted' })], { done: true })],
  ['expiredListingsAreNotTalks', liveSession([
    listing({ listingId: 'dd_k', expiresAt: FIXED_NOW - 1 }),
  ])],
  ['unknownKind', liveSession([listing({ listingId: 'dd_l', kind: 'mystery' })])],
]) {
  for (const at of [FIXED_NOW, FIXED_NOW + HOUR]) {
    out.live.push({
      label, at,
      lines: dn.deadlineHeadlines(makeState({ session }), { live: true, clubName: 'Player Rovers', nowMs: at }),
    });
  }
}

// ── Aftermath ───────────────────────────────────────────────────────────────
const banked = (over = {}) => ({
  windowStart: WINDOW_START, endedAt: WINDOW_START + HOUR,
  signings: 0, sales: 0, loans: 0, loanOuts: 0, missed: 0, ...over,
});

out.aftermath = [];
for (const [label, session, history] of [
  ['busyEvening',
    liveSession([
      listing({ listingId: 'dd_m', status: 'accepted', price: 30000 }),
      listing({ listingId: 'dd_n', kind: 'bid', status: 'accepted', price: 44000 }),
    ], { done: true }),
    [banked({ signings: 1, sales: 1 })]],
  ['oneDeal',
    liveSession([listing({ listingId: 'dd_o', status: 'accepted' })], { done: true }),
    [banked({ signings: 1 })]],
  ['quietEvening', liveSession([], { done: true }), [banked()]],
  ['quietButMissed', liveSession([], { done: true }), [banked({ missed: 3 })]],
  ['missedExactlyOne', liveSession([], { done: true }), [banked({ missed: 1 })]],
  ['loansCountToo',
    liveSession([
      listing({ listingId: 'dd_p', kind: 'loan', status: 'accepted', matches: 5 }),
      listing({ listingId: 'dd_q', kind: 'loanOut', status: 'accepted', matches: 3 }),
    ], { done: true }),
    [banked({ loans: 1, loanOuts: 1 })]],
  // The session on file belongs to an older window, so its deals are not
  // tonight's business however recently they were banked.
  ['staleSession',
    liveSession([listing({ listingId: 'dd_r', status: 'accepted' })],
      { done: true, windowStart: WINDOW_START - 24 * HOUR }),
    [banked({ signings: 1 })]],
  ['marqueeUndisclosed',
    liveSession([
      listing({ listingId: 'dd_s', marquee: true, status: 'accepted', price: 250000 }),
    ], { done: true }),
    [banked({ signings: 1 })]],
]) {
  out.aftermath.push({
    label,
    lines: dn.deadlineHeadlines(makeState({ session, history }),
      { clubName: 'Player Rovers', nowMs: FIXED_NOW }),
  });
}

// The league-wide number is seeded off the window, so it holds all evening.
out.aftermathStable = (() => {
  const state = makeState({
    session: liveSession([], { done: true }),
    history: [banked()],
  });
  const a = dn.deadlineHeadlines(state, { clubName: 'Player Rovers', nowMs: FIXED_NOW });
  const b = dn.deadlineHeadlines(state, { clubName: 'Player Rovers', nowMs: FIXED_NOW + 20 * 60 * 1000 });
  return { a, b, same: JSON.stringify(a) === JSON.stringify(b) };
})();

// ── The undisclosed-fee flip ────────────────────────────────────────────────
// Stable per listing id, so a fee cannot turn undisclosed halfway through a
// rotation. Both branches have to be reachable or every deal reads the same way.
out.undisclosed = [];
for (const id of ['dd_a', 'dd_b', 'dd_c', 'dd_d', 'dd_e', 'dd_f', 'dd_g', 'dd_h', '', 'dd_bid_1700000000000_4242']) {
  const state = makeState({
    session: liveSession([listing({ listingId: id, status: 'accepted' })], { done: true }),
    history: [banked({ signings: 1 })],
  });
  const lines = dn.deadlineHeadlines(state, { clubName: 'Player Rovers', nowMs: FIXED_NOW });
  out.undisclosed.push({ listingId: id, key: lines[0].key, fee: lines[0].params.fee ?? null });
}

process.stdout.write(JSON.stringify(out));
