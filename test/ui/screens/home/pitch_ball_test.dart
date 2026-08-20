/// The stray ball, against the JS frame by frame.
///
/// `test/fixtures/pitch_ball.json` is `tool/dump_pitch_ball_reference.mjs`
/// driving the real `PitchBallSim` with a fake DOM and a fake clock — two
/// forty-second runs, one neutral and one crushed, because what he does with a
/// ball is a mood-weighted roll and a neutral manager almost never lets one go
/// past him.
///
/// **The randomness is in the fixture**, as a list both runtimes read in order.
/// That pins the draw ORDER as well as the formulae, which matters more here:
/// an extra draw anywhere shifts every later number, and that is the shape of
/// four separate bugs this port has already had.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_ball.dart';

/// The fixture's own draws, in order. Anything past the end reads 0, which is
/// what the JS stub does — and if a run ever gets there the traces will have
/// diverged long before.
class _Reel implements math.Random {
  _Reel(this.draws);

  final List<double> draws;
  int at = 0;

  @override
  double nextDouble() => at < draws.length ? draws[at++] : 0;

  @override
  bool nextBool() => nextDouble() < 0.5;

  @override
  int nextInt(int max) => (nextDouble() * max).floor();
}

Mood _moodOf(String id) => switch (id) {
  'elated' => Mood.elated,
  'pleased' => Mood.pleased,
  'glum' => Mood.glum,
  'crushed' => Mood.crushed,
  _ => Mood.neutral,
};

BallPhase _phaseOf(String id) => switch (id) {
  'in' => BallPhase.incoming,
  'trap' => BallPhase.trap,
  'pickup' => BallPhase.pickup,
  'hold' => BallPhase.hold,
  'out' => BallPhase.out,
  'past' => BallPhase.past,
  _ => BallPhase.idle,
};

