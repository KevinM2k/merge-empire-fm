import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/iap_billing_policy.dart';

StoreProduct product(String sku, {bool offer = true, String? price}) =>
    (sku: sku, hasOffer: offer, localisedPrice: price);

void main() {
  group('what the shop may offer', () {
    test('NO BILLING MEANS EVERYTHING IS OFFERABLE', () {
      // There is no store to ask, and hiding the whole shelf in a browser or on
      // a dev build is worse than useless. The JS spends a paragraph on it.
      expect(canOffer('anything', null), isTrue);
    });

    test('but a SKU the store has never heard of is NOT', () {
      expect(canOffer('ghost', {'real': product('real')}), isFalse);
    });

    test('AND NEITHER IS ONE WITH NO PURCHASABLE OFFER', () {
      // Created in the console but not Active, or not rolled out here. Every
      // `buy` fails `no_offer` forever, so a tile for it can never complete —
      // which is exactly what a partial store rollout looks like.
      expect(
        canOffer('vip', {'vip': product('vip', offer: false)}),
        isFalse,
      );
    });
  });

  group('the price', () {
    test('THE STORE\'S BEATS THE CATALOGUE\'S', () {
      // A player in Japan being shown a pound sign is the whole reason the
      // store is asked at all.
      expect(
        priceFor('vip', '£4.99', {'vip': product('vip', price: '¥800')}),
        '¥800',
      );
    });

    test('and the catalogue is the fallback, including with no billing', () {
      expect(priceFor('vip', '£4.99', null), '£4.99');
      expect(priceFor('vip', '£4.99', {'vip': product('vip')}), '£4.99');
      expect(
        priceFor('vip', '£4.99', {'vip': product('vip', price: '')}),
        '£4.99',
      );
    });
  });

  group('why an attempt cannot start', () {
    test('BILLING BEING DOWN OUTRANKS EVERYTHING', () {
      // It cannot be in flight if it never started, so the order is not
      // cosmetic.
      expect(
        blockedReason(
          'vip',
          billingReady: false,
          inFlight: true,
          known: null,
        ),
        PurchaseFailure.notInitialized,
      );
    });

    test('one purchase at a time', () {
      expect(
        blockedReason(
          'vip',
          billingReady: true,
          inFlight: true,
          known: {'vip': product('vip')},
        ),
        PurchaseFailure.alreadyInFlight,
      );
    });

    test('an unknown SKU and an unofferable one are DIFFERENT noes', () {
      expect(
        blockedReason(
          'ghost',
          billingReady: true,
          inFlight: false,
          known: {'vip': product('vip')},
        ),
        PurchaseFailure.productNotFound,
      );
      expect(
        blockedReason(
          'vip',
          billingReady: true,
          inFlight: false,
          known: {'vip': product('vip', offer: false)},
        ),
        PurchaseFailure.noOffer,
      );
    });

    test('and a ready store with a live offer blocks nothing', () {
      expect(
        blockedReason(
          'vip',
          billingReady: true,
          inFlight: false,
          known: {'vip': product('vip')},
        ),
        isNull,
      );
    });
  });

  group('what the store said', () {
    test('6500 AND 6501 ARE THE PLAYER PRESSING BACK, not a failure', () {
      // The difference between a quiet dismissal and an error card for
      // something the player chose.
      for (final code in purchaseCancelCodes) {
        expect(failureForStoreCode(code), PurchaseFailure.cancelled);
      }
    });

    test('and anything else is a payment failure', () {
      expect(failureForStoreCode(null), PurchaseFailure.paymentFailed);
      expect(failureForStoreCode(7), PurchaseFailure.paymentFailed);
    });

    test('the reasons keep the JS\'s own wire strings', () {
      // `iapEngine` branches on these and the shop's copy is keyed to them.
      expect(
        PurchaseFailure.values.map((f) => f.id),
        containsAll(<String>[
          'not_initialized',
          'already_in_flight',
          'product_not_found',
          'no_offer',
          'cancelled',
          'payment_failed',
        ]),
      );
    });
  });

  test('a non-consumable is what a restore brings back', () {
    expect(isNonConsumable('non_consumable'), isTrue);
    expect(isNonConsumable('consumable'), isFalse);
  });
}
