/// Reading a cup tie's shootout off the result.
///
/// **The widget that used to draw one is gone**, and the tests that pumped it
/// went with it — see `shootout.dart`'s own header. The shootout is told kick
/// by kick in the feed now and the board carries the running bracket, so the
/// row of ticks and crosses was a third telling of the same thing. What is
/// left here is the READ, which every one of those surfaces goes through.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/match/shootout.dart';

Map<String, dynamic> result({
  required List<(String team, bool scored)> kicks,
  int homeScore = 4,
  int awayScore = 3,
  bool playerWins = true,
}) => <String, dynamic>{
  'penaltyShootout': <String, dynamic>{
    'playerWins': playerWins,
    'homeScore': homeScore,
    'awayScore': awayScore,
    'kicks': [
      for (final k in kicks)
        <String, dynamic>{
          'team': k.$1,
          'scored': k.$2,
          'suddenDeath': false,
        },
    ],
  },
};

void main() {
  group('reading it off the result', () {
    test('a match that was not a shootout has none', () {
      expect(shootoutFrom(const <String, dynamic>{}), isNull);
      expect(shootoutFrom(null), isNull);
    });

    test('HOME IS ALWAYS OURS — there is no venue flip', () {
      // The same rule the goals follow, and the one thing here that looks like
      // it should be checked and must not be.
      final penalties = shootoutFrom(
        result(
          kicks: [
            ('home', true),
            ('away', false),
            ('home', true),
            ('away', true),
          ],
        ),
      )!;
      expect(penalties.ours.kicks, [true, true]);
      expect(penalties.theirs.kicks, [false, true]);
    });

    test('and the totals come off the shootout, not off the kicks', () {
      // Sudden death can run past the five, and the engine is the thing that
      // counted.
      final penalties = shootoutFrom(
        result(kicks: [('home', true)], homeScore: 6, awayScore: 5),
      )!;
      expect(penalties.ours.score, 6);
      expect(penalties.theirs.score, 5);
      expect(penalties.won, isTrue);
    });

    test('a shootout with no kicks recorded still reads its totals', () {
      // An older save, or a result written before the kicks were carried.
      final penalties = shootoutFrom(const <String, dynamic>{
        'penaltyShootout': <String, dynamic>{
          'playerWins': false,
          'homeScore': 2,
          'awayScore': 3,
        },
      })!;
      expect(penalties.ours.kicks, isEmpty);
      expect(penalties.ours.score, 2);
      expect(penalties.won, isFalse);
    });
  });
}
