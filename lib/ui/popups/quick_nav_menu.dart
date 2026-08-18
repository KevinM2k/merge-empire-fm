/// The quick-nav menu — the third and last popup shape.
///
/// A grouped list of shortcuts to the screens that are not tabs. Grouped
/// headings come straight from the catalogue's `quicknav.group.*` keys.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

class QuickNavItem {
  const QuickNavItem({
    required this.labelKey,
    required this.icon,
    required this.onTap,
  });

  final String labelKey;
  final IconData icon;
  final VoidCallback onTap;
}

class QuickNavGroup {
  const QuickNavGroup({required this.titleKey, required this.items});

  final String titleKey;
  final List<QuickNavItem> items;
}

Future<void> showQuickNavMenu(
  BuildContext context, {
  required List<QuickNavGroup> groups,
}) {
  final kit = Theme.of(context).extension<KitTheme>()!;
  return showBottomSheetPopup<void>(
    context,
    heightFraction: 0.6,
    child: ListView(
      key: const ValueKey('quick-nav'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          t('quicknav.title'),
          style: TextStyle(
            color: kit.accentBright,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              t(group.titleKey),
              style: TextStyle(color: kit.textMuted, fontSize: 12),
            ),
          ),
          for (final item in group.items)
            ListTile(
              key: ValueKey('quick-nav-${item.labelKey}'),
              leading: Icon(item.icon, color: kit.accent),
              title: Text(t(item.labelKey)),
              onTap: () {
                Navigator.of(context).pop();
                item.onTap();
              },
            ),
        ],
      ],
    ),
  );
}
