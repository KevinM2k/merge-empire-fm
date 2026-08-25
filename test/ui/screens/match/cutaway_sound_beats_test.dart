/// **THE SOUND AND THE PICTURE WERE ON DIFFERENT CLOCKS.**
///
/// The match screen played a chance's shot and the crowd's reaction off the
/// MINUTE TICK — `shotKick` at once and the roar 180ms later. But a passage runs
/// run-ups and two or three passes before anybody shoots, so the goal was heard
/// while the ball was still in midfield and the net then bulged in silence.
/// Reported as the sounds and the action not syncing up at all.
///
/// The clip has two beats of its own — struck, and arrived — and this is where
/// they are pinned: that they happen, in that order, and that the strike is far
/// enough into the passage that firing a cue at minute-tick time could never
/// have landed on it.
library;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_game.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_sequences.dart';

/// Play a clip through, recording when each beat landed.
Future<({double? struck, double? verdict, double end})> beatsOf(
  WidgetTester tester,
  CutawayOutcome outcome, {
  CutawaySequence? sequence,
}) async {
  double? struck;
  double? verdict;
  var done = false;
  var t = 0.0;
  final game = CutawayGame(
    sequence: sequence ?? cutawaySequences.first,
    attackingRight: true,
    outcome: outcome,
    seed: 7,
    onDone: (_) => done = true,
  );
  game.struck.addListener(() => struck ??= t);
  game.verdict.addListener(() {
    if (game.verdict.value != null) verdict ??= t;
  });
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: GameWidget(game: game))),
    );
    await game.loaded;
  });
  const step = 1 / 60;
  while (!done && t < 30) {
    game.update(step);
    t += step;
  }
  return (struck: struck, verdict: verdict, end: t);
}

void main() {
  testWidgets('every clip strikes the ball, and says when', (tester) async {
    // A cue with no beat to hang on is a cue that never plays, which would be
    // worse than one that plays early.
    for (final outcome in CutawayOutcome.values) {
      final beats = await beatsOf(tester, outcome);
      expect(
        beats.struck,
        isNotNull,
        reason: '$outcome never reported a strike — its shot cue is silent',
      );
      expect(
        beats.verdict,
        isNotNull,
        reason: '$outcome never reported a verdict — its crowd is silent',
      );
    }
  });

  testWidgets('and the verdict is never before the strike', (tester) async {
    // The reaction has to follow the shot. `_finish` is only reached through the
    // shot's own flight, so this is structural rather than a race — pinned
    // because a cue order that inverted would be heard as a roar before a kick.
    for (final outcome in CutawayOutcome.values) {
      final beats = await beatsOf(tester, outcome);
      expect(
        beats.verdict!,
        greaterThanOrEqualTo(beats.struck!),
        reason: '$outcome delivered its verdict before the ball was struck',
      );
    }
  });

  testWidgets('and the strike is LATE — which is the whole bug', (tester) async {
    // The number that makes the case. A cue fired on the minute tick lands at
    // t=0; the boot does not reach the ball for most of a second. That gap is
    // what a player heard as the sound being out of sync, and it is why the
    // 180ms constant on the no-clip path was never a flight time. Measured:
    // the boot reaches the ball at 0.90s and it crosses the line at 1.12s, so
    // the old cues were 900ms and 940ms early.
    final beats = await beatsOf(tester, CutawayOutcome.goal);
    expect(
      beats.struck!,
      greaterThan(0.4),
      reason: 'the passage shoots almost at once — this test proves nothing, '
          'and the sequences must have changed',
    );
    // And the ball is still in the air after that.
    expect(beats.verdict!, greaterThan(beats.struck!));
  });
}
