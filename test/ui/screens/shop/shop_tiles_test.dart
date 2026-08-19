/// The shared section frame and tile.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_section.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_tiles.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

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
        disabledReason: t('settings.comingSoon'),
      ),
    );
    expect(find.text('£4.99'), findsOneWidget);
    expect(find.text(t('settings.comingSoon')), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const ValueKey('shop-buy-thing')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('a progress tile offers no purchase at all', (tester) async {
    await pump(
      tester,
      const ShopProgressTile(
        tileKey: 'pack-black',
        title: 'Black',
        owned: 2,
        total: 5,
      ),
    );
    expect(find.text('2/5'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
  });
}
