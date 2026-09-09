/// `_LiveStore`, the private half of `iap_billing.dart` no test reached
/// before this — every other test in the suite replaces the SEAMS
/// (`iapPurchaseSource` etc.), so the class that actually talks to the plugin
/// had none of its own. `_LiveStore` is private, so this drives it the way
/// the file's own header says a test should: by swapping the PLATFORM
/// (`InAppPurchasePlatform.instance`) rather than the seam, through
/// `wireNativeBilling` and the public seams it wires.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart' show InAppPurchase;
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:merge_empire_fc/engine/iap_billing_policy.dart';
import 'package:merge_empire_fc/services/iap_billing.dart';

/// A store with no real plugin behind it, driven entirely from the test.
class _FakePlatform extends InAppPurchasePlatform {
  final _controller = StreamController<List<PurchaseDetails>>.broadcast();

  bool available = true;
  List<ProductDetails> products = [];
  bool buyResult = true;
  final List<String> completedIds = [];
  int restoreCalls = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(productDetails: products, notFoundIDs: []);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      buyResult;

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async => buyResult;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completedIds.add(purchase.productID);
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalls++;
  }

  /// Deliver purchase updates the way the real plugin's stream would.
  void push(List<PurchaseDetails> purchases) => _controller.add(purchases);

  void dispose() => _controller.close();
}

ProductDetails _product(String id) => ProductDetails(
  id: id,
  title: id,
  description: id,
  price: '£1.00',
  rawPrice: 1,
  currencyCode: 'GBP',
);

PurchaseDetails _purchase(
  String id,
  PurchaseStatus status, {
  bool pendingComplete = true,
}) => PurchaseDetails(
  productID: id,
  status: status,
  transactionDate: '0',
  verificationData: PurchaseVerificationData(
    localVerificationData: 'local',
    serverVerificationData: 'server',
    source: 'google_play',
  ),
)..pendingCompletePurchase = pendingComplete;

