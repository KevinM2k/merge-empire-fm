// Reference output from the JS deal-advice engine — Coach Colin.
//
// Nothing here draws a random number. What it pins is a lattice of judgements
// that all read the same squad from different angles: a price band against fair
// value, whether the player would get in the side, whether the position is
// bare or already glutted, whether there is room on the grid at all — and the
// CAPS, which are the part a port gets wrong. A cap that is applied as a
// demotion instead prints "worth doing" over "we're already well stocked", which
// is two halves of one sentence arguing with each other.
//
// Prices are derived from `playerValue` at generation time rather than written
// down, so each case lands in the band it is named for even if the valuation
// curve is retuned later.
//
//   node tool/dump_deal_advice_reference.mjs > test/fixtures/deal_advice_reference.json

import { readFileSync } from 'node:fs';

const FIXED_NOW = 1700000000000;
Date.now = () => FIXED_NOW;

const da = await import('../../merge-empire-fc/src/engine/dealAdviceEngine.js');
const ne = await import('../../merge-empire-fc/src/engine/negotiationEngine.js');
const mge = await import('../../merge-empire-fc/src/engine/miniGamesEngine.js');

const questRef = JSON.parse(
  readFileSync(new URL('../test/fixtures/quest_engine_reference.json', import.meta.url), 'utf8'),
);

const clone = (v) => JSON.parse(JSON.stringify(v));

/// The reference save, with the branches the advice reads.
const baseState = ({ coins = 5_000_000, cells = null, division = 'regional_league' } = {}) => {
  const s = clone(questRef.state);
  s.resources.fanCoins = coins;
  s.progression.currentDivision = division;
  if (cells) s.grid.cells = cells;
  return s;
};

const card = (definitionId, instanceId) => ({ instanceId, definitionId, seasonsPlayed: 0 });

/// A squad built to order: `spec` is position letters to how many, at tier 3.
const squad = (spec, { size = 15 } = {}) => {
  const cells = [];
  let n = 0;
  for (const [pos, count] of Object.entries(spec)) {
    for (let i = 0; i < count; i++) cells.push(card(`player_t3_${pos}`, `s${n++}`));
  }
  while (cells.length < size) cells.push(null);
  return cells;
};

const out = {};
out.constants = {
  grindGames: da.GRIND_GAMES,
  grindPayoutMult: da.GRIND_PAYOUT_MULT,
  overOdds: da.OVER_ODDS,
  lowball: da.LOWBALL,
  glutAt: da.GLUT_AT,
  meaningful: da.MEANINGFUL,
  coverAt: da.COVER_AT,
};

// ── The two rules of thumb ──────────────────────────────────────────────────
out.suggested = [];
for (const listing of [
  { askAnchor: 10000, price: 8000 },
  { price: 8000 },
  { askAnchor: 0, price: 0 },
  { askAnchor: -5, price: 0 },
  { offerAnchor: 12345 },
  {},
]) {
  out.suggested.push({
    listing,
    ask: da.suggestedAsk(listing),
    offer: da.suggestedOffer(listing),
  });
}
out.suggestedNull = { ask: da.suggestedAsk(null), offer: da.suggestedOffer(null) };

// ── Buying ──────────────────────────────────────────────────────────────────
// Each case names the squad it is judged against and the multiple of fair value
// the price is set to.
const buyCase = (label, { spec, definitionId, mult, coins = 5_000_000, kind = 'signing', size = 15 }) => {
  const state = baseState({ coins, cells: squad(spec, { size }) });
  const theirs = card(definitionId, 'incoming');
  const fair = ne.playerValue(state, theirs);
  const price = Math.max(1, Math.round(fair * mult));
  const listing = {
    listingId: `dd_${label}`, kind, status: 'live', marquee: false,
    playerName: 'Incoming Star', fromTeam: 'Northern Legion FC',
    definitionId, card: theirs, position: definitionId.split('_').pop().toUpperCase(),
    price, offerAnchor: price, spawnAt: FIXED_NOW, expiresAt: FIXED_NOW + 60_000,
    matches: kind === 'loan' ? 4 : 0,
  };
  return { label, spec, definitionId, mult, coins, kind, size, fair, price, listing,
    advice: da.adviseOnListing(state, listing) };
};

