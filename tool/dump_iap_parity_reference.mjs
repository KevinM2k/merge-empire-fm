// Seeded reference output from the JS IAP engine.
//
//   node tool/dump_iap_parity_reference.mjs > test/fixtures/iap_reference.json
//
// **THIS SCRIPT WAS MISSING, and the fixture it feeds is one of the strictest
// in the suite.** `iap_parity_test` compares the whole catalogue field for
// field and what all 25 purchases leave in the save — and `dump_iap_reference`,
// which its own doc comment points at, writes a DIFFERENT file
// (`iap_catalogue_reference.json`, a narrower shape). So the one fixture that
// gates every change to what a product pays out had no generator checked in,
// and the row asking for coin packs to hold more than coins was filed as
// blocked partly because of it.
//
// Everything here mirrors `iap_parity_test`'s own helpers — `_baseState`,
// `_digest`, `_productMap`, `setupFor` — because the two only mean anything if
// they are the same questions asked of the two engines.
import fs from 'node:fs';

const iap = await import('../../merge-empire-fc/src/engine/iapEngine.js');
const { DIVISIONS } = await import('../../merge-empire-fc/src/data/divisions.js');

const FIXED_NOW = 1700000000000;
Date.now = () => FIXED_NOW;

const clone = (v) => JSON.parse(JSON.stringify(v));

// The JS has no `getProduct` export — the shop looks products up by scanning
// the array, so this does the same rather than inventing an accessor the spec
// does not have.
const product = (id) => iap.PRODUCTS.find((p) => p.id === id);

// The same save the Dart test starts every case from: the quest fixture's
// state, emptied of everything a purchase writes to.
const refSave = JSON.parse(
  fs.readFileSync('test/fixtures/quest_engine_reference.json', 'utf8'),
);

const baseState = ({
  division = 'sunday_league',
  hardMode = false,
  activeEvents = [],
} = {}) => {
  const s = clone(refSave.state);
  s.resources.fanCoins = 0;
  s.resources.gems = 0;
  s.energy = { current: 0, lastRegenAt: FIXED_NOW };
  s.boosts = {};
  s.shop = {};
  s.prestige = { level: 0 };
  s.settings = { hardMode };
  s.progression.currentDivision = division;
  if (activeEvents.length) s.events = { active: activeEvents };
  return s;
};

// The slice of the save the comparison actually reads.
const digest = (s) => ({
  fanCoins: s.resources?.fanCoins,
  gems: s.resources?.gems,
  energyCurrent: s.energy?.current,
  shop: s.shop,
  boosts: s.boosts,
  cardEnergy: (s.grid?.cells ?? []).map((c) => c?.energy ?? null),
});

// Every field, so a SKU typo shows up rather than being spot-checked past.
const productMap = (p) => {
  const out = {
    id: p.id,
    sku: p.sku,
    type: p.type,
    category: p.category,
    name: p.name,
    icon: p.icon,
  };
  if (p.desc != null) out.desc = p.desc;
  out.price = p.price;
  out.priceValue = p.priceValue;
  if (p.coins != null) out.coins = p.coins;
  if (p.popular !== undefined) out.popular = p.popular;
  if (p.bonus != null) out.bonus = p.bonus;
  if (p.descHard != null) out.descHard = p.descHard;
  if (p.coinsScaleWithDivision) out.coinsScaleWithDivision = true;
  if (p.energyAdd != null) out.energyAdd = p.energyAdd;
  if (p.oneTime) out.oneTime = true;
  if (p.vipCoinsPerWin != null) out.vipCoinsPerWin = p.vipCoinsPerWin;
  if (p.vipDays != null) out.vipDays = p.vipDays;
  if (p.energyDirector) out.energyDirector = true;
  if (p.gems != null) out.gems = p.gems;
  if (p.styleVault) out.styleVault = true;
  return out;
};

const out = { fixedNow: FIXED_NOW };

out.products = iap.PRODUCTS.map(productMap);
out.shopProductIds = iap.getShopProducts().map((p) => p.id);

// ── division scaling ───────────────────────────────────────────────────────
out.divisionCoinMult = {};
for (const d of DIVISIONS) {
  out.divisionCoinMult[d.id] = iap.getDivisionCoinMult(baseState({ division: d.id }));
}
out.divisionCoinMult.nonsense = iap.getDivisionCoinMult(baseState({ division: 'nonsense' }));
out.divisionCoinMultNoState = iap.getDivisionCoinMult(null);

out.coinBundleValuePct = {};
for (const id of ['coins_small', 'coins_medium', 'coins_large', 'coins_mega']) {
  out.coinBundleValuePct[id] = iap.getCoinBundleValuePct(product(id));
}

