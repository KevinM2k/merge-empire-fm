// Reference output from the JS scout-voucher engine.
//
// Nothing here is random. What it pins is the RULE the whole item rests on: a
// voucher may never guarantee a tier the player's own division cannot already
// scout for coins, so what is buyable is derived from the odds table rather than
// tabulated. A port that hardcoded the ladder would look identical today and
// quietly break the moment the odds are retuned.
//
// The other half is the one-voucher rule, which lives in two files that cannot
// import each other: the engine's `anyVoucherArmed` and the gem catalogue's
// `scout_voucher_gem.heldWhen`. Both are dumped against the same shop shapes so
// the two halves can be pinned together.
//
//   node tool/dump_scout_voucher_reference.mjs > test/fixtures/scout_voucher_reference.json

const sv = await import('../../merge-empire-fc/src/engine/scoutVoucherEngine.js');
const ge = await import('../../merge-empire-fc/src/engine/gemEngine.js');
const { DIVISIONS } = await import('../../merge-empire-fc/src/data/divisions.js');

const clone = (v) => JSON.parse(JSON.stringify(v));

const DIV_IDS = DIVISIONS.map((d) => d.id);
const TIERS = [1, 2, 3, 4, 5, 6, 7, 8, 9];

const makeState = ({ division = 'regional_league', gems = 20, shop = {} } = {}) => ({
  progression: { currentDivision: division },
  resources: { fanCoins: 0, gems, trophies: 0 },
  shop: { ...shop },
});

const out = {
  divisionIds: DIV_IDS,
  maxVoucherTier: sv.MAX_VOUCHER_TIER,
  voucherTiers: sv.VOUCHER_TIERS,
  voucherGemCost: sv.VOUCHER_GEM_COST,
};

// ── What each division offers ───────────────────────────────────────────────
out.tiersFor = {};
for (const divisionId of [...DIV_IDS, 'not_a_division']) {
  out.tiersFor[divisionId] = sv.voucherTiersFor(divisionId);
}
out.tiersForNull = sv.voucherTiersFor(undefined);

out.offered = [];
for (const divisionId of [...DIV_IDS, 'not_a_division']) {
  for (const floor of TIERS) {
    out.offered.push({ divisionId, floor, offered: sv.voucherOffered(divisionId, floor) });
  }
}

out.unlockDivision = {};
for (const floor of [...TIERS, 10]) out.unlockDivision[floor] = sv.voucherUnlockDivision(floor);

out.cost = {};
for (const floor of [...TIERS, 0, 10]) out.cost[floor] = sv.voucherCost(floor);

// ── What the ordinary scout does ────────────────────────────────────────────
out.odds = [];
for (const divisionId of [...DIV_IDS, 'not_a_division']) {
  for (const floor of TIERS) {
    out.odds.push({ divisionId, floor, odds: sv.voucherOdds(divisionId, floor) });
  }
}

// ── What is armed ───────────────────────────────────────────────────────────
// Dumped against the gem catalogue's own `heldWhen` too: the one-voucher rule
// lives in two files that cannot import each other.
const SHOPS = {
  empty: {},
  freeScout: { freeScoutReady: true },
  freeScoutFalse: { freeScoutReady: false },
  floorArmed: { scoutVoucherTier: 5 },
  floorOne: { scoutVoucherTier: 1 },
  floorZero: { scoutVoucherTier: 0 },
  floorNull: { scoutVoucherTier: null },
  floorFractional: { scoutVoucherTier: 5.7 },
  floorInfinite: { scoutVoucherTier: Infinity },
  floorString: { scoutVoucherTier: '5' },
  both: { scoutVoucherTier: 4, freeScoutReady: true },
};

const gemItem = ge.GEM_ITEMS.find((i) => i.id === 'scout_voucher_gem');

out.armed = [];
for (const [label, shop] of Object.entries(SHOPS)) {
  const state = makeState({ shop });
  out.armed.push({
    label,
    held: sv.heldVoucherTier(state),
    armed: sv.anyVoucherArmed(state),
    // The gem catalogue's half of the same rule.
    gemHeld: !!gemItem.heldWhen?.(state),
  });
}
out.armedNoState = { held: sv.heldVoucherTier(null), armed: sv.anyVoucherArmed(null) };
out.armedNoShop = {
  held: sv.heldVoucherTier({ progression: {} }),
  armed: sv.anyVoucherArmed({ progression: {} }),
};

