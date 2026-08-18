// Reference costs for the Shop's three coin consumables.
//
// Their pricing never left `ui/screens/ShopScreen.js`, so it is transcribed here
// from `_scaledCost` and `_spongeCost` rather than imported — there is no module
// to import. That makes the fixture the only check on the arithmetic, so it
// covers every division and the whole sponge ramp including its cap.
//
//   node tool/dump_shop_consumables_reference.mjs > test/fixtures/shop_consumables_reference.json

const { DIVISIONS, getDivision } = await import('../../merge-empire-fc/src/data/divisions.js');
const { roundCoins } = await import('../../merge-empire-fc/src/utils/format.js');

// _scaledCost: prices scale with division — always ~5-8 match wins worth.
const scaledCost = (divisionId, base) => {
  const div = getDivision(divisionId);
  return roundCoins(base * (div.matchRevenueBase / 100));
};

// _spongeCost: capped at x3. The old ramp was 2^uses and unbounded, which made
// the third heal cost 60+ matches worth at every division.
const spongeCost = (divisionId, uses) =>
  roundCoins(scaledCost(divisionId, 1500) * Math.min(3, 1 + uses * 0.5));

const out = { scaled: {}, sponge: {} };

for (const div of DIVISIONS) {
  out.scaled[div.id] = {
    sponge_base: scaledCost(div.id, 1500),
    kit_sponsor: scaledCost(div.id, 5000),
    match_rev: scaledCost(div.id, 3500),
    matchRevenueBase: div.matchRevenueBase,
  };
  out.sponge[div.id] = [0, 1, 2, 3, 4, 5, 10].map((uses) => ({
    uses,
    cost: spongeCost(div.id, uses),
  }));
}

process.stdout.write(JSON.stringify(out, null, 2));
