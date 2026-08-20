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
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/ui/theme/sky.dart';
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
            // And you cannot fix a bright hue by darkening it. Yellow is
            // intrinsically light — taking gold to 4.5:1 against a near-white
            // pane lands on `#665600`, a dark olive that is perfectly legible and
            // no longer money. So the hue stays and the BACKING changes: a soft
            // dark halo under the glyph in daylight, which is contrast the colour
            // does not have to pay for.
            color: iconColor ?? glassAccent(context, kit.accentBright),
            shadows: iconColor == null || nightSceneOf(context)
                ? null
                : const [
                    Shadow(color: Color(0x59102030), blurRadius: 3),
                    Shadow(color: Color(0x33102030), blurRadius: 6),
                  ],
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
  Widget build(BuildContext context) {
    return GlassPanel(
      key: const ValueKey('hud-cluster'),
      radius: 14,
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
                color: glassInk(context).withValues(alpha: 0.22),
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
          decoration: BoxDecoration(color: kit.accent, shape: BoxShape.circle),
          child: Icon(Icons.add, size: 12, color: kit.accentInk),
        ),
      ),
    );
  }
}
