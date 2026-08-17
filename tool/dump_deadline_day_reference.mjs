// Seeded reference output from the JS Deadline Day engine.
//
// This is the one part of the game that runs on a REAL clock, and everything in
// it derives from elapsed wall time rather than tick counts. So the fixture pins
// whole SESSIONS at fixed instants: open the window, jump the clock, and compare
// every listing on the board — because a port can get each formula right and
// still spawn a different feed if it draws in a different order, or anchors the
// schedule to the player instead of to the window.
//
// BOTH generators are pinned. Listings roll real cards, and `rollDealCard` mixes
// the seeded stream (gender, trait chance) with bare Math.random (variant, rating
// spread, ATK/DEF ratio, the trait itself) — so Math.random is replaced with a
// second mulberry32 and the Dart side drives the same one.
//
// Date.now is pinned so every stamp is a number both runtimes agree on.
//
//   node tool/dump_deadline_day_reference.mjs > test/fixtures/deadline_day_reference.json

import { readFileSync } from 'node:fs';

const FIXED_NOW = 1700000000000;
Date.now = () => FIXED_NOW;

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
const dd = await import('../../merge-empire-fc/src/engine/deadlineDayEngine.js');
const ddData = await import('../../merge-empire-fc/src/data/deadlineDay.js');

const questRef = JSON.parse(
  readFileSync(new URL('../test/fixtures/quest_engine_reference.json', import.meta.url), 'utf8'),
);

const clone = (v) => JSON.parse(JSON.stringify(v));

// The window this fixture is built around: opens at FIXED_NOW, shuts an hour on.
const WINDOW_START = FIXED_NOW;
const WINDOW_END = FIXED_NOW + ddData.SESSION_MS;

const baseState = (over = {}) => {
  const s = clone(questRef.state);
  s.resources.fanCoins = 5_000_000;
  s.stats = s.stats ?? {};
  s.events = { active: [], progress: {}, claimed: {} };
  for (const [k, v] of Object.entries(over)) {
    if (v && typeof v === 'object' && !Array.isArray(v) && s[k] && typeof s[k] === 'object') {
      Object.assign(s[k], v);
    } else {
      s[k] = v;
    }
  }
  return s;
};

// A card's instance id embeds a module counter reflecting how many cards each
// runtime happened to have built — nothing about the deal. Stripped everywhere,
// with the shape asserted separately on the Dart side.
const ID_KEYS = new Set(['instanceId', 'signedInstanceId']);
const stripIds = (v) => {
  if (Array.isArray(v)) return v.map(stripIds);
  if (v && typeof v === 'object') {
    const out = {};
    for (const [k, val] of Object.entries(v)) {
      if (ID_KEYS.has(k)) continue;
      out[k] = stripIds(val);
    }
    return out;
  }
  return v;
};

/// Only what a session actually writes. The pyramid and the discovered-player log
/// are the bulk of the save and Deadline Day touches neither.
const digest = (s) => ({
  deadlineDay: stripIds(s.deadlineDay ?? null),
  cells: (s.grid?.cells ?? []).map((c) => c && stripIds({
    definitionId: c.definitionId,
    listed: c.listed ?? null,
    loanedOut: c.loanedOut ?? null,
    loanMatchesLeft: c.loanMatchesLeft ?? null,
    borrowed: c.borrowed ?? null,
    displayName: c.displayName ?? null,
  })),
  lineup: (s.squad?.lineup ?? []).map((l) => l.cardInstanceId ?? null),
  fanCoins: s.resources?.fanCoins ?? null,
  transfersAccepted: s.stats?.transfersAccepted ?? null,
});

const out = { fixedNow: FIXED_NOW, windowStart: WINDOW_START, windowEnd: WINDOW_END };

