/// **THE THREE DEVICES A SHOPFRONT HAS AND THIS SHOP DID NOT.**
///
/// Asked for from the couch against a shelf of reference shots: a panel the tabs
/// open into, a corner flash on the value claims, and a strip of item chips
/// saying what is actually in the box. None of them needs new copy, which is why
/// all three could land — the catalogues are generated from the JS and no `t()`
/// key can be added from this repo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/iap_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/shop/pack_contents.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_paid.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_screen.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_section.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_tiles.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/util/format.dart';

import 'shop_helpers.dart';
// The whole-screen pump lives with the screen's own tests; the panel is a
// property of the screen, so this file borrows it rather than building a second.
import 'shop_screen_test.dart' show pumpShop;

void main() {
  tearDown(resetLocale);

  /// **A VALUE CLAIM IS A BANNER, not a rosette stuck on the corner.**
  ///
  /// Both shelves wore a die-cut seal for a pass; asked for again from the
  /// couch, with the banner named. On a tile this size a rosette sat over the
  /// pile it was recommending and shoved the crown across to the other corner to
  /// make room for itself, and it is the second device in a shop that already
  /// has one — the offers hero's corner flash.
  group('A VALUE CLAIM IS A CORNER FLASH, not a rosette', () {
    testWidgets('the coin shelf flashes its badges', (tester) async {
      await pumpShopWidget(tester, (_) {}, CoinPacksSection.new);
      final popular = find.byKey(const ValueKey('shop-badge-coins_medium'));
      expect(popular, findsOneWidget);
      expect(
        tester.widget(popular),
        isA<CornerBanner>(),
        reason: 'the popular tag went back to being a rosette',
      );
      // It still says the shipped words — a banner is a shape, not new copy.
      expect(
        find.descendant(
          of: popular,
          matching: find.text(t('shop.most_popular').toUpperCase()),
        ),
        findsOneWidget,
      );
    });

    testWidgets('and the gem shelf wears the SAME one', (tester) async {
      // Two shelves saying similar things in two shapes is two devices; the
      // whole value of the flash is that it is the one object a claim comes in.
      await pumpShopWidget(tester, (_) {}, GemPacksSection.new);
      final bonus = getShopProducts().firstWhere(
        (p) => p.category == 'gems' && p.bonus != null,
      );
      final flash = find.byKey(ValueKey('shop-seal-${bonus.id}'));
      expect(flash, findsOneWidget);
      expect(tester.widget(flash), isA<CornerBanner>());
    });

    testWidgets('and it is CUT BY the tile rather than stuck over it', (
      tester,
    ) async {
      await pumpShopWidget(tester, (_) {}, CoinPacksSection.new);
      final flash = tester.getRect(
        find.byKey(const ValueKey('shop-badge-coins_medium')),
      );
      final tile = tester.getRect(
        find.byKey(const ValueKey('shop-tile-coins_medium')),
      );
      // A banner is part of the tile: inside its bounds, in the top-right
      // corner. The seal it replaces hung off the corner on purpose, which is
      // the difference between the two devices.
      expect(flash.top, greaterThanOrEqualTo(tile.top - 0.5));
      expect(flash.right, lessThanOrEqualTo(tile.right + 0.5));
      expect(
        flash.right,
        greaterThan(tile.right - flash.width),
        reason: 'the flash has drifted off the corner it runs across',
      );
    });

    /// **THE TEXT SITS IN THE MIDDLE OF WHAT IS SEEN.**
    ///
    /// The bar was placed by its top edge and then rotated about its own centre,
    /// so where it landed depended on how tall the text rendered — and measured,
    /// its centre was 12pt up the band from the middle of the visible chord.
    /// Reported from the couch on the offers hero.
    testWidgets('and its words are centred on the band, not up one end', (
      tester,
    ) async {
      await pumpShopWidget(tester, (_) {}, CoinPacksSection.new);
      final flash = tester.getRect(
        find.byKey(const ValueKey('shop-badge-coins_medium')),
      );
      final tile = tester.getRect(
        find.byKey(const ValueKey('shop-tile-coins_medium')),
      );
      final words = tester.getRect(
        find.descendant(
          of: find.byKey(const ValueKey('shop-badge-coins_medium')),
          matching: find.byKey(const ValueKey('shop-corner-banner')),
        ),
      );
      // The band runs across a right-angle corner at 45 degrees, so the middle
      // of the visible run is the foot of the perpendicular from the corner —
      // equidistant from the two edges it crosses. Which is to say: as far in
      // from the tile's right edge as it is down from its top.
      final inFromRight = tile.right - words.center.dx;
      final downFromTop = words.center.dy - tile.top;
      expect(
        inFromRight,
        closeTo(downFromTop, 3),
        reason: 'the words are up one end of the band, not in the middle',
      );
      expect(flash.contains(words.center), isTrue);
    });
  });

  group('WHAT IS IN THE BOX, drawn', () {
    testWidgets('every offer states its contents as chips', (tester) async {
      // The three heroes carried their contents as prose and nothing else, on
      // the highest-converting slot in the game.
      await pumpShopWidget(tester, (_) {}, OffersSection.new);
      for (final product in getShopProducts()) {
        if (product.category != 'bundle' && product.category != 'vip') continue;
        expect(
          find.byKey(ValueKey('shop-contents-${product.id}')),
          findsOneWidget,
          reason: '${product.id} says nothing about what it pays',
        );
      }
    });

    testWidgets('and a grid tile does NOT — it has no room and no need', (
      tester,
    ) async {
      // A two-across tile is a picture, a name, a line and a button; a strip in
      // it would be the description twice, in less space.
      await pumpShopWidget(tester, (_) {}, CoinPacksSection.new);
      expect(find.byType(PackContentsRow), findsNothing);
    });

    testWidgets('THE COIN FIGURE IS THIS SAVE\'S, not the catalogue\'s', (
      tester,
    ) async {
      // A Starter Pack in the Champions Cup grants a thousand times its printed
      // number — `getProductGrantCoins` is the shop's single source of truth for
      // that and this is one more caller of it. A strip showing the printed
      // figure would lie to every player past Sunday League.
      final starter = getProduct('starter_pack')!;
      final state = {
        'progression': {'currentDivision': 'elite_league'},
      };
      final items = packContents(starter, state);
      final coins = items.singleWhere((i) => i.icon == 'coin');
      expect(
        coins.count,
        formatCoinsCompact(getProductGrantCoins(state, starter)),
      );
      expect(
        coins.count,
        isNot(formatCoinsCompact(starter.coins!)),
        reason: 'the division multiplier was dropped on the floor',
      );
    });

    testWidgets('and the one-offs carry no count at all', (tester) async {
      // The Vault is every look pack there is, not "×1 wardrobe". A quantity on
      // a one-off makes it sound like a consumable.
      final vault = packContents(getProduct('style_vault')!, null);
      expect(vault, isNotEmpty);
      expect(vault.every((i) => i.count == null), isTrue);
    });

    testWidgets('a chip is a glyph and a figure, and the glyph is drawn', (
      tester,
    ) async {
      await pumpShopWidget(tester, (_) {}, OffersSection.new);
      final strip = find.byKey(const ValueKey('shop-contents-vip_pass'));
      expect(
        find.descendant(of: strip, matching: find.byType(GameIcon)),
        findsNWidgets(packContents(getProduct('vip_pass')!, null).length),
      );
    });
  });

  group('THE TABS OPEN INTO A PANEL', () {
    testWidgets('the selected tab is the panel\'s own fill', (tester) async {
      // The strip already broke its baseline under the selected tab, which is
      // the join — but there was nothing on the other side of it to join TO, so
      // the gap opened onto the club backdrop and the tabs went back to reading
      // as a row of links. A join between two different colours is a seam.
      await pumpShop(tester, (_) {});
      final kit = Theme.of(
        tester.element(find.byType(ShopScreen)),
      ).extension<KitTheme>()!;
      final fill =
          (tester
                      .widget<DecoratedBox>(
                        find
                            .descendant(
                              of: find.byKey(
                                ValueKey('shop-tab-${shopTabSlug(shopTabs[0])}'),
                              ),
                              matching: find.byType(DecoratedBox),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration)
              .color!;
      expect(
        fill,
        Color.alphaBlend(
          shopTabs[0].ink.withValues(alpha: 0.16),
          shopPanelInk(kit),
        ),
        reason: 'the selected tab is a different colour from what it opens into',
      );
    });

    testWidgets('AND THE PANEL KEEPS THE STRIP\'S OWN MARGIN', (tester) async {
      // The strip is inset either side and the panel ran to both edges of the
      // phone, so the thing the tabs are supposed to be standing on was wider
      // than they were. Reported from the couch.
      await pumpShop(tester, (_) {});
      final tabs = tester.getRect(find.byKey(const ValueKey('shop-tabs')));
      // The scroll view fills the panel exactly — its own padding is inside it.
      final panel = tester.getRect(find.byKey(const ValueKey('shop-scroll')));
      expect(panel.left, closeTo(tabs.left, 0.5));
      expect(panel.right, closeTo(tabs.right, 0.5));
      expect(panel.left, greaterThan(0), reason: 'still flush to the glass');
    });

    testWidgets('and an unselected tab stands SHORTER, so the strip stacks', (
      tester,
    ) async {
      // Four tabs of one height differing only in fill is a segmented control.
      // A tab that is behind the others is physically further back.
      await pumpShop(tester, (_) {});
      final selected = tester.getRect(
        find.descendant(
          of: find.byKey(ValueKey('shop-tab-${shopTabSlug(shopTabs[0])}')),
          matching: find.byType(DecoratedBox),
        ).first,
      );
      final other = tester.getRect(
        find.descendant(
          of: find.byKey(ValueKey('shop-tab-${shopTabSlug(shopTabs[1])}')),
          matching: find.byType(DecoratedBox),
        ).first,
      );
      expect(other.top, greaterThan(selected.top));
      expect(
        other.bottom,
        closeTo(selected.bottom, 1),
        reason: 'the tabs no longer share a baseline',
      );
    });
  });
}
