/// The mirrored ATK/DEF comparison block, with each side's RATING flanking it.
/// Ported from `ui/components/matchStatRows.js`.
///
/// ```
///     78    27 ▬▬  ATK  ▬▬ 31    74
///           16 ▬▬  DEF  ▬▬ 22
/// ```
///
/// Built for the next-match card and SHARED with the live match page, which is
/// the same fixture ten seconds later — two teams, four figures, one comparison.
/// Two copies would drift apart the first time either surface was touched.
///
/// **The label owns the centre and both bars grow OUTWARD from it**, so the
/// longer bar names the stronger side before either number is read. Stacked per
/// column the four figures were four readouts to pair up by eye; mirrored, the
/// pairing is the layout.
///
/// **Bar and figure share one hue**, and it is the CROSS-stat verdict: our ATK is
/// judged against their DEF, not against its own magnitude. A row carries one
/// opinion, and green always means "this beats what it faces" — a bar shaded by
/// its own size would answer a different question from the number beside it and
/// the two would visibly disagree on the same row.
///
/// **The ratings are taken out of flow** and pinned to the span of the team
/// column above, so each figure lands dead centre under its own club name. In
/// flow they cannot: the Lucky Boot 🍀 makes one rating wider than the other, so
/// any content-sized row centres the pair off-axis.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/widgets/bar_fill.dart';
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';

/// The card's geometry. Every row keys off the same gutter, which is what makes
/// the ratings line up under the names — while the gutter was sized by the VS
/// glyph the only way to match it was to clone the glyph and hide it.
const double nmGutter = 34;
const double nmGap = 4;
const double _ratingHalf = 22;
const double _statClear = 8;

/// Deeper and more saturated than a plain red: this is 10px type on mid-tone
/// glass, where `#f87171` went milky. Shared with the grudge chip beside it.
const Color vsRed = Color(0xFFFF6B70);
const Color _vsGreen = Color(0xFF4ADE80);
const Color _vsLevel = Color(0xFF60A5FA);

/// Green when this figure beats the one it faces, red when it loses, blue level.
Color vsColor(int mine, int opp) => mine > opp
    ? _vsGreen
    : mine < opp
    ? vsRed
    : _vsLevel;

/// One side's ATK and DEF, already through `fifaSplit`.
typedef StatSide = ({int atk, int def});

/// One modifier hanging off a rating: a glyph, a signed number and the sentence
/// that explains it.
typedef StatMod = ({String icon, int amount, Color colour, String tip});

class MatchStatRows extends StatelessWidget {
  const MatchStatRows({
    super.key,
    required this.left,
    required this.right,
    required this.leftRating,
    required this.rightRating,
    this.leftMods = const [],
    this.rightMods = const [],
    this.leftBoot = false,
    this.rightBoot = false,
  });

  final StatSide left;
  final StatSide right;
  final int? leftRating;
  final int? rightRating;
  final List<StatMod> leftMods;
  final List<StatMod> rightMods;

  /// The Lucky Boot weakened this side. Marked rather than silently quoted.
  final bool leftBoot;
  final bool rightBoot;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // The team column's inner edge — where the gutter starts.
        final ratingBox = w / 2 - nmGutter / 2 - nmGap;
        // As wide as the rows can be without running into a rating centred under
        // its club name. DERIVED from the gutter, not guessed.
        final rowsWidth =
            (w / 2 + nmGutter / 2 + nmGap - 2 * _ratingHalf - 2 * _statClear)
                .clamp(80.0, w);

