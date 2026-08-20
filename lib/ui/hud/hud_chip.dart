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
          Icon(icon, size: iconSize, color: iconColor ?? kit.accentBright),
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
/// Identical on every tab, which is the point: the HUD is the same instrument
/// wherever you are, and the Play tab having its own treatment is what made it
/// read as a different app. A themed pill rather than glass — see the note in
/// `theme/glass.dart` about what glass is for. The Play tab, where the diorama
/// runs behind it, is exactly the case a solid pill is needed for.
class HudCluster extends StatelessWidget {
  const HudCluster({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Container(
      key: const ValueKey('hud-cluster'),
      decoration: BoxDecoration(
        color: kit.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        // NO SHADOW. It was there to lift the pill off the diorama, and on the
        // diorama is exactly where it did not work: the cluster sits on a sky
        // that is already a gradient, so a soft dark edge under it read as
        // grime rather than as height. The border separates it on every page,
        // and a shadow that only convinces on four of five screens is worse
        // than none.
        border: Border.all(color: kit.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            // A hairline, not a gap. The four readings are one instrument, and
            // the divider is what keeps them from running into each other
            // without splitting them back into four boxes.
            if (i > 0) Container(width: 1, height: 22, color: kit.border),
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
