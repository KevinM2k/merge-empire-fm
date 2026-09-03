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

  /// A board at the whistle, by the two things the write-up reads off it.
  ReportStats board(int possession, int shots, int theirShots) => (
    possession: possession,
    shots: shots,
    theirShots: theirShots,
    onTarget: 5,
    theirOnTarget: 1,
    corners: 6,
    theirCorners: 2,
  );

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
    test('a red of ours is a named player, and no minute', () {
      final beat = buildMatchReport(
        facts(
          cards: const [
            (minute: 63, ours: true, player: 'Smith', red: true),
          ],
        ),
      ).firstWhere((b) => b.key.startsWith('report.cards.'));
      expect(beat.key, 'report.cards.our_red_named');
      expect(beat.params['player'], 'Smith');
      // "Sent off in the 63rd minute" is the same clinical habit as the goal
      // timeline. What matters is that they finished a man short.
      expect(beat.params.containsKey('minute'), isFalse);
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

  group('THE GOALS ARE TALKING POINTS, NOT A TIMELINE', () {
    // Reported from the couch: the write-up "says what minute every goal was
    // scored in", where it should read "player a started us off and player b
    // got a hat-trick, they were untouchable today". So a 3-2 is no longer
    // five sentences with five minutes in them.
    ReportGoal g(int minute, {bool ours = true, String? scorer = 'Bobby'}) =>
        (minute: minute, ours: ours, scorer: ours ? scorer : null);

    test('no goal is told with its minute any more', () {
      final keys = keysOf(
        facts(
          ours: 3,
          theirs: 2,
          scorers: const ['A', 'B', 'C'],
          wasBehind: true,
          goals: [
            g(10, ours: false),
            g(25, scorer: 'A'),
            g(40, scorer: 'B'),
            g(60, scorer: 'C'),
            g(80, ours: false),
          ],
        ),
      );
      expect(keys.where((k) => k.startsWith('report.goal.')), isEmpty);
    });

    test('who started it is one sentence, and it carries no minute', () {
      final beat = buildMatchReport(
        facts(
          ours: 2,
          scorers: const ['Smith', 'Jones'],
          goals: [g(12, scorer: 'Smith'), g(70, scorer: 'Jones')],
        ),
      ).firstWhere((b) => b.key == 'report.goals.opened');
      expect(beat.params['player'], 'Smith');
      expect(beat.params.containsKey('minute'), isFalse);
    });

    test('and it stands aside when the tally is about to name the same man', () {
      // "Bobby got them going" in front of "Bobby scored three" is one talking
      // point told twice.
      final keys = keysOf(
        facts(
          ours: 3,
          scorers: const ['Bobby', 'Bobby', 'Bobby'],
          goals: [g(12), g(40), g(70)],
        ),
      );
      expect(keys, isNot(contains('report.goals.opened')));
      expect(keys, contains('report.scorers.hat_trick'));
    });

    test('nor is a lone goal opened by anybody — the tally has it', () {
      final keys = keysOf(facts(goals: [g(12, scorer: 'Smith')]));
      expect(keys, isNot(contains('report.goals.opened')));
      expect(keys, contains('report.scorers.one'));
    });

    test('the opposition never opens the scoring by name; they cannot', () {
      // The sim does not name their scorers, and the shape beat already tells
      // a side that went behind first.
      expect(
        keysOf(
          facts(
            ours: 1,
            theirs: 1,
            wasBehind: true,
            wasAhead: false,
            goals: [g(10, ours: false), g(60)],
          ),
        ),
        isNot(contains('report.goals.opened')),
      );
    });

    test('and an unnamed scorer of ours does not open it either', () {
      expect(
        keysOf(
          facts(
            ours: 2,
            scorers: const ['Jones'],
            goals: [g(20, scorer: null), g(60, scorer: 'Jones')],
          ),
        ),
        isNot(contains('report.goals.opened')),
      );
    });

    test('the tally names the scorers whether or not there is a timeline', () {
      // The single scorer and the spread used to be suppressed when the result
      // carried goal events, because the goal-by-goal beats named everybody.
      // Nothing names them now.
      expect(keysOf(facts(goals: [(minute: 20, ours: true, scorer: 'Bobby')])),
          contains('report.scorers.one'));
      expect(keysOf(facts()), contains('report.scorers.one'));
      expect(
        keysOf(
          facts(
            ours: 3,
            scorers: const ['A', 'B', 'C'],
            goals: [g(20, scorer: 'A'), g(50, scorer: 'B'), g(70, scorer: 'C')],
          ),
        ),
        contains('report.scorers.spread'),
      );
    });
  });

  group('WHEN THE DAMAGE WAS DONE, IN HALVES', () {
    // "Let's say we scored 4 in the second half" — the write-up should be able
    // to say that without listing the four minutes it took.
    ReportGoal g(int minute, {bool ours = true}) =>
        (minute: minute, ours: ours, scorer: ours ? 'Bobby' : null);

    test('four after the break is a surge, and no number is printed', () {
      final beat = buildMatchReport(
        facts(
          ours: 4,
          scorers: const ['A', 'B', 'C', 'D'],
          goals: [g(50), g(60), g(70), g(80)],
        ),
      ).firstWhere((b) => b.key.startsWith('report.goals.surge'));
      expect(beat.key, 'report.goals.surge.ours');
      expect(beat.params.keys, unorderedEquals(['club', 'opp']));
    });

    test('and it reads the other way when they are the ones scoring them', () {
      expect(
        keysOf(
          facts(
            ours: 0,
            theirs: 4,
            scorers: const [],
            wasAhead: false,
            wasBehind: true,
            goals: [
              g(50, ours: false),
              g(60, ours: false),
              g(70, ours: false),
              g(80, ours: false),
            ],
          ),
        ),
        contains('report.goals.surge.theirs'),
      );
    });

    test('a half that did not run away from the other one says nothing', () {
      // Three after the break, two before it: a scoreline, not a talking point.
      expect(
        keysOf(
          facts(
            ours: 5,
            scorers: const ['A', 'B', 'C', 'D', 'E'],
            goals: [g(10), g(30), g(50), g(60), g(70)],
          ),
        ).where((k) => k.startsWith('report.goals.surge')),
        isEmpty,
      );
      // And two on their own are never one.
      expect(
        keysOf(
          facts(ours: 2, scorers: const ['A', 'B'], goals: [g(50), g(70)]),
        ).where((k) => k.startsWith('report.goals.surge')),
        isEmpty,
      );
    });
  });

  group('THE CHANGES AND THE NUMBERS', () {
    test('a substitute who scored is the sentence; the team sheet is not', () {
      final beats = buildMatchReport(
        facts(
          ours: 2,
          scorers: const ['Bobby', 'Brown'],
          subs: const [
            (minute: 60, on: 'Jones', off: 'Smith'),
            (minute: 75, on: 'Brown', off: null),
          ],
          theirSubs: 3,
        ),
      ).where((b) => b.key.startsWith('report.subs.')).toList();
      expect(beats.map((b) => b.key), ['report.subs.impact']);
      expect(beats.single.params['player'], 'Brown');
      // No list of names, and no minute against any of them.
      expect(beats.single.params.keys, unorderedEquals(['club', 'player']));
    });

    test('changes that did nothing are a line only when there were enough', () {
      expect(
        keysOf(
          facts(
            subs: const [
              (minute: 60, on: 'Jones', off: 'Smith'),
              (minute: 75, on: 'Brown', off: null),
            ],
          ),
        ).where((k) => k.startsWith('report.subs.')),
        isEmpty,
      );
      expect(
        keysOf(
          facts(
            subs: const [
              (minute: 60, on: 'Jones', off: 'Smith'),
              (minute: 70, on: 'Brown', off: null),
              (minute: 75, on: 'Green', off: 'Bobby'),
            ],
          ),
        ),
        contains('report.subs.changes'),
      );
    });

    test('the board is a verdict with no digits in it', () {
      // It read "{club} had 57% of the ball and 9 shots to Ayton's 4" — the
      // statistics panel, transcribed.
      String boardKey(ReportStats s) => buildMatchReport(
        facts(stats: s),
      ).firstWhere((b) => b.key.startsWith('report.stats.')).key;

      expect(boardKey(board(62, 14, 4)), 'report.stats.on_top');
      expect(boardKey(board(38, 4, 14)), 'report.stats.pinned_back');
      expect(boardKey(board(62, 4, 14)), 'report.stats.ball_only');
      expect(boardKey(board(38, 14, 4)), 'report.stats.counter');
      expect(boardKey(board(50, 8, 8)), 'report.stats.even');
      // One axis is enough to be second best, and it is why neither of those
      // two pools may claim the ball: this side had 55% of it.
      expect(boardKey(board(55, 8, 12)), 'report.stats.pinned_back');
      expect(boardKey(board(50, 12, 8)), 'report.stats.on_top');

      final beat = buildMatchReport(
        facts(stats: board(62, 14, 4)),
      ).firstWhere((b) => b.key.startsWith('report.stats.'));
      expect(beat.params.keys, unorderedEquals(['club', 'opp']));
    });

    test('and nothing is said about a board the result cannot fill', () {
      expect(
        keysOf(facts()).where((k) => k.startsWith('report.stats.')),
        isEmpty,
      );
    });
  });

  group('WHAT THE LOSING SIDE DID ABOUT IT', () {
    // Asked for from the couch: "team b tried throwing everything forward in
    // the last part of the game but just couldn't find a breakthrough (or
    // could only manage a consolation goal)".
    ReportGoal g(int minute, {bool ours = true}) =>
        (minute: minute, ours: ours, scorer: ours ? 'Bobby' : null);

    test('behind going into the last of it, and nothing to show for it', () {
      final beat = buildMatchReport(
        facts(ours: 1, goals: [g(20)]),
      ).firstWhere((b) => b.key.startsWith('report.late.'));
      expect(beat.key, 'report.late.held_out');
      // The two roles by name, so the sentence works from either dugout.
      expect(beat.params['chaser'], 'Ayton');
      expect(beat.params['holder'], 'Testville');
    });

    test('a goal in the closing stages that was not enough is a consolation', () {
      final beat = buildMatchReport(
        facts(ours: 2, theirs: 1, scorers: const ['A', 'B'], goals: [
          g(20),
          g(30),
          g(85, ours: false),
        ]),
      ).firstWhere((b) => b.key.startsWith('report.late.'));
      expect(beat.key, 'report.late.consolation');
      expect(beat.params['chaser'], 'Ayton');
    });

    test('and the roles swap when it is our side doing the chasing', () {
      final beat = buildMatchReport(
        facts(
          ours: 0,
          theirs: 2,
          scorers: const [],
          wasAhead: false,
          wasBehind: true,
          goals: [g(20, ours: false), g(30, ours: false)],
        ),
      ).firstWhere((b) => b.key.startsWith('report.late.'));
      expect(beat.key, 'report.late.held_out');
      expect(beat.params['chaser'], 'Testville');
      expect(beat.params['holder'], 'Ayton');
    });

    test('a match still level at that point was won late, not held out', () {
      expect(
        keysOf(facts(goals: [g(88)])).where((k) => k.startsWith('report.late.')),
        isEmpty,
      );
    });

    test('and a draw has nobody chasing at the end of it', () {
      expect(
        keysOf(
          facts(
            ours: 1,
            theirs: 1,
            wasBehind: true,
            wasAhead: false,
            goals: [g(20, ours: false), g(40)],
          ),
        ).where((k) => k.startsWith('report.late.')),
        isEmpty,
      );
    });

    test('nor has a result the events cannot describe', () {
      expect(
        keysOf(facts()).where((k) => k.startsWith('report.late.')),
        isEmpty,
      );
    });

    test('and nobody four down is chasing a breakthrough', () {
      // A 5-1 ended "Ayton threw everything forward and could not find a way
      // through". Four goals down with a quarter of an hour left is a side
      // seeing the afternoon out.
      expect(
        keysOf(
          facts(
            ours: 5,
            theirs: 1,
            scorers: const ['A', 'B', 'C', 'D', 'E'],
            goals: [
              g(22),
              g(51),
              g(58),
              g(66),
              g(72),
              g(88, ours: false),
            ],
          ),
        ).where((k) => k.startsWith('report.late.')),
        isEmpty,
      );
    });

    test('and the gap has to be catchable at both ends of it', () {
      // Three down going into the closing stages and beaten by two is a late
      // goal, not a siege the other side withstood.
      expect(
        keysOf(
          facts(
            ours: 1,
            theirs: 3,
            scorers: const ['A'],
            wasAhead: false,
            wasBehind: true,
            goals: [
              g(10, ours: false),
              g(20, ours: false),
              g(30, ours: false),
              g(85),
            ],
          ),
        ).where((k) => k.startsWith('report.late.')),
        isEmpty,
      );
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

    test('the minute and the tactic still travel, for the fallback', () {
      // No shipped line prints either any more — "on 80 minutes {club}
      // switched to Defence" is a settings screen, and all ten catalogues have
      // been moved off it. The GENERATED entries under the overlays still use
      // them, though, and that is what a locale gets if its overlay ever loses
      // the key, so the beat goes on passing them rather than risking a
      // literal `{minute}` at a player.
      final beat = buildMatchReport(
        facts(lateSwitch: (minute: 72, tactic: 'parkTheBus')),
      ).firstWhere((b) => b.key.startsWith('report.tactic.'));
      expect(beat.params['minute'], 72);
      expect(beat.params['tactic'], t('strategy.parkTheBus.name'));
      expect(beat.params['club'], 'Testville');
    });

    test('a match nobody changed anything in says nothing about tactics', () {
      expect(
        keysOf(facts()).where((k) => k.startsWith('report.tactic.')),
        isEmpty,
      );
    });

    test('the kick-off tactic and the early switches are not told at all', () {
      // Reported from the couch: "exactly what tactic we used and when". Three
      // sentences about the dial is a report about the manager; only the last
      // late change survives, and it is told as a decision.
      expect(
        keysOf(facts(startTactic: 'balanced')).where(
          (k) => k.startsWith('report.tactic.'),
        ),
        isEmpty,
      );
      expect(
        keysOf(
          facts(
            startTactic: 'balanced',
            switches: const [(minute: 30, tactic: 'highPress')],
          ),
        ).where((k) => k.startsWith('report.tactic.')),
        isEmpty,
      );
      final keys = keysOf(
        facts(
          startTactic: 'balanced',
          switches: const [(minute: 30, tactic: 'highPress')],
          lateSwitch: (minute: 75, tactic: 'parkTheBus'),
        ),
      ).where((k) => k.startsWith('report.tactic.')).toList();
      expect(keys, ['report.tactic.shut_up_shop']);
    });

    test('and only the LAST late change, when there were two of them', () {
      final keys = keysOf(
        facts(
          switches: const [(minute: 65, tactic: 'allOutAttack')],
          lateSwitch: (minute: 82, tactic: 'parkTheBus'),
        ),
      ).where((k) => k.startsWith('report.tactic.')).toList();
      expect(keys, ['report.tactic.shut_up_shop']);
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
      'opened by a name': facts(
        ours: 2,
        scorers: const ['A', 'B'],
        goals: const [
          (minute: 12, ours: true, scorer: 'A'),
          (minute: 70, ours: true, scorer: 'B'),
        ],
      ),
      'our surge': facts(
        ours: 4,
        scorers: const ['A', 'B', 'C', 'D'],
        goals: const [
          (minute: 50, ours: true, scorer: 'A'),
          (minute: 60, ours: true, scorer: 'B'),
          (minute: 70, ours: true, scorer: 'C'),
          (minute: 80, ours: true, scorer: 'D'),
        ],
      ),
      'their surge': facts(
        ours: 0,
        theirs: 4,
        scorers: const [],
        wasAhead: false,
        wasBehind: true,
        goals: const [
          (minute: 50, ours: false, scorer: null),
          (minute: 60, ours: false, scorer: null),
          (minute: 70, ours: false, scorer: null),
          (minute: 80, ours: false, scorer: null),
        ],
      ),
      'held out': facts(
        ours: 1,
        goals: const [(minute: 20, ours: true, scorer: 'Bobby')],
      ),
      'consolation': facts(
        ours: 2,
        theirs: 1,
        scorers: const ['A', 'B'],
        goals: const [
          (minute: 20, ours: true, scorer: 'A'),
          (minute: 30, ours: true, scorer: 'B'),
          (minute: 85, ours: false, scorer: null),
        ],
      ),
      'chasing it ourselves': facts(
        ours: 0,
        theirs: 2,
        scorers: const [],
        wasAhead: false,
        wasBehind: true,
        goals: const [
          (minute: 20, ours: false, scorer: null),
          (minute: 30, ours: false, scorer: null),
        ],
      ),
      // The board is a verdict now, and there are five of them.
      'on top': facts(stats: board(62, 14, 4)),
      'pinned back': facts(
        ours: 0,
        theirs: 2,
        scorers: const [],
        wasAhead: false,
        stats: board(38, 4, 14),
      ),
      'all the ball, no chances': facts(stats: board(62, 4, 14)),
      'on the counter': facts(stats: board(38, 14, 4)),
      'nothing between them': facts(stats: board(50, 8, 8)),
      'booked once': facts(ourYellows: 1),
      'their cards': facts(theirYellows: 2, theirReds: 2),
      'a red without a name': facts(
        cards: const [(minute: 50, ours: true, player: null, red: true)],
      ),
      'a bench that changed nothing': facts(
        subs: const [
          (minute: 60, on: 'Jones', off: 'Smith'),
          (minute: 70, on: 'Brown', off: null),
          (minute: 75, on: 'Green', off: 'Bobby'),
        ],
        theirSubs: 1,
      ),
      'a substitute who scored': facts(
        ours: 2,
        scorers: const ['Bobby', 'Brown'],
        subs: const [
          (minute: 60, on: 'Jones', off: 'Smith'),
          (minute: 75, on: 'Brown', off: null),
        ],
        theirSubs: 1,
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
            // **THE LOCALE'S OWN ENTRY, not the English fallback.** This read
            // `catalog[key] ?? englishCatalog[key]` and passed while thirty of
            // the sixty-five keys existed in English alone — so a French
            // write-up opened in French, said four sentences in English, and
            // closed in French again. `t()`'s fallback is right for a string a
            // catalogue has not caught up with; it is wrong for a paragraph
            // COMPOSED out of pools, because the reader gets both languages at
            // once rather than one language that is behind. See
            // `lib/i18n/locale_copy.dart`.
            final raw = catalog[beat.key];
            expect(
              raw,
              isNotNull,
              reason:
                  '${beat.key} is missing from $locale — the write-up would '
                  'fall back to English in the middle of a paragraph',
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
