/// One shelf item, in every state it can be in.
///
/// A tile that hides its price stops being an offer; a tile that hides WHY it
/// cannot be bought is just broken. Both stay visible in the disabled state.
///
/// **A CARD, not a list row.** These were `ListTile`s in a column, which is a
/// settings screen rather than a shop — the JS lays every shelf out as a grid of
/// centred cards with the glyph on top, the price on a button pinned to the
/// bottom, and every button in a row lining up whatever the text above it does.
/// That last part is why the description clamps to two lines: without it one
/// long one sets the height of the whole row.
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
    this.glyph,
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

  /// The art on top, and the first thing scanned.
  ///
  /// A WIDGET rather than an emoji. The JS puts `p.icon` here — a literal 🎁 or
  /// 💎 — because its `icon` field is plain text that the toast also renders. On
  /// this side the two are separate: the toast can keep the emoji and the tile
  /// gets the app's own line art (`game_icon.dart`) or, for the coin packs, a
  /// drawn picture of the thing it is named after.
  final Widget? glyph;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final lines = <Widget>[
      if (subtitle != null)
        Text(
          subtitle!,
          textAlign: TextAlign.center,
          // Two lines then ellipsis: descriptions run from three words to a
          // sentence, and without the clamp one long one sets the height of its
          // whole row.
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: kit.textMuted, fontSize: 11, height: 1.3),
        ),
      if (badge != null)
        Text(
          badge!,
          textAlign: TextAlign.center,
          style: TextStyle(color: kit.accentBright, fontSize: 11),
        ),
      if (disabledReason != null)
        Text(
          disabledReason!,
          textAlign: TextAlign.center,
          style: TextStyle(color: kit.textMuted, fontSize: 11),
        ),
    ];

    return Opacity(
      // An owned tile stays on the shelf, knocked back — taking it away loses
      // the answer to "did I buy that already".
      opacity: onBuy == null && disabledReason == null ? 0.62 : 1,
      child: Container(
        key: ValueKey('shop-tile-$tileKey'),
        padding: const EdgeInsets.fromLTRB(9, 12, 9, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kit.surface2, kit.surface],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kit.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (glyph != null)
              SizedBox(height: 46, child: Center(child: glyph)),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            for (final line in lines)
              Padding(padding: const EdgeInsets.only(top: 2), child: line),
            // Pushes the button down so every one in a row lines up however
            // tall the text above it is. The row is now only as tall as its
            // tallest tile (see `ShopGrid`), so on that tile this is nothing and
            // on its shorter neighbour it is the difference — which is what it
            // was always supposed to be, rather than half the tile.
            const Spacer(),
            const SizedBox(height: 10),
            ElevatedButton(
              key: ValueKey('shop-buy-$tileKey'),
              onPressed: onBuy,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Text(price, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
