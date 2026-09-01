/// Manager Customisations — the one section that sells nothing for gems.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_customiser.dart'
    show LookPreview, lookItemLabel;
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

  testWidgets('the vault is real money and BUYS', (tester) async {
    // It was dead while there was no bridge. The JS names it and the gem
    // bundles as the two tiles that used to charge straight off themselves,
    // which is why the tap goes through the confirm rather than the store.
    await pumpShopWidget(tester, (_) {}, LooksSection.new);
    final vault = products.firstWhere((p) => p.styleVault);
    expect(find.text(vault.price), findsOneWidget);
    expect(
      tester
          .widget<StoreButton>(find.byKey(ValueKey('shop-buy-${vault.id}')))
          .onTap,
      isNotNull,
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
  group('A PACK SAYS WHAT IS IN IT', () {
    // The tile answered "what does this cost" and the confirm summarised — "two
    // Headwear, one Accessory" is a count of things the player cannot see, and
    // the tile with the picture on it is behind the card. Asked for directly:
    // list every item, and TICK the ones already unlocked.
    testWidgets('every item is named, from the catalogue', (tester) async {
      await pumpShopWidget(tester, (_) {}, LooksSection.new);
      final pack = lookPacks.first;
      await tester.tap(
        find.byKey(ValueKey('shop-tile-pack-${pack.id}'), skipOffstage: false),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('pack-contents-${pack.id}')), findsOneWidget);
      for (final item in pack.items) {
        final axis = item.split(':').first;
        final id = item.split(':').last;
        // **THE CATALOGUE'S OWN KEY SCHEME, which is not one scheme** — see
        // `lookItemLabel`. Asking for `customise.<axis>.<id>` and tidying the
        // id when it missed printed "Sunhat" where the catalogue says "Sun
        // Hat", here and on the customiser's chips.
        expect(
          find.text(lookItemLabel(axis, id)),
          findsOneWidget,
          reason: item,
        );
      }
    });

    testWidgets('AND WHAT IS ALREADY OWNED IS TICKED', (tester) async {
      // A tick rather than a lock: what the player is deciding is what this
      // pack still has to GIVE them, so the ones they have are the marked ones.
      // A padlock on the rest would read as the pack being unavailable.
      final pack = lookPacks.first;
      await pumpShopWidget(
        tester,
        // `club.lookItems` is where an owned cosmetic lives — `gemUnlocks` is
        // the permanent-purchase ledger and a different question.
        (s) => (s['club'] as Map<String, dynamic>)['lookItems'] = <dynamic>[
          pack.items.first,
        ],
        LooksSection.new,
      );
      await tester.tap(
        find.byKey(ValueKey('shop-tile-pack-${pack.id}'), skipOffstage: false),
      );
      await tester.pumpAndSettle();

      final ticks = find.descendant(
        of: find.byKey(ValueKey('pack-contents-${pack.id}')),
        matching: find.byIcon(Icons.check_circle),
      );
      expect(ticks, findsOneWidget, reason: 'one owned, one tick');
    });
  });


  testWidgets('A PACK SHOWS WHAT EACH THING LOOKS LIKE', (tester) async {
    // The rows were a shirt glyph and a word — "Bucket", "Viking", "Party" —
    // which tells a player nothing about what they are buying. The customiser
    // has been drawing the real thing all along; the same [LookPreview] is on
    // the pack now, on the player's OWN figure with the one choice swapped in.
    await pumpShopWidget(tester, (_) {}, LooksSection.new);
    final tile = find.byKey(
      ValueKey('shop-tile-pack-${lookPacks.first.id}'),
      skipOffstage: false,
    );
    await tester.scrollUntilVisible(tile, 80);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(LookPreview), findsWidgets);
  });

  /// **A HAIR COLOUR IS NOT A STAR.**
  ///
  /// The colour axes were excluded from the preview on the customiser's
  /// reasoning that a colour is better looked at as a colour — but the
  /// customiser then draws a SWATCH, and the shop has no swatch branch, so a
  /// player buying a colour pack saw `GameIcon('star')`, once per colour.
  /// Reported from the couch, asking for the head. A star is not a worse look at
  /// a colour; it is no look at one.
  testWidgets('AND A HAIR COLOUR IS SHOWN ON A HEAD', (tester) async {
    final pack = lookPacks.firstWhere(
      (p) => p.items.any((i) => i.startsWith('color:')),
      orElse: () => lookPacks.first,
    );
    final colours = pack.items.where((i) => i.startsWith('color:')).length;
    if (colours == 0) return;

    await pumpShopWidget(tester, (_) {}, LooksSection.new);
    final tile = find.byKey(
      ValueKey('shop-tile-pack-${pack.id}'),
      skipOffstage: false,
    );
    await tester.scrollUntilVisible(tile, 80);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    final previews = tester
        .widgetList<LookPreview>(find.byType(LookPreview))
        .where((p) => p.axis.kind == 'color')
        .toList();
    expect(
      previews,
      hasLength(colours),
      reason: 'a colour still has no picture of itself',
    );
    // Each is a DIFFERENT head, which is the whole point — and the hat comes
    // off, or a manager in a bucket hat previews four identical hats.
    expect(
      previews.map((p) => p.look['hair']).toSet(),
      hasLength(colours),
      reason: 'every colour drew the same head',
    );
    for (final preview in previews) {
      expect(preview.look['hat'], 'none');
    }
  });

  /// **ACROSS, NOT DOWN.**
  ///
  /// The items were a column of 54pt pictures with their names beside them and
  /// the rest of a wide sheet empty to the right, so the pictures — the whole
  /// reason the list is drawn rather than written — were the smallest thing on
  /// it. The customiser lays the same choices out as a grid with the name under
  /// each one, which is what was asked for.
  testWidgets('AND THEY SIT SIDE BY SIDE, name under picture', (tester) async {
    final pack = lookPacks.firstWhere((p) => p.items.length > 1);
    await pumpShopWidget(tester, (_) {}, LooksSection.new);
    final tile = find.byKey(
      ValueKey('shop-tile-pack-${pack.id}'),
      skipOffstage: false,
    );
    await tester.scrollUntilVisible(tile, 80);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    final first = pack.items.first.split(':');
    final second = pack.items[1].split(':');
    final a = tester.getRect(find.text(lookItemLabel(first.first, first.last)));
    final b = tester.getRect(
      find.text(lookItemLabel(second.first, second.last)),
    );
    expect(a.center.dy, closeTo(b.center.dy, 1), reason: 'still a column');
    expect(b.center.dx, greaterThan(a.center.dx));

    // And the name is UNDER its own picture rather than beside it.
    final pictures = tester
        .widgetList<LookPreview>(find.byType(LookPreview))
        .toList();
    expect(pictures, isNotEmpty);
    final art = tester.getRect(find.byWidget(pictures.first));
    expect(a.top, greaterThanOrEqualTo(art.bottom - 1));
  });

  group('A PACK TILE IS AN OBJECT ON THE PAGE', () {
    testWidgets('its pane is OPAQUE, whatever is behind the shop', (
      tester,
    ) async {
      // It was the pack's colour at 10% alpha over nothing at all, so on the
      // turf and humbug backdrops the page showed straight through all ten —
      // reported as the customisation buttons being see-through. `.look-tile`
      // is that tint wash over an opaque `surface-2 -> surface`, the base the
      // rest of the shelf is built on, plus the shadow that lifts it off.
      await pumpShopWidget(tester, (_) {}, LooksSection.new);
      for (final pack in lookPacks) {
        final pane =
            tester
                    .widget<Container>(
                      find.byKey(
                        ValueKey('shop-tile-pack-${pack.id}'),
                        skipOffstage: false,
                      ),
                    )
                    .decoration!
                as BoxDecoration;
        expect(pane.color, isNull, reason: '${pack.id}: back to a flat wash');
        for (final colour in (pane.gradient! as LinearGradient).colors) {
          expect(colour.a, 1.0, reason: '${pack.id}: $colour lets the page in');
        }
        expect(
          pane.boxShadow,
          isNotNull,
          reason: '${pack.id}: nothing sitting it on top of the page',
        );
      }
    });

    testWidgets('AND ITS PRICE IS A FULL-SIZE BUTTON', (tester) async {
      // It was the `--sm` variant, which is the ROW button — for a list line,
      // not for a tile this wide, where 11pt type read as a caption.
      await pumpShopWidget(tester, (_) {}, LooksSection.new);
      final button = tester.widget<StoreButton>(
        find.byKey(const ValueKey('pack-pill-buy'), skipOffstage: false).first,
      );
      expect(button.small, isFalse, reason: 'the small one is for a list line');
      expect(
        button.stretch,
        isFalse,
        reason: 'stretched it is the tile footer rather than a button',
      );
    });
  });
}
