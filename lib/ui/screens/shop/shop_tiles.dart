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
import 'package:merge_empire_fc/ui/screens/shop/shop_shine.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart'
    show readableInk;
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart' show minFontSize;

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
    this.warnReason = false,
    this.badge,
    this.glyph,
    this.featured = false,
    this.ribbon,
    this.corner,
    this.accent,
    this.skin,
    this.contents,
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

  /// Whether [disabledReason] is a precondition the player can act on rather
  /// than a state they are already in. Owned and Active are good news and stay
  /// muted; "No injured players!" is the tile explaining why the thing would do
  /// nothing, and in muted grey it read as a second line of description.
  final bool warnReason;

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

  /// The badge a featured tile wears — "ONE-TIME", "REACTIVATE", a bonus line.
  ///
  /// **A CHIP BESIDE THE TITLE, not a corner ribbon.** It was drawn diagonally
  /// across the top-right corner, which on a full-width hero is exactly where
  /// the buy button is — reported as the badge sitting on top of the button.
  /// The corner ribbon was the port's own: `.shop-hero__ribbon` exists in the
  /// stylesheet but none of the three heroes carries it, and `_renderPremium`
  /// puts this text inline next to the name in a gold-on-gold chip. That is
  /// also the version with somewhere to go — the hero is a row with room beside
  /// the title and none over the button.
  final String? ribbon;

  /// **THE CORNER FLASH — "MOST POPULAR", drawn diagonally across the top
  /// right.** `.shop-hero__ribbon` in the stylesheet, which the port had left
  /// unused.
  ///
  /// It was tried in this corner once and taken out again, because on a
  /// full-width hero laid out as one row that corner is exactly where the buy
  /// button sits. What changed is the hero: the price is on its own line at the
  /// bottom now, so the corner is empty and the flash goes where a shopfront
  /// puts one. Asked for by name from the couch.
  ///
  /// [ribbon] is a different thing and they can both be on: that is the chip
  /// beside the title — "ONE-TIME", "REACTIVATE", a bonus line — and this is
  /// the shelf saying which one everybody buys.
  final String? corner;

  /// This product's own colour, for the rim, the glow and the title. Null is
  /// the shelf's gold.
  ///
  /// The spec gives each hero one — VIP purple, the Energy Director blue — so
  /// three offers in a column are three things rather than one repeated.
  final Color? accent;

  /// This hero's own background and rim — `.premium-vip`, `.premium-starter`,
  /// `.premium-director`.
  ///
  /// **The three offers were the shelf's grey surface, three times.** Each has
  /// its own deep gradient in the spec — purple into black, green into purple,
  /// blue into green — and that is the whole reason the shop's best slot looks
  /// like a shopfront rather than a list. Dark in both themes, as the spec's
  /// are: the light-mode overrides in `screens.css` cover the energy cards and
  /// deliberately leave these alone.
  final ({Gradient gradient, Color border, double width})? skin;

  /// **THE STRIP THAT SAYS WHAT IS IN THE BOX** — see `pack_contents.dart`.
  ///
  /// Featured only, and it goes on the price's own line, to its left: that line
  /// was a button pushed against the right edge with the whole width of the
  /// hero empty beside it, which is the room a contents strip wants and the
  /// reason the price moved down there in the first place. On a two-across grid
  /// tile there is no such room and the description is already the whole story.
  final Widget? contents;

  /// Reads on [skin]'s gradient. The heroes are dark whatever the theme, so
  /// their text cannot come from the kit.
  static const Color _skinInk = Color(0xFFE8EAF0);

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    // **`readableInk` DARKENS FOR A LIGHT GROUND, and a skinned hero has not
    // got one.** The three offers are the spec's own deep gradients in both
    // themes, so taking VIP's purple down to 34% lightness for "light mode" put
    // it on near-black. These colours were chosen against near-black in the
    // first place, which is exactly the case `readableInk` exists to leave
    // alone.
    final ink = skin != null
        ? (accent ?? _featureInk)
        : readableInk(context, accent ?? _featureInk);
    // **EVERY LINE CARRIES ITS OWN ALIGNMENT, because an inherited one loses.**
    // A grid tile is centred and a hero is a left-aligned column beside its art;
    // the hero branch used to say so by wrapping each line in a
    // `DefaultTextStyle.merge(textAlign: left)`, which does nothing at all here
    // — `Text.textAlign`, when it is set, beats the inherited default outright.
    // So the offers ran a centred description under a left-aligned title inside
    // a left-aligned block, which is what "the text is like centered on the
    // right hand side" was.
    final align = featured ? TextAlign.left : TextAlign.center;
    final lines = <Widget>[
      if (subtitle != null)
        Text(
          subtitle!,
          textAlign: align,
          // Clamped, or one long description sets the height of its whole
          // row. A featured hero gets a line more and a size up: it is one
          // tile to a row, so nothing is measured against it, and the offers
          // are the descriptions actually worth reading.
          maxLines: featured ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: skin == null ? kit.textMuted : _skinInk,
            fontSize: featured ? 12.5 : minFontSize,
            height: 1.35,
          ),
        ),
      if (badge != null)
        Text(
          badge!,
          textAlign: align,
          style: TextStyle(color: kit.accentBright, fontSize: 12),
        ),
      if (disabledReason != null)
        Text(
          disabledReason!,
          textAlign: align,
          style: TextStyle(
            color: warnReason ? dangerInk : kit.textMuted,
            fontSize: 12,
            fontWeight: warnReason ? FontWeight.w700 : null,
          ),
        ),
    ];

    return Opacity(
      // An owned tile stays on the shelf, knocked back — taking it away loses
      // the answer to "did I buy that already".
      opacity: onBuy == null && disabledReason == null ? 0.62 : 1,
      // **CLIPPED, because the corner flash runs off the corner.** It is a bar
      // laid across the top-right at 45 degrees and the tile's rounded rect is
      // what makes it a triangle rather than a stray rectangle.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            _pane(context, kit, ink, lines),
            // **LIFE, and most of it on the offers.** Asked for from the
            // couch: the boxes want to move a little, the special offers
            // especially. A featured tile is the shopfront window, so it gets
            // the sweep AND four twinkles; every other tile gets the sweep
            // alone, because a shelf where all eight sparkle is a fruit
            // machine. See [TileShine] — it costs one painter and it stops
            // dead under `disableAnimations`.
            Positioned.fill(
              child: TileShine(
                radius: 14,
                sparkles: featured ? 4 : 0,
                seed: tileKey.hashCode,
                tint: featured ? ink : Colors.white,
              ),
            ),
            if (corner case final flash?)
              Positioned(
                top: 0,
                right: 0,
                child: CornerBanner(text: flash, ink: ink),
              ),
          ],
        ),
      ),
    );
  }

  /// `product.starter_pack.badge_onetime` and its siblings, as the spec draws
  /// them: gold on a translucent gold field, inside a gold hairline, sitting on
  /// the title's own line.
  Widget _chip(String text, Color ink) => Container(
    key: ValueKey('shop-ribbon-$tileKey'),
    padding: const EdgeInsets.fromLTRB(6, 1, 6, 1),
    decoration: BoxDecoration(
      color: ink.withValues(alpha: 0.15),
      border: Border.all(color: ink.withValues(alpha: 0.33)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.6,
        color: ink,
      ),
    ),
  );

  Widget _pane(
    BuildContext context,
    KitTheme kit,
    Color ink,
    List<Widget> lines,
  ) {
    return Container(
        key: ValueKey('shop-tile-$tileKey'),
        padding: featured
            ? const EdgeInsets.fromLTRB(14, 16, 14, 14)
            : const EdgeInsets.fromLTRB(9, 12, 9, 10),
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
          gradient:
              skin?.gradient ??
              LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kit.surface2, kit.surface],
              ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                skin?.border ??
                (featured ? ink.withValues(alpha: 0.65) : kit.border),
            width: skin?.width ?? (featured ? 1.5 : 1),
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
            // **ART AND WORDS ACROSS, PRICE UNDERNEATH.** The hero was one row
            // — art, words, price, left to right — which fitted the shelf into
            // three short bands and then reported back as a shopfront with a
            // lot of empty page under it. It is the highest-converting slot in
            // the game and it was the smallest thing on the screen.
            //
            // So the art is half again as big, the description gets its third
            // line back, and the price moves to its own line at the bottom
            // right. That last part is not only room: a price parked in the
            // top-right corner is what stopped this tile carrying a corner
            // flash the last time one was tried. See [corner].
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // **THE WORDS KEEP OUT OF THE FLASH'S WAY.** The corner banner
                  // is drawn as a sibling of this pane, and the hero's words
                  // start at the art's right shoulder and run to the tile's own
                  // edge — so "MOST POPULAR" was laid straight across the name
                  // of the thing it was recommending. Reported from the couch.
                  // Only this row is inset: the price line beneath it is well
                  // clear of the corner and a button pushed 48pt off the right
                  // edge would read as unfinished.
                  Padding(
                  padding: EdgeInsets.only(
                    right: corner == null ? 0 : CornerBanner.clearance,
                  ),
                  child: Row(
                    // **THE ART IS CENTRED AGAINST THE WORDS, not hung off the
                    // top of them.** The spec's hero is one `align-items:center`
                    // flex row; the port started it, so a 64pt picture sat level
                    // with the title with the whole description falling away
                    // below it.
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (glyph != null) ...[
                        SizedBox(width: 64, child: Center(child: glyph)),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Name and badge on one line, wrapping rather than
                            // truncating — the spec's own `flex-wrap:wrap`.
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 3,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                    color: ink,
                                  ),
                                ),
                                if (ribbon case final banner?)
                                  _chip(banner, ink),
                              ],
                            ),
                            for (final line in lines)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: line,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ),
                  const SizedBox(height: 12),
                  // **THE CONTENTS AND THE PRICE SHARE A LINE.** The button was
                  // alone on it, hard against the right edge, with the width of
                  // the hero empty to its left — and what belongs in that space
                  // is the one thing the tile never said outright: what the
                  // money actually buys. Bottom-aligned, so a strip that wraps
                  // to two rows grows upward and the button stays on the tile's
                  // own baseline.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: contents ?? const SizedBox.shrink(),
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


