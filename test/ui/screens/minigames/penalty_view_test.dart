/// The penalty scene's FIGURES, as geometry.
///
/// Everything here is pure arithmetic on the projection, which is exactly where
/// the two faults that were reported from the couch lived: a keeper whose limbs
/// stretched like one of the Fantastic Four, and gloves drawn nowhere near the
/// ball they had just saved. Neither is visible in a widget test that only asks
/// whether the scene painted.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/penalty_physics.dart';
import 'package:merge_empire_fc/ui/screens/minigames/penalty_view.dart';

void main() {
  const view = Size(400, 800);

  /// Every pose worth checking: standing, part way, and full stretch each way,
  /// low and high.
  final poses = <KeeperPose>[
    for (final side in [-0.98, -0.5, 0.0, 0.5, 0.98])
      for (final dive in [0.0, 0.35, 0.7, 1.0])
        for (final height in [0.1, 0.5, 0.9])
          KeeperPose(
            hand: Vec3(
              side * keeperDiveSpan * dive,
              0,
              0.55 + height * 1.5 * dive,
            ),
            dive: dive,
            side: side,
          ),
  ];

  group('the keeper', () {
    test('HE IS CENTRED ON THE POINT THE REACH TEST MEASURES FROM', () {
      // The figure used to be placed at `hand.x * 0.42` with the arm drawn to a
      // body-relative offset, so the two never had to agree: the drawn glove sat
      // 1.3 to 2.4 METRES from the point the save was decided at, and a GATHERED
      // ball — which the engine pins to `keeperHand` exactly — floated in open
      // air beside the gloves that had supposedly caught it.
      //
      // `keeperHand` is the CENTRE of his reach rather than a fingertip,
      // whatever its name says: `_keeperGotIt` tests against it and then allows
      // another `keeperReach` on top. So it is his chest, and that is what has
      // to land on it — which also puts a caught ball where a keeper holds one.
      for (final pose in poses) {
        final rig = keeperRigFor(pose, view);
        final truth = project(pose.hand, view);
        expect(rig, isNotNull);
        expect(truth, isNotNull);
        expect(
          (rig!.shoulder - truth!).distance,
          lessThan(0.5),
          reason:
              'side ${pose.side} dive ${pose.dive}: he is '
              '${(rig.shoulder - truth).distance.toStringAsFixed(1)}px from the '
              'point that decided the save',
        );
      }
    });

    test('and his gloves sweep exactly the reach the engine allows him', () {
      // The drawn arm IS `keeperReach`, so the sweep on screen and the circle in
      // the maths are one number. A shorter arm would show a keeper failing to
      // touch balls he saved; a longer one, the reverse.
      for (final pose in poses) {
        final rig = keeperRigFor(pose, view)!;
        final arm = scaleAt(-0.25, view, keeperReach);
        expect((rig.glove - rig.shoulder).distance, closeTo(arm, 1e-6));
        expect((rig.trailGlove - rig.shoulder).distance, closeTo(arm, 1e-6));
      }
    });

    test('AND HIS ARMS DO NOT STRETCH', () {
      // One arm went from 0.40 to 1.35 units across the dive while the other
      // halved — an arm that more than triples in length is not an arm reaching,
      // it is an arm growing. A limb keeps its length and changes its ANGLE.
      final lengths = <double>{};
      final trailLengths = <double>{};
      for (final pose in poses) {
        final rig = keeperRigFor(pose, view)!;
        lengths.add(
          double.parse((rig.glove - rig.shoulder).distance.toStringAsFixed(6)),
        );
        trailLengths.add(
          double.parse(
            (rig.trailGlove - rig.shoulder).distance.toStringAsFixed(6),
          ),
        );
      }
      expect(
        lengths,
        hasLength(1),
        reason: 'the leading arm changes length: $lengths',
      );
      expect(
        trailLengths,
        hasLength(1),
        reason: 'the trailing arm changes length: $trailLengths',
      );
    });

    test('and his legs keep their length too', () {
      final thighs = <double>{};
      for (final pose in poses) {
        final rig = keeperRigFor(pose, view)!;
        for (final boot in [rig.leftBoot, rig.rightBoot]) {
          thighs.add(
            double.parse((boot - rig.hip).distance.toStringAsFixed(6)),
          );
        }
      }
      expect(thighs, hasLength(1), reason: 'a leg changed length: $thighs');
    });

    test('the body stays a body: head above shoulder above hip', () {
      // In HIS frame, whatever the dive has done to the whole figure. Measured
      // along his own spine rather than down the screen, because at full stretch
      // he is horizontal and "above" stops meaning up.
      for (final pose in poses) {
        final rig = keeperRigFor(pose, view)!;
        final spine = rig.hip - rig.shoulder;
        final toHead = rig.head - rig.shoulder;
        // The head runs the same way up the spine as the shoulder does from the
        // hip, so their dot product is negative.
        expect(
          spine.dx * toHead.dx + spine.dy * toHead.dy,
          lessThan(0),
          reason: 'side ${pose.side} dive ${pose.dive}: his head is inside him',
        );
      }
    });

    test('a full dive lays him FLAT, and a standing keeper is upright', () {
      // The dive is a rotation, and it is what says diving rather than
      // side-stepping.
      double tilt(KeeperPose pose) {
        final rig = keeperRigFor(pose, view)!;
        final spine = rig.head - rig.hip;
        // Degrees away from straight up the screen.
        return math.atan2(spine.dx.abs(), -spine.dy) * 180 / math.pi;
      }

      final standing = KeeperPose(
        hand: Vec3(0, 0, 0.9),
        dive: 0,
        side: 0,
      );
      final flat = KeeperPose(
        hand: Vec3(-keeperDiveSpan * 0.98, 0, 0.85),
        dive: 1,
        side: -0.98,
      );
      expect(tilt(standing), lessThan(5), reason: 'he is leaning at rest');
      expect(tilt(flat), greaterThan(50), reason: 'a full dive is not a lean');
    });

    test('and he is BEHIND the camera nowhere, so the rig is never null here', () {
      // A pose the projection cannot resolve returns null rather than drawing a
      // figure on the wrong side of the frame at enormous size — but no reachable
      // keeper pose is behind the lens, so every one above must solve.
      for (final pose in poses) {
        expect(keeperRigFor(pose, view), isNotNull);
      }
    });
  });

  group('the man taking it', () {
    /// The whole run-up and the follow-through past it.
    final moments = [
      for (var i = 1; i <= 24; i++) i / 12,
    ];

    test('HIS LEGS DO NOT STRETCH EITHER', () {
      // The kicking leg ran 0.80 to 1.05 units across the strike — a 31% stretch
      // arriving exactly when the eye is on it. A leg swings; it does not grow.
      final thighs = <double>{};
      for (final t in moments) {
        final rig = takerRigFor(t, view);
        if (rig == null) continue;
        for (final boot in [rig.plantBoot, rig.kickBoot]) {
          thighs.add(
            double.parse(
              ((boot - rig.hip).distance / rig.unit).toStringAsFixed(6),
            ),
          );
        }
      }
      expect(thighs, hasLength(1), reason: 'a leg changed length: \$thighs');
    });

    test('and neither do his arms', () {
      final arms = <double>{};
      for (final t in moments) {
        final rig = takerRigFor(t, view);
        if (rig == null) continue;
        for (final hand in [rig.leftHand, rig.rightHand]) {
          arms.add(
            double.parse(
              ((hand - rig.shoulder).distance / rig.unit).toStringAsFixed(6),
            ),
          );
        }
      }
      expect(arms, hasLength(1), reason: 'an arm changed length: \$arms');
    });

    test('HE SHRINKS AS HE RUNS IN, because the path is in WORLD space', () {
      // Ten metres of run-up toward a camera ten metres back: interpolating two
      // screen points would slide a same-sized figure across a converging pitch.
      // Toward the GOAL is away from the lens — the camera stands behind him —
      // so running in makes him smaller, and the last thing on screen is his
      // back.
      final first = takerRigFor(0.05, view)!;
      final planted = takerRigFor(1.0, view)!;
      expect(
        planted.unit,
        lessThan(first.unit),
        reason: 'he did not shrink as he ran away from the lens',
      );
    });

    test('his standing boot is ON the turf he is running over', () {
      // The plant foot is the contact, so it is what the world path places —
      // the rest of him hangs off it.
      for (final t in moments) {
        final rig = takerRigFor(t, view);
        if (rig == null) continue;
        expect((rig.plantBoot - rig.ground).distance, lessThan(0.5));
      }
    });

    test('and he FADES OUT rather than vanishing mid-frame', () {
      expect(takerRigFor(1.0, view)!.fade, 1);
      expect(takerRigFor(1.5, view)!.fade, lessThan(1));
      expect(takerRigFor(2.0, view), isNull, reason: 'he never left');
    });
  });

  group('the aim line', () {
    Path straight() => Path()
      ..moveTo(0, 0)
      ..lineTo(100, 0);

    test('IT IS DOTTED, not one solid stroke', () {
      // A solid line says where you are pointing. Dashes with movement in them
      // say which way the ball is going, which is the part the preview was not
      // saying at all.
      final dashes = dashedPath(straight()).computeMetrics().toList();
      expect(dashes.length, greaterThan(3));
      for (final d in dashes) {
        expect(d.length, lessThanOrEqualTo(aimDash + 1e-9));
      }
    });

    test('and the dashes MARCH toward the goal', () {
      // The phase runs backwards along the path so the dashes travel forwards:
      // one full period on and the pattern is where it started, and half a
      // period on it is not.
      // The LEADING dash's length is the readable signature: the pattern slides
      // out under the start of the path, so the first dash is progressively
      // clipped and then whole again. Its start cannot move — it is pinned at
      // zero by the clip — which is what makes it the wrong thing to measure.
      double leadDash(double phase) =>
          dashedPath(straight(), phase: phase).computeMetrics().first.length;

      final home = leadDash(0);
      final half = leadDash((aimDash + aimGap) / 2);
      final full = leadDash(aimDash + aimGap);
      expect(home, closeTo(aimDash, 1e-6));
      expect(half, isNot(closeTo(home, 0.01)), reason: 'nothing moved');
      expect(full, closeTo(home, 0.01), reason: 'it does not repeat');
    });

    test('a zero-length pattern draws nothing rather than looping for ever', () {
      expect(
        dashedPath(straight(), dash: 0, gap: 0).computeMetrics().isEmpty,
        isTrue,
      );
    });
  });
}
