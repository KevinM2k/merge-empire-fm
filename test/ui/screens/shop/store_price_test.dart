/// **A PLAYER IN ITALY WAS BEING SHOWN POUNDS**, on the Special Offers shelf.
///
/// The catalogue's own `price` is a fallback in ONE currency — sterling — and
/// `priceFor` exists so that the store's answer wins wherever there is one. The
/// tiles all called it. What did not hold was the thing they called it WITH:
/// `storeCatalogue` handed a null answer to anybody who asked while the first
/// query was still out, and pinned a failed first query for the whole process.
/// `storeCatalogueProvider` is a `FutureProvider`, so whatever it resolved to
/// the first time was the price every real-money tile printed until the app was
/// killed.
///
/// Two strings carried sterling in the COPY as well, which no amount of asking
/// the store could have fixed: the coins-per-pound badge and the parental
/// consent notice. Both are here too.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/iap_billing_policy.dart';
import 'package:merge_empire_fc/engine/iap_engine.dart';
import 'package:merge_empire_fc/i18n/catalogs.g.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/services/iap_billing.dart';
import 'package:merge_empire_fc/ui/popups/age_gate_sheet.dart';
import 'package:merge_empire_fc/ui/screens/shop/currency_sheet.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_looks.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_paid.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_screen.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart' show ShopSection;
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

import 'shop_helpers.dart';

/// Every real-money SKU, priced the way a Play console in Italy would price it.
Map<String, StoreProduct> _italianStore() => {
  for (final product in products)
    product.sku: (
      sku: product.sku,
      hasOffer: true,
      localisedPrice: '€${product.priceValue.toStringAsFixed(2)}',
    ),
};

