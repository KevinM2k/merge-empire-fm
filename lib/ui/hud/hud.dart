/// The floating resource bar.
///
/// It is not a bar: the JS removed the header background so the scene shows
/// through, and each stat is its own chip. Every value comes off a derived
/// provider, so a coin landing rebuilds the coin label and nothing else.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/util/kit_theme.dart' show whiteInkMinContrast;
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart'
    show vsAmberPlate, vsGreenPlate, vsRedPlate;
import 'package:merge_empire_fc/ui/widgets/store_button.dart'
    show storeCoinFace, storeGemFace;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/badge_engine.dart';
import 'package:merge_empire_fc/engine/energy_engine.dart';
import 'package:merge_empire_fc/engine/season_end.dart' show prestigeLevel;
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/hud/hud_boosts.dart';
import 'package:merge_empire_fc/ui/hud/coin_counter.dart';
import 'package:merge_empire_fc/ui/hud/coin_flight.dart'
    show coinChipKey, coinRewardProvider;
import 'package:merge_empire_fc/ui/hud/hud_chip.dart';
import 'package:merge_empire_fc/ui/popups/income_breakdown_card.dart';
import 'package:merge_empire_fc/ui/screens/shop/currency_sheet.dart';
import 'package:merge_empire_fc/ui/screens/trophies/trophy_room_sheet.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/badge_icon.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

/// The pip cap, which the Energy Director upgrade raises from 10 to 15. Reading
/// it rather than hardcoding 10 is what stops an upgraded player seeing "15/10".
final energyMaxProvider = savePick<int>(getEnergyMax);

/// The three resources' fixed hues. The bar behind them swings from deep green to
/// bright yellow with the kit and the theme, and no accent-derived set survives
/// that range — so the coin is gold, the bolt blue and the gem cyan on EVERY kit,
/// which is what keeps them told apart at a glance.
/// **THREE READINGS, THREE COLOURS — AND TWO OF THEM WERE THE SAME.** Energy was
/// `#57BCFF` and gems `#7FD4FF`: twenty degrees of hue apart, both pale, both
/// blue. Colour-coding that a player cannot tell apart is not colour-coding, and
/// on the club's own chrome the paler of the two sank into the bar.
///
/// Separated as far as three hues can be here, and the constraints are tighter
/// than they look. GOLD is money and is not negotiable. The GEM keeps cyan —
/// which is what a gem is — but a vivid one rather than a wash. That leaves
/// energy, and the obvious answer of yellow is the one hue it cannot have,
/// because that is the coins; and orange came out 30° from gold, which is the
/// same mistake one hue over.
///
/// **GREEN, which used to be ruled out and no longer is.** The reason it was
/// out is written in the sentence above this one in every earlier draft — "green
/// is the chrome the icons sit on and half the kits are some shade of it" — and
/// that stopped being true the day the bars went neutral. See [hudChrome]. It
/// took a spell as violet in between, and the report from the couch was that
/// energy wants to be GREEN WHEN IT IS FULL AND RED WHEN IT IS LOW, which is
/// what a tank reads as everywhere else in the world. So the bolt is green, the
/// ladder runs down from it, and the hue and the warning are the same
/// instrument rather than two.
const Color hudCoinInk = Color(0xFFFFD700);
const Color hudEnergyInk = Color(0xFF4ADE80);
const Color hudGemInk = Color(0xFF22D3EE);

/// A figure takes its own WALLET's ink, and it does not move.
///
/// **A NUMBER THAT CHANGES COLOUR IS A DIFFERENT NUMBER.** All three readings
/// were `glassAccent(context, kit.accentBright)` — the club's accent, put
/// through the pane's contrast ramp — so the coins, the gems and the energy
/// were one colour on a dark page, another on a light one, and a third colour
/// again on the next club. Reported in one line: they should be the same
/// everywhere.
///
/// The bar had already answered this question once, for the GLYPHS, and the
/// answer is reused rather than re-argued: you cannot fix a bright ink by
/// darkening it, so the ink is left exactly alone and the BACKING changes —
/// see [hudFigureShadows].
///
/// **A neutral was tried first and it is the interesting failure.** White is
/// the obvious "one colour everywhere", on the reasoning that the glyph
/// carries identity and the figure carries information. But the pane swings
/// from near-white in daylight to near-black at night, and NO neutral survives
/// both: white on the light pane is a white core inside a dark halo, which
/// reads as a smudge rather than as a number. The wallet hues are the one
/// palette in this bar already proven against both panes — that is exactly
/// what `hud_chip.dart` picked them for — so the figure joins its glyph
/// instead of standing apart from it, and the pair reads as one object.
const Color hudFigureInk = hudCoinInk;

