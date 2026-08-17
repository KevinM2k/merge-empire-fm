/// The rules the shop has to obey, as distinct from the numbers it produces.
///
/// The parity fixture pins the catalogue and the payouts against the JS; this pins
/// the pricing DESIGN, which is the part that goes quietly wrong. Every rule here
/// is one the JS argues for at length, and most of them are one edit away from
/// being broken by a change that looks harmless.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/gem_engine.dart';
import 'package:merge_empire_fc/engine/iap_engine.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/time.dart';

const int _now = 1700000000000;

Map<String, dynamic> _state({
  String division = 'sunday_league',
  bool hardMode = false,
  int coins = 0,
}) => {
  'resources': {'fanCoins': coins, 'gems': 0, 'trophies': 0},
  'energy': {'current': 0},
  'shop': <String, dynamic>{},
  'boosts': <String, dynamic>{},
  'prestige': {'level': 0},
  'settings': {'hardMode': hardMode},
  'progression': {'currentDivision': division},
  'grid': {'cells': <Object?>[]},
};

num _coins(Map<String, dynamic> s) =>
    (s['resources'] as Map)['fanCoins'] as num;

void main() {
  setUp(() => setClock(() => _now));
  tearDown(() {
    resetClock();
    clearBus();
  });

  group('the gem ladder prices the whole catalogue', () {
    test('every rung is a real step up', () {
      // A rung nobody rationally picks is worse than no rung: it makes the shelf
      // look padded. There used to be a £1.49 / 10-gem rung that was dead on
      // arrival, because 50p more bought twice the gems.
      final bundles = [
        for (final p in products)
          if (p.category == 'gems') p,
      ];
      expect(bundles.length, greaterThan(1));
      for (var i = 1; i < bundles.length; i++) {
        expect(
          bundles[i].priceValue,
          greaterThan(bundles[i - 1].priceValue),
          reason: 'the ladder must be in price order',
        );
        expect(
          bundles[i].gems! / bundles[i].priceValue,
          greaterThan(bundles[i - 1].gems! / bundles[i - 1].priceValue),
          reason: '${bundles[i].id} is not better value than the rung below',
        );
      }
    });

    test('and cannot be discounted so hard it undercuts the Style Vault', () {
      // Every gem price in the game is quoted against ONE rate, and the rate a
      // player actually pays is whichever rung they buy. Discount the ladder
      // harder and the whole catalogue quietly goes on sale — which is what drags
      // the Vault's ceiling down.
      final bundles = [
        for (final p in products)
          if (p.category == 'gems') p,
      ];
      final setGems = lookPacks.fold<int>(0, (sum, _) => sum + packGemCost());
      final cheapestRoute = bundles
          .map((b) => (setGems / b.gems!).ceil() * b.priceValue)
          .reduce((a, b) => a < b ? a : b);
      final vault = getProduct('style_vault')!;

      expect(
        vault.priceValue,
        lessThan(cheapestRoute),
        reason: 'the Style Vault must undercut buying the packs with gems',
      );
      // And it must not read as costing the same as thirty days of doubled income.
      expect(vault.priceValue, lessThan(getProduct('vip_pass')!.priceValue));
      // But it should sit above the Starter Pack — a cosmetic bundle is not an
      // entry-level purchase.
      expect(vault.priceValue, greaterThan(getProduct('starter_pack')!.priceValue));
    });
  });

  group('coin bundles', () {
    test('get better value as they get bigger', () {
      final bundles = [
        for (final p in products)
          if (p.category == 'coins') p,
      ];
      for (var i = 1; i < bundles.length; i++) {
        expect(
          getCoinBundleValuePct(bundles[i]),
          greaterThan(getCoinBundleValuePct(bundles[i - 1])),
          reason: bundles[i].id,
        );
      }
      // The cheapest is the baseline, so it is worth nothing extra by definition.
      expect(getCoinBundleValuePct(bundles.first), 0);
    });

    test('scale with division so they stay meaningful late-game', () {
      final sunday = _state();
      final champions = _state(division: 'champions_cup');
      purchaseProduct(sunday, 'coins_small');
      purchaseProduct(champions, 'coins_small');
      expect(_coins(champions), _coins(sunday) * 1000);
    });

    test('an unknown division pays the base rate rather than nothing', () {
      final state = _state(division: 'not_a_division');
      purchaseProduct(state, 'coins_small');
      expect(_coins(state), getProduct('coins_small')!.coins);
    });
  });

  group('what the shop says is what it pays', () {
    test('for every product, at every division', () {
      // These were computed separately once and drifted by two to three times.
      for (final division in divisionCoinMult.keys) {
        for (final product in products) {
          final shown = getProductGrantCoins(
            _state(division: division),
            product,
          );
          final state = _state(division: division);
          purchaseProduct(state, product.id);
          expect(
            _coins(state),
            shown,
            reason: '${product.id} @ $division',
          );
        }
      }
    });
  });

  group('one-time products', () {
    test('cannot be bought twice, and grant nothing on the second try', () {
      final state = _state();
      expect(purchaseProduct(state, 'starter_pack').ok, isTrue);
      final coinsAfter = _coins(state);
      final spentAfter = (state['shop'] as Map)['totalSpent'];

      final second = purchaseProduct(state, 'starter_pack');
      expect(second.ok, isFalse);
      expect(second.reason, 'already_purchased');
      expect(_coins(state), coinsAfter);
      expect((state['shop'] as Map)['totalSpent'], spentAfter);
    });

    test('are recorded alongside each other, not overwritten', () {
      final state = _state();
      purchaseProduct(state, 'starter_pack');
      purchaseProduct(state, 'energy_director');
      purchaseProduct(state, 'style_vault');
      expect((state['shop'] as Map)['purchasedIds'], [
        'starter_pack',
        'energy_director',
        'style_vault',
      ]);
    });

    test('are non-consumables in the store, which is what refuses the repeat', () {
      for (final p in products) {
        if (p.oneTime) expect(p.type, 'non_consumable', reason: p.id);
      }
    });
  });

  group('spend tracking', () {
    test('accumulates the real price across every purchase', () {
      final state = _state();
      purchaseProduct(state, 'coins_small'); // 0.99
      purchaseProduct(state, 'coins_small'); // 0.99
      purchaseProduct(state, 'gems_35'); // 3.99
      expect(
        (state['shop'] as Map)['totalSpent'] as num,
        closeTo(0.99 + 0.99 + 3.99, 1e-9),
      );
    });

    test('survives a save with no shop branch at all', () {
      // The JS throws here: it writes `state.shop.totalSpent` having only created
      // the branch inside two of the grant branches. Unreachable in the app,
      // because the schema always writes it — but a real latent crash, and fixed
      // in the port. See docs/REMAINING.md.
      final state = <String, dynamic>{
        'resources': {'fanCoins': 0},
        'progression': {'currentDivision': 'sunday_league'},
      };
      expect(() => purchaseProduct(state, 'coins_small'), returnsNormally);
      expect(_coins(state), 5000);
      expect((state['shop'] as Map)['totalSpent'], 0.99);
    });
  });

  group('energy', () {
    test('stacks pips on top in Casual, above the regen cap', () {
      // The pack deliberately exceeds the cap; regen itself still caps.
      final state = _state();
      purchaseProduct(state, 'energy_director');
      expect((state['energy'] as Map)['current'], 50);
    });

    test('builds the energy branch on a save that has none', () {
      final state = _state()..remove('energy');
      expect(() => purchaseProduct(state, 'starter_pack'), returnsNormally);
      expect((state['energy'] as Map)['current'], 10);
    });

    test('banks a full extra bar per player in Pro mode, not team pips', () {
      // There is no team pip pool in Pro — energy is per-player fitness, so the
      // buy overfills each card instead.
      final state = _state(hardMode: true);
      (state['grid'] as Map)['cells'] = [
        {
          'instanceId': 'c0',
          'definitionId': 'player_t5_mid',
          'seasonsPlayed': 0,
        },
      ];
      purchaseProduct(state, 'energy_director');
      expect((state['energy'] as Map)['current'], 0);
      final card = ((state['grid'] as Map)['cells'] as List).first as Map;
      expect(card['energy'], greaterThan(0));
    });
  });

  group('VIP', () {
    test('is worth the same number of league wins at every division', () {
      // Which is the whole design: a flat coin figure would be worthless by
      // Continental.
      final perWin = getProduct('vip_pass')!.vipCoinsPerWin!;
      for (final division in divisionCoinMult.keys) {
        final state = _state(division: division);
        final coins = getVipCoins(state);
        expect(coins % perWin, 0, reason: division);
      }
      expect(
        getVipCoins(_state(division: 'champions_cup')),
        greaterThan(getVipCoins(_state())),
      );
    });

    test('cannot be stacked while it is still live', () {
      final state = _state();
      expect(purchaseProduct(state, 'vip_pass').ok, isTrue);
      expect(purchaseProduct(state, 'vip_pass').reason, 'vip_already_active');
    });

    test('can be renewed once it has lapsed', () {
      final state = _state();
      purchaseProduct(state, 'vip_pass');
      (state['shop'] as Map)['vipExpiresAt'] = _now - 1;
      expect(isVipActive(state), isFalse);
      expect(purchaseProduct(state, 'vip_pass').ok, isTrue);
      expect(isVipActive(state), isTrue);
    });

    test('sets the income boost flag, not just the shop stamp', () {
      // The doubled idle income comes off the boost, so a pass that only wrote the
      // shop field would sell nothing.
      final state = _state();
      purchaseProduct(state, 'vip_pass');
      expect((state['boosts'] as Map)['vipActive'], isTrue);
      expect(
        (state['boosts'] as Map)['vipExpiresAt'],
        (state['shop'] as Map)['vipExpiresAt'],
      );
    });

    test('reads as inactive with nothing bought', () {
      expect(isVipActive(_state()), isFalse);
      expect(vipTimeRemaining(_state()), 0);
      expect(isVipActive(null), isFalse);
      expect(vipTimeRemaining(null), 0);
    });
  });

  group('gems', () {
    test('are the only thing the gem bundles sell', () {
      for (final p in products) {
        if (p.category == 'gems') {
          expect(p.gems, isNotNull, reason: p.id);
          expect(p.coins, isNull, reason: p.id);
        } else {
          expect(p.gems, isNull, reason: p.id);
        }
      }
    });

    test('are all consumable — gems are spent, so they can be bought again', () {
      for (final p in products) {
        if (p.category == 'gems') expect(p.type, 'consumable', reason: p.id);
      }
      final state = _state();
      purchaseProduct(state, 'gems_5');
      purchaseProduct(state, 'gems_5');
      expect((state['resources'] as Map)['gems'], 10);
    });
  });

  group('the shelf', () {
    test('refuses a product nobody sells, without touching the save', () {
      final state = _state();
      final res = purchaseProduct(state, 'nope');
      expect(res.ok, isFalse);
      expect(res.reason, 'unknown_product');
      expect(_coins(state), 0);
      expect(state['shop'], isEmpty);
    });

    test('prices every product, and gives every one a real name', () {
      for (final p in products) {
        expect(p.priceValue, greaterThan(0), reason: p.id);
        expect(p.price, startsWith('£'), reason: p.id);
        expect(p.name, isNotEmpty, reason: p.id);
        expect(p.icon, isNotEmpty, reason: p.id);
        expect(const {'consumable', 'non_consumable'}, contains(p.type),
            reason: p.id);
      }
    });
  });
}
