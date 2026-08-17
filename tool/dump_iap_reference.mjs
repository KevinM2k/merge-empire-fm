// Reference output from the JS IAP engine.
//
// Two things matter here and neither is subtle arithmetic.
//
// THE CATALOGUE IS A CONTRACT. Every `sku` is a live product id in App Store
// Connect and Play Console; a typo is a SKU that cannot be bought. So the whole
// catalogue is compared field by field rather than spot-checked.
//
// WHAT A PRODUCT PAYS OUT must equal what the shop SAYS it pays out. The two used
// to be computed separately and drifted by 2-3x, which is why getProductGrantCoins
// exists — so both are pinned here, at every division.
//
//   node tool/dump_iap_reference.mjs > test/fixtures/iap_reference.json

import { readFileSync } from 'node:fs';

const FIXED_NOW = 1700000000000;
Date.now = () => FIXED_NOW;

const iap = await import('../../merge-empire-fc/src/engine/iapEngine.js');
const ge = await import('../../merge-empire-fc/src/engine/gemEngine.js');
const ml = await import('../../merge-empire-fc/src/data/managerAvatar.js');

const questRef = JSON.parse(
  readFileSync(new URL('../test/fixtures/quest_engine_reference.json', import.meta.url), 'utf8'),
);

const clone = (v) => JSON.parse(JSON.stringify(v));

const DIVISIONS = ['sunday_league', 'amateur_cup', 'regional_league',
  'national_league', 'elite_league', 'continental', 'champions_cup'];

const baseState = (over = {}) => {
  const s = clone(questRef.state);
  s.resources.fanCoins = 0;
  s.resources.gems = 0;
  s.energy = { current: 0, lastRegenAt: FIXED_NOW };
  s.boosts = {};
  s.shop = {};
  s.prestige = { level: 0 };
  s.settings = { hardMode: false };
  // The reference save sits in Regional League (a x10 coin multiplier), which
  // would make every "at Sunday League" case below silently scaled.
  s.progression.currentDivision = 'sunday_league';
  for (const [k, v] of Object.entries(over)) {
    if (v && typeof v === 'object' && !Array.isArray(v) && s[k] && typeof s[k] === 'object') {
      Object.assign(s[k], v);
    } else {
      s[k] = v;
    }
  }
  return s;
};

/// Only what a purchase writes.
const digest = (s) => ({
  fanCoins: s.resources?.fanCoins ?? null,
  gems: s.resources?.gems ?? null,
  energyCurrent: s.energy?.current ?? null,
  shop: s.shop ?? null,
  boosts: s.boosts ?? null,
  // Pro mode banks a full extra bar per player rather than team pips.
  cardEnergy: (s.grid?.cells ?? []).map((c) => (c ? (c.energy ?? null) : null)),
});

const out = { fixedNow: FIXED_NOW };

// ── the catalogue ─────────────────────────────────────────────────────────
// Every field, in order. A SKU typo is a product nobody can buy.
out.products = iap.PRODUCTS.map((p) => ({ ...p }));
out.shopProductIds = iap.getShopProducts().map((p) => p.id);

// ── division scaling ──────────────────────────────────────────────────────
out.divisionCoinMult = Object.fromEntries(
  [...DIVISIONS, 'nonsense'].map((d) => [
    d, iap.getDivisionCoinMult(baseState({ progression: { currentDivision: d } })),
  ]),
);
out.divisionCoinMultNoState = iap.getDivisionCoinMult(null);

out.coinBundleValuePct = Object.fromEntries(
  iap.PRODUCTS.filter((p) => p.category === 'coins')
    .map((p) => [p.id, iap.getCoinBundleValuePct(p)]),
);

out.vipCoins = Object.fromEntries(
  DIVISIONS.map((d) => [d, iap.getVipCoins(baseState({ progression: { currentDivision: d } }))]),
);

// What the shop SHOWS must equal what the purchase PAYS. These were computed
// separately once and drifted by 2-3x.
out.grantCoins = [];
for (const division of DIVISIONS) {
  for (const p of iap.PRODUCTS) {
    out.grantCoins.push({
      division, id: p.id,
      shown: iap.getProductGrantCoins(baseState({ progression: { currentDivision: division } }), p),
    });
  }
}
out.grantCoinsNoProduct = iap.getProductGrantCoins(baseState(), null);

// ── event gating ──────────────────────────────────────────────────────────
out.eventProducts = {
  // No product is event-gated today, so both of these are empty — which is the
  // fact worth pinning: a gated SKU appearing by accident would show up here.
  activeEvent: iap.getEventProducts(baseState({ events: { active: ['wc2026'] } }), 'wc2026')
    .map((p) => p.id),
  inactiveEvent: iap.getEventProducts(baseState({ events: { active: [] } }), 'wc2026')
    .map((p) => p.id),
};

