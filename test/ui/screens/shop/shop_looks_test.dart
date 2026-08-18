/// Manager Customisations — the one section that sells nothing for gems.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/engine/iap_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_looks.dart';

import 'shop_helpers.dart';

void main() {
  tearDown(resetLocale);

  testWidgets('the vault is real money and disabled', (tester) async {
    await pumpShopWidget(tester, (_) {}, LooksSection.new);
    final vault = products.firstWhere((p) => p.styleVault);
    expect(find.text(vault.price), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(ValueKey('shop-buy-${vault.id}')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('a pack tile reports progress and offers no purchase', (
    tester,
  ) async {
    await pumpShopWidget(tester, (_) {}, LooksSection.new);
    for (final pack in lookPacks) {
      expect(
        find.byKey(ValueKey('shop-tile-pack-${pack.id}'), skipOffstage: false),
        findsOneWidget,
        reason: pack.id,
      );
      // No buy control on a pack: nothing here is bought with gems.
      expect(
        find.byKey(ValueKey('shop-buy-pack-${pack.id}'), skipOffstage: false),
        findsNothing,
        reason: pack.id,
      );
    }
  });

  testWidgets('the section note counts the packs owned', (tester) async {
    await pumpShopWidget(tester, (_) {}, LooksSection.new);
    expect(
      find.text(t('shop.vault.progress', {'n': 0, 'total': lookPacks.length})),
      findsOneWidget,
    );
  });

  testWidgets('exactly one buy button in the section — the vault', (
    tester,
  ) async {
    await pumpShopWidget(tester, (_) {}, LooksSection.new);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
