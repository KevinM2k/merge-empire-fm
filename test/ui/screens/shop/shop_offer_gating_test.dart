/// A SKU the store cannot sell does not get a tile.
///
/// A product created in the console but not Active comes back with no
/// purchasable offer, and every `buy` then fails `no_offer` forever — so a tile
/// at the catalogue's fallback price is one that can never complete. That is
/// the state a partial store rollout leaves you in, because SKUs go live one at
/// a time.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/iap_billing_policy.dart';
import 'package:merge_empire_fc/services/iap_billing.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_screen.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

import 'shop_helpers.dart';

void main() {
  setUp(() {
    resetIapBillingSource();
    forgetStoreCatalogue();
  });

  tearDown(() {
    resetIapBillingSource();
    forgetStoreCatalogue();
  });

  test('NO STORE IS NOT AN EMPTY STORE', () async {
    // Empty means "it answered and knows none of our products", which hides
    // every tile. Null means "there is nobody to ask", which shows them all and
    // lets the simulate path handle the tap.
    expect(await storeCatalogue(), isNull);
    expect(billingReady, isFalse);
    expect(canOffer('anything', await storeCatalogue()), isTrue);
  });

  test('a store that will not answer is a store that is not there', () async {
    iapBillingSource = () async => throw StateError('plugin died');
    expect(await storeCatalogue(), isNull);
  });

  test('and it is asked ONCE, not per tile', () async {
    var asked = 0;
    iapBillingSource = () async {
      asked++;
      return <String, StoreProduct>{};
    };
    await storeCatalogue();
    await storeCatalogue();
    await storeCatalogue();
    expect(asked, 1);
  });

  test('a restore is the one thing that makes it ask again', () async {
    var asked = 0;
    iapBillingSource = () async {
      asked++;
      return <String, StoreProduct>{};
    };
    await storeCatalogue();
    forgetStoreCatalogue();
    await storeCatalogue();
    expect(asked, 2);
  });

  testWidgets('THE SHELF IS THERE WITH NO STORE, and a dead SKU is not', (
    tester,
  ) async {
    Future<void> pump() async {
      final container = shopContainer((_) {});
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              theme: ref.watch(appThemeProvider),
              home: const Scaffold(body: ShopScreen()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // No store at all: this is the state the build ships in, and the shelf has
    // to be on screen.
    await pump();
    expect(find.byKey(const ValueKey('shop-tile-vip_pass')), findsOneWidget);

    // A store that knows the SKU and has nothing purchasable for it: created in
    // the console, not Active. The tile goes, rather than rendering a price
    // that can never be paid.
    forgetStoreCatalogue();
    iapBillingSource = () async => {
      'com.mergeempirefc.vip_pass': (
        sku: 'com.mergeempirefc.vip_pass',
        hasOffer: false,
        localisedPrice: null,
      ),
    };
    await pump();
    expect(find.byKey(const ValueKey('shop-tile-vip_pass')), findsNothing);
  });
}
