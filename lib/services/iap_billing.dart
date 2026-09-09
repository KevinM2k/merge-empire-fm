/// The store, as far as the shop is concerned — the transport half of
/// `../merge-empire-fc/src/engine/iapClient.js`.
///
/// **The rules are in `engine/iap_billing_policy.dart`**, which is pure and
/// tested; what is here is the plugin and the lifecycle. That split is why
/// swapping `cordova-plugin-purchase` for `in_app_purchase` changed nothing
/// above this file.
///
/// **A PURCHASE ARRIVES ON A STREAM, NOT AS A RETURN VALUE.** `buy()` says only
/// that the store's sheet went up; the answer comes back later on
/// `purchaseStream`, and on the next launch too if the app died mid-payment.
/// That is the one shape difference from the JS worth knowing about, and it is
/// the reason [buySku] hands back a future completed by the stream rather than
/// by the call.
///
/// **AND A PURCHASE MUST BE COMPLETED OR THE STORE REDELIVERS IT.** `complete()`
/// is what tells the store the goods were handed over; skip it and Play and
/// StoreKit both re-present the same purchase on every launch, forever. It runs
/// on failures too — a cancelled or errored purchase is still pending until it
/// is acknowledged.
///
/// The seams are here rather than at the call sites so a test replaces the
/// store instead of the platform, which is the same arrangement
/// `platform_seams.dart` explains.
library;

import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart'
    show InAppPurchasePlatform;
import 'package:merge_empire_fc/engine/iap_billing_policy.dart';

/// What the store has told us about, keyed by SKU — or **null when billing is
/// not running at all**, which is not the same as an empty store.
///
/// Empty means "the store answered and knows none of our products", which
/// hides every tile. Null means "there is nobody to ask", which shows them all
/// and lets the simulate path handle the tap. Getting those two the same way
/// round is the difference between a browser showing an empty shop and a
/// device showing one it cannot sell from.
typedef StoreCatalogue = Map<String, StoreProduct>?;

/// The catalogue seam. Returns null when no store answers.
Future<StoreCatalogue> Function() iapBillingSource = _noStore;

/// The purchase seam: put the store's own sheet up for one SKU and wait for
/// what it says. [nonConsumable] picks which of the plugin's two buys to make —
/// the store treats them differently and a consumable bought as the other can
/// never be bought again.
Future<PurchaseOutcome> Function(String sku, {required bool nonConsumable})
iapPurchaseSource = _noPurchase;

/// The restore seam. Returns the SKUs this account already owns.
Future<Set<String>> Function() iapRestoreSource = _noRestore;

Future<StoreCatalogue> _noStore() async => null;

Future<PurchaseOutcome> _noPurchase(String sku, {required bool nonConsumable}) async =>
    purchaseFailed(PurchaseFailure.notInitialized);

Future<Set<String>> _noRestore() async => const {};

/// Put them back. For tests.
///
/// Clears [_live] too, not just the seams: `wireNativeBilling` only ever
/// builds one `_LiveStore` (`??=`) and a test that wires a fresh fake platform
/// without this would hand it a store still listening on the OLD one.
void resetIapBillingSource() {
  iapBillingSource = _noStore;
  iapPurchaseSource = _noPurchase;
  iapRestoreSource = _noRestore;
  forgetStoreCatalogue();
  _live = null;
}

/// What the store knows, or null. Cached for the process: a store's catalogue
/// does not change under a running app, and asking it is a plugin round trip.
StoreCatalogue _cached;
bool _asked = false;

Future<StoreCatalogue> storeCatalogue() async {
  if (_asked) return _cached;
  _asked = true;
  try {
    _cached = await iapBillingSource();
  } catch (_) {
    // A store that will not answer is a store that is not there.
    _cached = null;
  }
  return _cached;
}

/// Forget what the store said. For tests, and for a restore, which is the one
/// thing that can change what this build owns.
void forgetStoreCatalogue() {
  _asked = false;
  _cached = null;
}

/// Whether native billing is up at all.
bool get billingReady => _cached != null;

/// Buy one SKU. Never throws: everything is a [PurchaseOutcome].
Future<PurchaseOutcome> buySku(String sku, {required bool nonConsumable}) async {
  try {
    return await iapPurchaseSource(sku, nonConsumable: nonConsumable);
  } catch (_) {
    return purchaseFailed(PurchaseFailure.paymentFailed);
  }
}

