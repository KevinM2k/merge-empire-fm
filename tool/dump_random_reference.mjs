// Regenerates the reference values in test/util/random_test.dart.
//
// The Dart port must reproduce the JS stream draw for draw, so the expectations
// are generated from the JS implementation rather than written by hand.
const m = await import('../../merge-empire-fc/src/utils/random.js');

const SEEDS = [0, 1, 12345, 999999937, 2147483647, -1, -2147483648];

for (const s of SEEDS) {
  m.setSeed(s);
  const draws = Array.from({ length: 8 }, () => m.random());
  console.log(`  ${s}: [\n${draws.map((d) => `    ${d},`).join('\n')}\n  ],`);
}

m.setSeed(12345);
console.log('randomInt(3,7) x10:', JSON.stringify(Array.from({ length: 10 }, () => m.randomInt(3, 7))));

m.setSeed(12345);
console.log('shuffle([1..8]):', JSON.stringify(m.shuffle([1, 2, 3, 4, 5, 6, 7, 8])));

m.setSeed(12345);
const pool = [
  { item: 'bronze', weight: 70 },
  { item: 'silver', weight: 25 },
  { item: 'gold', weight: 5 },
];
console.log('weightedPick x12:', JSON.stringify(Array.from({ length: 12 }, () => m.weightedPick(pool))));

m.setSeed(12345);
console.log('pickRandom x8:', JSON.stringify(Array.from({ length: 8 }, () => m.pickRandom(['a', 'b', 'c', 'd']))));
