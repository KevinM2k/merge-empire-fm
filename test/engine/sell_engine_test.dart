import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/sell_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';

Map<String, dynamic> _state(String division) => {
  'progression': <String, dynamic>{'currentDivision': division},
};

CardInstance _card({int seasonsPlayed = 0}) => CardInstance.from({
  'instanceId': 'c1',
  'definitionId': 'player_t5_mid',
  'seasonsPlayed': seasonsPlayed,
})!;

void main() {
  group('parity with the JS', () {
    test('reproduces every reference price to the last digit', () {
      // The division multiplier is a fractional power, which is exactly the
      // sort of arithmetic that drifts between two languages without anyone
      // noticing — every sale in the game would be a percent or two off.
      final data =
          jsonDecode(
                File('test/fixtures/sell_price_reference.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final expected = data['baseSellPrice'] as Map<String, dynamic>;
      expect(expected, isNotEmpty);

      for (final entry in expected.entries) {
        final parts = entry.key.split('|');
        final def = getPlayerDef(parts[0]);
        expect(def, isNotNull, reason: parts[0]);
        final got = baseSellPrice(
          def,
          CardInstance.from({
            'instanceId': 'x',
            'definitionId': parts[0],
            'seasonsPlayed': int.parse(parts[2]),
          }),
          _state(parts[1]),
        );
        expect(got, closeTo(entry.value as num, 1e-9), reason: entry.key);
      }
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

    test('and a veteran never falls below a fifth of their value', () {
      final fresh = baseSellPrice(
        getPlayerDef('player_t5_mid'),
        _card(),
        _state('regional_league'),
      );
      final ancient = baseSellPrice(
        getPlayerDef('player_t5_mid'),
        _card(seasonsPlayed: 40),
        _state('regional_league'),
      );
      expect(ancient, greaterThanOrEqualTo(fresh * 0.2 - 1e-9));
    });

    test('the first ten seasons cost nothing — decline starts after that', () {
      final def = getPlayerDef('player_t5_mid');
      final young = baseSellPrice(def, _card(), _state('regional_league'));
      final ten = baseSellPrice(
        def,
        _card(seasonsPlayed: 10),
        _state('regional_league'),
      );
      expect(ten, young);
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
}
