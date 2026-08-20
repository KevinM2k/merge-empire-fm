/// The end of a chance.
///
/// **A goal used to end on the frame the ball crossed the line**, which is the
/// one moment in a match worth watching, cut the instant it happened. The clip
/// has an OUTRO now: the word goes up, the scorer runs to the corner with two of
/// them chasing, and only then does the stage go back to an empty pitch. What is
/// checked here is that the outro exists, that it is longer for a goal than for a
/// miss, and that nobody is still playing football during it.
library;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_game.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_pitch.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_sequences.dart';

/// Run a whole clip and report what happened, at a fixed step.
///
/// Mounted through a `GameWidget` and inside `runAsync`, which the load test
/// explains: the camera needs a laid-out canvas before `onLoad` can size it, and
/// decoding a PNG is real I/O that a widget test's fake clock never lets finish.
Future<({CutawayOutcome? done, double seconds, CutawayGame game})> playOut(
  WidgetTester tester,
  CutawayOutcome outcome, {
  bool attackingRight = true,
  double cap = 30,
}) async {
  CutawayOutcome? done;
  final game = CutawayGame(
    sequence: cutawaySequences.first,
    attackingRight: attackingRight,
    outcome: outcome,
    seed: 7,
    onDone: (o) => done = o,
  );
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameWidget(game: game)),
      ),
    );
    await game.loaded;
  });
  const step = 1 / 60;
  var t = 0.0;
  while (done == null && t < cap) {
    game.update(step);
    t += step;
  }
  return (done: done, seconds: t, game: game);
}

void main() {
  testWidgets('a chance still ends, whatever the outcome', (tester) async {
    // A clip that never calls back leaves the match screen showing a full pitch
    // for the rest of the game — the fault a test has caught here before.
    for (final outcome in CutawayOutcome.values) {
      final run = await playOut(tester, outcome);
      expect(run.done, outcome, reason: '$outcome never finished');
    }
  });

  testWidgets('and a GOAL takes longer to end than a miss', (tester) async {
    final goal = await playOut(tester, CutawayOutcome.goal);
    final wide = await playOut(tester, CutawayOutcome.wide);
    expect(
      goal.seconds,
      greaterThan(wide.seconds + 1),
      reason: 'the celebration is not being played',
    );
  });

  testWidgets('the verdict is up before the clip ends', (tester) async {
    // The word is the whole point of the cutaway landing — a chance with no word
    // on it is one the player has to work out from where the ball stopped.
    final run = await playOut(tester, CutawayOutcome.goal);
    expect(run.game.verdict.value, CutawayOutcome.goal);
  });

  testWidgets('the scorer ends up at a CORNER, not in the goalmouth', (
    tester,
  ) async {
    final run = await playOut(
      tester,
      CutawayOutcome.goal,
      attackingRight: true,
    );
    final scorer = run.game.attackers[run.game.carrier];
    // The attacking end, and one of its two corners.
    expect(scorer.position.x, greaterThan(pitchWidth * 0.8));
    final toTop = scorer.position.y;
    final toBottom = pitchHeight - scorer.position.y;
    expect(
      toTop < pitchHeight * 0.2 || toBottom < pitchHeight * 0.2,
      isTrue,
      reason: 'he stopped in the middle: ${scorer.position}',
    );
  });

  testWidgets(
    'and it mirrors, so an attack the other way runs to the other end',
    (tester) async {
      final run = await playOut(
        tester,
        CutawayOutcome.goal,
        attackingRight: false,
      );
      final scorer = run.game.attackers[run.game.carrier];
      expect(scorer.position.x, lessThan(pitchWidth * 0.2));
    },
  );

  testWidgets('nobody is still playing when it is over', (tester) async {
    // A defence that kept tracking through a celebration is the one thing that
    // would make it read as still in play.
    final run = await playOut(tester, CutawayOutcome.goal);
    for (final m in [
      ...run.game.attackers,
      ...run.game.defenders,
      run.game.keeper,
    ]) {
      expect(m.frozen, isTrue);
    }
  });

  testWidgets('a miss freezes everyone the moment the ball arrives', (
    tester,
  ) async {
    // Nothing to celebrate, so nobody keeps running — but the word still needs a
    // beat on screen, which is what the shorter outro is.
    final run = await playOut(tester, CutawayOutcome.saved);
    expect(run.game.keeper.frozen, isTrue);
    expect(run.game.verdict.value, CutawayOutcome.saved);
  });
}
