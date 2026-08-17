import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/match_resolution.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;

MatchRatings _ratings(double oa, double od, double pa, double pd) =>
    (ourAttack: oa, ourDefence: od, oppAttack: pa, oppDefence: pd);

void main() {
  group('resolveScoreline — seeded parity with node', () {
    test('reproduces the JS scorelines exactly', () {
      // The two-line core: our ATK vs their DEF, then their ATK vs our DEF,
      // sampled in that order from the shared seeded stream.
      const cases = <(MatchRatings, List<List<int>>)>[
        (
          (ourAttack: 62, ourDefence: 58, oppAttack: 55, oppDefence: 60),
          [[1, 3], [1, 1], [4, 2], [1, 0], [1, 0], [0, 0], [1, 2], [1, 1]],
        ),
        (
          (ourAttack: 70, ourDefence: 65, oppAttack: 50, oppDefence: 52),
          [[3, 1], [1, 0], [5, 2], [1, 0], [1, 0], [0, 0], [2, 1], [1, 1]],
        ),
        (
          (ourAttack: 40, ourDefence: 42, oppAttack: 75, oppDefence: 78),
          [[0, 3], [0, 1], [0, 5], [0, 2], [0, 1], [0, 1], [0, 2], [0, 2]],
        ),
      ];

      for (final (ratings, expected) in cases) {
        seeded.setSeed(4242);
        final got = [
          for (var i = 0; i < expected.length; i++)
            () {
              final s = resolveScoreline(ratings);
              return [s.home, s.away];
            }(),
        ];
        expect(got, expected, reason: '$ratings');
      }
    });

    test('reproduces the JS at raised variance', () {
      seeded.setSeed(77);
      final got = [
        for (var i = 0; i < 6; i++)
          () {
            final s = resolveScoreline(
              _ratings(62, 60, 55, 58),
              variance: 1.15,
            );
            return [s.home, s.away];
          }(),
      ];
      expect(got, [[1, 2], [3, 0], [4, 0], [0, 0], [3, 1], [0, 0]]);
    });

    test('the sampling ORDER is load-bearing', () {
      // Ours first, theirs second — swapping them draws different numbers off
      // the shared stream and changes every scoreline after it.
      seeded.setSeed(4242);
      final ours = resolveScoreline(_ratings(62, 58, 55, 60));

      seeded.setSeed(4242);
      final away = simulateGoalsShim(55, 58);
      final home = simulateGoalsShim(62, 60);
      expect([home, away], isNot([ours.home, ours.away]));
    });

    test('is deterministic for a given seed', () {
      seeded.setSeed(9);
      final a = List.generate(10, (_) => resolveScoreline(_ratings(60, 60, 60, 60)));
      seeded.setSeed(9);
      final b = List.generate(10, (_) => resolveScoreline(_ratings(60, 60, 60, 60)));
      expect(a.map((s) => [s.home, s.away]), b.map((s) => [s.home, s.away]));
    });
  });

  group('the ATK-vs-DEF pairing', () {
    test('a stronger attack against a weaker defence scores more', () {
      seeded.setSeed(1);
      var strong = 0;
      var weak = 0;
      for (var i = 0; i < 2000; i++) {
        strong += resolveScoreline(_ratings(80, 60, 60, 40)).home;
      }
      seeded.setSeed(1);
      for (var i = 0; i < 2000; i++) {
        weak += resolveScoreline(_ratings(40, 60, 60, 80)).home;
      }
      expect(strong, greaterThan(weak * 3));
    });

    test('our defence only ever affects THEIR goals', () {
      seeded.setSeed(3);
      final solid = <int>[];
      for (var i = 0; i < 1500; i++) {
        solid.add(resolveScoreline(_ratings(60, 90, 60, 60)).away);
      }
      seeded.setSeed(3);
      final leaky = <int>[];
      for (var i = 0; i < 1500; i++) {
        leaky.add(resolveScoreline(_ratings(60, 30, 60, 60)).away);
      }
      expect(solid.reduce((a, b) => a + b), lessThan(leaky.reduce((a, b) => a + b)));
    });

    test('an even match is symmetric over many runs', () {
      seeded.setSeed(2024);
      var home = 0;
      var away = 0;
      for (var i = 0; i < 5000; i++) {
        final s = resolveScoreline(_ratings(60, 60, 60, 60));
        home += s.home;
        away += s.away;
      }
      expect(home / away, closeTo(1.0, 0.1));
    });
  });

  group('applySquadModifiers', () {
    test('adds home advantage below the cap', () {
      final r = applySquadModifiers(baseAttack: 60, baseDefence: 55, homeAdv: 4);
      expect(r.attack, 64);
      expect(r.defence, 59);
    });

    test('home advantage alone cannot exceed 100', () {
      final r = applySquadModifiers(baseAttack: 99, baseDefence: 99, homeAdv: 4);
      expect(r.attack, 100);
    });

    test('earned buffs apply AFTER the cap', () {
      // A maxed side can still be lifted past 100 by what it has earned.
      final r = applySquadModifiers(
        baseAttack: 99,
        baseDefence: 99,
        homeAdv: 4,
        stagnation: 3,
        relegationZone: true,
      );
      expect(r.attack, 100 + 3 + relegationBoost);
    });

    test('is neutral with no modifiers', () {
      final r = applySquadModifiers(baseAttack: 60, baseDefence: 55);
      expect(r.attack, 60);
      expect(r.defence, 55);
    });
  });

  group('applyOpponentModifiers', () {
    test('adds their home advantage', () {
      final r = applyOpponentModifiers(baseAttack: 60, baseDefence: 55, homeAdv: 3);
      expect(r.attack, 63);
      expect(r.defence, 58);
    });

    test('their defence has a floor ours does not', () {
      // A side with no defence at all would hand an unbounded rate through the
      // lambda curve.
      final r = applyOpponentModifiers(baseAttack: 60, baseDefence: 2);
      expect(r.defence, 10);
    });

    test('a grudge lifts both their stats', () {
      final plain = applyOpponentModifiers(baseAttack: 60, baseDefence: 60);
      final fired = applyOpponentModifiers(
        baseAttack: 60,
        baseDefence: 60,
        grudgeBoost: 2,
      );
      expect(fired.attack, plain.attack + 2);
      expect(fired.defence, plain.defence + 2);
    });

    test('relegation resilience lifts both', () {
      final r = applyOpponentModifiers(
        baseAttack: 20,
        baseDefence: 20,
        relegationZone: true,
      );
      expect(r.attack, 20 + relegationBoost);
    });
  });

  group('applyTactic', () {
    test('parking the bus raises OUR defence, not their attack', () {
      final r = applyTactic(
        attack: 60,
        defence: 60,
        strategy: strategies['parkTheBus'],
      );
      expect(r.defence, greaterThan(60));
      expect(r.attack, lessThan(60));
    });

    test('floors at one so a rating can never reach zero', () {
      final r = applyTactic(
        attack: 0.5,
        defence: 0.5,
        strategy: strategies['parkTheBus'],
      );
      expect(r.attack, greaterThanOrEqualTo(1));
      expect(r.defence, greaterThanOrEqualTo(1));
    });

    test('Counter Attack reads the opponent shape', () {
      final vsOpen = applyTactic(
        attack: 60,
        defence: 60,
        strategy: strategies['counterAttack'],
        oppAttackRatio: 0.46,
      );
      final vsDeep = applyTactic(
        attack: 60,
        defence: 60,
        strategy: strategies['counterAttack'],
        oppAttackRatio: 0.30,
      );
      expect(vsOpen.attack, greaterThan(vsDeep.attack));
    });

    test('a null strategy leaves the ratings alone', () {
      final r = applyTactic(attack: 60, defence: 55, strategy: null);
      expect(r.attack, 60);
      expect(r.defence, 55);
    });
  });

  group('rollMatchVariance', () {
    test('is the tactic tempo when there is no swing', () {
      seeded.setSeed(1);
      expect(rollMatchVariance(strategies['allOutAttack']), 1.15);
      expect(rollMatchVariance(strategies['parkTheBus']), 0.88);
    });

    test('a swinging tactic lands hot or cold', () {
      seeded.setSeed(5);
      final counter = strategies['counterAttack']!;
      final seen = {for (var i = 0; i < 200; i++) rollMatchVariance(counter)};
      expect(seen, {
        counter.variance * (1 - counter.swing),
        counter.variance * (1 + counter.swing),
      });
    });
  });

  group('resolveSegmented', () {
    test('a single full window matches a one-shot resolution', () {
      final r = _ratings(62, 58, 55, 60);
      seeded.setSeed(31);
      final segmented = resolveSegmented([(upToMinute: 90, ratings: r)]);
      seeded.setSeed(31);
      final oneShot = resolveScoreline(r);
      expect([segmented.home, segmented.away], [oneShot.home, oneShot.away]);
    });

    test('a weakened second window concedes more', () {
      // The Casual injury path: full strength, then a man down.
      final strong = _ratings(62, 62, 60, 60);
      final weak = _ratings(50, 50, 60, 60);

      seeded.setSeed(8);
      var conceded = 0;
      for (var i = 0; i < 800; i++) {
        conceded += resolveSegmented([
          (upToMinute: 30, ratings: strong),
          (upToMinute: 90, ratings: weak),
        ]).away;
      }

      seeded.setSeed(8);
      var whole = 0;
      for (var i = 0; i < 800; i++) {
        whole += resolveSegmented([(upToMinute: 90, ratings: strong)]).away;
      }

      expect(conceded, greaterThan(whole));
    });

    test('an empty window list is goalless', () {
      expect(resolveSegmented([]), (home: 0, away: 0));
    });

    test('a zero-length window scores nothing', () {
      seeded.setSeed(2);
      final s = resolveSegmented([(upToMinute: 0, ratings: _ratings(90, 90, 20, 20))]);
      expect(s, (home: 0, away: 0));
    });

    test('windows sample at their OWN rate, keeping a late burst possible', () {
      // Rather than scaling a full-match count down, which made two goals in
      // twenty minutes impossible.
      seeded.setSeed(17);
      var sawBurst = false;
      for (var i = 0; i < 4000 && !sawBurst; i++) {
        final s = resolveSegmented([
          (upToMinute: 70, ratings: _ratings(1, 90, 1, 90)),
          (upToMinute: 90, ratings: _ratings(95, 90, 1, 90)),
        ]);
        if (s.home >= 2) sawBurst = true;
      }
      expect(sawBurst, isTrue);
    });
  });

  group('outcome and forceWin', () {
    test('reads a scoreline', () {
      expect(outcomeOf((home: 2, away: 1)).won, isTrue);
      expect(outcomeOf((home: 1, away: 1)).drawn, isTrue);
      expect(outcomeOf((home: 0, away: 1)).lost, isTrue);
    });

    test('exactly one outcome is ever true', () {
      for (final s in [(home: 3, away: 0), (home: 1, away: 1), (home: 0, away: 2)]) {
        final o = outcomeOf(s);
        expect([o.won, o.drawn, o.lost].where((b) => b).length, 1);
      }
    });

    test('forceWin lifts a loss or draw by one goal', () {
      expect(forceWin((home: 0, away: 2)), (home: 3, away: 2));
      expect(forceWin((home: 1, away: 1)), (home: 2, away: 1));
    });

    test('forceWin leaves a win alone', () {
      expect(forceWin((home: 4, away: 1)), (home: 4, away: 1));
    });

    test('home always holds the player goals, whatever the venue', () {
      // Being home affects the advantage bonus and display order, never which
      // variable holds whose goals.
      expect(outcomeOf(forceWin((home: 0, away: 5))).won, isTrue);
    });
  });
}

/// Direct access to the goal sampler, so the ordering test can draw the two
/// samples the other way round.
int simulateGoalsShim(num atk, num def) => resolveScoreline((
  ourAttack: atk.toDouble(),
  ourDefence: 1,
  oppAttack: 1,
  oppDefence: def.toDouble(),
)).home;