out.constants = {
  SESSION_MS: ddData.SESSION_MS,
  LISTING_INTERVAL_MS: ddData.LISTING_INTERVAL_MS,
  LISTING_TTL_MS: ddData.LISTING_TTL_MS,
  MAX_SPAWNS: ddData.MAX_SPAWNS,
  MAX_LIVE_LISTINGS: ddData.MAX_LIVE_LISTINGS,
  BID_SHARE: ddData.BID_SHARE,
  LOAN_SHARE: ddData.LOAN_SHARE,
  LOAN_OUT_SHARE: ddData.LOAN_OUT_SHARE,
  BID_PREMIUM: ddData.BID_PREMIUM,
  SIGNING_PREMIUM: ddData.SIGNING_PREMIUM,
  MARQUEE_PREMIUM: ddData.MARQUEE_PREMIUM,
  MAX_MARQUEE: ddData.MAX_MARQUEE,
  MARQUEE_MIN_INDEX: ddData.MARQUEE_MIN_INDEX,
  MARQUEE_MAX_INDEX: ddData.MARQUEE_MAX_INDEX,
  MARQUEE_CHANCE: ddData.MARQUEE_CHANCE,
  BID_MIN_TIER: ddData.BID_MIN_TIER,
  MIN_HEALTHY_KEEP: ddData.MIN_HEALTHY_KEEP,
  SCORE_PER_SALE: ddData.SCORE_PER_SALE,
  SCORE_PER_LOAN: ddData.SCORE_PER_LOAN,
  SCORE_PER_SIGNING: ddData.SCORE_PER_SIGNING,
  SCORE_PER_MARQUEE: ddData.SCORE_PER_MARQUEE,
  HISTORY_LIMIT: ddData.HISTORY_LIMIT,
  TICKER_LINES: ddData.TICKER_LINES,
  MAX_MARKET_TIER: dd.MAX_MARKET_TIER,
};

// ── divGapMult ─────────────────────────────────────────────────────────────
// A bounded per-rung step, not the real revenue ratio — the ladder spans a
// 1200x income range and pricing on the true ratio would let one top-flight bid
// pay for the whole of Sunday League.
out.divGapMult = Object.fromEntries(
  [-9, -6, -3, -2, -1, 0, 1, 2, 3, 6, 9, null].map((g) => [String(g), dd.divGapMult(g)]),
);

// ── a whole session, at several arrival times ──────────────────────────────
//
// Punctual, a minute in, ten minutes late, half an hour late, and after closing.
// The late arrivals are the interesting ones: the schedule is the WINDOW's, so
// business has already come and gone.
const sessionRun = (name, seed, mathSeedValue, joinOffsetMs, ticks, over = {}) => {
  rng.setSeed(seed);
  setMathSeed(mathSeedValue);
  const state = baseState(over);
  const joinAt = WINDOW_START + joinOffsetMs;
  const started = dd.startSession(state, WINDOW_START, joinAt, WINDOW_END);

  const snapshots = [];
  for (const offset of ticks) {
    const at = WINDOW_START + offset;
    dd.tickSession(state, at);
    snapshots.push({
      offset,
      remainingMs: dd.sessionRemainingMs(state, at),
      status: dd.sessionStatus(state, WINDOW_START, at),
      live: dd.liveListings(state, at).map((l) => l.listingId),
      liveBuy: dd.liveListingsBySide(state, 'buy', at).map((l) => l.listingId),
      liveSell: dd.liveListingsBySide(state, 'sell', at).map((l) => l.listingId),
    });
  }

  out[name] = {
    seed, mathSeed: mathSeedValue, joinOffsetMs, ticks,
    started: { ok: started.ok, reason: started.reason ?? null, endsAt: started.endsAt ?? null },
    snapshots,
    state: digest(state),
  };
};

const EVERY_FEW = [0, 90_000, 300_000, 600_000, 1_200_000];

