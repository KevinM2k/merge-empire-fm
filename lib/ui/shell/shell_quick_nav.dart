/// The quick-nav menu's contents, and the button that opens it.
///
/// The menu shape was built with the other two and nothing ever showed it. It
/// is the right home for the screens that are not tabs — quests, and in time
/// the trophy room, the player index and the leaderboard — because they are
/// destinations rather than places you live.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/popups/quick_nav_menu.dart';
import 'package:merge_empire_fc/ui/screens/index/player_index_sheet.dart';
import 'package:merge_empire_fc/ui/screens/quests/quests_sheet.dart';
import 'package:merge_empire_fc/ui/screens/trophies/trophy_room_sheet.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// What the menu offers today.
///
/// The JS groups its eight tiles as "where you stand / what there is to do /
/// what you've won". The Leaderboard belongs in the third and is not listed
/// yet, because it needs `leaderboardService` before the screen is worth
/// writing — a menu row leading nowhere is the bug this file was written to
/// fix, not one to add.
List<QuickNavGroup> quickNavGroups(BuildContext context, WidgetRef ref) => [
  QuickNavGroup(
    titleKey: 'quicknav.group.league',
    items: [
      QuickNavItem(
        labelKey: 'scene.dock.index',
        icon: Icons.menu_book,
        onTap: () => showPlayerIndexSheet(context),
      ),
    ],
  ),
  QuickNavGroup(
    titleKey: 'quicknav.group.activity',
    items: [
      QuickNavItem(
        labelKey: 'quests.title',
        icon: Icons.checklist,
        onTap: () => showQuestsSheet(context, ref),
      ),
    ],
  ),
  QuickNavGroup(
    titleKey: 'quicknav.group.rewards',
    items: [
      QuickNavItem(
        labelKey: 'scene.dock.trophies',
        icon: Icons.emoji_events,
        onTap: () => showTrophyRoomSheet(context),
      ),
    ],
  ),
];

/// Opens the menu, badged when something is waiting to be claimed.
class QuickNavButton extends ConsumerWidget {
  const QuickNavButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final claimable = ref.watch(claimableQuestsProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          key: const ValueKey('quick-nav-open'),
          tooltip: t('quicknav.title'),
          icon: const Icon(Icons.menu),
          onPressed: () =>
              showQuickNavMenu(context, groups: quickNavGroups(context, ref)),
        ),
        if (claimable > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              key: const ValueKey('quick-nav-badge'),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: kit.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$claimable',
                style: TextStyle(
                  color: kit.accentInk,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
