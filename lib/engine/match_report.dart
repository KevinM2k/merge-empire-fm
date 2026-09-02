/// **THE FULL-TIME WRITE-UP.**
///
/// Asked for from the couch, at length and with a worked example: a paragraph
/// at the end of a match that tells the story of it — the result, the shape it
/// took, who scored, what the referee did, where it leaves us in the table and
/// who is next. "Obviously a lot of this will have to be contextually aware and
/// will have to be modified based on what happened in the game."
///
/// **It is a sequence of BEATS, not one string.** A match report written as one
/// key per outcome is a catalogue of hundreds that still cannot say "came from
/// two behind, and the sending-off is why". Each beat is a sentence about one
/// thing, chosen from what actually happened, and the ones that have nothing to
/// say are simply absent — so a routine 1–0 gets three sentences and a
/// ten-man comeback gets six.
///
/// **Nothing here knows about Flutter or about `t()`.** The beats carry keys and
/// parameters; the screen resolves them. That is what lets the whole thing be
/// tested as arithmetic, and it is why the pools this draws from are the
/// commentary's own `|`-separated multi-line entries — one match's report is
/// seeded off the fixture, so re-reading it does not rewrite it.
library;

import 'package:merge_empire_fc/i18n/i18n.dart' show getLocale;
import 'package:merge_empire_fc/util/format.dart' show ordinalSuffix;

/// One sentence of the report, as a key and its parameters.
typedef ReportBeat = ({String key, Map<String, Object?> params});

/// What the match did, in the order it did it — everything the report reads.
typedef ReportFacts = ({
  int ours,
  int theirs,

  /// **THE WRITE-UP NAMES BOTH CLUBS.** It was written in the first person —
  /// "we", "us", "our back line" — and was asked to be a third party's account
  /// of the match instead: "its like an independent summary of the game." So
  /// every beat carries the club as well as the opponent, and none of them says
  /// "us".
  String clubName,
  String opponentName,
  bool isHome,
  bool isCup,

  /// Our scorers, in the order they scored. Names, because that is what a
  /// sentence prints; a brace is two entries of the same name.
  List<String> scorers,

  /// Whether we were ever behind, and whether we were ever ahead. The two
  /// together are the shape: behind-and-not-ahead is a chase, both is a
  /// turnaround, ahead-and-not-behind is a lead that held or slipped.
  bool wasBehind,
  bool wasAhead,

  /// Cautions and sendings-off, ours and theirs — see `booking_engine.dart`.
  int ourYellows,
  int ourReds,
  int theirYellows,
  int theirReds,

  /// Where the table leaves us, and how far we moved. A null position is a cup
  /// tie or a save with no table; [posDelta] is positive for a climb.
  int? position,
  int? points,
  int? posDelta,

  /// Who is next, and where. Null when the season has run out of fixtures.
  String? nextOpponent,
  bool nextIsHome,
});

