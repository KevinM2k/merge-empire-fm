/// Building and upgrading club assets.
///
/// The arithmetic (`buildCost`, `tapCost`, `tierThreshold`) is already ported
/// and pinned in `data/club_assets.dart`; what is tested here is the FLOW, which
/// only ever existed inside the JS screen.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/engine/club_asset_engine.dart';
import 'package:merge_empire_fc/state/state_schema.dart';

const String _key = AssetCategory.training;

Map<String, dynamic> stateWith({int coins = 0, int players = 1}) {
  final s = createDefaultState();
  (s['resources'] as Map<String, dynamic>)['fanCoins'] = coins;
  final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
  for (var i = 0; i < players; i++) {
    cells[i] = <String, dynamic>{'definitionId': 'p', 'instanceId': 'c$i'};
  }
  return s;
}

int coinsOf(Map<String, dynamic> s) =>
    ((s['resources'] as Map<String, dynamic>)['fanCoins'] as num).toInt();

void main() {
  group('building', () {
    test('a fresh save owns nothing', () {
      final s = stateWith();
      for (final key in AssetCategory.all) {
        expect(isAssetOwned(s, key), isFalse, reason: key);
        expect(assetTier(s, key), 0, reason: key);
      }
    });

    test('costs the build price and opens at tier one', () {
      final s = stateWith(coins: 10000);
      final result = buildAsset(s, _key);
      expect(result.ok, isTrue);
      expect(result.cost, buildCost);
      expect(coinsOf(s), 10000 - buildCost);
      expect(isAssetOwned(s, _key), isTrue);
      expect(assetTier(s, _key), 1);
    });

    test('is refused with no players, and takes no coins', () {
      // A club with nobody in it has nothing to put in a facility.
      final s = stateWith(coins: 10000, players: 0);
      expect(buildBlocked(s, _key), 'needs_player');
      expect(buildAsset(s, _key).ok, isFalse);
      expect(coinsOf(s), 10000);
      expect(isAssetOwned(s, _key), isFalse);
    });

    test('is refused when short of coins, and takes none of them', () {
      final s = stateWith(coins: buildCost - 1);
      expect(buildBlocked(s, _key), 'insufficient_coins');
      expect(buildAsset(s, _key).ok, isFalse);
      expect(coinsOf(s), buildCost - 1);
    });

    test('cannot be built twice', () {
      final s = stateWith(coins: 10000);
      buildAsset(s, _key);
      final after = coinsOf(s);
      expect(buildBlocked(s, _key), 'already_owned');
      expect(buildAsset(s, _key).ok, isFalse);
      expect(coinsOf(s), after);
    });

    test('an unknown category builds nothing', () {
      final s = stateWith(coins: 10000);
      expect(buildBlocked(s, 'NOPE'), 'unknown_category');
      expect(buildAsset(s, 'NOPE').ok, isFalse);
      expect(coinsOf(s), 10000);
    });
  });

  group('investing', () {
    test('is refused before the asset is built', () {
      final s = stateWith(coins: 10000);
      expect(investBlocked(s, _key), 'not_owned');
      expect(investInAsset(s, _key).ok, isFalse);
    });

    test('one tap costs the table price and banks it', () {
      final s = stateWith(coins: 100000);
      buildAsset(s, _key);
      final cost = nextInvestCost(s, _key);
      expect(cost, tapCost(1, 0));

      final before = coinsOf(s);
      final result = investInAsset(s, _key);
      expect(result.ok, isTrue);
      expect(coinsOf(s), before - cost);
      expect(assetInvested(s, _key), cost);
      expect(assetTapCount(s, _key), 1);
    });

    test('the price walks up within a tier', () {
      final s = stateWith(coins: 1000000);
      buildAsset(s, _key);
      final first = nextInvestCost(s, _key);
      investInAsset(s, _key);
      expect(nextInvestCost(s, _key), greaterThan(first));
    });

    test('enough taps tier it up, and reset the counters', () {
      // Each tier is priced as its own ladder, so carrying a remainder forward
      // would make the next tier's first tap cheaper than the table says.
      final s = stateWith(coins: 100000000);
      buildAsset(s, _key);
      var tieredUp = false;
      for (var i = 0; i < 200 && !tieredUp; i++) {
        tieredUp = investInAsset(s, _key).tieredUp;
      }
      expect(tieredUp, isTrue);
      expect(assetTier(s, _key), 2);
      expect(assetInvested(s, _key), 0);
      expect(assetTapCount(s, _key), 0);
      expect(nextInvestCost(s, _key), tapCost(2, 0));
    });

    test('progress runs 0 to 1 within a tier', () {
      final s = stateWith(coins: 100000000);
      buildAsset(s, _key);
      expect(investProgress(s, _key), 0);
      investInAsset(s, _key);
      expect(investProgress(s, _key), greaterThan(0));
      expect(investProgress(s, _key), lessThanOrEqualTo(1));
    });

    test('is refused when short, and takes nothing', () {
      final s = stateWith(coins: 100000);
      buildAsset(s, _key);
      (s['resources'] as Map<String, dynamic>)['fanCoins'] = 1;
      expect(investBlocked(s, _key), 'insufficient_coins');
      expect(investInAsset(s, _key).ok, isFalse);
      expect(coinsOf(s), 1);
      expect(assetInvested(s, _key), 0);
    });

    test('stops at the ceiling, and asks for nothing there', () {
      final s = stateWith(coins: 100000000);
      buildAsset(s, _key);
      (s['clubAssets'] as Map<String, dynamic>)[_key] = <String, dynamic>{
        'owned': true,
        'tier': maxAssetTier,
        'invested': 0,
        'tapCount': 0,
      };
      expect(isAssetMaxed(s, _key), isTrue);
      expect(nextInvestCost(s, _key), 0);
      expect(investProgress(s, _key), 1);
      expect(investBlocked(s, _key), 'max_tier');
      final before = coinsOf(s);
      expect(investInAsset(s, _key).ok, isFalse);
      expect(coinsOf(s), before);
    });

    test('coins stay whole numbers', () {
      final s = stateWith(coins: 100000);
      buildAsset(s, _key);
      investInAsset(s, _key);
      expect((s['resources'] as Map)['fanCoins'], isA<int>());
    });
  });

  test('every shipped category can be built and invested in', () {
    for (final key in AssetCategory.all) {
      final s = stateWith(coins: 100000000);
      expect(buildAsset(s, key).ok, isTrue, reason: key);
      expect(investInAsset(s, key).ok, isTrue, reason: key);
    }
  });
}
