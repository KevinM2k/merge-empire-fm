/// The shared section frame. Seven shelves, one heading treatment.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// The seven shelves, in display order.
///
/// The order is not arbitrary and was arrived at by fixing a mess: offers and
/// passes first (the highest-converting slot), then the free shelf — the reason
/// a non-payer opens the shop at all — then hard currency before soft, then the
/// things those currencies buy, then cosmetics. What it replaced had coins split
/// across two sections with a cash section wedged between them.
enum ShopSectionId {
  offers('shop.section.offers', Icons.local_offer, Color(0xFFFFB300)),
  free('shop.section.free', Icons.card_giftcard, Color(0xFFFFD54A)),
  gems('shop.section.gems', Icons.diamond, Color(0xFF7FD4FF)),
  coins('shop.section.coins', Icons.monetization_on, Color(0xFFFFC83C)),
  boosts('shop.section.boosts', Icons.bolt, Color(0xFF66BB6A)),
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
    return Padding(
      key: ValueKey('shop-section-${id.name}'),
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // NO DISC. Every icon in this shop used to sit in a bordered,
              // tinted box and the gem tiles never did — and the gem tiles are
              // the ones that look right. A frame around a glyph adds a
              // rectangle competing with the card's own edge and shrinks the art
              // to pay for it. Bigger glyph, no box.
              Icon(id.icon, size: 20, color: id.ink),
              const SizedBox(width: 8),
              Text(
                t(id.titleKey).toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 8),
              // The rule runs to the right edge and fades out. It stops the
              // heading floating unattached above its content, and does most of
              // the work of "this is a section" without a heavy container round
              // everything.
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        id.ink.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                note!,
                style: TextStyle(color: kit.textMuted, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
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
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      // Taller than wide: the glyph, two lines of text and a button stack up.
      childAspectRatio: columns >= 3 ? 0.72 : 0.95,
      children: children,
    );
  }
}
