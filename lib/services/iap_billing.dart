/// The store, as far as the shop is concerned — the transport half of
/// `../merge-empire-fc/src/engine/iapClient.js`.
///
/// **There is no billing plugin in this build**, and this file is what that
/// fact lives behind rather than being spread across the shop. Everything it
/// exposes has a documented answer for "no store", every one of them is the
/// JS's own, and [iapBillingSource] is the one line a plugin gets wired into.
///
/// The rules are in `engine/iap_billing_policy.dart`, which is pure and tested.
/// What is here is the seam.
library;

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

/// The seam. Returns null until a billing plugin is wired in.
Future<StoreCatalogue> Function() iapBillingSource = _noStore;

Future<StoreCatalogue> _noStore() async => null;

/// Put it back. For tests.
void resetIapBillingSource() => iapBillingSource = _noStore;

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
