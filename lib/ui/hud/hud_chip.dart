/// One reading in the HUD's cluster.
///
/// **THE CHIPS HAVE NO CHROME OF THEIR OWN ANY MORE.** They were four separate
/// pills — glass on the Play tab and a themed pill everywhere else — which is two
/// problems in one. The HUD looked like a different HUD depending on which tab
/// you were on, and the glass version was the worse of the two: four small panes
/// each with their own rim and shadow read as embossed buttons rather than as
/// status. And four boxes is four boxes; the coins, the energy, the gems and the
/// cog are ONE thing, which is what a player is checking when they look up there.
///
/// So [HudCluster] draws the box, once, and a chip is now just icon | value |
/// trailing with a hairline between it and its neighbour.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart' show hudTroughInk;
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

class HudChip extends StatelessWidget {
  const HudChip({
    super.key,
    required this.icon,
    this.iconColor,
    required this.child,
    this.onTap,
    this.trailing,
    this.semanticLabel,
    this.iconSize = 16,
  });

  final IconData icon;

  /// The icon's own colour, overriding the kit accent.
  ///
  /// The three resources are colour-CODED and their hues are fixed on every kit:
  /// the coin gold, the bolt blue, the gem cyan. The bar behind them swings from
  /// deep green to bright yellow depending on kit and theme, and taking the
  /// accent meant all three came out the same colour as each other — which is
  /// the coding gone.
  final Color? iconColor;
  final Widget child;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? semanticLabel;

  /// Bigger for the cog, which has no figure beside it. At the resources' 16 it
  /// was the one item in the cluster that read as smaller than the rest, because
  /// every other one is a glyph AND a number.
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // **THE GLYPH KEEPS ITS HUE; THE FIGURE BUYS THE CONTRAST.** These
          // were briefly pushed through `glassAccent` with everything else, and
          // it took the colour coding out — a darkened gold and a darkened cyan
          // are two browns. The split is that a 16px glyph with a distinctive
          // SHAPE is identity and a number is information: the coin is a coin
          // whatever its luminance, and the figure beside it is what has to be
          // read. So the icon is left alone and the value is darkened.
          Icon(
            icon,
            size: iconSize,
            // **A wallet's hue is left EXACTLY alone; a control's is ramped.**
            //
            // Those are two different jobs. The cog carries no meaning in its
            // colour, so it takes the pane's contrast ramp — on a kit whose
            // accent is the same hue as the glass it was the one control in the
            // bar you could not find. The coin, the bolt and the gem carry
            // nothing BUT their colour: gold is money, cyan is gems, violet is
            // energy, and their separation from each other is the whole reason
            // those three were picked. See [hudCoinInk].
            //
            // And you cannot fix a bright hue by taking it to 4.5:1: yellow is
            // intrinsically light, and gold at that threshold lands on
            // `#665600`, a dark olive that is perfectly legible and no longer
            // money. So the wallets go through [hudInk] instead, which deepens
            // a hue only as far as a 16px glyph actually needs — and the soft
            // dark halo that used to buy the same contrast in daylight is gone
            // with the figures'. See [hudFigureShadows].
            // The cog carries no meaning in its colour, so it takes the
            // club's — raw, because the trough it stands on is dark whatever
            // the theme is, which is the pairing `accentBright` is for.
            color: iconColor ?? kit.accentBright,
          ),
          // The cog has no figure, so it gets no gutter either — otherwise it
          // sits off-centre in its own segment.
          if (child is! SizedBox) ...[const SizedBox(width: 4), child],
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
        ],
      ),
    );
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );
  }
}

/// The one box the whole cluster sits in.
///
/// **GLASS, and the SAME glass as the next-match card.** This has been round the
/// houses and the landing point is worth writing down.
///
/// It started as four separate panes — one per reading — which is what read as
/// embossed buttons: four rims, four shadows and four highlights for what is one
/// instrument. Collapsing them into one box fixed that, and the box was made a
/// solid pill because at the glass of the time a 13px accent-green figure on it
/// was under 2:1.
///
/// That was solving the wrong end. The pane was never the problem — the FIGURE
/// was, and `glassAccent` is the fix for it: a mid-tone hue darkened until it
/// reads on a bright pane. With the ink handled, the pane can be the app's one
/// glass recipe, and the HUD stops being the one surface that does its own thing.
class HudCluster extends StatelessWidget {
  const HudCluster({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => _body(context);

  Widget _body(BuildContext context) {
    // **THE PILL IS A DARK TROUGH IN BOTH THEMES, and that is what lets the
    // wallets keep their colours.** The three hues are identity — gold is
    // money, cyan is gems, green is energy — and on a near-white daylight bar a
    // raw `#FFD700` is 1.2:1, so the only way to print them there was to deepen
    // them. Which worked, and read as muted: the report was that light mode
    // wants the same vibrant yellows, greens and blues the dark theme has.
    //
    // A hue cannot be both vivid and legible on white, so the SURFACE moves
    // instead of the ink. The JS's own resource pill is described as a dark
    // trough for exactly this reason.
    return GlassPanel(
      key: const ValueKey('hud-cluster'),
      radius: 14,
      darkGlass: true,
      // **THE SAME RECIPE THE NEXT-MATCH CARD USES.** Both stand on the sky and
      // both were reported in the same breath — the card much lighter than the
      // bar, and the bar too dark. They are one material now rather than two
      // that happen to be dark, which is a thing to state once instead of two
      // opacities to keep in step by eye.
      density: GlassDensity.deep,
      tint: skyPaneTint,
      // **NO DROP SHADOW.** Every other pane in the app casts one to say it is
      // in FRONT of the page — see [GlassPanel.shadow]. This one is not on the
      // page, it is in a bar, and the shadow was a dark smear under the one
      // strip that is on screen on every tab all the time. Asked for directly.
      shadow: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            // A hairline, not a gap. The four readings are one instrument, and
            // the divider is what keeps them from running into each other
            // without splitting them back into four boxes.
            if (i > 0)
              Container(
                width: 1,
                height: 22,
                // The trough's own ink, not the page's: `glassInk` follows the
                // THEME and this pane deliberately does not.
                color: hudTroughInk.withValues(alpha: 0.22),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// The small `+` that deep-links out of a resource chip.
class HudPlus extends StatelessWidget {
  const HudPlus({super.key, required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          // **THE ACCENT ITSELF, and the ink measured for it.** Anything
          // derived from the club's colour rather than the colour reads as not
          // quite the club's colour — reported directly — and a filled disc is
          // exactly what `accentInk` is measured against.
          decoration: BoxDecoration(color: kit.accent, shape: BoxShape.circle),
          child: Icon(Icons.add, size: 12, color: kit.accentInk),
        ),
      ),
    );
  }
}
