/// Signing a player — the action the game opens on.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/engine/scout_signing_engine.dart';
import 'package:merge_empire_fc/state/state_schema.dart';

Map<String, dynamic> stateWith({int coins = 100000, bool freeScout = false}) {
  final s = createDefaultState();
  (s['resources'] as Map<String, dynamic>)['fanCoins'] = coins;
  (s['shop'] as Map<String, dynamic>)['freeScoutReady'] = freeScout;
  return s;
}

int coinsOf(Map<String, dynamic> s) =>
    ((s['resources'] as Map<String, dynamic>)['fanCoins'] as num).toInt();

int filled(Map<String, dynamic> s) =>
    ((s['grid'] as Map<String, dynamic>)['cells'] as List)
        .where((c) => c != null)
        .length;

void main() {
  group('the price', () {
    test('is the division base with no academy', () {
      final s = stateWith();
      expect(scoutCost(s), Scout.baseCostByDiv['sunday_league'] ?? Scout.baseCost);
    });

    test('a free scout makes it nothing', () {
      expect(scoutCost(stateWith(freeScout: true)), 0);
    });

    test('but the underlying price is still askable', () {
      // The shop and the reveal both need the real figure even while a voucher
      // is covering it.
      final s = stateWith(freeScout: true);
      expect(scoutCost(s, ignoreVoucher: true), greaterThan(0));
    });

    test('the academy discounts it, and never below one coin', () {
      final s = stateWith();
      final full = scoutCost(s);
      (s['clubAssets'] as Map<String, dynamic>)[AssetCategory.academy] = {
        'owned': true,
        'tier': 8,
        'invested': 0,
        'tapCount': 0,
      };
      final discounted = scoutCost(s);
      expect(discounted, lessThan(full));
      expect(discounted, greaterThanOrEqualTo(1));
    });
  });

  group('signing', () {
    test('an empty grid can be filled from nothing', () {
      // The state the game opens in.
      final s = stateWith();
      expect(filled(s), 0);
      expect(signBlocked(s), isNull);

      final result = signPlayer(s);
      expect(result.ok, isTrue);
      expect(result.idx, 0);
      expect(filled(s), 1);
    });

    test('charges the price', () {
      final s = stateWith(coins: 100000);
      final cost = scoutCost(s);
      signPlayer(s);
      expect(coinsOf(s), 100000 - cost);
    });

    test('counts the scout', () {
      final s = stateWith();
      signPlayer(s);
      expect((s['stats'] as Map<String, dynamic>)['totalScouts'], 1);
    });

    test('fills the next empty slot each time', () {
      final s = stateWith();
      for (var i = 0; i < 5; i++) {
        expect(signPlayer(s).idx, i, reason: 'signing $i');
      }
      expect(filled(s), 5);
    });

    test('a free scout signs without charging, and is then spent', () {
      final s = stateWith(coins: 100000, freeScout: true);
      final result = signPlayer(s);
      expect(result.ok, isTrue);
      expect(result.wasFree, isTrue);
      expect(result.cost, 0);
      expect(coinsOf(s), 100000, reason: 'no coins taken');
      expect((s['shop'] as Map<String, dynamic>)['freeScoutReady'], isFalse);
      // And the next one costs again.
      expect(scoutCost(s), greaterThan(0));
    });

    test('a skint club is refused, and keeps its coins', () {
      final s = stateWith(coins: 0);
      expect(signBlocked(s), 'insufficient_coins');
      expect(signPlayer(s).ok, isFalse);
      expect(filled(s), 0);
      expect(coinsOf(s), 0);
    });

    test('a full grid is refused, and takes nothing', () {
      final s = stateWith();
      final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
      for (var i = 0; i < cells.length; i++) {
        cells[i] = <String, dynamic>{'definitionId': 'x', 'instanceId': 'c$i'};
      }
      final before = coinsOf(s);
      expect(signBlocked(s), 'grid_full');
      expect(signPlayer(s).ok, isFalse);
      expect(coinsOf(s), before);
    });

    test('coins stay whole numbers', () {
      final s = stateWith();
      signPlayer(s);
      expect((s['resources'] as Map)['fanCoins'], isA<int>());
    });
  });
}