/// **THE DIAGONAL FLASH ACROSS A TILE'S TOP-RIGHT CORNER.**
///
/// `.shop-hero__ribbon` in `styles/screens.css`, which the port had never
/// drawn: "MOST POPULAR" was a line of ordinary text in the middle of the card,
/// where it read as one more thing to skim rather than as the shelf pointing.
///
/// Asked for by name from the couch, and it is the one shopfront device the
/// tile had no equivalent of — a banner is not a label, it is a mark ON the
/// window. The parent clips it: a bar rotated 45 degrees inside a square is a
/// triangle only because the corner is cut off.
class CornerBanner extends StatelessWidget {
  const CornerBanner({super.key, required this.text, required this.ink});

  final String text;

  /// The tile's own colour, so three offers in a column are three shopfronts
  /// rather than one repeated. The ink ON it is worked out here — a banner is
  /// small and high-contrast or it is not a banner.
  final Color ink;

  /// The corner it is cut out of, how far down the DIAGONAL its centre-line
  /// sits, how thick the band is, and how long.
  ///
  /// **THE TEXT WAS NOT IN THE MIDDLE OF THE BANNER, and the geometry says why.**
  /// The bar was placed by its top edge, `_drop` pixels down the box, and then
  /// rotated about its own centre — so where it ended up depended on how tall
  /// the text happened to render. Measured, its centre landed 12pt up the band
  /// from the middle of the part that is actually VISIBLE: the visible run is the
  /// chord across the corner, and the chord's midpoint is the foot of the
  /// perpendicular from the corner, which is nowhere near the box's own centre.
  /// Reported from the couch.
  ///
  /// So the band is placed by that foot instead — [_reach] down the diagonal
  /// from the corner — and the text, centred in the band, is therefore centred
  /// on what is seen. [_bar] only has to be longer than the chord.
  static const double _box = 96;
  static const double _reach = 34;
  static const double _thick = 17;
  static const double _bar = 150;

