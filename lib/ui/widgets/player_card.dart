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

import 'dart:math' as math;

import 'package:flutter/material.dart';
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

  /// How thick that rim is, at this size.
  ///
  /// **A FIXED 1.4 IS A HAIRLINE ON A BIG ONE.** It was written for the match
  /// feed, where these are 26 points across and 1.4 is a rim; the goal badge
  /// draws the same widget at 72 over a live pitch, and the same 1.4 there is a
  /// line nobody can see — reported from the couch as the scorer's circle having
  /// no border at all. Four per cent of the diameter is 1.4 at 26 and about 3 at
  /// 72, so the rows this was tuned for are untouched and anything drawn large
  /// gets a rim in proportion.
  double get _rimWidth => math.max(1.4, size * 0.04);

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
        border: rim == null ? null : Border.all(color: rim, width: _rimWidth),
        // **And a hard edge OUTSIDE it**, because the rim is the club's own
        // accent and the goal badge stands on grass: a green kit's rim against a
        // pitch is the one case where a correct colour is an invisible one. A
        // shadow with no blur is a second ring — the only way a `BoxDecoration`
        // draws two — and at a third of its thickness it reads as the edge of
        // the badge rather than as a second border.
        boxShadow: rim == null
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  spreadRadius: _rimWidth * 0.34,
                ),
              ],
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

/// The colour a loan is marked in, on the card and on the sheet it opens.
///
/// The detail sheet's own badge, so a borrowed player carries the same teal
/// wherever he is looked at rather than a blue on the grid and a teal one tap
/// later. Fixed rather than kit-derived for the reason the wallet hues are: it
/// is a STATUS, and a status that changes colour with the club is not one.
const Color loanBadge = Color(0xFF26A69A);

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

  /// **SUSPENDED — a red card sitting on his own card.**
  ///
  /// A sending-off bans the player from the next match, and a squad screen that
  /// does not say so is one a manager picks an illegal eleven from. Asked for
  /// from the couch: a red card over the card. It reads exactly like the
  /// injured cross beside it — a status the card wears until it is served.
  bool suspended,

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

  /// **FORM: a rating point, up or down, and it was invisible.**
  ///
  /// It is real — `getEffectiveRating` adds `card.form` straight onto the
  /// composed figure, so a player in bad form is genuinely a point worse than
  /// the number on his card would otherwise say — and `Card.js` has drawn it
  /// since the JS shipped: a green ▲ or a red ▼ in the footer row beside the
  /// seasons count. The port drew the seasons and not the form, and
  /// `squad.form.good` / `squad.form.bad` sat translated in ten catalogues with
  /// nothing able to print either. Reported from the couch: we say form is
  /// down, does it affect ratings, and it needs to be visible.
  ///
  /// Zero draws nothing, which is the JS's rule too — most of a squad is on
  /// neither run, and an arrow on every card says nothing about any of them.
  int form,
});

/// The ▲ and ▼ a card's form is drawn as, in the JS's own two colours.
///
/// `#4ade80` and `#f87171` are `card.css`'s `.card-form.is-up` / `.is-down`,
/// which are the same pair `vsGreenOn`/`vsRedOn` resolve to on a dark surface —
/// so this is the app's own green and red rather than a third one, and it is
/// stated here because a card is drawn on its own rarity fill rather than on a
/// pane and cannot ask `glassAccent` what it is standing on.
Color formInk(int form) =>
    form > 0 ? const Color(0xFF4ADE80) : const Color(0xFFF87171);

