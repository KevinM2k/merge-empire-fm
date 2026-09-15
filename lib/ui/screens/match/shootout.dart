/// What a cup tie's shootout is, read off the result.
///
/// **THIS FILE USED TO DRAW ONE, and the drawing is gone.** It was a row of
/// ticks and crosses under the two totals, on the board at full time and on
/// the summary — put there when the JS's kick-by-kick reveal was dropped for
/// want of translated copy, and kept for a while after the reveal came back.
/// Reported from the couch the moment both were on screen at once: "I don't
/// like the thing at the top when the penalties is over — the thing with the
/// dots."
///
/// Which is right, and it is the same objection as the repeated heading and
/// the repeated scoreline before it. The shootout is TOLD now — every kick a
/// card in the feed with the taker on it — and the board carries the running
/// bracket, `0 (4) - (2) 0`. A panel restating both in a third notation is a
/// third telling of one thing.
///
/// What is left is the read: `home` is always OURS on a result, the same rule
/// the goals follow. Every surface that asks about a shootout asks here — the
/// whistle's sting, Colin's full-time word, the write-up's headline and the
/// summary's `regulationScore`.
library;

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