void main() {
  setUp(() {
    resetIapBillingSource();
    forgetStoreCatalogue();
  });

  tearDown(() {
    resetIapBillingSource();
    forgetStoreCatalogue();
    resetLocale();
  });

  test('TWO CALLERS SHARE ONE QUERY, and both get the answer', () async {
    // The bug, at its smallest. `game_host` warms the catalogue at boot and the
    // shop asks for it again when a shelf is built; the guard used to be a
    // bool set BEFORE the await, so the second caller was told "already asked"
    // and handed a `_cached` that was still null.
    var asked = 0;
    final gate = Completer<Map<String, StoreProduct>>();
    iapBillingSource = () async {
      asked++;
      return gate.future;
    };

    final first = storeCatalogue();
    final second = storeCatalogue();
    gate.complete(_italianStore());

    expect(await first, isNotNull);
    expect(
      await second,
      isNotNull,
      reason: 'the second caller was handed the not-yet-filled cache',
    );
    expect(asked, 1, reason: 'and it must still be ONE round trip');
  });

  test('a query that failed is asked again; one that answered is not', () async {
    var asked = 0;
    iapBillingSource = () async {
      asked++;
      throw StateError('billing is not up yet');
    };
    expect(await storeCatalogue(), isNull);
    expect(await storeCatalogue(), isNull);
    expect(asked, 2, reason: 'a failure must not be cached for the process');

    iapBillingSource = () async {
      asked++;
      return _italianStore();
    };
    expect(await storeCatalogue(), isNotNull);
    expect(await storeCatalogue(), isNotNull);
    expect(asked, 3, reason: 'and a real answer must be cached');
  });

  test('an EMPTY answer is a real answer and is kept', () async {
    // The store spoke and knows none of our SKUs. That hides every tile, and it
    // must not be re-asked as though nobody had answered.
    var asked = 0;
    iapBillingSource = () async {
      asked++;
      return <String, StoreProduct>{};
    };
    expect(await storeCatalogue(), isEmpty);
    expect(await storeCatalogue(), isEmpty);
    expect(asked, 1);
  });

  testWidgets('THE OFFERS SHELF PRICES IN EUROS when the store does', (
    tester,
  ) async {
    iapBillingSource = () async => _italianStore();

    final container = shopContainer((_) {});
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: ref.watch(appThemeProvider),
            home: const Scaffold(
              body: SingleChildScrollView(child: OffersSection()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The three Special Offers tiles, and not a pound sign among them.
    expect(find.textContaining('£'), findsNothing);
    expect(find.textContaining('€1.99'), findsWidgets);
  });

  testWidgets('AND A SHOP OPENED BEFORE THE STORE ANSWERED ASKS AGAIN', (
    tester,
  ) async {
    // The second half of the report. `storeCatalogueProvider` keeps what it
    // first resolved to, so a boot where Play was not up yet used to leave
    // every real-money tile on the catalogue's sterling fallback for the life
    // of the app. The shop asks again itself when it opens with nothing on
    // file — see `ShopScreenState.initState`.
    var up = false;
    var asked = 0;
    iapBillingSource = () async {
      asked++;
      return up ? _italianStore() : null;
    };

    final container = shopContainer((_) {});
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
    expect(find.textContaining('£'), findsWidgets);
    expect(asked, greaterThanOrEqualTo(1));

    // Play comes up. The shop is still open, and the next thing that rebuilds
    // it is enough — the re-ask runs off the frame after `initState`, so a
    // fresh mount of the screen is what a player does when they come back to
    // the tab.
    up = true;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
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
    expect(find.textContaining('£'), findsNothing);
    expect(find.textContaining('€'), findsWidgets);
  });

  testWidgets('EVERY REAL-MONEY SHELF PRICES IN EUROS, not just offers', (
    tester,
  ) async {
    // "ALL costs in GBP" was the report, and the offers shelf was only where
    // they happened to be looking. Each of these draws its own tile — the
    // three heroes, `GemPackTile`, `CoinPackTile` and the Looks vault — and
    // `GemPackTile` is the one that had been rendering `IapProduct.price`
    // directly rather than resolving it, so "they all go through `priceFor`"
    // is a claim worth checking rather than asserting.
    iapBillingSource = () async => _italianStore();

    for (final shelf in <(String, Widget)>[
      ('offers', const OffersSection()),
      ('gems', const GemPacksSection()),
      ('coins', const CoinPacksSection()),
      ('looks', const LooksSection()),
      ('hud coin sheet', const CurrencySheet(which: ShopSection.coins)),
      ('hud gem sheet', const CurrencySheet(which: ShopSection.gems)),
    ]) {
      forgetStoreCatalogue();
      final container = shopContainer((_) {});
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              theme: ref.watch(appThemeProvider),
              home: Scaffold(
                body: SingleChildScrollView(child: shelf.$2),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('£'),
        findsNothing,
        reason: '${shelf.$1} is still priced in pounds',
      );
      expect(
        find.textContaining('€'),
        findsWidgets,
        reason: '${shelf.$1} shows no price at all',
      );
    }
  });

  testWidgets('AND THE HUD SHEET RECOVERS TOO, not only the Shop tab', (
    tester,
  ) async {
    // **The hole the first fix left.** The re-ask went into
    // `ShopScreenState.initState` alone, and the HUD's coin and gem chips open
    // `CurrencySheet` directly — so the commonest route to the packs never
    // built the tab, never re-asked, and went on printing sterling. Both
    // surfaces call `askStoreAgainIfItNeverAnswered` now.
    var up = false;
    iapBillingSource = () async => up ? _italianStore() : null;

    final container = shopContainer((_) {});
    Future<void> pump() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              theme: ref.watch(appThemeProvider),
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: CurrencySheet(which: ShopSection.coins),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump();
    expect(find.textContaining('£'), findsWidgets);

    up = true;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pump();
    expect(
      find.textContaining('£'),
      findsNothing,
      reason: 'the sheet the HUD opens never asked the store again',
    );
    expect(find.textContaining('€'), findsWidgets);
  });

  test('A RESTORE DROPS AN ANSWER THAT WAS ALREADY OUT', () async {
    // `restorePurchases` forgets the catalogue the moment the store answers it,
    // because a SKU bought on another device is now this build's to sell
    // against. A query started BEFORE that is still in flight, and it used to
    // write its pre-restore answer into the cache when it resolved — so the
    // forgetting was undone by the thing it was racing.
    final gate = Completer<Map<String, StoreProduct>>();
    iapBillingSource = () async => gate.future;
    final pending = storeCatalogue();

    forgetStoreCatalogue();
    gate.complete(_italianStore());
    await pending;

    expect(
      billingReady,
      isFalse,
      reason: 'the superseded answer was cached over the forgetting',
    );

    // And the next ask is a real one, against whatever the store says now.
    iapBillingSource = () async => <String, StoreProduct>{};
    expect(await storeCatalogue(), isEmpty);
  });

  testWidgets('THE CONSENT NOTICE QUOTES THE STORE, not sterling', (
    tester,
  ) async {
    iapBillingSource = () async => _italianStore();

    await pumpShopWidget(tester, (_) {}, () => const AgeGateHarness());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final range = coinBundlePriceRange();
    expect(
      find.textContaining(
        '€${range.cheapest.priceValue.toStringAsFixed(2)}',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('€${range.dearest.priceValue.toStringAsFixed(2)}'),
      findsOneWidget,
    );
    expect(find.textContaining('£'), findsNothing);
  });

  testWidgets('AND THE CONFIRM CARD, which is the last thing before paying', (
    tester,
  ) async {
    // Every tile hands its own resolved price to `confirmRealMoneyPurchase`,
    // which is a parameter rather than another lookup — so the card is only as
    // right as its caller, and it is the screen a player reads with their
    // thumb over the button. Nothing checked it.
    iapBillingSource = () async => _italianStore();

    final container = shopContainer((_) {});
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: ref.watch(appThemeProvider),
            home: const Scaffold(
              body: SingleChildScrollView(child: OffersSection()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final starter = getProduct('starter_pack')!;
    await tester.tap(find.byKey(ValueKey('shop-buy-${starter.id}')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('paid-confirm-${starter.id}')),
      findsOneWidget,
      reason: 'the confirm card did not open, so nothing was checked',
    );
    expect(
      find.textContaining('€${starter.priceValue.toStringAsFixed(2)}'),
      findsWidgets,
      reason: 'the card quotes a price the store did not give it',
    );
    expect(find.textContaining('£'), findsNothing);
  });

  test('no shipped string writes a currency symbol of its own', () {
    // The tiles ask the store. A string cannot, so a currency symbol written
    // into the copy is sterling in Japan for ever — which is exactly what
    // `shop.coin_value_badge` and `agegate.purchases_body` were.
    final offenders = <String>[];
    for (final id in catalogs.keys) {
      catalogFor(id).forEach((key, value) {
        if (RegExp(r'[£$¥]').hasMatch(value)) offenders.add('$id: $key');
      });
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'a price belongs to the store, not to the catalogue:\n'
          '${offenders.join('\n')}',
    );
  });
}

/// The sheet's body on its own — `showAgeGateSheet` needs a navigator and a
/// route, and what is under test is the sentence.
class AgeGateHarness extends StatelessWidget {
  const AgeGateHarness({super.key});

  @override
  Widget build(BuildContext context) => Builder(
    builder: (context) => TextButton(
      onPressed: () => showAgeGateSheet(context),
      child: const Text('open'),
    ),
  );
}
