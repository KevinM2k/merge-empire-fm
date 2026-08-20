/// The floating resource bar.
///
/// It is not a bar: the JS removed the header background so the scene shows
/// through, and each stat is its own chip. Every value comes off a derived
/// provider, so a coin landing rebuilds the coin label and nothing else.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/badge_engine.dart';
import 'package:merge_empire_fc/engine/energy_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/hud/coin_counter.dart';
import 'package:merge_empire_fc/ui/hud/hud_chip.dart';
import 'package:merge_empire_fc/ui/screens/shop/currency_sheet.dart';
import 'package:merge_empire_fc/ui/screens/trophies/trophy_room_sheet.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/badge_icon.dart';
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
/// because that is the coins; green is out too, because green is the chrome the
/// icons sit on and half the kits are some shade of it; and orange came out 30°
/// from gold, which is the same mistake one hue over.
///
/// So the bolt is VIOLET. Lightning is drawn violet about as often as it is drawn
/// yellow, it is 135° from the gold and 90° from the gem, and it is the one warm-
/// side hue no wallet in this game has a claim on. Fixed on every kit, because
/// what these code is WHICH WALLET, and that does not change with the strip.
const Color hudCoinInk = Color(0xFFFFD700);
const Color hudEnergyInk = Color(0xFFA855F7);
const Color hudGemInk = Color(0xFF22D3EE);

/// The energy figure's colour, full to empty.
///
/// The same ladder the squad's fitness bars use, and the same one the JS puts on
/// the Pro-mode fitness figure: green while there is plenty, amber when it is
/// getting thin, red when it is nearly gone. At the cap it takes the kit's own
/// accent — a full tank is the club's colour rather than a warning of any kind.
Color energyInk(num current, int max, Color full) {
  if (max <= 0 || current >= max) return full;
  final pct = current / max * 100;
  return pct > 50
      ? const Color(0xFF4ADE80)
      : pct > 20
      ? const Color(0xFFFBBF24)
      : const Color(0xFFF87171);
}

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
const double hudClearance = 56 + hudBottomMargin;

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
    final kit = Theme.of(context).extension<KitTheme>()!;
    // The figures, through [glassAccent]: 13px of mid-tone accent on a bright
    // pane is the 2.4:1 case, and these are the numbers the whole bar exists to
    // show.
    final valueStyle = TextStyle(
      color: glassAccent(context, kit.accentBright),
      fontWeight: FontWeight.w700,
      fontSize: 13,
    );

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
          IconButton(
            key: const ValueKey('hud-badge'),
            tooltip: t('trophy.title'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            // BIG. It is the club's own crest and the way into the trophy
            // room, and at 26 it was the smallest thing on a bar of 16px icons
            // sitting in chips — a badge that reads as a bullet point.
            icon: BadgeIcon(
              badgeId: ref.watch(equippedBadgeProvider),
              size: 38,
            ),
            onPressed: () => showTrophyRoomSheet(context),
          ),
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
                      value: ref.watch(coinsProvider),
                      style: valueStyle,
                    ),
                  ),
                  HudChip(
                    key: const ValueKey('hud-energy'),
                    icon: Icons.bolt,
                    iconColor: hudEnergyInk,
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
                            style: valueStyle.copyWith(
                              color: energyInk(
                                ref.watch(energyProvider),
                                ref.watch(energyMaxProvider),
                                kit.accentBright,
                              ),
                            ),
                          ),
                          TextSpan(
                            text: '/${ref.watch(energyMaxProvider)}',
                            style: valueStyle.copyWith(
                              fontSize: 10,
                              color: (valueStyle.color ?? kit.textMuted)
                                  .withValues(alpha: 0.6),
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

/// The kit's own chrome, for the top bar and the bottom tab bar.
///
/// **THE BARS ARE THE ONE PLACE THE KIT COLOUR IS STRUCTURAL**, and that is the
/// JS's decision rather than this file's. Its note, verbatim in intent: light mode
/// is deliberately NEUTRAL — white cards on a light-grey page — and the kit hue is
/// used for accents AND *"for the HUD top bar + bottom tab bar, which are solid
/// accent-coloured chrome"*. The page stays white; the chrome is the club.
///
/// The port had both bars as `surface`, so a player who picked claret and blue got
/// a grey app with a green tint in the buttons. On the tabs, the bars were the
/// only two surfaces big enough to say whose club this is.
///
/// Dark mode is the kit's `--hud-gradient`: a very dark tint of the same hue
/// rather than the accent at full strength, because a saturated bar on a
/// near-black page is a stripe of daylight across it. Derived from the accent
/// here rather than added to `KitSurfaces` — the JS builds it per kit from the
/// same hue, and blending to near-black reaches the same place without a second
/// pinned value to keep in step.
LinearGradient hudChrome(KitTheme kit, BuildContext context) {
  final light = Theme.of(context).brightness == Brightness.light;
  if (light) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(kit.accent, Colors.white, 0.10)!,
        kit.accent,
        Color.lerp(kit.accent, Colors.black, 0.06)!,
      ],
    );
  }
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.lerp(kit.accent, Colors.black, 0.90)!,
      Color.lerp(kit.accent, Colors.black, 0.82)!,
      Color.lerp(kit.accent, Colors.black, 0.90)!,
    ],
  );
}

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
