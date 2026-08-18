// Reference output from the JS club-asset tier cards.
//
// Every line on a card is DERIVED from the function the game actually gates on,
// with the milestone unlocks computed as a diff across the tier boundary. So the
// whole ladder is dumped, for all seven assets at all eight tiers, plus the
// delta into each one: a port that reimplemented any of those curves would agree
// on most rows and disagree on exactly the rows the original was written to fix
// — Fan Zone's home advantage, which does not step at every tier, and the
// Academy's slot, which does.
//
//   node tool/dump_club_asset_tiers_reference.mjs > test/fixtures/club_asset_tiers_reference.json

const cat = await import('../../merge-empire-fc/src/engine/clubAssetTiers.js');
const { ASSET_META, MAX_ASSET_TIER } = await import('../../merge-empire-fc/src/data/clubAssets.js');

// Declaration order, which is the order the default state writes its keys in.
const KEYS = Object.keys(ASSET_META);

const out = { keys: KEYS, maxAssetTier: MAX_ASSET_TIER };

// Tier 0 is the unbuilt asset and carries nothing; tier 9 is past the end.
out.statsAt = {};
out.unlocksAt = {};
for (const key of KEYS) {
  out.statsAt[key] = {};
  out.unlocksAt[key] = {};
  for (let tier = 0; tier <= MAX_ASSET_TIER + 1; tier++) {
    out.statsAt[key][tier] = cat.assetStatsAt(key, tier);
    out.unlocksAt[key][tier] = cat.assetUnlocksAt(key, tier);
  }
}

out.delta = {};
for (const key of KEYS) {
  out.delta[key] = {};
  for (let tier = 0; tier <= MAX_ASSET_TIER; tier++) {
    out.delta[key][tier] = cat.assetTierDelta(key, tier);
  }
}

out.ladder = {};
for (const key of KEYS) out.ladder[key] = cat.assetLadder(key);

// An asset the catalogue does not know reports nothing rather than throwing.
out.unknownKey = {
  stats: cat.assetStatsAt('NOT_AN_ASSET', 3),
  unlocks: cat.assetUnlocksAt('NOT_AN_ASSET', 3),
  delta: cat.assetTierDelta('NOT_AN_ASSET', 3),
  ladder: cat.assetLadder('NOT_AN_ASSET'),
};

process.stdout.write(JSON.stringify(out));
