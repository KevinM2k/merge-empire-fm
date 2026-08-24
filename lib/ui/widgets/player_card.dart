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
import 'package:merge_empire_fc/ui/widgets/bar_fill.dart';
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/data/card_theme.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/ui/widgets/player_portrait.dart';

/// A player's full-length artwork, as a sheet's hero.
///
/// **Shared, because two sheets about one player should show the same player.**
/// The squad sheet gave him 260px of full-length figure and the sell sheet a
/// 72px thumbnail of his merge card — the same man, described twice, once as a
/// person and once as an inventory item. What you are deciding about is the
/// player, so it is the player you look at.
///
/// `cover` anchored to the TOP: this is a portrait crop and centring the slack
/// cuts the head off.
class PlayerHeroArt extends StatelessWidget {
  const PlayerHeroArt({
    required this.position,
    required this.tier,
    required this.variant,
    this.height = 260,
    this.dimmed = false,
    super.key,
  });

  final String position;
  final int tier;
  final int variant;

  /// 260 is the squad sheet's, and the number the crop was chosen against.
  final double height;

  /// Greyed, for a player who cannot take the field.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ArtImage(
        path: playerImagePath(position, tier, variant),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        dimmed: dimmed,
        fallback: PlayerPortrait(variantIndex: variant, kitColor: kit.accent),
      ),
    );
  }
}

/// A player's face — round, small, and cropped to the head.
///
/// **The art is a FULL-LENGTH figure**, so the crop is `cover` anchored to the
/// TOP: centred, a square box of a standing man is a torso. That is the same
/// rule the squad sheet's [PlayerHeroArt] and the pitch token already follow —
/// what differs here is only the size and the shape, which is exactly why it
/// lives beside them rather than being written a third time.
///
/// Built for the match feed, where a goal names a player and the art of the
/// player it names belongs beside it.
class PlayerFace extends StatelessWidget {
  const PlayerFace({
    required this.position,
    required this.tier,
    required this.variant,
    this.size = 26,
    this.ring,
    super.key,
  });

  final String position;
  final int tier;
  final int variant;
  final double size;

  /// A rim, for a face that has to read against a busy row. Null for none.
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final rim = ring;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kit.surface,
        border: rim == null ? null : Border.all(color: rim, width: 1.4),
      ),
      // Clipped INSIDE the rim: a child filling the box paints over the
      // border's own curve otherwise — the same fault the cards' scrim had.
      child: ClipOval(
        child: ArtImage(
          path: playerImagePath(position, tier, variant),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          fallback: PlayerPortrait(variantIndex: variant, kitColor: kit.accent),
        ),
      ),
    );
  }
}

/// How many of these fit across a bench grid of [width].
///
/// **Three is the FLOOR, not the answer — above 359 points.** A max-extent
/// delegate fits as many cards as the width allows, which is four on most
/// phones, and four across a sheet an inch or two wide leaves each one too
/// small to read the face on. A tablet earns the columns its width actually
/// pays for.
///
/// **Below that the floor was the bug it was written to prevent.** `.bench-grid`
/// drops to two at `max-width: 359px`, and three across 320 points is exactly
/// the "too small to read the face on" case — so the floor was enforcing it
/// rather than preventing it on the one size where it matters most.
///
/// Lives here rather than on either screen because BOTH benches use it — the
/// squad's and the match's — and two different answers to the same question
/// would read as a bug.
int benchColumns(double width) {
  // **TWO ON THE NARROWEST PHONES, which is `.bench-grid`'s own
  // `max-width: 359px` step and which the floor of three was overriding.** The
  // floor exists so a four-column delegate cannot squeeze a sheet an inch wide
  // — and that is the same argument, one size further down: three across 320
  // points is the case it was written against, not an exception to it.
  if (width <= 359) return 2;
  final earned = (width / benchColumnWidth).floor();
  return earned < 3 ? 3 : earned;
}

/// The width one bench card wants before another column is worth having.
const double benchColumnWidth = 132;

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

  /// The trait he carries, or null for a card that has never rolled one.
  ///
  /// **The glyph and the level, not the name.** A trait is the one thing on a
  /// card that is neither the position nor the rating, and it was visible only
  /// on the sheet a tap opens — so picking an eleven, or choosing who comes on,
  /// was done blind to the half of a player's worth the game asks him to roll
  /// for. The emoji is the trait's own and needs no translating; [title] is the
  /// localised `⚽ Finisher III` and it is what a screen reader is given.
  ({String icon, String level, String title})? trait,
});

class PlayerCard extends StatelessWidget {
  const PlayerCard({
    super.key,
    required this.view,
    this.light,
    this.onTap,
    this.selected = false,
    this.kitColor,
  });

  final CardView view;

