/// The quick-nav menu — the third and last popup shape.
///
/// **A centred grid, deliberately NOT a bottom sheet.** The JS says why in as
/// many words: a 3×3 grid wants the middle of the screen, and the sheet's
/// chrome — a grab handle, a pinned close — promises scrollable content about
/// something that has none. The port had it as a sheet, which put the last
/// group below the fold on a short screen: the exact failure the shape was
/// chosen to avoid.
///
/// Groups come straight from the catalogue's `quicknav.group.*` keys, and the
/// grouping is the point — "where you stand / what there is to do / what you've
/// won" makes eight destinations findable in a way one flat list does not.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

class QuickNavItem {
  const QuickNavItem({
    required this.labelKey,
    required this.icon,
    required this.onTap,
    this.dot = false,
    this.badge,
  });

  final String labelKey;
  final IconData icon;
  final VoidCallback onTap;

  /// Something behind this tile wants attention. The burger's own dot is the OR
  /// of these, so nothing that used to nag from the scene goes quiet just
  /// because it moved one tap deeper.
  final bool dot;

  /// A live VALUE in place of the glyph — the table tile carries the league
  /// position its dock button used to, zone colour and all. It is the one thing
  /// in here that is a readout rather than a door, which is why it earns the
  /// exception.
  final Widget? badge;
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
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (dialogContext) => _QuickNavMenu(groups: groups),
  );
}

class _QuickNavMenu extends StatelessWidget {
  const _QuickNavMenu({required this.groups});

  final List<QuickNavGroup> groups;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Dialog(
      backgroundColor: kit.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: kit.border),
      ),
      child: SingleChildScrollView(
        key: const ValueKey('quick-nav'),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t('quicknav.title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kit.accentBright,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            for (final group in groups) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Text(
                  t(group.titleKey).toUpperCase(),
                  style: TextStyle(
                    color: kit.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              // Wrap rather than a fixed grid: a group of two centres rather
              // than left-packing beside an empty third cell.
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final item in group.items) _QuickNavTile(item: item),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickNavTile extends StatelessWidget {
  const _QuickNavTile({required this.item});

  final QuickNavItem item;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return SizedBox(
      width: 92,
      child: InkWell(
        key: ValueKey('quick-nav-${item.labelKey}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Closed BEFORE the destination opens, so the menu is not left
          // stacked underneath whatever rises over it.
          Navigator.of(context).pop();
          item.onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: kit.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kit.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  item.badge ?? Icon(item.icon, color: kit.accent, size: 26),
                  if (item.dot)
                    Positioned(
                      right: -3,
                      top: -2,
                      child: Container(
                        key: ValueKey('quick-nav-dot-${item.labelKey}'),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF44336),
                          border: Border.all(color: kit.surface2, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                t(item.labelKey),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