  /// How much of [_bar] the tile actually shows.
  ///
  /// The band crosses the corner at 45°, so the two edges cut it at
  /// `_reach * √2` from the corner apiece and the chord between them is twice
  /// [_reach]. Everything outside that is behind the tile's own clip.
  static const double _chord = _reach * 2;

  /// How much of the tile's top-right the flash covers, which is what a tile
  /// carrying one has to keep clear. The band's far edge, projected back onto
  /// the edges it crosses.
  ///
  /// **The flash ran straight across the hero's title.** It is drawn as a
  /// sibling of the pane and the hero's words start at the art's right shoulder
  /// and run to the tile's edge, so "MOST POPULAR" was laid over the name of the
  /// thing it was recommending. A tile that wears one insets its own words by
  /// this. See [ShopTile].
  static const double clearance = (_reach + _thick / 2) * 1.4143;

  @override
  Widget build(BuildContext context) {
    // Whichever of the two inks reads better, MEASURED. A brightness guess
    // put white on VIP purple at 2.88:1; the better of white and near-black is
    // never under 4.5:1 on any colour, which is what "high-contrast" has to
    // mean on nine-point type.
    final l = ink.computeLuminance();
    final onInk = 1.05 / (l + 0.05) >= (l + 0.05) / 0.0575
        ? Colors.white
        : adOfferOnInk;
    // The foot of the perpendicular from the corner, which is the middle of the
    // chord the band is seen through.
    const along = _reach / 1.4143;
    return IgnorePointer(
      child: SizedBox(
        width: _box,
        height: _box,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: _box - along - _bar / 2,
              top: along - _thick / 2,
              width: _bar,
              height: _thick,
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  alignment: Alignment.center,
                  color: ink,
                  // **THE BAR IS 150 LONG AND ONLY [_chord] OF IT IS SEEN.**
                  // The text was centred in the BAR and clipped by the tile, so
                  // a label wider than the chord lost a bite off both ends —
                  // "MOST POPULAR" measures about 73 against a 68-point chord,
                  // and the VIP pass and the coin pile both wore it cut off.
                  // Reported from the couch.
                  //
                  // Held to what is actually visible and scaled down to fit, so
                  // no label can be clipped again — including the ten
                  // translations of it, which are not this one's length and
                  // cannot be checked by eye.
                  child: SizedBox(
                    width: _chord - 8,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        text.toUpperCase(),
                        key: const ValueKey('shop-corner-banner'),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: onInk,
                        ),
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