/// The whole report, beat by beat.
///
/// [ReportFacts.scorers] and the booking counts are the port's own; the rest
/// comes off the settled result and the table the round left behind.
List<ReportBeat> buildMatchReport(ReportFacts f) {
  final beats = <ReportBeat>[];
  final margin = f.ours - f.theirs;

  // ── 1. The result, in words, at the margin it was won by ──────────────────
  //
  // The margin is what decides the tone: a 4–0 and a 1–0 are both wins and are
  // not the same afternoon, and a report that opens the same way for both is
  // the generic paragraph this exists to avoid.
  final headline = switch (margin) {
    >= 4 => 'report.win.rout',
    3 => 'report.win.comfortable',
    2 => 'report.win.clear',
    1 => 'report.win.narrow',
    0 => f.ours == 0 ? 'report.draw.goalless' : 'report.draw.shared',
    -1 => 'report.loss.narrow',
    -2 => 'report.loss.clear',
    -3 => 'report.loss.comfortable',
    _ => 'report.loss.rout',
  };
  beats.add((
    key: headline,
    params: {
      'club': f.clubName,
      'opp': f.opponentName,
      'ours': f.ours,
      'theirs': f.theirs,
      'venue': f.isHome ? 'home' : 'away',
    },
  ));

  // ── 2. The shape of it ───────────────────────────────────────────────────
  //
  // Only when there is a shape to describe. A 0–0 has none, and a one-goal win
  // where nothing was ever level is already fully told by the line above.
  final shape = switch ((f.wasBehind, f.wasAhead)) {
    (true, true) when margin > 0 => 'report.shape.turnaround',
    (true, true) when margin == 0 => 'report.shape.pegged_back',
    (true, true) => 'report.shape.led_and_lost',
    (true, false) when margin == 0 => 'report.shape.rescued',
    (true, false) => 'report.shape.chasing',
    (false, true) when margin > 0 => 'report.shape.never_behind',
    (false, true) => 'report.shape.threw_it',
    (false, false) => '',
  };
  if (shape.isNotEmpty) {
    beats.add((
      key: shape,
      params: {'club': f.clubName, 'opp': f.opponentName},
    ));
  }

  // ── 3. Who scored ────────────────────────────────────────────────────────
  //
  // A hat-trick, a brace and a name are three different sentences about the
  // same fact, and the difference is the whole reason a player reads this.
  final tally = <String, int>{};
  for (final name in f.scorers) {
    if (name.isEmpty) continue;
    tally[name] = (tally[name] ?? 0) + 1;
  }
  if (tally.isNotEmpty) {
    final best = tally.entries.reduce((a, b) => b.value > a.value ? b : a);
    if (best.value >= 3) {
      beats.add((
        key: 'report.scorers.hat_trick',
        params: {'club': f.clubName, 'player': best.key, 'n': best.value},
      ));
    } else if (best.value == 2) {
      beats.add((
        key: 'report.scorers.brace',
        params: {'club': f.clubName, 'player': best.key},
      ));
    } else if (tally.length >= 3) {
      beats.add((
        key: 'report.scorers.spread',
        params: {'club': f.clubName, 'n': tally.length},
      ));
    } else {
      beats.add((
        key: 'report.scorers.one',
        params: {'club': f.clubName, 'player': tally.keys.first},
      ));
    }
  } else if (f.ours == 0) {
    beats.add((key: 'report.scorers.none', params: {'club': f.clubName}));
  }

  // A clean sheet is worth a line of its own, and only when it was actually
  // worked for — nil-nil already said it in the headline.
  if (f.theirs == 0 && f.ours > 0) {
    beats.add((key: 'report.clean_sheet', params: {'club': f.clubName}));
  }

  // ── 4. The referee ───────────────────────────────────────────────────────
  //
  // Ours first, because ours is the one that costs a suspension. Their card is
  // mentioned only when ours had none — two discipline sentences in a
  // four-sentence report is a match report about the referee.
  if (f.ourReds > 0) {
    beats.add((
      key: f.ourReds > 1 ? 'report.cards.our_reds' : 'report.cards.our_red',
      params: {'club': f.clubName, 'n': f.ourReds},
    ));
  } else if (f.ourYellows >= 2) {
    beats.add((
      key: 'report.cards.our_yellows',
      params: {'club': f.clubName, 'n': f.ourYellows},
    ));
  } else if (f.theirReds > 0) {
    beats.add((
      key: 'report.cards.their_red',
      params: {'club': f.clubName, 'opp': f.opponentName},
    ));
  }

  // ── 5. Where it leaves us ────────────────────────────────────────────────
  //
  // A cup tie has no table to move in, and neither has a save whose season has
  // not started — both come through as a null position rather than as a zero.
  final pos = f.position;
  final pts = f.points;
  if (!f.isCup && pos != null && pts != null) {
    final delta = f.posDelta ?? 0;
    beats.add((
      key: delta > 0
          ? 'report.table.climbed'
          : delta < 0
          ? 'report.table.dropped'
          : 'report.table.held',
      // **THE ORDINAL IS PART OF THE VALUE, not part of the sentence.** The
      // English copy said `{pos}th`, which prints "1th" — reported from the
      // couch. Moving the suffix into the string would need a second
      // placeholder that only one language uses, and the catalogue test is
      // right to refuse that; the suffix is also not a suffix in most of them
      // (German writes "Rang 4.", Chinese "第4"). So the value carries it, and
      // only where the language has one.
      params: {
        'club': f.clubName,
        'pos': ordinalOf(pos),
        'pts': pts,
        'n': delta.abs(),
        // One place, two places. The catalogue carries the plural as a
        // fragment the way `trophy.summary` already does — "1 places" was
        // reported from the couch.
        's': delta.abs() == 1 ? '' : 's',
      },
    ));
  }

  // ── 6. And who is next ───────────────────────────────────────────────────
  final next = f.nextOpponent;
  if (next != null && next.isNotEmpty) {
    beats.add((
      key: f.nextIsHome ? 'report.next.home' : 'report.next.away',
      params: {'club': f.clubName, 'opp': next},
    ));
  }

  return beats;
}

/// Was our side ever behind, and were we ever ahead?
///
/// Read off the goal events in minute order rather than from the final score,
/// which is the only way to tell a 2–2 that was 2–0 up from a 2–2 that was 0–2
/// down — and those are opposite afternoons.
({bool wasBehind, bool wasAhead}) leadSwings(List<Map<String, dynamic>> goals) {
  final ordered = [...goals]
    ..sort(
      (a, b) => ((a['minute'] as num?) ?? 0).compareTo((b['minute'] as num?) ?? 0),
    );
  var ours = 0;
  var theirs = 0;
  var behind = false;
  var ahead = false;
  for (final g in ordered) {
    if (g['team'] == 'home') {
      ours++;
    } else {
      theirs++;
    }
    if (ours > theirs) ahead = true;
    if (theirs > ours) behind = true;
  }
  return (wasBehind: behind, wasAhead: ahead);
}

/// A league position as the reader's language writes one.
///
/// English is the only catalogue whose sentences read as "4th"; the rest set
/// the number in their own furniture — "Rang 4.", "4º", "第4" — and appending
/// an English suffix to any of them would be worse than the bug it fixes.
String ordinalOf(int pos) =>
    getLocale() == 'en' ? '$pos${ordinalSuffix(pos)}' : '$pos';
