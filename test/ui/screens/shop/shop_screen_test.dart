/// The Shop screen: seven shelves, and the deep link that lands on two of them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_screen.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_section.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_paid.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_tiles.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

import 'shop_helpers.dart';

Future<ProviderContainer> pumpShop(
  WidgetTester tester,
  void Function(Map<String, dynamic> state) mutate,
) async {
  final container = shopContainer(mutate);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: const Scaffold(body: ShopScreen()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  tearDown(resetLocale);

  testWidgets('EVERY SHELF IS REACHABLE, one tab at a time', (tester) async {
    // **The shop is tabbed now** — seven shelves on one page was too much, and
    // the categories were left open. A tab is a GROUP of the shelves that
    // already exist rather than a new taxonomy, so what this has to prove is
    // that none of them fell out of the grouping: every section is on exactly
    // one tab, and every tab can be reached.
    await pumpShop(tester, (_) {});
    for (final id in shopSectionOrder) {
      final tab = shopTabOf(id);
      expect(tab, greaterThanOrEqualTo(0), reason: '${id.name} has no tab');
      await tester.tap(
        find.byKey(ValueKey('shop-tab-${shopTabSlug(shopTabs[tab])}')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('shop-section-${id.name}'), skipOffstage: false),
        findsOneWidget,
        reason: id.name,
      );
    }
  });

  testWidgets('and each shelf is on exactly ONE tab', (tester) async {
    // A shelf in two places is a shelf a player finds twice and trusts once.
    for (final id in shopSectionOrder) {
      expect(
        shopTabs.where((tab) => tab.sections.contains(id)).length,
        1,
        reason: id.name,
      );
    }
  });

  testWidgets('and the order inside a tab is the order the JS ships', (
    tester,
  ) async {
    final flat = [for (final tab in shopTabs) ...tab.sections];
    expect(flat.toSet(), shopSectionOrder.toSet());
    // Every tab but one follows the enum.
    for (final tab in shopTabs) {
      if (tab.sections.length < 2) continue;
      if (tab.titleKey == 'shop.section.boosts') continue;
      final order = [
        for (final id in shopSectionOrder)
          if (tab.sections.contains(id)) id,
      ];
      expect(tab.sections, order, reason: tab.titleKey);
    }

    // **AND THE BOOSTS TAB IS SPELLED OUT**, because it is the one place the
    // order is an argument rather than the enum's. What fixes the squad, then
    // what multiplies its income, then the voucher ladder — eight tiles, which
    // buries whatever is under it. The quick-fire match and the lucky boot had
    // a shelf between income and the vouchers; they are tiles on the Boosts
    // grid now.
    expect(
      shopTabs
          .firstWhere((t) => t.titleKey == 'shop.section.boosts')
          .sections,
      [
        ShopSectionId.boosts,
        ShopSectionId.income,
        ShopSectionId.vouchers,
      ],
    );
  });

  testWidgets('THE MATCH DAY ITEMS ARE ON THE BOOSTS SHELF, under its heading', (
    tester,
  ) async {
    // They had a shelf and a heading of their own, directly under Boosts &
    // Items and inside a tab named for it — one answer to "what can I buy that
    // helps me" split across two headings. Asked for from the couch: the two
    // items go under Boosts & Items and the heading goes.
    await pumpShop(tester, (_) {});
    await tester.tap(find.byKey(const ValueKey('shop-tab-boosts')));
    await tester.pumpAndSettle();

    final boosts = find.byKey(
      const ValueKey('shop-section-boosts'),
      skipOffstage: false,
    );
    expect(boosts, findsOneWidget);
    for (final tile in ['ad-match-cooldown', 'ad-lucky-boot']) {
      expect(
        find.descendant(
          of: boosts,
          matching: find.byKey(
            ValueKey('shop-tile-$tile'),
            skipOffstage: false,
          ),
        ),
        findsOneWidget,
        reason: '$tile is not on the Boosts shelf',
      );
    }
    // And no heading of their own anywhere on the tab.
    expect(
      find.byKey(
        const ValueKey('shop-section-matchDay'),
        skipOffstage: false,
      ),
      findsNothing,
    );
  });

  testWidgets('the gems section survives owning the style vault', (
    tester,
  ) async {
    // A section that deletes itself takes the player's balance off screen.
    await pumpShop(tester, (s) {
      (s['shop'] as Map<String, dynamic>)['styleVault'] = true;
    });
    await tester.tap(find.byKey(const ValueKey('shop-tab-premium')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('shop-section-gems'), skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('a coin deep link consumes the flag', (tester) async {
    final container = await pumpShop(tester, (_) {});
    container
        .read(shellControllerProvider.notifier)
        .deepLinkShop(ShopSection.coins);
    await tester.pumpAndSettle();
    expect(
      container.read(shellControllerProvider).pendingShopSection,
      isNull,
      reason: 'consumed, so a rebuild does not scroll again',
    );
  });

  testWidgets('A DEEP LINK OPENS THE TAB, and lands clear of the HUD', (
    tester,
  ) async {
    // **It used to scroll to a heading and then back off by the HUD's own
    // clearance**, because `ensureVisible` puts its target at the top of the
    // VIEWPORT and the top of the viewport is where the floating HUD is — so
    // the heading the link was aimed at was the one thing behind the glass. A
    // tab has no such problem: the shelf is the only thing on the page.
    final container = await pumpShop(tester, (_) {});
    container
        .read(shellControllerProvider.notifier)
        .deepLinkShop(ShopSection.coins);
    await tester.pumpAndSettle();

    final heading = tester.getRect(
      find.byKey(const ValueKey('shop-section-coins')),
    );
    final clearance = hudClearanceOf(
      tester.element(find.byKey(const ValueKey('shop-scroll'))),
    );
    expect(
      heading.top,
      greaterThanOrEqualTo(clearance - 1),
      reason: 'under the glass, not behind it',
    );
    // **The two currencies SHARE a tab now.** Both sell a balance and both
    // shelves state their own prices, so the split cost a tab and bought a
    // player nothing — a coin link lands on the tab that holds the packs, with
    // the gems above them on the same page.
    expect(
      find.byKey(const ValueKey('shop-section-gems'), skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('a gem deep link consumes the flag too', (tester) async {
    final container = await pumpShop(tester, (_) {});
    container
        .read(shellControllerProvider.notifier)
        .deepLinkShop(ShopSection.gems);
    await tester.pumpAndSettle();
    expect(container.read(shellControllerProvider).pendingShopSection, isNull);
  });

  testWidgets('a link set before the screen exists is still honoured', (
    tester,
  ) async {
    // The tab can be built by the very frame that set the link.
    final container = shopContainer((_) {});
    container
        .read(shellControllerProvider.notifier)
        .deepLinkShop(ShopSection.gems);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: ref.watch(appThemeProvider),
            home: const Scaffold(body: ShopScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(shellControllerProvider).pendingShopSection, isNull);
  });

  testWidgets('THE OFFERS WEAR A RIBBON, and a colour of their own', (
    tester,
  ) async {
    // `.shop-hero__ribbon` is the loudest thing on the card in the spec; the
    // port put the same words in a line of grey text under the description,
    // which is the quietest place on it. And three heroes in a column all drew
    // the same gold, so they read as one card repeated.
    await pumpShop(tester, (_) {});
    expect(
      find.byKey(const ValueKey('shop-ribbon-energy_director')),
      findsOneWidget,
    );
    final vip = tester.widget<ShopTile>(
      find.ancestor(
        of: find.byKey(const ValueKey('shop-tile-vip_pass')),
        matching: find.byType(ShopTile),
      ),
    );
    final director = tester.widget<ShopTile>(
      find.ancestor(
        of: find.byKey(const ValueKey('shop-tile-energy_director')),
        matching: find.byType(ShopTile),
      ),
    );
    expect(vip.accent, isNotNull);
    expect(director.accent, isNot(vip.accent));
  });

  testWidgets('THE GEM PACKS ARE THE SPEC\'S OWN TILES', (tester) async {
    // Blue three-dimensional tiles with the pile on them, the number big and
    // the price as a green button — and an ODD count runs the biggest pack
    // full width as a hero rather than leaving half a tile of dead space on the
    // last row. That is `_renderGemPacks` and `.gem-pack-hero` in
    // `ShopScreen.js`; the port drew the shop's generic pane with a price under
    // it. Asked for by name, with the shipped version as the reference.
    await pumpShop(tester, (_) {});
    await tester.tap(find.byKey(const ValueKey('shop-tab-premium')));
    await tester.pumpAndSettle();

    final tiles = tester.widgetList<GemPackTile>(find.byType(GemPackTile));
    expect(tiles, isNotEmpty);
    final heroes = tiles.where((t) => t.hero);
    if (tiles.length.isOdd) {
      expect(heroes, hasLength(1), reason: 'the last one runs full width');
      expect(heroes.single.tile, tiles.last.tile);
    } else {
      expect(heroes, isEmpty);
    }

    // The hero is genuinely wider than the pair above it.
    if (heroes.isNotEmpty) {
      final wide = tester.getSize(
        find.byKey(ValueKey('shop-tile-${heroes.single.tile.product.id}')),
      );
      final narrow = tester.getSize(
        find.byKey(ValueKey('shop-tile-${tiles.first.tile.product.id}')),
      );
      expect(wide.width, greaterThan(narrow.width * 1.5));
    }
  });

  testWidgets('EVERY TAB HAS A BACKGROUND, so the strip reads on a backdrop', (
    tester,
  ) async {
    // The unselected tabs were `Colors.transparent` with a muted label on them,
    // which is fine over a plain page and unreadable over the ones this game
    // draws: the club backdrops put turf and black-and-white stripes directly
    // behind the strip. Reported as the top of the Shop being impossible to
    // read on them.
    await pumpShop(tester, (_) {});
    final kit = Theme.of(
      tester.element(find.byType(ShopScreen)),
    ).extension<KitTheme>()!;

    // **THE PAINTER, not a `DecoratedBox`.** The tab's face is a `CustomPaint`
    // — a `BoxDecoration` cannot round only the top corners AND leave the
    // bottom edge open into the panel — so what a test can ask is the painter
    // what colours it was given. See [ShopTabFace].
    for (final (i, tab) in shopTabs.indexed) {
      final fill = tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byKey(ValueKey('shop-tab-${shopTabSlug(tab)}')),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((p) => p.painter)
          .whereType<ShopTabFace>()
          .first
          .fill;
      expect(fill.a, 1, reason: '${shopTabSlug(tab)} still shows the page');
      // The selected tab keeps its own tint — BLENDED onto the fill rather than
      // laid over the page, so the shelf colours that tell the tabs apart
      // survive going opaque.
      if (i == 0) {
        expect(fill, isNot(kit.surface));
      } else {
        expect(fill, kit.surface);
      }
    }
  });
}
