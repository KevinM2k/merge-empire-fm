/// One frosted chip in the HUD.
///
/// There is no bar behind these. The JS deleted the header background so the
/// game scene shows through and each stat floats on its own.
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

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kit.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kit.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor ?? kit.accent),
          const SizedBox(width: 4),
          child,
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
        ],
      ),
    );
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: onTap == null
          ? body
          : InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: body),
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
