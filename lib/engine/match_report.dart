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

import 'package:merge_empire_fc/i18n/i18n.dart' show getLocale, t;
import 'package:merge_empire_fc/util/format.dart' show ordinalSuffix;

/// One sentence of the report, as a key, its parameters, and which paragraph
/// it belongs to.
///
/// **[para] IS PART OF THE STORY, not formatting.** The report used to be one
/// block of prose on the reasoning that six bullet points is a scorecard. That
/// is still true of bullets and was never true of paragraphs: a human writing
/// this up would break after the result, again after the performances, and
/// again before what it all means for the table. Asked for from the couch.
///
/// Beats are emitted in order and the paragraph index only ever rises, so the
/// screen groups consecutive runs and needs to know nothing about the keys.
typedef ReportBeat = ({String key, Map<String, Object?> params, int para});

/// The paragraphs, in the order a report is read.
///
/// Named rather than numbered at the call sites, because the whole value of
/// the break is that the reader can tell what each one is about.
abstract final class ReportPara {
  /// What happened: the result and the shape it took.
  static const int result = 0;

  /// How the two sides played, and who scored.
  static const int performance = 1;

  /// The incidents — the referee, and what the manager changed.
  static const int incidents = 2;

  /// What it means: the table, and who is next.
  static const int standing = 3;
}

/// One goal, as the report reads it.
///
/// [scorer] is null for the opposition's: the sim never names their players,
/// so their goals are told as the club's. **That is the first gap the news
/// section will hit** — see [ReportFacts.goals].
typedef ReportGoal = ({int minute, bool ours, String? scorer});

/// One card. [player] is null for theirs, for the same reason.
typedef ReportCard = ({int minute, bool ours, String? player, bool red});

/// One of our substitutions. [off] is null when the hole was already empty.
typedef ReportSub = ({int minute, String on, String? off});

/// One change of tactic, by the id `strategies` uses.
typedef ReportSwitch = ({int minute, String tactic});

/// The board at the whistle, OUR side first. Possession is a percentage.
typedef ReportStats = ({
  int possession,
  int shots,
  int theirShots,
  int onTarget,
  int theirOnTarget,
  int corners,
  int theirCorners,
});