void main() {
  final raw = File('test/fixtures/pitch_ball.json').readAsStringSync();
  final fixture = jsonDecode(raw) as Map<String, dynamic>;
  final playerSpeed = (fixture['playerSpeed'] as num).toDouble();
  final edgeX = (fixture['edgeX'] as num).toDouble();
  final exitX = (fixture['exitX'] as num).toDouble();
  final frameMs = (fixture['frameMs'] as num).toDouble();

  group('against the JS, frame by frame', () {
    for (final run in fixture['runs'] as List) {
      final r = run as Map<String, dynamic>;
      final mood = r['mood'] as String;

      test('a $mood manager plays every ball the same way', () {
        final reel = _Reel([
          for (final v in r['draws'] as List) (v as num).toDouble(),
        ]);
        final cues = <({int frame, BallCue cue})>[];
        var frame = 0;
        final sim = PitchBallSim(
          getMood: () => _moodOf(mood),
          onCue: (cue) => cues.add((frame: frame, cue: cue)),
          random: reel,
        );
        // The JS's unlaid-out fallbacks, so this compares the PHYSICS rather
        // than two different ways of measuring a viewport — the port derives
        // both edges exactly where the JS estimates one and measures the other.
        sim.pinFrame(ahead: edgeX, behind: -exitX);

        final trace = r['trace'] as List;
        // **The JS's clock, not a constant step.** It accumulates milliseconds
        // and divides the difference, and the rounding that falls out of that is
        // load-bearing: 0.8s of countdown against 48 frames of 1000/60 lands a
        // hair ABOVE zero, so the first ball arrives on the 49th frame rather
        // than the 48th. A constant `1/60` arrives a frame early and every later
        // number is then compared against the wrong one.
        var now = 0.0;
        var last = 0.0;
        for (var i = 0; i < trace.length; i++) {
          frame = i + 1;
          now += frameMs;
          // A CONSTANT pace, which is what the JS assumes throughout. The port
          // drives the ball off the world's real travel instead — see the note
          // at the top of `pitch_ball.dart` — and that is tested separately;
          // here the ground is the JS's.
          //
          // The FIRST frame is a no-op, matching the JS: `_arm` stamps `_last`
          // and calls the loop with the same timestamp, so the opening callback
          // has no elapsed time and returns before any physics.
          final step = i == 0 ? 0.0 : (now - last) / 1000;
          last = now;
          sim.step(step, walkSpeed: playerSpeed, nominalWalkSpeed: playerSpeed);
          final want = trace[i] as Map<String, dynamic>;
          double at(String key) => (want[key] as num).toDouble();
          // A tight tolerance on purpose: this is the same arithmetic in two
          // languages, so anything past floating-point noise is a real
          // difference in the port.
          expect(
            sim.phase,
            _phaseOf(want['phase'] as String),
            reason: 'phase at frame $i',
          );
          expect(sim.x, closeTo(at('x'), 1e-4), reason: 'x at frame $i');
          expect(sim.y, closeTo(at('y'), 1e-4), reason: 'y at frame $i');
          expect(sim.vx, closeTo(at('vx'), 1e-4), reason: 'vx at frame $i');
          expect(sim.vy, closeTo(at('vy'), 1e-4), reason: 'vy at frame $i');
          expect(sim.rot, closeTo(at('rot'), 1e-4), reason: 'rot at frame $i');
          expect(
            sim.grounded,
            want['grounded'],
            reason: 'grounded at frame $i',
          );
          expect(sim.play, want['play'], reason: 'play at frame $i');
        }

        // And he told the screen the same things at the same moments — the
        // carry pose and the snub both hang off these.
        expect(
          [for (final c in cues) c.cue.name],
          [for (final c in r['cues'] as List) (c as Map)['cue']],
        );
        expect(
          [for (final c in cues) c.frame],
          [for (final c in r['cues'] as List) (c as Map)['frame']],
        );
      });
    }
  });

  group('the two things that strand a ball', () {
    // Both were invisible in review and awkward to catch by eye: they present
    // as "the ball just sits there sometimes".
    test('A BALL THAT ARRIVES BOUNCING COMES TO REST, and he plays it', () {
      // The regression the JS's own test guards. A decaying bounce never
      // satisfies `|vy| < REST_SNAP` on its own: the discrete recursion has a
      // fixed point at about 0.34·g·dt, below the point where a bounce can
      // survive a frame and above the snap threshold. So it bounces for ever at
      // an apex of a hundredth of a unit — visually parked on the grass, and
      // never grounded. The trap is gated on grounded, so the ball reached his
      // boot and was never trapped, never played and never retired.
      final sim = PitchBallSim(
        getMood: () => Mood.neutral,
        onCue: (_) {},
        random: math.Random(7),
      );
      sim.y = 0.02;
      sim.vy = -8.5; // squarely inside the fixed point the old test missed
      sim.grounded = false;
      sim.phase = BallPhase.incoming;
      for (var i = 0; i < 60; i++) {
        sim.step(1 / 60, walkSpeed: 62, nominalWalkSpeed: 62);
        if (sim.grounded) break;
      }
      expect(sim.grounded, isTrue, reason: 'it is still bouncing');
    });

    test('and a wedged phase is aged out rather than left', () {
      // Every phase ends on a position or a timer, and a ball that satisfies
      // neither would sit there for the rest of the session. The guard is a
      // backstop rather than a pacing control, so it is generous — but a phase
      // that can only be left on a position test is worth a timeout regardless.
      final sim = PitchBallSim(
        getMood: () => Mood.neutral,
        onCue: (_) {},
        random: math.Random(7),
      );
      sim.phase = BallPhase.incoming;
      sim.play = 'pass';
      // Airborne and going nowhere, so the trap's `grounded && x <= trapX` can
      // never fire.
      sim.x = 120;
      sim.vx = 0;
      sim.grounded = false;
      sim.y = 40;
      for (var i = 0; i < 60 * 14; i++) {
        sim.step(1 / 60, walkSpeed: 0, nominalWalkSpeed: 62);
        if (sim.phase != BallPhase.incoming) break;
      }
      expect(
        sim.phase,
        isNot(BallPhase.incoming),
        reason: 'it never got unstuck',
      );
    });
  });

  group('the rules that make him a manager rather than a striker', () {
    PitchBallSim fresh({int seed = 3}) => PitchBallSim(
      getMood: () => Mood.neutral,
      onCue: (_) {},
      random: math.Random(seed),
    );

    test('a settled ball lies STILL on the grass it is lying on', () {
      // The port's one departure from the JS, and the reason for it: the world
      // here moves at the supporting boot's own varying rate, so a ball driven
      // by a constant pace would slide against the very grass it is resting on.
      // Its speed over the turf has to be zero whatever the turf is doing.
      final sim = fresh();
      sim.phase = BallPhase.incoming;
      sim.play = 'pass';
      sim.x = 90;
      sim.grounded = true;
      // Rolling to a stop against a ground that is speeding up and slowing down
      // exactly as his stride does.
      for (var i = 0; i < 240; i++) {
        final speed = 40 + 40 * math.sin(i / 12);
        sim.step(1 / 60, walkSpeed: speed, nominalWalkSpeed: 62);
        if (sim.phase != BallPhase.incoming) break;
        // Once friction has taken it, its speed over the turf must be nothing —
        // the ball is not moving; the world is coming to it.
        if (i > 120) {
          expect(
            sim.vx + speed,
            closeTo(0, 1e-9),
            reason: 'it is sliding over the grass at frame $i',
          );
        }
      }
    });

    test('and it stops SPINNING when he stops walking', () {
      // A ball at his boot only ever turns because the turf is moving under it.
      final sim = fresh();
      sim.phase = BallPhase.trap;
      sim.timer = 99;
      sim.x = 5;
      sim.vx = 0;
      final before = sim.rot;
      for (var i = 0; i < 30; i++) {
        sim.step(1 / 60, walkSpeed: 0, nominalWalkSpeed: 62);
      }
      expect(sim.rot, before);
    });

    test('a pass is hit hard enough to actually clear the frame', () {
      // Solved rather than tuned: he keeps walking after it, so the gap that has
      // to open is the ball's travel MINUS his. The plain sqrt(2fd) under-hits
      // by about 40% — the ball stalls in front of him and he walks back onto
      // it, which is the dribble again.
      for (final width in [150.0, 230.0, 420.0]) {
        final sim = fresh();
        sim.pinFrame(ahead: width, behind: width);
        sim.phase = BallPhase.trap;
        sim.play = 'pass';
        sim.timer = 0;
        sim.x = 5;
        var cleared = false;
        for (var i = 0; i < 60 * 12; i++) {
          sim.step(1 / 60, walkSpeed: 62, nominalWalkSpeed: 62);
          if (sim.phase == BallPhase.idle) {
            cleared = true;
            break;
          }
        }
        expect(cleared, isTrue, reason: 'a pass stalled on a $width frame');
      }
    });

    test('WIND ONLY TOUCHES A BALL IN THE AIR', () {
      // Not a simplification. A grounded ball has to keep closing on him at
      // exactly his walking pace, which is what makes him walk onto it instead
      // of it drifting to meet him; any standing acceleration on a settled ball
      // breaks that and it slides over the grass like it is on ice.
      final rolling = fresh()
        ..phase = BallPhase.out
        ..x = 60
        ..vx = 0
        ..grounded = true
        ..wind = 400;
      final calm = fresh()
        ..phase = BallPhase.out
        ..x = 60
        ..vx = 0
        ..grounded = true;
      for (var i = 0; i < 30; i++) {
        rolling.step(1 / 60, walkSpeed: 62, nominalWalkSpeed: 62);
        calm.step(1 / 60, walkSpeed: 62, nominalWalkSpeed: 62);
      }
      expect(
        rolling.x,
        calm.x,
        reason: 'the wind blew a ball along the ground',
      );

      final flying = fresh()
        ..phase = BallPhase.out
        ..x = 60
        ..y = 40
        ..vx = 100
        ..grounded = false
        ..wind = 400;
      final still = fresh()
        ..phase = BallPhase.out
        ..x = 60
        ..y = 40
        ..vx = 100
        ..grounded = false;
      for (var i = 0; i < 10; i++) {
        flying.step(1 / 60, walkSpeed: 62, nominalWalkSpeed: 62);
        still.step(1 / 60, walkSpeed: 62, nominalWalkSpeed: 62);
      }
      expect(
        flying.x,
        greaterThan(still.x),
        reason: 'a gale did nothing to a ball in flight',
      );
    });

    test('mid-bow the ball waits at his boot rather than being played', () {
      // Only HIS half of the interaction is suspended: a ball still rolling in
      // still rolls in and still traps, it just sits there until he
      // straightens up.
      final sim = fresh()
        ..phase = BallPhase.trap
        ..play = 'pass'
        ..timer = 0.1
        ..x = 5
        ..halted = true;
      for (var i = 0; i < 60; i++) {
        sim.step(1 / 60, walkSpeed: 0, nominalWalkSpeed: 62);
      }
      expect(sim.phase, BallPhase.trap, reason: 'he played it mid-bow');
      sim.halted = false;
      for (var i = 0; i < 20; i++) {
        sim.step(1 / 60, walkSpeed: 62, nominalWalkSpeed: 62);
      }
      expect(sim.phase, BallPhase.out, reason: 'and then he never played it');
    });
  });
}
