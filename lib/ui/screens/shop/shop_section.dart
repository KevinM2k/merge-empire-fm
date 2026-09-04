/// The shared section frame. Seven shelves, one heading treatment.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/section_heading.dart';

/// The seven shelves, in display order.
///
/// The order is not arbitrary and was arrived at by fixing a mess: offers and
/// passes first (the highest-converting slot), then the free shelf — the reason
/// a non-payer opens the shop at all — then hard currency before soft, then the
/// things those currencies buy, then cosmetics. What it replaced had coins split
/// across two sections with a cash section wedged between them.
enum ShopSectionId {
  offers('shop.section.offers', Icons.local_offer, Color(0xFFFFB300)),

  /// **THERE WAS A `matchDay` SHELF HERE and its two tiles moved.** It began as
  /// `free` — both were rewarded-ad grants under a heading that said Free,
  /// which made the two things that most change how a match goes the two things
  /// a player could only get by watching an advert — and became Match Day once
  /// they cost gems. What finished it was the tab: Boosts holds four shelves
  /// and is NAMED for the first of them, so a two-tile heading eighteen points
  /// under Boosts & Items was subdividing a shelf the player reads as one
  /// thing. Asked for from the couch. The tiles are on the end of the Boosts
  /// grid now — see `matchDayTiles`.
  gems('shop.section.gems', Icons.diamond, Color(0xFF7FD4FF)),
  coins('shop.section.coins', Icons.monetization_on, Color(0xFFFFC83C)),
  boosts('shop.section.boosts', Icons.bolt, Color(0xFF66BB6A)),

  /// **THE BOOSTS SHELF WAS TWO SHELVES.** A Magic Sponge and an Energy Refill
  /// fix the squad; a Kit Sponsor, a TV deal and Trophy Polish multiply what it
  /// earns. Those are two different questions a player comes to the shop with,
  /// and one heading over both of them answered neither. Asked for from the
  /// couch: split the boosts from the income. See [incomeShelfIds].
  income('shop.section.income', Icons.trending_up, Color(0xFF66BB6A)),
  vouchers(
    'shop.section.vouchers',
    Icons.confirmation_number,
    Color(0xFF66BB6A),
  ),
  looks('shop.section.looks', Icons.checkroom, Color(0xFFB98BFF));

  const ShopSectionId(this.titleKey, this.icon, this.ink);

  final String titleKey;

  /// Line art, not emoji: a section heading is interface.
  final IconData icon;

  /// **Each shelf has its OWN colour**, and that is what makes seven of them
  /// scannable. Painting them all in the club's accent — which the port did —
  /// turns the shop into one long undifferentiated list, and the whole point of
  /// a section heading is that you can find your way back to it.
  ///
  /// The solid value; the rule under it uses a translucent version, because
  /// line art washes out at the rule's alpha.
  final Color ink;
}

const List<ShopSectionId> shopSectionOrder = ShopSectionId.values;

/// **THE SHOP IS TABBED, because seven shelves on one page is too much.**
/// Asked for directly, with the categories left open.
///
/// A tab is a GROUP of the shelves that already exist rather than a new
/// taxonomy: the sections keep their colours and their order, and what changes
/// is how many of them you are looking at. Every tab is labelled with a shipped
/// `shop.section.*` key, because the catalogues are generated from the JS and a
/// new one was not available.
///
/// **Four tabs, not five.** Gems and coin packs both sell a BALANCE and both
/// rows state their own price, so splitting them bought a player nothing and
/// cost them a tab — the label is `shop.section.premium`, which is shipped in
/// ten languages and which the JS itself never printed. The free shelf moved
/// out of Offers as well: a quick-fire match and a lucky boot are things that
/// make your next match go better, which is what the boosts tab is, and the
/// only thing separating them was that they cost a video rather than a coin.
typedef ShopTab = ({
  String titleKey,
  IconData icon,
  Color ink,
  List<ShopSectionId> sections,
});

const List<ShopTab> shopTabs = [
  (
    titleKey: 'shop.section.offers',
    icon: Icons.local_offer,
    ink: Color(0xFFFFB300),
    sections: [ShopSectionId.offers],
  ),
  (
    titleKey: 'shop.section.premium',
    icon: Icons.diamond,
    ink: Color(0xFF7FD4FF),
    sections: [ShopSectionId.gems, ShopSectionId.coins],
  ),
  (
    titleKey: 'shop.section.boosts',
    icon: Icons.bolt,
    ink: Color(0xFF66BB6A),
    sections: [
      ShopSectionId.boosts,
      ShopSectionId.income,
      // The voucher ladder last: it is eight tiles and it buried everything
      // above it when it sat higher.
      ShopSectionId.vouchers,
    ],
  ),
  (
    titleKey: 'shop.section.looks',
    icon: Icons.checkroom,
    ink: Color(0xFFB98BFF),
    sections: [ShopSectionId.looks],
  ),
];

