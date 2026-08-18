/// The real-money shelves and the free shelf. Nothing here can be bought yet.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/ad_gate_engine.dart';
import 'package:merge_empire_fc/engine/iap_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_free.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_paid.dart';

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
      expect(find.text(p.name), findsWidgets, reason: p.id);
    }
  });

  testWidgets('Restore Purchases is present and disabled', (tester) async {
    await pumpPaid(tester);
    expect(find.text(t('shop.restore_purchases')), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('shop-restore')))
          .onPressed,
      isNull,
    );
  });

  test('no paid section calls the grant step', () {
    // purchaseProduct runs AFTER a store confirms a payment. A button wired to
    // it would hand out paid goods for free.
    for (final path in [
      'lib/ui/screens/shop/shop_paid.dart',
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

    testWidgets('a spent daily cap reads as a cap, not as ready', (tester) async {
      // The gate is real even though the button is not.
      await pumpShopWidget(
        tester,
        (s) {
          for (var i = 0; i < 20; i++) {
            recordPackAd(s);
          }
        },
        FreeShelfSection.new,
      );
      expect(find.text(t('shop.daily_cap')), findsWidgets);
    });
  });
}