String formGlyph(int form) => form > 0 ? '▲' : '▼';

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
                // **THE CARD IS A COLUMN OF THREE BANDS, and the picture is the
                // middle one.** It was a full-bleed portrait with everything
                // else floating over it, and that is not what `card.css` says:
                // `.card` is a flex column of `.card-strip` (4px), `.card-
                // artwrap` (`flex: 1`, `margin: 2px 3px 0`, its own 6px radius
                // and rarity tint) and `.card-footer`, and the image inside the
                // well is `object-fit: contain`.
                //
                // The port drew it `fitWidth` across the whole card instead, so
                // the art was scaled to the card's WIDTH — wider than the well
                // the spec gives it and taller than the space left over — and
                // pinned to the very top, which put the top of the drawing
                // under the border and the rating chip. Reported as the picture
                // being bigger than the text and the border and cut off at the
                // top, which is precisely what a `fitWidth` crop does.
                //
                // A previous pass had tried `contain` over the WHOLE card and
                // backed it out because it left a band of nothing above his
                // head. That is the same fault one step earlier: contained in a
                // 3:4 card a square drawing loses a quarter of the height to
                // slack. Contained in the WELL — the card less the strip and
                // less the footer — it is 94 wide by ~91 tall at bench size,
                // near enough square that the whole figure fits with nothing
                // to spare.
                Column(
                  children: [
                    // `.card-strip` — the rarity, as a bar across the top.
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accentLight, accent],
                        ),
                      ),
                    ),
                    // **THE PICTURE TAKES THE WHOLE CARD, and the words float
                    // on it.** It was a flex column — a well for the art and a
                    // footer under it — which is what `card.css` says, and on a
                    // 90pt card the footer was taking half the height for a
                    // tier chip, a name and a rate. Reported directly: make the
                    // image bigger, they can sit ON the picture.
                    //
                    // The reason the port moved AWAY from an overlay is still
                    // true and is answered rather than ignored: a caption laid
                    // straight on a drawing is unreadable over a light shirt.
                    // It has a scrim under it now — see the footer below — so
                    // what changed is not "no well" but "a well the size of the
                    // card, with the words on a ground of their own".
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(3, 2, 3, 3),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: DecoratedBox(
                            // `--c-tint-strong` over `--c-tint-soft`: the
                            // accent at 0x18 and 0x08, which is what a card
                            // with no art still shows.
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  accent.withValues(alpha: 0x18 / 255),
                                  accent.withValues(alpha: 0x08 / 255),
                                ],
                              ),
                            ),
                            child: view.variant == null
                                ? const SizedBox.expand()
                                : SizedBox.expand(
                                    child: ArtImage(
                                      path: playerImagePath(
                                        view.position,
                                        view.tier,
                                        view.variant!,
                                      ),
                                      // **COVER, not contain.** The well is
                                      // the whole card now, so a contained
                                      // drawing sits in a 3:4 box with a
                                      // quarter of the height as slack. It
                                      // fills, and what it loses off the sides
                                      // is background.
                                      fit: BoxFit.cover,
                                      fallback: PlayerPortrait(
                                        variantIndex: view.variant!,
                                        kitColor: kitColor ?? accent,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // **THE FOOTER IS A SCRIM ON THE PICTURE, not a band under it.**
                // It was a panel in the column, which is what `card.css` says
                // and what cost half a small card's height. Laid over the art it
                // costs nothing, and the gradient is what makes the words
                // readable over a light shirt — fading to nothing at the top so
                // there is no edge across the drawing.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          // CSS `0deg` is bottom-to-top, so the heavier end is
                          // the one against the bottom edge.
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: light
                              ? const [Color(0xF7FFFFFF), Color(0xE8FFFFFF), Color(0x00FFFFFF)]
                              : const [Color(0xF0000000), Color(0xD9000000), Color(0x00000000)],
                          stops: const [0, 0.62, 1],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(5, 3, 5, 4),
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
                                    foreground: view.injured
                                        ? chipRed
                                        : chipInk,
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
                                    Icon(
                                      Icons.healing,
                                      size: 12,
                                      color: chipRed,
                                    ),
                                  // **A LOAN SAYS SO IN WORDS.** It was a pair
                                  // of 12px arrows and nothing else, which on
                                  // the Players tab is a glyph a player has to
                                  // be taught — and a borrowed card is the one
                                  // thing on that grid that is not theirs to
                                  // keep, so it is worth a word. Reported from
                                  // the couch as the loaned players not saying
                                  // LOANED.
                                  //
                                  // `squad.detail.loaned_badge` is that word,
                                  // shipped in ten languages, and the teal is
                                  // the detail sheet's own badge colour — the
                                  // sheet a tap on this card opens says the
                                  // same thing in the same colour, and the
                                  // direction of the loan with it.
                                  if (view.onLoan) ...[
                                    if (view.injured) const SizedBox(width: 3),
                                    Flexible(
                                      child: _Chip(
                                        key: const ValueKey('card-loaned'),
                                        label: t('squad.detail.loaned_badge'),
                                        background: loanBadge,
                                        foreground: Colors.white,
                                        bold: true,
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            // **THE NAME, AND HIS FORM BESIDE IT.** `Card.js`
                            // puts the arrow in the footer row with the seasons
                            // count; this port has no seasons line on the card,
                            // so it goes at the end of the name — which is the
                            // one place on a bench-width card that is not
                            // already spoken for, and it is right beside the
                            // man it is about. See [CardView.form].
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    view.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: captionInk,
                                    ),
                                  ),
                                ),
                                if (view.form != 0) ...[
                                  const SizedBox(width: 3),
                                  Text(
                                    formGlyph(view.form),
                                    key: const ValueKey('card-form'),
                                    // The word, not the glyph, is what a screen
                                    // reader gets: an arrow read aloud is a
                                    // shape rather than a fact.
                                    semanticsLabel: t(
                                      view.form > 0
                                          ? 'squad.form.good'
                                          : 'squad.form.bad',
                                    ),
                                    style: TextStyle(
                                      fontSize: minFontSize,
                                      height: 1,
                                      fontWeight: FontWeight.w900,
                                      color: formInk(view.form),
                                    ),
                                  ),
                                ],
                              ],
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
                            // THE MONEY. What this player actually pays per
                            // second, and a bar whose cycle is one payout of it
                            // — so a faster bar is literally a richer player,
                            // and a sponsor or an injury visibly changes the
                            // speed.
                            if (view.incomePerSec != null) ...[
                              const SizedBox(height: 3),
                              _IncomeRate(
                                ratePerSec: view.incomePerSec!,
                                // **GREEN FOR MONEY IN, RED FOR MONEY OUT.**
                                // The bar and the rate were the club's accent,
                                // which says nothing about the direction the
                                // money is going — and a loan is the one card
                                // on the grid that is COSTING you. Asked for
                                // directly. The bar runs the other way for one
                                // too, so a loan visibly drains where a signing
                                // visibly fills.
                                ink: view.onLoan ? incomeOutInk : incomeInInk,
                                drains: view.onLoan,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ),
                // **THE BAR IS THE CARD'S BOTTOM EDGE.** It was three points
                // tall in the middle of the caption, under the rate, where it
                // was reported as missing — a hairline of faint accent inside a
                // stack of text is not a progress bar anybody sees. Full width
                // along the foot, it is the one thing on the card that is
                // always in the same place on every card.
                if (view.incomePerSec != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _IncomeBar(
                      ratePerSec: view.incomePerSec!,
                      ink: view.onLoan ? incomeOutInk : incomeInInk,
                      track: captionTrack,
                      drains: view.onLoan,
                    ),
                  ),
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
                      // **THE RIBBON GOES IN THE GAP, not across the face.** It
                      // sat at `top: 24` on the right — clear of the chips, and
                      // straight over the portrait's head on a maxed card.
                      // Reported from the couch, naming the space between the
                      // rating and the position as where it would fit, which is
                      // exactly right: that gap is empty on every card and this
                      // is the one thing that wants it.
                      //
                      // `Flexible` with a `FittedBox` inside the ribbon's own
                      // build, so a long localised label gives way to the two
                      // chips rather than pushing either off the card.
                      if (view.maxed || view.atCap)
                        Flexible(
                          child: _Ribbon(
                            label: view.maxed
                                ? t('card.max_ribbon')
                                : t('card.tier_locked', {'tier': view.tier}),
                            // Gold for the top of the game, and a flat warning
                            // colour for the top of this division — one is an
                            // achievement and the other is a reason to get
                            // promoted.
                            background: view.maxed
                                ? const Color(0xFFF9A825)
                                : const Color(0xFF37474F),
                            foreground: view.maxed
                                ? const Color(0xFF241C00)
                                : Colors.white,
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
                // **UNDER THE RATING, opposite the ribbon.** The footer band
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
                // **THE RED, over the art.** Big enough to be the first thing
                // read on the card, because it is the one fact that stops him
                // being picked. Angled, the way a card is held.
                if (view.suspended)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Transform.rotate(
                          angle: -0.22,
                          child: Container(
                            key: const ValueKey('card-suspended'),
                            width: 26,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0342B),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0x66000000),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x73000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
            fontSize: bold ? 13 : minFontSize,
            fontWeight: bold ? FontWeight.w700 : uiBaseWeight,
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
        // **Rounded on all four, because it is no longer in a corner.** It used
        // to hang off the card's right edge and took the edge's own radius on
        // one side only; between the two chips it is a pill like they are.
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4)],
      ),
      // It shares a row with the two chips and they win: a long localised
      // label shrinks rather than pushing either of them off the card.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
            color: foreground,
          ),
        ),
      ),
    ),
  );
}

