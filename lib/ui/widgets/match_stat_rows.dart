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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/widgets/bar_fill.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';

/// The card's geometry. Every row keys off the same gutter, which is what makes
/// the ratings line up under the names — while the gutter was sized by the VS
/// glyph the only way to match it was to clone the glyph and hide it.
const double nmGutter = 34;
const double nmGap = 4;
const double _ratingHalf = 22;
const double _statClear = 8;

/// Viewport width at which the stat bars start being drawn — the spec's
/// `@media (max-width: 379px)` rule, from the other side. See the note in
/// [MatchStatRows.build] for why the bars and not the figures are what goes.
const double _barsFrom = 380;

/// One row of the card's `[1fr | gutter | 1fr]` shape.
///
/// **ONE ROW, because there were two.** The next-match card and the live
/// scoreboard each carried their own copy of these five lines, which is the
/// arrangement that makes the ratings line up under the club names — and two
/// copies of a shape whose entire job is alignment drift the first time either
/// surface is touched. It lives here with [nmGutter] and [nmGap], which are what
/// it is made of.
class MatchRow extends StatelessWidget {
  const MatchRow({
    super.key,
    required this.left,
    required this.right,
    required this.gutter,
    this.bottomSpacing = 0,
  });

  final Widget left;
  final Widget right;
  final Widget gutter;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: bottomSpacing),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Center(child: left)),
        const SizedBox(width: nmGap),
        SizedBox(
          width: nmGutter,
          child: Center(child: gutter),
        ),
        const SizedBox(width: nmGap),
        Expanded(child: Center(child: right)),
      ],
    ),
  );
}

/// Deeper and more saturated than a plain red: this is 10px type on mid-tone
/// glass, where `#f87171` went milky. Shared with the grudge chip beside it.
/// The three verdict hues, per pane.
///
/// **THEY HAVE TO INVERT WITH THE SURFACE.** These were one fixed set, picked for
/// dark glass: `#4ADE80` mint, `#FF6B70` coral, `#60A5FA` sky — all three
/// deliberately LIGHT, which is what makes them read on a near-black pane and
/// what makes them vanish on a bright one. A `+1` in mint on a daylit pane is
/// invisible, and it was.
///
/// Same hue, opposite lightness. The signal is the hue and it survives the flip;
/// the lightness is about the surface and nothing else.
const Color _vsRedDark = Color(0xFFFF6B70);
const Color _vsGreenDark = Color(0xFF4ADE80);
const Color _vsLevelDark = Color(0xFF60A5FA);

// **AS CLOSE TO THE DARK PAIR AS A WHITE PAGE ALLOWS.**
//
// "The red and green should be the same as dark mode" has now been said three
// times, and as INK on white they cannot be: `#4ADE80` is 1.9:1 there. What was
// never true is that they had to be as DARK as they were — `#C62828` and
// `#15803D` are a maroon and a bottle green, two shades and a good deal of
// saturation away from the mint and the coral they stand in for, and that gap
// is what reads as "not the same colour" rather than the contrast rule.
//
// These are the brightest members of each hue that still clear 3:1 on the
// light theme's own surfaces, which the contrast sweep checks. Same hue as the
// dark pair, one step down in lightness instead of three.
const Color _vsRedLight = Color(0xFFE03131);
const Color _vsGreenLight = Color(0xFF11913F);
const Color _vsLevelLight = Color(0xFF2563EB);
const Color _vsAmberLight = Color(0xFFC2650B);

/// **The same three, for a surface that is FILLED with them.**
///
/// A badge takes the daylight member whatever the theme is — the vivid pair is
/// too pale to carry a label — so the HUD's energy chip and the card's modifier
/// chips are the same green and the same red. Asked for directly: use the green
/// and the red the ATK/DEF ratings use. See `hudBadgeColour`.
const Color vsGreenPlate = _vsGreenLight;
const Color vsAmberPlate = _vsAmberLight;
const Color vsRedPlate = _vsRedLight;

bool _dark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color vsRedOn(BuildContext context) =>
    _dark(context) ? _vsRedDark : _vsRedLight;
