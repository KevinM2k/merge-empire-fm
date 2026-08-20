/// The shared section frame and tile.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_section.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_tiles.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';

/// A tile is a GRID CELL — its button is pushed to the bottom so every button
/// in a row lines up — so it needs a bounded height, the way the grid gives it
/// one. Pumped into an unbounded scroller it has nothing to push against.
Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: buildAppTheme(kitId: '#4caf50', light: false),
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(height: 220, child: child)),
    ),
  ),
);

void main() {
  tearDown(resetLocale);

  test('the section order is the one the JS ships', () {
    // Offers first (the highest-converting slot), then the free shelf (why a
    // non-payer opens the shop at all), then hard currency before soft, then
    // what those currencies buy, then cosmetics.
    expect(shopSectionOrder, [
      ShopSectionId.offers,
      ShopSectionId.free,
      ShopSectionId.gems,
      ShopSectionId.coins,
      ShopSectionId.boosts,
      ShopSectionId.vouchers,
      ShopSectionId.looks,
    ]);
  });

  test('every section names a key that exists', () {
    for (final id in shopSectionOrder) {
      expect(t(id.titleKey), isNot(id.titleKey), reason: id.name);
    }
  });

  testWidgets('the frame shows its heading and its child', (tester) async {
    await pump(
      tester,
      const ShopSectionFrame(id: ShopSectionId.coins, child: Text('inner')),
    );
    // Uppercased, the way the JS sets every shelf heading.
    expect(find.text(t('shop.section.coins').toUpperCase()), findsOneWidget);
    expect(find.text('inner'), findsOneWidget);
  });

  testWidgets('a section note is rendered once, above the child', (
    tester,
  ) async {
    await pump(
      tester,
      ShopSectionFrame(
        id: ShopSectionId.vouchers,
        note: t('shop.voucher.one_at_a_time'),
        child: const Text('inner'),
      ),
    );
    expect(find.text(t('shop.voucher.one_at_a_time')), findsOneWidget);
  });

  testWidgets('a buyable tile shows its price and calls back', (tester) async {
    var bought = 0;
    await pump(
      tester,
      ShopTile(
        tileKey: 'thing',
        title: 'Thing',
        price: '1,000',
        tone: StoreTone.coin,
        onBuy: () => bought++,
      ),
    );
    expect(find.text('1,000'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shop-buy-thing')));
    await tester.pump();
    expect(bought, 1);
  });

  testWidgets('a disabled tile keeps its price and states the reason', (
    tester,
  ) async {
    await pump(
      tester,
      ShopTile(
        tileKey: 'thing',
        title: 'Thing',
        price: '£4.99',
        tone: StoreTone.cash,
        disabledReason: t('settings.comingSoon'),
      ),
    );
    expect(find.text('£4.99'), findsOneWidget);
    expect(find.text(t('settings.comingSoon')), findsOneWidget);
    expect(
      tester
          .widget<StoreButton>(find.byKey(const ValueKey('shop-buy-thing')))
          .onTap,
      isNull,
    );
  });

  testWidgets('and the button is coloured for what it COSTS', (tester) async {
    // The colour answers "what does this cost me?" — green real money, blue
    // gems, gold coins, yellow an ad. Before this every one of them was the kit
    // accent, so a shelf of coin, gem and cash packs was one green wall.
    for (final (tone, expected) in [
      (StoreTone.cash, const Color(0xFF43A047)),
      (StoreTone.gem, const Color(0xFF1E88C7)),
      (StoreTone.coin, const Color(0xFFD8A01A)),
      (StoreTone.ad, const Color(0xFFFFD54A)),
    ]) {
      await pump(
        tester,
        ShopTile(
          tileKey: 'thing',
          title: 'Thing',
          price: '1,000',
          tone: tone,
          onBuy: () {},
        ),
      );
      final box = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const ValueKey('shop-buy-thing')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(
        (box.decoration! as BoxDecoration).color,
        expected,
        reason: '$tone',
      );
    }
  });

  testWidgets('a rewarded-video button discloses that it is an ad', (
    tester,
  ) async {
    // The label is a verb ("Claim"), so the disclosure has to come from
    // somewhere.
    await pump(
      tester,
      ShopTile(
        tileKey: 'thing',
        title: 'Thing',
        price: 'Claim',
        tone: StoreTone.ad,
        onBuy: () {},
      ),
    );
    expect(find.text('AD'), findsOneWidget);
    await pump(
      tester,
      ShopTile(
        tileKey: 'thing',
        title: 'Thing',
        price: '1,000',
        tone: StoreTone.coin,
        onBuy: () {},
      ),
    );
    expect(find.text('AD'), findsNothing);
  });
}
