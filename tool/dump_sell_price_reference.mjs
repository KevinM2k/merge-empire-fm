// Reference sell prices from the JS.
//
// The division multiplier is a fractional power, which is exactly the sort of
// arithmetic that drifts between two languages without anyone noticing — every
// sale in the game would be a percent or two off.
//
//   node tool/dump_sell_price_reference.mjs > test/fixtures/sell_price_reference.json

const sell = await import('../../merge-empire-fc/src/engine/sellEngine.js');
const { PLAYERS } = await import('../../merge-empire-fc/src/data/players.js');

const DEFS = ['player_t1_gk', 'player_t3_def', 'player_t5_mid', 'player_t7_fwd', 'player_t9_fwd'];
const DIVS = ['sunday_league', 'regional_league', 'elite_league', 'champions_cup'];

const baseSellPrice = {};
for (const id of DEFS) {
  const def = PLAYERS.find((p) => p.id === id);
  for (const division of DIVS) {
    for (const seasonsPlayed of [0, 12]) {
      baseSellPrice[`${id}|${division}|${seasonsPlayed}`] = sell.baseSellPrice(
        def,
        { seasonsPlayed },
        { progression: { currentDivision: division } },
      );
    }
  }
}

process.stdout.write(JSON.stringify({ baseSellPrice }));
