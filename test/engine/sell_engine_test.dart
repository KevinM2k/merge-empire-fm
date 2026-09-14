import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/sell_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';

Map<String, dynamic> _state(String division) => {
  'progression': <String, dynamic>{'currentDivision': division},
};

CardInstance _card({int seasonsPlayed = 0, int? age}) => CardInstance.from({
  'instanceId': 'c1',
  'definitionId': 'player_t5_mid',
  'seasonsPlayed': seasonsPlayed,
  'age': ?age,
})!;

void main() {
  /// The reference's rows, as `(definitionId, divisionId, seasons, price)`.
  List<(String, String, int, num)> referenceRows() {
    final data =
        jsonDecode(
              File('test/fixtures/sell_price_reference.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final expected = data['baseSellPrice'] as Map<String, dynamic>;
    expect(expected, isNotEmpty);
    return [
      for (final e in expected.entries)
        () {
          final p = e.key.split('|');
          return (p[0], p[1], int.parse(p[2]), e.value as num);
        }(),
    ];
  }

  CardInstance refCard(String defId, int seasons) => CardInstance.from({
    'instanceId': 'x',
    'definitionId': defId,
    'seasonsPlayed': seasons,
  })!;

  group('the reference prices', () {
    // **STILL PINNED, AND STILL WORTH PINNING.** The division multiplier is a
    // fractional power, which is exactly the sort of arithmetic that drifts
    // without anyone noticing — every sale in the game would be a percent or
    // two off. What these rows no longer are is a SPEC: the runtime they came
    // from is gone, and the veteran discount they encode (a percentage off the
    // rating, per season of service) has been replaced by the tier ladder. So
    // the rows that never touched that discount are compared to the digit, and
    // the ones that did are checked against the rule that replaced it.

    test('reproduce to the last digit for a card in its prime', () {
      var checked = 0;
      for (final (defId, divId, seasons, want) in referenceRows()) {
        final def = getPlayerDef(defId);
        expect(def, isNotNull, reason: defId);
        final card = refCard(defId, seasons);
        // Only the rows the old discount never touched. It bit from the
        // eleventh year of wear, so these are the fresh ones — and a fresh card
        // has not declined either, which is the other half of the same filter.
        if (seasons > 10) continue;
        expect(marketDefFor(def!, card.age).tier, def.tier, reason: defId);
        expect(
          baseSellPrice(def, card, _state(divId)),
          closeTo(want, 1e-9),
          reason: '$defId|$divId|$seasons',
        );
        checked++;
      }
      expect(checked, greaterThan(0), reason: 'the scan matched nothing');
    });

    test('AND EVERY ROW IS WORTH WHAT THE TIER IT WEARS IS WORTH', () {
      // The rule the reference's discount was replaced by, asserted directly
      // rather than as a frozen number: a World Legend who has fallen to Gold
      // Elite fetches Gold Elite money — not a percentage off World Legend
      // money, which left a thirty-nine-year-old drawn in silver fetching a
      // hundred and forty-five times what silver is worth.
      var declined = 0;
      for (final (defId, divId, seasons, _) in referenceRows()) {
        final def = getPlayerDef(defId)!;
        final card = refCard(defId, seasons);
        final worn = marketDefFor(def, card.age);
        expect(worn.position, def.position, reason: 'a keeper stays a keeper');
        expect(
          baseSellPrice(def, card, _state(divId)),
          closeTo(
            baseSellPrice(worn, refCard(worn.id, 0), _state(divId)),
            1e-9,
          ),
          reason: '$defId|$divId|$seasons wears ${worn.id}',
        );
        if (worn.tier != def.tier) declined++;
      }
      // And the fixture genuinely exercises the falling case, or this is a test
      // that only ever compares a card to itself.
      expect(declined, greaterThan(0), reason: 'no reference row declines');
    });
  });

  group('the shape of the price', () {
    test('a higher tier is worth more', () {
      final low = baseSellPrice(
        getPlayerDef('player_t1_gk'),
        null,
        _state('regional_league'),
      );
      final high = baseSellPrice(
        getPlayerDef('player_t7_fwd'),
        null,
        _state('regional_league'),
      );
      expect(high, greaterThan(low));
    });

    test('the same card is worth more the higher you climb', () {
      final sunday = baseSellPrice(
        getPlayerDef('player_t5_mid'),
        null,
        _state('sunday_league'),
      );
      final champions = baseSellPrice(
        getPlayerDef('player_t5_mid'),
        null,
        _state('champions_cup'),
      );
      expect(champions, greaterThan(sunday));
    });

    test('but nowhere near as much as match revenue does', () {
      // The power scaling is what stops late-game sell prices ballooning with
      // matchRevenueBase, which reaches 200× by Continental.
      final sunday = baseSellPrice(
        getPlayerDef('player_t5_mid'),
        null,
        _state('sunday_league'),
      );
      final champions = baseSellPrice(
        getPlayerDef('player_t5_mid'),
        null,
        _state('champions_cup'),
      );
      expect(champions / sunday, lessThan(20));
    });

    test('an ageing card is worth less', () {
      final fresh = baseSellPrice(
        getPlayerDef('player_t5_mid'),
        _card(),
        _state('regional_league'),
      );
      final old = baseSellPrice(
        getPlayerDef('player_t5_mid'),
        _card(seasonsPlayed: 13),
        _state('regional_league'),
      );
      expect(old, lessThan(fresh));
    });

    test('AND THERE IS NO FLOOR UNDER HIM ANY MORE', () {
      // There used to be one — a fifth of his value, whatever age he reached —
      // and it is gone with the percentage discount it belonged to. A card that
      // has fallen four tiers is worth what four tiers down is worth, which is
      // a great deal less than a fifth. That is the point of the rule.
      final def = getPlayerDef('player_t5_mid')!;
      final fresh = baseSellPrice(def, _card(), _state('regional_league'));
      final ancient = baseSellPrice(
        def,
        _card(age: retirementAge - 1),
        _state('regional_league'),
      );
      expect(ancient, lessThan(fresh * 0.2));
    });

    test('a card in his PRIME is worth full price however long he has served', () {
      // Service used to cost him from the eleventh season. It costs him nothing
      // now: a thirty-year-old is at his peak whether he arrived last year or
      // twelve years ago, and the price says so.
      final def = getPlayerDef('player_t5_mid');
      final young = baseSellPrice(def, _card(), _state('regional_league'));
      final served = baseSellPrice(
        def,
        _card(seasonsPlayed: 20, age: peakAgeEnd),
        _state('regional_league'),
      );
      expect(served, young);
    });
  });

  group('edge cases', () {
    test('a missing definition is worth nothing rather than throwing', () {
      expect(baseSellPrice(null, _card(), _state('regional_league')), 0);
    });

    test('a missing card is priced as brand new', () {
      final def = getPlayerDef('player_t5_mid');
      expect(
        baseSellPrice(def, null, _state('regional_league')),
        baseSellPrice(def, _card(), _state('regional_league')),
      );
    });

    test('a save with no division falls back rather than failing', () {
      final def = getPlayerDef('player_t5_mid');
      expect(baseSellPrice(def, null, null), greaterThan(0));
      expect(baseSellPrice(def, null, <String, dynamic>{}), greaterThan(0));
    });

    test('the market factor is the haircut, not a bonus', () {
      // Selling recovers something; it is not a second income stream.
      expect(sellMarketFactor, lessThan(1));
    });
  });

  group('where a multiplier sits on the bar', () {
    test('the worst rung is the FLOOR and the best is not the ceiling', () {
      // The top of the scale is the best rung PLUS a half, which is the JS's
      // own figure and is not arbitrary: a roll lands on a rung and adds a
      // little on top, so the jackpot's 2.8 is the floor of the best band. End
      // the bar at 2.8 and every jackpot pegs at the far end — the best outcome
      // in the game would look identical to the second best.
      expect(marketPosition(marketTiers.first.mult), 0);
      expect(marketPosition(marketTiers.last.mult), lessThan(1));
      expect(marketPosition(marketTiers.last.mult + 0.5), 1);
    });

    test('and it rises with the offer', () {
      var last = -1.0;
      for (final tier in marketTiers) {
        final at = marketPosition(tier.mult);
        expect(at, greaterThan(last));
        last = at;
      }
    });

    test('nothing can walk off either end', () {
      expect(marketPosition(-5), 0);
      expect(marketPosition(100), 1);
    });
  });
}
