/// Manager Customisations — the one section that sells nothing for gems.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/engine/iap_engine.dart';
import 'package:merge_empire_fc/engine/look_pack_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/engine/gem_engine.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_looks.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_section.dart';

import 'shop_helpers.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';

void main() {
  tearDown(resetLocale);

  testWidgets('the vault is real money and disabled', (tester) async {
    await pumpShopWidget(tester, (_) {}, LooksSection.new);
    final vault = products.firstWhere((p) => p.styleVault);
    expect(find.text(vault.price), findsOneWidget);
    expect(
      tester
          .widget<StoreButton>(find.byKey(ValueKey('shop-buy-${vault.id}')))
          .onTap,
      isNull,
    );
  });

  testWidgets('a pack tile reports progress, and the TILE is the control', (
    tester,
  ) async {
    // The price was a figure the player could read and not act on: what spent
    // the gems was a sheet the port did not have. The tile itself is the
    // control now — no `StoreButton` on it, because a pack is small and the
    // whole tile is the tap target.
    await pumpShopWidget(tester, (_) {}, LooksSection.new);
    for (final pack in lookPacks) {
      expect(
        find.byKey(ValueKey('shop-tile-pack-${pack.id}'), skipOffstage: false),
        findsOneWidget,
        reason: pack.id,
      );
      expect(
        find.byKey(ValueKey('shop-buy-pack-${pack.id}'), skipOffstage: false),
        findsNothing,
        reason: pack.id,
      );
    }
  });

  group('BUYING A PACK', () {
    Future<void> tapFirstPack(WidgetTester tester) async {
      final tile = find.byKey(
        ValueKey('shop-tile-pack-${lookPacks.first.id}'),
        skipOffstage: false,
      );
      await tester.scrollUntilVisible(tile, 80);
      await tester.tap(tile);
      await tester.pumpAndSettle();
    }

    testWidgets('ASKS FIRST, then spends the gems', (tester) async {
      final container = await pumpShopWidget(
        tester,
        (s) => (s['resources'] as Map<String, dynamic>)['gems'] = 50,
        LooksSection.new,
      );
      await tapFirstPack(tester);
      expect(
        find.byKey(ValueKey('spend-confirm-pack-${lookPacks.first.id}')),
        findsOneWidget,
        reason: 'the pack was bought without asking',
      );

      await tester.tap(
        find.byKey(ValueKey('spend-confirm-yes-pack-${lookPacks.first.id}')),
      );
      await tester.pumpAndSettle();
      final save = container.read(gameProvider).state!;
      expect(isPackComplete(save, lookPacks.first.id), isTrue);
      expect(getGems(save), 50 - packGemCost());
      await settleSave(tester);
    });

    testWidgets('and a player who cannot afford it is shown the gems', (
      tester,
    ) async {
      // "Not enough gems" is never said: the answer to wanting the thing is a
      // way to afford it.
      await pumpShopWidget(
        tester,
        (s) => (s['resources'] as Map<String, dynamic>)['gems'] = 0,
        LooksSection.new,
      );
      await tapFirstPack(tester);
      await tester.tap(
        find.byKey(ValueKey('spend-confirm-yes-pack-${lookPacks.first.id}')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('currency-sheet-gems')),
        findsOneWidget,
      );
    });

    testWidgets('THE PRICE IS A BLUE BUTTON WITH A WHITE GEM', (tester) async {
      // It was a near-black pill with a blue gem and blue digits at 11px, which
      // reads as a disabled chip rather than as the control that buys the pack.
      await pumpShopWidget(tester, (_) {}, LooksSection.new);
      final pill = tester.widget<Container>(
        find.byKey(const ValueKey('pack-pill-buy'), skipOffstage: false).first,
      );
      expect((pill.decoration! as BoxDecoration).color, ShopSectionId.gems.ink);
      final gem = tester.widget<Icon>(
        find
            .descendant(
              of: find.byKey(
                const ValueKey('pack-pill-buy'),
                skipOffstage: false,
              ),
              matching: find.byIcon(Icons.diamond),
            )
            .first,
      );
      expect(gem.color, Colors.white);
    });
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
    expect(find.byType(StoreButton), findsOneWidget);
  });

  group('the case', () {
    testWidgets('the packs sit INSIDE the vault, not beside it', (
      tester,
    ) async {
      // The relationship — this one buys those six — has to be a shape. Seven
      // tiles in one grid with a caption over them read as seven things for
      // sale, which is the JS's own note on the same mistake.
      await pumpShopWidget(tester, (_) {}, LooksSection.new);
      final case_ = find.byKey(const ValueKey('shop-vault-case'));
      expect(case_, findsOneWidget);
      for (final pack in lookPacks) {
        expect(
          find.descendant(
            of: case_,
            matching: find.byKey(
              ValueKey('shop-tile-pack-${pack.id}'),
              skipOffstage: false,
            ),
          ),
          findsOneWidget,
          reason: pack.id,
        );
      }
      expect(
        find.descendant(
          of: case_,
          matching: find.byKey(
            ValueKey(
              'shop-tile-${products.firstWhere((p) => p.styleVault).id}',
            ),
          ),
        ),
        findsOneWidget,
        reason: 'and the vault is the lid on it',
      );
    });

    testWidgets('and the lid says what it holds', (tester) async {
      await pumpShopWidget(tester, (_) {}, LooksSection.new);
      expect(
        find.text(t('shop.looks.case_label', {'total': lookPacks.length})),
        findsOneWidget,
      );
    });

    testWidgets('a pack carries its OWN price', (tester) async {
      // "What does this pack cost" is the question a tile answers — see
      // `look_pack_engine.dart`. It had been answering "how much of it do you
      // have", which is the sub-line's job.
      await pumpShopWidget(tester, (_) {}, LooksSection.new);
      final cost = lookTileState(
        createDefaultState(),
        lookPacks.first.id,
      )!.cost;
      expect(find.text('$cost'), findsNWidgets(lookPacks.length));
    });

    testWidgets('and owning the vault opens it rather than selling it', (
      tester,
    ) async {
      await pumpShopWidget(
        tester,
        (s) => (s['shop'] as Map<String, dynamic>)['purchasedIds'] = [
          styleVaultId,
        ],
        LooksSection.new,
      );
      expect(find.text(t('shop.looks.vault_owned')), findsOneWidget);
      expect(
        find.byType(StoreButton),
        findsNothing,
        reason: 'nothing left to buy',
      );
      // Every pack came with it, so every pill reads Owned.
      expect(find.text(t('shop.owned')), findsNWidgets(lookPacks.length + 1));
    });
  });
}