/// **NOTHING BEHIND THE FIGURES.** They wore a soft dark halo in daylight to
/// buy a fixed ink some contrast against a pane that ramps — and the report
/// from the couch was that the bar looked smudged, the violet energy figure
/// worst of all: a thin `#A855F7` numeral over a dark blur is a purple core in
/// a grey cloud rather than a number. Asked for directly, in both themes.
///
/// The contrast the halo was buying is bought by [hudInk] instead, which is the
/// same answer one layer down: deepen the hue rather than put something behind
/// it. Kept as a function rather than deleted so the one call site still reads
/// as "and this is what goes behind it", and so the answer lives in one place
/// if the daylight pane ever needs one again.
List<Shadow>? hudFigureShadows(BuildContext context) => null;

/// The cap beside the energy figure — quiet, and fixed with it.
///
/// It was `glassMuted`, which ramps with the pane like everything else did.
/// The energy hue held back to 62% is the same relationship in a colour that
/// does not move.
///
/// **A FADED WHITE, now the badge is the colour.** It was the bolt's own green
/// at 62%, which was right when the figure stood on glass and is green-on-green
/// inside a green chip. The reading beside it takes the badge's own lightened
/// ink — see `hudBadgeInk` — and the cap is quieter than that: it is the cap,
/// not the reading.
const Color hudCapInk = Color(0x9EFFFFFF);


/// Energy running LOW, and energy nearly gone. Fixed, and these are the dark
/// theme's own values — which is what "match the red and green dark mode uses"
/// has been asking for.
const Color hudEnergyLowInk = Color(0xFFFF9800);
const Color hudEnergyEmptyInk = Color(0xFFF87171);

/// The energy figure's colour, full to empty.
///
/// **THE COLOUR ONLY MEANS SOMETHING WHEN IT IS A WARNING.** The ladder used to
/// have four rungs — the kit's accent at the cap, then green, amber, red — and
/// the top two both meant "you are fine". So the one figure in the bar whose
/// colour carries information spent most of its life saying nothing with it,
/// in a colour that changed with the club and the theme on top.
///
/// Three rungs, and the first of them is the bolt's own hue: plenty looks like
/// the glyph beside it, and a colour LEAVING that hue is the warning. No
/// context, because none of it depends on the theme.
///
/// **And that hue is GREEN again, which is the whole point of the ladder.**
/// Full green, running down through amber to red is what a tank reads as
/// without being told, and for a spell the top rung was a violet that had to
/// be learned. Asked for directly. See [hudEnergyInk] for why green was ever
/// off the table and why it is back on it.
Color energyInk(num current, int max) {
  if (max <= 0) return hudEnergyInk;
  final pct = current / max * 100;
  return pct > 50
      ? hudEnergyInk
      : pct > 20
      ? hudEnergyLowInk
      : hudEnergyEmptyInk;
}

/// How many adventures this save has finished — the figure the crest's chip
/// shows. Zero on a save that has never prestiged, and the chip is then not
/// drawn at all.
final prestigeLevelProvider = savePick<int>(prestigeLevel);

/// The badge the player is wearing. The JS hangs it off the manager avatar in
/// the top-left; that avatar is not drawn yet, so the badge stands on its own
/// until it is. It has to be SOMEWHERE: the Trophy Room's "Set as Badge" is
/// otherwise a button with no visible effect anywhere in the game.
final equippedBadgeProvider = savePick<String>(getEquippedBadgeId);

/// How much room the HUD needs above a screen's own content.
///
/// The JS has no equivalent: there, `.app-body` starts BELOW the bar
/// (`margin-top: --hud-height`) so no screen pays it any attention. Here the HUD
/// floats over the content, so every screen clears it — and three of them had
/// picked their own number while the Shop had picked none at all, which is why
/// the Shop's first tile sat under the coin counter.
///
/// One constant, so a change to the bar's height moves every screen with it.
///
/// 56 is the bar itself; the extra 10 is a MARGIN under it. Without the gap the
/// first thing on every page sat directly against the cluster's bottom edge —
/// legible, but reading as one block with the HUD rather than as the start of the
/// page.
/// How tall the bar itself is: the crest's TAP TARGET, plus the row's padding.
///
/// **48, not the 38 the crest is DRAWN at.** An `IconButton` will not go below
/// the platform's minimum touch size, and the crest is the tallest thing in the
/// row — the chips come out at 31 — so it is what sets the bar's height.
const double hudBarHeight = 48 + 6 * 2;

