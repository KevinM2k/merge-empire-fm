/// The real-money shelves: Offers, Gems and Coins, plus Restore Purchases.
///
/// Every control here is DEAD until M4 lands the billing bridge, and every tile
/// still shows its real price — a shelf that hides its prices stops being a
/// shop. `purchaseProduct` is deliberately not called anywhere in this file: it
/// is the GRANT step, what runs once a store has confirmed a payment, so a
/// button wired to it would hand out paid goods for free.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_providers.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_section.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_tiles.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// Said on every real-money control, so a player is told the feature is coming
/// rather than left with a button that does nothing.
String paidDisabledReason() => t('settings.comingSoon');

class _PaidShelf extends ConsumerWidget {
  const _PaidShelf({required this.id, required this.categories});

  final ShopSectionId id;
  final Set<String> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref
        .watch(shopProductsProvider)
        .where((p) => categories.contains(p.category))
        .toList();
    return ShopSectionFrame(
      id: id,
      child: ShopGrid(
        children: [
          for (final product in products)
            ShopTile(
              tileKey: product.id,
              title: product.name,
              subtitle: product.desc,
              price: product.price,
              badge: product.popular ? t('shop.most_popular') : null,
              disabledReason: paidDisabledReason(),
            ),
        ],
      ),
    );
  }
}

/// One-time and time-limited real-money items — the highest-converting slot,
/// which is why it is first.
class OffersSection extends StatelessWidget {
  const OffersSection({super.key});

  @override
  Widget build(BuildContext context) =>
      const _PaidShelf(id: ShopSectionId.offers, categories: {'bundle', 'vip'});
}

/// Hard currency, and the only way to buy it — there is deliberately no
/// coin-to-gem exchange.
class GemPacksSection extends StatelessWidget {
  const GemPacksSection({super.key});

  @override
  Widget build(BuildContext context) =>
      const _PaidShelf(id: ShopSectionId.gems, categories: {'gems'});
}

/// Soft currency. The HUD's "+" deep-links here, so its position in the list
/// does not govern how players reach it.
class CoinPacksSection extends StatelessWidget {
  const CoinPacksSection({super.key});

  @override
  Widget build(BuildContext context) =>
      const _PaidShelf(id: ShopSectionId.coins, categories: {'coins'});
}

/// Required by App Store guidelines, and correctly the LAST thing on the screen
/// rather than buried mid-shop.
class RestoreRow extends StatelessWidget {
  const RestoreRow({super.key});

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 32),
      child: ShopGrid(
        children: [
          OutlinedButton(
            key: const ValueKey('shop-restore'),
            onPressed: null,
            child: Text(t('shop.restore_purchases')),
          ),
          const SizedBox(height: 4),
          Text(
            paidDisabledReason(),
            style: TextStyle(color: kit.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
