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
  ///
  /// **It is READ rather than PRINTED.** The write-up used to spend a sentence
  /// and a minute on each of these; it now uses the same list to answer three
  /// questions a reader actually asks — who started it, which half it was won
  /// in, and what the side that lost did about it late on. See the goal
  /// sections of [buildMatchReport].
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
  ///
  /// **Recorded, and mostly not printed.** The write-up named the kick-off
  /// tactic and then every switch by name and minute, which was three
  /// sentences about the manager's dial; it now takes only the LAST LATE
  /// change out of [switches] and says which way it went. Both fields stay on
  /// the record for the same reason [theirSubs] does — the news section reads
  /// this record, not the save.
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

  // ── 3. Who started it ────────────────────────────────────────────────────
  //
  // **IT USED TO BE ONE SENTENCE PER GOAL, each with its minute and the
  // running score.** Reported from the couch: the write-up "spits out the
  // stats a bit too much… it says what minute every goal was scored in", and
  // the ask that came with it is a paragraph about the afternoon rather than a
  // transcript of it — "player a started us off and player b got a hat-trick,
  // they were untouchable today". So a 4-1 is no longer five sentences with
  // five minutes in them.
  //
  // **The timeline is still READ, it is simply no longer PRINTED.** It is what
  // says who opened the scoring, which half the goals came in and what the
  // side that lost did about it in the closing stages — three talking points
  // that a list of minutes leaves the reader to work out for themselves.
  //
  // The tally comes first because the opener defers to it: "Bobby got them
  // started" in front of "Bobby scored three" is one talking point told twice.
  final tally = <String, int>{};
  for (final name in f.scorers) {
    if (name.isEmpty) continue;
    tally[name] = (tally[name] ?? 0) + 1;
  }
  final best = tally.isEmpty
      ? null
      : tally.entries.reduce((a, b) => b.value > a.value ? b : a);
  // Who the tally beat below will name, so the opener knows to stand aside. A
  // spread of scorers names nobody, and neither does a blank.
  final spread = best != null && best.value == 1 && tally.length > 1;
  final standout = best == null || spread ? null : best.key;

  // Ours only, and named only. The opposition's opener is already the shape
  // beat's story, and the sim never names their scorers — "Ayton got them
  // started" is a sentence about nobody.
  final first = ordered.isEmpty ? null : ordered.first;
  final openScorer = first != null && first.ours ? first.scorer : null;
  if (openScorer != null &&
      openScorer.isNotEmpty &&
      openScorer != standout &&
      ordered.length > 1) {
    beats.add((
      key: 'report.goals.opened',
      para: ReportPara.performance,
      params: {
        'club': f.clubName,
        'opp': f.opponentName,
        'player': openScorer,
      },
    ));
  }

  // ── 4. And who took it away ──────────────────────────────────────────────
  //
  // A hat-trick, a brace and a name are three different sentences about the
  // same fact, and the difference is the whole reason a player reads this.
  //
  // **All four come out again now the timeline is not printed.** The single
  // scorer and the spread used to be suppressed whenever the result carried
  // goal events, because the goal-by-goal beats had already named everybody.
  // Nothing names them any more, so without this a 1-0 would say nothing at
  // all about who scored it — which is the one fact the reader came for.
  if (best != null) {
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
    } else if (spread) {
      // **TWO IS ALREADY A SPREAD.** This was three, and everything below it
      // fell through to `report.scorers.one` — which names `best.key` and so
      // told a 2-0 shared between two players that one of them "got the goal".
      // It was invisible while a goal-by-goal timeline was naming both.
      beats.add((
        key: 'report.scorers.spread',
        para: ReportPara.performance,
        params: {'club': f.clubName, 'n': tally.length},
      ));
    } else {
      beats.add((
        key: 'report.scorers.one',
        para: ReportPara.performance,
        params: {'club': f.clubName, 'player': best.key},
      ));
    }
  } else if (f.ours == 0) {
    beats.add((
      key: 'report.scorers.none',
      para: ReportPara.performance,
      params: {'club': f.clubName},
    ));
  }

  // ── 5. When the damage was done, told in HALVES ──────────────────────────
  //
  // "Let's say we scored 4 in the second half" was the couch's own example of
  // something the write-up should be able to say without listing the four
  // minutes it took. So: one sentence, and only when a half genuinely ran away
  // from the other — three or more after the break and at least two more than
  // before it. Anything short of that is not a talking point, it is a
  // scoreline, and the headline has already told it.
  if (ordered.isNotEmpty) {
    var oursFirst = 0;
    var oursSecond = 0;
    var theirsFirst = 0;
    var theirsSecond = 0;
    for (final g in ordered) {
      if (g.ours) {
        if (g.minute > halfTimeMinute) {
          oursSecond++;
        } else {
          oursFirst++;
        }
      } else if (g.minute > halfTimeMinute) {
        theirsSecond++;
      } else {
        theirsFirst++;
      }
    }
    final surge = oursSecond >= surgeGoals && oursSecond >= oursFirst + 2
        ? 'report.goals.surge.ours'
        : theirsSecond >= surgeGoals && theirsSecond >= theirsFirst + 2
        ? 'report.goals.surge.theirs'
        : '';
    if (surge.isNotEmpty) {
      beats.add((
        key: surge,
        para: ReportPara.performance,
        params: {'club': f.clubName, 'opp': f.opponentName},
      ));
    }
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

  // ── 6. How it looked, WITHOUT the numbers ────────────────────────────────
  //
  // **THE BOARD IS NOT A SENTENCE.** This read "{club} had 57% of the ball and
  // 9 shots to {opp}'s 4, 5 of them on target" — which is the statistics panel
  // transcribed into prose, and it is the line the couch meant by "it spits
  // out the stats a bit too much". The panel is right there and prints all
  // seven numbers properly. What a write-up owes the reader is what they ADD
  // UP TO, so the same board now picks one sentence about who had the better
  // of it, with no digits in it at all.
  //
  // Two axes, because a match can be dominated either way round and the
  // interesting cases are the ones where they disagree: all of the ball and
  // none of the chances is a different afternoon from the reverse, and both of
  // those are a different afternoon from being on top of everything.
  //
  // **The two pools that CONTRAST them are the only ones that may claim the
  // ball**, which is why they take both axes rather than a sum. `on_top` and
  // `pinned_back` fire on a single axis as well — 55% of the ball and eight
  // shots to twelve is a side second best — and a variant of theirs saying
  // "{opp} had the ball" would be a flat lie about that match, so they are
  // written about the better of it and about who looked like scoring.
  final st = f.stats;
  if (st != null) {
    final ball = st.possession >= possessionEdge
        ? 1
        : st.possession <= 100 - possessionEdge
        ? -1
        : 0;
    final shotGap = st.shots - st.theirShots;
    final chances = shotGap >= shotEdge
        ? 1
        : shotGap <= -shotEdge
        ? -1
        : 0;
    beats.add((
      key: switch ((ball, chances)) {
        (1, -1) => 'report.stats.ball_only',
        (-1, 1) => 'report.stats.counter',
        _ when ball + chances > 0 => 'report.stats.on_top',
        _ when ball + chances < 0 => 'report.stats.pinned_back',
        _ => 'report.stats.even',
      },
      para: ReportPara.performance,
      params: {'club': f.clubName, 'opp': f.opponentName},
    ));
  }

  // ── 7. And how the OPPOSITION played ─────────────────────────────────────
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

  // ── 8. The referee ───────────────────────────────────────────────────────
  //
  // **What MATTERS, not everything.** A first cut told every card and was sent
  // back as too long: "if a team just got one booking… so what?! dont even
  // mention it!" So: a red is a named player and a minute, always; our
  // bookings only when there were two or more, by name; theirs only the reds.
  // Ours first, because ours is the one that costs a suspension.
  //
  // **And no minute on it.** "Sent off in the 63rd minute" is the same clinical
  // habit as the goal timeline — what matters is that they finished a man
  // short, and the English line says that. No catalogue's `our_red` uses a
  // minute either, so nothing is left holding a placeholder.
  final cards = [...f.cards]..sort((a, b) => a.minute.compareTo(b.minute));
  for (final c in cards) {
    if (!c.ours || !c.red) continue;
    final name = c.player ?? '';
    beats.add((
      // The generated line when the result did not keep the name.
      key: name.isEmpty ? 'report.cards.our_red' : 'report.cards.our_red_named',
      para: ReportPara.incidents,
      params: {'club': f.clubName, 'player': name},
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

  // ── 9. The changes ───────────────────────────────────────────────────────
  //
  // **A SUBSTITUTION IS ONLY A TALKING POINT WHEN IT CHANGED SOMETHING.** This
  // was one sentence listing every change with both names and the minute of
  // each — "Jones for Smith (60th) and Brown (75th)" — which is a team sheet
  // rather than a sentence, and it is the same complaint as the goal minutes.
  // What a reader remembers is a substitute who scored, so that is the line; a
  // bench emptied without one gets a mention only when there were enough
  // changes to have been a plan.
  final subs = [...f.subs]..sort((a, b) => a.minute.compareTo(b.minute));
  final scored = f.scorers.toSet();
  final impact = [
    for (final sub in subs)
      if (sub.on.isNotEmpty && scored.contains(sub.on)) sub.on,
  ];
  if (impact.isNotEmpty) {
    beats.add((
      key: 'report.subs.impact',
      para: ReportPara.incidents,
      params: {'club': f.clubName, 'player': impact.first},
    ));
  } else if (subs.length >= manyChanges) {
    beats.add((
      key: 'report.subs.changes',
      para: ReportPara.incidents,
      params: {'club': f.clubName, 'opp': f.opponentName},
    ));
  }

  // ── 10. The tactics ──────────────────────────────────────────────────────
  //
  // **ONE SENTENCE, AND IT NAMES NEITHER THE DIAL NOR THE MINUTE.** It was
  // three: the tactic the side kicked off with, every change to it by name and
  // minute, and then the late one. Reported from the couch — "exactly what
  // tactic we used and when… changed tactics in 80 minutes to defence" — along
  // with what it should say instead: "team a dropped to defend deep late in
  // the game to defend the lead". That is the LAST LATE change and nothing
  // else, keyed by which way it went, and the English copy tells it as a
  // decision rather than as a setting.
  //
  // **`minute` and `tactic` still travel, and no shipped line uses them.** All
  // ten catalogues have been moved off the minute now — English in
  // `en_copy.dart` and the nine in `lib/i18n/copy/` — but the GENERATED entries
  // underneath those overlays still read "{club} went defensive on {minute}
  // minutes", and a locale falls back to the generated entry the moment its
  // overlay does not carry the key. Dropping the parameters would make that
  // fallback print a literal `{minute}` at a player rather than an older
  // sentence. Two spare map entries is the cheaper side of that trade.
  //
  // [ReportFacts.startTactic] and the earlier switches are still recorded and
  // simply no longer printed; see the field.
  final switches = [...f.switches]
    ..sort((a, b) => a.minute.compareTo(b.minute));
  ReportSwitch? lastLate;
  for (final sw in switches) {
    if (sw.minute >= lateSwitchFrom) lastLate = sw;
  }
  if (lastLate != null) {
    beats.add((
      key: switch (lastLate.tactic) {
        'parkTheBus' || 'counterAttack' => 'report.tactic.shut_up_shop',
        'allOutAttack' || 'highPress' => 'report.tactic.went_for_it',
        _ => 'report.tactic.settled',
      },
      para: ReportPara.incidents,
      params: {
        'club': f.clubName,
        'opp': f.opponentName,
        // The generated copy says "on {minute} minutes": a plain number.
        'minute': lastLate.minute,
        'tactic': tacticName(lastLate.tactic),
      },
    ));
  }

  // ── 11. And what the losing side did about it ────────────────────────────
  //
  // **THE CLOSING STAGES, from the other dugout.** Asked for from the couch in
  // the same breath as the tactics: "team b tried everything forward in the
  // last part of the game but just couldn't find a breakthrough (or could only
  // manage a consolation goal)". The timeline knows both halves of that — who
  // was already behind going into the last quarter of an hour, and whether
  // they got anything after it — so it is one sentence about the pressure
  // rather than the late goal being told again as a minute.
  //
  // Only when somebody was chasing: a match still level at [closingFrom] was
  // won late, and the headline has already said so in those words.
  //
  // **AND ONLY WHEN THEY WERE CHASING SOMETHING CATCHABLE.** Written without
  // this, a 5-1 ended "Ayton threw everything forward and could not find a way
  // through" — nobody four goals down is chasing a breakthrough, they are
  // seeing the afternoon out. [chasableGap] is what a side can still believe
  // in with a quarter of an hour to go, and it has to hold at BOTH ends: the
  // gap they went into the closing stages with, and the one they finished on.
  if (margin != 0 && margin.abs() <= chasableGap && ordered.isNotEmpty) {
    var atClosing = 0;
    var chaserLate = 0;
    for (final g in ordered) {
      if (g.minute <= closingFrom) {
        atClosing += g.ours ? 1 : -1;
      } else if (g.ours == (margin < 0)) {
        // A goal in the closing stages by the side that ended up losing.
        chaserLate++;
      }
    }
    final wasChasing =
        atClosing.abs() <= chasableGap &&
        (margin > 0 ? atClosing > 0 : atClosing < 0);
    if (wasChasing) {
      beats.add((
        key: chaserLate > 0
            ? 'report.late.consolation'
            : 'report.late.held_out',
        para: ReportPara.incidents,
        params: {
          'club': f.clubName,
          'opp': f.opponentName,
          // The two roles by name, so the sentence can be about either club
          // without the copy having to know which one the save belongs to.
          'chaser': margin > 0 ? f.opponentName : f.clubName,
          'holder': margin > 0 ? f.clubName : f.opponentName,
        },
      ));
    }
  }

  // ── 12. Where it leaves us ───────────────────────────────────────────────
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

  // ── 13. And who is next ──────────────────────────────────────────────────
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

/// The break. A goal after this one was scored in the second half.
///
/// The sim's clock runs to 90 without stoppage time, so the halves are the
/// plain halves of it.
const int halfTimeMinute = 45;

/// Goals in one half that make it a SURGE worth a sentence.
///
/// Three, and at least two more than the other half — the couch's own example
/// was four in the second, and the point of the line is that it says "the
/// second half ran away from them" instead of listing four minutes.
const int surgeGoals = 3;

/// Where "the last part of the game" starts, for the losing side's late push.
///
/// A quarter of an hour: far enough out that a side really was chasing it,
/// close enough that a goal in it is a consolation rather than a comeback.
const int closingFrom = 75;

/// Substitutions that add up to a plan rather than to a change of legs.
const int manyChanges = 3;

/// A deficit a side can still believe in with [closingFrom] gone.
///
/// Two. Three down with a quarter of an hour left is not a side throwing
/// everything forward, it is a side seeing the afternoon out, and the write-up
/// said the opposite of a 5-1 before this was here.
const int chasableGap = 2;

/// Possession from here up is HAVING THE BALL, and its mirror is not having it.
///
/// The write-up prints no percentages any more — see the board section of
/// [buildMatchReport] — so the number is only ever a threshold.
const int possessionEdge = 58;

/// A shot count this far clear of the other side's is HAVING THE CHANCES.
const int shotEdge = 3;

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
