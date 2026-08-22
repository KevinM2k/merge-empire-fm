/// Coach Colin's read on the HISTORY between these two clubs.
///
/// **Fourteen `manager_hint.*` strings sat translated in ten catalogues with
/// nothing able to print one**, and the surface they belong to has existed the
/// whole time: `coach_bubble.dart`'s own header says it is the port of
/// `_computeManagerTips`, which is the JS function these are the output of. The
/// pool had the grudge and the rating gap and nothing about the fixture itself.
///
/// **The data was all there too.** `fixtureResults` is keyed `s{season}_m{n}`
/// and every entry carries the opponent's name, the score and the outcome — and
/// it is cleared only by a PRESTIGE reset, not by a season rollover, which is
/// exactly what "last season" and "{n} seasons back" need to mean anything.
///
/// **`record.dominant` and `record.struggling` are built now, off the spec.**
/// They wanted a sample size and a margin before an all-time record counts as
/// either, and both were in `../merge-empire-fc` rather than in this repo — so
/// they sat unreachable rather than being guessed at. See [fixtureHintPool] for
/// the three numbers and for the shape the JS gives them, which is a pool the
/// record JOINS rather than a line it replaces.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/i18n/i18n.dart' show stableIndex;

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

/// One meeting with this club, oldest first once sorted.
typedef Meeting = ({int season, int matchNum, bool won, bool drawn, String score});

/// A line for the coach's pool: which string, and what to fill it with.
typedef ManagerHint = ({String key, Map<String, Object?> params});

/// Every match played against [opponentName], oldest first.
///
/// Sorted by (season, match) off the KEY rather than by insertion: a save's map
/// order is whatever the JSON round-trip produced, and "our last two" read off
/// an unsorted list is two arbitrary matches.
List<Meeting> meetingsWith(Map<String, dynamic>? state, String? opponentName) {
  if (opponentName == null || opponentName.isEmpty) return const [];
  final results = _map(_map(state?['progression'])?['fixtureResults']);
  if (results == null) return const [];

  final out = <Meeting>[];
  for (final entry in results.entries) {
    final r = _map(entry.value);
    if (r == null || r['opponentName'] != opponentName) continue;
    final parsed = _parseKey(entry.key);
    if (parsed == null) continue;
    // `homeGoals` in a stored result is OURS whatever the venue was — the same
    // convention the fixtures sheet orients around — so the score reads our way
    // round, which is how every one of these sentences is written.
    final ours = _num(r['homeGoals'])?.toInt() ?? 0;
    final theirs = _num(r['awayGoals'])?.toInt() ?? 0;
    out.add((
      season: parsed.season,
      matchNum: parsed.matchNum,
      won: r['won'] == true,
      drawn: r['drawn'] == true,
      score: '$ours-$theirs',
    ));
  }
  out.sort((a, b) {
    final bySeason = a.season.compareTo(b.season);
    return bySeason != 0 ? bySeason : a.matchNum.compareTo(b.matchNum);
  });
  return out;
}

({int season, int matchNum})? _parseKey(String key) {
  // `s{season}_m{match}`. Anything else is not a league fixture — cup ties are
  // keyed differently and are not this fixture's history.
  if (!key.startsWith('s')) return null;
  final split = key.indexOf('_m');
  if (split < 2) return null;
  final season = int.tryParse(key.substring(1, split));
  final matchNum = int.tryParse(key.substring(split + 2));
  if (season == null || matchNum == null) return null;
  return (season: season, matchNum: matchNum);
}

/// How long the current run of the same result is, counting back from the last
/// meeting. A draw ends a run rather than extending one.
int streakLength(List<Meeting> meetings) {
  if (meetings.isEmpty) return 0;
  final last = meetings.last;
  if (last.drawn) return 0;
  var n = 0;
  for (var i = meetings.length - 1; i >= 0; i--) {
    final m = meetings[i];
    if (m.drawn || m.won != last.won) break;
    n++;
  }
  return n;
}

/// How long ago that was, as one of the three `manager_hint.when.*` strings.
///
/// Returns a KEY rather than a sentence: the engine may not reach the
/// catalogue, and the caller has to interpolate `{n}` into it anyway.
ManagerHint whenPlayed(int season, int currentSeason) {
  final back = currentSeason - season;
  if (back <= 0) return (key: 'manager_hint.when.this_season', params: const {});
  if (back == 1) return (key: 'manager_hint.when.last_season', params: const {});
  return (key: 'manager_hint.when.n_seasons_back', params: {'n': back});
}