out.buy = [
  // Price bands, judged against a squad the incoming player clearly improves.
  buyCase('bargainUpgrade', { spec: { fwd: 1, mid: 3, def: 3, gk: 1 }, definitionId: 'player_t7_fwd', mult: 0.5 }),
  buyCase('fairUpgrade', { spec: { fwd: 1, mid: 3, def: 3, gk: 1 }, definitionId: 'player_t7_fwd', mult: 1.0 }),
  buyCase('overpricedUpgrade', { spec: { fwd: 1, mid: 3, def: 3, gk: 1 }, definitionId: 'player_t7_fwd', mult: 1.5 }),
  // Nobody in the position at all.
  buyCase('positionGap', { spec: { mid: 3, def: 3, gk: 1 }, definitionId: 'player_t3_fwd', mult: 1.0 }),
  // Would not get in the side, but there is nobody behind the man who does.
  buyCase('needsCover', { spec: { fwd: 1, mid: 3, def: 3, gk: 1 }, definitionId: 'player_t1_fwd', mult: 0.5 }),
  // Would not get in the side and there IS cover: the price is beside the point.
  buyCase('belowStandard', { spec: { fwd: 3, mid: 3, def: 3, gk: 1 }, definitionId: 'player_t1_fwd', mult: 0.5 }),
  // A fourth in the position, capped however good the price.
  buyCase('glutBargain', { spec: { fwd: 4, mid: 3, def: 3, gk: 1 }, definitionId: 'player_t8_fwd', mult: 0.5 }),
  buyCase('glutOverpriced', { spec: { fwd: 4, mid: 3, def: 3, gk: 1 }, definitionId: 'player_t8_fwd', mult: 1.5 }),
  // A grid with no empty cell blocks before the advice runs at all — which is
  // why the `no_room` reason below is unreachable: the cap is 30 and the grid is
  // 15, so free slots can never hit zero while a signing is still allowed.
  buyCase('fullGrid', { spec: { fwd: 1, mid: 3, def: 3, gk: 1 }, definitionId: 'player_t7_fwd', mult: 1.0, size: 8 }),
  // A loan is haggleable the same way a signing is.
  buyCase('loanOverpriced', { spec: { fwd: 1, mid: 3, def: 3, gk: 1 }, definitionId: 'player_t7_fwd', mult: 1.5, kind: 'loan' }),
];

// ── Blocked ─────────────────────────────────────────────────────────────────
const blockedCase = (label, { spec, definitionId, mult, coins, kind = 'signing', size = 15 }) => {
  const state = baseState({ coins, cells: squad(spec, { size }) });
  const theirs = card(definitionId, 'incoming');
  const fair = ne.playerValue(state, theirs);
  const price = Math.max(1, Math.round(fair * mult));
  const listing = {
    listingId: `dd_${label}`, kind, status: 'live', marquee: false,
    playerName: 'Incoming Star', fromTeam: 'Northern Legion FC',
    definitionId, card: theirs, position: definitionId.split('_').pop().toUpperCase(),
    price, offerAnchor: price, spawnAt: FIXED_NOW, expiresAt: FIXED_NOW + 60_000,
    matches: kind === 'loan' ? 4 : 0,
  };
  return { label, spec, definitionId, mult, coins, kind, size, fair, price, listing,
    rewardBase: mge.miniGameRewardBase(state),
    advice: da.adviseOnListing(state, listing) };
};

out.blocked = [];
for (const [label, opts] of [
  // Just short: the money we have still clears the counter floor, so there is a
  // cheeky offer worth making.
  ['cheekyOffer', { spec: { fwd: 1, mid: 3, def: 3, gk: 1 }, definitionId: 'player_t7_fwd', mult: 1.0, coinsFrac: 0.8 }],
  // Nowhere near, but the player would improve us and the gap is grindable.
  ['findMoney', { spec: { mid: 3, def: 3, gk: 1 }, definitionId: 'player_t1_fwd', mult: 1.0, coinsFrac: 0 }],
  // Nowhere near, would improve us, and the gap is NOT grindable.
  ['cannotAfford', { spec: { fwd: 1, mid: 3, def: 3, gk: 1 }, definitionId: 'player_t8_fwd', mult: 1.0, coinsFrac: 0 }],
  // Broke, and he would not improve us either: no second line at all.
  ['brokeAndNotWanted', { spec: { fwd: 3, mid: 3, def: 3, gk: 1 }, definitionId: 'player_t1_fwd', mult: 1.0, coinsFrac: 0 }],
  // Full grid: a different block entirely, and no money line.
  ['squadFull', { spec: { fwd: 4, mid: 4, def: 4, gk: 3 }, definitionId: 'player_t7_fwd', mult: 1.0, coinsFrac: 10, size: 15 }],
]) {
  const state = baseState({ cells: squad(opts.spec, { size: opts.size ?? 15 }) });
  const theirs = card(opts.definitionId, 'incoming');
  const fair = ne.playerValue(state, theirs);
  const price = Math.max(1, Math.round(fair * opts.mult));
  const coins = Math.round(price * opts.coinsFrac);
  out.blocked.push(blockedCase(label, { ...opts, coins }));
}

