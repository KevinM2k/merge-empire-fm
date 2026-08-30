/// "The user tapped Buy", over the store seam.
///
/// **The order of the pre-flight checks is what most of this pins.** They run
/// before the store is asked, so a refusal the app can see coming never becomes
/// a payment sheet the player has to dismiss — and the age gate is second
/// because it is a legal check rather than a stock one.
///
/// Nothing here opens a store: `iapBillingSource` and `iapPurchaseSource` are
/// replaced wholesale.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/iap_billing_policy.dart';
import 'package:merge_empire_fc/engine/iap_engine.dart';
import 'package:merge_empire_fc/services/iap_billing.dart';
import 'package:merge_empire_fc/services/iap_purchase.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/util/time.dart';

late List<({String sku, bool nonConsumable})> bought;

/// A store that knows every SKU this build does.
void storeKnowsEverything({bool hasOffer = true}) {
  iapBillingSource = () async => {
    for (final product in products)
      product.sku: (
        sku: product.sku,
        hasOffer: hasOffer,
        localisedPrice: '¥500',
      ),
  };
}

void storeSays(PurchaseOutcome outcome) {
  iapPurchaseSource = (sku, {required bool nonConsumable}) async {
    bought.add((sku: sku, nonConsumable: nonConsumable));
    return outcome;
  };
}

/// The app's own mutator, as far as this is concerned — the real one goes
/// through `GameState.update` so the save is scheduled; here the point is only
/// that the grant runs against the same map.
PurchaseResult Function(PurchaseResult Function(Map<String, dynamic>))
mutatorFor(Map<String, dynamic> state) => (apply) => apply(state);

