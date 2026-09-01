/// Which way the men on the 2D pitch are looking.
///
/// **The sprite faces +X and the port thought it faced north.** Kenney's
/// top-down footballer is a shirt oval with the face as a pale crescent on the
/// RIGHT of the head; the heading was assigned as `atan2(x, -y)`, so every
/// figure ran with its face a quarter turn off the way it was going — a man
/// sprinting at goal was looking at the far touchline. Reported from the couch.
///
/// The other half of the same report: they should be watching the BALL most of
/// the time, which is what [Mover.watching] is. Both are checked here on real
/// movers out of a loaded game rather than on a stub, because the convention is
/// shared with the dribble — the ball is knocked a step along the carrier's
/// heading, so a facing fix that missed it would put the ball behind him.
library;

import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_game.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_pitch.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_sequences.dart';

import 'cutaway_ball_and_names_test.dart' show loaded;

/// Where he is looking, as a unit vector — the sprite's own forward.
Vector2 facing(Mover man) => Vector2(math.cos(man.heading), math.sin(man.heading));

/// Him on his own, off the game's brain: a defender the script would otherwise
/// keep handing new targets to.
Future<Mover> aloneOnThePitch(WidgetTester tester) async {
  final game = await loaded(tester, sequence: cutawaySequences.first);
  final man = game.defenders.first;
  man.watching = null;
  man.target = man.position.clone();
  return man;
}

void run(Mover man, {required double seconds}) {
  for (var i = 0; i < seconds * 60; i++) {
    man.update(1 / 60);
  }
}

void main() {
  testWidgets('HE FACES THE WAY HE RUNS', (tester) async {
    final man = await aloneOnThePitch(tester);

    man.target = man.position + Vector2(40, 0);
    run(man, seconds: 1);
    expect(
      man.heading,
      closeTo(0, 0.05),
      reason: 'running right IS the sprite unrotated — a zero heading looked '
          'north, which is where the quarter turn came from',
    );

    // And turning: he agrees with his own run rather than with the target,
    // which after a corner taken at pace is not the same line.
    man.target = man.position - Vector2(0, 40);
    run(man, seconds: 1);
    expect(shortestTurn(man.heading, man.travelAngle).abs(), lessThan(0.02));
    expect(
      math.sin(man.heading),
      lessThan(-0.9),
      reason: 'and running up the pitch faces up it',
    );
  });

  testWidgets('AND HE WATCHES THE BALL WHEN HE IS NOT RUNNING', (tester) async {
    final man = await aloneOnThePitch(tester);
    // Square behind him, so a figure that ignores it is unmistakable.
    final ball = man.position + Vector2(0, 30);
    man.watching = () => ball;

    run(man, seconds: 1);
    expect(
      man.heading,
      closeTo(math.pi / 2, 0.02),
      reason: 'a squad facing the way they happen to have stopped is a squad '
          'ignoring the game',
    );
  });

  testWidgets('and the first frame SNAPS rather than spinning him round', (
    tester,
  ) async {
    final man = await aloneOnThePitch(tester);
    final ball = man.position + Vector2(-30, 0);
    man.watching = () => ball;

    // One frame is far less than the turn rate would need for a half turn: a
    // clip that opened on eleven men swinging round would be the fix showing.
    man.update(1 / 60);
    expect(man.heading.abs(), closeTo(math.pi, 0.01));
  });

  testWidgets('but a ball at his own FEET is not something to stare at', (
    tester,
  ) async {
    final man = await aloneOnThePitch(tester);
    man.watching = () => man.position + Vector2(0, MoverTuning.ballAtFeet - 1);
    man.target = man.position + Vector2(40, 0);
    run(man, seconds: 1);
    expect(
      man.heading,
      closeTo(0, 0.05),
      reason: 'the carrier knocks it along a step AHEAD of his heading, so a '
          'man who turns to look at it turns for ever',
    );
  });

  testWidgets('AND NOBODY LEAVES THE PITCH, in any sequence', (tester) async {
    // The camera shows exactly the 200x120, so off the field is off the screen.
    // A run to the corner flag overshoots — the velocity eases in and out — and
    // men were walking into the surround on the way there. Reported from the
    // couch.
    for (var i = 0; i < cutawaySequences.length; i++) {
      final game = await loaded(
        tester,
        sequence: cutawaySequences[i],
        seed: 17 + i,
      );
      var t = 0.0;
      while (!game.finished && t < 30) {
        game.update(1 / 60);
        t += 1 / 60;
        for (final man in [...game.attackers, ...game.defenders, game.keeper]) {
          expect(
            man.position.x,
            inInclusiveRange(0, pitchWidth),
            reason: '${cutawaySequences[i].id} at ${t}s',
          );
          expect(
            man.position.y,
            inInclusiveRange(0, pitchHeight),
            reason: '${cutawaySequences[i].id} at ${t}s',
          );
        }
      }
    }
  });

  testWidgets('AND NOBODY RUNS SIDEWAYS, in any sequence', (tester) async {
    // The whole cast, every frame of every script. **Measured on a SETTLED
    // run**: a body turns at [MoverTuning.turnRate], so a man given a new
    // target mid-stride is legitimately behind his own velocity for a few
    // frames, and a frozen one — the wall, the free-kick taker — keeps the
    // velocity he was stopped with for ever. What is being pinned is the
    // steady state: once a run has held its line for a beat, the ball may cant
    // him and it may not turn him out of it.
    for (var i = 0; i < cutawaySequences.length; i++) {
      final game = await loaded(
        tester,
        sequence: cutawaySequences[i],
        seed: 3 + i,
      );
      final held = <Mover, int>{};
      final was = <Mover, double>{};
      var t = 0.0;
      while (!game.finished && t < 30) {
        game.update(1 / 60);
        t += 1 / 60;
        for (final man in [...game.attackers, ...game.defenders, game.keeper]) {
          if (man.frozen || man.speed < MoverTuning.baseSpeed * 0.5) {
            held[man] = 0;
            continue;
          }
          final before = was[man];
          was[man] = man.travelAngle;
          if (before == null ||
              shortestTurn(before, man.travelAngle).abs() > 0.05) {
            held[man] = 0;
            continue;
          }
          held[man] = (held[man] ?? 0) + 1;
          if (held[man]! < 24) continue;

          final off = shortestTurn(man.heading, man.travelAngle).abs();
          expect(
            off,
            lessThan(MoverTuning.watchMostOff + 0.05),
            reason: '${cutawaySequences[i].id}: a man on a held line looking '
                '${(off * 180 / math.pi).round()} degrees off his own run',
          );
        }
      }
    }
  });
}
