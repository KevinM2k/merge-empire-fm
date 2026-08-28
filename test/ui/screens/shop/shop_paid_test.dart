/// The real-money shelves and the free shelf.
///
/// **They BUY now**, so the half of this file that asserted a dead shop has
/// been rewritten rather than deleted: what it was pinning — that a tile which
/// cannot complete still shows its price and says why — is still the rule, it
/// just applies to a narrower case.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/ad_gate_engine.dart';
import 'package:merge_empire_fc/engine/iap_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/services/iap_billing.dart';
import 'package:merge_empire_fc/services/iap_purchase.dart';
import 'package:merge_empire_fc/ui/screens/shop/coin_pack_art.dart';
import 'package:merge_empire_fc/ui/screens/shop/gem_pack_art.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_tiles.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/screens/shop/currency_sheet.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_copy.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_free.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_paid.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_spend.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/util/time.dart';

import 'shop_helpers.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';

void main() {
  tearDown(resetLocale);

  /// The row is the last thing on a long scrolling shop, so it has to be
  /// brought on screen before it can be tapped — a tap that misses reads as a
  /// restore that did nothing.
  Future<void> tapRestore(WidgetTester tester) async {
    final row = find.byKey(const ValueKey('shop-restore'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    await settleSave(tester);
  }

  Future<ProviderContainer> pumpPaid(WidgetTester tester) => pumpShopWidget(
    tester,
    (_) {},
    () => const Column(
      children: [
        OffersSection(),
        GemPacksSection(),
        CoinPacksSection(),
        RestoreRow(),
      ],
    ),
  );

  testWidgets('every paid tile is priced and BUYS', (tester) async {
    // It used to assert the opposite, and the reason was honest: there was no
    // bridge, so a live button would have taken a tap and done nothing. There
    // is one now — `services/iap_purchase.dart`.
    await pumpPaid(tester);
    final buttons = tester.widgetList<StoreButton>(find.byType(StoreButton));
    expect(buttons, isNotEmpty);
    for (final b in buttons) {
      expect(b.onTap, isNotNull);
    }
  });

  testWidgets('and says COMING SOON only where nothing can take a payment', (
    tester,
  ) async {
    // A test host is a debug build, which is the JS's own simulate path — the
    // one place a purchase may be granted without a store. Turn that off and
    // the shelf goes back to saying so rather than offering a button that
    // cannot complete.
    simulatePurchases = false;
    addTearDown(() => simulatePurchases = true);
    await pumpPaid(tester);
    expect(find.text(t('settings.comingSoon')), findsWidgets);
    for (final b in tester.widgetList<StoreButton>(find.byType(StoreButton))) {
      expect(b.onTap, isNotNull, reason: 'the tile still explains itself');
    }
  });

  testWidgets('the coin section lists the bundles at their real prices', (
    tester,
  ) async {
    await pumpPaid(tester);
    final coins = getShopProducts().where((p) => p.category == 'coins');
    expect(coins, isNotEmpty);
    for (final p in coins) {
      expect(find.text(p.price), findsWidgets, reason: p.id);
    }
  });

  testWidgets('offers carries the passes and bundles, not the currency', (
    tester,
  ) async {
    await pumpPaid(tester);
    for (final p in getShopProducts().where(
      (p) => p.category == 'bundle' || p.category == 'vip',
    )) {
      expect(find.text(productName(p)), findsWidgets, reason: p.id);
    }
  });

  testWidgets('THE OFFERS ARE ONE PER ROW, full width', (tester) async {
    // Three of them, and they are the shelf the shop opens on: two up made the
    // highest-converting slot in the game the same size as a consumable, with
    // the third alone in a half-width tile beside a gap.
    await pumpShopWidget(tester, (_) {}, () => const OffersSection());
    final offers = getShopProducts().where(
      (p) => p.category == 'bundle' || p.category == 'vip',
    );
    expect(offers.length, greaterThan(1));
    final widths = [
      for (final p in offers)
        tester
            .getSize(
              find.byKey(ValueKey('shop-tile-${p.id}'), skipOffstage: false),
            )
            .width,
    ];
    final shelf = tester.getSize(find.byType(OffersSection)).width;
    for (final width in widths) {
      expect(
        width,
        closeTo(widths.first, 1),
        reason: 'the offers are not the same width',
      );
      expect(
        width,
        greaterThan(shelf * 0.8),
        reason: 'an offer is sharing its row',
      );
    }
  });

  /// **AND THE POPULAR ONE WEARS A CORNER FLASH.** `.shop-hero__ribbon` in the
  /// stylesheet, which the port had never drawn: "MOST POPULAR" was a line of
  /// ordinary grey text in the middle of the card, on the shelf the shop opens
  /// on. Asked for by name from the couch.
  testWidgets('THE POPULAR OFFER WEARS A CORNER BANNER, not a grey line', (
    tester,
  ) async {
    await pumpShopWidget(tester, (_) {}, () => const OffersSection());
    final banner = find.byType(CornerBanner);
    expect(banner, findsOneWidget);
    expect(
      find.descendant(of: banner, matching: find.text(t('shop.most_popular'))),
      findsOneWidget,
    );
    // Diagonal, and in the TOP-RIGHT corner of the tile it belongs to.
    final popular = getShopProducts().firstWhere(
      (p) => p.popular && (p.category == 'bundle' || p.category == 'vip'),
    );
    final tile = tester.getRect(
      find.byKey(ValueKey('shop-tile-${popular.id}'), skipOffstage: false),
    );
    final flash = tester.getRect(banner);
    expect(flash.right, closeTo(tile.right, 1));
    expect(flash.top, closeTo(tile.top, 1));
    expect(
      tester.widget<Transform>(
        find.descendant(of: banner, matching: find.byType(Transform)),
      ),
      isNotNull,
    );
  });

  /// **AND THE HERO USES THE ROOM IT HAS.** One row of art, words and price
  /// fitted the shelf into three short bands with most of the page empty under
  /// them — the highest-converting slot in the game was the smallest thing on
  /// the screen. Reported from the couch.
  testWidgets('an offer is taller than a consumable, not the same height', (
    tester,
  ) async {
    await pumpShopWidget(tester, (_) {}, () => const OffersSection());
    final offers = getShopProducts().where(
      (p) => p.category == 'bundle' || p.category == 'vip',
    );
    for (final offer in offers) {
      final tile = tester.getSize(
        find.byKey(ValueKey('shop-tile-${offer.id}'), skipOffstage: false),
      );
      expect(tile.height, greaterThan(110), reason: offer.id);
      // And the price is on its own line at the bottom rather than parked in
      // the corner the flash needs.
      final button = tester.getRect(
        find.byKey(ValueKey('shop-buy-${offer.id}'), skipOffstage: false),
      );
      final rect = tester.getRect(
        find.byKey(ValueKey('shop-tile-${offer.id}'), skipOffstage: false),
      );
      expect(
        button.center.dy,
        greaterThan(rect.center.dy),
        reason: '${offer.id}: the price is still in the top half',
      );
    }
  });

  testWidgets('Restore Purchases is present and RUNS', (tester) async {
    await pumpPaid(tester);
    expect(find.text(t('shop.restore_purchases')), findsOneWidget);
    expect(
      tester.widget<InkWell>(find.byKey(const ValueKey('shop-restore'))).onTap,
      isNotNull,
    );
  });

  testWidgets('a restore with nothing to restore says so and grants nothing', (
    tester,
  ) async {
    // Nothing owned and nothing reachable read the same from here, which is
    // the JS's own conflation: neither is a failure the player can act on.
    final container = await pumpPaid(tester);
    final before = jsonEncode(container.read(gameProvider).state);
    await tapRestore(tester);
    expect(jsonEncode(container.read(gameProvider).state), before);
  });

  testWidgets('A RESTORE RE-GRANTS ONLY WHAT THE SAVE DOES NOT OWN', (
    tester,
  ) async {
    // And only non-consumables: a coin pack is consumed the moment it is
    // granted and the store lists it forever, so re-granting one would be a
    // free coin button.
    final vault = getProduct('style_vault')!;
    final coins = getShopProducts().firstWhere((p) => p.category == 'coins');
    iapRestoreSource = () async => {vault.sku, coins.sku};
    addTearDown(resetIapBillingSource);

    final container = await pumpPaid(tester);
    final coinsBefore = container.read(coinsProvider);
    await tapRestore(tester);

    final shop =
        container.read(gameProvider).state!['shop'] as Map<String, dynamic>;
    expect(shop['purchasedIds'], contains(vault.id));
    expect(
      container.read(coinsProvider),
      coinsBefore,
      reason: 'a consumable must not come back',
    );

    // Twice is not two grants.
    await tapRestore(tester);
    expect(
      (shop['purchasedIds'] as List).where((id) => id == vault.id),
      hasLength(1),
    );
  });

  group('what a tile says', () {
    testWidgets('the CATALOGUE names the product, not the definition', (
      tester,
    ) async {
      // `IapProduct.name` is the English literal on the record and the shop had
      // been rendering it straight — so the whole shelf was untranslatable, and
      // wrong even in English.
      await pumpPaid(tester);
      final small = getProduct('coins_small')!;
      expect(productName(small), isNot(small.name));
      expect(find.text(productName(small)), findsOneWidget);
      expect(
        find.text(small.name),
        findsNothing,
        reason: 'the definition is the FALLBACK',
      );
    });

    testWidgets('and no placeholder ever reaches the player', (tester) async {
      // Every coin bundle's description is literally '{coins} coins' and every
      // gem bundle's is '{gems} gems'.
      await pumpPaid(tester);
      expect(find.textContaining('{coins}'), findsNothing);
      expect(find.textContaining('{gems}'), findsNothing);
    });

    testWidgets('a bundle says what THIS division would pay', (tester) async {
      // Not the base on the product: a bundle's coins scale with division, and
      // at Champions Cup the same £0.99 pays a thousand times more.
      await pumpShopWidget(
        tester,
        (s) => (s['progression'] as Map<String, dynamic>)['currentDivision'] =
            'regional_league',
        CoinPacksSection.new,
      );
      final small = getProduct('coins_small')!;
      expect(
        find.textContaining(formatCoins(small.coins! * 10)),
        findsWidgets,
        reason: 'ten times, at the regional league',
      );
      expect(
        find.textContaining(t('shop.division_mult', {'mult': 10})),
        findsWidgets,
      );
    });
  });

  group('the gem shelf', () {
    testWidgets('EACH PACK GETS ITS OWN PICTURE, not one gem three times', (
      tester,
    ) async {
      // Every bundle on the shelf wore the same 34px `GameIcon('gem')`, so
      // Pocket of Gems, Casket of Gems and Hoard of Gems were three prices
      // under three identical images — the tile said nothing at all about
      // which of them was the big one. The names are the brief, the same way
      // they were for the coin packs on the shelf beside it.
      await pumpShopWidget(tester, (_) {}, GemPacksSection.new);
      final drawn = tester
          .widgetList<GemPackPicture>(find.byType(GemPackPicture))
          .map((g) => g.art)
          .toList();
      expect(drawn, [GemPackArt.pocket, GemPackArt.casket, GemPackArt.hoard]);
      // And no two of them are the same drawing.
      expect(drawn.toSet(), hasLength(drawn.length));
    });

    test('every gem product in the catalogue has a picture of its own', () {
      // A pack added to the catalogue ahead of its art would silently fall back
      // to the pocket, which is the one-icon-for-everything bug coming back.
      final ids = getShopProducts()
          .where((p) => p.category == 'gems')
          .map((p) => p.id)
          .toList();
      expect(ids, isNotEmpty);
      expect(
        ids.map(gemPackArtFor).toSet(),
        hasLength(ids.length),
        reason: 'two gem packs share a picture: $ids',
      );
    });
  });

  group('the coin shelf', () {
    testWidgets('each bundle gets a PICTURE of what it is called', (
      tester,
    ) async {
      // All four share one 💰 in the catalogue, and the JS tells them apart with
      // a cluster of 1/2/3/5 coins — which is a quantity and makes no sense of
      // "Coin Vault".
      await pumpShopWidget(tester, (_) {}, CoinPacksSection.new);
      final drawn = tester
          .widgetList<CoinPackPicture>(find.byType(CoinPackPicture))
          .map((c) => c.art)
          .toList();
      expect(drawn, [
        CoinPackArt.pocket,
        CoinPackArt.pile,
        CoinPackArt.vault,
        CoinPackArt.mountain,
      ]);
    });

    testWidgets('and every other shelf gets the app\'s own line art', (
      tester,
    ) async {
      // `ShopTile` has had a `glyph` since it was written and nothing ever
      // passed one, so every shelf was text with a price under it. Not the
      // catalogue's emoji either — that one is for the toast, which renders it
      // as text.
      await pumpPaid(tester);
      final onShelf = getShopProducts().where(
        (p) => const {'bundle', 'vip', 'gems', 'coins'}.contains(p.category),
      );
      for (final product in onShelf) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('shop-tile-${product.id}')),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is GameIcon || w is CoinPackPicture || w is GemPackPicture,
            ),
          ),
          findsWidgets,
          reason: product.id,
        );
        expect(find.text(product.icon), findsNothing, reason: product.id);
      }
    });

    testWidgets('the popular one is crowned and tagged', (tester) async {
      await pumpShopWidget(tester, (_) {}, CoinPacksSection.new);
      expect(find.text('👑'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('shop-badge-coins_medium')),
        findsOneWidget,
      );
      expect(find.text(t('shop.most_popular')), findsOneWidget);
    });

    testWidgets('the value badge is COMPUTED, and the vault wears none', (
      tester,
    ) async {
      // Hand-typed percentages were wrong by two to three times, which is why
      // `getCoinBundleValuePct` exists.
      await pumpShopWidget(tester, (_) {}, CoinPacksSection.new);
      final mega = getProduct('coins_mega')!;
      expect(
        find.byKey(const ValueKey('shop-badge-coins_large')),
        findsNothing,
        reason: 'the JS gives the vault no badge at all',
      );
      // The mega tier's own tag wins over the computed figure.
      expect(find.text(productBonus(mega)!), findsOneWidget);
      expect(
        find.text(
          t('shop.coin_value_badge', {
            'pct': getCoinBundleValuePct(getProduct('coins_small')!),
          }),
        ),
        findsNothing,
        reason:
            'the cheapest bundle is the baseline, so it improves on nothing',
      );
    });
  });

  group('the currency sheet', () {
    // Its own pump: the sheet fills the height it is given (a
    // `FractionallySizedBox` in `showBottomSheetPopup`), which the shared
    // harness's scroll view cannot provide.
    Future<void> pumpSheet(WidgetTester tester, ShopSection which) =>
        pumpShopWidget(
          tester,
          (_) {},
          () => SizedBox(height: 600, child: CurrencySheet(which: which)),
          scroll: false,
        );

    testWidgets('sells the same shelf the tab does', (tester) async {
      // One shelf, one implementation. Two would be the thing that drifts.
      await pumpSheet(tester, ShopSection.coins);
      for (final p in getShopProducts().where((p) => p.category == 'coins')) {
        expect(find.text(p.price), findsOneWidget, reason: p.id);
      }
      expect(find.text(t('shop.section.coins').toUpperCase()), findsOneWidget);
    });

    testWidgets('and the gem sheet sells gems, not coins', (tester) async {
      await pumpSheet(tester, ShopSection.gems);
      expect(find.text(productName(getProduct('gems_5')!)), findsOneWidget);
      expect(find.text(productName(getProduct('coins_small')!)), findsNothing);
    });
  });

  test('no paid section calls the grant step', () {
    // purchaseProduct runs AFTER a store confirms a payment. A button wired to
    // it would hand out paid goods for free.
    for (final path in [
      'lib/ui/screens/shop/shop_paid.dart',
      'lib/ui/screens/shop/shop_copy.dart',
      'lib/ui/screens/shop/coin_cluster.dart',
      'lib/ui/screens/shop/currency_sheet.dart',
      'lib/ui/screens/shop/shop_free.dart',
      'lib/ui/screens/shop/shop_looks.dart',
      'lib/ui/screens/shop/shop_screen.dart',
    ]) {
      final file = File(path);
      if (!file.existsSync()) continue;
      // Comments stripped first: these files NAME the grant step in order to
      // explain why they do not call it, and that explanation should not be
      // the thing that fails the check.
      final code = file
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(code.contains('purchaseProduct'), isFalse, reason: path);
    }
  });

  group('the free shelf', () {
    testWidgets('shows both rows, AND THEY CAN BE WATCHED NOW', (tester) async {
      // **This assertion has been inverted, and the inversion is the news.** It
      // used to say every button on the shelf was dead, because there was no
      // AdMob behind it; `services/admob_ads.dart` is that AdMob, so the two
      // tiles pay out again. What decides whether one is live is the GATE and
      // the cap, which is what the rest of this group covers.
      await pumpShopWidget(tester, (_) {}, FreeShelfSection.new);
      expect(find.text(t('shop.lucky_boot_ad_name')), findsOneWidget);
      expect(find.text(t('shop.match_cooldown_ad_name')), findsOneWidget);
      for (final b in tester.widgetList<StoreButton>(
        find.byType(StoreButton),
      )) {
        expect(b.onTap, isNotNull);
      }
    });

    testWidgets('a spent daily cap reads as a cap, not as ready', (
      tester,
    ) async {
      // The gate is real even though the button is not.
      await pumpShopWidget(tester, (s) {
        for (var i = 0; i < 20; i++) {
          recordPackAd(s);
        }
      }, FreeShelfSection.new);
      expect(find.text(t('shop.daily_cap')), findsWidgets);
    });
  });
  testWidgets('THE THREE OFFERS LOOK LIKE OFFERS', (tester) async {
    // They were made full width a pass ago — the shelf the shop opens on — and
    // width alone did not do it: they still drew the same grey pane as a
    // consumable. A gold rim, a gold wash off the top edge, and the glyph and
    // title up with them.
    await pumpShopWidget(tester, (_) {}, OffersSection.new);
    final tiles = tester.widgetList<ShopTile>(find.byType(ShopTile));
    expect(tiles, isNotEmpty);
    for (final tile in tiles) {
      expect(tile.featured, isTrue, reason: tile.tileKey);
    }
  });

  testWidgets('and the shelves behind them do not', (tester) async {
    // Featured is the offers shelf and only that one; a shop where everything
    // is special has nothing special in it.
    await pumpShopWidget(tester, (_) {}, GemPacksSection.new);
    for (final tile in tester.widgetList<ShopTile>(find.byType(ShopTile))) {
      expect(tile.featured, isFalse, reason: tile.tileKey);
    }
  });


  group('EVERY REAL-MONEY TAP GOES THROUGH THE CONFIRM', () {
    // The JS's own comment on the line that binds these tiles, and it names the
    // two that used to charge straight off themselves: the gem bundles and the
    // Style Vault. On a two-across grid a mis-tap was a completed purchase with
    // no interstitial.
    testWidgets('a gem bundle asks before it charges', (tester) async {
      await pumpPaid(tester);
      final gems = getShopProducts().firstWhere((p) => p.category == 'gems');
      final tile = find.byKey(ValueKey('shop-tile-${gems.id}'));
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('paid-confirm-${gems.id}')), findsOneWidget);
      // And the disclaimer, which is shipped copy this card is the only caller
      // of.
      expect(find.textContaining('will be charged'), findsOneWidget);
    });

    testWidgets('and cancelling grants nothing', (tester) async {
      final container = await pumpPaid(tester);
      final gems = getShopProducts().firstWhere((p) => p.category == 'gems');
      final before = jsonEncode(container.read(gameProvider).state);
      final tile = find.byKey(ValueKey('shop-tile-${gems.id}'));
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('paid-cancel-${gems.id}')));
      await tester.pumpAndSettle();
      expect(jsonEncode(container.read(gameProvider).state), before);
    });

    testWidgets('an offer tile asks too', (tester) async {
      await pumpPaid(tester);
      final offer = getShopProducts().firstWhere((p) => p.category == 'bundle');
      final buy = find.byKey(ValueKey('shop-buy-${offer.id}'));
      await tester.ensureVisible(buy);
      await tester.pumpAndSettle();
      await tester.tap(buy);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('paid-confirm-${offer.id}')), findsOneWidget);
    });
  });

  group('a tile you already own', () {
    testWidgets('SAYS SO INSTEAD OF ASKING FOR THE MONEY AGAIN', (tester) async {
      // The purchase would get as far as `initiatePurchase` and be refused
      // `already_purchased` — a dead end reached by pressing the thing the shop
      // was pointing at.
      await pumpShopWidget(
        tester,
        (s) => (s['shop'] as Map<String, dynamic>)['purchasedIds'] = [
          'starter_pack',
        ],
        () => const Column(children: [OffersSection()]),
      );
      expect(find.text(t('shop.owned_check')), findsWidgets);
      expect(find.text(t('shop.owned_regranted')), findsWidgets);
      final button = tester.widget<StoreButton>(
        find.byKey(const ValueKey('shop-buy-starter_pack')),
      );
      expect(button.onTap, isNull);
    });

    testWidgets('and a running VIP counts down rather than selling', (
      tester,
    ) async {
      await pumpShopWidget(
        tester,
        (s) => (s['shop'] as Map<String, dynamic>)['vipExpiresAt'] =
            now() + const Duration(days: 9).inMilliseconds,
        () => const Column(children: [OffersSection()]),
      );
      expect(find.text(t('shop.vip.active_btn')), findsWidgets);
      expect(find.text(t('shop.vip.active', {'days': 9})), findsWidgets);
      expect(
        tester
            .widget<StoreButton>(find.byKey(const ValueKey('shop-buy-vip_pass')))
            .onTap,
        isNull,
      );
    });

    testWidgets('A LAPSED VIP IS ASKED BACK', (tester) async {
      // The one state worth its own ribbon: they have paid before.
      await pumpShopWidget(
        tester,
        (s) => (s['shop'] as Map<String, dynamic>)['vipExpiresAt'] = 1,
        () => const Column(children: [OffersSection()]),
      );
      expect(find.text(t('shop.vip.reactivate_ribbon')), findsWidgets);
      expect(find.text(t('shop.vip.lapsed_note')), findsWidgets);
      expect(
        tester
            .widget<StoreButton>(find.byKey(const ValueKey('shop-buy-vip_pass')))
            .onTap,
        isNotNull,
        reason: 'a lapsed pass is buyable again',
      );
    });
  });

  group('EVERY TILE HAS AN EDGE, so a shelf reads on any backdrop', () {
    // Asked for twice from the couch — the coin packs, then "in fact all of
    // these boosts & items". Both already had one; what they did not have was
    // anything stopping the next pass taking it away, which on the turf and
    // humbug backgrounds is a shelf of floating text.
    Border edgeOf(WidgetTester tester, Key key) =>
        ((tester.widget<Container>(find.byKey(key, skipOffstage: false)).decoration!
                as BoxDecoration)
            .border! as Border);

    testWidgets('a coin pack, and the popular one wears a different one', (
      tester,
    ) async {
      await pumpShopWidget(tester, (_) {}, CoinPacksSection.new);
      final packs = getShopProducts()
          .where((p) => p.category == 'coins')
          .toList();
      expect(packs, isNotEmpty);
      final popular = packs.where((p) => p.popular).toList();
      expect(popular, hasLength(1), reason: 'one shelf, one flagship');
      final flagship = edgeOf(
        tester,
        ValueKey('shop-tile-${popular.single.id}'),
      );
      for (final pack in packs.where((p) => !p.popular)) {
        final edge = edgeOf(tester, ValueKey('shop-tile-${pack.id}'));
        expect(edge.top.width, greaterThan(0), reason: pack.id);
        expect(
          edge.top.color,
          isNot(flagship.top.color),
          reason: '${pack.id} is edged like the flagship',
        );
      }
    });

    testWidgets('and every boost and item on the shelf below', (tester) async {
      await pumpShopWidget(tester, (_) {}, BoostsSection.new);
      final tiles = tester.widgetList<ShopTile>(find.byType(ShopTile));
      expect(tiles, isNotEmpty);
      for (final tile in tiles) {
        final edge = edgeOf(tester, ValueKey('shop-tile-${tile.tileKey}'));
        expect(edge.top.width, greaterThan(0), reason: tile.tileKey);
      }
    });
  });
}
