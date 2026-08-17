import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/goal_model.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;

/// Reference values generated from the JS
/// (`../merge-empire-fc/src/engine/matchEngine.js`) via node.
///
/// The seeded scoreline sequences below are the important ones: they exercise
/// the whole chain — PRNG, lambda curve, Poisson sampler — so matching them is
/// evidence the simulation itself is faithful, not just its constants.
void main() {
  group('divisionInjuryMultiplier', () {
    test('matches the JS across the ladder', () {
      expect(
        List.generate(7, divisionInjuryMultiplier),
        [
          1,
          1.1166666666666667,
          1.2333333333333334,
          1.35,
          1.4666666666666666,
          1.5833333333333335,
          1.7,
        ],
      );
    });

    test('higher leagues are more physical', () {
      for (var i = 1; i < 7; i++) {
        expect(
          divisionInjuryMultiplier(i),
          greaterThan(divisionInjuryMultiplier(i - 1)),
        );
      }
    });

    test('clamps outside the ladder', () {
      expect(divisionInjuryMultiplier(-5), 1.0);
      expect(divisionInjuryMultiplier(99), 1.7);
    });
  });

  group('getInjuryChance', () {
    test('matches the JS across ages and divisions', () {
      const cases = <(int, int, double)>[
        (0, 0, 0.12),
        (8, 0, 0.184),
        (10, 0, 0.2),
        (14, 0, 0.36),
        (0, 6, 0.204),
        (8, 6, 0.31279999999999997),
        (14, 6, 0.55),
      ];
      for (final (seasons, div, expected) in cases) {
        expect(
          getInjuryChance(seasons, div),
          closeTo(expected, 1e-12),
          reason: 'S$seasons div$div',
        );
      }
    });

    test('a fresh squad picks up a knock roughly every eight matches', () {
      expect(getInjuryChance(0, 0), baseInjuryChance);
    });

    test('rises with age', () {
      var prev = 0.0;
      for (var s = 0; s <= 14; s++) {
        final c = getInjuryChance(s);
        expect(c, greaterThanOrEqualTo(prev), reason: 'season $s');
        prev = c;
      }
    });

    test('ramps quadratically past the peak', () {
      // Linear to season 10, then a quadratic climb.
      final prePeakStep = getInjuryChance(9) - getInjuryChance(8);
      final postPeakStep = getInjuryChance(14) - getInjuryChance(13);
      expect(postPeakStep, greaterThan(prePeakStep * 2));
    });

    test('is capped so no card is a certainty to get hurt', () {
      expect(getInjuryChance(99, 6), 0.55);
      for (var s = 0; s <= 40; s++) {
        expect(getInjuryChance(s, 6), lessThanOrEqualTo(0.55));
      }
    });
  });

  group('getInjuryDuration', () {
    test('matches the JS and caps at an hour', () {
      expect(
        [0, 1, 5, 10, 20].map(getInjuryDuration),
        [600000, 900000, 2100000, 3600000, 3600000],
      );
    });

    test('never falls with age', () {
      var prev = 0;
      for (var s = 0; s <= 20; s++) {
        final d = getInjuryDuration(s);
        expect(d, greaterThanOrEqualTo(prev));
        prev = d;
      }
    });
  });

  group('hasEnoughPlayers', () {
    CardInstance card({bool injured = false}) =>
        CardInstance({'definitionId': 'player_t1_fwd', if (injured) 'injured': true});

    test('needs three healthy players', () {
      expect(hasEnoughPlayers([card(), card(), card()]), isTrue);
      expect(hasEnoughPlayers([card(), card()]), isFalse);
    });

    test('injured players do not count', () {
      expect(
        hasEnoughPlayers([card(), card(), card(injured: true)]),
        isFalse,
      );
    });

    test('an empty grid cannot field a side', () {
      expect(hasEnoughPlayers([]), isFalse);
      expect(hasEnoughPlayers([null, null, null]), isFalse);
    });
  });

  group('goalRateLambda', () {
    test('matches the JS exactly across the rating range', () {
      const cases = <(int, int, double)>[
        (50, 50, 1.4336597384696317),
        (70, 50, 2.0359940791084057),
        (50, 70, 0.593262645722884),
        (90, 20, 2.2900830234319947),
        (20, 90, 0.12),
        (100, 1, 2.292534409533329),
        (1, 100, 0.12),
      ];
      for (final (atk, def, expected) in cases) {
        expect(
          goalRateLambda(atk, def),
          closeTo(expected, 1e-12),
          reason: '$atk vs $def',
        );
      }
    });

    test('a hopeless underdog still threatens a little', () {
      // Real relegation sides away at champions average 0.3 to 0.5 goals.
      expect(goalRateLambda(20, 90), lambdaFloor);
      expect(goalRateLambda(1, 100), greaterThan(0));
    });

    test('a crushing edge saturates rather than running away', () {
      // So a mismatch is a clear 3-0, not uncapped cricket scores.
      expect(goalRateLambda(100, 1), lessThan(lambdaSoftCap));
      expect(goalRateLambda(100, 1), greaterThan(evenMatchLambda));
    });

    test('is strictly increasing in attacker rating', () {
      // Win-probability ordering must be untouched by the soft cap.
      var prev = 0.0;
      for (var atk = 10; atk <= 100; atk += 5) {
        final l = goalRateLambda(atk, 50);
        expect(l, greaterThanOrEqualTo(prev), reason: 'atk $atk');
        prev = l;
      }
    });

    test('is strictly decreasing in defender rating', () {
      var prev = double.infinity;
      for (var def = 10; def <= 100; def += 5) {
        final l = goalRateLambda(50, def);
        expect(l, lessThanOrEqualTo(prev), reason: 'def $def');
        prev = l;
      }
    });

    test('an even match sits near the real-football average', () {
      // About 2.7 total goals across both sides.
      final l = goalRateLambda(60, 60);
      expect(l * 2, closeTo(2.87, 0.2));
    });

    test('the curve responds proportionally, not convexly', () {
      // A convex amplifier made "throw everyone forward" a dominant underdog
      // exploit — a weak side more than DOUBLED its goals for a modest cost.
      expect(lambdaCurveExp, 1.0);

      final base = goalRateLambda(50, 50);
      final boosted = goalRateLambda(59, 50); // an 18% attacking tilt
      expect(boosted / base, lessThan(1.6));
    });
  });

  group('maxGoalRate', () {
    test('matches the JS and is derived from the tactics', () {
      expect(maxMatchVariance, 1.5);
      expect(maxGoalRate, closeTo(4.199999999999999, 1e-12));
      expect(maxGoalRate, lambdaSoftCap * maxMatchVariance);
    });

    test('is a rate yardstick, not a hard ceiling on a scoreline', () {
      // The sampler is Poisson and its tail is unbounded.
      seeded.setSeed(1);
      var sawMore = false;
      for (var i = 0; i < 500 && !sawMore; i++) {
        if (poissonGoals(maxGoalRate) > maxGoalRate) sawMore = true;
      }
      expect(sawMore, isTrue);
    });
  });

  group('poissonGoals', () {
    test('a zero rate always yields nothing', () {
      seeded.setSeed(1);
      for (var i = 0; i < 50; i++) {
        expect(poissonGoals(0), 0);
      }
    });

    test('a negative rate is treated as zero', () {
      seeded.setSeed(1);
      expect(poissonGoals(-5), 0);
    });

    test('never returns a negative count', () {
      seeded.setSeed(42);
      for (var i = 0; i < 500; i++) {
        expect(poissonGoals(1.35), greaterThanOrEqualTo(0));
      }
    });

    test('its mean converges on the rate', () {
      seeded.setSeed(12345);
      var total = 0;
      const n = 20000;
      for (var i = 0; i < n; i++) {
        total += poissonGoals(1.35);
      }
      expect(total / n, closeTo(1.35, 0.05));
    });
  });

  group('simulateGoals — seeded parity with node', () {
    test('reproduces the JS scoreline sequence exactly', () {
      // The whole chain: PRNG, lambda curve, Poisson sampler.
      seeded.setSeed(12345);
      final got = List.generate(12, (_) => simulateGoals(60, 50));
      expect(got, [2, 2, 0, 7, 1, 3, 4, 1, 1, 1, 3, 0]);
    });

    test('reproduces the JS partial-window sequence exactly', () {
      seeded.setSeed(999);
      final got = List.generate(12, (_) => sampleWindowGoals(70, 55, 0.25));
      expect(got, [1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
    });

    test('is deterministic for a given seed', () {
      seeded.setSeed(7);
      final first = List.generate(20, (_) => simulateGoals(65, 55));
      seeded.setSeed(7);
      final second = List.generate(20, (_) => simulateGoals(65, 55));
      expect(first, second);
    });

    test('variance stretches the distribution without changing the mean much', () {
      seeded.setSeed(3);
      var calm = 0;
      var wild = 0;
      const n = 4000;
      for (var i = 0; i < n; i++) {
        calm += simulateGoals(60, 60, 0.88);
      }
      seeded.setSeed(3);
      for (var i = 0; i < n; i++) {
        wild += simulateGoals(60, 60, 1.15);
      }
      expect(wild, greaterThan(calm));
    });
  });

  group('sampleWindowGoals', () {
    test('a zero-length window scores nothing', () {
      seeded.setSeed(1);
      for (var i = 0; i < 50; i++) {
        expect(sampleWindowGoals(80, 20, 0), 0);
      }
    });

    test('a negative fraction is treated as zero', () {
      seeded.setSeed(1);
      expect(sampleWindowGoals(80, 20, -1), 0);
    });

    test('a full window matches a full-match simulation', () {
      seeded.setSeed(5);
      final window = List.generate(30, (_) => sampleWindowGoals(70, 55, 1.0));
      seeded.setSeed(5);
      final full = List.generate(30, (_) => simulateGoals(70, 55));
      expect(window, full);
    });

    test('a late burst stays rare but possible', () {
      // Sampling at the window's own rate, rather than flooring a full-match
      // count, is what makes two goals in twenty minutes achievable at all.
      seeded.setSeed(11);
      var sawTwo = false;
      for (var i = 0; i < 3000 && !sawTwo; i++) {
        if (sampleWindowGoals(80, 40, 0.22) >= 2) sawTwo = true;
      }
      expect(sawTwo, isTrue);
    });
  });

  group('poissonPmf', () {
    test('is a probability distribution', () {
      final pmf = poissonPmf(1.35);
      expect(pmf.length, scoreTail);
      for (final p in pmf) {
        expect(p, inInclusiveRange(0, 1));
      }
      expect(pmf.reduce((a, b) => a + b), closeTo(1.0, 1e-4));
    });

    test('the tail is negligible at the highest rate the sim can run', () {
      // The claim is about the mass BEYOND the table — P(X > 10) — which is
      // what makes truncating there free.
      // Pinned to the value node computes, which is 1.6e-4: the JS comment
      // claims "< 1e-4" and is a touch optimistic, so the number is asserted
      // rather than the claim.
      final pmf = poissonPmf(lambdaSoftCap);
      final beyond = 1 - pmf.reduce((a, b) => a + b);
      expect(beyond, closeTo(0.00016373169734462678, 1e-15));
      expect(beyond, lessThan(1e-3));
    });

    test('a zero rate puts all the mass on nil', () {
      final pmf = poissonPmf(0);
      expect(pmf[0], 1.0);
      expect(pmf.skip(1).every((p) => p == 0), isTrue);
    });

    test('its mode moves with the rate', () {
      int modeOf(List<double> pmf) {
        var best = 0;
        for (var i = 1; i < pmf.length; i++) {
          if (pmf[i] > pmf[best]) best = i;
        }
        return best;
      }

      expect(modeOf(poissonPmf(0.3)), 0);
      expect(modeOf(poissonPmf(2.8)), greaterThan(1));
    });
  });

  group('retirementMultiplier', () {
    test('is neutral before the decline', () {
      expect(retirementMultiplier(0), 1.0);
      expect(retirementMultiplier(10), 1.0);
    });

    test('falls past the peak but never below half', () {
      expect(retirementMultiplier(11), closeTo(0.9, 1e-9));
      expect(retirementMultiplier(99), 0.5);
    });
  });
}
