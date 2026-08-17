// Every team name the banks in progressionEngine.js can produce, sorted the way
// the JS league table sorts them (`String.localeCompare`).
//
// The Dart port can't call localeCompare, so `compareTeamNames` folds accents
// and compares case-insensitively instead. This fixture is what proves the two
// orders are identical across the whole name space rather than merely on the
// ASCII majority.
//
//   node tool/dump_team_name_order.mjs > test/fixtures/team_name_order.json

import { readFileSync } from 'node:fs';

const src = readFileSync(
  new URL('../../merge-empire-fc/src/engine/progressionEngine.js', import.meta.url),
  'utf8',
);

// Pull the banks straight out of the source so the fixture can never drift from
// the names the game actually generates.
const bank = (name) => {
  const m = src.match(new RegExp(`const ${name} = \\[([\\s\\S]*?)\\];`));
  if (!m) throw new Error(`bank ${name} not found`);
  return [...m[1].matchAll(/'((?:[^'\\]|\\.)*)'/g)].map((x) => x[1]);
};

const GR = bank('_GR_FIRST');
const SP = bank('_SP_FIRST');
const PRO_PREFIX = bank('_PRO_PREFIX');
const PRO_NOUN = bank('_PRO_NOUN');
const SUFFIX = bank('_SUFFIX');

const names = new Set();
for (const first of [...GR, ...SP]) {
  for (const suffix of SUFFIX) names.add(`${first} ${suffix}`);
}
for (const prefix of PRO_PREFIX) {
  for (const noun of PRO_NOUN) names.add(`${prefix} ${noun}`);
}
// The statistically-unreachable fallback, which is still a name a table can hold.
for (let n = 1; n <= 3; n++) names.add(`Valley United ${n}`);

const sorted = [...names].sort((a, b) => String(a).localeCompare(String(b)));
process.stdout.write(JSON.stringify({ sorted }, null, 0));
