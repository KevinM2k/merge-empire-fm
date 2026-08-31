/// **WHAT IS ACTUALLY IN THE BOX, drawn rather than described.**
///
/// Asked for from the couch against a shelf of reference shots, and it is the
/// one device every shop in that set has and this one did not: a strip of small
/// item chips under the offer — a glyph for the thing, a figure for how many —
/// so the contents of a bundle are read in half a second instead of out of a
/// sentence.
///
/// The port's three heroes carried their contents as prose and nothing else:
/// "{coins} coins + 10 Energy — re-granted every reset!" is an accurate line
/// that a player skims past, and on the highest-converting slot in the game it
/// was the only statement of what the money buys.
///
/// **Nothing here needs new copy**, which is why it can exist at all: a chip is
/// an icon and a number, and both come off the product. The prose stays — it is
/// where "permanent, even after resets" lives, and no glyph says that.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/engine/iap_engine.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart'
    show hudCoinInk, hudEnergyInk, hudGemInk;
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/util/format.dart';

/// One thing a pack contains: the glyph, the wallet's colour, and the count.
///
/// [count] is null for the things there is exactly one of — the Vault is not
/// "×1 wardrobe", it is the wardrobe.
typedef PackItem = ({String icon, Color ink, String? count});

/// What [product] pays, as chips, **at the division this save is actually in.**
///
/// The coin figure is [getProductGrantCoins]'s, not the catalogue's: a Starter
/// Pack in the Champions Cup grants a thousand times its printed number, and a
/// strip that shows the printed one is a strip that lies to every player past
/// Sunday League. That function is already the single source of truth for the
/// shop's copy and this is one more caller of it.
///
/// Order is the order a player cares in: hard currency, soft currency, then the
/// things that are neither.
List<PackItem> packContents(IapProduct product, Map<String, dynamic>? state) {
  final coins = getProductGrantCoins(state, product);
  return [
    if ((product.gems ?? 0) > 0)
      (icon: 'gem', ink: hudGemInk, count: '${product.gems}'),
    if (coins > 0)
      (icon: 'coin', ink: hudCoinInk, count: formatCoinsCompact(coins)),
    if ((product.energyAdd ?? 0) > 0)
      (icon: 'bolt', ink: hudEnergyInk, count: '${product.energyAdd}'),
    // A pass is a length of time, so its chip is the clock and its figure the
    // days — the one number on the VIP tile that is not money.
    if ((product.vipDays ?? 0) > 0)
      (
        icon: 'stopwatch',
        ink: const Color(0xFFB77BFF),
        count: '${product.vipDays}',
      ),
    // Neither of these has a quantity. The Vault is every look pack there is
    // and the Director is a permanent upgrade to the tank — a "×1" on either
    // would make a one-off sound like a consumable.
    if (product.styleVault) (icon: 'shirt', ink: const Color(0xFFB98BFF), count: null),
    if (product.energyDirector)
      (icon: 'crown', ink: const Color(0xFFFFD54A), count: null),
  ];
}

/// The strip, as the offers wear it.
///
/// **It wraps rather than scrolls.** The reference shops run theirs off the
/// right-hand edge with a half-chip showing, which is a promise that swiping
/// reveals more; nothing here has more than four chips, so a strip that could
/// scroll would be a scroll affordance over content that always fits.
class PackContentsRow extends StatelessWidget {
  const PackContentsRow({
    super.key,
    required this.items,
    this.size = 34,
    this.tileKey,
  });

  final List<PackItem> items;

  /// The chip's side. The offers draw them at 34; a smaller shelf could ask for
  /// less without the numbers colliding, which is why it is a parameter and not
  /// a constant.
  final double size;

  /// The product this strip belongs to, for a test to find one strip among
  /// three on the same shelf.
  final String? tileKey;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(
      key: tileKey == null ? null : ValueKey('shop-contents-$tileKey'),
      spacing: 6,
      runSpacing: 6,
      children: [for (final item in items) _Chip(item: item, size: size)],
    );
  }
}

/// One item, in a box of its own.
///
/// A rounded square in the wallet's own hue, with the count on a dark strip
/// along the bottom — the count is a different KIND of thing from the glyph
/// above it, and stacking them without the strip makes a two-digit figure read
/// as part of the picture.
class _Chip extends StatelessWidget {
  const _Chip({required this.item, required this.size});

  final PackItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final radius = BorderRadius.circular(size * 0.26);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(item.ink.withValues(alpha: 0.34), kit.surface2),
            Color.alphaBlend(item.ink.withValues(alpha: 0.16), kit.surface),
          ],
        ),
        border: Border.all(color: item.ink.withValues(alpha: 0.55)),
        boxShadow: const [
          BoxShadow(color: Color(0x3D000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The glyph sits ABOVE centre when there is a strip under it, so the
            // count does not sit on its feet.
            Padding(
              padding: EdgeInsets.only(bottom: item.count == null ? 0 : size * 0.26),
              child: GameIcon(item.icon, size: size * 0.52, color: item.ink),
            ),
            if (item.count case final count?)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.42),
                  padding: const EdgeInsets.symmetric(vertical: 0.5),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        count,
                        style: TextStyle(
                          fontSize: size * 0.27,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
