/// Differential test: the Dart IAP engine against the JS it was ported from.
///
/// Two things matter here and neither is subtle arithmetic.
///
/// THE CATALOGUE IS A CONTRACT. Every SKU is a live product id in App Store
/// Connect and Play Console, so a typo is a product nobody can buy — the whole
/// catalogue is compared field by field rather than spot-checked.
///
/// WHAT A PRODUCT PAYS OUT must equal what the shop SAYS it pays out. The two were
/// computed separately once and drifted by two to three times, which is the reason
/// `getProductGrantCoins` exists, so both are pinned at every division.
///
/// See `tool/dump_iap_reference.mjs`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/iap_engine.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

final Map<String, dynamic> ref = jsonDecode(
  File('test/fixtures/iap_reference.json').readAsStringSync(),
) as Map<String, dynamic>;

final Map<String, dynamic> refSave = jsonDecode(
  File('test/fixtures/quest_engine_reference.json').readAsStringSync(),
) as Map<String, dynamic>;

final int fixedNow = ref['fixedNow'] as int;

Object? _json(Object? v) => jsonDecode(jsonEncode(v));
Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// The save every case starts from, matching the dump script's own.
Map<String, dynamic> _baseState({
  String division = 'sunday_league',
  bool hardMode = false,
  List<String> activeEvents = const [],
}) {
  final s = jsonDecode(jsonEncode(refSave['state'])) as Map<String, dynamic>;
  (s['resources'] as Map)['fanCoins'] = 0;
  (s['resources'] as Map)['gems'] = 0;
  s['energy'] = {'current': 0, 'lastRegenAt': fixedNow};
  s['boosts'] = <String, dynamic>{};
  s['shop'] = <String, dynamic>{};
  s['prestige'] = {'level': 0};
  s['settings'] = {'hardMode': hardMode};
  // The reference save sits in Regional League, which would silently scale every
  // "at Sunday League" case.
  (s['progression'] as Map)['currentDivision'] = division;
  if (activeEvents.isNotEmpty) {
    s['events'] = {'active': activeEvents};
  }
  return s;
}

/// The same slice of the save the dump records.
Map<String, dynamic> _digest(Map<String, dynamic> s) {
  final cells = _map(s['grid'])?['cells'];
  return {
    'fanCoins': _map(s['resources'])?['fanCoins'],
    'gems': _map(s['resources'])?['gems'],
    'energyCurrent': _map(s['energy'])?['current'],
    'shop': s['shop'],
    'boosts': s['boosts'],
    'cardEnergy': [
      if (cells is List)
        for (final c in cells) _map(c)?['energy'],
    ],
  };
}

/// A product as the fixture records it — every field, so a SKU typo shows up.
Map<String, dynamic> _productMap(IapProduct p) => {
  'id': p.id,
  'sku': p.sku,
  'type': p.type,
  'category': p.category,
  'name': p.name,
  'icon': p.icon,
  if (p.desc != null) 'desc': p.desc,
  'price': p.price,
  'priceValue': p.priceValue,
  if (p.coins != null) 'coins': p.coins,
  if (p.popular || _popularIsExplicit(p.id)) 'popular': p.popular,
  if (p.bonus != null) 'bonus': p.bonus,
  if (p.descHard != null) 'descHard': p.descHard,
  if (p.coinsScaleWithDivision) 'coinsScaleWithDivision': true,
  if (p.energyAdd != null) 'energyAdd': p.energyAdd,
  if (p.oneTime) 'oneTime': true,
  if (p.vipCoinsPerWin != null) 'vipCoinsPerWin': p.vipCoinsPerWin,
  if (p.vipDays != null) 'vipDays': p.vipDays,
  if (p.energyDirector) 'energyDirector': true,
  if (p.gems != null) 'gems': p.gems,
  if (p.styleVault) 'styleVault': true,
};

/// The JS writes `popular: false` explicitly on some products and omits it on
/// others. Which ones is not a fact about the game, so it is listed rather than
/// inferred — it only exists so the field-by-field compare lines up.
bool _popularIsExplicit(String id) => const {
  'coins_small',
  'coins_medium',
  'coins_large',
  'coins_mega',
  'starter_pack',
  'vip_pass',
  'energy_director',
}.contains(id);

List<Map<String, dynamic>> _rows(String key) => [
  for (final r in ref[key] as List) r as Map<String, dynamic>,
];

