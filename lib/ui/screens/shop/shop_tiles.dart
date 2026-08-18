/// One shelf item, in every state it can be in.
///
/// A tile that hides its price stops being an offer; a tile that hides WHY it
/// cannot be bought is just broken. Both stay visible in the disabled state.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

class ShopTile extends StatelessWidget {
  const ShopTile({
    super.key,
    required this.tileKey,
    required this.title,
    required this.price,
    this.subtitle,
    this.onBuy,
    this.disabledReason,
    this.badge,
  });

  final String tileKey;
  final String title;
  final String price;
  final String? subtitle;
  final VoidCallback? onBuy;

  /// Why the button is dead. Rendered under it, never instead of the price.
  final String? disabledReason;

  /// "Most popular", "Owned", a tier name.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final lines = <Widget>[
      if (subtitle != null)
        Text(subtitle!, style: TextStyle(color: kit.textMuted, fontSize: 12)),
      if (badge != null)
        Text(badge!, style: TextStyle(color: kit.accentBright, fontSize: 11)),
      if (disabledReason != null)
        Text(
          disabledReason!,
          style: TextStyle(color: kit.textMuted, fontSize: 11),
        ),
    ];

    return Card(
      key: ValueKey('shop-tile-$tileKey'),
      color: kit.surface,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(title),
        subtitle: lines.isEmpty
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: lines,
              ),
        trailing: ElevatedButton(
          key: ValueKey('shop-buy-$tileKey'),
          onPressed: onBuy,
          child: Text(price),
        ),
      ),
    );
  }
}

/// A tile that reports progress rather than offering a purchase.
///
/// The manager look packs are this: nothing in that section is bought with
/// gems, so a price and a buy button would both be a lie.
class ShopProgressTile extends StatelessWidget {
  const ShopProgressTile({
    super.key,
    required this.tileKey,
    required this.title,
    required this.owned,
    required this.total,
  });

  final String tileKey;
  final String title;
  final int owned;
  final int total;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Card(
      key: ValueKey('shop-tile-$tileKey'),
      color: kit.surface,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(title),
        trailing: Text(
          '$owned/$total',
          style: TextStyle(
            color: owned >= total ? kit.accentBright : kit.textMuted,
          ),
        ),
      ),
    );
  }
}