/// What the match did, in the order it did it — everything the report reads.
///
/// **THE SUMMARY USES EVERYTHING THE MATCH RECORDED.** It opened as six
/// sentences picked off the margin, and a 1-0 won in the 88th minute read the
/// same as one won in the 5th — "held on to a single goal for longer than was
/// comfortable", about a lead two minutes old. Reported from the couch, with
/// the direction that followed: the stats, the tactics, the goals and who
/// scored them and when, the substitutions, the discipline — a life-like
/// summary rather than a verdict. So everything the settled result records is
/// in here, and anything the match knows that the result does NOT record is a
/// gap to close on the result rather than to write around. A news section
/// with full reports of the whole week's games, written in an independent
/// voice, is the stated future and will read the same record — for AI-versus-
/// AI fixtures it will have nothing else.
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

  /// **EVERY GOAL, in the order they went in.** The timeline is what the
  /// margin cannot say: which goal opened it, who levelled, and the minute of
  /// the one that settled it — see [deciderMinute]. Empty when the result
  /// carries no events, and the report falls back to telling the tally.
  List<ReportGoal> goals,

  /// Every card the referee showed, both sides.
  List<ReportCard> cards,

  /// Our substitutions, and how many the opposition made. Theirs are counted
  /// rather than named because the result records them as `opp_sub` events
  /// with no name on them.
  List<ReportSub> subs,
  int theirSubs,

  /// The tactic at kick-off, and every change to it in order. Null when the
  /// result does not say — the kick-off tactic is written by the match screen
  /// and an older result has none.
  String? startTactic,
  List<ReportSwitch> switches,

  /// The board at the whistle. Null when the result has no events to count.
  ReportStats? stats,

  /// Where the table leaves us, and how far we moved. A null position is a cup
  /// tie or a save with no table; [posDelta] is positive for a climb.
  int? position,
  int? points,
  int? posDelta,

  /// Who is next, and where. Null when the season has run out of fixtures.
  String? nextOpponent,
  bool nextIsHome,

  /// **AND WHO THE OPPONENT PLAYS NEXT.** Asked for from the couch: the
  /// write-up is "meant to be a summary about the game for anyone reading it",
  /// so ending it with only our own next fixture is half a sentence — a reader
  /// who does not support either club has been told about one of them.
  ///
  /// Null when the schedule does not say, which is a cup tie or the last round
  /// of a season; the beat is simply absent then.
  String? oppNextOpponent,
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
  //
  // **AND THE MINUTE, when the goal that settled it came late.** A one-goal
  // win in the 88th is not "a single goal defended for longer than they would
  // have liked" — it was level for eighty-seven minutes. The timeline knows
  // that and the margin does not, so a late decider takes over the headline
  // for the one-goal results and the draw, which are the ones a late goal
  // changes the story of.
  final ordered = [...f.goals]..sort((a, b) => a.minute.compareTo(b.minute));
  final decider = deciderMinute(f.goals);
  final lateGoal = decider != null && decider >= lateGoalMinute;
  //
  // **AND IT OPENS LIKE THE WHISTLE HAS JUST GONE.** Reported from the couch:
  // the first line "just gives the score (which is already visible) and gives a
  // one liner" — it should read "the whistle has gone and there was one goal in
  // it", "what a thriller, seven goals between them but it goes to {team}". The
  // English pools are written that way in `en_copy.dart`, and a high-scoring
  // one-goal result — or a 3-3 — is a THRILLER before it is
  // narrow or late, because the seven goals are the bigger fact.
  final total = f.ours + f.theirs;
  final headline = switch (margin) {
    1 when total >= thrillerGoals => 'report.win.thriller',
    -1 when total >= thrillerGoals => 'report.loss.thriller',
    0 when total >= thrillerGoals + 1 => 'report.draw.thriller',
    1 when lateGoal => 'report.win.late',
    -1 when lateGoal => 'report.loss.late',
    0 when lateGoal => 'report.draw.late',
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
    para: ReportPara.result,
    params: {
      'club': f.clubName,
      'opp': f.opponentName,
      // **THE SCORE READS THE WAY A SCORE IS WRITTEN: home team first.**
      // These were our goals then theirs regardless of venue, so an away win
      // was reported as "a narrow one, 1-0" when the board — and every other
      // surface in the game — said 0-1. Reported from the couch.
      //
      // [ours] and [theirs] are still OUR goals and THEIRS, because several
      // beats are about us rather than about the fixture; [score] is the pair
      // written out in the order a reader expects, and the headline uses that.
      'ours': f.ours,
      'theirs': f.theirs,
      'total': total,
      'score': f.isHome ? '${f.ours}-${f.theirs}' : '${f.theirs}-${f.ours}',
      // Who that score belongs to, left and right, so a sentence can name them
      // in the same order.
      'homeTeam': f.isHome ? f.clubName : f.opponentName,
      'awayTeam': f.isHome ? f.opponentName : f.clubName,
      'venue': f.isHome ? 'home' : 'away',
      // Only the late headlines print it; the rest ignore the spare.
      if (lateGoal) 'minute': ordinalOf(decider),
    },
  ));

  // ── 2. The shape of it ───────────────────────────────────────────────────
  //
  // Only when there is a shape to describe. A 0–0 has none, and a one-goal win
  // where nothing was ever level is already fully told by the line above.
  //
  // **AND ONLY WHEN THE COPY'S CLAIM ABOUT TIME IS TRUE.** Three of the seven
  // pools say WHEN as well as what: `chasing` and `never_behind` are written
  // about an EARLY goal — "Behind early, {club} spent the rest of the
  // afternoon…", "Ahead early and untroubled after it" — and `rescued` about a
  // LONG spell behind, "trailing for much of it". Reported from the couch
  // twice: "Behind early" printed about a goal in the 67th minute, and the
  // 88th-minute case above. The shape was chosen off two booleans that know
  // nothing about minutes, so the line is now gated on the timeline it claims
  // to describe, and when the claim would be false the goal-by-goal beats
  // below tell it with the real minutes instead. The other four pools make no
  // claim about time and are safe at any minute.
  final opener = ordered.isEmpty ? null : ordered.first.minute;
  final openerEarly = opener == null || opener <= earlyGoalMinute;
  final behindFor = minutesBehind(ordered, until: decider);
  final longSpellBehind = opener == null || behindFor >= longSpellMinutes;
  final shape = switch ((f.wasBehind, f.wasAhead)) {
    (true, true) when margin > 0 => 'report.shape.turnaround',
    (true, true) when margin == 0 => 'report.shape.pegged_back',
    (true, true) => 'report.shape.led_and_lost',
    (true, false) when margin == 0 =>
      longSpellBehind ? 'report.shape.rescued' : '',
    (true, false) => openerEarly && !lateGoal ? 'report.shape.chasing' : '',
    (false, true) when margin > 0 =>
      openerEarly && !lateGoal ? 'report.shape.never_behind' : '',
    (false, true) => 'report.shape.threw_it',
    (false, false) => '',
  };
  if (shape.isNotEmpty) {
    beats.add((
      key: shape,
      para: ReportPara.result,
      params: {'club': f.clubName, 'opp': f.opponentName},
    ));
  }

  // ── 3. The goals, one by one ─────────────────────────────────────────────
  //
  // **GOAL MINUTES, WHO SCORED THEM, and what each one did to the match.** A
  // reader of a real summary is told the opener, the equaliser and the winner
  // in order, and this is that: each goal is keyed by the situation it made —
  // opened the scoring, levelled, put a side in front, stretched a lead, or
  // pulled one back — and carries the minute, the scorer and the score it
  // left. The opposition's goals carry the club, because the sim does not name
  // their scorers. Every goal, because a 4-3 is seven sentences and that is
  // the afternoon it was.
  var scoredUs = 0;
  var scoredThem = 0;
  for (final g in ordered) {
    final before = scoredUs - scoredThem;
    if (g.ours) {
      scoredUs++;
    } else {
      scoredThem++;
    }
    final after = scoredUs - scoredThem;
    final situation = scoredUs + scoredThem == 1
        ? 'opener'
        : after == 0
        ? 'leveller'
        : before == 0
        ? 'lead'
        : after.abs() > before.abs()
        ? 'extend'
        : 'pull_back';
    beats.add((
      key: 'report.goal.${g.ours ? 'ours' : 'theirs'}.$situation',
      para: ReportPara.performance,
      params: {
        'club': f.clubName,
        'opp': f.opponentName,
        'minute': ordinalOf(g.minute),
        // A scorer the result did not name is told as the club.
        'scorer': g.scorer ?? f.clubName,
        // The score it left, written home team first like the headline's.
        'score': f.isHome
            ? '$scoredUs-$scoredThem'
            : '$scoredThem-$scoredUs',
      },
    ));
  }

  // ── 4. The numbers ───────────────────────────────────────────────────────
  //
  // The board the statistics tab shows, in a sentence: possession, shots and
  // corners, both sides. Asked for from the couch as part of the summary using
  // everything the match has.
  final st = f.stats;
  if (st != null) {
    beats.add((
      key: 'report.stats.board',
      para: ReportPara.performance,
      params: {
        'club': f.clubName,
        'opp': f.opponentName,
        'poss': st.possession,
        'oppPoss': 100 - st.possession,
        'shots': st.shots,
        'oppShots': st.theirShots,
        'onTarget': st.onTarget,
        'oppOnTarget': st.theirOnTarget,
        'corners': st.corners,
        'oppCorners': st.theirCorners,
      },
    ));
  }

  // ── 5. And how the OPPOSITION played ─────────────────────────────────────
  //
  // **THE WRITE-UP IS FOR BOTH SETS OF SUPPORTERS, and everything between the
  // headline and the table was about us.** The shape, the scorers, the cards,
  // the tactical switch and the table are all [ReportFacts] about [clubName] —
  // so a beaten side got several sentences on how badly it had played and the
  // winners got named in a scoreline. Reported from the couch: it never says
  // the other team played out of this world, and a third party summarising the
  // match has to work for the people who came to watch them.
  //
  // One beat, and it is about THEM rather than a second sentence about us. It
  // reads the same facts the headline does — the margin, and whether the lead
  // ever changed hands — because that is all this file knows: the port never
  // names an opposition player, so there is no their-scorers line to write.
  final oppKey = switch ((margin, f.wasAhead, f.wasBehind)) {
    // They won it from behind, which is the one thing worth saying first.
    (< 0, true, _) => 'report.opp.comeback',
    // Three clear is a performance rather than a result.
    (<= -3, _, _) => 'report.opp.rampant',
    // A win and a clean sheet is two jobs done, and the copy should say so.
    (< 0, _, _) when f.ours == 0 => 'report.opp.shut_us_out',
    (< 0, _, _) => 'report.opp.clinical',
    // We led and did not win: they earned the point back.
    (0, true, _) => 'report.opp.fought_back',
    (0, _, _) when f.ours == 0 && f.theirs == 0 => 'report.opp.stalemate',
    (0, _, _) => 'report.opp.matched',
    (>= 3, _, _) => 'report.opp.outclassed',
    _ => 'report.opp.pushed',
  };
  beats.add((
    key: oppKey,
    para: ReportPara.performance,
    params: {'club': f.clubName, 'opp': f.opponentName},
  ));

  // ── 6. Who scored, as a tally ────────────────────────────────────────────
  //
  // A hat-trick, a brace and a name are three different sentences about the
  // same fact, and the difference is the whole reason a player reads this.
  //
  // **The single scorer and the spread are told by the timeline now**, so
  // those two beats only come out when the result carried no goal events for
  // the timeline to read — the tally is the one fact a list of goals does not
  // say out loud.
  final told = ordered.isNotEmpty;
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
        para: ReportPara.performance,
        params: {'club': f.clubName, 'player': best.key, 'n': best.value},
      ));
    } else if (best.value == 2) {
      beats.add((
        key: 'report.scorers.brace',
        para: ReportPara.performance,
        params: {'club': f.clubName, 'player': best.key},
      ));
    } else if (!told && tally.length >= 3) {
      beats.add((
        key: 'report.scorers.spread',
        para: ReportPara.performance,
        params: {'club': f.clubName, 'n': tally.length},
      ));
    } else if (!told) {
      beats.add((
        key: 'report.scorers.one',
        para: ReportPara.performance,
        params: {'club': f.clubName, 'player': tally.keys.first},
      ));
    }
  } else if (f.ours == 0) {
    beats.add((
      key: 'report.scorers.none',
      para: ReportPara.performance,
      params: {'club': f.clubName},
    ));
  }

  // A clean sheet is worth a line of its own, and only when it was actually
  // worked for — nil-nil already said it in the headline.
  if (f.theirs == 0 && f.ours > 0) {
    // **`opp` TOO, and it was not being passed.** The second of the three
    // variants opens "{opp} were kept out entirely" — so one write-up in three
    // that kept a clean sheet printed a literal `{opp}` at the reader.
    // Reported from the couch. A pool's variants do not all take the same
    // placeholders, which is exactly why the parameters have to satisfy the
    // WHOLE pool rather than the line that happened to be picked in testing.
    beats.add((
      key: 'report.clean_sheet',
      para: ReportPara.performance,
      params: {'club': f.clubName, 'opp': f.opponentName},
    ));
  }

  // ── 7. The referee ───────────────────────────────────────────────────────
  //
  // **What MATTERS, not everything.** A first cut told every card and was sent
  // back as too long: "if a team just got one booking… so what?! dont even
  // mention it!" So: a red is a named player and a minute, always; our
  // bookings only when there were two or more, by name; theirs only the reds.
  // Ours first, because ours is the one that costs a suspension.
  final cards = [...f.cards]..sort((a, b) => a.minute.compareTo(b.minute));
  for (final c in cards) {
    if (!c.ours || !c.red) continue;
    final name = c.player ?? '';
    beats.add((
      // The generated line when the result did not keep the name.
      key: name.isEmpty ? 'report.cards.our_red' : 'report.cards.our_red_named',
      para: ReportPara.incidents,
      params: {
        'club': f.clubName,
        'n': 1,
        'player': name,
        'minute': ordinalOf(c.minute),
      },
    ));
  }
  final ourBooked = [
    for (final c in cards)
      if (c.ours && !c.red) c,
  ];
  if (ourBooked.length > 1) {
    beats.add((
      key: 'report.cards.our_booked_many',
      para: ReportPara.incidents,
      params: {
        'club': f.clubName,
        'n': ourBooked.length,
        'names': nameList([
          for (final c in ourBooked) c.player ?? f.clubName,
        ]),
      },
    ));
  }
  final theirReds = cards.where((c) => !c.ours && c.red).length;
  if (theirReds == 1) {
    beats.add((
      key: 'report.cards.their_red',
      para: ReportPara.incidents,
      params: {'club': f.clubName, 'opp': f.opponentName},
    ));
  } else if (theirReds > 1) {
    beats.add((
      key: 'report.cards.their_reds',
      para: ReportPara.incidents,
      params: {'club': f.clubName, 'opp': f.opponentName, 'n': theirReds},
    ));
  }

  // ── 8. The changes ───────────────────────────────────────────────────────
  //
  // Our substitutions as ONE sentence — both names and the minute each, which
  // is the information, without a sentence per change, which was the length.
  // The opposition's are counted on the result and not worth a line.
  final subs = [...f.subs]..sort((a, b) => a.minute.compareTo(b.minute));
  if (subs.isNotEmpty) {
    beats.add((
      key: 'report.subs.made',
      para: ReportPara.incidents,
      params: {
        'club': f.clubName,
        'n': subs.length,
        's': subs.length == 1 ? '' : 's',
        'list': nameList([
          for (final sub in subs)
            sub.off == null || sub.off!.isEmpty
                ? '${sub.on} (${ordinalOf(sub.minute)})'
                : '${sub.on} for ${sub.off} (${ordinalOf(sub.minute)})',
        ]),
      },
    ));
  }

  // ── 9. The tactics ───────────────────────────────────────────────────────
  //
  // **WHAT WAS PLAYED, and every change to it.** It was one sentence about the
  // last LATE switch, on the reasoning that two sentences about the dial is a
  // report about the manager. The brief is a summary that uses everything, so:
  // the tactic the side started with when it changed, each change with its
  // minute, and the late one still gets the richer line — shutting up shop and
  // throwing men forward are opposite stories told at the same minute, and
  // that sentence says which.
  final switches = [...f.switches]
    ..sort((a, b) => a.minute.compareTo(b.minute));
  ReportSwitch? lastLate;
  for (final sw in switches) {
    if (sw.minute >= lateSwitchFrom) lastLate = sw;
  }
  // The kick-off tactic only when it CHANGED: "went with Balanced for the
  // whole ninety" is a sentence about nothing happening.
  final start = f.startTactic;
  if (start != null && start.isNotEmpty && switches.isNotEmpty) {
    beats.add((
      key: 'report.tactic.started',
      para: ReportPara.incidents,
      params: {'club': f.clubName, 'tactic': tacticName(start)},
    ));
  }
  for (final sw in switches) {
    if (sw == lastLate) {
      beats.add((
        key: switch (sw.tactic) {
          'parkTheBus' || 'counterAttack' => 'report.tactic.shut_up_shop',
          'allOutAttack' || 'highPress' => 'report.tactic.went_for_it',
          _ => 'report.tactic.settled',
        },
        para: ReportPara.incidents,
        params: {
          'club': f.clubName,
          'opp': f.opponentName,
          // The generated copy says "on {minute} minutes": a plain number.
          'minute': sw.minute,
          'tactic': tacticName(sw.tactic),
        },
      ));
    } else {
      beats.add((
        key: 'report.tactic.switch',
        para: ReportPara.incidents,
        params: {
          'club': f.clubName,
          'tactic': tacticName(sw.tactic),
          'minute': ordinalOf(sw.minute),
        },
      ));
    }
  }

  // ── 7. Where it leaves us ────────────────────────────────────────────────
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
      para: ReportPara.standing,
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
        // **AND THE SAME FOR POINTS, which the copy had hardcoded** — a side on
        // a single point was told it had "1 points". Reported from the couch.
        // Two suffixes rather than one because they count different things: a
        // club can climb one place to sit on twenty points, or hold its place
        // on one. The English copy carrying `point{ps}` lives in
        // `lib/i18n/en_copy.dart`; the other nine keep their own wording and
        // ignore the spare parameter, as 57 catalogue entries already do
        // with `{s}`.
        'ps': pts == 1 ? '' : 's',
      },
    ));
  }

  // ── 8. And who is next ───────────────────────────────────────────────────
  final next = f.nextOpponent;
  final theirNext = f.oppNextOpponent;
  if (next != null && next.isNotEmpty) {
    beats.add((
      key: theirNext != null && theirNext.isNotEmpty
          ? (f.nextIsHome ? 'report.next.home_both' : 'report.next.away_both')
          : (f.nextIsHome ? 'report.next.home' : 'report.next.away'),
      para: ReportPara.standing,
      params: {
        'club': f.clubName,
        'opp': next,
        // The club this match was against, and who THEY play next — see
        // [ReportFacts.oppNextOpponent].
        'them': f.opponentName,
        'theirNext': theirNext ?? '',
      },
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

/// A goal from here on is a LATE one, and the headline says so.
const int lateGoalMinute = 80;

/// Goals in a one-goal result that make it a THRILLER; a draw needs 3-3.
const int thrillerGoals = 5;

/// A goal up to here is an EARLY one, which is what `chasing` and
/// `never_behind` are written about.
const int earlyGoalMinute = 30;

/// Time behind that counts as "trailing for much of it" — see `rescued`.
const int longSpellMinutes = 30;

/// How many minutes our side spent behind, up to [until] (the whistle when
/// null). Read off the goals in order; a side that was never behind spent none.
int minutesBehind(List<ReportGoal> ordered, {int? until}) {
  var diff = 0;
  var behindSince = -1;
  var total = 0;
  for (final g in ordered) {
    if (until != null && g.minute > until) break;
    final was = diff;
    diff += g.ours ? 1 : -1;
    if (was >= 0 && diff < 0) behindSince = g.minute;
    if (was < 0 && diff >= 0 && behindSince >= 0) {
      total += g.minute - behindSince;
      behindSince = -1;
    }
  }
  if (behindSince >= 0) total += (until ?? 90) - behindSince;
  return total;
}

/// A change of tactic from here on is about seeing the match out, and the last
/// of those gets the richer sentence.
///
/// **Sixty minutes is the line**, and it is a judgement rather than a
/// measurement: a switch on the hour is a manager reacting to what is in front
/// of him, and one in the twentieth is still the plan. The log is written by
/// the match screen — see `applyStrategy` — because the engine's own result
/// records WHAT was played and never WHEN it changed.
const int lateSwitchFrom = 60;

/// A tactic, by the name the tactics strip gives it.
String tacticName(String id) => t('strategy.$id.name');

/// "A, B and C" — English only, like the rest of the copy this repo owns.
String nameList(List<String> names) => switch (names.length) {
  0 => '',
  1 => names.single,
  _ => '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}',
};

/// The minute of the goal that settled the result, or null when nothing did.
///
/// For a win or a loss it is the last goal after which the lead never changed
/// hands — the goal that turned level into ahead for good. For a draw it is
/// the equaliser. A goalless draw has no such goal, and neither has a result
/// with no goal events to read.
int? deciderMinute(List<ReportGoal> goals) {
  if (goals.isEmpty) return null;
  final ordered = [...goals]..sort((a, b) => a.minute.compareTo(b.minute));
  var diff = 0;
  int? decider;
  for (final g in ordered) {
    final before = diff;
    diff += g.ours ? 1 : -1;
    // From level (or worse) to in front is the only kind of goal a lead can
    // date from; a goal that only widens one leaves the decider where it was.
    if (diff > 0 && before <= 0) decider = g.minute;
    if (diff < 0 && before >= 0) decider = g.minute;
  }
  // Level at the end: whatever the last goal was, it was the equaliser.
  return diff == 0 ? ordered.last.minute : decider;
}

/// A league position as the reader's language writes one.
///
/// English is the only catalogue whose sentences read as "4th"; the rest set
/// the number in their own furniture — "Rang 4.", "4º", "第4" — and appending
/// an English suffix to any of them would be worse than the bug it fixes.
String ordinalOf(int pos) =>
    getLocale() == 'en' ? '$pos${ordinalSuffix(pos)}' : '$pos';