Color vsGreenOn(BuildContext context) =>
    _dark(context) ? _vsGreenDark : _vsGreenLight;
Color vsAmberOn(BuildContext context) =>
    _dark(context) ? const Color(0xFFFF9800) : _vsAmberLight;

/// The light-mode counterpart of a colour that was chosen against a dark one.
///
/// **For semantics that arrive as DATA**, where there is no `BuildContext` at
/// the point the colour is picked — a provider's rows, a table keyed by tier.
/// Those are the sites that could not simply call [vsRedOn], and they are why
/// "the reds and greens are wrong in light mode" kept being reported after the
/// obvious call sites had been fixed.
///
/// Anything it does not recognise comes back untouched, so it is safe to run a
/// whole column through: a gold, a club accent and a tier colour are all
/// deliberate and none of them is this bug.
///
/// `light: true` asks for the daylight member whatever the theme is. For a
/// surface that is the same on both — a badge FILLED with the colour and
/// printed in white, where the vivid member is too pale to carry white. See
/// `_Mod`.
Color semanticInk(BuildContext context, Color ink, {bool light = false}) {
  if (_dark(context) && !light) return ink;
  return switch (ink.toARGB32()) {
    0xFF4ADE80 || 0xFF76E876 => _vsGreenLight,
    0xFFF87171 || 0xFFFF6B70 => _vsRedLight,
    // **Every gold in the palette, not just the one.** A table's points figure
    // is `#FFD700` and it was pure daylight yellow on a white page — reported
    // straight off the standings as unreadable.
    0xFFFBBF24 || 0xFFFFB020 || 0xFFFFD700 || 0xFFFFC93C => _vsAmberLight,
    0xFF60A5FA => _vsLevelLight,
    _ => ink,
  };
}

/// **The dark plate a bright semantic colour can sit on in EITHER theme.**
///
/// The light-mode pair above exists because `#4ADE80` on a white pane is 1.9:1
/// and nobody can read it in daylight — but that only applies to ink printed
/// straight onto the page. Give the colour a dark ground of its own and the
/// dark-mode value works everywhere, which is what "the reds and greens should
/// be the same as dark mode" is actually asking for and what the sell popup
/// already does.
///
/// **Only for CHIPS AND BADGES**, never for a run of body text: a plate behind
/// a sentence is a highlighter pen. A figure, a letter, a short label.
/// A tile's colour, taken down far enough to read on a LIGHT pane.
///
/// **Every feature colour in this file was chosen against near-black.** The
/// shelf's gold is 1.26:1 on the light theme's `surface2` and the VIP purple is
/// 2.30:1 — which is the whole of "light mode doesn't work", arriving through a
/// door this pass opened. Same hue, taken to the lightness `_lightFrom` gives
/// the kit's own bright accent.
Color readableInk(BuildContext context, Color ink) {
  if (Theme.of(context).brightness == Brightness.dark) return ink;
  final hsl = HSLColor.fromColor(ink);
  return hsl.withLightness(math.min(hsl.lightness, 0.34)).toColor();
}

/// Black or white on [fill], whichever a reader actually manages.
///
/// A luminance threshold picks white for a mid purple and leaves it at 2.88:1;
/// measuring both and taking the better one cannot.
Color inkOn(Color fill) {
  double ratio(Color a) {
    final x = a.computeLuminance();
    final y = fill.computeLuminance();
    return ((x > y ? x : y) + 0.05) / ((x < y ? x : y) + 0.05);
  }

  const dark = Color(0xFF201603);
  return ratio(dark) >= ratio(Colors.white) ? dark : Colors.white;
}
/// The ground a semantic chip sits on, given the ink that goes over it.
///
/// **A dark plate in both themes was itself a report.** It fixed one — the
/// tinted fills behind a near-black light-mode ink were grey boxes — and caused
/// the next: a row of near-black chips on a daylit table is a set of holes in
/// it. Dark mode keeps the plate the bright three were chosen for; light mode
/// gets a wash of the chip's own hue, with the deep ink over it.
Color semanticPlate(BuildContext context, [Color? ink]) => _dark(context)
    ? const Color(0xFF11151A)
    : (ink ?? _vsLevelLight).withValues(alpha: 0.13);