sessionRun('punctual', 11, 101, 0, EVERY_FEW);
sessionRun('aMinuteIn', 11, 101, 60_000, EVERY_FEW);
sessionRun('tenLate', 11, 101, 600_000, [600_000, 900_000, 1_500_000]);
sessionRun('halfHourLate', 7, 77, 1_800_000, [1_800_000, 2_400_000, 3_000_000]);
// Right to the end, so the session closes itself and banks a summary.
sessionRun('toTheWhistle', 3, 33, 0, [0, 1_800_000, 3_599_000, 3_600_000, 3_700_000]);
// A bare squad: bids must not strip it below a fieldable core, so the feed falls
// back to the other kinds.
sessionRun('bareSquad', 5, 55, 0, [0, 300_000, 900_000], {
  grid: { cells: clone(questRef.state.grid.cells).map((c, i) => (i < 3 ? c : null)) },
});
// Broke, so nothing on the buy side can be taken — the feed still fills.
sessionRun('broke', 9, 99, 0, [0, 300_000, 900_000], { resources: { fanCoins: 0 } });

// ── the gates ─────────────────────────────────────────────────────────────
out.gates = [];
{
  rng.setSeed(11);
  setMathSeed(101);
  const state = baseState();
  dd.startSession(state, WINDOW_START, WINDOW_START, WINDOW_END);
  dd.tickSession(state, WINDOW_START + 1_200_000);
  const at = WINDOW_START + 1_200_000;
  for (const l of dd.liveListings(state, at)) {
    out.gates.push({
      listingId: l.listingId,
      kind: l.kind,
      side: dd.listingSide(l),
      blocked: dd.listingBlockedReason(state, l),
      canSign: (() => { const g = dd.canSign(state, l); return { ok: g.ok, reason: g.reason ?? null }; })(),
      remainingMs: dd.listingRemainingMs(l, at),
      expired: dd.listingExpired(l, at),
    });
  }
  out.gates.push({ listingId: null, blocked: dd.listingBlockedReason(state, null) });
}

// ── one session, driven through every interaction ──────────────────────────
//
// Each action is recorded with the state it left behind, so an ordering slip in
// any of them shows up rather than being averaged away.
const drive = (name, seed, mathSeedValue, plan, over = {}) => {
  rng.setSeed(seed);
  setMathSeed(mathSeedValue);
  const state = baseState(over);
  dd.startSession(state, WINDOW_START, WINDOW_START, WINDOW_END);
  const at = WINDOW_START + 1_200_000;
  dd.tickSession(state, at);

  const steps = [];
  for (const step of plan) {
    const board = dd.liveListings(state, at);
    const target = board.find((l) => step.kind == null || l.kind === step.kind);
    if (!target) { steps.push({ action: step.action, kind: step.kind, skipped: 'none_live' }); continue; }
    let res;
    switch (step.action) {
      case 'accept':
        res = dd.acceptListing(state, target.listingId, at); break;
      case 'dismiss':
        res = dd.dismissListing(state, target.listingId); break;
      case 'askForMore':
        res = dd.askForMore(state, target.listingId, Math.round((target.price ?? 0) * step.mult), at); break;
      case 'submitOffer':
        res = dd.submitOffer(state, target.listingId, { cash: Math.round((target.price ?? 0) * step.mult), players: step.players ?? [] }, at); break;
      case 'acceptCounter':
        res = dd.acceptSellerCounter(state, target.listingId, at); break;
      case 'pause':
        res = { paused: dd.pauseListing(state, target.listingId, at) }; break;
      case 'resume':
        res = { resumed: dd.resumeListing(state, target.listingId, at + 30_000) }; break;
      default:
        throw new Error(`unknown action ${step.action}`);
    }
    steps.push({
      action: step.action, kind: step.kind, mult: step.mult ?? null,
      listingId: target.listingId,
      result: stripIds(res),
      listing: stripIds(state.deadlineDay.session.listings.find((l) => l.listingId === target.listingId)),
    });
  }

  out[name] = {
    seed, mathSeed: mathSeedValue, steps,
    summary: dd.endSession(state, WINDOW_END),
    state: digest(state),
  };
};

drive('sellSide', 11, 101, [
  { action: 'accept', kind: 'bid' },
  { action: 'dismiss', kind: 'bid' },
  { action: 'accept', kind: 'loanOut' },
]);

