/// The rules the coach has to obey, as distinct from the numbers it produces.
///
/// The parity fixture pins the arithmetic against the JS; this pins the
/// PROPERTIES, so a fixture regenerated against a broken source still fails
/// here. Every one of these is a bug the JS shipped at some point.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/tactic_coach.dart';

/// A level, mid-table matchup — the reference case for "does a tactic pay".
const _oppAtk = 60;
const _oppDef = 61;

void main() {
  group('tacticExpectedPoints', () {
    test('no tactic is the right answer everywhere', () {
      // A tactic that is never correct is a decoy on the dial; one that is
      // always correct makes the other four decoys. Either way the choice stops
      // being a choice, which is what the zero-sum rule exists to prevent.
      final winners = {
        for (final m in [
          (41, 40, 72, 70),
          (60, 60, 60, 60),
          (78, 76, 54, 55),
          (85, 35, 62, 61),
        ])
          [
            for (final s in strategies.values)
              (
                id: s.id,
                pts: tacticExpectedPoints(m.$1, m.$2, m.$3, m.$4, s),
              ),
          ].reduce((a, b) => b.pts > a.pts ? b : a).id,
      };
      expect(winners.length, greaterThan(1));
    });

    test('attacking cannot lift an underdog to parity', () {
      // The rate used to grow with a CONVEX amplifier stacked on the already
      // convex rating term, so a weak side that shifted weight forward more than
      // doubled its goals for a modest defensive cost — "throw everyone forward"
      // as a dominant underdog exploit, the reverse of real football.
      final underdogBest = [
        for (final s in strategies.values)
          tacticExpectedPoints(41, 40, 72, 70, s),
      ].reduce((a, b) => a > b ? a : b);
      final levelWorst = [
        for (final s in strategies.values)
          tacticExpectedPoints(60, 60, 60, 60, s),
      ].reduce((a, b) => a < b ? a : b);
      expect(underdogBest, lessThan(levelWorst * 0.6));
    });

    test('being ahead is worth more than being level, at any tactic', () {
      for (final s in strategies.values) {
        final ahead = tacticExpectedPoints(
          70, 69, _oppAtk, _oppDef, s,
          fraction: 0.2, margin: 1,
        );
        final level = tacticExpectedPoints(
          70, 69, _oppAtk, _oppDef, s,
          fraction: 0.2, margin: 0,
        );
        expect(ahead, greaterThan(level), reason: s.id);
      }
    });

    test('with no match left, the margin alone decides the points', () {
      for (final s in strategies.values) {
        expect(
          tacticExpectedPoints(70, 69, _oppAtk, _oppDef, s,
              fraction: 0, margin: 1),
          closeTo(3, 1e-9),
          reason: s.id,
        );
        expect(
          tacticExpectedPoints(70, 69, _oppAtk, _oppDef, s,
              fraction: 0, margin: 0),
          closeTo(1, 1e-9),
          reason: s.id,
        );
        expect(
          tacticExpectedPoints(70, 69, _oppAtk, _oppDef, s,
              fraction: 0, margin: -1),
          closeTo(0, 1e-9),
          reason: s.id,
        );
      }
    });

    test('Counter Attack reads the opponent, and the read is a wash', () {
      // Its gain against the most attacking shape is paid for by an equal loss
      // against the most defensive one, so across the shapes the AI fields it
      // averages to nothing. That is what keeps the read from being a buff.
      final counter = strategies['counterAttack']!;
      final open = tacticExpectedPoints(
        70, 69, _oppAtk, _oppDef, counter,
        oppAttackRatio: 0.457,
      );
      final deep = tacticExpectedPoints(
        70, 69, _oppAtk, _oppDef, counter,
        oppAttackRatio: 0.348,
      );
      expect(open, greaterThan(deep));
    });
  });

  group('suggestTactic', () {
    test('chases when two down late', () {
      // Not a special case bolted on: a draw is worth 1 and a defeat 0, so with
      // almost nothing left to lose the objective asks for the game stretched.
      final picked = suggestTactic(
        73, 72, _oppAtk, _oppDef,
        fraction: 0.15, margin: -2,
      );
      expect(strategies[picked.id]!.atkMult, greaterThan(1));
    });

    test('shuts the game down when a lead is worth protecting', () {
      final picked = suggestTactic(
        73, 72, _oppAtk, _oppDef,
        fraction: 0.15, margin: 2,
      );
      expect(strategies[picked.id]!.defMult, greaterThan(1));
    });

    test('will not park the bus with most of the match still to play', () {
      // Expected points alone would kill the game off from the first minute,
      // which is the "park the bus to sneak promotion" degenerate.
      final picked = suggestTactic(
        73, 72, _oppAtk, _oppDef,
        fraction: 0.9, margin: 1,
      );
      expect(strategies[picked.id]!.defMult, lessThanOrEqualTo(1));
      expect(picked.heldOffSittingBack, isTrue);
    });

    test('lets a side under the cosh defend, lead or not', () {
      // A team being outgunned defends because it has to. The early-lead guard
      // is lifted when their attack is above our defence.
      final picked = suggestTactic(
        45, 44, 80, 78,
        fraction: 0.9, margin: 1,
      );
      expect(picked.heldOffSittingBack, isFalse);
    });

    test('a bench that cannot absorb a knock vetoes the risky tactics', () {
      final picked = suggestTactic(45, 44, _oppAtk, _oppDef, benchCover: 0);
      expect(strategies[picked.id]!.injMod, lessThanOrEqualTo(1));
    });

    test('deep cover unlocks what a bare eleven cannot afford', () {
      // The veto is depth, not odds — the same matchup with cover behind it may
      // legitimately reach for High Press.
      final ids = {
        for (final cover in [0.0, 1.0, 2.0, 9.0])
          cover: suggestTactic(
            41, 40, 72, 70,
            benchCover: cover,
            injuryRisk: 0.2,
            injuryCost: 0.3,
          ).id,
      };
      for (final entry in ids.entries) {
        if ((tacticMinBenchCover[entry.value] ?? 0) > 0) {
          expect(entry.key, greaterThanOrEqualTo(tacticMinBenchCover[entry.value]!));
        }
      }
    });

    test('ranks every tactic, best first', () {
      final picked = suggestTactic(60, 60, _oppAtk, _oppDef);
      expect(picked.ranked, hasLength(strategies.length));
      for (var i = 1; i < picked.ranked.length; i++) {
        expect(
          picked.ranked[i - 1].expectedPoints,
          greaterThanOrEqualTo(picked.ranked[i].expectedPoints),
        );
      }
    });

    test('an injury cost the squad cannot bear is what thinSquad means', () {
      // Free of injury economics the odds want something risky; price the knock
      // high enough and the pick moves, which is the flag's whole meaning.
      final free = suggestTactic(41, 40, 72, 70);
      final priced = suggestTactic(
        41, 40, 72, 70,
        injuryRisk: 0.5,
        injuryCost: 4,
      );
      if (free.id != priced.id) {
        expect(priced.thinSquad, isTrue);
      }
      expect(free.thinSquad, isFalse);
    });
  });

  group('baselineInjuryRisk', () {
    test('is zero with nobody fit to pick', () {
      expect(
        baselineInjuryRisk({
          'grid': {'cells': <Object?>[]},
        }),
        0,
      );
    });

    test('rises with a squad that has been at the club longer', () {
      double riskAt(int seasons) => baselineInjuryRisk({
        'grid': {
          'cells': [
            for (var i = 0; i < 11; i++)
              {
                'instanceId': 'c$i',
                'definitionId': 'player_t3_mid',
                'seasonsPlayed': seasons,
              },
          ],
        },
        'progression': {'currentDivision': 'sunday_league'},
      });
      expect(riskAt(10), greaterThan(riskAt(0)));
      expect(riskAt(14), greaterThan(riskAt(10)));
    });
  });

  group('injuryCostPoints', () {
    test('is zero without a full eleven to lose someone from', () {
      expect(injuryCostPoints(null, _oppAtk, _oppDef), 0);
      expect(
        injuryCostPoints({
          'squad': {'lineup': <Object?>[]},
        }, _oppAtk, _oppDef),
        0,
      );
    });
  });
}
