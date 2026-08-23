/**
 * The AdMob unit ids, as the SHIPPED app carries them.
 *
 *   node tool/dump_ad_units_reference.mjs > test/fixtures/ad_units_reference.json
 *
 * **A wrong unit id does not fail — it just never pays.** The gate opens, the
 * countdown runs, the player watches nothing and the reward never lands, which
 * reads as the reward being broken rather than the placement being wrong. And
 * the ids are per PLATFORM: an Android unit requested from iOS is a no-fill,
 * for ever, silently.
 *
 * **PARSED rather than imported, and that is deliberate.** The two tables are
 * module-private in `energyEngine.js` — exporting them from there to satisfy a
 * fixture would be changing the spec to suit the port. The shape is a flat
 * `key: 'ca-app-pub-.../...'` map, which is stable enough to read directly and
 * loud enough to fail on if it ever is not.
 */
import fs from 'node:fs';

const src = fs.readFileSync(
  '../merge-empire-fc/src/engine/energyEngine.js',
  'utf8',
);

const table = (name) => {
  const at = src.indexOf(`const ${name} = {`);
  if (at < 0) throw new Error(`${name} not found — has the shape changed?`);
  const body = src.slice(at, src.indexOf('};', at));
  const out = {};
  for (const [, key, unit] of body.matchAll(
    /(\w+)\s*:\s*'(ca-app-pub-[\d/~]+)'/g,
  )) {
    out[key] = unit;
  }
  if (!Object.keys(out).length) throw new Error(`${name} parsed empty`);
  return out;
};

process.stdout.write(
  `${JSON.stringify(
    {
      android: table('REWARDED_BY_PLACEMENT_ANDROID'),
      ios: table('REWARDED_BY_PLACEMENT_IOS'),
    },
    null,
    2,
  )}\n`,
);
