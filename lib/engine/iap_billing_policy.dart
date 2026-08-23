/// What a purchase attempt can come back as, and what the shop may offer —
/// the pure half of `../merge-empire-fc/src/engine/iapClient.js`.
///
/// **The rest of that file is the cordova plugin's lifecycle**, and it is a
/// lifecycle this build will not have: a Flutter port reaches the stores
/// through their own billing plugin rather than through
/// `window.CdvPurchase`. What survives the change of transport is everything
/// the file ARGUES for, and every argument in it is a rule about state:
///
/// - **A SKU can be registered here and not exist in the store.** A product
///   that is not created-and-Active in Play Console or App Store Connect comes
///   back with no purchasable offer, and every `buy` then fails `no_offer`
///   forever. Without [canOffer] the shop renders a tile at its catalogue
///   fallback price that can never complete — which is exactly the state a
///   partial store rollout leaves you in, because SKUs get added one at a time.
/// - **And when billing is not running at all, EVERYTHING is offerable.**
///   There is no store to ask, and hiding the whole shelf in a browser or on a
///   dev build is worse than useless. The JS says so in as many words.
/// - **One purchase in flight.** A second tap while the store's own sheet is up
///   is not a second purchase, it is the same one.
///
/// Deliberately Flutter-free and plugin-free, so all of it runs under plain
/// `dart test` with no store and no device.
library;

/// Why an attempt did not become a purchase.
///
/// The JS's own strings, because they are what `iapEngine` branches on and what
/// the shop's copy is keyed to.
enum PurchaseFailure {
  /// Billing never started — web, a dev build, or a plugin that failed to come
  /// up. The simulate path handles the purchase.
  notInitialized('not_initialized'),

  /// A purchase is already up. The store owns the screen.
  alreadyInFlight('already_in_flight'),

  /// This build knows the SKU and the store does not.
  productNotFound('product_not_found'),

  /// The store knows the SKU but has nothing purchasable for it — created but
  /// not Active, or not rolled out to this account's country.
  noOffer('no_offer'),

  /// The player backed out. **Not an error to report**: they answered.
  cancelled('cancelled'),

  /// Anything else the store said no to.
  paymentFailed('payment_failed');

  const PurchaseFailure(this.id);

  /// The wire string, matching the JS.
  final String id;
}

/// What one attempt came to.
typedef PurchaseOutcome = ({bool ok, PurchaseFailure? reason});

const PurchaseOutcome purchaseSucceeded = (ok: true, reason: null);

PurchaseOutcome purchaseFailed(PurchaseFailure reason) =>
    (ok: false, reason: reason);

/// **The two codes that mean the player pressed Back.**
///
/// `cordova-plugin-purchase` reports a cancel as 6500 or 6501, and the JS maps
/// both to `cancelled` rather than to a failure — which is the difference
/// between a quiet dismissal and an error card for something the player chose.
/// The numbers are the plugin's; a Flutter billing plugin reports its own, and
/// this is the mapping that has to be re-pointed rather than re-decided.
const Set<int> purchaseCancelCodes = {6500, 6501};

PurchaseFailure failureForStoreCode(int? code) =>
    purchaseCancelCodes.contains(code)
    ? PurchaseFailure.cancelled
    : PurchaseFailure.paymentFailed;

/// What the store knows about one SKU, as far as any of this cares.
typedef StoreProduct = ({
  String sku,

  /// A purchasable offer exists. False is a product created but not Active.
  bool hasOffer,

  /// The store's own localised price, which beats the catalogue's every time —
  /// the catalogue's is a fallback in one currency.
  String? localisedPrice,
});

/// Can this SKU actually be bought right now?
///
/// [known] is what the store has told us about, or null when billing is not
/// running — and **null answers TRUE for everything**, which is the rule the
/// JS's own comment spends a paragraph on.
bool canOffer(String sku, Map<String, StoreProduct>? known) {
  if (known == null) return true;
  return known[sku]?.hasOffer ?? false;
}

/// The price to print: the store's, then the catalogue's.
///
/// Never the catalogue's when the store has one. A player in Japan being shown
/// a pound sign is the whole reason the store is asked at all.
String priceFor(String sku, String catalogue, Map<String, StoreProduct>? known) {
  final live = known?[sku]?.localisedPrice;
  return live != null && live.isNotEmpty ? live : catalogue;
}

/// Why an attempt cannot even be started, or null when it can.
///
/// Checked in the JS's own order, which matters: "billing is not up" outranks
/// "something else is in flight", because the second cannot be true if the
/// first is.
PurchaseFailure? blockedReason(
  String sku, {
  required bool billingReady,
  required bool inFlight,
  required Map<String, StoreProduct>? known,
}) {
  if (!billingReady) return PurchaseFailure.notInitialized;
  if (inFlight) return PurchaseFailure.alreadyInFlight;
  final product = known?[sku];
  if (product == null) return PurchaseFailure.productNotFound;
  if (!product.hasOffer) return PurchaseFailure.noOffer;
  return null;
}

/// Which of the store's two product kinds a catalogue entry is.
///
/// A consumable can be bought again; a non-consumable is owned once and is what
/// `restorePurchases` brings back on a fresh install. The catalogue's `type`
/// field carries the JS's own two strings.
bool isNonConsumable(String type) => type == 'non_consumable';
