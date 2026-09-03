import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/match_report.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';

/// The report is a sequence of BEATS, so what is tested is which sentences a
/// match earns — not the prose, which is a catalogue's business.
void main() {
  ReportFacts facts({
    int ours = 1,
    int theirs = 0,
    List<String> scorers = const ['Bobby'],
    bool wasBehind = false,
    bool wasAhead = true,
    List<ReportGoal> goals = const [],
    // Counts, for the tests that only care how many; each becomes a card.
    int ourYellows = 0,
    int ourReds = 0,
    int theirYellows = 0,
    int theirReds = 0,
    List<ReportCard> cards = const [],
    List<ReportSub> subs = const [],
    int theirSubs = 0,
    String? startTactic,
    List<ReportSwitch> switches = const [],
    ({int minute, String tactic})? lateSwitch,
    ReportStats? stats,
    int? position = 4,
    int? points = 20,
    int? posDelta = 0,
    String? nextOpponent = 'Ayton',
    String? oppNextOpponent,
    bool isCup = false,
  }) => (
    ours: ours,
    theirs: theirs,
    clubName: 'Testville',
    opponentName: 'Ayton',
    isHome: true,
    isCup: isCup,
    scorers: scorers,
    wasBehind: wasBehind,
    wasAhead: wasAhead,
    goals: goals,
    cards: [
      ...cards,
      for (var i = 0; i < ourYellows; i++)
        (minute: 20 + i, ours: true, player: 'Booked $i', red: false),
      for (var i = 0; i < ourReds; i++)
        (minute: 60 + i, ours: true, player: 'Dismissed $i', red: true),
      for (var i = 0; i < theirYellows; i++)
        (minute: 30 + i, ours: false, player: null, red: false),
      for (var i = 0; i < theirReds; i++)
        (minute: 70 + i, ours: false, player: null, red: true),
    ],
    subs: subs,
    theirSubs: theirSubs,
    startTactic: startTactic,
    switches: [...switches, ?lateSwitch],
    stats: stats,
    position: position,
    points: points,
    posDelta: posDelta,
    nextOpponent: nextOpponent,
    nextIsHome: false,
    oppNextOpponent: oppNextOpponent,
  );

  List<String> keysOf(ReportFacts f) =>
      [for (final b in buildMatchReport(f)) b.key];

  group('THE HEADLINE IS THE MARGIN', () {
    test('and it is a different sentence at every one of them', () {
      expect(keysOf(facts(ours: 5, theirs: 0)).first, 'report.win.rout');
      expect(keysOf(facts(ours: 3, theirs: 0)).first, 'report.win.comfortable');
      expect(keysOf(facts(ours: 2, theirs: 0)).first, 'report.win.clear');
      expect(keysOf(facts(ours: 1, theirs: 0)).first, 'report.win.narrow');
      expect(keysOf(facts(ours: 0, theirs: 0)).first, 'report.draw.goalless');
      expect(keysOf(facts(ours: 2, theirs: 2)).first, 'report.draw.shared');
      expect(keysOf(facts(ours: 0, theirs: 1)).first, 'report.loss.narrow');
      expect(keysOf(facts(ours: 0, theirs: 4)).first, 'report.loss.rout');
    });

    test('and the score travels with it, so the sentence can print it', () {
      final beat = buildMatchReport(facts(ours: 3, theirs: 1)).first;
      expect(beat.params['ours'], 3);
      expect(beat.params['theirs'], 1);
      expect(beat.params['opp'], 'Ayton');
      // **AND THE CLUB, because nothing here says "us".** Asked for from the
      // couch: the write-up is a third party's account of the match.
      expect(beat.params['club'], 'Testville');
    });
  });

  group('A LATE DECIDER TAKES OVER THE HEADLINE', () {
    // Reported from the couch: a 1-0 won in the 88th minute was written up as
    // "a single goal that {club} defended for longer than they would have
    // liked" — a lead two minutes old. The margin picked the sentence and the
    // margin cannot know when the goal went in; the timeline can.
    ReportGoal goal(int minute, {bool ours = true}) =>
        (minute: minute, ours: ours, scorer: ours ? 'Bobby' : null);

    test('a one-goal win in the 88th is a late winner, not a siege', () {
      final beats = buildMatchReport(facts(goals: [goal(88)]));
      expect(beats.first.key, 'report.win.late');
      expect(beats.first.params['minute'], '88th');
    });

    test('and the same goal in the 5th is the ordinary narrow win', () {
      final beats = buildMatchReport(facts(goals: [goal(5)]));
      expect(beats.first.key, 'report.win.narrow');
      expect(beats.first.params.containsKey('minute'), isFalse);
    });

    test('the 80th is the line', () {
      expect(keysOf(facts(goals: [goal(80)])).first, 'report.win.late');
      expect(keysOf(facts(goals: [goal(79)])).first, 'report.win.narrow');
    });

    test('a 2-1 whose winner came late is late too', () {
      final keys = keysOf(
        facts(
          ours: 2,
          theirs: 1,
          scorers: const ['Bobby', 'Bobby'],
          goals: [goal(10), goal(40, ours: false), goal(85)],
        ),
      );
      expect(keys.first, 'report.win.late');
    });

    test('but a 2-0 is not, however late the second went in', () {
      final keys = keysOf(
        facts(ours: 2, scorers: const ['A', 'B'], goals: [goal(10), goal(89)]),
      );
      expect(keys.first, 'report.win.clear');
    });

    test('a late loser and a late leveller get their own sentences', () {
      expect(
        keysOf(
          facts(
            ours: 0,
            theirs: 1,
            scorers: const [],
            wasAhead: false,
            wasBehind: true,
            goals: [goal(90, ours: false)],
          ),
        ).first,
        'report.loss.late',
      );
      expect(
        keysOf(
          facts(
            ours: 1,
            theirs: 1,
            wasAhead: false,
            wasBehind: true,
            goals: [goal(20, ours: false), goal(88)],
          ),
        ).first,
        'report.draw.late',
      );
    });

    test('a result with no goal events is written the way it always was', () {
      expect(keysOf(facts()).first, 'report.win.narrow');
    });
  });

  group('SEVEN GOALS IS A THRILLER BEFORE IT IS ANYTHING ELSE', () {
    // Reported from the couch, as the sentence he wanted: "what a thriller of
    // a game, 7 goals between them but it goes to {team}".
    test('a one-goal result with five or more goals', () {
      expect(
        keysOf(facts(ours: 4, theirs: 3, scorers: const ['A', 'B', 'C', 'D'])).first,
        'report.win.thriller',
      );
      expect(
        keysOf(facts(ours: 2, theirs: 3, wasBehind: true, wasAhead: false)).first,
        'report.loss.thriller',
      );
      expect(keysOf(facts(ours: 2, theirs: 1)).first, 'report.win.narrow');
    });

    test('a draw needs six — a 2-2 is a shared afternoon, a 3-3 is a game', () {
      expect(keysOf(facts(ours: 3, theirs: 3)).first, 'report.draw.thriller');
      expect(keysOf(facts(ours: 2, theirs: 2)).first, 'report.draw.shared');
    });

    test('and it outranks a late winner, with the total on it', () {
      final beat = buildMatchReport(
        facts(
          ours: 4,
          theirs: 3,
          scorers: const ['A', 'B', 'C', 'D'],
          goals: const [
            (minute: 10, ours: true, scorer: 'A'),
            (minute: 20, ours: false, scorer: null),
            (minute: 30, ours: true, scorer: 'B'),
            (minute: 40, ours: false, scorer: null),
            (minute: 50, ours: true, scorer: 'C'),
            (minute: 60, ours: false, scorer: null),
            (minute: 89, ours: true, scorer: 'D'),
          ],
        ),
      ).first;
      expect(beat.key, 'report.win.thriller');
      expect(beat.params['total'], 7);
    });
  });

  group('WHICH GOAL SETTLED IT', () {
    ReportGoal g(int minute, {bool ours = true}) =>
        (minute: minute, ours: ours, scorer: null);

    test('the last goal that turned level into a lead that held', () {
      // 1-0 up, pegged back, won it late: the 85th is the one.
      expect(deciderMinute([g(10), g(40, ours: false), g(85)]), 85);
      // Two clear early: the lead dates from the first.
      expect(deciderMinute([g(10), g(30)]), 10);
      // Behind, level, in front, stretched: the third goal, not the fourth.
      expect(deciderMinute([g(5, ours: false), g(20), g(60), g(88)]), 60);
    });

    test('for a draw it is the equaliser', () {
      expect(deciderMinute([g(20, ours: false), g(88)]), 88);
      expect(deciderMinute([g(20), g(70, ours: false)]), 70);
    });

    test('and nothing settled a goalless one', () {
      expect(deciderMinute(const []), isNull);
    });

    test('it reads the order, not the list', () {
      expect(deciderMinute([g(85), g(40, ours: false), g(10)]), 85);
    });
  });

  group('THE SHAPE ONLY CLAIMS A TIME IT CAN STAND BEHIND', () {
    // "Behind early, {club} spent the rest of the afternoon chasing a game
    // that had got away from them" — printed about a goal in the 67th minute.
    // Reported from the couch. Two of the seven shape pools are written about
    // an EARLY goal and one about a LONG spell behind; the two booleans that
    // picked them knew nothing about minutes.
    ReportGoal goal(int minute, {bool ours = true}) =>
        (minute: minute, ours: ours, scorer: ours ? 'Bobby' : null);
    ReportFacts chasing(int minute) => facts(
      ours: 0,
      theirs: 1,
      scorers: const [],
      wasAhead: false,
      wasBehind: true,
      goals: [goal(minute, ours: false)],
    );

    test('"behind early" needs the goal inside the first half hour', () {
      expect(keysOf(chasing(20)), contains('report.shape.chasing'));
      expect(keysOf(chasing(30)), contains('report.shape.chasing'));
      expect(keysOf(chasing(67)), isNot(contains('report.shape.chasing')));
    });

    test('and so does "ahead early"', () {
      expect(
        keysOf(facts(goals: [goal(12)])),
        contains('report.shape.never_behind'),
      );
      expect(
        keysOf(facts(goals: [goal(50)])),
        isNot(contains('report.shape.never_behind')),
      );
      // The 88th-minute case: late as well as not early.
      expect(
        keysOf(facts(goals: [goal(88)])),
        isNot(contains('report.shape.never_behind')),
      );
    });

    test('"trailing for much of it" needs half an hour behind', () {
      ReportFacts rescued(int behindAt, int levelAt) => facts(
        ours: 1,
        theirs: 1,
        wasAhead: false,
        wasBehind: true,
        goals: [goal(behindAt, ours: false), goal(levelAt)],
      );
      expect(keysOf(rescued(20, 75)), contains('report.shape.rescued'));
      expect(keysOf(rescued(60, 75)), isNot(contains('report.shape.rescued')));
    });

    test('the shapes that say nothing about time are said at any minute', () {
      expect(
        keysOf(
          facts(
            ours: 2,
            theirs: 1,
            scorers: const ['Bobby', 'Bobby'],
            wasBehind: true,
            goals: [goal(60, ours: false), goal(70), goal(75)],
          ),
        ),
        contains('report.shape.turnaround'),
      );
    });

    test('with no goal events the shape is told as it always was', () {
      expect(keysOf(facts()), contains('report.shape.never_behind'));
    });
  });

  group('MINUTES SPENT BEHIND', () {
    ReportGoal g(int minute, {bool ours = true}) =>
        (minute: minute, ours: ours, scorer: null);

    test('counts the spells, not the goals', () {
      // Behind 20–45, level, behind again 60–75: forty minutes.
      expect(
        minutesBehind([g(20, ours: false), g(45), g(60, ours: false), g(75)]),
        40,
      );
      expect(minutesBehind([g(10)]), 0);
    });

    test('a spell still open runs to the whistle, or to the minute asked', () {
      expect(minutesBehind([g(70, ours: false)]), 20);
      expect(minutesBehind([g(70, ours: false)], until: 80), 10);
    });
  });

  group('THE SHAPE IS WHAT THE SCORE CANNOT SAY', () {
    test('a 2-2 that was 2-0 down is not a 2-2 that was 2-0 up', () {
      expect(
        keysOf(facts(ours: 2, theirs: 2, wasBehind: true, wasAhead: false)),
        contains('report.shape.rescued'),
      );
      expect(
        keysOf(facts(ours: 2, theirs: 2, wasBehind: false, wasAhead: true)),
        contains('report.shape.threw_it'),
      );
    });

    test('and a comeback win says so', () {
      expect(
        keysOf(facts(ours: 3, theirs: 2, wasBehind: true, wasAhead: true)),
        contains('report.shape.turnaround'),
      );
    });

    test('a goalless draw has no shape to describe', () {
      final keys = keysOf(
        facts(ours: 0, theirs: 0, scorers: const [], wasAhead: false),
      );
      expect(keys.where((k) => k.startsWith('report.shape.')), isEmpty);
    });
  });

  group('WHO SCORED', () {
    test('a hat-trick, a brace and a name are three sentences', () {
      expect(
        keysOf(facts(ours: 3, scorers: const ['A', 'A', 'A'])),
        contains('report.scorers.hat_trick'),
      );
      expect(
        keysOf(facts(ours: 2, scorers: const ['A', 'A'])),
        contains('report.scorers.brace'),
      );
      expect(
        keysOf(facts(scorers: const ['A'])),
        contains('report.scorers.one'),
      );
      expect(
        keysOf(facts(ours: 3, scorers: const ['A', 'B', 'C'])),
        contains('report.scorers.spread'),
      );
    });

    test('and a clean sheet is only a line when one was worked for', () {
      expect(keysOf(facts(ours: 1, theirs: 0)), contains('report.clean_sheet'));
      expect(
        keysOf(facts(ours: 0, theirs: 0, scorers: const [], wasAhead: false)),
        isNot(contains('report.clean_sheet')),
      );
    });
  });

  group('THE REFEREE IS TOLD WHERE IT MATTERS', () {
    // A first cut told every card and was sent back as too long: "if a team
    // just got one booking… so what?! dont even mention it!"
    test('a red of ours is a named player and a minute', () {
      final beat = buildMatchReport(
        facts(
          cards: const [
            (minute: 63, ours: true, player: 'Smith', red: true),
          ],
        ),
      ).firstWhere((b) => b.key.startsWith('report.cards.'));
      expect(beat.key, 'report.cards.our_red_named');
      expect(beat.params['player'], 'Smith');
      expect(beat.params['minute'], '63rd');
    });

    test('and falls back to the generated line when the name is gone', () {
      expect(
        keysOf(facts(cards: const [(minute: 63, ours: true, player: null, red: true)])),
        contains('report.cards.our_red'),
      );
    });

    test('one booking is not worth saying; two or more are named', () {
      expect(
        keysOf(facts(ourYellows: 1)).where((k) => k.startsWith('report.cards')),
        isEmpty,
      );
      final many = buildMatchReport(
        facts(ourYellows: 3),
      ).firstWhere((b) => b.key.startsWith('report.cards.'));
      expect(many.key, 'report.cards.our_booked_many');
      expect(many.params['names'], 'Booked 0, Booked 1 and Booked 2');
    });

    test('theirs are only the reds', () {
      final keys = keysOf(facts(theirReds: 1, theirYellows: 4));
      expect(keys, contains('report.cards.their_red'));
      expect(keys.where((k) => k.contains('yellow')), isEmpty);
      expect(keysOf(facts(theirReds: 2)), contains('report.cards.their_reds'));
    });
  });

  group('THE GOALS, ONE BY ONE', () {
    ReportGoal g(int minute, {bool ours = true, String? scorer = 'Bobby'}) =>
        (minute: minute, ours: ours, scorer: ours ? scorer : null);

    test('each goal is keyed by what it did to the match', () {
      // 0-1, 1-1, 2-1, 3-1, 3-2: opener, leveller, lead, extend, pull back.
      final keys = keysOf(
        facts(
          ours: 3,
          theirs: 2,
          scorers: const ['Bobby', 'Bobby', 'Bobby'],
          wasBehind: true,
          goals: [
            g(10, ours: false),
            g(25),
            g(40),
            g(60),
            g(80, ours: false),
          ],
        ),
      ).where((k) => k.startsWith('report.goal.')).toList();
      expect(keys, [
        'report.goal.theirs.opener',
        'report.goal.ours.leveller',
        'report.goal.ours.lead',
        'report.goal.ours.extend',
        'report.goal.theirs.pull_back',
      ]);
    });

    test('and carries the minute, the scorer and the score it left', () {
      final beat = buildMatchReport(
        facts(goals: [g(88, scorer: 'Smith')]),
      ).firstWhere((b) => b.key.startsWith('report.goal.'));
      expect(beat.params['minute'], '88th');
      expect(beat.params['scorer'], 'Smith');
      expect(beat.params['score'], '1-0');
    });

    test('an unnamed scorer of ours is told as the club', () {
      final beat = buildMatchReport(
        facts(goals: [g(20, scorer: null)]),
      ).firstWhere((b) => b.key.startsWith('report.goal.'));
      expect(beat.params['scorer'], 'Testville');
    });

    test('the tally still says brace and hat-trick, and no longer the one', () {
      expect(
        keysOf(facts(goals: [g(20)])),
        isNot(contains('report.scorers.one')),
      );
      expect(
        keysOf(
          facts(ours: 2, scorers: const ['Bobby', 'Bobby'], goals: [g(20), g(50)]),
        ),
        contains('report.scorers.brace'),
      );
      // No events to read: the old sentence comes back.
      expect(keysOf(facts()), contains('report.scorers.one'));
    });
  });

  group('THE CHANGES AND THE NUMBERS', () {
    test('the substitutions are one sentence, both names and a minute each', () {
      final beats = buildMatchReport(
        facts(
          subs: const [
            (minute: 60, on: 'Jones', off: 'Smith'),
            (minute: 75, on: 'Brown', off: null),
          ],
          theirSubs: 3,
        ),
      ).where((b) => b.key.startsWith('report.subs.')).toList();
      expect(beats.map((b) => b.key), ['report.subs.made']);
      expect(beats.single.params['n'], 2);
      expect(
        beats.single.params['list'],
        'Jones for Smith (60th) and Brown (75th)',
      );
    });

    test('the board is one sentence, our side first', () {
      final beat = buildMatchReport(
        facts(
          stats: (
            possession: 57,
            shots: 9,
            theirShots: 4,
            onTarget: 5,
            theirOnTarget: 1,
            corners: 6,
            theirCorners: 2,
          ),
        ),
      ).firstWhere((b) => b.key == 'report.stats.board');
      expect(beat.params['poss'], 57);
      expect(beat.params['oppPoss'], 43);
      expect(beat.params['shots'], 9);
      expect(beat.params['oppShots'], 4);
    });

    test('and nothing is said about a board the result cannot fill', () {
      expect(keysOf(facts()), isNot(contains('report.stats.board')));
    });
  });

  group('WHERE IT LEAVES US', () {
    test('a climb, a fall and standing still are three sentences', () {
      expect(keysOf(facts(posDelta: 2)), contains('report.table.climbed'));
      expect(keysOf(facts(posDelta: -2)), contains('report.table.dropped'));
      expect(keysOf(facts(posDelta: 0)), contains('report.table.held'));
    });

    test('and a cup tie has no table to move in', () {
      expect(
        keysOf(facts(isCup: true)).where((k) => k.startsWith('report.table')),
        isEmpty,
      );
    });

    test('nor has a save with no row in one', () {
      expect(
        keysOf(
          facts(position: null, points: null, posDelta: null),
        ).where((k) => k.startsWith('report.table')),
        isEmpty,
      );
    });

    test('and the last word is who is next, when there is one', () {
      expect(keysOf(facts()).last, 'report.next.away');
      // **And BOTH clubs' next fixtures when the schedule knows them.** Asked
      // for from the couch: the write-up is a summary for anyone reading it, so
      // ending on only our own next game tells a reader about one of the two
      // sides.
      expect(
        keysOf(facts(oppNextOpponent: 'Beeches')).last,
        'report.next.away_both',
      );
      expect(
        keysOf(facts(nextOpponent: null)).last,
        isNot(startsWith('report.next')),
      );
    });
  });

  group('WHICH WAY IT SWUNG', () {
    List<Map<String, dynamic>> goals(List<(int, String)> at) => [
      for (final (minute, team) in at)
        {'minute': minute, 'type': 'goal', 'team': team},
    ];

    test('reads the order, not the final score', () {
      // 0-2 down, 2-2 at the end.
      expect(
        leadSwings(goals([(10, 'away'), (20, 'away'), (70, 'home'), (85, 'home')])),
        (wasBehind: true, wasAhead: false),
      );
      // 2-0 up, 2-2 at the end.
      expect(
        leadSwings(goals([(10, 'home'), (20, 'home'), (70, 'away'), (85, 'away')])),
        (wasBehind: false, wasAhead: true),
      );
    });

    test('and it sorts, because the events may not be in order', () {
      expect(
        leadSwings(goals([(85, 'home'), (10, 'away')])),
        (wasBehind: true, wasAhead: false),
      );
    });

    test('nothing happened, nothing swung', () {
      expect(leadSwings(const []), (wasBehind: false, wasAhead: false));
    });
  });

  group('HOW IT WAS SEEN OUT', () {
    // Asked for from the couch: "we know the context of the tactics used, like
    // if we switched to defence in 70m we can happily say they spent the last
    // part of the game defending — we have that info so we should use it." The
    // match screen logs the minute now; nothing recorded it before.
    test('a late switch is named, and which way it went decides the line', () {
      expect(
        keysOf(facts(lateSwitch: (minute: 70, tactic: 'parkTheBus'))),
        contains('report.tactic.shut_up_shop'),
      );
      expect(
        keysOf(facts(lateSwitch: (minute: 70, tactic: 'counterAttack'))),
        contains('report.tactic.shut_up_shop'),
      );
      expect(
        keysOf(facts(lateSwitch: (minute: 68, tactic: 'allOutAttack'))),
        contains('report.tactic.went_for_it'),
      );
      expect(
        keysOf(facts(lateSwitch: (minute: 68, tactic: 'highPress'))),
        contains('report.tactic.went_for_it'),
      );
      expect(
        keysOf(facts(lateSwitch: (minute: 75, tactic: 'balanced'))),
        contains('report.tactic.settled'),
      );
    });

    test('and the minute travels, because the sentence prints it', () {
      final beat = buildMatchReport(
        facts(lateSwitch: (minute: 72, tactic: 'parkTheBus')),
      ).firstWhere((b) => b.key.startsWith('report.tactic.'));
      expect(beat.params['minute'], 72);
      expect(beat.params['club'], 'Testville');
    });

    test('a match nobody changed anything in says nothing about tactics', () {
      expect(
        keysOf(facts()).where((k) => k.startsWith('report.tactic.')),
        isEmpty,
      );
    });

    test('a kick-off tactic is told only when it changed', () {
      expect(
        keysOf(facts(startTactic: 'balanced')).where(
          (k) => k.startsWith('report.tactic.'),
        ),
        isEmpty,
      );
      final keys = keysOf(
        facts(
          startTactic: 'balanced',
          switches: const [(minute: 30, tactic: 'highPress')],
          lateSwitch: (minute: 75, tactic: 'parkTheBus'),
        ),
      ).where((k) => k.startsWith('report.tactic.')).toList();
      // Started, an early switch by name, and the late one with its story.
      expect(keys, [
        'report.tactic.started',
        'report.tactic.switch',
        'report.tactic.shut_up_shop',
      ]);
    });

    test('and the tactic travels as the strip names it', () {
      final beat = buildMatchReport(
        facts(
          startTactic: 'parkTheBus',
          switches: const [(minute: 30, tactic: 'highPress')],
        ),
      ).firstWhere((b) => b.key == 'report.tactic.started');
      expect(beat.params['tactic'], t('strategy.parkTheBus.name'));
    });
  });

  group('EVERY VARIANT OF EVERY BEAT IS FILLED IN', () {
    // **A pool's variants do not all take the same placeholders.** Reported
    // from the couch: a match summary printing a literal `{opp}`. It was
    // `report.clean_sheet`, whose second of three variants opens "{opp} were
    // kept out entirely" while the beat passed `club` alone — so one clean
    // sheet in three read its own placeholder at the player.
    //
    // Asserting the RENDERED beat would have missed it two runs in three,
    // because `t()` picks one variant. This expands the pool instead and
    // checks every line of it, in every catalogue, for every shape of match
    // the report can describe. Any beat that ever needs a name it is not given
    // fails here rather than on somebody's phone.
    final shapes = <String, ReportFacts>{
      'clean sheet': facts(ours: 2, theirs: 0),
      'thriller won': facts(ours: 4, theirs: 3, scorers: const ['A', 'B', 'C', 'D']),
      'thriller lost': facts(ours: 3, theirs: 4, wasBehind: true),
      'thriller drawn': facts(ours: 3, theirs: 3, wasBehind: true),
      'late winner': facts(
        goals: const [(minute: 88, ours: true, scorer: 'Bobby')],
      ),
      'late loser': facts(
        ours: 0,
        theirs: 1,
        scorers: const [],
        wasAhead: false,
        wasBehind: true,
        goals: const [(minute: 90, ours: false, scorer: null)],
      ),
      'late leveller': facts(
        ours: 1,
        theirs: 1,
        wasAhead: false,
        wasBehind: true,
        goals: const [
          (minute: 20, ours: false, scorer: null),
          (minute: 88, ours: true, scorer: 'Bobby'),
        ],
      ),
      'goal by goal': facts(
        ours: 3,
        theirs: 2,
        scorers: const ['A', 'B', 'C'],
        wasBehind: true,
        goals: const [
          (minute: 10, ours: false, scorer: null),
          (minute: 25, ours: true, scorer: 'A'),
          (minute: 40, ours: true, scorer: 'B'),
          (minute: 60, ours: true, scorer: 'C'),
          (minute: 80, ours: false, scorer: null),
        ],
      ),
      'the board': facts(
        stats: (
          possession: 57,
          shots: 9,
          theirShots: 4,
          onTarget: 5,
          theirOnTarget: 1,
          corners: 6,
          theirCorners: 2,
        ),
      ),
      'booked once': facts(ourYellows: 1),
      'their cards': facts(theirYellows: 2, theirReds: 2),
      'a red without a name': facts(
        cards: const [(minute: 50, ours: true, player: null, red: true)],
      ),
      'subs': facts(
        subs: const [
          (minute: 60, on: 'Jones', off: 'Smith'),
          (minute: 75, on: 'Brown', off: null),
        ],
        theirSubs: 1,
      ),
      'started and switched early': facts(
        startTactic: 'balanced',
        switches: const [(minute: 30, tactic: 'highPress')],
      ),
      'goalless': facts(ours: 0, theirs: 0, scorers: const []),
      'rout': facts(ours: 5, theirs: 0, scorers: const ['A', 'B', 'C']),
      'hammered': facts(ours: 0, theirs: 4, scorers: const [], wasAhead: false),
      'turnaround': facts(ours: 2, theirs: 1, wasBehind: true),
      'threw it': facts(ours: 1, theirs: 2, wasBehind: true, wasAhead: true),
      'our red': facts(ourReds: 1),
      'two reds': facts(ourReds: 2),
      'our yellows': facts(ourYellows: 3),
      'their red': facts(theirReds: 1),
      'climbed': facts(posDelta: 2),
      'dropped': facts(posDelta: -1),
      'held': facts(posDelta: 0),
      'one place': facts(posDelta: 1),
      'cup tie': facts(isCup: true, position: null, points: null),
      'both next': facts(oppNextOpponent: 'Beeches'),
      'shut up shop': facts(
        lateSwitch: (minute: 74, tactic: 'parkTheBus'),
      ),
      'went for it': facts(
        lateSwitch: (minute: 70, tactic: 'allOutAttack'),
      ),
      'settled': facts(lateSwitch: (minute: 80, tactic: 'balanced')),
      'brace': facts(ours: 2, scorers: const ['Bobby', 'Bobby']),
      'hat-trick': facts(
        ours: 3,
        scorers: const ['Bobby', 'Bobby', 'Bobby'],
      ),
    };

    for (final locale in localeIds) {
      test('in $locale', () {
        setLocale(locale);
        addTearDown(resetLocale);
        final catalog = catalogFor(locale);
        for (final entry in shapes.entries) {
          for (final beat in buildMatchReport(entry.value)) {
            final raw = catalog[beat.key] ?? englishCatalog[beat.key];
            expect(
              raw,
              isNotNull,
              reason: '${beat.key} is not in $locale or in English',
            );
            for (final variant in raw!.split('|')) {
              var filled = variant;
              for (final p in beat.params.entries) {
                filled = filled.replaceAll('{${p.key}}', '${p.value}');
              }
              expect(
                RegExp(r'\{\w+\}').firstMatch(filled)?.group(0),
                isNull,
                reason:
                    '${entry.key}: ${beat.key} leaves a placeholder unfilled '
                    'in $locale — it is given ${beat.params.keys.toList()}',
              );
            }
          }
        }
      });
    }
  });

}
