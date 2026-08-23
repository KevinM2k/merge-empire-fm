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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';

/// The gold a shopfront puts round the thing in the window. Fixed rather than
/// the club's accent: a featured offer is the STORE speaking, not the club, and
/// half the kits are a shade of green the chrome is already made of.
const Color _featureInk = Color(0xFFFFC542);

class ShopTile extends StatelessWidget {
  const ShopTile({
    super.key,
    required this.tileKey,
    required this.title,
    required this.price,
    required this.tone,
    this.subtitle,
    this.onBuy,
    this.disabledReason,
    this.badge,
    this.glyph,
    this.featured = false,
    this.ribbon,
    this.accent,
  });

  final String tileKey;
  final String title;
  final String price;

  /// What it costs, which is what colours the button — see [StoreButton].
  /// Required rather than defaulted: a tile that forgets its currency looks
  /// exactly like one that is priced in the club's accent, and the whole point
  /// of the colour is that it cannot be guessed wrong quietly.
  final StoreTone tone;
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

  /// **The shelf the shop OPENS on, and width alone did not make it special.**
  /// The three offers were made full-width a pass ago and still drew the same
  /// grey pane as a consumable — the highest-converting slot in the game, in
  /// the shop's furniture. Featured tiles take a gold rim and a gold wash off
  /// the top edge, the glyph goes up, and the title with it: everything a
  /// shopfront does to the thing in the window, and nothing that needs new copy.
  final bool featured;

  /// The corner banner a featured tile wears — `.shop-hero__ribbon` in the
  /// spec, and the loudest thing on the card there.
  ///
  /// **The badge was a line of grey text under the description.** The spec
  /// carries the same words diagonally across the corner, which is what a
  /// shopfront does and what the offers shelf was reported as missing. Only
  /// drawn on a [featured] tile: on a consumable it would be a sale sign on a
  /// tin of beans.
  final String? ribbon;

  /// This product's own colour, for the rim, the glow and the title. Null is
  /// the shelf's gold.
  ///
  /// The spec gives each hero one — VIP purple, the Energy Director blue — so
  /// three offers in a column are three things rather than one repeated.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final ink = accent ?? _featureInk;
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

    final banner = featured ? ribbon : null;
    return Opacity(
      // An owned tile stays on the shelf, knocked back — taking it away loses
      // the answer to "did I buy that already".
      opacity: onBuy == null && disabledReason == null ? 0.62 : 1,
      child: banner == null
          ? _pane(context, kit, ink, lines)
          : ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  _pane(context, kit, ink, lines),
                  // Across the corner at 45 degrees, running off both edges so
                  // the clip is what ends it — which is what makes it a ribbon
                  // rather than a chip that happens to be diagonal.
                  Positioned(
                    top: 16,
                    right: -34,
                    child: Transform.rotate(
                      angle: math.pi / 4,
                      child: Container(
                        key: ValueKey('shop-ribbon-$tileKey'),
                        width: 130,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        color: ink,
                        child: Text(
                          banner.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            // Measured, not guessed: the ribbon takes the
                            // product's own colour and gold wants black on it
                            // where purple wants white.
                            color: ink.computeLuminance() > 0.4
                                ? const Color(0xFF201603)
                                : Colors.white,
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

  Widget _pane(
    BuildContext context,
    KitTheme kit,
    Color ink,
    List<Widget> lines,
  ) {
    return Container(
        key: ValueKey('shop-tile-$tileKey'),
        padding: const EdgeInsets.fromLTRB(9, 12, 9, 10),
        // **THE YELLOW TOP HAS GONE.** A featured tile was a three-stop
        // VERTICAL gradient starting on the feature colour, so the top half
        // faded out of a yellow band that stopped dead in the middle of the
        // card — reported as "the special offers have a weird yellow top", with
        // the spec named. The spec has no such wash: `.shop-hero.is-featured`
        // is the ordinary surface plus a diagonal SHEEN and a corner ribbon,
        // and what marks it out is the border and the glow, both of which stay.
        //
        // **The sheen's SWEEP is not ported.** In the JS it travels across the
        // tile every six seconds; here it is parked where the sweep pauses.
        // A perpetual animation on a scrolling shelf is a repeating controller
        // per tile, and the spec turns the sweep off under reduced motion
        // anyway — so the static highlight is the version that is always right.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kit.surface2, kit.surface],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: featured ? ink.withValues(alpha: 0.65) : kit.border,
            width: featured ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: featured
                  ? ink.withValues(alpha: 0.28)
                  : const Color(0x33000000),
              blurRadius: featured ? 14 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        foregroundDecoration: featured
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  // 105 degrees in the CSS, which is a band leaning right.
                  begin: const Alignment(-1, -0.6),
                  end: const Alignment(1, 0.6),
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.14),
                    Colors.white.withValues(alpha: 0),
                  ],
                  stops: const [0.38, 0.48, 0.58],
                ),
              )
            : null,
        child: featured
            // **A ROW, NOT A COLUMN, once it is full width.** Stacked, an offer
            // is a 62px glyph over a title over two lines over a badge over a
            // full-width button — a card half the height of the shelf, three
            // times over. Reported as still too big after the ribbon landed.
            // The spec lays every hero out exactly this way: art, words, price,
            // left to right (`justify-content:space-between`).
            ? Row(
                children: [
                  if (glyph != null) ...[
                    SizedBox(width: 46, child: Center(child: glyph)),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                            color: ink,
                          ),
                        ),
                        for (final line in lines)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: DefaultTextStyle.merge(
                              textAlign: TextAlign.left,
                              child: line,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  StoreButton(
                    key: ValueKey('shop-buy-$tileKey'),
                    tone: tone,
                    label: price,
                    stretch: false,
                    onTap: onBuy,
                  ),
                ],
              )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (glyph != null)
              SizedBox(height: 46, child: Center(child: glyph)),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
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
            StoreButton(
              key: ValueKey('shop-buy-$tileKey'),
              tone: tone,
              label: price,
              leading: switch (tone) {
                // The wallet, on the button, before the number — the same two
                // marks the HUD shows the balances with, so a price and a
                // balance are read in the same units.
                StoreTone.coin => const CoinIcon(size: 12, solid: true),
                StoreTone.gem => const GameIcon('gem', size: 13),
                // **An ad button says so on the button.** The tone was already
                // the ad yellow and the label is a VERB ("Claim") — which on
                // its own is a free thing rather than a thing you watch a video
                // for, and the disclosure has to come from somewhere.
                StoreTone.ad => const GameIcon('video', size: 13),
                _ => null,
              },
              onTap: onBuy,
            ),
          ],
        ),
    );
  }
}
