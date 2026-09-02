import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/match_report.dart';

/// The report is a sequence of BEATS, so what is tested is which sentences a
/// match earns — not the prose, which is a catalogue's business.
void main() {
  ReportFacts facts({
    int ours = 1,
    int theirs = 0,
    List<String> scorers = const ['Bobby'],
    bool wasBehind = false,
    bool wasAhead = true,
    int ourYellows = 0,
    int ourReds = 0,
    int theirYellows = 0,
    int theirReds = 0,
    int? position = 4,
    int? points = 20,
    int? posDelta = 0,
    String? nextOpponent = 'Ayton',
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
    ourYellows: ourYellows,
    ourReds: ourReds,
    theirYellows: theirYellows,
    theirReds: theirReds,
    position: position,
    points: points,
    posDelta: posDelta,
    nextOpponent: nextOpponent,
    nextIsHome: false,
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

  group('THE REFEREE GETS ONE SENTENCE AT MOST', () {
    test('and a red of ours outranks everything else', () {
      final keys = keysOf(facts(ourReds: 1, ourYellows: 3, theirReds: 1));
      expect(keys, contains('report.cards.our_red'));
      expect(keys, isNot(contains('report.cards.our_yellows')));
      expect(keys, isNot(contains('report.cards.their_red')));
    });

    test('a single caution is not worth saying', () {
      expect(
        keysOf(facts(ourYellows: 1)).where((k) => k.startsWith('report.cards')),
        isEmpty,
      );
    });

    test('and theirs is mentioned only when ours had nothing', () {
      expect(keysOf(facts(theirReds: 1)), contains('report.cards.their_red'));
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
}
