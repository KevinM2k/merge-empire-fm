/// The quick-nav menu's contents.
///
/// This is where the home screen's furniture went. Ten orbs used to run up both
/// sides of the diorama and the table and fixtures were a strip of sub-tabs
/// across the top; grouping them as "where you stand / what there is to do /
/// what you've won" makes them findable in a way two columns of icons and a tab
/// strip never were.
///
/// The BUTTON that opens this lives on the home screen, bottom right — see
/// `ui/screens/home/home_dock.dart`. It is not in the HUD: the HUD is the
/// resource bar and follows the player across every tab, and a menu about where
/// to go belongs on the screen you go from.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/ui/popups/quick_nav_menu.dart';
import 'package:merge_empire_fc/ui/screens/home/league_sheets.dart';
import 'package:merge_empire_fc/ui/screens/index/player_index_sheet.dart';
import 'package:merge_empire_fc/ui/screens/minigames/training_sheet.dart';
import 'package:merge_empire_fc/ui/screens/quests/quests_sheet.dart';
import 'package:merge_empire_fc/ui/screens/trophies/trophy_room_sheet.dart';

/// What the menu offers.
///
/// The Leaderboard is the one tile the JS has that is not here: it needs
/// `leaderboardService` before the screen is worth writing, and a menu row
/// leading nowhere is the bug this menu was built to fix.
List<QuickNavGroup> quickNavGroups(BuildContext context, WidgetRef ref) => [
  QuickNavGroup(
    titleKey: 'quicknav.group.league',
    items: [
      QuickNavItem(
        labelKey: 'subnav.fixtures',
        icon: Icons.calendar_month,
        onTap: () => showFixturesSheet(context),
      ),
      QuickNavItem(
        labelKey: 'subnav.table',
        icon: Icons.format_list_numbered,
        onTap: () => showLeagueTableSheet(context),
      ),
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
      QuickNavItem(
        labelKey: 'subnav.training',
        icon: Icons.fitness_center,
        onTap: () => showTrainingSheet(context),
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

/// Whether anything behind the burger is asking to be looked at.
///
/// The OR of every tile's own badge, so nothing that used to nag from the scene
/// goes quiet just because it moved one tap deeper.
final quickNavNeedsAttentionProvider = Provider<bool>(
  (ref) => ref.watch(claimableQuestsProvider) > 0,
);