out.vipCoins = {};
for (const d of DIVISIONS) {
  out.vipCoins[d.id] = iap.getVipCoins(baseState({ division: d.id }));
}

// What the shop SHOWS, at every division, for every product that grants coins.
out.grantCoins = [];
for (const d of DIVISIONS) {
  for (const p of iap.PRODUCTS) {
    out.grantCoins.push({
      division: d.id,
      id: p.id,
      shown: iap.getProductGrantCoins(baseState({ division: d.id }), p),
    });
  }
}
out.grantCoinsNoProduct = iap.getProductGrantCoins(baseState(), null);

out.eventProducts = {
  activeEvent: iap.getEventProducts(baseState({ activeEvents: ['wc2026'] }), 'wc2026').map((p) => p.id),
  inactiveEvent: iap.getEventProducts(baseState(), 'wc2026').map((p) => p.id),
};

// ── one purchase per product per division, plus the two Pro-mode branches ───
const buy = (label, productId, setup = {}) => {
  const state = baseState(setup);
  const res = iap.purchaseProduct(state, productId);
  return {
    label,
    productId: productId ?? null,
    ok: res.ok,
    reason: res.reason ?? null,
    product: res.product?.id ?? null,
    state: digest(state),
  };
};

out.purchases = [buy('unknown', 'nope')];
for (const p of iap.PRODUCTS) {
  out.purchases.push(buy(`${p.id}@sunday`, p.id));
  out.purchases.push(buy(`${p.id}@champions`, p.id, { division: 'champions_cup' }));
}
// Pro mode changes what these two DO, not just what they say.
out.purchases.push(buy('starter_pack@hard', 'starter_pack', { hardMode: true }));
out.purchases.push(buy('energy_director@hard', 'energy_director', { hardMode: true }));

// ── repeat buys ────────────────────────────────────────────────────────────
{
  const state = baseState();
  const first = iap.purchaseProduct(state, 'starter_pack');
  const after = JSON.stringify(digest(state));
  const second = iap.purchaseProduct(state, 'starter_pack');
  out.repeatOneTime = {
    first: { ok: first.ok },
    second: { ok: second.ok, reason: second.reason ?? null },
    unchanged: JSON.stringify(digest(state)) === after,
    state: digest(state),
  };
}
{
  const state = baseState();
  for (let i = 0; i < 3; i++) iap.purchaseProduct(state, 'coins_small');
  iap.purchaseProduct(state, 'gems_5');
  out.repeatConsumable = digest(state);
}

// ── VIP ────────────────────────────────────────────────────────────────────
{
  const state = baseState();
  const first = iap.purchaseProduct(state, 'vip_pass');
  const whileActive = iap.purchaseProduct(state, 'vip_pass');
  const active = {
    isVipActive: iap.isVipActive(state),
    remaining: iap.vipTimeRemaining(state),
  };
  state.shop.vipExpiresAt = FIXED_NOW - 1;
  const expired = {
    isVipActive: iap.isVipActive(state),
    remaining: iap.vipTimeRemaining(state),
  };
  const again = iap.purchaseProduct(state, 'vip_pass');
  out.vip = {
    first: { ok: first.ok },
    whileActive: { ok: whileActive.ok, reason: whileActive.reason ?? null },
    active,
    expired,
    again: { ok: again.ok },
    state: digest(state),
  };
}
{
  const state = baseState();
  out.vipFresh = {
    isVipActive: iap.isVipActive(state),
    remaining: iap.vipTimeRemaining(state),
  };
}

// ── the gem ladder, and whether the Style Vault still wins ─────────────────
const gemBundles = iap.PRODUCTS.filter((p) => p.category === 'gems');
out.gemLadder = gemBundles.map((p) => ({
  id: p.id,
  gems: p.gems,
  priceValue: p.priceValue,
  perPound: p.gems / p.priceValue,
}));
{
  const packCount = 10;
  const setGems = 50;
  const bestGemsPerPound = Math.max(...gemBundles.map((b) => b.gems / b.priceValue));
  const cheapestBundleRoute = Math.min(
    ...gemBundles.map((b) => Math.ceil(setGems / b.gems) * b.priceValue),
  );
  const vault = product('style_vault');
  out.styleVault = {
    packCount,
    setGems,
    bestGemsPerPound,
    cheapestBundleRoute,
    vaultPrice: vault.priceValue,
    vaultWins: vault.priceValue < cheapestBundleRoute,
    ceiling: setGems / bestGemsPerPound,
  };
}

process.stdout.write(JSON.stringify(out, null, 2));
