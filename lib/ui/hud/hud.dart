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
const Color hudCoinInk = Color(0xFFFFD700);
const Color hudEnergyInk = Color(0xFF57BCFF);
const Color hudGemInk = Color(0xFF7FD4FF);

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
const double hudClearance = 56;

/// The same clearance, plus whatever the notch takes.
///
/// The shell no longer wraps its tab content in a top `SafeArea`: it did, and
/// that stopped every screen's BACKGROUND at the notch — so the home screen's
/// diorama ended in a bar of page colour instead of running to the top of the
/// glass, which is where the JS puts it (`.ps-holder` is `position: fixed;
/// top: 0` precisely so it escapes). The ground bleeds now and the CONTENT clears
/// the notch itself, which is this.
double hudClearanceOf(BuildContext context) =>
    MediaQuery.paddingOf(context).top + hudClearance;

class Hud extends ConsumerWidget {
  const Hud({super.key, this.onSettings});

  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // On the Play tab the whole HUD is written for DARK GLASS, so the whole HUD
    // is built under the dark build of the kit — the figures, the captions and
    // the icons as well as the chips they sit in. Resolving the ink out here in
    // the app's own theme is what put pale-green numbers on a near-white pill
    // the moment light mode was on; the `Builder` is what puts the rest of this
    // method under it.
    //
    // Everywhere else it keeps the app's own theme, because everywhere else the
    // page underneath is the app's own surface — see `HudChip.onScene`.
    final onScene = ref.watch(shellControllerProvider).tab == ShellTab.home;
    if (!onScene) {
      // A REAL BLUR ACROSS THE WHOLE STRIP, not four blurred chips with gaps
      // between them. Content scrolls under this bar on every tab but Play, and
      // through the gaps it went past in full focus — so the HUD read as four
      // dark boxes with a shop tile sliding between them. One backdrop filter
      // over the band, and anything behind it is genuinely out of focus.
      return _FrostedBar(child: _bar(context, ref, onScene: false));
    }
    return Theme(
      data: ref.watch(glassThemeProvider),
      child: Builder(builder: (context) => _bar(context, ref, onScene: true)),
    );
  }

  Widget _bar(BuildContext context, WidgetRef ref, {required bool onScene}) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final shell = ref.read(shellControllerProvider.notifier);
    final valueStyle = TextStyle(
      color: kit.accentBright,
      fontWeight: FontWeight.w600,
      fontSize: 13,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      // TOGETHER, not spread. `spaceBetween` pushes the badge to one edge and
      // the cog to the other and opens whatever is left between the three
      // resource chips — so on a wide phone they drift apart into four
      // unrelated things instead of reading as one strip of status.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
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
          const SizedBox(width: 4),
          HudChip(
            onScene: onScene,
            key: const ValueKey('hud-coins'),
            iconColor: hudCoinInk,
            icon: Icons.monetization_on,
            semanticLabel: t('hud.aria.income_breakdown'),
            trailing: HudPlus(
              key: const ValueKey('hud-coins-plus'),
              label: t('nav.shop'),
              onTap: () => shell.deepLinkShop(ShopSection.coins),
            ),
            child: CoinCounter(
              value: ref.watch(coinsProvider),
              style: valueStyle,
            ),
          ),
          const SizedBox(width: 4),
          HudChip(
            onScene: onScene,
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
                      color: (valueStyle.color ?? kit.textMuted).withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          HudChip(
            onScene: onScene,
            key: const ValueKey('hud-gems'),
            icon: Icons.diamond,
            iconColor: hudGemInk,
            semanticLabel: t('shop.section.gems'),
            // No + of its own: the whole chip deep-links, which keeps a third
            // resource from widening the row by another mini-badge.
            onTap: () => shell.deepLinkShop(ShopSection.gems),
            child: Text('${ref.watch(gemsProvider)}', style: valueStyle),
          ),
          const Spacer(),
          HudChip(
            onScene: onScene,
            key: const ValueKey('hud-cog'),
            icon: Icons.settings,
            semanticLabel: t('hud.aria.settings'),
            onTap: onSettings,
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
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
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            // Enough tint that white text on it survives whatever it is over —
            // the blur softens the background, it does not darken it.
            color: kit.bg.withValues(alpha: 0.62),
            border: Border(
              bottom: BorderSide(color: kit.border.withValues(alpha: 0.5)),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