/// What this account already owns. Empty when nothing does, or when nobody
/// answered — a restore that cannot reach the store must not un-own anything.
Future<Set<String>> restoreOwnedSkus() async {
  try {
    return await iapRestoreSource();
  } catch (_) {
    return const {};
  }
}

// ---------------------------------------------------------------------------
// The real store.
// ---------------------------------------------------------------------------

/// The live plugin, and the purchase stream it answers on.
///
/// **One subscription for the app's lifetime.** The stream carries purchases
/// this session started AND ones the store is redelivering from a session that
/// died mid-payment, so it has to be listening before anything is bought — a
/// subscription opened per tap would miss the second kind entirely, which is
/// how a paid-for pack goes missing.
class _LiveStore {
  _LiveStore(this._plugin, {this.onUnclaimed});

  // **THE RAW PLATFORM, not the `InAppPurchase` wrapper.** The wrapper's own
  // `.instance` getter registers the real platform as a SIDE EFFECT of being
  // read for the first time in the process — fine at boot, but it means the
  // only way to test this class was to let that registration run first and
  // then hope nothing else touched `.instance` again. Every method this class
  // calls is on `InAppPurchasePlatform` too, already registered by Flutter's
  // own plugin bootstrap before any app code runs, so reading the interface
  // directly changes nothing at runtime and needs no such trick in a test.
  final InAppPurchasePlatform _plugin;

  /// A purchase that arrived with nobody in [_waiting] for it — a session
  /// that died mid-payment gets it redelivered on the next launch, once
  /// `buy`'s own Completer is long gone. [isRestore] is true for
  /// `PurchaseStatus.restored`, the store's own "you already own this", so the
  /// caller can grant it without logging it as a new sale — the same
  /// distinction `restorePurchases` draws for its own restore.
  final void Function(String storeSku, {required bool isRestore})? onUnclaimed;

  StreamSubscription<List<PurchaseDetails>>? _listener;

  /// The buy in flight, waiting on the stream. Keyed by product id, because
  /// that is what the store echoes back.
  final Map<String, Completer<PurchaseOutcome>> _waiting = {};

  /// SKUs the store handed back during a restore, filled while one runs.
  Set<String>? _restoring;
  Completer<void>? _restoreDone;

