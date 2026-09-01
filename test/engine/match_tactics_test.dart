import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;

/// Reference values generated from the JS
/// (`../merge-empire-fc/src/engine/matchEngine.js`) via node.
void main() {
  group('season shape', () {
    test('an 8-team league is 14 matches', () {
      expect(opponentsPerSeason, 7);
      expect(matchesPerSeason, 14);
      expect(matchesPerSeason, opponentsPerSeason * 2);
    });

    test('a squad of three can still field a side', () {
      expect(minSquadPlayers, 3);
    });
  });

  group('home advantage', () {
    test('is NOTHING with no Fan Zone, then +1 to +4 as one is built', () {
      // **The first tier is what turns the pill on.** It paid +1 at tier 0, so
      // a club with no ground at all had a home advantage and buying the Fan
      // Zone — the one asset whose whole promise is a crowd — moved the pill by
      // nothing. Asked for from the couch, and changed in the SPEC too, because
      // the difftest compares six seasons match by match against it.
      expect(
        List.generate(9, homeAdvantageDisplayFor),
        [0, 1, 2, 2, 3, 3, 3, 4, 4],
      );
    });

    test('the per-stat bonus equals the pill value', () {
      // The pill, the ATK/DEF rows and the star must all move together.
      for (var tier = 0; tier <= 8; tier++) {
        expect(homeAdvantageFor(tier), homeAdvantageDisplayFor(tier));
      }
    });

    test('clamps a tier outside the range', () {
      // A negative tier is no Fan Zone, which is now the same as tier 0.
      expect(homeAdvantageDisplayFor(-5), 0);
      expect(homeAdvantageDisplayFor(99), 4);
    });

    test('never falls as the Fan Zone grows', () {
      var prev = 0;
      for (var tier = 0; tier <= 8; tier++) {
        final v = homeAdvantageDisplayFor(tier);
        expect(v, greaterThanOrEqualTo(prev));
        prev = v;
      }
    });
  });

  group('applyLuckyBoot', () {
    test('matches the JS across the rating scale', () {
      expect(
        [12, 20, 22, 50, 88, 100].map(applyLuckyBoot),
        [10, 16, 18, 40, 70, 80],
      );
    });

    test('a weakening effect never RAISES a rating', () {
      // Every call site used to clamp with max(20, r - 10), so a 12-rated
      // opponent came out at twenty — the weakest teams got stronger when you
      // spent on making them worse.
      for (var r = 1; r <= 100; r++) {
        expect(applyLuckyBoot(r), lessThanOrEqualTo(r), reason: 'rating $r');
      }
    });

    test('takes a consistent proportion at every level', () {
      // A flat reduction cannot work across a 20-to-100 scale.
      for (final r in [25, 50, 100]) {
        expect(applyLuckyBoot(r) / r, closeTo(1 - luckyBootPct, 0.03));
      }
    });

    test('never drops below the floor', () {
      expect(applyLuckyBoot(1), greaterThanOrEqualTo(luckyBootFloor));
      expect(applyLuckyBoot(0), greaterThanOrEqualTo(0));
    });

    test('the quoted reduction is derived, not written down', () {
      expect(luckyBootReduction, 20);
      expect(luckyBootReduction, (luckyBootPct * 100).round());
    });
  });

  group('position weights', () {
    test('attack weights rise up the pitch, defence weights fall', () {
      expect(attackWeights['GK']! < attackWeights['DEF']!, isTrue);
      expect(attackWeights['DEF']! < attackWeights['MID']!, isTrue);
      expect(attackWeights['MID']! < attackWeights['FWD']!, isTrue);

      expect(defenceWeights['GK']! > defenceWeights['DEF']!, isTrue);
      expect(defenceWeights['DEF']! > defenceWeights['MID']!, isTrue);
      expect(defenceWeights['MID']! > defenceWeights['FWD']!, isTrue);
    });

    test('a keeper contributes nothing to attack and everything to defence', () {
      expect(attackWeights['GK'], 0.00);
      expect(defenceWeights['GK'], 1.00);
    });

    test('the two tables mirror each other', () {
      for (final pos in ['GK', 'DEF', 'MID', 'FWD']) {
        expect(attackWeights[pos]! + defenceWeights[pos]!, closeTo(1.0, 1e-9));
      }
    });
  });

  group('teamSplitForFormation', () {
    test('matches the JS at rating 50', () {
      const expected = {
        '3-4-3': (attack: 49, defence: 50),
        '4-3-3': (attack: 48, defence: 50),
        '4-4-2': (attack: 47, defence: 51),
        '5-3-2': (attack: 46, defence: 51),
        '5-4-1': (attack: 45, defence: 52),
      };
      expected.forEach((id, split) {
        expect(teamSplitForFormation(50, id), split, reason: id);
      });
    });

    test('an attacking shape out-attacks a defensive one', () {
      final open = teamSplitForFormation(60, '3-4-3');
      final deep = teamSplitForFormation(60, '5-4-1');
      expect(open.attack, greaterThan(deep.attack));
      expect(open.defence, lessThan(deep.defence));
    });

    test('both stats sit around the rating, not summing to it', () {
      // These are FIFA-style team numbers.
      final split = teamSplitForFormation(60, '4-4-2');
      expect(split.attack, inInclusiveRange(50, 70));
      expect(split.defence, inInclusiveRange(50, 70));
    });

    test('an unknown formation falls back to 4-4-2', () {
      expect(
        teamSplitForFormation(50, 'nonsense'),
        teamSplitForFormation(50, '4-4-2'),
      );
    });

    test('every AI formation fields eleven', () {
      aiFormationPositions.forEach((id, positions) {
        expect(positions.length, 11, reason: id);
        expect(positions.where((p) => p == 'GK').length, 1, reason: id);
      });
    });

    test('the shape name matches the outfield line-up', () {
      aiFormationPositions.forEach((id, positions) {
        final parts = id.split('-').map(int.parse).toList();
        expect(positions.where((p) => p == 'DEF').length, parts.first, reason: id);
        expect(positions.where((p) => p == 'FWD').length, parts.last, reason: id);
      });
    });
  });

  group('opponentAtkDef', () {
    test('matches the JS for a formation id', () {
      expect(opponentAtkDef(60, '4-3-3'), (attack: 58, defence: 60));
    });

    test('a legacy bare share maps to the closest formation', () {
      expect(opponentAtkDefFromShare(60, 0.45), (attack: 59, defence: 60));
    });

    test('an unknown formation falls back to the base share', () {
      expect(
        opponentAtkDef(60, 'nonsense'),
        opponentAtkDefFromShare(60, oppBaseAtkShare),
      );
    });
  });

  group('formationForShare', () {
    test('maps shares onto shapes at the documented midpoints', () {
      expect(formationForShare(0.50), '3-4-3');
      expect(formationForShare(0.444), '3-4-3');
      expect(formationForShare(0.43), '4-3-3');
      expect(formationForShare(0.40), '4-4-2');
      expect(formationForShare(0.37), '5-3-2');
      expect(formationForShare(0.30), '5-4-1');
    });

    test('is monotonic — a more attacking share never yields a deeper shape', () {
      const order = ['5-4-1', '5-3-2', '4-4-2', '4-3-3', '3-4-3'];
      var prev = 0;
      for (var share = 0.30; share <= 0.50; share += 0.005) {
        final idx = order.indexOf(formationForShare(share));
        expect(idx, greaterThanOrEqualTo(prev), reason: 'share $share');
        prev = idx;
      }
    });
  });

  group('tactics', () {
    test('there are five, and balanced is the default', () {
      expect(strategies.length, 5);
      expect(defaultStrategy, 'balanced');
      expect(strategies.containsKey(defaultStrategy), isTrue);
    });

    test('EVERY tactic is zero-sum on composite rating', () {
      // A tactic redistributes strength, it does not create it. An older
      // version let High Press sum to 2.09, which let underdogs over-perform.
      strategies.forEach((id, s) {
        expect(s.atkMult + s.defMult, closeTo(2.0, 1e-9), reason: id);
      });
    });

    test('balanced changes nothing', () {
      final b = strategies['balanced']!;
      expect(b.atkMult, 1.0);
      expect(b.defMult, 1.0);
      expect(b.injMod, 1.0);
      expect(b.variance, 1.0);
      expect(b.swing, 0);
    });

    test('the two attacking tactics differ in the KIND of risk', () {
      final press = strategies['highPress']!;
      final allOut = strategies['allOutAttack']!;

      // High Press: the bigger tilt, priced in bodies.
      expect(press.atkMult, greaterThan(allOut.atkMult));
      expect(press.injMod, greaterThan(allOut.injMod));

      // All Out Attack: the higher tempo, buying chaos rather than strength.
      expect(allOut.variance, greaterThan(press.variance));
    });

    test('High Press is not strictly dominated', () {
      // It shipped as All Out Attack with a smaller tilt, less tempo and more
      // injury risk — dominated on every axis, so never correct.
      final press = strategies['highPress']!;
      final allOut = strategies['allOutAttack']!;
      final betterSomewhere = press.atkMult > allOut.atkMult ||
          press.variance > allOut.variance ||
          press.injMod < allOut.injMod;
      expect(betterSomewhere, isTrue);
    });

    test('defending caps upside — a smaller swing at lower tempo', () {
      final bus = strategies['parkTheBus']!;
      final allOut = strategies['allOutAttack']!;
      expect(bus.variance, lessThan(1.0));
      expect((bus.defMult - 1).abs(), lessThan((allOut.atkMult - 1).abs()));
    });

    test('only Counter Attack carries a swing and a commitment read', () {
      final withSwing = strategies.values.where((s) => s.swing != 0);
      expect(withSwing.map((s) => s.id), ['counterAttack']);

      final withRead = strategies.values.where((s) => s.commitmentGain != 0);
      expect(withRead.map((s) => s.id), ['counterAttack']);
    });

    test('every tactic has a hint and a description', () {
      strategies.forEach((id, s) {
        expect(s.hint, isNotEmpty, reason: id);
        expect(strategyDescriptions[id], isNotNull, reason: id);
      });
    });

    test('possession tracks the attacking tilt', () {
      final sorted = strategies.values.toList()
        ..sort((a, b) => a.atkMult.compareTo(b.atkMult));
      expect(sorted.first.possession, lessThan(sorted.last.possession));
    });
  });

  group('commitment read', () {
    test('the neutral point matches the JS', () {
      expect(commitmentNeutral, closeTo(0.48128522305836385, 1e-12));
    });

    test('matches the JS across the share range', () {
      const cases = <(double, double)>[
        (0.30, -1),
        (0.36, -1),
        (0.40, 0.05753532151018794),
        (0.43, 0.48860067192935897),
        (0.46, 0.9302437550028473),
        (0.50, 0.9302437550028473),
      ];
      for (final (share, expected) in cases) {
        expect(commitmentRead(share), closeTo(expected, 1e-12), reason: '$share');
      }
    });

    test('stays within -1 and +1', () {
      for (var share = 0.0; share <= 1.0; share += 0.01) {
        expect(commitmentRead(share), inInclusiveRange(-1, 1));
      }
    });

    test('a null share reads neutral', () {
      expect(commitmentRead(null), 0);
    });

    test('an open shape reads higher than a deep block', () {
      expect(commitmentRead(0.50), greaterThan(commitmentRead(0.30)));
    });

    test('attackingCommitment splits a side between the ends', () {
      expect(attackingCommitment(50, 50), 0.5);
      expect(attackingCommitment(75, 25), 0.75);
      expect(attackingCommitment(0, 0), 0.5);
      expect(attackingCommitment(null, null), 0.5);
    });
  });

  group('tacticMultipliers', () {
    test('returns the flat table values with no opponent in view', () {
      final m = tacticMultipliers(strategies['allOutAttack']);
      expect(m.atk, 1.18);
      expect(m.def, 0.82);
    });

    test('matches the JS for Counter Attack against a read opponent', () {
      final deep = tacticMultipliers(strategies['counterAttack'], 0.30);
      final open = tacticMultipliers(strategies['counterAttack'], 0.46);
      expect(deep.atk, closeTo(0.7544000000000001, 1e-12));
      expect(open.atk, closeTo(1.0740483658284716, 1e-12));
      expect(deep.def, 1.08);
      expect(open.def, 1.08);
    });

    test('the read is a wash across the shapes the AI fields', () {
      // The gain against the most attacking shape is paid for by an equal loss
      // against the most defensive one.
      final counter = strategies['counterAttack']!;
      final reads = aiFormationPositions.keys
          .map((id) => commitmentRead(_shareFor(id)))
          .toList();
      final mean = reads.reduce((a, b) => a + b) / reads.length;
      expect(mean, closeTo(0, 0.35));
      expect(counter.commitmentGain, greaterThan(0));
    });

    test('a tactic with no read ignores the opponent', () {
      final a = tacticMultipliers(strategies['highPress'], 0.30);
      final b = tacticMultipliers(strategies['highPress'], 0.50);
      expect(a.atk, b.atk);
    });

    test('a null strategy is neutral', () {
      final m = tacticMultipliers(null);
      expect(m.atk, 1);
      expect(m.def, 1);
    });

    test('applyTactic helpers agree with the multipliers', () {
      final s = strategies['parkTheBus'];
      expect(applyTacticAtk(100, s), closeTo(86, 1e-9));
      expect(applyTacticDef(100, s), closeTo(114, 1e-9));
    });
  });

  group('stratBiasPoints', () {
    test('derives the legacy point scale from the attack multiplier', () {
      expect(stratBiasPoints(strategies['balanced']), closeTo(0, 1e-9));
      expect(stratBiasPoints(strategies['allOutAttack']), closeTo(9, 1e-9));
      expect(stratBiasPoints(strategies['parkTheBus']), closeTo(-7, 1e-9));
    });
  });

  group('rollSwingFactor', () {
    test('a tactic with no swing is always neutral', () {
      seeded.setSeed(1);
      for (var i = 0; i < 50; i++) {
        expect(rollSwingFactor(strategies['balanced']), 1);
      }
    });

    test('is mean-preserving — it widens outcomes without inflating goals', () {
      seeded.setSeed(12345);
      final counter = strategies['counterAttack']!;
      var sum = 0.0;
      const n = 20000;
      for (var i = 0; i < n; i++) {
        sum += rollSwingFactor(counter);
      }
      expect(sum / n, closeTo(1.0, 0.02));
    });

    test('only ever returns the two poles', () {
      seeded.setSeed(7);
      final counter = strategies['counterAttack']!;
      final seen = {for (var i = 0; i < 200; i++) rollSwingFactor(counter)};
      expect(seen, {1 - counter.swing, 1 + counter.swing});
    });

    test('a null strategy is neutral', () {
      expect(rollSwingFactor(null), 1);
    });
  });
}

/// The average attack share of an AI shape, for the wash test.
double _shareFor(String formationId) {
  const posRatio = {'GK': 0.025, 'DEF': 0.20, 'MID': 0.50, 'FWD': 0.80};
  final positions = aiFormationPositions[formationId]!;
  final total = positions.map((p) => posRatio[p]!).reduce((a, b) => a + b);
  return total / positions.length;
}