/// The three, at their dark-mode brightness, for use ON [semanticPlate].
const Color vsGreenBright = _vsGreenDark;
const Color vsRedBright = _vsRedDark;
const Color vsAmberBright = Color(0xFFFFB020);

/// **THE DARK GROUND A VIVID INK STANDS ON, wherever one does.**
///
/// The modifier badge, the ATK/DEF recess and the HUD's own pill all carry
/// colours chosen for a night sky — the card's red and green, the wallet hues —
/// on panes that are the same glass in both themes. One constant rather than
/// three, because the last four rounds of this were three opacities being kept
/// in step by eye and losing.
///
/// **ONLY THE RECESS TAKES IT.** The HUD's pill and the modifier badges were
/// both given this ground too and both came back as far too dark: they sit ON
/// a daylit pane rather than inside a panel, and a dark lozenge on one is the
/// slab the card itself was never allowed to be. The recess is different — it
/// is an inset in the middle of the card, which is a place a scoreboard is
/// expected to be dark.
const Color vividWellFill = Color(0x990E1620);

/// What reads on [vividWellFill] — the recess's labels and its bar tracks. The
/// pane's own ink is a near-black in daylight and this is not the pane.
const Color vividWellInk = Color(0xFFE9EFF5);

/// Green when this figure beats the one it faces, red when it loses, blue level.
///
/// **THE DARK TRIPLE, IN BOTH THEMES — this is the card's own palette.** The
/// light counterparts above are the brightest members of each hue that still
/// clear 3:1 as ink on white, which is the right rule for a table of text and
/// the wrong one here: the ATK and DEF figures are read as a PAIR against the
/// other side of the same row, and what is being compared is which one is
/// green. "The red and green should be the same as dark mode" has now been
/// asked five times, about this row specifically. See [statToneColor], which
/// is the same decision for the modifiers hanging under it.
Color vsColor(BuildContext context, int mine, int opp) {
  if (mine > opp) return _vsGreenDark;
  if (mine < opp) return _vsRedDark;
  return _vsLevelDark;
}

/// No ramp either, for the same reason: `glassAccent` would take all three of
/// them straight back down to the light counterparts this just stopped using.
Color vsColorOnGlass(BuildContext context, int mine, int opp) =>
    vsColor(context, mine, opp);

/// One side's ATK and DEF, already through `fifaSplit`.
typedef StatSide = ({int atk, int def});

/// What a modifier MEANS, rather than what colour it is.
///
/// A `Color` here was the bug: the modifiers are built in a provider, which has
/// no `BuildContext` and so no idea which pane they are about to be drawn on — so
/// every one of them was a fixed light hue for dark glass and disappeared in
/// daylight. The tone travels; the colour is resolved where it is painted.
///
/// **AND THE SIDE OF THE CARD IS NOT A TONE.** This was `good` / `bad` / `warn`,
/// where `good` meant "in our favour" — so the away side's `+4` for home
/// advantage came out RED while ours came out green, and both of them are the
/// same fact: four rating points added to the figure above. Reported directly —
/// "regardless if that's home or away, it's a plus so it should be green" — and
/// it is the right rule: the modifiers hang off a rating each, so what they
/// colour is the arithmetic on THAT rating, not who benefits.
enum StatTone {
  /// The number itself decides: a plus is green and a minus is red, on either
  /// side of the card. See [_Mod].
  delta,

  /// Nobody's gain. A relegation scrap lifts whoever is in it, so it is the one
  /// modifier that is not a verdict on the fixture — amber on both sides.
  warn,
}

