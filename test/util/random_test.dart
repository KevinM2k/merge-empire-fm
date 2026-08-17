import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/util/random.dart';

/// Reference values generated from the JS implementation
/// (`../merge-empire-fc/src/utils/random.js`) via node. mulberry32 relies on
/// `Math.imul`, `|0` and `>>>` — 32-bit semantics Dart does not share by
/// default — so these pin bit-exact parity rather than mere plausibility.
///
/// Regenerate with tool/dump_random_reference.mjs.
const _reference = <int, List<double>>{
  0: [
    0.26642920868471265,
    0.0003297457005828619,
    0.2232720274478197,
    0.1462021479383111,
    0.46732782293111086,
    0.5450490827206522,
    0.6152513844426721,
    0.6489853798411787,
  ],
  1: [
    0.6270739405881613,
    0.002735721180215478,
    0.5274470399599522,
    0.9810509674716741,
    0.9683778982143849,
    0.281103502959013,
    0.6128388606011868,
    0.7207431411370635,
  ],
  12345: [
    0.9797282677609473,
    0.3067522644996643,
    0.484205421525985,
    0.817934412509203,
    0.5094283693470061,
    0.34747186047025025,
    0.07375754183158278,
    0.7663964673411101,
  ],
  999999937: [
    0.4222431951202452,
    0.7476034415885806,
    0.033541144570335746,
    0.15489679691381752,
    0.4536716346628964,
    0.2804461740888655,
    0.856395430630073,
    0.9628198486752808,
  ],
  2147483647: [
    0.4290980885270983,
    0.12713524978607893,
    0.3852774982806295,
    0.39639189024455845,
    0.11962746665813029,
    0.9531875969842076,
    0.6806830384302884,
    0.9957805015146732,
  ],
  -1: [
    0.8964226141106337,
    0.189478256739676,
    0.7156526781618595,
    0.9440599093213677,
    0.8452364315744489,
    0.5391399988438934,
    0.6804977387655526,
    0.4755720964167267,
  ],
  -2147483648: [
    0.8205775609239936,
    0.4481089550536126,
    0.7836112855002284,
    0.5120457962621003,
    0.8388098266441375,
    0.4205148529727012,
    0.8944806265644729,
    0.9326926763169467,
  ],
};

void main() {
  setUp(() => setSeed(12345));

  group('mulberry32 parity with JS', () {
    _reference.forEach((seed, expected) {
      test('seed $seed reproduces the JS stream exactly', () {
        setSeed(seed);
        for (var i = 0; i < expected.length; i++) {
          expect(
            random(),
            expected[i],
            reason: 'seed $seed, draw $i diverged from the JS reference',
          );
        }
      });
    });
  });

  group('random', () {
    test('returns values in [0, 1)', () {
      for (var i = 0; i < 500; i++) {
        final r = random();
        expect(r, greaterThanOrEqualTo(0));
        expect(r, lessThan(1));
      }
    });
  });

  group('randomInt', () {
    test('returns values within the inclusive range', () {
      for (var i = 0; i < 200; i++) {
        final r = randomInt(3, 7);
        expect(r, greaterThanOrEqualTo(3));
        expect(r, lessThanOrEqualTo(7));
      }
    });

    test('matches the JS sequence for randomInt(3, 7)', () {
      setSeed(12345);
      final got = List.generate(10, (_) => randomInt(3, 7));
      expect(got, [7, 4, 5, 7, 5, 4, 3, 6, 7, 7]);
    });

    test('a zero-width range returns that single value', () {
      expect(randomInt(5, 5), 5);
    });
  });

  group('weightedPick', () {
    test('matches the JS sequence', () {
      setSeed(12345);
      final pool = [
        const WeightedEntry('bronze', 70),
        const WeightedEntry('silver', 25),
        const WeightedEntry('gold', 5),
      ];
      final got = List.generate(12, (_) => weightedPick(pool));
      expect(got, [
        'gold',
        'bronze',
        'bronze',
        'silver',
        'bronze',
        'bronze',
        'bronze',
        'silver',
        'gold',
        'silver',
        'bronze',
        'silver',
      ]);
    });

    test('a single-entry pool always returns that item', () {
      expect(weightedPick([const WeightedEntry('only', 1)]), 'only');
    });

    test('always returns a member of the pool', () {
      final pool = [
        const WeightedEntry('a', 70),
        const WeightedEntry('b', 25),
        const WeightedEntry('c', 5),
      ];
      for (var i = 0; i < 100; i++) {
        expect(['a', 'b', 'c'], contains(weightedPick(pool)));
      }
    });

    test('zero-weight entries are never picked', () {
      final pool = [
        const WeightedEntry('never', 0),
        const WeightedEntry('always', 10),
      ];
      for (var i = 0; i < 100; i++) {
        expect(weightedPick(pool), 'always');
      }
    });
  });

  group('pickRandom', () {
    test('matches the JS sequence', () {
      setSeed(12345);
      final got = List.generate(8, (_) => pickRandom(['a', 'b', 'c', 'd']));
      expect(got, ['d', 'b', 'b', 'd', 'c', 'b', 'a', 'd']);
    });
  });

  group('shuffle', () {
    test('matches the JS permutation exactly', () {
      setSeed(12345);
      expect(shuffle([1, 2, 3, 4, 5, 6, 7, 8]), [4, 1, 2, 6, 5, 7, 3, 8]);
    });

    test('returns all original elements', () {
      final shuffled = shuffle([1, 2, 3, 4, 5])..sort();
      expect(shuffled, [1, 2, 3, 4, 5]);
    });

    test('does not mutate the original', () {
      final original = [1, 2, 3];
      shuffle(original);
      expect(original, [1, 2, 3]);
    });

    test('an empty list shuffles to an empty list', () {
      expect(shuffle(<int>[]), isEmpty);
    });
  });

  group('withSeed', () {
    test('runs off the given seed and resumes the stream mid-flow', () {
      setSeed(12345);
      // Advance the shared stream one draw, so restoration has something
      // non-trivial to put back.
      expect(random(), _reference[12345]![0]);

      final inner = withSeed(999999937, () => random());
      expect(inner, _reference[999999937]![0]);

      // The shared stream picks up at draw 1, exactly where it left off.
      expect(random(), _reference[12345]![1]);
    });

    test('restores the seed even when fn throws', () {
      setSeed(12345);
      expect(
        () => withSeed(1, () => throw StateError('boom')),
        throwsStateError,
      );
      // Stream untouched: still on the first draw for 12345.
      expect(random(), _reference[12345]![0]);
    });

    test('passes the return value through', () {
      expect(withSeed(1, () => 'value'), 'value');
    });
  });
}
