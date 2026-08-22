/// Colin, INSIDE a sheet.
///
/// **A sheet is a route, so it covers him.** The floating coach sits in the
/// shell's own `Stack`, which is what makes a sheet or a dialog hide him by
/// construction rather than by every modal in the app remembering to ask him to
/// step aside — and it is also why fifteen `coach.*` strings written for the
/// JS's League SUB-TABS had nothing able to print one. The JS puts them on a
/// panel beside the list; the port's equivalent is a line at the head of the
/// sheet the list is in.
///
/// **Quiet by design.** He is not interrupting here — the player opened a list
/// and he is annotating it — so it is a line with his tail rather than a card
/// with his head: the same distinction `CoachLine.strong` draws on the cards.
/// The CUP and ENERGY lines are the exception and wear the accent, because both
/// are things to act on before anything on the list matters.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/sub_tab_coach.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart' show coachPortrait;
import 'package:merge_empire_fc/ui/screens/match/cup_launcher.dart' show cupDue;
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';

/// Which of the three reads to draw.
enum CoachLineFor { table, fixtures, minigames }

/// The line for a sheet, or null when he has nothing to say about it.
final subTabTipProvider = savePick<Map<CoachLineFor, SubTabTip?>>((s) {
  // Read ONCE per save rather than per sheet: `cupDue` walks the cup run and
  // all three reads ask the same question of it.
  final due = cupDue(s);
  return {
    CoachLineFor.table: leagueTableTip(s, cupIsDue: due),
    CoachLineFor.fixtures: leagueFixturesTip(s, cupIsDue: due),
    CoachLineFor.minigames: leagueMinigamesTip(s, cupIsDue: due),
  };
});

class SubTabCoachLine extends ConsumerWidget {
  const SubTabCoachLine({
    super.key,
    required this.which,
    this.reserve = false,
    this.enabled = true,
  });

  final CoachLineFor which;

  /// False draws nothing but still holds the height when [reserve] is set.
  ///
  /// **The league table pager is the case.** His read is about where YOU are in
  /// the table, so over a division you are merely browsing it would be a
  /// sentence about somebody else's season.
  final bool enabled;

  /// Hold the row's height even when there is nothing to say.
  ///
  /// **For a pager.** The league table swipes between divisions and he only
  /// speaks over your OWN — so without this the sheet grew and shrank under the
  /// finger mid-drag, which is a layout change during a gesture and reads as
  /// the swipe fighting back.
  final bool reserve;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tip = enabled ? ref.watch(subTabTipProvider)[which] : null;
    if (tip == null) {
      return reserve ? const SizedBox(height: _reserved) : const SizedBox.shrink();
    }
    final kit = Theme.of(context).extension<KitTheme>()!;
    // **`tPoolStable`, seeded on the season and the state it is about.** Every
    // one of these keys is two or three sentences separated by pipes, so a
    // straight `t()` reads the whole pool at the player — and the sheet is
    // rebuilt on every idle tick, so a random pick would have him rephrasing
    // himself while it is open.
    final text = tPoolStable(tip.key, tip.seed, tip.params);

    final row = Padding(
      key: ValueKey('coach-line-${which.name}'),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: ClipOval(
              child: ArtImage(
                path: coachPortrait,
                fit: BoxFit.cover,
                fallback: Icon(Icons.sports, size: 15, color: kit.accent),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              // Two lines and no more: he is annotating a list, and a
              // paragraph at the head of one is the list starting further down.
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                fontWeight: tip.priority ? FontWeight.w700 : FontWeight.w400,
                color: tip.priority ? kit.accentBright : kit.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
    return reserve ? SizedBox(height: _reserved, child: row) : row;
  }
}

/// Two lines of 11.5pt at 1.4, plus the row's own bottom padding.
const double _reserved = 42;