/// The colour a modifier's glyph and figure take.
///
/// [amount] is what picks green from red for [StatTone.delta]; a zero would be a
/// modifier not worth drawing, so it falls on the green side with the pluses.
/// **THE DARK PAIR, IN BOTH THEMES, on this card.**
///
/// The light-mode counterparts above are the brightest members of each hue that
/// still clear 3:1 as ink on white, and that is the right rule for a table of
/// text. It is the wrong rule here and it has now been asked about four times:
/// these are a signed number and a 9pt glyph hung off a rating, read as a PAIR
/// against the other side of the same card, and what a player is comparing is
/// which one is green. A darker green and a darker red compare exactly as well
/// as the mint and the coral and read as a different palette from the one on
/// the same card in dark mode.
///
/// No ramp either, for the same reason: `glassAccent` would take both of them
/// straight back down. `vsRedOn` and `vsGreenOn` keep the flip everywhere else,
/// which is every place these are actually running text.
Color statToneColor(BuildContext context, StatTone tone, int amount) =>
    switch (tone) {
      StatTone.warn => const Color(0xFFFF9800),
      StatTone.delta when amount < 0 => _vsRedDark,
      StatTone.delta => _vsGreenDark,
    };

/// One modifier hanging off a rating: a glyph, a signed number, what it means,
/// and the sentence that explains it.
typedef StatMod = ({String icon, int amount, StatTone tone, String tip});

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
        // **Narrow phones: the bars come off, and the figures stay.** MEASURED
        // in the spec rather than picked (`@media (max-width: 379px)`): the bar
        // width is derived from the card's, and at 375px and under every one of
        // them bottoms out on its 12px floor whatever figure it is drawing —
        // four identical stubs claiming to compare four different numbers,
        // which is worse than no bar. 390px is the first common width where they
        // differ, so the line falls between. It is also what stops the block
        // spilling its own well, since a bar at the floor overflows the row
        // rather than shrinking further.
        //
        // The VIEWPORT, not this card: the spec's rule is a media query, and
        // `rowsWidth` above is already the widest the rows can be without
        // running into a rating, so the card cannot buy the room back.
        //
        // Decided ONCE here and passed down, rather than looked up in each of
        // the four sides: it is one property of the block, and the four have to
        // agree or the mirror breaks.
        //
        // The arithmetic checks out against the real card, which is the viewport
        // less 13 of page inset and 8 of card padding a side. At 390 the rows
        // get 135, the bars 15 each — the spec's own figure. At 375 they get
        // 11.25 and bottom out. And with the bars gone a 320pt phone leaves 86
        // inside the well against 30 + 12 + two 19pt floors, so the figures fit
        // there without the furniture having to give anything up.
        final bars = MediaQuery.sizeOf(context).width >= _barsFrom;

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
                  child: _StatWell(left: left, right: right, bars: bars),
                ),
                Positioned(
                  left: 0,
                  width: ratingBox,
                  child: _Rating(
                    key: const ValueKey('nm-rating-left'),
                    figureKey: const ValueKey('nm-figure-left'),
                    value: leftRating,
                    mods: leftMods,
                    // BOTH sides or neither — see [_Rating._modBand].
                    band: leftMods.isNotEmpty || rightMods.isNotEmpty,
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
                    band: leftMods.isNotEmpty || rightMods.isNotEmpty,
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
  const _StatWell({
    required this.left,
    required this.right,
    required this.bars,
  });

  final StatSide left;
  final StatSide right;
  final bool bars;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        // **A REAL RECESS, and dark in both themes.** It was a 5% whisper,
        // because on a near-white pane a proper wash reads as a slab rather
        // than as depth — true, and it left the four figures standing on the
        // pane itself. Those figures are the DARK triple whatever the theme is
        // (see [vsColor]), and the red is the one that suffers: a coral chosen
        // for a night sky, printed on daylight glass. Reported twice.
        //
        // Taking it properly dark was tried and is what this note is for: the
        // four figures read beautifully and the BARS beside them disappeared,
        // because they are drawn from the pane's own ink and the pane's ink is
        // dark. A recess deep enough for a coral red is a recess nothing else
        // in it survives.
        //
        // So the well is dark AND everything in it is repainted for that
        // ground: the labels and the bar tracks take [vividWellInk], and the
        // figures were already the dark triple. See [vividWellFill] for why it
        // is not as dark as the badge.
        //
        // **A SHADOW UNDER THE FIGURES WAS TRIED FIRST, and it is the reason
        // this well exists.** A tight dark outline on a vivid glyph is the
        // textbook answer to a bright ground and it did not carry — reported as
        // not helping — which is what a 1px edge does against a whole pane of
        // luminance. A ground beats an outline; it just has to be a small one.
        color: vividWellFill,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: vividWellInk.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatRow(
            label: 'ATK',
            leftValue: left.atk,
            rightValue: right.atk,
            bars: bars,
            // Cross-stat: attack is judged against the defence it faces.
            leftColour: vsColorOnGlass(context, left.atk, right.def),
            rightColour: vsColorOnGlass(context, right.atk, left.def),
          ),
          const SizedBox(height: 5),
          _StatRow(
            label: 'DEF',
            leftValue: left.def,
            rightValue: right.def,
            bars: bars,
            leftColour: vsColorOnGlass(context, left.def, right.atk),
            rightColour: vsColorOnGlass(context, right.def, left.atk),
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
    required this.bars,
  });

  final String label;
  final int leftValue;
  final int rightValue;
  final Color leftColour;
  final Color rightColour;
  final bool bars;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Side(
            value: leftValue,
            colour: leftColour,
            mirrored: false,
            bars: bars,
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
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              // The WELL's ink, not the pane's — see [vividWellInk].
              color: vividWellInk,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _Side(
            value: rightValue,
            colour: rightColour,
            mirrored: true,
            bars: bars,
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
    required this.bars,
  });

  final int value;
  final Color colour;
  final bool mirrored;
  final String statKey;

  /// Whether this side draws its bar at all — decided once for the whole block
  /// in [MatchStatRows.build], where the reasoning lives.
  final bool bars;

  @override
  Widget build(BuildContext context) {
    // **THE FIGURE DOES NOT SHRINK. The BAR does.** The spec is
    // `.nm-stat-val { flex: 0 0 auto; min-width: 19px }` against
    // `.nm-stat-bar { flex: 1 }`, and this had them the other way round: the
    // figure took a 2/7 proportional share of the side and the bar took 5/7.
    // A share is not a leftover — there was never "room" for the 19 to apply,
    // so the box measured 9.3px on a 340pt card, NARROWER THAN ONE DIGIT, and
    // every two-figure stat was clipped to its first digit at every width. 91
    // against 81 read as 9 against 8.
    final figure = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 19),
      child: Text(
        '$value',
        key: ValueKey('nm-stat-$statKey'),
        maxLines: 1,
        textAlign: mirrored ? TextAlign.left : TextAlign.right,
        style: TextStyle(
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w900,
          color: colour,
          // Tabular, so the four figures line up down the block instead of
          // jittering by digit width — as the ratings above them already do.
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );

    if (!bars) {
      return Row(
        // Both sides lay out TOWARD the centre label, which keeps the four
        // figures reading as one mirrored comparison instead of drifting to the
        // card's edges.
        mainAxisAlignment: mirrored
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        // Loose, and the ONLY child — so it is handed the whole side rather than
        // a share of it, and takes its intrinsic width whenever that fits. Which
        // is the opposite of what starved it before: a lone flexible child
        // competes with nothing. The floor still applies; this only decides what
        // happens in the corner where even the trimmed row cannot hold two
        // three-digit figures, and there the spec spills into the empty margin
        // beside the ratings while a Flutter Row would put a banner on the card.
        children: [Flexible(child: figure)],
      );
    }

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
        // A TRACK has to be visible on its own, or a bar at 20% reads as a
        // stray mark rather than as a fifth of something — and it is inside the
        // dark recess, so it is a pale wash rather than the pane's dark one.
        // Taking the well dark without this is what made the bars vanish.
        color: vividWellInk.withValues(alpha: 0.20),
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
    required this.band,
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

  /// Whether to hold the band open — see [_modBand]. Decided for the PAIR, not
  /// for this side: a fixture with no modifier at either end (the match page's
  /// own board, always) pays nothing for it.
  final bool band;
  final bool boot;
  final bool bootOnLeft;

  /// The figure's own height, which is what the modifiers hang below.
  static const double _figureHeight = 26;

  /// The band the modifiers sit in, RESERVED whether there are any or not.
  ///
  /// **They were a `Positioned` hanging out of a `Clip.none` stack, and that is
  /// why tapping one did nothing.** Flutter paints outside a box happily and
  /// hit-tests nothing outside it, so the glyphs drew where they were meant to
  /// and every tap on one fell through to the card behind — which opens the
  /// league table. The `Tooltip` explaining home advantage had been unreachable
  /// since it was written. Reported as the icons under the next-match card
  /// needing a popup saying what they are.
  ///
  /// Reserving the band on both sides is what the out-of-flow trick was buying:
  /// in flow and only when present, a side WITH a modifier sat higher than a
  /// side without and the two ratings stopped lining up.
  ///
  /// **Tall enough for the BADGE**, which is what it holds now — at the old 20
  /// the chip was clipped to a sliver with its contents cut off, which reads as
  /// a mark too small to find rather than as a badge.
  static const double _modBand = 26;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _figureHeight,
          child: Stack(
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
              // Hangs into the empty margin rather than widening the figure —
              // in flow it pushed the number off the line it shares with the
              // club name above, so the one fixture in ten with a weakened
              // opponent looked misaligned.
              if (boot)
                Align(
                  alignment: bootOnLeft
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: const Text(
                    '🍀',
                    style: TextStyle(fontSize: 15, height: 1),
                  ),
                ),
            ],
          ),
        ),
        if (band)
          SizedBox(
            height: _modBand,
            child: mods.isEmpty
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final mod in mods) ...[
                        if (mod != mods.first) const SizedBox(width: 2),
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
      // **ON A TAP.** A `Tooltip`'s default trigger on a touch screen is a LONG
      // PRESS, so the comment above — "tapping one says the word" — was a claim
      // the widget did not keep: the `+1` beside the club rating had an
      // explanation nobody could reach without knowing to hold it down. It says
      // where the number comes from, which is the Stadium's Fan Zone tier.
      triggerMode: TooltipTriggerMode.tap,
      // Long enough to READ. The default 1.5s is written for a mouse hovering
      // away, not for a sentence somebody has just asked to see.
      showDuration: const Duration(seconds: 3),
      child: Builder(
        builder: (context) {
          // **THE SIGN IS PRINTED FROM THE NUMBER**, not hardcoded. It was a
          // literal `+`, which is why nothing here could ever have been a
          // subtraction and why the colour had to come from somewhere else.
          // **WHITE ON A SOLID PLATE, not the colour on a tint of itself.**
          // The badge was the league chip's recipe — a 13% wash, a rim, the
          // colour as ink — which on a `+2` is a pale green lozenge with a
          // green mark in it. Reported directly: white on green.
          //
          // The plate is the DAYLIGHT member of the pair in both themes, and
          // that is what makes one recipe work on both: white on the mint
          // `#4ADE80` is 1.8:1, white on `#11913F` is 4.9, and a solid green
          // chip on the dark card reads exactly as well as it does on the light
          // one. The vivid pair stays where it has a dark ground to sit on,
          // which is the ATK/DEF recess above.
          final plate = semanticInk(
            context,
            statToneColor(context, mod.tone, mod.amount),
            light: true,
          );
          return Padding(
            // **A TARGET, not just a mark.** The glyph and its number are 22
            // by 10; the padding is what a thumb actually lands on, and it is
            // inside the tooltip's own detector so it is all live.
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: Container(
              // **A BADGE, and a readable one.** It was a bare glyph and a
              // signed number on the pane, in a colour chosen for a dark
              // ground; asked for directly, put the modifiers in a badge. The
              // pattern is the league sheet's form chip — the colour's own
              // tint for a plate, the colour at 45% for a rim, the colour full
              // strength for the ink — and it is a size up, because the first
              // pass at this was a chip too small to find.
              padding: const EdgeInsets.fromLTRB(5, 3, 6, 3),
              decoration: BoxDecoration(
                color: plate,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GameIcon(mod.icon, size: 10.5, color: Colors.white),
                  const SizedBox(width: 2),
                  Text(
                    '${mod.amount < 0 ? '-' : '+'}${mod.amount.abs()}',
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
