/// The two shelves a player can buy from.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/scout_voucher_engine.dart';
import 'package:merge_empire_fc/engine/shop_consumables_engine.dart';
import 'package:merge_empire_fc/data/card_theme.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_providers.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_spend.dart';

import 'shop_helpers.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
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
      // Not the plain scout voucher: it is the bottom rung of the voucher
      // LADDER and is deliberately not drawn among the gem items — see
      // `_renderGemItems` in the JS, which filters it for the same reason.
      final live = container
          .read(gemItemTilesProvider)
          .firstWhere(
            (t) => t.blocked == null && t.item.id != 'scout_voucher_gem',
          );
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
          .firstWhere(
            (t) =>
                t.blocked == 'insufficient_gems' &&
                t.item.id != 'scout_voucher_gem',
          );
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
          .firstWhere(
            (t) =>
                t.blocked == 'insufficient_gems' &&
                t.item.id != 'scout_voucher_gem',
          );
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

    group('THE SHELF IS TWO SHELVES', () {
      // **A Magic Sponge and a Kit Sponsor answer different questions.** One
      // heading over both of them answered neither: a player looking for
      // income scanned past a bandage, and a player with three injured men
      // scanned past a TV deal. Asked for from the couch: split the boosts from
      // the income. See `incomeShelfIds`.
      testWidgets('and BOOSTS keeps what fixes the squad', (tester) async {
        await pumpShopWidget(tester, (_) {}, BoostsSection.new);
        expect(
          find.byKey(const ValueKey('shop-tile-coin-magic_sponge')),
          findsOneWidget,
        );
        for (final id in incomeShelfIds) {
          expect(
            find.byKey(ValueKey('shop-tile-coin-$id')),
            findsNothing,
            reason: '$id is income and is still on the boosts shelf',
          );
          expect(find.byKey(ValueKey('shop-tile-gem-$id')), findsNothing);
        }
      });

      testWidgets('and INCOME takes what multiplies the earnings', (
        tester,
      ) async {
        await pumpShopWidget(tester, (_) {}, IncomeSection.new);
        expect(
          find.byKey(const ValueKey('shop-tile-coin-kit_sponsor')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('shop-tile-coin-magic_sponge')),
          findsNothing,
          reason: 'a bandage does not pay anything',
        );
      });

      testWidgets('and it is a PARTITION — nothing is drawn twice', (
        tester,
      ) async {
        // The two shelves read one membership test, so a tile is on exactly
        // one of them. A row added without touching `incomeShelfIds` lands on
        // Boosts, which is the safer default: a boost on the wrong shelf is
        // misfiled, and an income item on the wrong shelf is a claim about
        // what it does.
        Future<Set<String>> tilesOf(Widget Function() build) async {
          await pumpShopWidget(tester, (_) {}, build);
          return {
            for (final el in find
                .byWidgetPredicate(
                  (w) =>
                      w.key is ValueKey<String> &&
                      (w.key! as ValueKey<String>).value.startsWith(
                        'shop-tile-',
                      ),
                )
                .evaluate())
              ((el.widget.key! as ValueKey<String>).value),
          };
        }

        final boosts = await tilesOf(BoostsSection.new);
        final income = await tilesOf(IncomeSection.new);
        expect(boosts, isNotEmpty);
        expect(income, isNotEmpty);
        expect(
          boosts.intersection(income),
          isEmpty,
          reason: 'a tile is on both shelves',
        );
      });
    });

    testWidgets('a gem purchase never fires when the row is blocked', (
      tester,
    ) async {
      final container = await pumpShopWidget(tester, (_) {}, BoostsSection.new);
      final before = container.read(gemsProvider);
      await tester.pump(const Duration(milliseconds: 50));
      expect(container.read(gemsProvider), before);
    });

    // **THE KIT SPONSOR IS ON THE INCOME SHELF NOW.** It is ×1.25 income for a
    // season, and the old Boosts shelf mixed that in with a bandage and an
    // energy refill — see `incomeShelfIds`. The tile, the price and the buy
    // flow are the same widget either side of the split; what changed is which
    // shelf draws it.
    testWidgets('buying a season boost debits the coins and arms it', (
      tester,
    ) async {
      final container = await pumpShopWidget(
        tester,
        (s) => (s['resources'] as Map<String, dynamic>)['fanCoins'] = 999999,
        IncomeSection.new,
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
      }, IncomeSection.new);
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

    testWidgets('THE TIER IS THE NAME, not "Scout Vouchers" eight times', (
      tester,
    ) async {
      // The section heading has already said it, so repeating it on every tile
      // spends the widest line on each of them saying the same thing.
      final container = await pumpShopWidget(
        tester,
        (_) {},
        VouchersSection.new,
      );
      final tiles = container.read(voucherTilesProvider);
      expect(tiles, isNotEmpty);
      for (final tile in tiles) {
        expect(
          find.text(tierLabel[tile.floor] ?? 'T${tile.floor}'),
          findsWidgets,
          reason: 'rung ${tile.floor}',
        );
      }
      expect(
        find.textContaining('${t('shop.section.vouchers')} '),
        findsNothing,
      );
    });

    testWidgets('"OR BETTER" IS ON THE TILE, with the odds it replaces', (
      tester,
    ) async {
      // A voucher sets a FLOOR. A tile reading just "GOLD★" is the exact-tier
      // misreading the whole design was chosen to avoid, and it had no sub at
      // all — `shop.voucher.sub` was translated in ten catalogues and
      // unreachable.
      final container = await pumpShopWidget(
        tester,
        (_) {},
        VouchersSection.new,
      );
      final offered = container
          .read(voucherTilesProvider)
          .firstWhere((t) => t.offered);
      expect(offered.odds, greaterThan(0));
      final pct = (offered.odds * 100).toStringAsFixed(
        offered.odds * 100 < 10 ? 1 : 0,
      );
      expect(
        find.text(t('shop.voucher.sub', {'pct': pct})),
        findsWidgets,
        reason: 'the floor rule and its odds are not on the tile',
      );
    });

    testWidgets('EVERY RUNG IS SHOWN, and a locked one names its division', (
      tester,
    ) async {
      // The shelf listed only the tiers this division can buy, so the top of
      // the ladder was not there at all — and a ladder with its top hidden is a
      // shelf, which takes the reason to climb with it.
      final container = await pumpShopWidget(
        tester,
        (_) {},
        VouchersSection.new,
      );
      final tiles = container.read(voucherTilesProvider);
      expect(tiles, hasLength(voucherTiers.length));
      final locked = tiles.where((t) => !t.offered);
      expect(locked, isNotEmpty, reason: 'a fresh save can buy every rung');
      for (final tile in locked) {
        expect(
          find.text(
            t('shop.voucher.unlocks_in', {
              'division': tName('division', tile.unlocksIn),
            }),
          ),
          findsWidgets,
          reason: 'rung ${tile.floor}',
        );
      }
    });

    testWidgets('a locked rung wears a PADLOCK, not "Coming soon"', (
      tester,
    ) async {
      // The JS puts a lock glyph on a locked rung's button and no price; the
      // port's `blockedCopy` had no line for `notOffered` and its fallthrough
      // printed the settings screen's "Coming soon" under a tile whose own
      // subtitle already said which division unlocks it.
      final container = await pumpShopWidget(
        tester,
        (_) {},
        VouchersSection.new,
      );
      final locked = container
          .read(voucherTilesProvider)
          .where((t) => !t.offered)
          .toList();
      expect(locked, isNotEmpty);
      expect(find.text(t('settings.comingSoon')), findsNothing);
      for (final tile in locked) {
        final button = find.byKey(ValueKey('shop-buy-voucher-${tile.floor}'));
        expect(
          find.descendant(
            of: button,
            matching: find.byWidgetPredicate(
              (w) => w is GameIcon && w.name == 'lock',
            ),
          ),
          findsOneWidget,
          reason: 'rung ${tile.floor}',
        );
        expect(
          find.descendant(of: button, matching: find.text('${tile.cost ?? 0}')),
          findsNothing,
          reason: 'rung ${tile.floor} still quotes a price',
        );
      }
    });

    testWidgets('and THE GAMBLE RUNG IS ON THE SHELF', (tester) async {
      // The cheapest of them, and the only one that can hand over an Icon.
      await pumpShopWidget(tester, (_) {}, VouchersSection.new);
      expect(find.byKey(const ValueKey('shop-tile-voucher-random')), findsOne);
      expect(find.text(t('shop.voucher.random')), findsOneWidget);
      expect(find.text(t('shop.voucher.random_sub')), findsOneWidget);
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

      // Every rung this division can BUY is blocked by the armed one. The
      // rungs above it stay `notOffered`, which is a different no and the
      // reason the tile names a division instead of a price.
      final after = container.read(voucherTilesProvider);
      expect(
        after
            .where((t) => t.offered)
            .every((t) => t.blocked == VoucherBlock.alreadyHeld),
        isTrue,
      );
      expect(
        after
            .where((t) => !t.offered)
            .every((t) => t.blocked == VoucherBlock.notOffered),
        isTrue,
      );
      // And exactly ONE says it is the one being held.
      expect(after.where((t) => t.holding), hasLength(1));
    });
  });

  testWidgets('THE PLAIN SCOUT VOUCHER IS DRAWN ONCE, in the ladder', (
    tester,
  ) async {
    // It is the bottom rung of the voucher ladder, not a loose consumable, and
    // it was appearing twice — once among the gem items beside the TV
    // broadcast deal and once in the section a player looking for a scout
    // actually goes to. `_renderGemItems` filters it out and says why; the port
    // did not. Reported as the same voucher showing up twice.
    await pumpShopWidget(tester, (_) {}, BoostsSection.new);
    expect(
      find.byKey(const ValueKey('shop-tile-gem-scout_voucher_gem')),
      findsNothing,
    );
  });
}
