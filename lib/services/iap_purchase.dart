/// "The user tapped Buy" — `initiatePurchase` from
/// `../merge-empire-fc/src/engine/iapEngine.js`, and the restore beside it.
///
/// **It is here rather than in `engine/iap_engine.dart` because it needs the
/// STORE.** Everything the engine does to a save when a purchase lands is
/// already there and pure — `purchaseProduct` — and this is the half that has
/// to ask a plugin whether the money arrived. The JS keeps them in one file and
/// says in its own test that this function is deliberately untested for exactly
/// that reason.
///
/// **THE ORDER OF THE PRE-FLIGHT CHECKS IS THE SPEC.** They run before the
/// store is asked, so a refusal the app can see coming never becomes a payment
/// sheet the player has to dismiss: unknown product, then the age gate, then
/// already-owned, then VIP already running. The age gate is second because it
/// is a legal one — Texas SB 2420 — and a minor must not be told what they
/// cannot buy is out of stock.
///
/// **AND A REFUSAL IS ASKED ABOUT ONCE.** A non-consumable the account already
/// owns comes back from Play as a failure, which left a lapsed VIP tapping Buy
/// and being told "payment failed" with no way on. The store is asked what it
/// owns rather than what its error code meant — see the note in
/// [initiatePurchase] — and an owned SKU is granted instead of refused.
///
/// **NOTHING IS GRANTED WITHOUT A STORE.** The JS grants for free in a dev
/// build and refuses everywhere else, and the reason it spells out is that a
/// hosted build and a native launch whose billing plugin failed to come up look
/// identical from here. `kDebugMode` is the port's `import.meta.env.DEV`.
library;

import 'package:flutter/foundation.dart';
import 'package:merge_empire_fc/engine/age_verification.dart';
import 'package:merge_empire_fc/engine/iap_billing_policy.dart';
import 'package:merge_empire_fc/engine/iap_engine.dart';
import 'package:merge_empire_fc/services/iap_billing.dart';
import 'package:merge_empire_fc/util/time.dart';

/// Why a tap did not become a purchase, or [PurchaseResult.ok].
///
/// The reasons are the JS's own wire strings — `iapEngine`'s callers branch on
/// them and the shop's copy is keyed to them.
typedef InitiateResult = PurchaseResult;

InitiateResult _refused(String reason) =>
    (ok: false, reason: reason, product: null);

/// **A build with no store must not hand out goods.** True only in a debug
/// build, which is the JS's `import.meta.env.DEV` — a released binary that
/// cannot reach billing refuses instead.
bool simulatePurchases = kDebugMode;

/// Buy [productId], for real if there is a store to buy from.
///
/// [mutate] runs the grant against the save the way the app's own state layer
/// wants it run — the JS takes the same callback, and for the same reason:
/// everything else in the save layer goes through one mutator so that "did
/// anything need saving" is a question nobody has to remember to ask.
Future<InitiateResult> initiatePurchase(
  Map<String, dynamic> state,
  String productId,
  PurchaseResult Function(PurchaseResult Function(Map<String, dynamic>) apply)
  mutate,
) async {
  final product = getProduct(productId);
  if (product == null) return _refused('unknown_product');

  // Texas SB 2420: no IAP for a Play-verified minor without parental consent.
  if (!isIapAllowed(state)) return _refused('parental_consent_required');

  final shop = state['shop'];
  final owned = shop is Map<String, dynamic> ? shop['purchasedIds'] : null;
  if (product.oneTime && owned is List && owned.contains(productId)) {
    return _refused('already_purchased');
  }
  if (productId == 'vip_pass') {
    final expires = shop is Map<String, dynamic> ? shop['vipExpiresAt'] : null;
    if (expires is num && expires > now()) return _refused('vip_already_active');
  }

  // Only ask the store once the answer can change something.
  final known = await storeCatalogue();
  if (known != null) {
    final outcome = await buySku(
      product.sku,
      nonConsumable: isNonConsumable(product.type),
    );
    if (!outcome.ok) {
      // **A NON-CONSUMABLE THE ACCOUNT ALREADY OWNS IS NOT A PAYMENT FAILURE**,
      // and it was the shop's one dead end. `vip_pass` is a non-consumable and
      // is deliberately not `oneTime`, so a LAPSED VIP is offered the buy
      // button while the store is entitled to refuse a second purchase of
      // something the account already bought — Play answers
      // ITEM_ALREADY_OWNED. Neither store has a code for that beyond a
      // failure, so the player got "payment failed" and no way forward.
      //
      // **The store is asked WHAT IT OWNS rather than what its error meant.**
      // The numeric codes above are `cordova-plugin-purchase`'s and have never
      // been re-pointed at this plugin's, so branching on one here would be a
      // guess; ownership is a question every store answers the same way, and
      // `restoreOwnedSkus` already asks it. A store that will not answer
      // returns nothing and the original refusal stands.
      //
      // Not on `cancelled`: the player pressed Back, which is an answer.
      // Only non-consumables, because a restore never lists anything else —
      // a consumable that "failed" really failed.
      //
      // Mostly Android in practice: StoreKit hands a repeat purchase of a
      // non-consumable back as a restore rather than an error, so iOS tends
      // not to reach here at all.
      final recoverable =
          outcome.reason != PurchaseFailure.cancelled &&
          isNonConsumable(product.type);
      if (!recoverable ||
          !(await restoreOwnedSkus()).contains(product.sku)) {
        return _refused(outcome.reason?.id ?? PurchaseFailure.paymentFailed.id);
      }
      // Owned. The grant below is what a restore would have done.
    }
  } else if (!simulatePurchases) {
    return _refused('billing_unavailable');
  }

  return mutate((s) => purchaseProduct(s, productId));
}

/// What a restore came to.
///
/// [restored] is every non-consumable the store says this account owns;
/// [granted] is the ones this save did not already have, which is the number
/// worth telling the player.
typedef RestoreResult = ({Set<String> restored, List<String> granted});

/// Give back what a fresh install lost.
///
/// **Only NON-CONSUMABLES.** A coin pack is consumed the moment it is granted
/// and the store will happily list it forever; re-granting one on every restore
/// is a free coin button. The two kinds are the store's own distinction and
/// `isNonConsumable` reads the catalogue's field for it.
///
/// **And only what this save does not already own**, so tapping Restore twice
/// is not two grants. `purchaseProduct` is what records the ownership, so the
/// check is the same list it writes.
Future<RestoreResult> restorePurchases(
  Map<String, dynamic> state,
  PurchaseResult Function(PurchaseResult Function(Map<String, dynamic>) apply)
  mutate,
) async {
  final owned = await restoreOwnedSkus();
  // The store answered, so what it knows may have changed — a SKU bought on
  // another device is now this build's to sell against.
  forgetStoreCatalogue();
  final granted = <String>[];
  for (final product in products) {
    if (!owned.contains(product.sku)) continue;
    if (!isNonConsumable(product.type)) continue;
    final shop = state['shop'];
    final already = shop is Map<String, dynamic> ? shop['purchasedIds'] : null;
    if (already is List && already.contains(product.id)) continue;
    final result = mutate((s) => purchaseProduct(s, product.id));
    if (result.ok) granted.add(product.id);
  }
  return (restored: owned, granted: granted);
}
