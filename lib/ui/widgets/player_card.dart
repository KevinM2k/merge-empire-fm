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
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/data/card_theme.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/ui/widgets/player_portrait.dart';

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

  /// Which portrait to draw. Null draws none.
  int? variant,

  /// 0..1, or null in casual mode.
  ///
  /// Per-player fitness is a PRO-MODE idea — casual play has team energy pips
  /// instead — so null means "this game has no such number", not "full". A bar
  /// pinned at 100% for every casual player would be a number that never moves.
  double? fitness,

  /// Coins a second, or null where a rate is meaningless — a borrowed player,
  /// or a picker that is not the grid.
  double? incomePerSec,

  /// Top of the game: nothing to merge into, ever.
  bool maxed,

  /// Top of THIS DIVISION. Different from [maxed] and it has to look different,
  /// because one is an achievement and the other is a reason to get promoted.
  bool atCap,
});

class PlayerCard extends StatelessWidget {
  const PlayerCard({
    super.key,
    required this.view,
    this.light = false,
    this.onTap,
    this.selected = false,
    this.kitColor,
  });

  final CardView view;

  /// Light mode swaps the BODY for a pale tint of the same rarity. The chips
  /// stay dark so their bright rarity text stays readable on top.
  final bool light;

  final VoidCallback? onTap;
  final bool selected;

  /// The club's colour, so a squad reads as one team. Falls back to the tier
  /// accent, which is what a card outside a squad context should wear.
  final Color? kitColor;

  TierTheme get _theme => tierThemes[view.tier] ?? tierThemes[1]!;

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
            gradient: tierBodyGradient(body),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            border: Border.all(
              color: selected ? accentLight : accent,
              width: selected ? 3 : 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (view.variant != null)
                Positioned.fill(
                  // `contain`, not `cover`: the art is drawn to fill a portrait
                  // frame and cropping it takes the head off.
                  child: ArtImage(
                    path: playerImagePath(
                      view.position,
                      view.tier,
                      view.variant!,
                    ),
                    fit: BoxFit.contain,
                    fallback: PlayerPortrait(
                      variantIndex: view.variant!,
                      kitColor: kitColor ?? accent,
                    ),
                  ),
                ),
              Padding(
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
                            label:
                                positionLabel[view.position] ?? view.position,
                            background: cssColor(theme.labelBg),
                            foreground: accentLight,
                          ),
                        ),
                      ],
                    ),
                    // WHICH CARDS PAIR UP. Two cards with the same definition
                    // merge whatever portrait or name they happen to carry, so
                    // without the tier on the face there was no way to tell by
                    // looking — the grid's whole mechanic had no visual cue.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _Chip(
                        key: ValueKey('card-tier-${view.tier}'),
                        label: view.injured
                            ? t('card.inj_short')
                            : (tierLabel[view.tier] ?? 'T${view.tier}'),
                        background: cssColor(theme.labelBg),
                        foreground: view.injured
                            ? Colors.redAccent
                            : accentLight,
                        bold: true,
                      ),
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
                              view.fitness! < 0.34
                                  ? Colors.redAccent
                                  : accentLight,
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
                    // THE MONEY. What this player actually pays per second, and
                    // a bar whose cycle is one payout of it — so a faster bar is
                    // literally a richer player, and a sponsor or an injury
                    // visibly changes the speed. The card had neither: the grid
                    // is an idle game's earner and none of its cards said what
                    // they earned.
                    if (view.incomePerSec != null) ...[
                      const SizedBox(height: 2),
                      _Income(
                        ratePerSec: view.incomePerSec!,
                        ink: accentLight,
                        track: cssColor(theme.labelBg),
                      ),
                    ],
                  ],
                ),
              ),
              // Across the corner, because at bench size a pip cannot carry a
              // word and every corner is already spoken for.
              if (view.maxed || view.atCap)
                Positioned(
                  top: 0,
                  right: 0,
                  child: _Ribbon(
                    label: view.maxed
                        ? t('card.max_ribbon')
                        : t('card.tier_locked', {'tier': view.tier}),
                    // Gold for the top of the game, and a flat warning colour
                    // for the top of this division — one is an achievement and
                    // the other is a reason to get promoted.
                    background: view.maxed
                        ? const Color(0xFFF9A825)
                        : const Color(0xFF37474F),
                    foreground: view.maxed
                        ? const Color(0xFF241C00)
                        : Colors.white,
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
    super.key,
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

/// The corner ribbon.
class _Ribbon extends StatelessWidget {
  const _Ribbon({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      key: const ValueKey('card-ribbon'),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(6)),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4)],
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
          color: foreground,
        ),
      ),
    ),
  );
}

/// The rate, and a bar that fills once per payout of it.
///
/// The cycle length is DERIVED from the rate rather than picked — see
/// `incomeBarCycleSec`. A hardcoded per-tier speed carries no information: it
/// tracks the badge the card is already wearing, not the money, and income
/// spans four orders of magnitude across the tiers where a tier table spans
/// one.
class _Income extends StatefulWidget {
  const _Income({
    required this.ratePerSec,
    required this.ink,
    required this.track,
  });

  final double ratePerSec;
  final Color ink;
  final Color track;

  @override
  State<_Income> createState() => _IncomeState();
}

class _IncomeState extends State<_Income> with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(vsync: this);

  Duration get _cycle => Duration(
    milliseconds: (incomeBarCycleSec(widget.ratePerSec) * 1000).round(),
  );

  void _sync() {
    // A grid of these is a screenful of looping animations, which is exactly
    // what reduce-motion is asking us not to run. The bar parks full — the
    // money is still arriving, so an empty one would be a lie.
    if (MediaQuery.of(context).disableAnimations) {
      if (_fill.isAnimating) _fill.stop();
      _fill.value = 1;
      return;
    }
    if (_fill.duration != _cycle) {
      final running = _fill.isAnimating;
      _fill.stop();
      _fill.duration = _cycle;
      if (running) _fill.repeat();
    }
    if (!_fill.isAnimating) _fill.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Income old) {
    super.didUpdateWidget(old);
    if (old.ratePerSec != widget.ratePerSec) _sync();
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('card-income'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // FLEXIBLE. A card is 90px wide and a rate can be five figures a
            // second at the top tiers; the figure gives ground before the coin
            // that says what it is.
            Flexible(
              child: Text(
                '+${formatRate(widget.ratePerSec)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: widget.ink,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.monetization_on, size: 9, color: widget.ink),
          ],
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 3,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: widget.track)),
                AnimatedBuilder(
                  animation: _fill,
                  builder: (context, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _fill.value,
                    child: ColoredBox(color: widget.ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