        return Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 9),
          // The Stack is forced to the FULL width. Left to itself it sizes to its
          // largest NON-POSITIONED child — the stat rows, which are barely half
          // the card — so `left: 0` on a rating meant the left edge of that narrow
          // box, not of the card. Both ratings ended up a quarter of the way in,
          // printing straight through the middle of the comparison they annotate.
          child: SizedBox(
            width: w,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: rowsWidth,
                  child: _StatWell(left: left, right: right),
                ),
                Positioned(
                  left: 0,
                  width: ratingBox,
                  child: _Rating(
                    key: const ValueKey('nm-rating-left'),
                    figureKey: const ValueKey('nm-figure-left'),
                    value: leftRating,
                    mods: leftMods,
                    boot: leftBoot,
                    // Always OUTWARD, away from the stat bars.
                    bootOnLeft: true,
                  ),
                ),
                Positioned(
                  right: 0,
                  width: ratingBox,
                  child: _Rating(
                    key: const ValueKey('nm-rating-right'),
                    figureKey: const ValueKey('nm-figure-right'),
                    value: rightRating,
                    mods: rightMods,
                    boot: rightBoot,
                    bootOnLeft: false,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The darker well around the ATK/DEF pair ONLY. It says these four figures are
/// one comparison; wrapped round the ratings too it just looked like a second
/// panel.
class _StatWell extends StatelessWidget {
  const _StatWell({required this.left, required this.right});

  final StatSide left;
  final StatSide right;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        // A RECESS, not a grey box. On dark glass a black wash reads as depth
        // and can take a quarter of the pane's opacity; on a near-white pane the
        // same wash is a mid-grey slab that outweighs everything on the card. It
        // has to be a whisper there — the border does the work instead.
        color: Colors.black.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.24 : 0.05,
        ),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: glassInk(context).withValues(alpha: 0.10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatRow(
            label: 'ATK',
            leftValue: left.atk,
            rightValue: right.atk,
            // Cross-stat: attack is judged against the defence it faces.
            leftColour: vsColor(left.atk, right.def),
            rightColour: vsColor(right.atk, left.def),
          ),
          const SizedBox(height: 5),
          _StatRow(
            label: 'DEF',
            leftValue: left.def,
            rightValue: right.def,
            leftColour: vsColor(left.def, right.atk),
            rightColour: vsColor(right.def, left.atk),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.leftValue,
    required this.rightValue,
    required this.leftColour,
    required this.rightColour,
  });

  final String label;
  final int leftValue;
  final int rightValue;
  final Color leftColour;
  final Color rightColour;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Row(
      children: [
        Expanded(
          child: _Side(
            value: leftValue,
            colour: leftColour,
            mirrored: false,
            statKey: '${label.toLowerCase()}-l',
          ),
        ),
        const SizedBox(width: 6),
        // No glyph. It was one per side (the same mark facing itself across the
        // card), then one ON the label — which left the row lopsided, since a
        // mark on one side of a centred word is the one thing a mirrored layout
        // cannot have. The width goes to the bars instead.
        SizedBox(
          width: 30,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: kit.textMuted,
              shadows: const [
                Shadow(
                  color: Color(0x8C000000),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _Side(
            value: rightValue,
            colour: rightColour,
            mirrored: true,
            statKey: '${label.toLowerCase()}-r',
          ),
        ),
      ],
    );
  }
}

/// Figure to the OUTSIDE, bar against the centre label.
class _Side extends StatelessWidget {
  const _Side({
    required this.value,
    required this.colour,
    required this.mirrored,
    required this.statKey,
  });

  final int value;
  final Color colour;
  final bool mirrored;
  final String statKey;

  @override
  Widget build(BuildContext context) {
    final figure = SizedBox(
      width: 19,
      child: Text(
        '$value',
        key: ValueKey('nm-stat-$statKey'),
        textAlign: mirrored ? TextAlign.left : TextAlign.right,
        style: TextStyle(
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w900,
          color: colour,
          shadows: const [
            Shadow(
              color: Color(0x8C000000),
              offset: Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
    );
    final bar = Expanded(
      child: _Bar(
        // 10% floor: the track is short, so a single-figure stat would round to
        // a sub-pixel sliver and read as an empty bar rather than a low one.
        fraction: (value.clamp(10, 100)) / 100,
        colour: colour,
        // Anchored at the centre label and growing outward, so both bars start
        // from the same line — the whole point of mirroring them.
        fromRight: !mirrored,
      ),
    );

    return Row(
      children: mirrored
          ? [figure, const SizedBox(width: 4), bar]
          : [bar, const SizedBox(width: 4), figure],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.colour,
    required this.fromRight,
  });

  final double fraction;
  final Color colour;
  final bool fromRight;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 5,
        color: glassInk(context).withValues(alpha: 0.15),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: fraction),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => BarFill(
            alignment: fromRight ? Alignment.centerRight : Alignment.centerLeft,
            fraction: v,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colour,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One side's strength figure, its modifiers hung beneath it.
class _Rating extends StatelessWidget {
  const _Rating({
    super.key,
    required this.value,
    required this.mods,
    required this.boot,
    required this.bootOnLeft,
    required this.figureKey,
  });

  /// Names the FIGURE, not its box. The box deliberately spans the whole team
  /// column so the number can centre under the club name; anything checking the
  /// number's position has to look at the number.
  final Key figureKey;

  final int? value;
  final List<StatMod> mods;
  final bool boot;
  final bool bootOnLeft;

  /// The figure's own height, which is what the modifiers hang below. Out of
  /// flow, because in flow they add height under the number and the box is
  /// vertically centred — so a side WITH a modifier sat higher than a side
  /// without, and the two ratings stopped lining up with each other.
  static const double _figureHeight = 26;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Text(
          '${value ?? '?'}',
          key: figureKey,
          style: TextStyle(
            fontSize: 26,
            height: 1,
            fontWeight: FontWeight.w900,
            color: ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        // Hangs into the empty margin rather than widening the figure — in flow
        // it pushed the number off the line it shares with the club name above,
        // so the one fixture in ten with a weakened opponent looked misaligned.
        if (boot)
          Align(
            alignment: bootOnLeft
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: const Text('🍀', style: TextStyle(fontSize: 15, height: 1)),
          ),
        if (mods.isNotEmpty)
          Positioned(
            top: _figureHeight + 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final mod in mods) ...[
                  if (mod != mods.first) const SizedBox(width: 6),
                  _Mod(mod: mod),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// A glyph and a signed number, no pill.
///
/// Every modifier is a delta ALREADY INSIDE the figure above it, so it hangs off
/// that figure rather than sitting in a row of its own at the foot of the card —
/// as outlined word-pills they read as separate facts about the fixture; hung,
/// they read as the arithmetic behind the number they moved. Tapping one says the
/// word.
class _Mod extends StatelessWidget {
  const _Mod({required this.mod});

  final StatMod mod;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: mod.tip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameIcon(mod.icon, size: 9, color: mod.colour),
          Text(
            '+${mod.amount}',
            style: TextStyle(
              fontSize: 9.5,
              height: 1,
              fontWeight: FontWeight.w900,
              color: mod.colour,
              fontFeatures: const [FontFeature.tabularFigures()],
              shadows: const [
                Shadow(
                  color: Color(0x99000000),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
