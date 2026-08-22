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
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart'
    show vsRedOn;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/daily_reward_engine.dart';
import 'package:merge_empire_fc/engine/league_table.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/daily_reward_sheet.dart';
import 'package:merge_empire_fc/ui/popups/quick_nav_menu.dart';
import 'package:merge_empire_fc/ui/screens/minigames/minigames_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart';
import 'package:merge_empire_fc/ui/screens/home/league_sheets.dart';
import 'package:merge_empire_fc/ui/screens/index/player_index_sheet.dart';
import 'package:merge_empire_fc/ui/screens/leaderboard/leaderboard_sheet.dart';
import 'package:merge_empire_fc/ui/screens/minigames/training_sheet.dart';
import 'package:merge_empire_fc/ui/screens/quests/quests_sheet.dart';
import 'package:merge_empire_fc/ui/screens/trophies/trophy_room_sheet.dart';

/// What the menu offers.
///
/// The Leaderboard is here with its OFFLINE state rather than absent. The
/// ranked list needs `leaderboardService` (M4), but the signed-out and offline
/// screens are ones the JS really shows — so the tile is not a row leading
/// nowhere, and the Shop no longer sells a rank with no door to look at it
/// through.
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
        // The one live VALUE in the menu rather than a door: the tile carries the
        // league position its old dock button did, coloured by the zone it sits
        // in. Gold for the title race, accent for promotion, red for the drop.
        badge: _TablePositionBadge(),
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
        dot: ref.watch(claimableQuestsProvider) > 0,
        onTap: () => showQuestsSheet(context, ref),
      ),
      QuickNavItem(
        labelKey: 'subnav.training',
        icon: Icons.fitness_center,
        dot: ref.watch(miniGamesReadyProvider) > 0,
        onTap: () => showTrainingSheet(context),
      ),
      // **Daily was missing entirely.** It is a reward waiting to be taken, so
      // it is the one tile in here that is actively owed to the player — and the
      // only route to it was a dock orb the port never built. Nagging until it
      // is claimed is the point of it.
      QuickNavItem(
        labelKey: 'scene.dock.daily',
        icon: Icons.calendar_today,
        dot: ref.watch(dailyRewardUnclaimedProvider),
        onTap: () =>
            showDailyRewardSheet(context, game: ref.read(gameProvider)),
      ),
    ],
  ),
  QuickNavGroup(
    titleKey: 'quicknav.group.rewards',
    items: [
      QuickNavItem(
        labelKey: 'scene.dock.global',
        icon: Icons.public,
        onTap: () => showLeaderboardSheet(context),
      ),
      QuickNavItem(
        labelKey: 'scene.dock.trophies',
        icon: Icons.emoji_events,
        onTap: () => showTrophyRoomSheet(context),
      ),
    ],
  ),
];

/// Whether today's reward is still there to take.
final dailyRewardUnclaimedProvider = savePick<bool>(
  (s) => !getDailyRewardStatus(s).claimedToday,
);

/// Whether anything behind the burger is asking to be looked at.
///
/// The OR of every tile's own badge, so nothing that used to nag from the scene
/// goes quiet just because it moved one tap deeper. It had only ever counted
/// quests, so a ready drill and an unclaimed daily left the burger silent.
final quickNavNeedsAttentionProvider = Provider<bool>(
  (ref) =>
      ref.watch(claimableQuestsProvider) > 0 ||
      ref.watch(miniGamesReadyProvider) > 0 ||
      ref.watch(dailyRewardUnclaimedProvider),
);

/// The player's position, coloured by the zone it sits in.
///
/// Two rows wide at the bottom, one at the top — except in the Champions Cup
/// where only first place goes up, and Sunday League where there is nowhere
/// below to fall to. `leagueZoneFor` owns those rules.
class _TablePositionBadge extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(leagueTableProvider);
    final index = rows.indexWhere((LeagueRow r) => r.isPlayer);
    if (index < 0) {
      return Icon(
        Icons.format_list_numbered,
        color: Theme.of(context).extension<KitTheme>()!.accent,
        size: 26,
      );
    }
    final pos = index + 1;
    final divisionId = ref.watch(currentDivisionProvider);
    final colour = switch (leagueZoneFor(pos, rows.length, divisionId)) {
      LeagueZone.champion => const Color(0xFFFFD700),
      LeagueZone.promotion => Theme.of(
        context,
      ).extension<KitTheme>()!.accentBright,
      LeagueZone.relegation => vsRedOn(context),
      // The THEME's ink, not a hard white: a mid-table position on a light-mode
      // tile was white on near-white, which is the one row in the table nobody
      // could read.
      LeagueZone.midtable => Theme.of(context).colorScheme.onSurface,
    };

    return SizedBox(
      height: 26,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$pos',
              style: TextStyle(
                fontSize: 22,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: colour,
              ),
            ),
            WidgetSpan(
              alignment: PlaceholderAlignment.top,
              child: Text(
                ordinalSuffix(pos),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: colour,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
