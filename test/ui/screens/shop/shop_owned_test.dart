/// What a paid tile says once you already own the thing.
///
/// Seven `shop.vip.*` keys shipped in ten languages with no caller, plus
/// `shop.owned_check`, `shop.owned_regranted` and the Energy Director's active
/// note — a state machine the JS draws on three tiles and the port drew on
/// none. It stopped being cosmetic the moment the tiles could actually buy: a
/// player who owns the Starter Pack was being offered it again, and the
/// purchase now gets as far as `initiatePurchase` before being refused.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/iap_engine.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_owned.dart';

const int _now = 1800000000000;
const int _day = 86400000;

Map<String, dynamic> save({Map<String, dynamic>? shop}) => <String, dynamic>{
  'shop': shop ?? <String, dynamic>{},
};

IapProduct get _vip => getProduct('vip_pass')!;
IapProduct get _starter => getProduct('starter_pack')!;
IapProduct get _director => getProduct('energy_director')!;
IapProduct get _coins =>
    getShopProducts().firstWhere((p) => p.category == 'coins');

void main() {
  group('VIP has three states', () {
    test('never bought is simply for sale', () {
      final state = ownedStateFor(_vip, save(), nowMs: _now);
      expect(state.owned, isFalse);
      expect(state.buttonKey, isNull);
      expect(state.noteKey, isNull);
      expect(state.ribbonKey, isNull);
    });

    test('RUNNING says how long is left, and has no ribbon', () {
      // The bonus line is an inducement, and inducing somebody to buy what they
      // already have is the tile arguing with itself.
      final state = ownedStateFor(
        _vip,
        save(shop: {'vipExpiresAt': _now + 10 * _day}),
        nowMs: _now,
      );
      expect(state.owned, isTrue);
      expect(state.buttonKey, 'shop.vip.active_btn');
      expect(state.noteKey, 'shop.vip.active');
      expect(state.days, 10);
      expect(state.ribbonKey, isNull);
    });

    test('and warns when it is nearly up', () {
      final state = ownedStateFor(
        _vip,
        save(shop: {'vipExpiresAt': _now + 2 * _day}),
        nowMs: _now,
      );
      expect(state.noteKey, 'shop.vip.active_expiring');
      expect(state.days, 2);
    });

    test('LAPSED IS THE INTERESTING ONE', () {
      // A player who has paid once is the one most likely to pay again, and the
      // tile is the only place that can say so.
      final state = ownedStateFor(
        _vip,
        save(shop: {'vipExpiresAt': _now - _day}),
        nowMs: _now,
      );
      expect(state.owned, isFalse, reason: 'it is buyable again');
      expect(state.ribbonKey, 'shop.vip.reactivate_ribbon');
      expect(state.noteKey, 'shop.vip.lapsed_note');
    });

    test('days left round UP', () {
      // A pass with two hours left is a pass with a day on it as far as a
      // player is concerned; "0 days left" about something still working is
      // worse than being a few hours generous.
      expect(
        vipDaysLeft(save(shop: {'vipExpiresAt': _now + 7200000}), nowMs: _now),
        1,
      );
      expect(vipDaysLeft(save(), nowMs: _now), 0);
      expect(
        vipDaysLeft(save(shop: {'vipExpiresAt': _now - 1}), nowMs: _now),
        0,
      );
    });

    test('and a save that never bought it has not LAPSED either', () {
      expect(vipLapsed(save(), nowMs: _now), isFalse);
      expect(vipLapsed(save(shop: {'vipExpiresAt': 0}), nowMs: _now), isFalse);
    });
  });

  group('the one-time products', () {
    test('OWNED, AND SAYING WHY THEY ARE STILL ON THE SHELF', () {
      // A one-time purchase that vanished once bought would look like it had
      // been taken away at the next prestige.
      final state = ownedStateFor(
        _starter,
        save(shop: {
          'purchasedIds': ['starter_pack'],
        }),
        nowMs: _now,
      );
      expect(state.owned, isTrue);
      expect(state.buttonKey, 'shop.owned_check');
      expect(state.noteKey, 'shop.owned_regranted');
    });

    test('and unbought they are for sale', () {
      expect(ownedStateFor(_starter, save(), nowMs: _now).owned, isFalse);
    });

    test('THE ENERGY DIRECTOR IS OWNED BY ITS EFFECT, not by a receipt', () {
      // `energyUpgraded` is what every other reader checks; a second source for
      // "do they have it" is how a restore and a purchase come to disagree.
      expect(
        ownedStateFor(
          _director,
          save(shop: {'energyUpgraded': true}),
          nowMs: _now,
        ).owned,
        isTrue,
      );
      expect(
        ownedStateFor(
          _director,
          save(shop: {
            'purchasedIds': ['energy_director'],
          }),
          nowMs: _now,
        ).owned,
        isFalse,
        reason: 'the receipt is not the flag',
      );
    });
  });

  group('a consumable', () {
    test('is never owned, however many have been bought', () {
      // A coin pack is consumed the moment it is granted.
      expect(
        ownedStateFor(
          _coins,
          save(shop: {
            'purchasedIds': [_coins.id],
          }),
          nowMs: _now,
        ).owned,
        isFalse,
      );
    });
  });
}
