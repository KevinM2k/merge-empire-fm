/// The real-money shelves and the free shelf. Nothing here can be bought yet.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/ad_gate_engine.dart';
import 'package:merge_empire_fc/engine/iap_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/shop/coin_pack_art.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/screens/shop/currency_sheet.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_copy.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_free.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_paid.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/util/format.dart';

import 'shop_helpers.dart';

void main() {
  tearDown(resetLocale);

  Future<void> pumpPaid(WidgetTester tester) => pumpShopWidget(
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

  testWidgets('every paid tile is priced and dead', (tester) async {
    await pumpPaid(tester);
    final buttons = tester.widgetList<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(buttons, isNotEmpty);
    for (final b in buttons) {
      expect(b.onPressed, isNull);
    }
    expect(find.text(t('settings.comingSoon')), findsWidgets);
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

  testWidgets('Restore Purchases is present and disabled', (tester) async {
    await pumpPaid(tester);
    expect(find.text(t('shop.restore_purchases')), findsOneWidget);
    expect(
      tester.widget<InkWell>(find.byKey(const ValueKey('shop-restore'))).onTap,
      isNull,
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
              (w) => w is GameIcon || w is CoinPackPicture,
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
    testWidgets('shows both rows and cannot be watched yet', (tester) async {
      await pumpShopWidget(tester, (_) {}, FreeShelfSection.new);
      expect(find.text(t('shop.lucky_boot_ad_name')), findsOneWidget);
      expect(find.text(t('shop.match_cooldown_ad_name')), findsOneWidget);
      for (final b in tester.widgetList<ElevatedButton>(
        find.byType(ElevatedButton),
      )) {
        expect(b.onPressed, isNull);
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
}
