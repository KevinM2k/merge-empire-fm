/// One player card. Ported from `ui/components/Card.js`.
///
/// The most-repeated widget in the game — the merge grid, the squad, the bench
/// and the pitch all draw it — so its frame cost is the frame cost. Two rules
/// carried from the port design and measured by the M0 probe:
///
/// - **A `RepaintBoundary` per card**, so one card animating does not repaint
///   the grid around it.
/// - **`const` wherever the data allows**, so a rebuild of the grid re-uses the
///   element rather than rebuilding the subtree.
///
/// The palette lives in `data/card_theme.dart`, which is Flutter-free; this is
/// the only place a tier's hex becomes a `Color`.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/data/card_theme.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

/// Everything the card paints, resolved by the caller.
///
/// A record rather than the save's card map: the widget should not know how a
/// card is stored, and a screen already has the engines to hand to answer these.
typedef CardView = ({
  String name,
  int tier,
  int rating,
  String position,
  bool injured,
  bool onLoan,
  /// 0..1, or null in casual mode.
  ///
  /// Per-player fitness is a PRO-MODE idea — casual play has team energy pips
  /// instead — so null means "this game has no such number", not "full". A bar
  /// pinned at 100% for every casual player would be a number that never moves.
  double? fitness,
});

class PlayerCard extends StatelessWidget {
  const PlayerCard({
    super.key,
    required this.view,
    this.light = false,
    this.onTap,
    this.selected = false,
  });

  final CardView view;

  /// Light mode swaps the BODY for a pale tint of the same rarity. The chips
  /// stay dark so their bright rarity text stays readable on top.
  final bool light;

  final VoidCallback? onTap;
  final bool selected;

  TierTheme get _theme => tierThemes[view.tier] ?? tierThemes[1]!;

  LinearGradient _gradient(TierGradient g) {
    // CSS measures its angle clockwise from "to top"; Flutter takes two points.
    // 160deg and 135deg are the only two the catalogue uses, and both read as a
    // top-left to bottom-right sweep.
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [for (final stop in g.stops) cssColor(stop.$1)],
      stops: [for (final stop in g.stops) stop.$2 / 100],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    final accent = cssColor(theme.accent);
    final accentLight = cssColor(theme.accentLight);
    final body = light ? theme.bgLight : theme.bg;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          key: ValueKey('card-${view.tier}-${view.name}'),
          decoration: BoxDecoration(
            gradient: _gradient(body),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            border: Border.all(
              color: selected ? accentLight : accent,
              width: selected ? 3 : 2,
            ),
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Flexible, not fixed: a card is small, and a selected one loses
              // another pixel each side to its thicker border. The chips shrink
              // rather than overflowing the header.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: _Chip(
                      label: '${view.rating}',
                      background: cssColor(theme.labelBg),
                      foreground: accentLight,
                      bold: true,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: _Chip(
                      label: positionLabel[view.position] ?? view.position,
                      background: cssColor(theme.labelBg),
                      foreground: accentLight,
                    ),
                  ),
                ],
              ),
              // Status before the name: an injury is the thing a player is
              // scanning a full grid for.
              if (view.injured || view.onLoan)
                Row(
                  children: [
                    if (view.injured)
                      const Icon(
                        Icons.healing,
                        size: 14,
                        color: Colors.redAccent,
                      ),
                    if (view.onLoan)
                      const Icon(
                        Icons.swap_horiz,
                        size: 14,
                        color: Colors.lightBlueAccent,
                      ),
                  ],
                ),
              if (view.fitness != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      key: const ValueKey('card-fitness'),
                      value: view.fitness!.clamp(0.0, 1.0),
                      minHeight: 3,
                      backgroundColor: cssColor(theme.labelBg),
                      valueColor: AlwaysStoppedAnimation(
                        view.fitness! < 0.34 ? Colors.redAccent : accentLight,
                      ),
                    ),
                  ),
                ),
              Text(
                view.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: light ? const Color(0xFF1A1A1A) : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.background,
    required this.foreground,
    this.bold = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: TextStyle(
            fontSize: bold ? 13 : 10,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: foreground,
          ),
        ),
      ),
    );
  }
}
