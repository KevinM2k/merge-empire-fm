/// The bottom tab bar.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';
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
    return Container(
      decoration: BoxDecoration(
        // The club's own chrome, same as the top bar — see `hudChrome`. It was
        // `surface`, so a player who picked claret and blue got a grey app.
        gradient: hudChrome(kit, context),
        border: Border(top: BorderSide(color: kit.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final tab in tabOrder)
              _TabButton(
                key: ValueKey('tab-${tab.name}'),
                tab: tab,
                active: tab == active,
                onTap: () => onTap(tab),
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
    required this.onTap,
  });

  final ShellTab tab;
  final bool active;
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
            // INVERTED, now the bar is the accent. An accent disc on an accent
            // bar is one colour, and the one tab with any weight in the bar was
            // the one that disappeared.
            decoration: BoxDecoration(
              color: kit.accentInk,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(tabIcons[tab], size: 28, color: kit.accent),
          ),
        ),
      );
    }

    // ON the accent, so the ink is the accent's own — the JS's rule for both
    // bars. `textMuted` is a grey picked for a grey surface and on claret it
    // read as dirt.
    final colour = active
        ? kit.accentInk
        : kit.accentInk.withValues(alpha: 0.62);
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tabIcons[tab], size: 22, color: colour),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 11, color: colour)),
            ],
          ),
        ),
      ),
    );
  }
}
