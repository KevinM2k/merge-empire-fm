/// The shootout, played out one kick at a time.
///
/// It DECIDES nothing — the engine rolled every kick before the screen opened —
/// so what is pinned here is the reveal: the order, the running total, and the
/// fact that the ending is not visible before it arrives.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/match/shootout_sequence.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

const _fast = Duration(milliseconds: 10);

Map<String, dynamic> _result(List<(String, bool)> kicks) => {
  'penaltyShootout': <String, dynamic>{
    'playerWins': false,
    'homeScore': 1,
    'awayScore': 2,
    'kicks': [
      for (final (team, scored) in kicks)
        <String, dynamic>{'team': team, 'scored': scored},
    ],
  },
};

Future<int> _pumpSequence(
  WidgetTester tester,
  List<ShootoutKick> kicks, {
  Duration step = _fast,
}) async {
  var done = 0;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(kitId: '#4caf50', light: false),
      home: Scaffold(
        body: ShootoutSequence(
          kicks: kicks,
          ourName: 'Testville',
          theirName: 'Rival Rovers',
          onDone: () => done++,
          stepUp: step,
          hold: step,
          settle: step,
        ),
      ),
    ),
  );
  return done;
}

String _runningScore(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('shootout-running-score')))
    .data!;

void main() {
  setUp(() => setLocale('en'));
  tearDown(resetLocale);

  group('reading the kicks off a result', () {
    test('keeps them in the ORDER they were taken', () {
      // `shootoutFrom` splits them into two rows of marks because that is what
      // a summary needs. A sequence needs them interleaved, because the
      // alternation is the drama.
      final kicks = shootoutKicksOf(
        _result([('home', true), ('away', false), ('home', true)]),
      );
      expect(kicks.map((k) => k.ours).toList(), [true, false, true]);
      expect(kicks.map((k) => k.scored).toList(), [true, false, true]);
    });

    test('and a tie that never went to penalties has none', () {
      expect(shootoutKicksOf(<String, dynamic>{}), isEmpty);
      expect(shootoutKicksOf(null), isEmpty);
      expect(shootoutKicksOf({'penaltyShootout': null}), isEmpty);
    });

    test('`home` is always OURS — there is no venue flip', () {
      final kicks = shootoutKicksOf(_result([('home', true), ('away', true)]));
      expect(kicks.first.ours, isTrue);
      expect(kicks.last.ours, isFalse);
    });
  });

  group('the sequence', () {
    testWidgets('a taker steps up BEFORE the outcome is known', (tester) async {
      await _pumpSequence(tester, shootoutKicksOf(_result([('away', true)])));
      await tester.pump();

      // The club is named while the ball is still on the spot, and nothing
      // says what happened yet.
      expect(find.byKey(const ValueKey('shootout-stepping-up')), findsOneWidget);
      expect(find.byKey(const ValueKey('shootout-scored')), findsNothing);
      expect(find.byKey(const ValueKey('shootout-missed')), findsNothing);
      expect(find.textContaining('Rival Rovers'), findsOneWidget);

      await tester.pump(_fast);
      expect(find.byKey(const ValueKey('shootout-scored')), findsOneWidget);
      expect(find.byKey(const ValueKey('shootout-stepping-up')), findsNothing);
    });

    testWidgets('a miss says so', (tester) async {
      await _pumpSequence(tester, shootoutKicksOf(_result([('home', false)])));
      await tester.pump();
      await tester.pump(_fast);
      expect(find.byKey(const ValueKey('shootout-missed')), findsOneWidget);
      expect(find.text(t('cup.shootout.missed')), findsOneWidget);
    });

    testWidgets('THE RUNNING SCORE COUNTS UP, it does not start at the end', (
      tester,
    ) async {
      // Read off the final totals it would give the ending away on the first
      // kick, which is the one thing a shootout must not do.
      await _pumpSequence(
        tester,
        shootoutKicksOf(
          _result([
            ('home', true),
            ('away', true),
            ('home', false),
            ('away', true),
          ]),
        ),
      );
      await tester.pump();
      expect(_runningScore(tester), '0 - 0');

      await tester.pump(_fast);
      expect(_runningScore(tester), '1 - 0', reason: 'ours went in');

      await tester.pump(_fast);
      await tester.pump(_fast);
      expect(_runningScore(tester), '1 - 1', reason: 'theirs answered');

      await tester.pump(_fast);
      await tester.pump(_fast);
      expect(_runningScore(tester), '1 - 1', reason: 'ours was saved');

      await tester.pump(_fast);
      await tester.pump(_fast);
      expect(_runningScore(tester), '1 - 2');
    });

    testWidgets('and it hands the screen back exactly once, at the end', (
      tester,
    ) async {
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(kitId: '#4caf50', light: false),
          home: Scaffold(
            body: ShootoutSequence(
              kicks: shootoutKicksOf(
                _result([('home', true), ('away', false)]),
              ),
              ourName: 'Testville',
              theirName: 'Rival Rovers',
              onDone: () => done++,
              stepUp: _fast,
              hold: _fast,
              settle: _fast,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(done, 0, reason: 'it finished before a ball was kicked');

      for (var i = 0; i < 20 && done == 0; i++) {
        await tester.pump(_fast);
      }
      expect(done, 1);

      // And it stays finished — a second call would settle the match twice.
      for (var i = 0; i < 10; i++) {
        await tester.pump(_fast);
      }
      expect(done, 1);
    });

    testWidgets('sudden death is called, because a miss means more there', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(kitId: '#4caf50', light: false),
          home: Scaffold(
            body: ShootoutSequence(
              kicks: const [(ours: true, scored: true, suddenDeath: true)],
              ourName: 'Testville',
              theirName: 'Rival Rovers',
              onDone: () {},
              stepUp: _fast,
              hold: _fast,
              settle: _fast,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('shootout-sudden-death')),
        findsOneWidget,
      );
    });

    testWidgets('a widget torn down mid-shootout takes its timers with it', (
      tester,
    ) async {
      // The route above this one is a screen a player can leave, and a timer
      // that outlives it calls `setState` on a dead element.
      await _pumpSequence(
        tester,
        shootoutKicksOf(_result([('home', true), ('away', true)])),
        step: const Duration(seconds: 5),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 30));
      expect(tester.takeException(), isNull);
    });
  });
}
