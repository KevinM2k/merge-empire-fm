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

    testWidgets('THE PRICE IS THE SHOP\'S OWN GEM BUTTON, not a lookalike', (
      tester,
    ) async {
      // A pass ago this became "a blue button with a white gem" and picked its
      // own blue — `ShopSectionId.gems.ink`, the SECTION's tint — so the ten
      // controls that buy a look pack were the only buy buttons in the shop
      // that were not `StoreButton`: different face, different edge, different
      // radius, no press.
      await pumpShopWidget(tester, (_) {}, LooksSection.new);
      final button = tester.widget<StoreButton>(
        find.byKey(const ValueKey('pack-pill-buy'), skipOffstage: false).first,
      );
      expect(button.tone, StoreTone.gem);
      expect(button.onTap, isNotNull, reason: 'and it is tappable');
    });
  });

    testWidgets('AND THE CONFIRM SAYS WHAT THE PACK UNLOCKS', (tester) async {
      // "4 items" over a confirm is a count of things the player cannot see —
      // the tile behind the sheet has the picture and the sheet covers it. The
      // contents are `axis:id` pairs and every axis already has a catalogue
      // label, so the summary needs no new copy.
      await pumpShopWidget(tester, (_) {}, LooksSection.new);
      await tester.tap(
        find.byKey(const ValueKey('pack-pill-buy'), skipOffstage: false).first,
      );
      await tester.pumpAndSettle();
      // The Summer pack is two Headwear, an Accessory and a Celebration.
      expect(
        find.textContaining('${t('customise.tab.hat')} ×2'),
        findsOneWidget,
      );
      expect(find.textContaining(t('customise.tab.emote')), findsOneWidget);
      // The TILES behind the sheet still say "4 items" and should — that is
      // the size of the pack. What changed is what the confirm leads with.
    });

  testWidgets('the section note counts the packs owned', (tester) async {
    await pumpShopWidget(tester, (_) {}, LooksSection.new);
    expect(
      find.text(t('shop.vault.progress', {'n': 0, 'total': lookPacks.length})),
      findsOneWidget,
    );
  });

  testWidgets('EVERY PACK HAS ONE, and so does the vault', (tester) async {
    // The vault plus one per unowned pack. They are all `StoreButton` now —
    // the packs used to draw a pill of their own, which is what made them the
    // odd controls in the shop.
    await pumpShopWidget(tester, (_) {}, LooksSection.new);
    expect(find.byType(StoreButton), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('shop-vault-case')),
        matching: find.byType(StoreButton),
      ),
      findsWidgets,
    );
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
