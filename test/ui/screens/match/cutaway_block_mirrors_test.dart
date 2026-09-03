/// The defensive block, at the end the side is actually defending.
///
/// **Scripts are written in ATTACK SPACE and `toPitch` mirrors BOTH axes** for a
/// team shooting left — the p axis reverses and the q axis flips with it, so a
/// script's inside-right channel stays the same side of the attacking player's
/// view either way. That is the whole reason one sequence table serves all four
/// combinations of home/away and ours/theirs.
///
/// So a q handed back to `_at` has to BE a q. The line's squeeze read the ball's
/// raw pitch y as though it were one, which is true at one end of the pitch and
/// exactly inverted at the other: at every away fixture the back four shifted to
/// the opposite flank from the ball and the block opened up on the side the move
/// was on.
///
/// The invariant is one sentence and it holds at both ends: a defender's target
/// is on the BALL'S side of his own lane, never the far side of it.
library;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_game.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_pitch.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_sequences.dart';

Future<CutawayGame> kickOff(
  WidgetTester tester, {
  required bool attackingRight,
}) async {
  final game = CutawayGame(
    // A passage that works the ball out to a flank, so the ball spends real
    // time off the middle of the pitch and the squeeze has something to do.
    sequence: cutawaySequences.firstWhere((s) => s.id == 'cross_right_header'),
    attackingRight: attackingRight,
    outcome: CutawayOutcome.goal,
    seed: 11,
    ours: true,
    names: const [],
  );
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: GameWidget(game: game))),
    );
    await game.loaded;
  });
  return game;
}

/// How far each lane-holding defender has been pulled off his lane, signed
/// against the direction the ball is in. Positive is toward the ball.
///
/// The pressing defender is left out: he is told to stand goal-side of the ball
/// itself, which is a different rule and would swamp the one under test.
List<double> squeezeToward(CutawayGame game) {
  final ballY = game.ball.position.y;
  var nearest = 0;
  var best = double.infinity;
  for (var i = 0; i < game.defenders.length; i++) {
    final d = game.defenders[i].position.distanceTo(game.ball.position);
    if (d < best) {
      best = d;
      nearest = i;
    }
  }
  return [
    for (var i = 0; i < game.defenders.length; i++)
      if (i != nearest)
        () {
          final laneY = toPitch(
            (p: 0.5, q: defensiveLanes[i]),
            attackingRight: game.attackingRight,
          ).y;
          final off = game.defenders[i].target.y - laneY;
          return ballY > laneY ? off : -off;
        }(),
  ];
}

void main() {
  for (final attackingRight in [true, false]) {
    testWidgets(
      'THE LINE SHIFTS TOWARD THE BALL, attacking '
      '${attackingRight ? 'right' : 'left'}',
      (tester) async {
        final game = await kickOff(tester, attackingRight: attackingRight);
        // Far enough in for the ball to be off the middle and for the line to
        // have been given a target from it.
        var sampled = 0;
        for (var frame = 0; frame < 240; frame++) {
          game.update(1 / 60);
          // Only the frames where the ball is genuinely off centre — a ball on
          // the halfway line squeezes nobody and would pass either way.
          if ((game.ball.position.y - pitchHeight / 2).abs() < 12) continue;
          for (final toward in squeezeToward(game)) {
            sampled++;
            expect(
              toward,
              greaterThanOrEqualTo(-0.001),
              reason: 'the block shifted AWAY from the ball',
            );
          }
        }
        expect(
          sampled,
          greaterThan(0),
          reason: 'the ball never left the middle, so nothing was tested',
        );
      },
    );
  }
}
