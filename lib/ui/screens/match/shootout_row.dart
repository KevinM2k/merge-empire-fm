/// A cup tie decided on penalties, shown at the final whistle.
///
/// **The engine has always simulated the shootout kick by kick** — sudden death
/// and all — and only its three totals reached the screen. So a drawn tie
/// arrived as a bare one-goal defeat the player never saw decided, which is the
/// JS's own warning about this field, word for word: "a 2-2 tie surfacing as
/// lost 2-3 with no penalties shown".
///
/// **THIS ROW IS THE RECORD, and it is no longer the whole reveal.**
///
/// It was. The JS's step-through is hardcoded English — "It's going to
/// penalties!", "We go through!", "Out on penalties" — with no `t()` key behind
/// any of it, and the catalogues here are generated from that same repo, so
/// there was no translated copy to port. The reveal was dropped on that
/// reasoning and this row put in its place: ticks and crosses under two totals,
/// which says the part that matters in every language the game ships in.
///
/// **Which was the copy deciding the behaviour, and it was reported as such.**
/// Asked for from the couch in these words: it should say it is going to
/// penalties and then take them one at a time with the score recorded as it
/// goes, "that's how it has always worked". Copy this repo owns is written in
/// `lib/i18n/en_copy.dart` and its nine and laid over the generated
/// catalogues, so the reveal is mintable and is minted — see `match.pens.*`,
/// `shootoutBeats` in `match_clock.dart` and `MatchScreenState._beginShootout`.
///
/// So the kicks are taken one at a time in the commentary with the running
/// score beside each, and THIS is what they add up to: the whole shootout at a
/// glance, once it is over, for a player who wants to see which kicks went in
/// rather than scroll a feed back.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// One team's kicks, as the save stores them.
typedef ShootoutLine = ({int score, List<bool> kicks});

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// Pull the shootout out of a match result, or null when it was not one.
({ShootoutLine ours, ShootoutLine theirs, bool won})? shootoutFrom(
  Map<String, dynamic>? result,
) {
  final shootout = _map(result?['penaltyShootout']);
  if (shootout == null) return null;
  final raw = shootout['kicks'];
  final ours = <bool>[];
  final theirs = <bool>[];
  if (raw is List) {
    for (final entry in raw) {
      final kick = _map(entry);
      if (kick == null) continue;
      // **`home` is always OURS in an engine result** — there is no venue flip,
      // which is the same rule the goals follow and the one thing here that
      // looks like it should be checked and must not be.
      (kick['team'] == 'home' ? ours : theirs).add(kick['scored'] == true);
    }
  }
  return (
    ours: (score: _int(shootout['homeScore']), kicks: ours),
    theirs: (score: _int(shootout['awayScore']), kicks: theirs),
    won: shootout['playerWins'] == true,
  );
}

int _int(Object? v) => v is num ? v.toInt() : 0;

/// The two lines of marks, under the two totals.
class ShootoutRow extends StatelessWidget {
  const ShootoutRow({
    super.key,
    required this.ours,
    required this.theirs,
    required this.won,
  });

  final ShootoutLine ours;
  final ShootoutLine theirs;
  final bool won;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Container(
      key: const ValueKey('shootout-row'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kit.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: won ? kit.accentBright : kit.border),
      ),
      child: Column(
        children: [
          // The totals, big, because that is the answer. The marks under them
          // are how it was arrived at.
          Text(
            '${ours.score} - ${theirs.score}',
            key: const ValueKey('shootout-score'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: won ? kit.accentBright : kit.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          _Marks(kicks: ours.kicks, ink: kit.accentBright, rowKey: 'ours'),
          const SizedBox(height: 4),
          _Marks(kicks: theirs.kicks, ink: kit.textMuted, rowKey: 'theirs'),
        ],
      ),
    );
  }
}

class _Marks extends StatelessWidget {
  const _Marks({required this.kicks, required this.ink, required this.rowKey});

  final List<bool> kicks;
  final Color ink;
  final String rowKey;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Row(
      key: ValueKey('shootout-marks-$rowKey'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < kicks.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Icon(
              kicks[i] ? Icons.circle : Icons.close,
              size: kicks[i] ? 11 : 13,
              // A miss is grey in BOTH rows: red for theirs would say their
              // miss was bad news, which is the opposite of what it was.
              color: kicks[i] ? ink : kit.border,
            ),
          ),
      ],
    );
  }
}
