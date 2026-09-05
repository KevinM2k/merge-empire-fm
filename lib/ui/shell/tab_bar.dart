/// The bottom tab bar.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart' show coachAlert;
import 'package:merge_empire_fc/ui/shell/tabs.dart';
import 'package:merge_empire_fc/ui/theme/glass.dart' show glassAccent;
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// Placeholder glyphs. The JS ships a hand-drawn SVG set; porting it is its own
/// module and nothing here depends on which glyph is used.
const Map<ShellTab, IconData> tabIcons = {
  ShellTab.grid: Icons.dashboard,
  ShellTab.squad: Icons.groups,
  ShellTab.home: Icons.home,
  ShellTab.club: Icons.checkroom,
  ShellTab.shop: Icons.storefront,
};

class ShellTabBar extends StatelessWidget {
  const ShellTabBar({
    super.key,
    required this.active,
    required this.onTap,
    this.nudge,
  });

  final ShellTab active;
  final void Function(ShellTab tab) onTap;

  /// The one tab the onboarding trail is pointing at, or null — which is the
  /// ordinary state of the game and the state every save that predates the
  /// trail is in. See `ui/shell/coach_guide_host.dart`.
  ///
  /// **Never the tab you are already on.** Arriving is what spends the marker,
  /// so the ring going out IS the confirmation; a ring under the player's thumb
  /// on the page they just opened is the app failing to notice.
  final ShellTab? nudge;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    // **NO BAR ON THE PLAY TAB, which is what the top one already does.**
    // Everywhere else content scrolls under this strip and it has to be a
    // surface; on Play the diorama runs to the bottom of the screen, and a
    // near-white band across the foot of it was reported as jarringly bright
    // against a page that is a pitch. The top HUD has answered this question
    // the same way since it was written — see `Hud.build`: off the scene it is
    // a frosted band, on it there is nothing behind the chips at all.
    final onScene = active == ShellTab.home;
    return Container(
      decoration: BoxDecoration(
        // The same chrome as the top bar — see [hudChrome]. Neutral by
        // luminance in both themes, with the club in what stands ON it.
        gradient: onScene ? null : hudChrome(kit, context),
        // Clear on the scene, not dropped: a border changes the bar's height.
        border: Border(
          top: BorderSide(
            color: onScene ? kit.border.withValues(alpha: 0) : kit.border,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        // **THE FOUR LABELLED TABS SHARE WHAT IS LEFT.** They were laid out at
        // their natural widths, so five buttons plus a 60pt disc overflowed a
        // 320pt phone by sixty pixels — in ENGLISH, and worse in German, where
        // "Mannschaft" is the label. Found by the long-language sweep in
        // `test/i18n/long_language_layout_test.dart`, which is the whole reason
        // that sweep exists.
        //
        // The disc does NOT flex: it is a fixed 60 by design — the one tab with
        // any weight in the bar — and letting it shrink with the others is what
        // would make it stop being that.
        child: Row(
          children: [
            for (final tab in tabOrder)
              if (tab == ShellTab.home)
                _TabButton(
                  key: ValueKey('tab-${tab.name}'),
                  tab: tab,
                  active: tab == active,
                  sceneTab: onScene,
                  nudge: tab == nudge && tab != active,
                  onTap: () => onTap(tab),
                )
              else
                Expanded(
                  child: _TabButton(
                    key: ValueKey('tab-${tab.name}'),
                    tab: tab,
                    active: tab == active,
                    sceneTab: onScene,
                    nudge: tab == nudge && tab != active,
                    onTap: () => onTap(tab),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    super.key,
    required this.tab,
    required this.active,
    required this.sceneTab,
    required this.nudge,
    required this.onTap,
  });

  final ShellTab tab;
  final bool active;

  /// The trail is pointing here. See [ShellTabBar.nudge].
  final bool nudge;

  /// The shell is on Play, so there is no bar behind this button — see
  /// [ShellTabBar.build].
  final bool sceneTab;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final label = t(tab.labelKey);

    // Play is the only tab with any weight in the bar, and the word under it was
    // the one label telling you nothing its icon didn't. Icon only there; the
    // name still exists for a screen reader.
    if (tab == ShellTab.home) {
      final disc = Semantics(
        label: label,
        button: true,
        selected: active,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 60,
            height: 60,
            margin: const EdgeInsets.symmetric(vertical: 4),
            // **THE CLUB'S OWN DISC, back the right way round.** It was
            // inverted — the accent's INK filled the circle and the accent drew
            // the glyph — because the bar underneath used to be the accent, and
            // an accent disc on an accent bar is one colour. The bar is neutral
            // now, so the one tab with any weight in it is the one thing here
            // wearing the strip — in the EXACT colour that was picked, which is
            // what `accentInk` is measured against. Anything derived from the
            // accent rather than the accent itself reads as not quite the
            // club's colour, which was reported directly.
            decoration: BoxDecoration(
              color: kit.accent,
              shape: BoxShape.circle,
              // **A RIM, so the disc has an edge whatever the club plays in.**
              // The fill is the accent EXACTLY — that is the point of it — and
              // a pale kit's exact accent is 1.2:1 against the neutral bar, so
              // a yellow club got an invisible circle with a glyph floating in
              // it. The edge does the separating; the colour is left alone.
              border: Border.all(
                color: hudChromeInk(context).withValues(alpha: 0.22),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(tabIcons[tab], size: 28, color: kit.accentInk),
          ),
        ),
      );
      // The ring rides OUTSIDE the disc rather than behind the glyph: the disc
      // is a filled accent, and a wash behind an opaque fill paints nothing.
      return _NudgeHalo(size: 72, on: nudge, tab: tab, child: disc);
    }

    // **THE INK COMES OFF THE BAR, and the HIGHLIGHT comes off the club.**
    // Both were `kit.accentInk` — measured against a FILLED accent, which the
    // chrome is not — so on a pale kit it resolved to a near-black and painted
    // it on the near-black dark-mode bar. Reported as the bottom HUD making the
    // icons invisible on some themes. The chrome has one luminance per theme
    // now, so the resting ink is simply the ink that reads on it, and the club
    // says which tab you are on.
    //
    // **ON THE SCENE IT IS THE PALE INK AND A SHADOW, in both themes.** With no
    // bar under them the tabs stand on the diorama, and a diorama is a picture
    // rather than a surface: the daylight ink is a near-black, which on grass is
    // mud. Every other caption down here already answers it the same way —
    // "Coach", "Menu" and the customise pill are all pale on their own dark
    // plates. There is no ACTIVE case to worry about: on the scene the selected
    // tab is Play, and Play is the disc.
    final onScene = tab != ShellTab.home && sceneTab;
    final colour = onScene
        ? const Color(0xFFE9EFF5)
        : active
        ? glassAccent(context, kit.accentBright)
        : hudChromeInk(context).withValues(alpha: 0.62);
    final shadows = !onScene
        ? null
        : const [Shadow(color: Color(0x99101820), blurRadius: 4)];
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NudgeHalo(
                size: 34,
                tab: tab,
                // Off unless the trail is pointing here, and then it is the
                // only thing in the bar moving.
                on: nudge,
                child: Icon(
                  tabIcons[tab],
                  size: 22,
                  color: colour,
                  shadows: shadows,
                ),
              ),
              const SizedBox(height: 2),
              // Shrunk rather than cut: a tab called "Mannsch…" is a tab
              // nobody can read, and one point of type is cheaper than an
              // ellipsis on a word this short.
              Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: colour,
                  shadows: shadows,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// **THE QUIET HALF OF THE NUDGE.** A slow wash behind a tab the onboarding
/// trail is pointing at — see `ui/shell/coach_guide_host.dart`.
///
/// **It breathes; it does not blink.** A two-second cosine, so it eases at both
/// ends and has no edge for the eye to catch on: this is a bar the player looks
/// at every few seconds anyway, and something flashing in it would read as a
/// fault rather than as an invitation. Colin's head answers the same question
/// the same way, at the same tempo — see `_CoachHead` in `coach_floating.dart`.
///
/// **[coachAlert], not the club's accent.** The accent is already the colour of
/// the SELECTED tab and of the Play disc, so a nudge painted in it would be the
/// bar saying "you are here" about a tab you are not on. This is the one ink in
/// the app that can never be a kit colour, and it is the ink already on Colin's
/// unread badge — which is the other end of the same message.
///
/// **Nothing animates while [on] is false**, which is why the controller lives
/// behind it: five of these mount on every frame of the shell, and four of them
/// are always off. It also keeps a perpetual animation out of every widget test
/// that pumps the shell without arming the trail — a `pumpAndSettle` never sees
/// it. A test that DOES arm one has to use `pump`.
class _NudgeHalo extends StatefulWidget {
  const _NudgeHalo({
    required this.size,
    required this.on,
    required this.tab,
    required this.child,
  });

  /// The halo's resting diameter, centred on [child].
  final double size;

  /// Names the wash `tab-nudge-<tab>`, so a test can ask which tab the coach is
  /// pointing at. On the RING rather than on this widget: an off halo is its
  /// own child and a key up here would be found either way, which is a test
  /// that passes whatever the bar is doing.
  final ShellTab tab;

  final bool on;
  final Widget child;

  @override
  State<_NudgeHalo> createState() => _NudgeHaloState();
}

class _NudgeHaloState extends State<_NudgeHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  void _sync() {
    // **The accessibility setting is honoured by holding it OPEN, not by
    // dropping it.** A player who has asked for no animation still has to be
    // able to see which tab the coach is pointing at, so the wash sits at its
    // brightest instead of disappearing.
    final run = widget.on && !MediaQuery.of(context).disableAnimations;
    if (run == _breath.isAnimating) return;
    if (run) {
      _breath.repeat();
    } else {
      _breath.stop();
      _breath.value = 0.5;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_NudgeHalo old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.on) return widget.child;
    return AnimatedBuilder(
      animation: _breath,
      // The glyph does not rebuild with the wash behind it.
      child: widget.child,
      builder: (context, child) {
        final breath = (1 - math.cos(_breath.value * 2 * math.pi)) / 2;
        final size = widget.size * (0.94 + 0.06 * breath);
        return Stack(
          // **Clip.none, and the overflow is the point.** The wash is wider
          // than the glyph it sits behind — on the labelled tabs it reaches
          // into the gap above the caption, and round the Play disc it stands
          // a point outside the disc's own margin. Nothing up the tree clips
          // the bar, so it paints.
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Positioned, so the halo contributes nothing to the button's
            // size: a tab that changes width when the coach points at it would
            // re-lay the whole bar out.
            Positioned(
              left: -widget.size,
              right: -widget.size,
              top: -widget.size,
              bottom: -widget.size,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    key: ValueKey('tab-nudge-${widget.tab.name}'),
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: coachAlert.withValues(
                        alpha: 0.10 + 0.13 * breath,
                      ),
                      border: Border.all(
                        color: coachAlert.withValues(
                          alpha: 0.34 + 0.36 * breath,
                        ),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ?child,
          ],
        );
      },
    );
  }
}