/// **WHICH WAY THE MONEY IS GOING.** Green in, red out — the same pair the rest
/// of the app uses for a verdict, because that is what this is. It was the
/// club's accent for both, which says nothing at all about direction and left
/// a loan player looking like a signing that happened to be cheap.
///
/// The light members deliberately: a card is a light surface in light mode and
/// a lit one in dark, and these are printed ON it rather than under it.
const Color incomeInInk = Color(0xFF11913F);
const Color incomeOutInk = Color(0xFFE03131);

/// The rate line, on the card's caption.
class _IncomeRate extends StatelessWidget {
  const _IncomeRate({
    required this.ratePerSec,
    required this.ink,
    required this.drains,
  });

  final double ratePerSec;
  final Color ink;
  final bool drains;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      // FLEXIBLE. A card is 90px wide and a rate can be five figures a second
      // at the top tiers; the figure gives ground before the coin that says
      // what it is.
      Flexible(
        child: Text(
          '${drains ? '-' : '+'}${formatRate(ratePerSec)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: ink,
          ),
        ),
      ),
      const SizedBox(width: 2),
      Icon(Icons.monetization_on, size: 9, color: ink),
    ],
  );
}

/// The bar that fills once per payout, along the card's bottom edge.
///
/// The cycle length is DERIVED from the rate rather than picked — see
/// `incomeBarCycleSec`. A hardcoded per-tier speed carries no information: it
/// tracks the badge the card is already wearing, not the money, and income
/// spans four orders of magnitude across the tiers where a tier table spans
/// one.
class _IncomeBar extends StatefulWidget {
  const _IncomeBar({
    required this.ratePerSec,
    required this.ink,
    required this.track,
    required this.drains,
  });

