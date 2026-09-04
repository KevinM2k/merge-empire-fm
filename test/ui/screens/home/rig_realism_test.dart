/// The rig's second pass at looking alive: hair that moves strand by strand,
/// a torso that pitches with the stride, shoulders that turn with the arms, a
/// head that bobs less than the hips, ankles that roll, a kick the whole body
/// takes part in, and a two-handed carry.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_art.g.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/ui/screens/home/gesture_poses.dart';
import 'package:merge_empire_fc/ui/screens/home/hair_strands.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_ball.dart';

void main() {
  group('HAIR IS SHEARED FROM THE CROWN, not turned', () {
    test('the roots hold and the tips move most', () {
      for (final front in [true, false]) {
        expect(hairShearAt(0, 40, swing: 5, front: front), 0, reason: 'root');
        var last = 0.0;
        for (var i = 1; i <= 10; i++) {
          final d = hairShearAt(i / 10, 40, swing: 5, front: front).abs();
          expect(d, greaterThan(last), reason: 'u=${i / 10} front=$front');
          last = d;
        }
      }
    });

    test('a fringe flutters where a tail swings', () {
      expect(
        hairShearAt(1, 40, swing: 5, front: true).abs(),
        lessThan(hairShearAt(1, 40, swing: 5, front: false).abs() / 2),
      );
    });

    test('and a swing the other way is the mirror', () {
      expect(
        hairShearAt(0.7, 40, swing: -4, front: false),
        closeTo(-hairShearAt(0.7, 40, swing: 4, front: false), 1e-9),
      );
    });

    test('a still figure displaces nothing', () {
      final mass = HairMass.of(managerHair['pony']!.$1, front: false);
      for (final shape in mass.shapes) {
        for (final p in shape.points) {
          expect(hairDisplace(p, mass, HairMotion.still), p);
        }
      }
    });

    test('a point ON the skull is held whatever its depth', () {
      final mass = HairMass.of(managerHair['flow']!.$1, front: false);
      const motion = HairMotion(swing: 5, phase: 0.3, amount: 1);
      // The skull's own centre, well below the crown: depth says move, the
      // skull says no.
      expect(hairDisplace(skullInArt, mass, motion), skullInArt);
      // A point twenty units behind it is free.
      final free = skullInArt.translate(-20, 20);
      expect(hairDisplace(free, mass, motion), isNot(free));
    });

    test('every style parses to a mass with strands where it is solid', () {
      for (final id in hairStyleIds) {
        final (back, front) = managerHair[id]!;
        for (final (svg, isFront) in [(back, false), (front, true)]) {
          if (svg.isEmpty) continue;
          final mass = HairMass.of(svg, front: isFront);
          expect(mass.shapes, isNotEmpty, reason: '$id has no shapes');
          final solid = mass.shapes.any((s) => s.colour.a >= 0.6);
          if (solid) {
            expect(mass.strands, isNotEmpty, reason: '$id has no strands');
          }
          // Every strand lies inside the mass's own box.
          final box = mass.bounds.inflate(0.5);
          for (final strand in mass.strands) {
            for (final p in strand.spine) {
              expect(box.contains(p), isTrue, reason: '$id strand escapes');
            }
            expect(strand.widths.length, strand.spine.length);
          }
        }
      }
      // A buzz cut is a tinted scalp: shapes, no strands.
      final buzz = HairMass.of(managerHair['buzz']!.$2, front: true);
      expect(buzz.strands, isEmpty);
    });

    test('strands are deterministic and the parse is memoised', () {
      final a = HairMass.of(managerHair['dreads']!.$1, front: false);
      final b = HairMass.of(managerHair['dreads']!.$1, front: false);
      expect(identical(a, b), isTrue);
    });

    test('no two strands share a phase, which is the point of them', () {
      final mass = HairMass.of(managerHair['flow']!.$1, front: false);
      final phases = mass.strands.map((s) => s.phase).toSet();
      expect(phases.length, mass.strands.length);
    });
  });

  group('THE BODY WALKS TOO', () {
    test('the torso pitches forward and rocks twice a stride', () {
      for (var i = 0; i <= 20; i++) {
        final p = walkBodyPitch(i / 20);
        expect(p, greaterThan(0), reason: 'leans back at ${i / 20}');
        expect(p, lessThan(4), reason: 'a lean, not a bow');
      }
      expect(walkBodyPitch(0.125), greaterThan(walkBodyPitch(0.375)));
      expect(walkBodyPitch(0), closeTo(walkBodyPitch(0.5), 1e-9));
    });

    test('the shoulders turn with the arms and against each other', () {
      // The near arm is forward at t=0.5; the near shoulder goes with it.
      expect(walkShoulderShift(0.5), greaterThan(0));
      expect(walkShoulderShift(0), lessThan(0));
      expect(walkShoulderShift(0.25).abs(), lessThan(0.01));
      for (var i = 0; i <= 8; i++) {
        expect(walkShoulderShift(i / 8).abs(), lessThan(2));
      }
    });

    test('the head bobs less than the hips', () {
      expect(headBobDamping, greaterThan(0));
      expect(headBobDamping, lessThan(0.5));
    });

    test('the ankle lands heel first and leaves toe last', () {
      // Heel strike at the start of the stance: toes up. Push-off past mid
      // stance: toes down. Small throughout — the JS's float is accepted, and
      // a big roll would push it past the measured limit.
      expect(walkerAnkleAngle(0), lessThan(0));
      expect(walkerAnkleAngle(0.52), greaterThan(0));
      for (var i = 0; i <= 40; i++) {
        expect(walkerAnkleAngle(i / 40).abs(), lessThanOrEqualTo(12));
      }
      expect(
        walkerAnkleAngle(0.3, near: false),
        closeTo(walkerAnkleAngle(0.8), 1e-9),
      );
      // And the boot's world angle carries it.
      expect(
        walkerBootAngle(0.52) - walkerThighAngle(0.52) - walkerShinAngle(0.52),
        closeTo(walkerAnkleAngle(0.52), 1e-9),
      );
    });
  });

  group('THE KICK IS THE WHOLE MAN', () {
    test('he looks at the ball and leans off the strike', () {
      final windup = gesturePose('kick', 0.3);
      final contact = gesturePose('kick', 0.6);
      expect(windup.head, greaterThan(4), reason: 'eyes on the ball');
      expect(contact.body, lessThan(-3), reason: 'leaning back');
      // The legs cancel the lean so the plant foot stays put.
      expect(contact.legs, closeTo(-contact.body!, 1e-9));
      expect(windup.legs, closeTo(-windup.body!, 1e-9));
    });

    test('the arms counter-swing', () {
      final windup = gesturePose('kick', 0.3);
      final contact = gesturePose('kick', 0.6);
      expect(windup.armNear, greaterThan(armNearRest), reason: 'near back');
      expect(contact.armNear, lessThan(armNearRest), reason: 'near forward');
      expect(windup.armFar, lessThan(armFarRest), reason: 'far forward');
      expect(contact.armFar, greaterThan(armFarRest), reason: 'far back');
    });

    test('and he is upright again at the end', () {
      final rest = gesturePose('kick', 1);
      expect(rest.body, closeTo(0, 1e-9));
      expect(rest.head, closeTo(0, 1e-9));
      expect(rest.bodyLift, closeTo(0, 1e-9));
    });
  });

  test('THE HAIR PAINTER ONLY REPAINTS WHEN THE MOTION CHANGES', () {
    final mass = HairMass.of(managerHair['pony']!.$1, front: false);
    const a = HairMotion(swing: 2, phase: 0.1, amount: 1);
    const b = HairMotion(swing: 2, phase: 0.1, amount: 1);
    const c = HairMotion(swing: 2.5, phase: 0.1, amount: 1);
    expect(
      HairPainter(mass: mass, motion: a).shouldRepaint(
        HairPainter(mass: mass, motion: b),
      ),
      isFalse,
    );
    expect(
      HairPainter(mass: mass, motion: a).shouldRepaint(
        HairPainter(mass: mass, motion: c),
      ),
      isTrue,
    );
  });

  testWidgets('a still figure caches no hair layer; a moving one does', (
    tester,
  ) async {
    Future<int> boundaries(bool reduceMotion) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: Scaffold(
              body: SizedBox(
                width: 120,
                height: 170,
                child: ManagerWalker(
                  kit: const Color(0xFF4CAF50),
                  skin: const Color(0xFFEEBB8C),
                  hair: const Color(0xFF3A2A1C),
                  walking: !reduceMotion,
                  look: const {'style': 'pony', 'outfit': 'kit'},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return find
          .descendant(
            of: find.byType(ManagerWalker),
            matching: find.byType(RepaintBoundary),
          )
          .evaluate()
          .length;
    }

    expect(await boundaries(true), 0);
    expect(await boundaries(false), greaterThanOrEqualTo(3));
  });

  test('the shear at the tip is bounded by the swing', () {
    // A rigid turn of θ moves a point L below the pivot by L·tan θ; the shear
    // never exceeds that, so hair can go no further than the slab it replaces.
    for (final swing in [1.0, 3.0, 5.0]) {
      const drop = 48.0;
      final rigid = drop * math.tan(swing * math.pi / 180);
      expect(
        hairShearAt(1, drop, swing: swing, front: false).abs(),
        lessThanOrEqualTo(rigid + 1e-9),
      );
    }
  });

  group('A GESTURE CAN TURN HIM', () {
    test('folded arms face the camera, applause faces the stand', () {
      expect(gestureTurnAt('armsfolded', 0.5), greaterThan(0.5));
      expect(gestureTurnAt('applaud', 0.5), lessThan(0));
      expect(gestureTurnAt('fistpump', 0.5), 0, reason: 'not every gesture turns');
    });

    test('and it ramps in from square and back to square', () {
      expect(gestureTurnAt('armsfolded', 0), 0);
      expect(gestureTurnAt('armsfolded', 1), 0);
      expect(gestureTurnAt('armsfolded', 0.08).abs(), lessThan(gestureTurnAt('armsfolded', 0.5).abs()));
      for (final id in gestureTurn.keys) {
        expect(hasGesturePose(id), isTrue, reason: '$id turns but has no pose');
        expect(gestureTurn[id]!.abs(), lessThanOrEqualTo(1));
      }
    });
  });

  testWidgets('HE GLANCES UNDER AN IDLE TOO, which is the home screen', (
    tester,
  ) async {
    // The home screen hands him an idle for breath and weight; the glances
    // were gated on there being none, so he only looked about in the
    // customiser. The head painter's angle is read off the tilt widget.
    const idle = (
      armNear: null, armFar: null, foreNear: null, foreFar: null,
      head: 0.0, body: null, bodyLift: 0.0, legs: null,
      kickThigh: null, kickShin: null, finger: 0.0,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: false),
          child: Scaffold(
            body: SizedBox(
              width: 120,
              height: 170,
              child: ManagerWalker(
                kit: Color(0xFF4CAF50),
                skin: Color(0xFFEEBB8C),
                hair: Color(0xFF3A2A1C),
                idle: idle,
                look: {'style': 'crop', 'outfit': 'kit'},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    double tilt() => tester
        .widgetList<Transform>(find.byType(Transform))
        .map((w) => w.transform)
        .fold<double>(0, (a, m) => a + m.getRotation().row0.y.abs());
    final square = tilt();
    // Into the middle of the first look-up.
    await tester.pump(const Duration(milliseconds: 4700));
    expect(tilt(), isNot(closeTo(square, 1e-6)), reason: 'no glance under an idle');
  });

  group('HE LOOKS AT THE BALL', () {
    test('when it is close, at his boot or coming up — not once it is his', () {
      expect(ballWatched(BallPhase.incoming, 200), isFalse);
      expect(ballWatched(BallPhase.incoming, ballWatchDistance), isTrue);
      expect(ballWatched(BallPhase.trap, 5), isTrue);
      expect(ballWatched(BallPhase.pickup, 0), isTrue);
      expect(ballWatched(BallPhase.hold, -4), isFalse);
      expect(ballWatched(BallPhase.out, 40), isFalse);
      expect(ballWatched(BallPhase.past, -30), isFalse);
      expect(ballWatched(BallPhase.idle, 0), isFalse);
      expect(ballHeadDrop, greaterThan(0), reason: 'down, not up');
      expect(ballGaze.dy, greaterThan(0));
    });

    testWidgets('and the head drops when told to', (tester) async {
      Future<double> tiltWith(bool watching) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: false),
              child: Scaffold(
                body: SizedBox(
                  width: 120,
                  height: 170,
                  child: ManagerWalker(
                    kit: const Color(0xFF4CAF50),
                    skin: const Color(0xFFEEBB8C),
                    hair: const Color(0xFF3A2A1C),
                    watchingBall: watching,
                    look: const {'style': 'crop', 'outfit': 'kit'},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        return tester
            .widgetList<Transform>(find.byType(Transform))
            .map((w) => w.transform)
            .fold<double>(0, (a, m) => a + m.getRotation().row0.y.abs());
      }

      final square = await tiltWith(false);
      final watching = await tiltWith(true);
      expect(watching, greaterThan(square + 0.05));
    });
  });
}