  /// Light mode swaps the BODY for a pale tint of the same rarity. The chips
  /// stay dark so their bright rarity text stays readable on top.
  /// Whether to wear the light palette, or null to take it from the theme.
  ///
  /// **NULL IS THE ANSWER ALMOST EVERYWHERE.** It was a `bool` defaulting to
  /// false, so a card was dark unless its caller remembered — and seven callers
  /// each remembering is seven chances to forget, which is how the squad, the
  /// bench and the pickers ended up with dark cards on a light page. Resolved
  /// here, from the theme the card is actually being drawn in.
  ///
  /// It stays overridable for the one case that is not about the theme: a card
  /// lifted onto a drag overlay or laid on a dark scrim decides for itself.
  final bool? light;

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
    final light =
        this.light ?? Theme.of(context).brightness == Brightness.light;
    final body = light ? theme.bgLight : theme.bg;
    // What sits ON the caption scrim — see the note where it is drawn. Dark ink
    // over a white scrim, light ink over a black one; the bars' tracks follow.
    final captionInk = light ? const Color(0xFF1A1F26) : Colors.white;
    final captionTrack = light ? Colors.black26 : Colors.white24;
    // **THE CHIPS WERE DARK IN BOTH THEMES, and they are what a light-mode card
    // still reads as dark at the foot of.** The scrim under them was fixed a
    // pass ago and the report kept coming back, which is the tell: the band is
    // white and the TIER CHIP sitting on it is `#3d2000`.
    //
    // The old pairing is coupled and the note above it says so — the ink is
    // `accentLight`, a PALE tier colour, which needs a dark ground to be read
    // off. **Swapping the two does not work either**: four of the nine accents
    // are `#ffaa00`, `#00c8ff` and friends, and none of them carries on white.
    //
    // So light mode inverts the JOB of the two rather than their values. The
    // contrast comes from near-black INK — the same `captionInk` the name
    // beside it already uses — and the tier is carried by a pale TINT of its
    // own colour. Dark mode is untouched: there the tint would vanish and the
    // pale ink is what carries.
    final chipBg = light
        ? Color.lerp(Colors.white, accentLight, 0.35)!
        : cssColor(theme.labelBg);
    final chipInk = light ? captionInk : accentLight;
    // Red on a white chip at `redAccent` is the same fault one shade along.
    final chipRed = light ? const Color(0xFFB3261E) : Colors.redAccent;

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
          // **CLIPPED TO THE INSIDE OF THE BORDER, not the outside.**
          // `Container.clipBehavior` clips to the decoration's OUTER path, so a
          // child that fills the box paints over the border's own curve at every
          // corner — the portrait at the top, the caption scrim at the bottom.
          // That was invisible while the scrim was black on a dark card; a white
          // one in light mode showed the border going missing at all four
          // corners.
          //
          // The child's box is already inset by the border, so what it needs is
          // the border's own radius LESS its width, which is the curve of the
          // hole it is sitting in.
          child: ClipRRect(
            borderRadius: BorderRadius.all(
              Radius.circular(10 - (selected ? 3 : 2)),
            ),
            child: Stack(
              children: [
                if (view.variant != null)
                  Positioned.fill(
                    // **AS WIDE AS THE CARD, AND STARTING AT ITS TOP.** `contain`
                    // fits the whole drawing inside the frame and centres the
                    // slack, which on art squarer than the card left a band of
                    // nothing above his head and shrank him to pay for it. Wider
                    // is fine — what is cropped off the bottom is his boots, and
                    // the name band is over them anyway.
                    child: ArtImage(
                      path: playerImagePath(
                        view.position,
                        view.tier,
                        view.variant!,
                      ),
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topCenter,
                      fallback: PlayerPortrait(
                        variantIndex: view.variant!,
                        kitColor: kitColor ?? accent,
                      ),
                    ),
                  ),
                // THREE BANDS, and the middle one is the picture.
                //
                // Everything used to be one `spaceBetween` column over the art:
                // six items spread evenly down the card, so the tier chip, the
                // status icons and the name landed wherever the count of them put
                // them and the portrait was whatever was left behind. Chips at the
                // top, art in the middle with nothing on it, and every word in one
                // legible block at the foot.
                Positioned(
                  top: 5,
                  left: 5,
                  right: 5,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: _Chip(
                          label: '${view.rating}',
                          background: chipBg,
                          foreground: chipInk,
                          bold: true,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: _Chip(
                          label: positionLabel[view.position] ?? view.position,
                          background: chipBg,
                          foreground: chipInk,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    // The band the words sit on. The portrait behind them is a
                    // photograph with no say in what colour it is under a caption,
                    // so the caption brings its own.
                    //
                    // **AND IT FOLLOWS THE THEME.** It was a black scrim in both,
                    // so a light-mode grid was a page of pale cards with dark feet
                    // — the one part of the card that had not been told which
                    // theme it was in. A scrim's job is contrast, and white does
                    // that for dark ink exactly as well as black does for light.
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: light
                            ? const [Color(0x00FFFFFF), Color(0xE6FFFFFF)]
                            : const [Color(0x00000000), Color(0xC7000000)],
                        stops: const [0, 0.55],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(5, 14, 5, 5),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // WHICH CARDS PAIR UP. Two cards with the same
                              // definition merge whatever portrait or name they
                              // happen to carry, so without the tier on the face
                              // there is no way to tell by looking — the grid's
                              // whole mechanic had no visual cue.
                              Flexible(
                                child: _Chip(
                                  key: ValueKey('card-tier-${view.tier}'),
                                  label: view.injured
                                      ? t('card.inj_short')
                                      : (tierLabel[view.tier] ??
                                            'T${view.tier}'),
                                  background: chipBg,
                                  foreground: view.injured ? chipRed : chipInk,
                                  bold: true,
                                ),
                              ),
                              // Status beside the tier rather than on a line of
                              // its own: an injury is what a player scanning a
                              // full grid is looking for, and it belongs with the
                              // thing it disqualifies him from.
                              if (view.injured || view.onLoan) ...[
                                const SizedBox(width: 3),
                                if (view.injured)
                                  Icon(Icons.healing, size: 12, color: chipRed),
                                if (view.onLoan)
                                  const Icon(
                                    Icons.swap_horiz,
                                    size: 12,
                                    color: Colors.lightBlueAccent,
                                  ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            view.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: captionInk,
                            ),
                          ),
                          if (view.fitness != null) ...[
                            const SizedBox(height: 3),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                key: const ValueKey('card-fitness'),
                                value: view.fitness!.clamp(0.0, 1.0),
                                minHeight: 3,
                                backgroundColor: captionTrack,
                                valueColor: AlwaysStoppedAnimation(
                                  view.fitness! < 0.34
                                      ? Colors.redAccent
                                      : accentLight,
                                ),
                              ),
                            ),
                          ],
                          // THE MONEY. What this player actually pays per second,
                          // and a bar whose cycle is one payout of it — so a
                          // faster bar is literally a richer player, and a sponsor
                          // or an injury visibly changes the speed.
                          if (view.incomePerSec != null) ...[
                            const SizedBox(height: 3),
                            _Income(
                              ratePerSec: view.incomePerSec!,
                              ink: accentLight,
                              track: captionTrack,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                // **UNDER THE RATING, opposite the ribbon.** The caption band
                // is full at bench width — tier, status, name and two bars —
                // and the art is where a card has room. Top left is the side
                // the rating already owns, so the two things that say how good
                // he is read as one column.
                if (view.trait case final trait?)
                  Positioned(
                    top: 24,
                    left: 5,
                    child: TraitBadge(
                      icon: trait.icon,
                      level: trait.level,
                      title: trait.title,
                    ),
                  ),
                // Across the corner, because at bench size a pip cannot carry a
                // word and every corner is already spoken for.
                if (view.maxed || view.atCap)
                  Positioned(
                    // UNDER the rating chips, not over them. At the very top it
                    // landed on the position chip, which is the one thing on the
                    // card a player is comparing across a grid.
                    top: 24,
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
      ),
    );
  }
}

/// The trait a card carries, as its own glyph and its level.
///
/// **One badge, drawn the same everywhere.** The bench and the pickers draw a
/// [PlayerCard] and the eleven draw a [PitchToken]; two badges would drift, and
/// a trait that looks like one thing on the pitch and another on the bench is a
/// trait the player has to learn twice.
class TraitBadge extends StatelessWidget {
  const TraitBadge({
    required this.icon,
    required this.level,
    required this.title,
    this.size = 9,
    super.key,
  });

  /// The trait's own emoji — no language in it, which is why it can go on a
  /// badge this small.
  final String icon;

  /// `I`, `II` or `III`.
  final String level;

  /// The localised `⚽ Finisher III`, for anything that reads rather than looks.
  final String title;

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: title,
    child: Container(
      key: const ValueKey('card-trait'),
      padding: EdgeInsets.symmetric(horizontal: size * 0.44, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xC7000000),
        borderRadius: BorderRadius.circular(size * 0.7),
        border: Border.all(color: const Color(0x38FFFFFF)),
      ),
      child: Text(
        level.isEmpty ? icon : '$icon $level',
        // Emoji come off the platform's own font; the level is the app's.
        style: TextStyle(
          fontSize: size,
          height: 1.2,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    ),
  );
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
                  builder: (context, _) => BarFill(
                    fraction: _fill.value,
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
