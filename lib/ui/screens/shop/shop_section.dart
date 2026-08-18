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
  offers('shop.section.offers', Icons.local_offer),
  free('shop.section.free', Icons.card_giftcard),
  gems('shop.section.gems', Icons.diamond),
  coins('shop.section.coins', Icons.monetization_on),
  boosts('shop.section.boosts', Icons.bolt),
  vouchers('shop.section.vouchers', Icons.confirmation_number),
  looks('shop.section.looks', Icons.checkroom);

  const ShopSectionId(this.titleKey, this.icon);

  final String titleKey;

  /// Line art, not emoji: a section heading is interface.
  final IconData icon;
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kit.accent.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(id.icon, size: 16, color: kit.accent),
              ),
              const SizedBox(width: 8),
              Text(
                t(id.titleKey),
                style: TextStyle(
                  color: kit.accentBright,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Divider(color: kit.border)),
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
