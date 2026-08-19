/// The bottom tab bar.
library;

import 'package:flutter/material.dart';
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
        color: kit.surface,
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
            decoration: BoxDecoration(
              color: kit.accent,
              shape: BoxShape.circle,
            ),
            child: Icon(tabIcons[tab], size: 28, color: kit.accentInk),
          ),
        ),
      );
    }

    final colour = active ? kit.accent : kit.textMuted;
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
