/// Colin, INSIDE a sheet.
///
/// **A sheet is a route, so it covers him.** The floating coach sits in the
/// shell's own `Stack`, which is what makes a sheet or a dialog hide him by
/// construction rather than by every modal in the app remembering to ask him to
/// step aside — and it is also why fifteen `coach.*` strings written for the
/// JS's League SUB-TABS had nothing able to print one.
///
/// **BOTTOM LEFT, IN THE SHAPE HE TAKES EVERYWHERE ELSE.** This was a portrait
/// and two lines of grey text at the TOP of the list — the JS puts them on a
/// panel beside it, and a DOM panel became a header row here. So the same man
/// arrived in a different place, at a different size, in a different voice,
/// depending which list you had opened; reported as not liking where he pops on
/// Fixtures and as wanting him always bottom left in the same format. It is
/// [CoachCorner] now, which is the floating coach's own rig.
///
/// **And it costs the list nothing.** The old row was IN the column, so the
/// league pager had to reserve its height to stop the sheet growing and
/// shrinking under a finger mid-swipe. An overlay cannot do that, so the
/// reservation has gone with it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/sub_tab_coach.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/match/cup_launcher.dart' show cupDue;
import 'package:merge_empire_fc/ui/shell/coach_floating.dart' show CoachCorner;

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

/// Put [child] under the sheet's own coach corner.
///
/// The corner is an OVERLAY: it is drawn over the list rather than above it, so
/// mounting one cannot change what the list is or how tall it is.
Widget withSubTabCoach({
  required Widget child,
  required CoachLineFor which,
  bool enabled = true,
}) => Stack(
  children: [
    child,
    Positioned.fill(child: SubTabCoachLine(which: which, enabled: enabled)),
  ],
);

class SubTabCoachLine extends ConsumerWidget {
  const SubTabCoachLine({super.key, required this.which, this.enabled = true});

  final CoachLineFor which;

  /// False draws nothing at all.
  ///
  /// **The league table pager is the case.** His read is about where YOU are in
  /// the table, so over a division you are merely browsing it would be a
  /// sentence about somebody else's season.
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tip = enabled ? ref.watch(subTabTipProvider)[which] : null;
    if (tip == null) return const SizedBox.shrink();
    // **`tPoolStable`, seeded on the season and the state it is about.** Every
    // one of these keys is two or three sentences separated by pipes, so a
    // straight `t()` reads the whole pool at the player — and the sheet is
    // rebuilt on every idle tick, so a random pick would have him rephrasing
    // himself while it is open.
    return CoachCorner(
      key: ValueKey('coach-line-${which.name}'),
      idPrefix: 'coach-line-${which.name}',
      // He is not interrupting here — the player opened the list he is
      // annotating — so he holds still. See [CoachCorner.pulse].
      pulse: false,
      text: tPoolStable(tip.key, tip.seed, tip.params),
    );
  }
}
