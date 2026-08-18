/// The Shop's three coin consumables, pinned against the live JS.
///
/// Their pricing never left `ui/screens/ShopScreen.js`, so the fixture is the
/// only check on the arithmetic — hence every division and the whole sponge ramp
/// including its cap.
///
/// Regenerate with tool/dump_shop_consumables_reference.mjs.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/shop_consumables_engine.dart';
import 'package:merge_empire_fc/state/state_schema.dart';

Map<String, dynamic> stateIn(
  String divisionId, {
  int coins = 0,
  int uses = 0,
  int season = 1,
  int injured = 0,
}) {
  final s = createDefaultState();
  (s['progression'] as Map<String, dynamic>)['currentDivision'] = divisionId;
  (s['progression'] as Map<String, dynamic>)['seasonCount'] = season;
  (s['resources'] as Map<String, dynamic>)['fanCoins'] = coins;
  (s['shop'] as Map<String, dynamic>)['spongeUses'] = uses;
  final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
  var placed = 0;
  for (var i = 0; i < cells.length && placed < injured; i++) {
    cells[i] = <String, dynamic>{
      'instanceId': 'inj$i',
      'definitionId': 'p1',
      'injured': true,
      'injuredAt': 1,
      'injuryDurationMs': 1000,
    };
    placed++;
  }
  return s;
}

void main() {
  final reference =
      jsonDecode(
            File(
              'test/fixtures/shop_consumables_reference.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  group('prices match the JS', () {
    final scaled = reference['scaled'] as Map<String, dynamic>;
    for (final entry in scaled.entries) {
      final expected = entry.value as Map<String, dynamic>;
      test('${entry.key} scales every base', () {
        final s = stateIn(entry.key);
        expect(scaledCoinCost(s, 1500), expected['sponge_base']);
        expect(kitSponsorCost(s), expected['kit_sponsor']);
        expect(tvDealCost(s), expected['match_rev']);
      });
    }

    final sponge = reference['sponge'] as Map<String, dynamic>;
    for (final entry in sponge.entries) {
      test('${entry.key} ramps the sponge and caps it', () {
        for (final row in (entry.value as List).cast<Map<String, dynamic>>()) {
          final s = stateIn(entry.key, uses: row['uses'] as int);
          expect(spongeCost(s), row['cost'], reason: 'uses ${row['uses']}');
        }
      });
    }

    test('the cap actually binds', () {
      // The old ramp was 2^uses and unbounded: the third heal cost sixty
      // matches' worth at every division, which forced an IAP rather than
      // offering one.
      final s = stateIn('sunday_league');
      expect(spongeCost(stateIn('sunday_league', uses: 4)), spongeCost(stateIn('sunday_league', uses: 99)));
      expect(spongeCost(stateIn('sunday_league', uses: 99)), scaledCoinCost(s, 1500) * 3);
    });
  });

  group('the sponge', () {
    test('heals every injured player, not the worst one', () {
      final s = stateIn('sunday_league', coins: 999999, injured: 3);
      expect(injuredCount(s), 3);
      final result = buyConsumable(s, 'magic_sponge');
      expect(result.ok, isTrue);
      expect(result.healed, 3);
      expect(injuredCount(s), 0);
    });

    test('debits the coins and counts the use', () {
      final s = stateIn('sunday_league', coins: 999999, injured: 1);
      final cost = spongeCost(s);
      buyConsumable(s, 'magic_sponge');
      expect((s['resources'] as Map)['fanCoins'], 999999 - cost);
      expect(spongeUses(s), 1);
      // And the next one costs more.
      expect(spongeCost(s), greaterThan(cost));
    });

    test('is blocked with nobody injured, and takes no coins', () {
      final s = stateIn('sunday_league', coins: 999999);
      expect(consumableBlocked(s, 'magic_sponge'), 'no_injured');
      expect(buyConsumable(s, 'magic_sponge').ok, isFalse);
      expect((s['resources'] as Map)['fanCoins'], 999999);
    });

    test('is blocked when the coins are short, and takes none of them', () {
      final s = stateIn('sunday_league', coins: 10, injured: 1);
      expect(consumableBlocked(s, 'magic_sponge'), 'insufficient_coins');
      expect(buyConsumable(s, 'magic_sponge').ok, isFalse);
      expect((s['resources'] as Map)['fanCoins'], 10);
      expect(injuredCount(s), 1, reason: 'and heals nobody');
    });
  });

  group('the season boosts', () {
    test('kit sponsor arms for this season only', () {
      final s = stateIn('sunday_league', coins: 999999, season: 4);
      expect(isKitSponsorActive(s), isFalse);
      expect(buyConsumable(s, 'kit_sponsor').ok, isTrue);
      expect(isKitSponsorActive(s), isTrue);
      expect((s['boosts'] as Map)['kitSponsorSeason'], 4);

      // Next season it is not active any more, and can be bought again.
      (s['progression'] as Map<String, dynamic>)['seasonCount'] = 5;
      expect(isKitSponsorActive(s), isFalse);
      expect(consumableBlocked(s, 'kit_sponsor'), isNull);
    });

    test('the TV deal arms for this season only', () {
      final s = stateIn('sunday_league', coins: 999999, season: 2);
      expect(buyConsumable(s, 'match_rev').ok, isTrue);
      expect(isTvDealActive(s), isTrue);
      expect((s['boosts'] as Map)['matchRevBoostSeason'], 2);
    });

    test('buying one twice in a season is blocked, and costs nothing', () {
      final s = stateIn('sunday_league', coins: 999999, season: 1);
      buyConsumable(s, 'kit_sponsor');
      final after = (s['resources'] as Map)['fanCoins'];
      expect(consumableBlocked(s, 'kit_sponsor'), 'already_active');
      expect(buyConsumable(s, 'kit_sponsor').ok, isFalse);
      expect((s['resources'] as Map)['fanCoins'], after);
    });
  });

  test('an unknown id buys nothing', () {
    final s = stateIn('sunday_league', coins: 999999);
    expect(consumableBlocked(s, 'nope'), 'unknown_item');
    expect(buyConsumable(s, 'nope').ok, isFalse);
    expect((s['resources'] as Map)['fanCoins'], 999999);
  });

  test('coins stay whole numbers', () {
    // roundCoins, not a double: coins are the most-written field in the save and
    // 75.0 is not 75 as JSON.
    final s = stateIn('regional_league', coins: 999999, injured: 1);
    buyConsumable(s, 'magic_sponge');
    expect((s['resources'] as Map)['fanCoins'], isA<int>());
  });
}