void main() {
  setUp(() {
    setClock(() => fixedNow);
    seeded.setSeed(1);
  });
  tearDown(() {
    resetClock();
    clearBus();
  });

  group('the catalogue', () {
    test('is the same shelf, field for field', () {
      final want = ref['products'] as List;
      expect(products, hasLength(want.length));
      for (var i = 0; i < products.length; i++) {
        expect(
          _json(_productMap(products[i])),
          want[i],
          reason: 'product $i (${products[i].id})',
        );
      }
    });

    test('every SKU is unique and follows the store convention', () {
      // A SKU is the store's key for the product. The prefix stays
      // `com.mergeempirefc` even though the game is now called Merge Empire
      // Football Manager: a published product id cannot be renamed.
      final skus = products.map((p) => p.sku).toList();
      expect(skus.toSet().length, skus.length);
      for (final p in products) {
        expect(p.sku, 'com.mergeempirefc.${p.id}');
      }
    });

    test('every product id is unique', () {
      final ids = products.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('a one-time product is a non-consumable in the store', () {
      // Buying a consumable twice is expected; buying a non-consumable twice is
      // what the store itself refuses, so the two flags have to agree.
      for (final p in products) {
        if (p.oneTime) expect(p.type, 'non_consumable', reason: p.id);
      }
    });

    test('the shop hides event-gated products and nothing else', () {
      expect(
        getShopProducts().map((p) => p.id).toList(),
        ref['shopProductIds'],
      );
    });

    test('event products only surface for an ACTIVE event', () {
      final want = ref['eventProducts'] as Map<String, dynamic>;
      expect(
        getEventProducts(
          _baseState(activeEvents: ['wc2026']),
          'wc2026',
        ).map((p) => p.id).toList(),
        want['activeEvent'],
      );
      expect(
        getEventProducts(_baseState(), 'wc2026').map((p) => p.id).toList(),
        want['inactiveEvent'],
      );
    });

    test('a product id nobody sells resolves to null', () {
      expect(getProduct('nope'), isNull);
      expect(getProduct(null), isNull);
    });
  });

  group('division scaling', () {
    test('matches the JS at every rung, and falls back to one', () {
      (ref['divisionCoinMult'] as Map<String, dynamic>).forEach((div, want) {
        expect(
          getDivisionCoinMult(_baseState(division: div)),
          want,
          reason: div,
        );
      });
      expect(getDivisionCoinMult(null), ref['divisionCoinMultNoState']);
    });

    test('the coin bundle value badges match the JS', () {
      (ref['coinBundleValuePct'] as Map<String, dynamic>).forEach((id, want) {
        expect(getCoinBundleValuePct(getProduct(id)!), want, reason: id);
      });
    });

    test('VIP coins are worth the same number of wins at every division', () {
      (ref['vipCoins'] as Map<String, dynamic>).forEach((div, want) {
        expect(getVipCoins(_baseState(division: div)), want, reason: div);
      });
    });

    test('what the shop SHOWS is what the purchase PAYS', () {
      // These were computed separately once and drifted by two to three times.
      for (final row in _rows('grantCoins')) {
        final state = _baseState(division: '${row['division']}');
        final product = getProduct('${row['id']}')!;
        expect(
          getProductGrantCoins(state, product),
          row['shown'],
          reason: '${row['id']} @ ${row['division']}',
        );
      }
      expect(getProductGrantCoins(_baseState(), null), ref['grantCoinsNoProduct']);
    });
  });

  group('buying things', () {
    /// The overrides each labelled purchase case was run with.
    ({String division, bool hardMode}) setupFor(String label) {
      if (label.endsWith('@champions')) {
        return (division: 'champions_cup', hardMode: false);
      }
      if (label.endsWith('@hard')) {
        return (division: 'sunday_league', hardMode: true);
      }
      return (division: 'sunday_league', hardMode: false);
    }

    test('every product grants exactly what the JS grants', () {
      final rows = _rows('purchases');
      expect(rows, hasLength(25));
      for (final row in rows) {
        final label = '${row['label']}';
        final setup = setupFor(label);
        final state = _baseState(
          division: setup.division,
          hardMode: setup.hardMode,
        );
        final res = purchaseProduct(state, row['productId'] as String?);
        expect(res.ok, row['ok'], reason: label);
        expect(res.reason, row['reason'], reason: label);
        expect(res.product?.id, row['product'], reason: label);
        expect(_json(_digest(state)), row['state'], reason: '$label — save');
      }
    });

    test('a one-time product refuses a second sale and grants nothing twice', () {
      final want = ref['repeatOneTime'] as Map<String, dynamic>;
      final state = _baseState();
      expect(purchaseProduct(state, 'starter_pack').ok,
          (want['first'] as Map)['ok']);
      final after = jsonEncode(_digest(state));

      final second = purchaseProduct(state, 'starter_pack');
      expect(second.ok, (want['second'] as Map)['ok']);
      expect(second.reason, (want['second'] as Map)['reason']);
      expect(jsonEncode(_digest(state)) == after, want['unchanged']);
      expect(_json(_digest(state)), want['state']);
    });

    test('a consumable can be bought over and over, and the spend adds up', () {
      final state = _baseState();
      for (var i = 0; i < 3; i++) {
        purchaseProduct(state, 'coins_small');
      }
      purchaseProduct(state, 'gems_5');
      expect(_json(_digest(state)), ref['repeatConsumable']);
    });
  });

  group('VIP', () {
    test('is refused while live and allowed once it has lapsed', () {
      final want = ref['vip'] as Map<String, dynamic>;
      final state = _baseState();

      expect(purchaseProduct(state, 'vip_pass').ok, (want['first'] as Map)['ok']);
      final whileActive = purchaseProduct(state, 'vip_pass');
      expect(whileActive.ok, (want['whileActive'] as Map)['ok']);
      expect(whileActive.reason, (want['whileActive'] as Map)['reason']);

      final active = want['active'] as Map<String, dynamic>;
      expect(isVipActive(state), active['isVipActive']);
      expect(vipTimeRemaining(state), active['remaining']);

      // Wind the pass back to expired and try again.
      (state['shop'] as Map)['vipExpiresAt'] = fixedNow - 1;
      final expired = want['expired'] as Map<String, dynamic>;
      expect(isVipActive(state), expired['isVipActive']);
      expect(vipTimeRemaining(state), expired['remaining']);

      expect(purchaseProduct(state, 'vip_pass').ok, (want['again'] as Map)['ok']);
      expect(_json(_digest(state)), want['state']);
    });

    test('is inactive on a fresh save', () {
      final want = ref['vipFresh'] as Map<String, dynamic>;
      final state = _baseState();
      expect(isVipActive(state), want['isVipActive']);
      expect(vipTimeRemaining(state), want['remaining']);
      expect(isVipActive(null), isFalse);
      expect(vipTimeRemaining(null), 0);
    });
  });

  group('the gem ladder and the Style Vault', () {
    test('every rung improves gems-per-pound', () {
      // A rung nobody rationally picks is worse than no rung — it makes the shelf
      // look padded.
      final rows = _rows('gemLadder');
      final bundles = [
        for (final p in products)
          if (p.category == 'gems') p,
      ];
      expect(bundles.map((p) => p.id).toList(), [
        for (final r in rows) r['id'],
      ]);
      for (var i = 0; i < bundles.length; i++) {
        final perPound = bundles[i].gems! / bundles[i].priceValue;
        expect(perPound, closeTo(rows[i]['perPound'] as num, 1e-12));
        if (i > 0) {
          final prev = bundles[i - 1].gems! / bundles[i - 1].priceValue;
          expect(perPound, greaterThan(prev), reason: bundles[i].id);
        }
      }
    });

    test('the Style Vault still undercuts every way of buying the same packs', () {
      // It is the SKU we most want sold, and one that loses to a cheaper bundle
      // reads as a trap. Change a pack price, a bundle price or the ladder and
      // this is the number that tells you whether the Vault still wins.
      final want = ref['styleVault'] as Map<String, dynamic>;
      final bundles = [
        for (final p in products)
          if (p.category == 'gems') p,
      ];
      final setGems = want['setGems'] as int;

      final bestRate = bundles
          .map((b) => b.gems! / b.priceValue)
          .reduce((a, b) => a > b ? a : b);
      final cheapestRoute = bundles
          .map((b) => (setGems / b.gems!).ceil() * b.priceValue)
          .reduce((a, b) => a < b ? a : b);
      final vault = getProduct('style_vault')!;

      expect(bestRate, closeTo(want['bestGemsPerPound'] as num, 1e-12));
      expect(cheapestRoute, closeTo(want['cheapestBundleRoute'] as num, 1e-9));
      expect(vault.priceValue, want['vaultPrice']);
      expect(vault.priceValue < cheapestRoute, want['vaultWins']);
      expect(vault.priceValue < cheapestRoute, isTrue);
      expect(setGems / bestRate, closeTo(want['ceiling'] as num, 1e-9));
    });
  });
}