  final double ratePerSec;
  final Color ink;
  final Color track;

  /// Empties instead of filling. A loan player is a wage going out, and a bar
  /// that fills is the wrong picture of that.
  final bool drains;

  @override
  State<_IncomeBar> createState() => _IncomeBarState();
}

class _IncomeBarState extends State<_IncomeBar>
    with SingleTickerProviderStateMixin {
  /// **NO LISTENER.** The painter repaints off the controller directly — see
  /// `_FillPainter`'s `repaint:` — so a Dart callback on every frame of every
  /// bar bought nothing but the per-cycle float, and the float has gone. On a
  /// full grid that was sixteen listeners running at sixty hertz behind a
  /// scrolling list.
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
  void didUpdateWidget(_IncomeBar old) {
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
    // NOT a `BarFill`: that is a layout, and a grid of these re-laid-out and
    // repainted every card every frame. This is one rect, painted off the
    // clock, in a layer a few points tall.
    return SizedBox(
      key: const ValueKey('card-income'),
      height: 5,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _FillPainter(
            fill: _fill,
            ink: widget.ink,
            track: widget.track,
            drains: widget.drains,
          ),
        ),
      ),
    );
  }
}

class _FillPainter extends CustomPainter {
  _FillPainter({
    required this.fill,
    required this.ink,
    required this.track,
    required this.drains,
  }) : super(repaint: fill);

  final Animation<double> fill;
  final Color ink;
  final Color track;
  final bool drains;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = track);
    final t = fill.value.clamp(0.0, 1.0);
    // A loan EMPTIES: same clock, same cycle, read the other way round.
    final w = size.width * (drains ? 1 - t : t);
    canvas.drawRect(
      Rect.fromLTWH(drains ? size.width - w : 0, 0, w, size.height),
      Paint()..color = ink,
    );
  }

  @override
  bool shouldRepaint(_FillPainter old) =>
      old.fill != fill ||
      old.ink != ink ||
      old.track != track ||
      old.drains != drains;
}
