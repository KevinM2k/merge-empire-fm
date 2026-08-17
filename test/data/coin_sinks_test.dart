import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/coin_sinks.dart';
import 'package:merge_empire_fc/data/divisions.dart';

/// Cost tables generated from node against
/// `../merge-empire-fc/src/data/coinSinks.js`.
void main() {
  group('the sink list', () {
    test('holds four sinks in order', () {
      expect(coinSinks.map((s) => s.id), [
        'loyalty_bonus',
        'kit_redesign',
        'youth_academy',
        'lucky_pack',
      ]);
    });

    test('every sink has a name and icon', () {
      for (final s in coinSinks) {
        expect(s.name, isNotEmpty, reason: s.id);
        expect(s.icon, isNotEmpty, reason: s.id);
      }
    });

    test('ids are unique', () {
      expect(coinSinks.map((s) => s.id).toSet().length, coinSinks.length);
    });

    test('unlock divisions are real ladder indices', () {
      for (final s in coinSinks) {
        expect(s.unlockDiv, inInclusiveRange(0, divisions.length - 1), reason: s.id);
      }
    });

    test('exactly one sink prices per tier rather than by division', () {
      final perTier = coinSinks.where((s) => s.costPerTier != null);
      expect(perTier.map((s) => s.id), ['loyalty_bonus']);
    });

    test('every other sink carries a base cost', () {
      for (final s in coinSinks.where((s) => s.costPerTier == null)) {
        expect(s.baseCost, isNotNull, reason: s.id);
        expect(s.baseCost, greaterThan(0), reason: s.id);
      }
    });
  });

  group('getCoinSink', () {
    test('finds a known sink', () {
      expect(getCoinSink('lucky_pack')?.name, 'Lucky Pack');
    });

    test('returns null for an unknown or null id', () {
      expect(getCoinSink('nope'), isNull);
      expect(getCoinSink(null), isNull);
    });
  });

  group('divisionCostMultiplier', () {
    test('is matchRevenueBase over 100', () {
      expect(divisionCostMultiplier(getDivision('sunday_league')), 1);
      expect(divisionCostMultiplier(getDivision('champions_cup')), 1200);
    });

    test('a missing division scales by one', () {
      expect(divisionCostMultiplier(null), 1);
    });

    test('rises up the ladder', () {
      for (var i = 1; i < divisions.length; i++) {
        expect(
          divisionCostMultiplier(divisions[i]),
          greaterThan(divisionCostMultiplier(divisions[i - 1])),
        );
      }
    });
  });

  group('sinkCost', () {
    test('kit_redesign scales across the ladder', () {
      expect(
        divisions.map((d) => sinkCost(getCoinSink('kit_redesign'), division: d)),
        [2000, 5000, 12000, 30000, 80000, 400000, 2400000],
      );
    });

    test('youth_academy scales across the ladder', () {
      expect(
        divisions.map((d) => sinkCost(getCoinSink('youth_academy'), division: d)),
        [8000, 20000, 48000, 120000, 320000, 1600000, 9600000],
      );
    });

    test('lucky_pack scales across the ladder', () {
      expect(
        divisions.map((d) => sinkCost(getCoinSink('lucky_pack'), division: d)),
        [3000, 7500, 18000, 45000, 120000, 600000, 3600000],
      );
    });

    test('loyalty_bonus ignores the division entirely', () {
      expect(
        divisions.map((d) => sinkCost(getCoinSink('loyalty_bonus'), division: d)),
        List.filled(divisions.length, 5000),
      );
    });

    test('loyalty_bonus scales with the target card tier', () {
      expect(
        [
          for (var t = 1; t <= 8; t++)
            sinkCost(
              getCoinSink('loyalty_bonus'),
              division: divisions.first,
              targetCardTier: t,
            ),
        ],
        [5000, 10000, 15000, 20000, 25000, 30000, 35000, 40000],
      );
    });

    test('loyalty_bonus floors the tier at one', () {
      final atZero = sinkCost(getCoinSink('loyalty_bonus'), targetCardTier: 0);
      expect(atZero, 5000);
      expect(sinkCost(getCoinSink('loyalty_bonus'), targetCardTier: -5), 5000);
    });

    test('a missing division prices at the base', () {
      expect(
        coinSinks.map((s) => sinkCost(s)),
        [5000, 2000, 8000, 3000],
      );
    });

    test('a null sink costs nothing', () {
      expect(sinkCost(null), 0);
    });

    test('every price is a rounded coin figure', () {
      for (final s in coinSinks) {
        for (final d in divisions) {
          final cost = sinkCost(s, division: d);
          expect(cost % 5, 0, reason: '${s.id} at ${d.id} is not a nice number');
        }
      }
    });

    test('costs never fall as the ladder rises', () {
      for (final s in coinSinks) {
        for (var i = 1; i < divisions.length; i++) {
          expect(
            sinkCost(s, division: divisions[i]),
            greaterThanOrEqualTo(sinkCost(s, division: divisions[i - 1])),
            reason: '${s.id} at ${divisions[i].id}',
          );
        }
      }
    });
  });
}