/// The bar, plus the gap under it.
///
/// **56 WAS FOUR PIXELS SHORT**, and the answer came from measuring rather than
/// from looking: the queue asked whether this was too DEEP, and with the bar at
/// 60 a page starting at `56 + 10` began six pixels UNDER the glass instead of
/// ten clear of it. `hud_test.dart` measures the rendered band against this, so
/// the next thing that changes the bar's height fails the build rather than
/// quietly sliding every page under it.
const double hudClearance = hudBarHeight + hudBottomMargin;

/// The gap between the bar and whatever the page starts with.
const double hudBottomMargin = 10;

/// The same clearance, plus whatever the notch takes.
///
/// The shell no longer wraps its tab content in a top `SafeArea`: it did, and
/// that stopped every screen's BACKGROUND at the notch — so the home screen's
/// diorama ended in a bar of page colour instead of running to the top of the
/// glass, which is where the JS puts it (`.ps-holder` is `position: fixed;
/// top: 0` precisely so it escapes). The ground bleeds now and the CONTENT clears
/// the notch itself, which is this.
///
/// [underBar] is false on the Play tab, and that is the only place it is:
/// [hudBottomMargin] exists to separate a page from the BAR above it, and on the
/// diorama there is no bar — the cluster floats and the scene runs to the top of
/// the screen. Ten pixels of nothing under an invisible bar is ten pixels the
/// card and the pitch could have had.
double hudClearanceOf(BuildContext context, {bool underBar = true}) =>
    MediaQuery.paddingOf(context).top +
    (underBar ? hudClearance : hudClearance - hudBottomMargin);

