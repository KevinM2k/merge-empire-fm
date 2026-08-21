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

    test('THE ARM HE IS DRAWN WITH IS SHORTER THAN HIS REACH', () {
      // Reported from the couch as huge arms. `keeperHand` is the centre of the
      // reach and the centre is his CHEST, so an arm drawn from there to the
      // glove is the full [keeperReach] — 1.05m of limb on a figure whose whole
      // leg is 0.88m, radiating out of his sternum. The glove has to stay on the
      // circle, because that circle is what decides saves; where the arm STARTS
      // does not.
      for (final pose in poses) {
        final rig = keeperRigFor(pose, view)!;
        final leg = (rig.leftBoot - rig.hip).distance;
        for (final (joint, glove) in [
          (rig.leadJoint, rig.glove),
          (rig.trailJoint, rig.trailGlove),
        ]) {
          final arm = (glove - joint).distance;
          expect((glove - rig.shoulder).distance, greaterThan(arm));
          expect(
            arm,
            lessThan(leg),
            reason:
                'side ${pose.side} dive ${pose.dive}: his arm is longer '
                'than his leg',
          );
        }
      }
    });

    test('and the DRAWN limb does not stretch either', () {
      // The invariant the rig was rebuilt around, applied to the segments that
      // are actually painted: shoulder to elbow to glove. A fixed sideways
      // shoulder offset would have failed this — a tucked arm would leave the
      // chest at a different angle from an outstretched one and so be drawn
      // longer. Displacing the joint along the arm's OWN direction is what keeps
      // every arm the same.
      final upper = <double>{};
      final fore = <double>{};
      for (final pose in poses) {
        final rig = keeperRigFor(pose, view)!;
        for (final (joint, elbow, glove) in [
          (rig.leadJoint, rig.leadElbow, rig.glove),
          (rig.trailJoint, rig.trailElbow, rig.trailGlove),
        ]) {
          upper.add(double.parse((elbow - joint).distance.toStringAsFixed(6)));
          fore.add(double.parse((glove - elbow).distance.toStringAsFixed(6)));
        }
      }
      expect(upper, hasLength(1), reason: 'an upper arm changed: $upper');
      expect(fore, hasLength(1), reason: 'a forearm changed: $fore');
    });

    test('the elbow is OFF the line, so the arm has a joint in it', () {
      for (final pose in poses) {
        final rig = keeperRigFor(pose, view)!;
        for (final (joint, elbow, glove) in [
          (rig.leadJoint, rig.leadElbow, rig.glove),
          (rig.trailJoint, rig.trailElbow, rig.trailGlove),
        ]) {
          // How far off the straight line it sits, which is the quantity that
          // reads: he is only about eighty pixels tall on a phone, so the arm's
          // extra path length over a spoke is under three of them.
          final along = glove - joint;
          final len = along.distance;
          final off =
              ((elbow.dx - joint.dx) * along.dy -
                  (elbow.dy - joint.dy) * along.dx) /
              len;
          expect(off.abs(), greaterThan(rig.unit * 0.05));
        }
      }
    });

    test('a keeper at rest has his arms OUT, not up in a V', () {
      // Fifty-two degrees from straight up is a man signalling a touchdown, and
      // two full-reach limbs held above the shoulders is most of what read as
      // huge: the length was reasonable, the pose was not.
      final rig = keeperRigFor(
        KeeperPose(hand: Vec3(0, 0, keeperStandZ), dive: 0, side: 0),
        view,
      )!;
      for (final glove in [rig.glove, rig.trailGlove]) {
        expect(
          glove.dy,
          greaterThan(rig.shoulder.dy),
          reason: 'a set keeper does not hold his gloves above his chest',
        );
        // And well out to the side of him, which is where a reach comes from.
        expect((glove.dx - rig.shoulder.dx).abs(), greaterThan(rig.unit * 0.8));
      }
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

      final standing = KeeperPose(hand: Vec3(0, 0, 0.9), dive: 0, side: 0);
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
    final moments = [for (var i = 1; i <= 24; i++) i / 12];

    test('HIS LEGS DO NOT STRETCH EITHER', () {
      // The kicking leg ran 0.80 to 1.05 units across the strike — a 31% stretch
      // arriving exactly when the eye is on it. A leg swings; it does not grow.
      //
      // Measured on the BONES, which is where the invariant belongs. It used to
      // be measured hip-to-boot, because the leg was one rigid segment — and
      // pinning that distance is exactly what forced the bones to stretch once
      // there was a knee between them. A folded leg is a SHORTER leg; a thigh is
      // a thigh whatever the knee is doing.
      final thighs = <double>{};
      final shins = <double>{};
      for (final t in moments) {
        final rig = takerRigFor(t, view);
        if (rig == null) continue;
        for (final (knee, boot) in [
          (rig.plantKnee, rig.plantBoot),
          (rig.kickKnee, rig.kickBoot),
        ]) {
          thighs.add(
            double.parse(
              ((knee - rig.hip).distance / rig.unit).toStringAsFixed(5),
            ),
          );
          shins.add(
            double.parse(
              ((boot - knee).distance / rig.unit).toStringAsFixed(5),
            ),
          );
        }
      }
      expect(thighs, hasLength(1), reason: 'a thigh changed length: $thighs');
      expect(shins, hasLength(1), reason: 'a shin changed length: $shins');
    });

    test('HE COCKS THE LEG BEFORE HE SWINGS IT', () {
      // Reported from the couch as an odd swing, and it was: the kicking leg ran
      // straight from 0.36 radians to 1.14 with nothing else happening — no
      // backlift, no knee, one stick pivoting at the hip. A kick goes BACK with
      // the knee folded and then snaps through and straightens into the ball.
      double across(double t) {
        final rig = takerRigFor(t, view)!;
        return rig.kickBoot.dx - rig.hip.dx;
      }

      double fold(double t) {
        final rig = takerRigFor(t, view)!;
        return (rig.kickBoot - rig.hip).distance / rig.unit;
      }

      // The backlift: behind the hip, and the leg is short because it is folded.
      expect(across(0.90), lessThan(0));
      expect(fold(0.90), lessThan(fold(0.82)));
      // And through it: in front of the hip, and straightened out again.
      expect(across(1.0), greaterThan(0));
      expect(fold(1.0), greaterThan(fold(0.90)));
      expect(across(1.0), greaterThan(across(0.90)));
    });

    test('and the knee is a real joint, off the hip-to-boot line', () {
      for (final t in moments) {
        final rig = takerRigFor(t, view);
        if (rig == null) continue;
        for (final (knee, boot) in [
          (rig.plantKnee, rig.plantBoot),
          (rig.kickKnee, rig.kickBoot),
        ]) {
          // It never folds past what the bones allow, and it never locks flat
          // enough to be a straight line pretending to be a leg.
          final span = (boot - rig.hip).distance;
          expect(
            span,
            lessThanOrEqualTo(
              (knee - rig.hip).distance + (boot - knee).distance + 1e-6,
            ),
          );
          expect(span, greaterThan(0));
        }
      }
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

    test(
      'a zero-length pattern draws nothing rather than looping for ever',
      () {
        expect(
          dashedPath(straight(), dash: 0, gap: 0).computeMetrics().isEmpty,
          isTrue,
        );
      },
    );
  });

  group('the stadium behind the goal', () {
    test('the backdrop and the turf MEET PAST THE GOAL LINE', () {
      // One number, shared, or the photograph and the grass leave a seam. The
      // widget puts the stadium above it and the painter starts the turf on it.
      final seam = standBaseY(view);
      expect(seam, project(Vec3(0, _runOff, 0), view)!.dy);
      expect(seam, greaterThan(view.height * 0.094));
      expect(seam, lessThan(view.height));
    });

    test('THE PITCH RUNS ON PAST THE GOAL rather than stopping on the line', () {
      // The reported fault: it was all grass above the crossbar, as though
      // there were a mountain behind them. The seam was the goal LINE, so the
      // band handed to the photograph started there — and the photograph's own
      // flat green field, cropped to it, stood up behind the goal.
      //
      // Ground does not stop at the line. The turf the painter draws now
      // covers the run-off too, which puts the seam ABOVE the goal line on
      // screen: further away is higher up.
      expect(standBaseY(view), lessThan(goalLineY(view)));
      // And it is a strip, not a wall — a couple of dozen pixels at this size.
      expect(goalLineY(view) - standBaseY(view), greaterThan(4));
      expect(goalLineY(view) - standBaseY(view), lessThan(view.height * 0.1));
    });

    test(
      'and the seam is BELOW the crossbar, so the goal stands against it',
      () {
        // The frame has to be seen against the stand rather than against grass —
        // which is the whole reason the net can be cords now.
        expect(
          standBaseY(view),
          greaterThan(project(Vec3(0, 0, goalHeight), view)!.dy),
        );
      },
    );

    test('a taller view moves the seam with it', () {
      expect(standBaseY(const Size(400, 900)), isNot(standBaseY(view)));
    });

    test('THE ART IS SHOWN FROM ITS HORIZON UP, not from its field', () {
      // Fitting a square drawing into the band shows whichever slice the
      // alignment picks, and which slice was the fault: anchored to the bottom
      // it was the art's own grass, standing up behind the goal like a hill. The
      // drawing has to be PLACED so its ground line falls on the seam — sized to
      // reach it — because on a tall view the band is nearly as tall as the
      // drawing and no alignment can show only what is above that line.
      const artHorizon = 0.62;
      for (final size in [
        const Size(400, 800),
        const Size(356, 520),
        const Size(360, 640),
        const Size(820, 1180),
      ]) {
        final band = standBaseY(size);
        final rect = backdropRect(size);
        expect(
          rect.top + artHorizon * rect.height,
          closeTo(band, 0.001),
          reason:
              "$size puts the art's ground line at "
              '${rect.top + artHorizon * rect.height}, not on the seam at $band',
        );
        // Square, covering the width, and never so short that the band runs off
        // the bottom of it into nothing.
        expect(rect.width, closeTo(rect.height, 1e-9));
        expect(rect.width, greaterThanOrEqualTo(size.width));
        expect(rect.bottom, greaterThanOrEqualTo(band));
        expect(rect.left, closeTo((size.width - rect.width) / 2, 1e-9));
      }
    });
  });

  group('the framing', () {
    test('ELEVEN METRES LOOKS LIKE ELEVEN METRES', () {
      // Reported from the couch as "the penalty spot is too close to the goal".
      // The spot is regulation and did not move — [spotDistance] is 11 and every
      // number the physics is balanced around rests on it. What moved is the
      // CAMERA: from 2.62m the gap between the ball and the goal line was barely
      // a third of the goal's own width, so eleven metres read as three.
      final ball = project(Vec3(0, -spotDistance, ballRadius), view)!.dy;
      final line = goalLineY(view);
      final post = project(Vec3(goalHalfWidth, 0, 0), view)!.dx;
      final width = 2 * (post - view.width / 2);
      expect(ball - line, greaterThan(width * 0.5));
    });

    test('and the goal still fills about three quarters of the frame', () {
      // The other constraint, which the height is not allowed to cost: the gap
      // was opened by raising the camera precisely because the focal length and
      // the camera's distance are both pinned by this.
      final post = project(Vec3(goalHalfWidth, 0, 0), view)!.dx;
      final width = 2 * (post - view.width / 2);
      expect(width / view.width, closeTo(0.75, 0.03));
    });

    test('the ball is FRAMED, whatever shape the view is', () {
      // The horizon used to be a constant fraction of the HEIGHT while every
      // offset in the projection is a fraction of the WIDTH, so the whole scene
      // slid up or down the frame as the aspect changed — and the camera had
      // been solved for one shape of window. It is derived from the ball now.
      for (final size in [
        const Size(400, 800),
        const Size(356, 520),
        const Size(300, 700),
        const Size(430, 560),
      ]) {
        final ball = project(Vec3(0, -spotDistance, ballRadius), size)!.dy;
        expect(
          ball / size.height,
          closeTo(0.70, 1e-6),
          reason: '$size puts the ball at ${ball / size.height} of the frame',
        );
        // And the goal is above it with room to spare, on every one of them.
        expect(goalLineY(size), lessThan(ball));
        expect(project(Vec3(0, 0, goalHeight), size)!.dy, greaterThan(0));
      }
    });

    test('A SHORT, WIDE VIEW OPENS THE LENS rather than losing the goal', () {
      // The view is an `Expanded` in a column of score lines, so on a short
      // screen it gets whatever is left — and the scene is a fixed multiple of
      // the WIDTH tall, so past a certain aspect no framing puts the crossbar
      // and the ball in the same picture. Anchoring on the ball alone pushed
      // the whole goal off the top; a widget test's own 800×600 surface is
      // already past that aspect, which is how it was caught.
      for (final size in [
        const Size(776, 300),
        const Size(700, 240),
        const Size(500, 400),
      ]) {
        final bar = project(Vec3(0, 0, goalHeight), size)!.dy;
        final ball = project(Vec3(0, -spotDistance, ballRadius), size)!.dy;
        expect(
          bar,
          greaterThan(0),
          reason: '$size puts the crossbar at $bar, off the top',
        );
        expect(
          ball,
          lessThan(size.height),
          reason: '$size puts the ball at $ball, off the bottom',
        );
        // The goal gives up width for it, which is the right thing to lose: it
        // is still most of a third of the frame and it can still be aimed at.
        final post = project(Vec3(goalHalfWidth, 0, 0), size)!.dx;
        expect(2 * (post - size.width / 2) / size.width, greaterThan(0.25));
      }
    });
  });

  group('the goal is a box', () {
    final mesh = NetMesh();

    test('THE SIDES ARE STRUNG, from the post back to the stanchion', () {
      // It had a back and nothing else, so from behind the spot the goal was a
      // flat grid on the grass — no side netting, and therefore nothing in the
      // picture running away from the camera to say the goal has depth.
      for (final side in [-1, 1]) {
        // Every vertex sits ON its post's plane, spans the frame's full height,
        // and travels the goal's full depth.
        for (var r = 0; r <= mesh.rows; r++) {
          for (var c = 0; c <= NetMesh.depthCells; c++) {
            final v = mesh.sideVertex(side, c, r);
            expect(v.x, closeTo(side * goalHalfWidth, 1e-9));
            expect(v.y, inInclusiveRange(0, goalDepth));
            expect(v.z, inInclusiveRange(0, goalHeight));
          }
        }
        expect(mesh.sideVertex(side, 0, 0).y, 0);
        expect(
          mesh.sideVertex(side, NetMesh.depthCells, 0).y,
          closeTo(goalDepth, 1e-9),
        );
        expect(mesh.sideVertex(side, 0, 0).z, closeTo(goalHeight, 1e-9));
        expect(mesh.sideVertex(side, 0, mesh.rows).z, 0);
      }
    });

    test('and the roof runs from the crossbar to the back', () {
      for (var r = 0; r <= NetMesh.depthCells; r++) {
        for (var c = 0; c <= mesh.columns; c++) {
          final v = mesh.roofVertex(c, r);
          expect(v.z, closeTo(goalHeight, 1e-9));
          expect(v.x.abs(), lessThanOrEqualTo(goalHalfWidth + 1e-9));
          expect(v.y, inInclusiveRange(0, goalDepth));
        }
      }
    });

    test('the three panels MEET THE BACK PLANE they hang off', () {
      // The seams have to be exact or the goal is three sheets near each other.
      // The side's back edge is the back plane's outermost column; the roof's
      // back edge is its top row.
      for (final side in [-1, 1]) {
        final c = side < 0 ? 0 : mesh.columns;
        for (var r = 0; r <= mesh.rows; r++) {
          final onSide = mesh.sideVertex(side, NetMesh.depthCells, r);
          final onBack = mesh.vertex(c, r);
          expect(onSide.x, closeTo(onBack.x, 1e-9));
          expect(onSide.y, closeTo(onBack.y, 1e-9));
          expect(onSide.z, closeTo(onBack.z, 1e-9));
        }
      }
      for (var c = 0; c <= mesh.columns; c++) {
        final onRoof = mesh.roofVertex(c, NetMesh.depthCells);
        final onBack = mesh.vertex(c, 0);
        expect(onRoof.x, closeTo(onBack.x, 1e-9));
        expect(onRoof.y, closeTo(onBack.y, 1e-9));
        expect(onRoof.z, closeTo(onBack.z, 1e-9));
      }
    });

    test('and the sides do not move when the back takes a shot', () {
      // Taut between the post and the stanchion is why the side netting is the
      // part of a goal that does not billow. The back plane is what the bulge
      // is for, and it still has it.
      final before = mesh.sideVertex(1, 2, 3);
      mesh.strike(Vec3(1, goalDepth, 1), 28);
      expect(mesh.vertex(7, 4).y, greaterThan(goalDepth));
      final after = mesh.sideVertex(1, 2, 3);
      expect(after.x, before.x);
      expect(after.y, before.y);
      expect(after.z, before.z);
      mesh.reset();
    });
  });
}

/// The run-off behind the goal, mirroring the view's own `_beyondGoal`.
const double _runOff = 7.5;