// ── Buying ──────────────────────────────────────────────────────────────────
out.blocked = [];
for (const [label, opts, floor] of [
  ['buyable', { division: 'champions_cup', gems: 20 }, 5],
  ['notOfferedHere', { division: 'sunday_league', gems: 20 }, 5],
  ['tierNineNeverSold', { division: 'champions_cup', gems: 20 }, 9],
  ['tierOneNeverSold', { division: 'champions_cup', gems: 20 }, 1],
  ['noPrice', { division: 'champions_cup', gems: 20 }, 10],
  ['alreadyHoldingAFloor', { division: 'champions_cup', gems: 20, shop: { scoutVoucherTier: 3 } }, 5],
  ['alreadyHoldingAFreeScout', { division: 'champions_cup', gems: 20, shop: { freeScoutReady: true } }, 5],
  ['tooFewGems', { division: 'champions_cup', gems: 4 }, 5],
  ['exactlyEnoughGems', { division: 'champions_cup', gems: 5 }, 5],
]) {
  out.blocked.push({ label, floor, ...opts, blocked: sv.voucherBlocked(makeState(opts), floor) ?? null });
}
out.blockedNoState = sv.voucherBlocked(null, 5) ?? null;

out.buy = [];
for (const [label, opts, floor] of [
  ['buysAndArms', { division: 'champions_cup', gems: 20 }, 8],
  ['cheapestRung', { division: 'amateur_cup', gems: 20 }, 2],
  ['refusedNotOffered', { division: 'sunday_league', gems: 20 }, 5],
  ['refusedTooPoor', { division: 'champions_cup', gems: 1 }, 8],
  ['refusedAlreadyArmed', { division: 'champions_cup', gems: 20, shop: { scoutVoucherTier: 2 } }, 8],
]) {
  const state = makeState(opts);
  const result = sv.buyScoutVoucher(state, floor);
  out.buy.push({ label, floor, result, gems: state.resources.gems, shop: clone(state.shop) });
}

// A save with no shop branch at all still arms one.
out.buyNoShopBranch = (() => {
  const state = { progression: { currentDivision: 'champions_cup' }, resources: { gems: 20 } };
  const result = sv.buyScoutVoucher(state, 6);
  return { result, shop: clone(state.shop), gems: state.resources.gems };
})();

// ── Spending ────────────────────────────────────────────────────────────────
out.consume = [];
for (const [label, shop] of [
  ['armed', { scoutVoucherTier: 7 }],
  ['fractional', { scoutVoucherTier: 7.9 }],
  ['none', {}],
  ['tierOne', { scoutVoucherTier: 1 }],
  ['freeScoutOnly', { freeScoutReady: true }],
]) {
  const state = makeState({ shop });
  const floor = sv.consumeScoutVoucher(state);
  out.consume.push({ label, floor, shop: clone(state.shop), armedAfter: sv.anyVoucherArmed(state) });
}

// Buy, then spend, then the shop is clear enough to buy again.
out.roundTrip = (() => {
  const state = makeState({ division: 'champions_cup', gems: 20 });
  const first = sv.buyScoutVoucher(state, 4);
  const blockedWhileArmed = sv.voucherBlocked(state, 6) ?? null;
  const spent = sv.consumeScoutVoucher(state);
  const second = sv.buyScoutVoucher(state, 6);
  return { first, blockedWhileArmed, spent, second, gems: state.resources.gems, shop: clone(state.shop) };
})();

// ── The ladder's shape ──────────────────────────────────────────────────────
// Exactly one new rung lights up per promotion, which is what stops the Shop
// growing two chips on one row.
out.ladder = DIV_IDS.map((divisionId, i) => ({
  divisionId,
  tiers: sv.voucherTiersFor(divisionId),
  newRungs: sv.voucherTiersFor(divisionId)
    .filter((t) => i === 0 || !sv.voucherTiersFor(DIV_IDS[i - 1]).includes(t)),
}));

process.stdout.write(JSON.stringify(out));