void main() {
  late _FakePlatform platform;

  setUpAll(() {
    // `InAppPurchase.instance` registers a REAL platform-specific plugin the
    // FIRST time it is ever touched in the process, as a side effect of the
    // getter — `wireNativeBilling` calls it to build `_LiveStore`, and
    // without this that registration would run against whatever fake a test
    // below has set, overwriting it (and, on Android, trying to open a real
    // billing connection that throws later, off a test that already
    // finished). Spent here once, under a target platform neither the
    // Android nor iOS/macOS branch recognises, so nothing real registers and
    // the only thing cached is the (stateless) wrapper — every later
    // `InAppPurchase.instance` call, from any test, just returns it without
    // touching the platform singleton again.
    final original = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    InAppPurchase.instance;
    debugDefaultTargetPlatformOverride = original;
  });

  setUp(() {
    platform = _FakePlatform();
    InAppPurchasePlatform.instance = platform;
    resetIapBillingSource();
  });

  tearDown(() {
    platform.dispose();
    resetIapBillingSource();
  });

  group('A REDELIVERED PURCHASE IS GRANTED, not just acknowledged', () {
    test('purchased with nobody waiting reaches onUnclaimed', () async {
      final unclaimed = <(String, bool)>[];
      wireNativeBilling(
        {'sku_a'},
        onUnclaimedPurchase: (sku, {required isRestore}) =>
            unclaimed.add((sku, isRestore)),
      );
      // Attaches the stream listener — `catalogue()` is a real plugin round
      // trip, awaited before anything is bought, and the ONLY thing this test
      // needs from it: the store is not asked about a SKU until the listener
      // that would catch its answer is already up.
      await storeCatalogue();
      // Nothing called `buySku('sku_a', ...)` first — this is the app dying
      // mid-payment and the store redelivering on the next launch.
      platform.push([_purchase('sku_a', PurchaseStatus.purchased)]);
      await pumpEventQueue();

      expect(unclaimed, [('sku_a', false)]);
      // And still acknowledged, or Play refunds it after three days.
      expect(platform.completedIds, ['sku_a']);
    });

    test('restored with nobody waiting is unclaimed AS A RESTORE', () async {
      final unclaimed = <(String, bool)>[];
      wireNativeBilling(
        {'sku_a'},
        onUnclaimedPurchase: (sku, {required isRestore}) =>
            unclaimed.add((sku, isRestore)),
      );
      await storeCatalogue();
      platform.push([_purchase('sku_a', PurchaseStatus.restored)]);
      await pumpEventQueue();

      expect(unclaimed, [('sku_a', true)]);
    });

    test('a purchase somebody IS waiting on never reaches onUnclaimed', () async {
      final unclaimed = <(String, bool)>[];
      wireNativeBilling(
        {'sku_a'},
        onUnclaimedPurchase: (sku, {required isRestore}) =>
            unclaimed.add((sku, isRestore)),
      );
      platform.products = [_product('sku_a')];
      await storeCatalogue();
      final buying = buySku('sku_a', nonConsumable: false);
      await pumpEventQueue();
      platform.push([_purchase('sku_a', PurchaseStatus.purchased)]);

      final outcome = await buying;
      expect(outcome.ok, isTrue);
      expect(unclaimed, isEmpty);
    });
  });

  group('A PENDING PURCHASE DOES NOT HANG THE BUY FOREVER', () {
    test('settles the waiting caller instead of leaving it forever', () async {
      wireNativeBilling({'sku_a'});
      platform.products = [_product('sku_a')];
      await storeCatalogue();
      final buying = buySku('sku_a', nonConsumable: false);
      await pumpEventQueue();

      platform.push([
        _purchase('sku_a', PurchaseStatus.pending, pendingComplete: false),
      ]);

      final outcome = await buying.timeout(const Duration(seconds: 1));
      expect(outcome.ok, isFalse);
      expect(outcome.reason, PurchaseFailure.paymentFailed);
      // A pending purchase must never be completed — the plugin throws for it.
      expect(platform.completedIds, isEmpty);
    });

    test('and frees the slot, so a retry is not "already in flight"', () async {
      wireNativeBilling({'sku_a'});
      platform.products = [_product('sku_a')];
      await storeCatalogue();
      final first = buySku('sku_a', nonConsumable: false);
      await pumpEventQueue();
      platform.push([
        _purchase('sku_a', PurchaseStatus.pending, pendingComplete: false),
      ]);
      await first;

      final second = buySku('sku_a', nonConsumable: false);
      await pumpEventQueue();
      platform.push([_purchase('sku_a', PurchaseStatus.purchased)]);
      final outcome = await second;
      expect(outcome.reason, isNot(PurchaseFailure.alreadyInFlight));
    });

    test(
      'and its late resolution is not lost — it lands as unclaimed',
      () async {
        final unclaimed = <(String, bool)>[];
        wireNativeBilling(
          {'sku_a'},
          onUnclaimedPurchase: (sku, {required isRestore}) =>
              unclaimed.add((sku, isRestore)),
        );
        platform.products = [_product('sku_a')];
        await storeCatalogue();
        final buying = buySku('sku_a', nonConsumable: false);
        await pumpEventQueue();
        platform.push([
          _purchase('sku_a', PurchaseStatus.pending, pendingComplete: false),
        ]);
        await buying;

        // The store settles it for real, well after the app stopped waiting.
        platform.push([_purchase('sku_a', PurchaseStatus.purchased)]);
        await pumpEventQueue();

        expect(unclaimed, [('sku_a', false)]);
      },
    );
  });

  group('A RESTORE RETURNS AS SOON AS THE STORE ANSWERS', () {
    test('rather than always waiting out the fallback timeout', () async {
      wireNativeBilling({'sku_a'});
      // Deliver the moment `restorePurchases()` is called — a real plugin's
      // own restore call resolves before the stream does, which `restore()`
      // awaits first, so the push has to be scheduled rather than immediate.
      unawaited(
        Future<void>.delayed(Duration.zero).then((_) {
          platform.push([_purchase('sku_a', PurchaseStatus.restored)]);
        }),
      );
      final stopwatch = Stopwatch()..start();
      final restored = await restoreOwnedSkus();
      stopwatch.stop();

      expect(restored, {'sku_a'});
      // Well under the 4-second fallback — this is the fix: it used to always
      // pay the full delay because nothing ever completed `_restoreDone`.
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('and an account that owns nothing still falls back to the timeout', () async {
      wireNativeBilling({'sku_a'});
      final restored = await restoreOwnedSkus();
      expect(restored, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 10)));
  });
}
