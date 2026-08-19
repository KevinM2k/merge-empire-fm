/// Manager Customisations — the one section that sells nothing for gems.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/engine/iap_engine.dart';
import 'package:merge_empire_fc/engine/look_pack_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
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
        find.byType(ElevatedButton),
        findsNothing,
        reason: 'nothing left to buy',
      );
      // Every pack came with it, so every pill reads Owned.
      expect(find.text(t('shop.owned')), findsNWidgets(lookPacks.length + 1));
    });
  });
}