  void start() {
    _listener ??= _plugin.purchaseStream.listen(
      _onPurchases,
      onError: (_) {
        // A stream that has fallen over cannot answer anything still waiting,
        // and a tap that never comes back is worse than one that fails.
        for (final pending in _waiting.values) {
          if (!pending.isCompleted) {
            pending.complete(purchaseFailed(PurchaseFailure.paymentFailed));
          }
        }
        _waiting.clear();
      },
    );
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // Still with the store — a slow card, a cash payment, Ask to Buy,
          // which can run for days. Left unsettled, the waiting caller hung
          // forever and the SKU's slot in `_waiting` was never freed, so a
          // retry answered `alreadyInFlight` for the rest of the session.
          // Settled as a failure now instead; if the store resolves it for
          // real later, that purchase arrives with nobody waiting for it any
          // more and is caught by [onUnclaimed] below, same as a redelivery.
          _settle(purchase.productID, purchaseFailed(PurchaseFailure.paymentFailed));
          continue;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _restoring?.add(purchase.productID);
          if (!_settle(purchase.productID, purchaseSucceeded)) {
            // Nobody was waiting — a redelivery, or the late resolution of a
            // `pending` this store already settled as failed above. Handing
            // it to `_settle` alone would complete a Completer nobody reads
            // and the grant would be lost for good: `completePurchase` below
            // still runs, and a consumable it acknowledges with no grant
            // behind it can never be redelivered again.
            onUnclaimed?.call(
              purchase.productID,
              isRestore: purchase.status == PurchaseStatus.restored,
            );
          }
        case PurchaseStatus.canceled:
          _settle(purchase.productID, purchaseFailed(PurchaseFailure.cancelled));
        case PurchaseStatus.error:
          _settle(
            purchase.productID,
            // **The plugin's own cancel codes, not the cordova ones.** The JS
            // maps 6500/6501 to a quiet dismissal; StoreKit and Play report
            // their own, and `canceled` above is where most of them land — this
            // is the one that arrives as an error with a code on it.
            purchaseFailed(
              failureForStoreCode(int.tryParse(purchase.error?.code ?? '')),
            ),
          );
      }
      // Whatever it came to, the store is told. An unacknowledged purchase is
      // redelivered on every launch until it is.
      if (purchase.pendingCompletePurchase) {
        await _plugin.completePurchase(purchase);
      }
    }
    // **THE PLUGIN GIVES NO "RESTORE FINISHED" SIGNAL OF ITS OWN** — see
    // `restore`'s own note — so a restore in progress that has heard from the
    // store AT ALL is the closest thing to one: in practice every owned SKU
    // arrives in one batch to this same callback. Completing here turns
    // "always wait the full 4 seconds" into "usually return the moment the
    // store answers", while an account that owns nothing still falls back to
    // `restore`'s own timeout, because this callback is never reached for it.
    if (_restoring != null && purchases.isNotEmpty) {
      final done = _restoreDone;
      if (done != null && !done.isCompleted) done.complete();
    }
  }

  /// Settle the buy waiting on [productId], if one is. True when one was.
  bool _settle(String productId, PurchaseOutcome outcome) {
    final pending = _waiting.remove(productId);
    if (pending == null) return false;
    if (!pending.isCompleted) pending.complete(outcome);
    return true;
  }

  Future<StoreCatalogue> catalogue(Set<String> skus) async {
    if (!await _plugin.isAvailable()) return null;
    start();
    final response = await _plugin.queryProductDetails(skus);
    // **`notFoundIDs` is not an error.** It is a SKU this build knows and the
    // console does not — exactly the partial-rollout state `canOffer` exists
    // for — so it is simply absent from the map and its tile is not drawn.
    return {
      for (final product in response.productDetails)
        product.id: (
          sku: product.id,
          hasOffer: true,
          localisedPrice: product.price,
        ),
    };
  }

  Future<PurchaseOutcome> buy(String sku, {required bool nonConsumable}) async {
    final known = await storeCatalogue();
    if (known == null) return purchaseFailed(PurchaseFailure.notInitialized);
    if (_waiting.containsKey(sku)) {
      return purchaseFailed(PurchaseFailure.alreadyInFlight);
    }
    // The plugin wants the whole `ProductDetails`, not the id, so the query is
    // made again for the one SKU rather than caching objects the store owns.
    final response = await _plugin.queryProductDetails({sku});
    final details = response.productDetails
        .where((p) => p.id == sku)
        .firstOrNull;
    if (details == null) return purchaseFailed(PurchaseFailure.productNotFound);

    start();
    final pending = Completer<PurchaseOutcome>();
    _waiting[sku] = pending;
    final param = PurchaseParam(productDetails: details);
    final bool started;
    try {
      started = nonConsumable
          ? await _plugin.buyNonConsumable(purchaseParam: param)
          : await _plugin.buyConsumable(purchaseParam: param);
    } catch (_) {
      _waiting.remove(sku);
      return purchaseFailed(PurchaseFailure.paymentFailed);
    }
    if (!started) {
      _waiting.remove(sku);
      return purchaseFailed(PurchaseFailure.paymentFailed);
    }
    return pending.future;
  }

  Future<Set<String>> restore() async {
    if (!await _plugin.isAvailable()) return const {};
    start();
    final found = <String>{};
    _restoring = found;
    _restoreDone = Completer<void>();
    try {
      await _plugin.restorePurchases();
      // **The plugin's `restorePurchases` returns before the stream does.**
      // There is no "and that was all of them" signal, so this waits a beat and
      // takes what arrived — the alternative is a future that never completes
      // for an account that owns nothing.
      await Future.any([
        _restoreDone!.future,
        Future<void>.delayed(const Duration(seconds: 4)),
      ]);
    } catch (_) {
      // Nothing restored is not the same as nothing owned; the caller grants
      // only what it is handed, so an empty set changes nothing.
    } finally {
      _restoring = null;
      _restoreDone = null;
    }
    return found;
  }
}

_LiveStore? _live;

/// Point the seams at the real store.
///
/// Called once at boot with the SKUs this build knows. Separate from the file's
/// own state so that importing it does not start a plugin.
///
/// [onUnclaimedPurchase] is where a redelivered or late-resolved purchase with
/// nobody waiting for it is granted — see `_LiveStore.onUnclaimed`. Optional
/// because this file does not import the engine that would apply a grant;
/// the caller wires one against its own save.
void wireNativeBilling(
  Set<String> skus, {
  void Function(String storeSku, {required bool isRestore})? onUnclaimedPurchase,
}) {
  final store = _live ??= _LiveStore(
    InAppPurchasePlatform.instance,
    onUnclaimed: onUnclaimedPurchase,
  );
  iapBillingSource = () => store.catalogue(skus);
  iapPurchaseSource = store.buy;
  iapRestoreSource = store.restore;
}
