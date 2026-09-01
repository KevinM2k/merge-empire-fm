/// A cup tie decided on penalties.
///
/// **The engine has always simulated the shootout kick by kick** and only its
/// three totals reached the screen — so a drawn tie arrived as a bare one-goal
/// defeat the player never saw decided. That is the JS's own warning about the
/// field, word for word: "a 2-2 tie surfacing as lost 2-3 with no penalties
/// shown".
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/match/shootout_row.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

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

Future<void> pumpRow(WidgetTester tester, Map<String, dynamic> from) async {
  final penalties = shootoutFrom(from)!;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(kitId: '#4caf50', light: false),
      home: Scaffold(
        body: Center(
          child: ShootoutRow(
            ours: penalties.ours,
            theirs: penalties.theirs,
            won: penalties.won,
          ),
        ),
      ),
    ),
  );
}

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

  group('on screen', () {
    testWidgets('THE TOTALS ARE THE ANSWER, the marks are how', (tester) async {
      await pumpRow(
        tester,
        result(
          kicks: [
            ('home', true),
            ('away', false),
            ('home', true),
          ],
          homeScore: 5,
          awayScore: 4,
        ),
      );
      expect(find.text('5 - 4'), findsOneWidget);
      expect(find.byKey(const ValueKey('shootout-marks-ours')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('shootout-marks-theirs')),
        findsOneWidget,
      );
    });

    testWidgets('a scored kick and a missed one are different marks', (
      tester,
    ) async {
      await pumpRow(
        tester,
        result(kicks: [('home', true), ('home', false)]),
      );
      expect(find.byIcon(Icons.circle), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('IT IS DRAWN, NOT WRITTEN', (tester) async {
      // The JS's reveal is hardcoded English with no `t()` behind any of it,
      // and the catalogues here are generated from that same repo — so there is
      // no translated copy to port and none can be minted. Marks say the same
      // thing in ten languages.
      await pumpRow(tester, result(kicks: [('home', true)]));
      expect(find.byType(Text), findsOneWidget, reason: 'only the score');
    });
  });
}