/// The one thing worth saying about this fixture's history, or null.
///
/// **Most specific first, and the ordering is the only judgement in here.** A
/// run of three is a pattern, a run of two is a warning, and a single result is
/// a fact — so a longer run outranks a shorter one and both outrank the last
/// meeting, because burying "we have lost four in a row to these" under the
/// score of the most recent one tells the player less than it knows.
///
/// [currentSeason] decides what "last season" means, so it is passed rather
/// than read: the caller already has the save open.
ManagerHint? headToHeadHint(
  Map<String, dynamic>? state,
  String? opponentName, {
  required int currentSeason,
}) {
  final meetings = meetingsWith(state, opponentName);
  if (meetings.isEmpty) return null;

  final opp = opponentName!;
  final streak = streakLength(meetings);
  final last = meetings.last;

  if (streak >= 3) {
    return (
      key: last.won
          ? 'manager_hint.streak.win.3plus'
          : 'manager_hint.streak.loss.3plus',
      params: {'opp': opp, 'n': streak},
    );
  }
  if (streak == 2) {
    return (
      key: last.won
          ? 'manager_hint.streak.win.2'
          : 'manager_hint.streak.loss.2',
      params: {'opp': opp, 'n': streak},
    );
  }
  return (
    key: last.drawn
        ? 'manager_hint.last_meeting.drawn'
        : last.won
        ? 'manager_hint.last_meeting.won'
        : 'manager_hint.last_meeting.lost',
    params: {
      'opp': opp,
      'lastScore': last.score,
      // The caller resolves this key and drops the sentence in — `{when}` is a
      // phrase inside a sentence, which is a shape only the catalogue layer can
      // finish.
      'when': whenPlayed(last.season, currentSeason),
    },
  );
}

/// The keys whose sentences compete for this fixture's line, and the params any
/// of them could ask for.
///
/// **The all-time record JOINS the pool rather than replacing what is in it.**
/// That is the JS's shape (`_opponentHistoryTip` concatenates onto the array it
/// has already built) and it is the reason `record.dominant` reads as an
/// occasional aside rather than as a scoreboard: a run of three still gets to
/// be the headline most of the time it exists.
///
/// Three numbers come out of `../merge-empire-fc` and none of them was
/// guessable, which is why these two keys sat unreachable for as long as the
/// spec repo was unreadable — a SAMPLE SIZE (three meetings), a MARGIN (two
/// clear, so `wins > losses + 1`) and a ONE-IN-THREE roll on whether the record
/// is mentioned at all.
///
/// The roll is seeded on the record itself rather than on the JS's match index:
/// its whole job is to hold still while the player looks at the bubble, and a
/// head-to-head line has nothing new to say until these two meet again.
({List<String> keys, Map<String, Object?> params})? fixtureHintPool(
  Map<String, dynamic>? state,
  String? opponentName, {
  required int currentSeason,
}) {
  final hint = headToHeadHint(state, opponentName, currentSeason: currentSeason);
  if (hint == null) return null;

  final meetings = meetingsWith(state, opponentName);
  final keys = [hint.key];
  final params = {...hint.params};

  final record = recordFor(meetings);
  final recordKey = record.key;
  if (recordKey != null &&
      stableIndex('rec|$opponentName|$currentSeason|${meetings.length}', 3) ==
          2) {
    keys.add(recordKey);
  }
  // The counts go in whether or not the key did: the params a pooled key needs
  // are the UNION across its variants, and offering them costs a caller that
  // never prints one absolutely nothing.
  params['wins'] = record.wins;
  params['draws'] = record.draws;
  params['losses'] = record.losses;
  return (keys: keys, params: params);
}

/// The all-time record, and which of the two record keys it reads as.
///
/// [key] is null when the record is too short or too even to be worth a
/// sentence — the numbers are still returned, because the caller supplies them
/// either way.
({String? key, int wins, int draws, int losses}) recordFor(
  List<Meeting> meetings,
) {
  var wins = 0;
  var draws = 0;
  for (final m in meetings) {
    if (m.won) {
      wins++;
    } else if (m.drawn) {
      draws++;
    }
  }
  final losses = meetings.length - wins - draws;
  String? key;
  if (meetings.length >= 3) {
    if (wins > losses + 1) {
      key = 'manager_hint.record.dominant';
    } else if (losses > wins + 1) {
      key = 'manager_hint.record.struggling';
    }
  }
  return (key: key, wins: wins, draws: draws, losses: losses);
}
