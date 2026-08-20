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
import 'package:merge_empire_fc/ui/widgets/store_button.dart';

/// Tap a priced row and say yes. Spending is a two-beat flow now — see
/// `purchase_flow.dart` — because a row the balance will not cover has to end
/// at the coin or gem packs rather than at a dead button.
Future<void> buyRow(WidgetTester tester, String tileKey) async {
  await tester.ensureVisible(find.byKey(ValueKey('shop-buy-$tileKey')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('shop-buy-$tileKey')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('spend-confirm-yes-$tileKey')));
  await tester.pumpAndSettle();
}

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

      await buyRow(tester, 'gem-${live.item.id}');
      expect(container.read(gemsProvider), lessThan(before));

      // And a receipt, so a purchase is an event rather than a number quietly
      // changing.
      expect(
        find.byKey(ValueKey('spend-receipt-gem-${live.item.id}')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(ValueKey('spend-receipt-ok-gem-${live.item.id}')),
      );
      await tester.pumpAndSettle();
      await settleSave(tester);
    });

    testWidgets('a row nobody can afford is still LIVE', (tester) async {
      // "Not enough gems" is never said: the player wanted the thing, and the
      // answer to wanting it is a way to afford it.
      final container = await pumpShopWidget(tester, (_) {}, BoostsSection.new);
      final broke = container
          .read(gemItemTilesProvider)
          .firstWhere((t) => t.blocked == 'insufficient_gems');
      expect(
        tester
            .widget<StoreButton>(
              find.byKey(ValueKey('shop-buy-gem-${broke.item.id}')),
            )
            .onTap,
        isNotNull,
      );
      expect(find.text(t('shop.toast.not_enough_gems')), findsNothing);
    });

    testWidgets('and saying yes to it opens the GEM PACKS', (tester) async {
      final container = await pumpShopWidget(tester, (_) {}, BoostsSection.new);
      final broke = container
          .read(gemItemTilesProvider)
          .firstWhere((t) => t.blocked == 'insufficient_gems');
      final before = container.read(gemsProvider);

      await buyRow(tester, 'gem-${broke.item.id}');
      expect(
        find.byKey(const ValueKey('currency-sheet-gems')),
        findsOneWidget,
        reason: 'the next thing on screen is the thing that fixes it',
      );
      expect(container.read(gemsProvider), before, reason: 'and nothing spent');
    });

    testWidgets('a refusal that is NOT about money is still said', (
      tester,
    ) async {
      // Already owned, already active, nobody injured — those are answers, not
      // obstacles, and they belong on the tile.
      final container = await pumpShopWidget(
        tester,
        (s) => (s['resources'] as Map<String, dynamic>)['gems'] = 500,
        BoostsSection.new,
      );
      final other = container
          .read(gemItemTilesProvider)
          .where((t) => t.blocked != null && t.blocked != 'insufficient_gems');
      for (final tile in other) {
        expect(
          tester
              .widget<StoreButton>(
                find.byKey(ValueKey('shop-buy-gem-${tile.item.id}')),
              )
              .onTap,
          isNull,
          reason: tile.item.id,
        );
      }
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

      await buyRow(tester, 'coin-kit_sponsor');
      await tester.tap(
        find.byKey(const ValueKey('spend-receipt-ok-coin-kit_sponsor')),
      );
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
            .widget<StoreButton>(
              find.byKey(const ValueKey('shop-buy-coin-kit_sponsor')),
            )
            .onTap,
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
            .widget<StoreButton>(
              find.byKey(const ValueKey('shop-buy-coin-magic_sponge')),
            )
            .onTap,
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

      await buyRow(tester, 'voucher-${open.floor}');
      await tester.tap(
        find.byKey(ValueKey('spend-receipt-ok-voucher-${open.floor}')),
      );
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

      await buyRow(tester, 'voucher-${open.floor}');
      await tester.tap(
        find.byKey(ValueKey('spend-receipt-ok-voucher-${open.floor}')),
      );
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