// ── buying things ─────────────────────────────────────────────────────────
out.purchases = [];
const purchase = (label, productId, over = {}, before = null) => {
  const state = baseState(over);
  if (before) before(state);
  const res = iap.purchaseProduct(state, productId);
  out.purchases.push({
    label, productId,
    ok: res.ok, reason: res.reason ?? null,
    product: res.product ? res.product.id : null,
    state: digest(state),
  });
};

purchase('unknown', 'nope');

// Every product, bought once at Sunday League and once at Champions Cup, so the
// scaling branches are both exercised.
for (const p of iap.PRODUCTS) {
  purchase(`${p.id}@sunday`, p.id);
  purchase(`${p.id}@champions`, p.id, { progression: { currentDivision: 'champions_cup' } });
}

// Pro mode: an energy buy banks a full extra bar per PLAYER, not team pips.
purchase('starter_pack@hard', 'starter_pack', { settings: { hardMode: true } });
purchase('energy_director@hard', 'energy_director', { settings: { hardMode: true } });

// One-time products refuse a second sale, and grant nothing twice.
out.repeatOneTime = (() => {
  const state = baseState();
  const first = iap.purchaseProduct(state, 'starter_pack');
  const after = digest(state);
  const second = iap.purchaseProduct(state, 'starter_pack');
  return {
    first: { ok: first.ok },
    second: { ok: second.ok, reason: second.reason },
    unchanged: JSON.stringify(digest(state)) === JSON.stringify(after),
    state: digest(state),
  };
})();

// A consumable can be bought over and over, and the spend accumulates.
out.repeatConsumable = (() => {
  const state = baseState();
  for (let i = 0; i < 3; i++) iap.purchaseProduct(state, 'coins_small');
  iap.purchaseProduct(state, 'gems_5');
  return digest(state);
})();

// VIP: refused while live, allowed once it has lapsed.
out.vip = (() => {
  const state = baseState();
  const first = iap.purchaseProduct(state, 'vip_pass');
  const whileActive = iap.purchaseProduct(state, 'vip_pass');
  const active = { isVipActive: iap.isVipActive(state), remaining: iap.vipTimeRemaining(state) };
  // Wind the pass back to expired and try again.
  state.shop.vipExpiresAt = FIXED_NOW - 1;
  const expired = { isVipActive: iap.isVipActive(state), remaining: iap.vipTimeRemaining(state) };
  const again = iap.purchaseProduct(state, 'vip_pass');
  return {
    first: { ok: first.ok },
    whileActive: { ok: whileActive.ok, reason: whileActive.reason },
    active, expired,
    again: { ok: again.ok },
    state: digest(state),
  };
})();

out.vipFresh = (() => {
  const state = baseState();
  return { isVipActive: iap.isVipActive(state), remaining: iap.vipTimeRemaining(state) };
})();

// ── the Style Vault must stay the best way to own every look ──────────────
//
// It is the SKU we most want sold, and one that loses to a cheaper bundle reads
// as a trap. Its price is DERIVED: the best gem rate times the gems in the full
// set, minus a margin. Move a pack price, a bundle price or the ladder and this
// is the number that tells you whether the Vault still wins.
out.styleVault = (() => {
  const packs = Object.keys(ml.LOOK_PACKS ?? {});
  const setGems = packs.reduce((sum, id) => sum + ge.packGemCost(id), 0);
  const bundles = iap.PRODUCTS.filter((p) => p.category === 'gems');
  // Cheapest way to buy at least `setGems` gems, buying whole bundles.
  const bestRate = Math.max(...bundles.map((b) => b.gems / b.priceValue));
  const cheapestRoute = Math.min(
    ...bundles.map((b) => Math.ceil(setGems / b.gems) * b.priceValue),
  );
  const vault = iap.PRODUCTS.find((p) => p.id === 'style_vault');
  return {
    packCount: packs.length,
    setGems,
    bestGemsPerPound: bestRate,
    cheapestBundleRoute: cheapestRoute,
    vaultPrice: vault.priceValue,
    vaultWins: vault.priceValue < cheapestRoute,
    // The ceiling the price is derived from.
    ceiling: setGems / bestRate,
  };
})();

// The gem ladder must improve with size at every rung, or the rational move is to
// buy the cheapest one forever and the ladder is decoration.
out.gemLadder = iap.PRODUCTS.filter((p) => p.category === 'gems')
  .map((p) => ({ id: p.id, gems: p.gems, priceValue: p.priceValue, perPound: p.gems / p.priceValue }));

process.stdout.write(JSON.stringify(out));