/// Which tab holds a shelf. Every shelf is in exactly one, and a section added
/// to the enum without a tab would be unreachable — so this returns -1 rather
/// than silently hiding it, and the deep link checks.
int shopTabOf(ShopSectionId id) =>
    shopTabs.indexWhere((tab) => tab.sections.contains(id));

/// The tab's identity in a widget key, off its own label rather than an index —
/// so a reordered strip does not silently move a test's target.
String shopTabSlug(ShopTab tab) => tab.titleKey.split('.').last;

/// **A SHELF ONLY WEARS A HEADING WHEN THE TAB HAS NOT ALREADY SAID IT.**
///
/// Asked for directly: the tab carries the name now, so a frame that repeats it
/// prints the same word twice, eighteen points apart. What survives is the case
/// the tab cannot cover — a tab holding several shelves, where the second and
/// third still have to be told apart.
///
/// **AND THE SHELF THE TAB IS NAMED AFTER IS NOT AN EXCEPTION TO THAT.** It
/// used to go bare on the same "the tab already said it" reasoning, which put
/// the Magic Sponge and the Energy Refill under nothing at the top of the
/// Boosts tab with Income, Match Day and Vouchers all headed below them — so
/// the two tiles read as loose stock above the shop rather than as the shelf
/// the tab opens on. Reported from the couch. The rule the exception was
/// protecting only ever applied to a tab of ONE shelf, and that case is still
/// bare because the count test below is what carries it.
bool sectionNeedsHeading(ShopSectionId id) {
  final index = shopTabOf(id);
  if (index < 0) return true;
  return shopTabs[index].sections.length > 1;
}

class ShopSectionFrame extends StatelessWidget {
  const ShopSectionFrame({
    super.key,
    required this.id,
    required this.child,
    this.note,
  });

  final ShopSectionId id;
  final Widget child;

  /// Said once, about the whole section. The voucher ladder's one-at-a-time rule
  /// is the answer to "why can't I buy this one" for all eight rungs at once,
  /// and repeating it per tile is worse rather than clearer.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final headed = sectionNeedsHeading(id);
    return Padding(
      key: ValueKey('shop-section-${id.name}'),
      // A headed shelf needs air above it to sit under; a bare one is already
      // under the tab that names it and the same 18 reads as a dropped row.
      padding: EdgeInsets.fromLTRB(12, headed ? 18 : 2, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The shop's own heading, which the trophy room now wears too —
          // see [SectionHeading], where this row lives.
          if (headed)
            SectionHeading(title: t(id.titleKey), icon: id.icon, ink: id.ink),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                note!,
                style: TextStyle(color: kit.textMuted, fontSize: 12),
              ),
            ),
          if (headed || note != null) const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// A shelf, laid out.
///
/// The column count is per-shelf and MEASURED rather than picked — the JS notes
/// that the voucher shelf is three across because at the shop's own type sizes
/// "WORLD CLASS" is 103px of text, and four across gives each tile 78px, which
/// wraps the name and pushes the description to three lines.
class ShopGrid extends StatelessWidget {
  const ShopGrid({required this.children, this.columns = 2, super.key});

  final List<Widget> children;
  final int columns;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    // ROWS OF EQUAL COLUMNS, sized to their CONTENT — not a grid with an aspect
    // ratio. An aspect ratio decides a tile's height from its width, so a tile
    // holding a title, a line of description and a button was given a box half
    // as tall again as it needed and had to fill the difference with a `Spacer`.
    // That gap is the same on every tile in the shop, under every title, and it
    // is why the shelves read as half empty.
    //
    // `IntrinsicHeight` is what keeps the two tiles in a row the same height as
    // each other — which is the one thing the aspect ratio was genuinely buying
    // — while letting the ROW be as tall as its tallest tile and no taller.
    final rows = <List<Widget>>[];
    for (var i = 0; i < children.length; i += columns) {
      rows.add(children.sublist(i, math.min(i + columns, children.length)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: 10),
                  // The last row can be short; the empty columns still take
                  // their share so the tiles that ARE there keep their width
                  // rather than stretching across the shelf.
                  Expanded(
                    child: c < rows[r].length
                        ? rows[r][c]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
