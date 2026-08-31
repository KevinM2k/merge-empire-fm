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
import 'package:merge_empire_fc/ui/hud/hud.dart' show hudBadgeColour, hudBadgeInk;
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
    // **EACH READING IS ITS OWN BADGE, FILLED WITH ITS OWN COLOUR.**
    //
    // Four rounds went into making a hue legible on a pane, and every one of
    // them lost the same way: deepening the ink read as muted, a dark pane read
    // as a slab cut out of the sky, an outline under the glyph did nothing, and
    // a pane light enough to belong left the colours unreadable. All four were
    // arguments about a GROUND the wallets did not control.
    //
    // A badge controls its ground. The chip is filled with the wallet's own
    // colour and printed in white, so gold is gold because the CHIP is gold —
    // the coding is louder than it has ever been — and it says the same thing
    // on a night sky as it does on a daylit one. Asked for in those terms.
    final hue = iconColor;
    final fill = hue == null ? kit.accent : hudBadgeColour(hue);
    final ink = hue == null ? kit.accentInk : hudBadgeInk(fill);
    final body = Container(
      padding: EdgeInsets.symmetric(
        horizontal: child is SizedBox ? 7 : 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: ink),
          // The cog has no figure, so it gets no gutter either — otherwise it
          // sits off-centre in its own badge.
          if (child is! SizedBox) ...[
            const SizedBox(width: 4),
            DefaultTextStyle.merge(style: TextStyle(color: ink), child: child),
          ],
          if (trailing != null) ...[const SizedBox(width: 5), trailing!],
        ],
      ),
    );
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: onTap == null
          ? body
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              child: body,
            ),
    );
  }
}

/// **FOUR BADGES IN A ROW, and no box.**
///
/// This has been round the houses and the landing point is worth writing down.
/// It began as four panes, which read as embossed buttons — four rims, four
/// shadows and four highlights for one instrument — so they were collapsed into
/// one box. The box then spent four rounds being too dark, too light, or a
/// different material from the next-match card under it, because a shared pane
/// has to serve four fixed hues at once and cannot.
///
/// A badge carries its own ground, so there is nothing left for the box to do.
/// Separated rather than divided, which is what tells them apart now that each
/// one is a different colour. See [HudChip].
class HudCluster extends StatelessWidget {
  const HudCluster({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('hud-cluster'),
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(width: 5),
        children[i],
      ],
    ],
  );
}

/// The small `+` that deep-links out of a resource chip.
class HudPlus extends StatelessWidget {
  const HudPlus({super.key, required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
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
          // **WHITE ON THE BADGE, not the club's colour.** It used to be an
          // accent disc, which is right on a neutral pane and wrong inside a
          // filled gold one — two saturated colours touching, and the club's
          // has nothing to say about buying coins. A hole punched in the badge
          // reads as part of it. See [HudChip].
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
          ),
          child: const Icon(Icons.add, size: 11, color: Colors.white),
        ),
      ),
    );
  }
}
