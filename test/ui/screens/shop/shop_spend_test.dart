/// The two shelves a player can buy from.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/scout_voucher_engine.dart';
import 'package:merge_empire_fc/engine/shop_consumables_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_providers.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_spend.dart';

import 'shop_helpers.dart';

void main() {
  tearDown(resetLocale);

  group('boosts and consumables', () {
    testWidgets('buying a gem item debits the gems', (tester) async {
      final container = await pumpShopWidget(
        tester,
        (s) => (s['resources'] as Map<String, dynamic>)['gems'] = 500,
        BoostsSection.new,
      );
      final live = container
          .read(gemItemTilesProvider)
          .firstWhere((t) => t.blocked == null);
      final before = container.read(gemsProvider);

      // The shelves are grids now, so a tile can sit below the fold.
      await tester.ensureVisible(
        find.byKey(ValueKey('shop-buy-gem-${live.item.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('shop-buy-gem-${live.item.id}')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(container.read(gemsProvider), lessThan(before));
    });

    testWidgets('a blocked gem row is dead and carries its reason', (
      tester,
    ) async {
      final container = await pumpShopWidget(tester, (_) {}, BoostsSection.new);
      final blocked = container
          .read(gemItemTilesProvider)
          .firstWhere((t) => t.blocked != null);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(ValueKey('shop-buy-gem-${blocked.item.id}')),
            )
            .onPressed,
        isNull,
      );
      expect(find.text(t('shop.toast.not_enough_gems')), findsWidgets);
    });

    testWidgets('a gem purchase never fires when the row is blocked', (
      tester,
    ) async {
      final container = await pumpShopWidget(tester, (_) {}, BoostsSection.new);
      final before = container.read(gemsProvider);
      await tester.pump(const Duration(milliseconds: 50));
      expect(container.read(gemsProvider), before);
    });

    testWidgets('buying a season boost debits the coins and arms it', (
      tester,
    ) async {
      final container = await pumpShopWidget(
        tester,
        (s) => (s['resources'] as Map<String, dynamic>)['fanCoins'] = 999999,
        BoostsSection.new,
      );
      final before = container.read(coinsProvider);

      // The shelves are grids now, so a tile can sit below the fold.
      await tester.ensureVisible(
        find.byKey(const ValueKey('shop-buy-coin-kit_sponsor')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shop-buy-coin-kit_sponsor')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(container.read(coinsProvider), lessThan(before));
      expect(isKitSponsorActive(container.read(gameProvider).state), isTrue);
    });

    testWidgets('a boost already running this season is dead', (tester) async {
      final container = await pumpShopWidget(tester, (s) {
        (s['resources'] as Map<String, dynamic>)['fanCoins'] = 999999;
        (s['boosts'] as Map<String, dynamic>)['kitSponsorSeason'] =
            (s['progression'] as Map<String, dynamic>)['seasonCount'];
      }, BoostsSection.new);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('shop-buy-coin-kit_sponsor')),
            )
            .onPressed,
        isNull,
      );
      expect(find.text(t('shop.already_active')), findsWidgets);
      expect(container.read(coinsProvider), 999999);
    });

    testWidgets('the sponge is dead with nobody injured, and says why', (
      tester,
    ) async {
      await pumpShopWidget(
        tester,
        (s) => (s['resources'] as Map<String, dynamic>)['fanCoins'] = 999999,
        BoostsSection.new,
      );
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('shop-buy-coin-magic_sponge')),
            )
            .onPressed,
        isNull,
      );
      expect(find.text(t('shop.toast.no_injured')), findsWidgets);
    });
  });

  group('the voucher ladder', () {
    testWidgets('the one-at-a-time rule is stated once, not per rung', (
      tester,
    ) async {
      await pumpShopWidget(tester, (_) {}, VouchersSection.new);
      expect(find.text(t('shop.voucher.one_at_a_time')), findsOneWidget);
    });

    testWidgets('buying a voucher debits the gems and arms the floor', (
      tester,
    ) async {
      final container = await pumpShopWidget(
        tester,
        (s) => (s['resources'] as Map<String, dynamic>)['gems'] = 500,
        VouchersSection.new,
      );
      final open = container
          .read(voucherTilesProvider)
          .firstWhere((t) => t.blocked == null);
      final before = container.read(gemsProvider);

      // The shelves are grids now, so a tile can sit below the fold.
      await tester.ensureVisible(
        find.byKey(ValueKey('shop-buy-voucher-${open.floor}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('shop-buy-voucher-${open.floor}')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(container.read(gemsProvider), lessThan(before));
      expect(heldVoucherTier(container.read(gameProvider).state), open.floor);
    });

    testWidgets('once one is armed every other rung is blocked', (
      tester,
    ) async {
      final container = await pumpShopWidget(
        tester,
        (s) => (s['resources'] as Map<String, dynamic>)['gems'] = 500,
        VouchersSection.new,
      );
      final open = container
          .read(voucherTilesProvider)
          .firstWhere((t) => t.blocked == null);

      // The shelves are grids now, so a tile can sit below the fold.
      await tester.ensureVisible(
        find.byKey(ValueKey('shop-buy-voucher-${open.floor}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('shop-buy-voucher-${open.floor}')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(
        container
            .read(voucherTilesProvider)
            .every((t) => t.blocked == VoucherBlock.alreadyHeld),
        isTrue,
      );
    });
  });
}