// Haggling: a sensible push, a greedy one, and pushing again after a counter.
drive('haggle', 11, 101, [
  { action: 'askForMore', kind: 'bid', mult: 1.1 },
  { action: 'askForMore', kind: 'bid', mult: 1.45 },
  { action: 'askForMore', kind: 'bid', mult: 1.45 },
  { action: 'accept', kind: 'bid' },
]);

drive('greed', 11, 101, [
  { action: 'askForMore', kind: 'bid', mult: 3 },
]);

drive('buySide', 11, 101, [
  { action: 'accept', kind: 'signing' },
  { action: 'accept', kind: 'loan' },
]);

// Offering under the asking price: a lowball, a serious short offer, then taking
// whatever number they came back with.
drive('offers', 11, 101, [
  { action: 'submitOffer', kind: 'signing', mult: 0.3 },
  { action: 'submitOffer', kind: 'signing', mult: 0.9 },
  { action: 'acceptCounter', kind: 'signing' },
]);

drive('pauseResume', 11, 101, [
  { action: 'pause', kind: 'signing' },
  { action: 'pause', kind: 'signing' },
  { action: 'resume', kind: 'signing' },
  { action: 'resume', kind: 'signing' },
]);

// ── re-entry, and the one-session rule ────────────────────────────────────
out.reentry = (() => {
  rng.setSeed(11);
  setMathSeed(101);
  const state = baseState();
  const first = dd.startSession(state, WINDOW_START, WINDOW_START, WINDOW_END);
  const again = dd.startSession(state, WINDOW_START, WINDOW_START + 60_000, WINDOW_END);
  dd.endSession(state, WINDOW_END);
  const afterEnd = dd.startSession(state, WINDOW_START, WINDOW_END + 1000, WINDOW_END + ddData.SESSION_MS);
  const nextWindow = dd.startSession(state, WINDOW_END, WINDOW_END + 1000, WINDOW_END + ddData.SESSION_MS);
  return {
    first: { ok: first.ok, reason: first.reason ?? null },
    again: { ok: again.ok, reason: again.reason ?? null },
    afterEnd: { ok: afterEnd.ok, reason: afterEnd.reason ?? null },
    nextWindow: { ok: nextWindow.ok, reason: nextWindow.reason ?? null },
    hasUsed: dd.hasUsedSession(state, WINDOW_START),
    historyLength: state.deadlineDay.history.length,
  };
})();

// Opening after the window has already shut buys nothing.
out.closedWindow = (() => {
  rng.setSeed(1);
  setMathSeed(1);
  const state = baseState();
  const r = dd.startSession(state, WINDOW_START, WINDOW_END + 1, WINDOW_END);
  return { ok: r.ok, reason: r.reason ?? null };
})();

// A session with no window end falls back to the fixed length.
out.noWindowEnd = (() => {
  rng.setSeed(1);
  setMathSeed(1);
  const state = baseState();
  const r = dd.startSession(state, WINDOW_START, WINDOW_START);
  return { ok: r.ok, endsAt: r.endsAt };
})();

// A blank state grows the branch rather than throwing.
out.ensure = (() => {
  const empty = {};
  const made = dd.ensureDeadlineDay(empty);
  const junk = { deadlineDay: { session: 'nope', history: 'nope' } };
  dd.ensureDeadlineDay(junk);
  return { made: clone(made), repaired: clone(junk.deadlineDay) };
})();

// The history ring keeps only the most recent few, newest first.
out.historyRing = (() => {
  rng.setSeed(2);
  setMathSeed(2);
  const state = baseState();
  for (let i = 0; i < ddData.HISTORY_LIMIT + 3; i++) {
    const start = WINDOW_START + i * ddData.SESSION_MS * 2;
    dd.startSession(state, start, start, start + ddData.SESSION_MS);
    dd.endSession(state, start + ddData.SESSION_MS);
  }
  return {
    length: state.deadlineDay.history.length,
    windowStarts: state.deadlineDay.history.map((h) => h.windowStart),
  };
})();

process.stdout.write(JSON.stringify(out));