// ── Selling ─────────────────────────────────────────────────────────────────
const sellCase = (label, { spec, sellIdx, mult, kind = 'bid' }) => {
  const cells = squad(spec);
  const state = baseState({ cells });
  const theirs = cells[sellIdx];
  const fair = ne.playerValue(state, theirs);
  const price = Math.max(1, Math.round(fair * mult));
  const listing = {
    listingId: `dd_${label}`, kind, status: 'live',
    playerName: 'One Of Ours', fromTeam: 'Northern Legion FC',
    definitionId: theirs.definitionId, cardInstanceId: theirs.instanceId,
    position: theirs.definitionId.split('_').pop().toUpperCase(),
    price, askAnchor: price, offer: { cash: price },
    spawnAt: FIXED_NOW, expiresAt: FIXED_NOW + 60_000,
  };
  return { label, spec, sellIdx, mult, kind, fair, price, listing,
    advice: da.adviseOnListing(state, listing) };
};

out.sell = [
  sellCase('overOdds', { spec: { fwd: 3, mid: 3, def: 3, gk: 1 }, sellIdx: 1, mult: 1.5 }),
  sellCase('aboutRight', { spec: { fwd: 3, mid: 3, def: 3, gk: 1 }, sellIdx: 1, mult: 1.0 }),
  sellCase('lowball', { spec: { fwd: 3, mid: 3, def: 3, gk: 1 }, sellIdx: 1, mult: 0.5 }),
  // The only one we have in the position: no price makes that a good idea.
  sellCase('onlyOne', { spec: { fwd: 1, mid: 3, def: 3, gk: 1 }, sellIdx: 0, mult: 1.5 }),
  // Four in the position, so a fair price becomes a good one.
  sellCase('glut', { spec: { fwd: 4, mid: 3, def: 3, gk: 1 }, sellIdx: 1, mult: 1.0 }),
  // A loanOut is a sell too, and its own gate.
  sellCase('loanOut', { spec: { fwd: 3, mid: 3, def: 3, gk: 1 }, sellIdx: 1, mult: 1.0, kind: 'loanOut' }),
];

// The best player we have is never an unqualified "take it", however good the
// money — and a fair price for him is a bad idea rather than a neutral one.
out.sellBest = [];
for (const mult of [1.5, 1.0, 0.5]) {
  const cells = squad({ fwd: 2, mid: 3, def: 3, gk: 1 });
  cells[0] = card('player_t8_fwd', 'star');
  const state = baseState({ cells });
  const fair = ne.playerValue(state, cells[0]);
  const price = Math.max(1, Math.round(fair * mult));
  const listing = {
    listingId: `dd_best_${mult}`, kind: 'bid', status: 'live',
    playerName: 'Our Best', fromTeam: 'Northern Legion FC',
    definitionId: cells[0].definitionId, cardInstanceId: 'star', position: 'FWD',
    price, askAnchor: price, offer: { cash: price },
    spawnAt: FIXED_NOW, expiresAt: FIXED_NOW + 60_000,
  };
  out.sellBest.push({ mult, fair, price, listing, advice: da.adviseOnListing(state, listing) });
}

// An equal twin still on the books means the man being sold is NOT
// irreplaceable — the comparison excludes him, which is the whole point.
out.sellTwin = (() => {
  const cells = squad({ fwd: 2, mid: 3, def: 3, gk: 1 });
  cells[0] = card('player_t8_fwd', 'twinA');
  cells[1] = card('player_t8_fwd', 'twinB');
  const state = baseState({ cells });
  const fair = ne.playerValue(state, cells[0]);
  const price = Math.round(fair * 1.5);
  const listing = {
    listingId: 'dd_twin', kind: 'bid', status: 'live',
    playerName: 'One Of Two', fromTeam: 'Northern Legion FC',
    definitionId: cells[0].definitionId, cardInstanceId: 'twinA', position: 'FWD',
    price, askAnchor: price, offer: { cash: price },
    spawnAt: FIXED_NOW, expiresAt: FIXED_NOW + 60_000,
  };
  return { fair, price, listing, advice: da.adviseOnListing(state, listing) };
})();

// ── The guards ──────────────────────────────────────────────────────────────
out.guards = {
  noState: da.adviseOnListing(null, { kind: 'signing', price: 1 }),
  noListing: da.adviseOnListing(baseState(), null),
  neither: da.adviseOnListing(null, null),
};

process.stdout.write(JSON.stringify(out));
