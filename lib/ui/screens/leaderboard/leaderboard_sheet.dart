/// The global leaderboard. Ported from `ui/screens/LeaderboardScreen.js`.
///
/// **The online half is not here, and cannot be yet.** The board itself comes
/// from `leaderboardService` (1,831 lines, Firestore-backed) and `authService`,
/// both of which are M4 — so this ports the two states the JS shows when
/// neither is available, which are real states rather than placeholders:
///
/// - **Signed out.** The JS renders the whole screen with a guest footer
///   inviting you to sign in to be listed. Your own standing still shows,
///   because the club, the division and the badge are computed locally — only
///   the RANK on it needs the board, and it comes from there. See
///   `myBoardRankProvider`.
/// - **Offline.** One line, `leaderboard.offline`.
///
/// It is reachable rather than absent BECAUSE those states exist. Leaving the
/// tile out meant the Shop could sell you a rank you had no way to look at, and
/// a player who signs in later finds the door already where they expect it.
///
/// What lands with M4 is the ranked list itself — see `docs/PARITY.md`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/auth_policy.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/leaderboard/leaderboard_board.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/shell/shell_routes.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/badge_icon.dart';
import 'package:merge_empire_fc/util/format.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// What we can say about the player without the service.
typedef LocalStanding = ({
  String club,
  String division,
  String badgeId,
});

final localStandingProvider = savePick<LocalStanding>((s) {
  final prog = _map(s['progression']);
  return (
    club: s['clubName'] is String && (s['clubName'] as String).isNotEmpty
        ? s['clubName'] as String
        : t('common.your_club'),
    division: tName('division', '${prog?['currentDivision'] ?? ''}'),
    badgeId: '${prog?['equippedBadgeId'] ?? 'default'}',
  );
});

Future<void> showLeaderboardSheet(BuildContext context) =>
    openShellSheet(context, ShellSheet.leaderboard, const LeaderboardView());

class LeaderboardView extends ConsumerWidget {
  const LeaderboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final me = ref.watch(localStandingProvider);
    final rank = ref.watch(myBoardRankProvider);
    final signedIn = isSignedInLocal(ref.watch(gameProvider).state);

    return Padding(
      key: const ValueKey('leaderboard'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 11px w800 was a GROUP LABEL, not a sheet title — the size the
          // fixture caption and the tactic line use, on the one line that is
          // the sheet's name. See `sheet_header.dart`.
          SheetHeader(
            title: t('leaderboard.title'),
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
          ),

          // Your own standing, which is local and therefore always knowable.
          // The JS shows it signed in or out for the same reason.
          Container(
            key: const ValueKey('leaderboard-me'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: kit.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kit.accent),
            ),
            child: Row(
              children: [
                BadgeIcon(badgeId: me.badgeId, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        me.club,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        me.division,
                        style: TextStyle(fontSize: 12, color: kit.textMuted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      t('leaderboard.your_rank_label'),
                      style: TextStyle(fontSize: 12, color: kit.textMuted),
                    ),
                    Text(
                      // **THE BOARD'S ANSWER, not a dash.** This printed
                      // `rank_unranked` for everybody, which was honest while
                      // there was no service and stopped being honest the day
                      // there was one — the fetch two widgets below has carried
                      // `playerRank` all along. A dash still stands for the two
                      // cases that really have no rank: a board that has not
                      // come back yet, and a player the board has never seen.
                      // See [myBoardRankProvider].
                      rank == null
                          ? t('leaderboard.rank_unranked')
                          : '#${formatCoins(rank)}',
                      key: const ValueKey('leaderboard-rank'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // **THE TWO STAT TILES ARE GONE.** "Trophies" and "Record" sat under
          // the standing card as a pair of big figures, and neither of them is
          // about the leaderboard: the trophy count is the trophy room's and the
          // season count is the season report's. Reported as two readings the
          // player could not tell the meaning of, on the one sheet whose whole
          // job is a ranked list — so the room goes to the list.
          const SizedBox(height: 20),
          // **THE BOARD ITSELF.** It was one line saying the service was not
          // here; `services/leaderboard_service.dart` is, so this is the ranked
          // list. Signed out it still loads — the boards are public to READ,
          // which is the JS's own Firestore rule — and the footer below says
          // what signing in adds.
          const LeaderboardBoard(),
          if (!signedIn) ...[
            const SizedBox(height: 8),
            Text(
              t('leaderboard.guest_footer'),
              key: const ValueKey('leaderboard-guest'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: kit.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
