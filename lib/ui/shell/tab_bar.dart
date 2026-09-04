/// The bottom tab bar.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
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
  const ShellTabBar({super.key, required this.active, required this.onTap});

  final ShellTab active;
  final void Function(ShellTab tab) onTap;

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
                  onTap: () => onTap(tab),
                )
              else
                Expanded(
                  child: _TabButton(
                    key: ValueKey('tab-${tab.name}'),
                    tab: tab,
                    active: tab == active,
                    sceneTab: onScene,
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
    required this.onTap,
  });

  final ShellTab tab;
  final bool active;

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
      return Semantics(
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
              Icon(tabIcons[tab], size: 22, color: colour, shadows: shadows),
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