class Hud extends ConsumerWidget {
  const Hud({super.key, this.onSettings});

  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // **THE HUD LOOKS THE SAME ON EVERY TAB.** It did not: the Play tab put each
    // reading in its own pane of glass and everywhere else they were themed
    // pills, so the same instrument read as two — and the glass version was the
    // worse of them, because four small panes each with a rim and a shadow read
    // as embossed buttons rather than as status. One cluster, one pill, all four
    // tabs; see `HudCluster`.
    //
    // What is still per-tab is the BAND behind the bar, and that is a different
    // question: off the Play tab content scrolls under the HUD and has to be
    // blurred, and on it the diorama is meant to show.
    final onScene = ref.watch(shellControllerProvider).tab == ShellTab.home;
    if (!onScene) {
      // A REAL BLUR ACROSS THE WHOLE STRIP, not four blurred chips with gaps
      // between them. Content scrolls under this bar on every tab but Play, and
      // through the gaps it went past in full focus — so the HUD read as four
      // dark boxes with a shop tile sliding between them. One backdrop filter
      // over the band, and anything behind it is genuinely out of focus.
      return _FrostedBar(child: _bar(context, ref));
    }
    return Padding(
      // The Play tab has no bar to frost — the scene shows through — so the
      // notch is cleared here instead. See `_FrostedBar` for why neither is
      // a `SafeArea` around the whole HUD any more.
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: _bar(context, ref),
    );
  }

  Widget _bar(BuildContext context, WidgetRef ref) {
    // FIXED, and haloed rather than ramped — see [hudFigureInk]. Each figure
    // wears its own wallet's ink, so the glyph and the number are one object.
    // **NO COLOUR HERE ANY MORE.** Each figure is printed on its own badge and
    // takes that badge's ink — see `HudChip`, which hands it down through a
    // `DefaultTextStyle`. Naming a colour at this level is what would put a
    // gold figure on a gem badge.
    const valueStyle = TextStyle(fontWeight: FontWeight.w700, fontSize: 13);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      // TWO things, at the two ends. `spaceBetween` was wrong when this row held
      // four separate chips — it opened gaps between them and they drifted apart
      // into four unrelated readings — and it is right now they are one cluster:
      // crest at the left edge, cluster at the right, nothing to spread.
      //
      // A `Spacer` cannot do it any more either. It is an `Expanded` at flex 1
      // and the cluster is a `Flexible` at flex 1, so the two SPLIT the free
      // space — and a loose Flexible that does not use all of its share leaves
      // the remainder stranded on the right of the row, which put 46px of
      // nothing between the cog and the edge.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // The crest and the prestige count are ONE group at the left edge —
          // `.hud-cluster` in `hud.css`, which holds exactly these two.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const ValueKey('hud-badge'),
                tooltip: t('trophy.title'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                // BIG. It is the club's own crest and the way into the trophy
                // room, and at 26 it was the smallest thing on a bar of 16px
                // icons sitting in chips — a badge that reads as a bullet
                // point.
                icon: BadgeIcon(
                  badgeId: ref.watch(equippedBadgeProvider),
                  size: 38,
                ),
                onPressed: () => showTrophyRoomSheet(context),
              ),
              const HudPrestige(),
            ],
          ),
          // **BETWEEN THE CREST AND THE CLUSTER, which is where the JS puts
          // them** — beside the income rate, because what belongs next to a
          // rate is what changes it. Only the boosts that affect IDLE income
          // for that reason; a match-only one goes in the pre-match card and
          // the income breakdown instead.
          const HudBoosts(),
          // `.hud-chips { margin-left: auto }` — the resources are a group on the
          // RIGHT and the crest is on the left, which is the JS's own layout. The
          // port had them all packed against the badge with the empty half of the
          // bar on the right.
          // ONE BOX round all four. See `HudCluster`.
          //
          // **It SCALES rather than overflowing.** Four readings in one pill is
          // a fixed width where four separate chips with gaps between them had
          // slack to give, and on a 400px screen it was 1.8px over. A caption
          // that scales down a point is the same answer the fixture caption
          // gives, and it beats both an ellipsis and a yellow overflow stripe.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: HudCluster(
                children: [
                  HudChip(
                    key: const ValueKey('hud-coins'),
                    iconColor: hudCoinInk,
                    icon: Icons.monetization_on,
                    semanticLabel: t('hud.aria.income_breakdown'),
                    // **The FIGURE opens the books; the + buys coins.** That is
                    // the JS's own split, and this chip has carried the aria
                    // label for the breakdown since it was written with nothing
                    // behind it — so the one screen that says where the idle
                    // rate comes from, and why a loan is eating it, had no door.
                    onTap: () => showIncomeBreakdown(
                      context,
                      state: ref.read(gameProvider).state,
                    ),
                    trailing: HudPlus(
                      key: const ValueKey('hud-coins-plus'),
                      label: t('nav.shop'),
                      // The SHEET, not the tab: a player who tapped the coin counter
                      // wants to buy coins, not to be taken somewhere and shown where
                      // they are. See `currency_sheet.dart`.
                      onTap: () =>
                          showCurrencySheet(context, ShopSection.coins),
                    ),
                    child: CoinCounter(
                      key: coinChipKey,
                      value: ref.watch(coinsProvider),
                      style: valueStyle,
                      // Swells when a REWARD lands and not when the players'
                      // own trickle does — see `coin_flight.dart`.
                      reward: ref.watch(coinRewardProvider),
                    ),
                  ),
                  HudChip(
                    key: const ValueKey('hud-energy'),
                    icon: Icons.bolt,
                    // **THE BADGE IS THE LADDER.** Energy is the one wallet
                    // whose colour carries a reading rather than an identity —
                    // green at the top, down through amber to red — and now the
                    // badge is the colour, the badge is what has to say it. See
                    // [energyInk].
                    iconColor: energyInk(
                      ref.watch(energyProvider),
                      ref.watch(energyMaxProvider),
                    ),
                    semanticLabel: t('hud.aria.energy'),
                    trailing: HudPlus(
                      key: const ValueKey('hud-energy-plus'),
                      label: t('hud.aria.energy'),
                      // The energy popup owns what happens next; the HUD only says the
                      // player asked for it.
                      onTap: () => emit('nav:energy'),
                    ),
                    // The COUNT carries the ladder; the cap beside it stays quiet, so
                    // the colour reads as "how much is left" rather than as a warning
                    // about the chip.
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${ref.watch(energyProvider).floor()}',
                            style: valueStyle,
                          ),
                          TextSpan(
                            text: '/${ref.watch(energyMaxProvider)}',
                            style: valueStyle.copyWith(
                              fontSize: 10,
                              color: hudCapInk,
                              // **Quiet, not invisible.** It was `glassMuted`,
                              // which ramps with the pane like the figures used
                              // to; [hudCapInk] is the same relationship to the
                              // figure in a colour that does not move, and it
                              // keeps the halo underneath.
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  HudChip(
                    key: const ValueKey('hud-gems'),
                    icon: Icons.diamond,
                    iconColor: hudGemInk,
                    semanticLabel: t('shop.section.gems'),
                    // No + of its own: the whole chip opens the packs, which keeps a
                    // third resource from widening the row by another mini-badge.
                    onTap: () => showCurrencySheet(context, ShopSection.gems),
                    child: Text(
                      '${ref.watch(gemsProvider)}',
                      style: valueStyle,
                    ),
                  ),
                  HudChip(
                    key: const ValueKey('hud-cog'),
                    icon: Icons.settings,
                    // Bigger, because it is the one item with no figure next to it —
                    // at the resources' 16 it read as the smallest thing in the row.
                    iconSize: 20,
                    semanticLabel: t('hud.aria.settings'),
                    onTap: onSettings,
                    child: const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The chrome behind the top bar and the bottom tab bar: LIGHT on a light theme,
/// DARK on a dark one, faintly the club's hue and never more than that.
///
/// **A DELIBERATE DIVERGENCE FROM THE JS, and it is the fix for a whole class of
/// bug.** The spec makes the two bars the one structural use of the kit colour —
/// "solid accent-coloured chrome" — so in light mode the bar was the accent at
/// full strength and in dark mode the accent blended most of the way to black.
/// Which means the luminance of both bars swung with the club: a claret bar and
/// a yellow bar want opposite inks, and every ink standing on one had to be
/// argued about separately. There are three long notes in this file that are
/// nothing but that argument.
///
/// **And on the bottom bar it went past awkward into invisible.** The tabs print
/// `kit.accentInk`, which is measured against a FILLED accent — correct for a
/// button. The dark chrome is not a filled accent, it is the accent at 15% over
/// black, so a pale kit (yellow, cyan, white) resolved `accentInk` to the
/// near-black `#0d0d0d` and painted it on a near-black bar. Reported as the
/// bottom HUD making the icons invisible on some themes.
///
/// So the bars take the kit's own SURFACE stack, which is already exactly this:
/// a neutral card ramp in light mode and a very dark tint of the club's hue in
/// dark mode. One luminance per theme for every kit — so an ink can be decided
/// once — and the club still says who it is in the accents standing on it. See
/// [hudChromeInk] for the ink that goes with it, and `tab_bar.dart` for the
/// highlight.
LinearGradient hudChrome(KitTheme kit, BuildContext context) {
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    // **Both themes return to `bg` at each end.** Light used to run white →
    // surface → surface2, which put the darkest of the three tones at one edge
    // of a band sitting on a white page — reported as too much background on
    // the top HUD, and too dark for light mode. Symmetrical, and no stop below
    // the page's own ground, is a band you can see the shape of without it
    // reading as a slab.
    colors: [kit.bg, kit.surface, kit.bg],
  );
}

/// The ink that reads on [hudChrome], and it is the same two values on every
/// kit — which is the whole point of the bars being neutral.
///
/// The app's own pane inks rather than a fourth pair invented here: the chrome
/// and the glass sitting on it now land in the same luminance band, so a label
/// on one and a label on the other have no reason to be different colours.
Color hudChromeInk(BuildContext context) => glassText(context);

/// **THE WALLET HUES ARE PRINTED RAW, on every theme.**
///
/// There was a ramp here that deepened them in daylight, because the bar had
/// gone neutral and gold on near-white is 1.2:1. It worked and it read as
/// muted — reported as light mode wanting the same vibrant yellows, greens and
/// blues the dark theme has. A hue cannot be both vivid and legible on white,
/// so the SURFACE moved instead: the cluster is a dark trough in both themes
/// now (see `HudCluster`), and on that these are exactly as chosen.
///
/// Kept as a function rather than deleted so the call sites still read as "and
/// this is what happens to a wallet's colour", and so there is one place to put
/// it back if anything in this bar ever stands on the chrome directly again.
Color hudInk(BuildContext context, Color colour) => colour;

/// **A WALLET'S BADGE COLOUR — the one the shop already uses for it.**
///
/// The cluster is four badges, each filled with its own wallet's colour and
/// printed in a lighter tint of it; see `HudChip`. Which colour a badge takes is
/// not a new question: the shop has answered it for years, and a coin badge in
/// the bar that is a different gold from the coin BUTTON you tap is two golds
/// for one currency. So the fills come straight off `_paletteFor` — the JS's
/// own values — rather than being derived here.
///
/// Energy has no shop button, and it does not need one: its ladder already
/// carries a colour, green down to red, and that is the badge. It takes the
/// card's own members of those hues rather than the vivid pair — a mint green
/// filled chip is too light to carry a label, which is what was reported. See
/// [vsGreenPlate].
Color hudBadgeColour(Color hue) => switch (hue.toARGB32() | 0xFF000000) {
  0xFFFFD700 => storeCoinFace,
  0xFF22D3EE => storeGemFace,
  // The ladder, in the members a filled chip can carry — the card's own greens
  // and reds, so the bar and the next-match card agree about what green means.
  0xFF4ADE80 => vsGreenPlate,
  0xFFFF9800 => vsAmberPlate,
  0xFFF87171 => vsRedPlate,
  _ => hue,
};

/// The ink printed ON a badge: the badge's own colour, lightened until it
/// carries.
///
/// **Lighter than the badge rather than white, which is what makes it show.**
/// Flat white on a mid gold is legible and reads as a sticker; the same hue
/// taken most of the way up keeps the badge one object and still clears the
/// large-text bar on every one of them. Asked for in those terms — a bit
/// lighter than the badge so the numbers show nicely.
Color hudBadgeInk(Color badge) {
  // 86% is where it starts, and it climbs from there until it actually clears
  // — a flat lerp is enough on a blue and is not on a gold, which is a light
  // colour to begin with, and the difference is the coin's figure being the one
  // that does not read.
  var out = Color.lerp(badge, Colors.white, 0.86)!;
  for (var i = 0; i < 12 && _onBadge(out, badge) < hudBadgeInkTarget; i++) {
    out = Color.lerp(out, Colors.white, 0.18)!;
  }
  return out;
}

/// **The palette's own bar for "is a pale ink readable on this", not 3:1.**
///
/// Gold is intrinsically light: even flat WHITE on the shop's `#D8A01A` is
/// 2.3, so a target of 3 is not a target, it is an instruction to stop using
/// the shop's gold. `whiteInkMinContrast` is where `inkFor` already draws that
/// line for every filled accent in the app, and a badge is a filled accent.
const double hudBadgeInkTarget = whiteInkMinContrast;

double _onBadge(Color ink, Color badge) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  double luma(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final a = luma(ink) + 0.05;
  final b = luma(badge) + 0.05;
  return a > b ? a / b : b / a;
}


/// The ink that reads on the cluster's dark trough, in either theme.
///
/// Not `glassInk`, which follows the theme: this one pane deliberately does
/// not, so the divider and anything else neutral inside it cannot follow it
/// either. See `HudCluster`.
const Color hudTroughInk = Color(0xFFE9EFF5);

/// The band the HUD sits in, off the Play tab.
///
/// A blur has to be CLIPPED to be a band: a `BackdropFilter` with nothing
/// bounding it samples the whole layer, so the fade at the bottom edge is what
/// makes it a bar rather than a smear over the screen.
class _FrostedBar extends StatelessWidget {
  const _FrostedBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return ClipRect(
      key: const ValueKey('hud-glass'),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: hudChrome(kit, context)),
          // **THE SAFE AREA IS INSIDE THE GLASS.** The shell used to wrap the
          // whole HUD in a `SafeArea`, which pushed the frosted band below the
          // notch and left the strip above it showing the raw page — a white bar
          // across the top of the Shop and the Squad tab in light mode, with the
          // blurred bar starting underneath it. Padding the band rather than
          // insetting it means the blur and the tint run to the top of the
          // screen and the chips still sit clear of the notch.
          child: Padding(
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The prestige count, beside the crest.
///
/// A straight port of `.hud-prestige` / `[data-prestige]` in
/// `../merge-empire-fc/src/ui/components/HUD.js`: a star, a `×`, the level, on
/// the same dark trough the resource pill uses — and NOTHING at level zero,
/// which is `.hud-prestige:empty { display: none }`.
///
/// **The multiplier was already on the books and the count was nowhere.** The
/// income breakdown names the level in its own row, so a player could read
/// `×1.2` and had no way to see they had prestiged twice. No new copy: a glyph
/// and a figure say it in every language, which is what the JS does too.
class HudPrestige extends ConsumerWidget {
  const HudPrestige({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(prestigeLevelProvider);
    if (level <= 0) return const SizedBox.shrink();
    final ink = glassInk(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: GlassPanel(
        key: const ValueKey('hud-prestige'),
        radius: 999,
        blur: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameIcon('star', size: 11, color: ink),
            const SizedBox(width: 2),
            Text(
              '×$level',
              style: TextStyle(
                color: ink,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