void main() {
  setUp(() {
    bought = [];
    resetIapBillingSource();
    storeSays(purchaseSucceeded);
    simulatePurchases = false;
  });

  tearDown(() {
    resetIapBillingSource();
    simulatePurchases = true;
  });

  test('a SKU nobody has heard of never reaches the store', () async {
    final state = createDefaultState();
    final result = await initiatePurchase(state, 'not_a_product', mutatorFor(state));
    expect(result.ok, isFalse);
    expect(result.reason, 'unknown_product');
    expect(bought, isEmpty);
  });

  test('THE AGE GATE OUTRANKS EVERY STOCK CHECK', () async {
    // Texas SB 2420. A minor must not be told what they cannot buy is out of
    // stock, so this is checked before anything about the store — and before
    // already-owned, which would otherwise answer first for a re-tap.
    final state = createDefaultState()
      ..['ageVerification'] = <String, dynamic>{
        'status': 'child',
        'parentalConsentGiven': false,
      };
    storeKnowsEverything();
    final result = await initiatePurchase(state, 'coins_small', mutatorFor(state));
    expect(result.reason, 'parental_consent_required');
    expect(bought, isEmpty);
  });

  test('and a parent who consented buys normally', () async {
    final state = createDefaultState()
      ..['ageVerification'] = <String, dynamic>{
        'status': 'child',
        'parentalConsentGiven': true,
      };
    storeKnowsEverything();
    expect(
      (await initiatePurchase(state, 'coins_small', mutatorFor(state))).ok,
      isTrue,
    );
  });

  test('a one-time product already owned is refused before the store', () async {
    final state = createDefaultState()
      ..['shop'] = <String, dynamic>{
        'purchasedIds': ['style_vault'],
      };
    storeKnowsEverything();
    final result = await initiatePurchase(state, 'style_vault', mutatorFor(state));
    expect(result.reason, 'already_purchased');
    expect(bought, isEmpty);
  });

  test('VIP that is still running is refused before the store', () async {
    final state = createDefaultState()
      ..['shop'] = <String, dynamic>{
        'vipExpiresAt': now() + const Duration(days: 2).inMilliseconds,
      };
    storeKnowsEverything();
    final result = await initiatePurchase(state, 'vip_pass', mutatorFor(state));
    expect(result.reason, 'vip_already_active');
    expect(bought, isEmpty);
  });

  test('VIP that has run out buys again', () async {
    final state = createDefaultState()
      ..['shop'] = <String, dynamic>{'vipExpiresAt': 1};
    storeKnowsEverything();
    expect(
      (await initiatePurchase(state, 'vip_pass', mutatorFor(state))).ok,
      isTrue,
    );
  });

  group('the store itself', () {
    test('is asked with the right kind of buy', () async {
      // A consumable bought as the other can never be bought again.
      storeKnowsEverything();
      final state = createDefaultState();
      await initiatePurchase(state, 'coins_small', mutatorFor(state));
      await initiatePurchase(state, 'style_vault', mutatorFor(state));
      expect(bought.map((b) => b.nonConsumable), [false, true]);
      expect(bought.first.sku, getProduct('coins_small')!.sku);
    });

    test('A REFUSAL GRANTS NOTHING', () async {
      storeKnowsEverything();
      storeSays(purchaseFailed(PurchaseFailure.cancelled));
      final state = createDefaultState();
      final coinsBefore = (state['resources'] as Map)['fanCoins'];
      final result = await initiatePurchase(
        state,
        'coins_small',
        mutatorFor(state),
      );
      expect(result.ok, isFalse);
      expect(result.reason, 'cancelled');
      expect((state['resources'] as Map)['fanCoins'], coinsBefore);
    });

    test('reports the store\'s own reason, not a generic one', () async {
      storeKnowsEverything();
      storeSays(purchaseFailed(PurchaseFailure.noOffer));
      final state = createDefaultState();
      expect(
        (await initiatePurchase(state, 'coins_small', mutatorFor(state))).reason,
        'no_offer',
      );
    });
  });

  group('with no store at all', () {
    test('A RELEASE BUILD REFUSES rather than granting for free', () async {
      // The JS's own reasoning: a hosted build and a native launch whose
      // billing failed to come up look identical from here.
      final state = createDefaultState();
      final coinsBefore = (state['resources'] as Map)['fanCoins'];
      final result = await initiatePurchase(
        state,
        'coins_small',
        mutatorFor(state),
      );
      expect(result.reason, 'billing_unavailable');
      expect((state['resources'] as Map)['fanCoins'], coinsBefore);
      expect(bought, isEmpty);
    });

    test('and a debug build simulates, which is what the shop runs on', () async {
      simulatePurchases = true;
      final state = createDefaultState();
      final coinsBefore = (state['resources'] as Map)['fanCoins'] as num;
      expect(
        (await initiatePurchase(state, 'coins_small', mutatorFor(state))).ok,
        isTrue,
      );
      expect(
        (state['resources'] as Map)['fanCoins'],
        greaterThan(coinsBefore),
      );
      expect(bought, isEmpty, reason: 'there was nobody to ask');
    });
  });

  group('AND A REFUSAL THAT MEANS "YOU ALREADY OWN THIS"', () {
    // **The shop's one dead end.** `vip_pass` is a non-consumable and is
    // deliberately not `oneTime`, so a lapsed VIP is offered the buy button
    // while the store is entitled to refuse a second purchase of something the
    // account already bought. Play answers ITEM_ALREADY_OWNED and neither
    // store has a code for it beyond a failure, so the player was told
    // "payment failed" and had nowhere to go.
    test('IS A GRANT, not a payment failure', () async {
      final vip = getProduct('vip_pass')!;
      storeKnowsEverything();
      storeSays(purchaseFailed(PurchaseFailure.paymentFailed));
      iapRestoreSource = () async => {vip.sku};
      final state = createDefaultState();
      final result = await initiatePurchase(state, 'vip_pass', mutatorFor(state));
      expect(result.ok, isTrue, reason: 'the account owns it');
      expect(
        (state['shop'] as Map<String, dynamic>)['vipExpiresAt'],
        isA<num>(),
      );
    });

    test('and a real failure is still a real failure', () async {
      // The store answered, and it does not own this.
      storeKnowsEverything();
      storeSays(purchaseFailed(PurchaseFailure.paymentFailed));
      iapRestoreSource = () async => const <String>{};
      final state = createDefaultState();
      final result = await initiatePurchase(state, 'vip_pass', mutatorFor(state));
      expect(result.ok, isFalse);
      expect(result.reason, 'payment_failed');
    });

    test('A CANCEL IS AN ANSWER, and is never overridden', () async {
      // The player pressed Back. Owning it is beside the point.
      final vip = getProduct('vip_pass')!;
      storeKnowsEverything();
      storeSays(purchaseFailed(PurchaseFailure.cancelled));
      iapRestoreSource = () async => {vip.sku};
      final state = createDefaultState();
      final result = await initiatePurchase(state, 'vip_pass', mutatorFor(state));
      expect(result.ok, isFalse);
      expect(result.reason, 'cancelled');
    });

    test('and a CONSUMABLE that failed really failed', () async {
      // A restore never lists one, so there is nothing to recover from — and
      // granting a coin pack off a failed payment is a free coin button.
      final coins = getShopProducts().firstWhere((p) => p.category == 'coins');
      storeKnowsEverything();
      storeSays(purchaseFailed(PurchaseFailure.paymentFailed));
      iapRestoreSource = () async => {coins.sku};
      final state = createDefaultState();
      final before = (state['resources'] as Map)['fanCoins'];
      final result = await initiatePurchase(state, coins.id, mutatorFor(state));
      expect(result.ok, isFalse);
      expect(result.reason, 'payment_failed');
      expect((state['resources'] as Map)['fanCoins'], before);
    });

    test('a store that will not answer leaves the refusal standing', () async {
      storeKnowsEverything();
      storeSays(purchaseFailed(PurchaseFailure.paymentFailed));
      iapRestoreSource = () async => throw Exception('offline');
      final state = createDefaultState();
      final result = await initiatePurchase(state, 'vip_pass', mutatorFor(state));
      expect(result.ok, isFalse);
      expect(result.reason, 'payment_failed');
    });
  });

  group('restoring', () {
    test('grants a non-consumable the save does not own', () async {
      final vault = getProduct('style_vault')!;
      iapRestoreSource = () async => {vault.sku};
      final state = createDefaultState();
      final result = await restorePurchases(state, mutatorFor(state));
      expect(result.granted, ['style_vault']);
      expect(
        (state['shop'] as Map<String, dynamic>)['purchasedIds'],
        contains('style_vault'),
      );
    });

    test('NEVER RE-GRANTS A CONSUMABLE', () async {
      // The store lists a coin pack forever; granting one on each restore is a
      // free coin button.
      final coins = getShopProducts().firstWhere((p) => p.category == 'coins');
      iapRestoreSource = () async => {coins.sku};
      final state = createDefaultState();
      final before = (state['resources'] as Map)['fanCoins'];
      final result = await restorePurchases(state, mutatorFor(state));
      expect(result.granted, isEmpty);
      expect((state['resources'] as Map)['fanCoins'], before);
    });

    test('twice is not two grants', () async {
      final vault = getProduct('style_vault')!;
      iapRestoreSource = () async => {vault.sku};
      final state = createDefaultState();
      await restorePurchases(state, mutatorFor(state));
      final second = await restorePurchases(state, mutatorFor(state));
      expect(second.granted, isEmpty);
      expect(
        (state['shop'] as Map<String, dynamic>)['purchasedIds'],
        ['style_vault'],
      );
    });

    test('a store that will not answer un-owns nothing', () async {
      iapRestoreSource = () async => throw Exception('offline');
      final state = createDefaultState()
        ..['shop'] = <String, dynamic>{
          'purchasedIds': ['style_vault'],
        };
      final result = await restorePurchases(state, mutatorFor(state));
      expect(result.restored, isEmpty);
      expect(
        (state['shop'] as Map<String, dynamic>)['purchasedIds'],
        ['style_vault'],
      );
    });
  });
}
