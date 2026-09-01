/// The penalty scene's FIGURES, as geometry.
///
/// Everything here is pure arithmetic on the projection, which is exactly where
/// the two faults that were reported from the couch lived: a keeper whose limbs
/// stretched like one of the Fantastic Four, and gloves drawn nowhere near the
/// ball they had just saved. Neither is visible in a widget test that only asks
/// whether the scene painted.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/penalty_physics.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/minigames/penalty_screen.dart';
import 'package:merge_empire_fc/ui/screens/minigames/penalty_view.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

/// The real screen, on a save sitting in one named division.
///
/// The kit is the first thing the scene takes from the SAVE rather than from
/// the physics, so the only test that can prove it is one that goes through
/// `PenaltyScreen` — a `PenaltyView` built by hand proves the parameter exists
/// and nothing about whether anything fills it.
Future<void> pumpPenalty(WidgetTester tester, {required String division}) async {
  tester.view.physicalSize = const Size(420 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final save = createDefaultState();
  (save['progression'] as Map<String, dynamic>)['currentDivision'] = division;

  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(save)}),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(gameProvider).load();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: const PenaltyScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Close it, IN the test body.
///
/// The screen's debounced save leaves a `Timer` pending and `flutter_test`
/// fails any test that ends with one outstanding — as an assertion at the top
/// of the body, which reads as the expectation below having failed rather than
/// as the scene never having been shut. `addTearDown` is too late: the
/// invariant is checked before teardowns run.
Future<void> closePenalty(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: saveDebounceMs + 100));
}

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
      //
      // **HIS CHEST, and it used to be his shoulder.** 0.9m off the floor is a
      // set keeper's HANDS, so making it his shoulder height left the drawn man
      // — 1.52m from shoulder to boot — with his feet better than half a metre
      // under the turf, which projects as a keeper standing a metre in front of
      // his own line. Reported from the drill.
      for (final pose in poses) {
        final rig = keeperRigFor(pose, view);
        final truth = project(pose.hand, view);
        expect(rig, isNotNull);
        expect(truth, isNotNull);
        expect(
          (rig!.chest - truth!).distance,
          lessThan(0.5),
          reason:
              'side ${pose.side} dive ${pose.dive}: he is '
              '${(rig.chest - truth).distance.toStringAsFixed(1)}px from the '
              'point that decided the save',
        );
      }
    });

    test('AND STANDING, HIS BOOTS ARE ON THE GOAL LINE', () {
      // The whole of the report: a figure whose feet are under the ground
      // projects as one standing well in front of it.
      final rig = keeperRigFor(
        KeeperPose(hand: Vec3(0, -0.25, keeperStandZ), dive: 0, side: 0),
        view,
      );
      final ground = project(Vec3(0, -0.25, 0), view);
      expect(rig, isNotNull);
      expect(ground, isNotNull);
      expect(
        (rig!.feet.dy - ground!.dy).abs(),
        lessThan(2),
        reason:
            'his boots are ${(rig.feet.dy - ground.dy).toStringAsFixed(1)}px '
            'off the turf',
      );
    });

    test('HIS ARM IS A BODY\'S ARM, not the reach circle\'s radius', () {
      // **The circle is the PHYSICS' truth and the figure is a person.** The
      // glove used to be pinned to the reach circle at full stretch, which
      // forced the two bones to sum to [keeperReach] less the girdle — 0.88m of
      // arm, the length of his whole leg, on a man 1.8m tall. That is the
      // monkey arms, and the pinning is what caused it.
      //
      // So the arm is sized like an arm and the glove lands where an arm's
      // glove lands. A save at the very edge of the reach may show the glove a
      // hand short of the ball for a frame; a keeper built like an ape shows in
      // every frame of every kick.
      final circle = scaleAt(-0.25, view, keeperReach);
      for (final pose in poses) {
        final rig = keeperRigFor(pose, view)!;
        final leg = (rig.leftBoot - rig.leftHip).distance;
        for (final (joint, glove) in [
          (rig.leadJoint, rig.glove),
          (rig.trailJoint, rig.trailGlove),
        ]) {
          final arm = (glove - joint).distance;
          expect(
            arm,
            lessThan(leg * 0.85),
            reason:
                'side ${pose.side} dive ${pose.dive}: his arm is '
                '${(arm / leg).toStringAsFixed(2)} of his leg',
          );
          // Inside the circle always, and folded well inside it at rest.
          final sweep = (glove - rig.shoulder).distance;
          expect(sweep, lessThan(circle));
          if (pose.dive == 0) expect(sweep, lessThan(circle * 0.72));
        }
        // The dive still STRAIGHTENS it, which is what full stretch means.
        if (pose.dive >= 1) {
          expect(
            (rig.glove - rig.leadJoint).distance,
            greaterThan((rig.glove - rig.leadElbow).distance * 1.9),
          );
        }
      }
    });

    test('AND HIS ARMS DO NOT STRETCH', () {
      // One arm went from 0.40 to 1.35 units across the dive while the other
      // halved — an arm that more than triples in length is not an arm reaching,
      // it is an arm growing. A limb keeps its length and changes its ANGLE —
      // measured on the BONES, because the chest-to-glove distance now varies
      // by design: the elbow folds at rest and straightens into the dive, and
      // the two-bone solve is what lets it do that without either bone moving.
      final upper = <double>{};
      final fore = <double>{};
      for (final pose in poses) {
        final rig = keeperRigFor(pose, view)!;
        for (final (joint, elbow, glove) in [
          (rig.leadJoint, rig.leadElbow, rig.glove),
          (rig.trailJoint, rig.trailElbow, rig.trailGlove),
        ]) {
          upper.add(double.parse((elbow - joint).distance.toStringAsFixed(5)));
          fore.add(double.parse((glove - elbow).distance.toStringAsFixed(5)));
        }
      }
      expect(upper, hasLength(1), reason: 'an upper arm changed: $upper');
      expect(fore, hasLength(1), reason: 'a forearm changed: $fore');
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

    test('AND HIS ELBOWS ARE OUTSIDE HIM, not buried in his chest', () {
      // The elbow bowed toward his FEET, and for an arm hanging down-and-out
      // that direction resolves inward: measured, the elbow sat 0.1 units off
      // his centreline with the glove 0.4 out — inside the 0.30-wide torso
      // stroke. So the upper arm disappeared into his chest and the forearm
      // surfaced out of his ribs, which is the standing pose reported from the
      // couch.
      final rig = keeperRigFor(
        KeeperPose(hand: Vec3(0, 0, keeperStandZ), dive: 0, side: 0),
        view,
      )!;
      for (final (joint, elbow) in [
        (rig.leadJoint, rig.leadElbow),
        (rig.trailJoint, rig.trailElbow),
      ]) {
        // Further out than the shoulder it hangs off, and well clear of the
        // torso stroke's own half-width.
        expect(
          (elbow.dx - rig.shoulder.dx).abs(),
          greaterThan((joint.dx - rig.shoulder.dx).abs()),
          reason: 'the elbow bows inward',
        );
        expect(
          (elbow.dx - rig.shoulder.dx).abs(),
          greaterThan(rig.unit * 0.15),
          reason: 'the elbow is inside the torso',
        );
      }
    });

    test('a keeper at rest has his gloves at his HIPS, not out at 90', () {
      // Fifty-two degrees from straight up is a man signalling a touchdown, and
      // two full-reach limbs held above the shoulders is most of what read as
      // huge: the length was reasonable, the pose was not.
      //
      // **AND 132 WAS STILL HALFWAY TO HORIZONTAL** — a chord 48 degrees off
      // vertical, putting each glove better than half a metre out from his
      // centreline. Reported from the couch as the arms sitting at right
      // angles. They hang now: down, and a hand's width proud of the hips.
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
        // At the hip, give or take a hand: down the body rather than across it.
        expect(
          glove.dy,
          closeTo(rig.hip.dy, rig.unit * 0.2),
          reason: 'not at his hips',
        );
        // Clear of the girdle, so the arm is an arm and not a stroke down the
        // side of the torso — but nowhere near a wingspan. The full span
        // belongs to the dive.
        expect((glove.dx - rig.shoulder.dx).abs(), greaterThan(rig.unit * 0.2));
        expect((glove.dx - rig.shoulder.dx).abs(), lessThan(rig.unit * 0.45));
      }
    });

    test('and his legs keep their length too', () {
      // Measured from the PELVIS each hangs off, not from his centreline. Both
      // legs used to start at the same point under a torso stroke whose round
      // cap domed over their tops, so they read as detached from the body.
      final thighs = <double>{};
      for (final pose in poses) {
        final rig = keeperRigFor(pose, view)!;
        for (final (hip, boot) in [
          (rig.leftHip, rig.leftBoot),
          (rig.rightHip, rig.rightBoot),
        ]) {
          thighs.add(double.parse((boot - hip).distance.toStringAsFixed(6)));
        }
      }
      expect(thighs, hasLength(1), reason: 'a leg changed length: $thighs');
    });

    test('and each leg hangs off its own side of the pelvis', () {
      for (final pose in poses) {
        final rig = keeperRigFor(pose, view)!;
        expect(
          (rig.leftHip - rig.rightHip).distance,
          greaterThan(rig.unit * 0.1),
        );
        // The bar is centred on the hip the whole figure is built from.
        final mid = Offset(
          (rig.leftHip.dx + rig.rightHip.dx) / 2,
          (rig.leftHip.dy + rig.rightHip.dy) / 2,
        );
        expect((mid - rig.hip).distance, lessThan(0.001));
      }
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

  /// **The keeper got harder as you climbed and looked exactly the same doing
  /// it.** The palettes lived in the sprite this scene replaced, so deleting a
  /// superseded file took a shipped feature with it and left `PARITY.md`
  /// ticking the item — which is why these pin the mapping rather than only
  /// the arithmetic around it.
  group('what he is wearing', () {
    test('THERE IS ONE KIT PER DIVISION, and no kit for a division there', () {
      // The sprite's table was indexed by a TIER the division had to be
      // converted into, and it carried an eighth entry its own ramp could
      // never reach. A list as long as `divisions` cannot drift either way.
      expect(keeperKits.length, divisions.length);
    });

    test('and the division picks it', () {
      // Pinned at both ends: these are the sprite's tier two and tier eight,
      // which are the kits Sunday League and the Champions Cup actually wore.
      expect(keeperKitForDivision(0).shirt, const Color(0xFFE0A32B));
      expect(
        keeperKitForDivision(divisions.length - 1).shirt,
        const Color(0xFF2E7CE8),
      );
      for (var i = 0; i < divisions.length; i++) {
        expect(
          keeperKitForDivision(i),
          keeperKits[i],
          reason: divisions[i].id,
        );
      }
    });

    test('a division off either end wears the nearest kit, not a throw', () {
      // `keeperReachFor` clamps rather than throwing and this is the third ramp
      // off the same index, so a division added without a kit has to draw a
      // keeper rather than take the scene down.
      expect(keeperKitForDivision(-1), keeperKits.first);
      expect(keeperKitForDivision(99), keeperKits.last);
    });

    test('EVERY DIVISION IS A DIFFERENT SHIRT, which is the whole point', () {
      final shirts = {for (final kit in keeperKits) kit.shirt};
      expect(shirts.length, keeperKits.length);
    });

    test('the gloves never match the sleeve they hang off', () {
      // The kit's own claim: the glove is the thing that saves it, so it is the
      // thing you have to be able to pick out. A glove the colour of the shirt
      // is the fault the scene's comment says it was rebuilt away from.
      for (var i = 0; i < keeperKits.length; i++) {
        expect(
          keeperKits[i].glove,
          isNot(keeperKits[i].shirt),
          reason: divisions[i].id,
        );
      }
    });

    test('and the shirt shade is DARKER than the shirt', () {
      // The torso gradient runs shoulder-to-hip through these two. A shade
      // lighter than the shirt lights his belly and leaves his chest in the
      // dark, which is a rig lit from underneath.
      for (var i = 0; i < keeperKits.length; i++) {
        final kit = keeperKits[i];
        expect(
          kit.shirtShade.computeLuminance(),
          lessThan(kit.shirt.computeLuminance()),
          reason: divisions[i].id,
        );
      }
    });

    // One pump per division, rather than seven inside one body: the save is a
    // process-lifetime map that a load REPLACES THE CONTENTS OF, so pumping a
    // second one over the first is exactly the sharp edge `game_state.dart`'s
    // header warns about — and a failure here names the division rather than
    // the loop.
    for (var i = 0; i < divisions.length; i++) {
      testWidgets('THE SAVE REACHES HIS SHIRT — ${divisions[i].id}', (
        tester,
      ) async {
        // The reachability half, and the half a geometry test cannot ask: every
        // kit above could be right and the scene still draw one hardcoded
        // shirt. The sprite's palettes were reachable too, right up until they
        // were not.
        await pumpPenalty(tester, division: divisions[i].id);
        final view = tester.widget<PenaltyView>(
          find.byKey(const ValueKey('penalty-view')),
        );
        expect(view.kit, keeperKits[i]);
        // And the painter is handed the same one — the scene draws what the
        // screen resolved rather than a second lookup of its own.
        final painter = tester
            .widgetList<CustomPaint>(
              find.descendant(
                of: find.byType(PenaltyView),
                matching: find.byType(CustomPaint),
              ),
            )
            .map((c) => c.painter)
            .whereType<PenaltyPainter>()
            .single;
        expect(painter.kit, keeperKits[i]);
        await closePenalty(tester);
      });
    }

    test('and he is DRAWN in it, standing and at full stretch either way', () {
      // Every kit through the real painter, in the poses that move the rig
      // furthest apart. **What this asks is only that `paint` returns**: a
      // colour the rig cannot take — a shader built from two coincident
      // points, a record field renamed out from under it — throws here rather
      // than on the screen of whichever division happens to hold it. It is a
      // smoke test and it is the only kind available, because what the pixels
      // came out as is not a thing a canvas recording will answer.
      var painted = 0;
      for (final kit in keeperKits) {
        for (final pose in [poses.first, poses[poses.length ~/ 2], poses.last]) {
          final recorder = ui.PictureRecorder();
          PenaltyPainter(
            kit: kit,
            turf: const Color(0xFF3A8C41),
            frame: PenaltyFrame(
              // On the spot, and drawn: a keeper painted beside a ball that is
              // not there is half the scene.
              ball: Vec3(0, -spotDistance, ballRadius),
              ballVisible: true,
              roll: 0,
              keeper: pose,
              net: NetMesh(),
              aimPreview: null,
            ),
          ).paint(Canvas(recorder), view);
          recorder.endRecording().dispose();
          painted++;
        }
      }
      // And that the loop above actually ran, rather than an empty table
      // passing every kit test in this group by having nothing to check.
      expect(painted, keeperKits.length * 3);
    });
  });

  group('the man taking it', () {
    /// The whole run-up and the follow-through past it.
    final moments = [for (var i = 1; i <= 24; i++) i / 12];

    test('HIS LEGS DO NOT STRETCH EITHER', () {
      // The kicking leg ran 0.80 to 1.05 units across the strike — a 31% stretch
      // arriving exactly when the eye is on it. A leg swings; it does not grow.
      //
      // Measured on the BONES, which is where the invariant belongs — and as a
      // CEILING rather than as a constant, because a leg folding away from the
      // lens foreshortens and both bones get shorter on screen with it. Pinning
      // the drawn lengths instead is what pushed the knee out sideways to make
      // the difference up, which is the crossing below.
      var longestThigh = 0.0;
      var longestShin = 0.0;
      for (final t in moments) {
        final rig = takerRigFor(t, view);
        if (rig == null) continue;
        for (final (hip, knee, boot) in [
          (rig.plantHip, rig.plantKnee, rig.plantBoot),
          (rig.kickHip, rig.kickKnee, rig.kickBoot),
        ]) {
          longestThigh = math.max(
            longestThigh,
            (knee - hip).distance / rig.unit,
          );
          longestShin = math.max(
            longestShin,
            (boot - knee).distance / rig.unit,
          );
        }
      }
      // The bones' own lengths, plus the outward bow the knee is allowed.
      expect(longestThigh, lessThan(0.50), reason: 'a thigh grew');
      expect(longestShin, lessThan(0.47), reason: 'a shin grew');
    });

    /// The knees drew a full X and then swapped over at mid-run.
    ///
    /// The boots were pulled onto their own sides of the pelvis and the KNEES
    /// were left where a two-bone solve put them — which, with the boot lifted
    /// and the hip almost above it, is a third of a metre out to the wrong side.
    /// Measured before the fix: the plant knee at +0.04 with its boot at −0.10,
    /// the kick knee at −0.18 with its boot at +0.10. Reported from the couch as
    /// the legs crossing over.
    test('AND HIS KNEES DO NOT CROSS EITHER', () {
      for (var t = 0.02; t < 0.82; t += 0.01) {
        final rig = takerRigFor(t, view);
        if (rig == null) continue;
        expect(
          rig.kickKnee.dx,
          greaterThan(rig.plantKnee.dx),
          reason: 'the knees swapped sides at t=$t',
        );
        // And each stays on the side of the pelvis its own boot is on.
        expect(rig.kickKnee.dx, greaterThan(rig.hip.dx));
        expect(rig.plantKnee.dx, lessThan(rig.hip.dx));
      }
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
      // On the bones — girdle to elbow, elbow to hand — because that is what
      // is drawn. They hang off the girdle's edges: from the torso's centreline
      // the torso stroke swallowed their top third and they surfaced at hip
      // height, which read as tiny arms out of his waist.
      final upper = <double>{};
      final fore = <double>{};
      for (final t in moments) {
        final rig = takerRigFor(t, view);
        if (rig == null) continue;
        for (final (joint, elbow, hand) in [
          (rig.leftJoint, rig.leftElbow, rig.leftHand),
          (rig.rightJoint, rig.rightElbow, rig.rightHand),
        ]) {
          upper.add(
            double.parse(
              ((elbow - joint).distance / rig.unit).toStringAsFixed(5),
            ),
          );
          fore.add(
            double.parse(
              ((hand - elbow).distance / rig.unit).toStringAsFixed(5),
            ),
          );
          // Off the centreline: an arm starts at a shoulder, not a sternum.
          expect((joint.dx - rig.shoulder.dx).abs(), greaterThan(1));
        }
      }
      expect(upper, hasLength(1), reason: 'an upper arm changed: $upper');
      expect(fore, hasLength(1), reason: 'a forearm changed: $fore');
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

    /// **HIS LEGS NEVER CROSS**, which they did on every stride.
    ///
    /// The run-up is seen from directly behind, so the stride runs in DEPTH —
    /// and it was drawn ACROSS instead, ±0.36 and ±0.34 radians off vertical.
    /// That is better than three times the half-pelvis, so each boot swung past
    /// the centreline and finished under the other hip. Reported from the couch
    /// as the legs crossing over in a weird way.
    test('HIS LEGS NEVER CROSS on the way in', () {
      // Every frame of the run-up, right up to the plant. The strike itself is
      // excluded on purpose: a right-footed kick DOES swing across the body,
      // and that one is a kick rather than a stride.
      for (var t = 0.02; t < 0.82; t += 0.01) {
        final rig = takerRigFor(t, view);
        if (rig == null) continue;
        expect(
          rig.kickBoot.dx,
          greaterThan(rig.plantBoot.dx),
          reason: 'the boots swapped sides at t=$t',
        );
        // And each stays on its own side of the pelvis it hangs from.
        expect(rig.kickBoot.dx, greaterThan(rig.hip.dx - rig.unit * 0.1));
        expect(rig.plantBoot.dx, lessThan(rig.hip.dx + rig.unit * 0.1));
      }
    });

    test('and the stride reads off the KNEE instead', () {
      // What carries a run seen from behind is the swinging leg folding and its
      // boot leaving the turf, so the lift grew as the sweep shrank.
      final lift = <double>[];
      for (var t = 0.02; t < 0.82; t += 0.01) {
        final rig = takerRigFor(t, view)!;
        lift.add((rig.kickBoot - rig.kickHip).distance / rig.unit);
      }
      expect(
        lift.reduce(math.max) - lift.reduce(math.min),
        greaterThan(0.2),
        reason: 'the leg never folds, so nothing says he is running',
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

    test('HIS LIMBS HANG OFF JOINTS, not off his centreline', () {
      // Reported from the couch: the arms and legs did not connect properly.
      // Both legs started at one point and both arms at another, under a torso
      // stroke whose round cap domed past each of them — so the shirt painted
      // over the tops of the legs and the limbs surfaced out of the body
      // instead of joining it. Every limb starts on a bar that is drawn.
      for (final t in moments) {
        final rig = takerRigFor(t, view);
        if (rig == null) continue;
        for (final (a, b) in [
          (rig.plantHip, rig.kickHip),
          (rig.leftJoint, rig.rightJoint),
        ]) {
          expect((a - b).distance, greaterThan(rig.unit * 0.1));
          // Centred on the body, so the bar the limbs hang off is the bar the
          // torso is drawn to.
          final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
          expect(mid.dx, closeTo(rig.hip.dx, 0.001));
        }
        // And the shoulder bar is at the shoulder, the hip bar at the hip.
        expect(
          Offset(
            (rig.leftJoint.dx + rig.rightJoint.dx) / 2,
            (rig.leftJoint.dy + rig.rightJoint.dy) / 2,
          ),
          within(distance: 0.001, from: rig.shoulder),
        );
      }
    });

    test('and his standing boot is STILL on the turf, pelvis and all', () {
      // The plant boot hangs off the pelvis rather than the centreline now, so
      // the half-pelvis has to come back out of the hip or the whole figure
      // slides a hip's width off the ground it is running over.
      for (final t in moments) {
        final rig = takerRigFor(t, view);
        if (rig == null) continue;
        expect((rig.plantBoot - rig.ground).distance, lessThan(0.5));
      }
    });

    test('HIS FOREARM COMES IN, not further out', () {
      // Both bones used to splay: the upper arm sat 35 degrees off vertical and
      // the forearm added another 20 on top, so his arms reached out sideways
      // nearly as far as his legs reached down. Seen from behind, a running arm
      // is an elbow out at the ribs with the hand tucked in front of it.
      for (final t in [0.3, 0.5, 0.7]) {
        final rig = takerRigFor(t, view)!;
        for (final (joint, elbow, hand) in [
          (rig.leftJoint, rig.leftElbow, rig.leftHand),
          (rig.rightJoint, rig.rightElbow, rig.rightHand),
        ]) {
          final side = joint.dx < rig.hip.dx ? -1.0 : 1.0;
          // The hand is no further out than the elbow — the forearm folded
          // back across rather than continuing the splay.
          expect(
            (hand.dx - rig.hip.dx) * side,
            lessThanOrEqualTo((elbow.dx - rig.hip.dx) * side + 0.001),
            reason: 'at $t the forearm carries on outward',
          );
        }
      }
    });
  });

  /// **The ball never came back on its own.**
  ///
  /// The frame the hold expires is the frame the kick is dropped and the mesh
  /// reset — and the ticker then returned WITHOUT a `setState`, because it had
  /// just made itself idle. So the last thing painted was the ball in the net,
  /// and the next repaint came from the player's own touch. Reported from the
  /// couch as having to click to get the ball back, with nothing ever saying so.
  group('THE BALL COMES BACK BY ITSELF', () {
    testWidgets('after a shot, without anything being touched', (tester) async {
      tester.view.physicalSize = const Size(420 * 3, 900 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      var results = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 700,
                child: PenaltyView(
                  readChance: 0,
                  kit: keeperKits.first,
                  turf: const Color(0xFF3A8C41),
                  rng: math.Random(7),
                  onResult: (_, _, _) => results++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      Vec3 ball() => tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(PenaltyView),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((c) => c.painter)
          .whereType<PenaltyPainter>()
          .single
          .frame
          .ball;

      final spot = ball();
      expect(spot.y, closeTo(-spotDistance, 1e-6), reason: 'not on the spot');

      // One swipe, hard and straight — the drag has to clear the tap guard.
      final centre = tester.getCenter(find.byType(PenaltyView));
      final gesture = await tester.startGesture(centre + const Offset(0, 220));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(centre + const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(centre + const Offset(0, -140));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pump();

      // The run-up, the flight and the hold, one frame at a time and with NO
      // further gesture: what is being asked is whether the scene puts itself
      // back, so a pump that included a touch would answer the wrong question.
      for (var i = 0; i < 400; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(results, 1, reason: 'the kick never resolved');
      expect(
        ball().y,
        closeTo(spot.y, 1e-6),
        reason: 'the ball is still where it finished',
      );
      expect(ball().x, closeTo(spot.x, 1e-6));
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
      // **The vertex NEAREST the strike, not a magic index.** The mesh's
      // density is a tuning number — it went from 15x8 to 24x13 when the net
      // was reported as too open — and a test that names a cell by number is a
      // test of the tuning rather than of the bulge.
      var deepest = 0.0;
      for (var col = 0; col <= mesh.columns; col++) {
        for (var row = 0; row <= mesh.rows; row++) {
          deepest = math.max(deepest, mesh.vertex(col, row).y);
        }
      }
      expect(deepest, greaterThan(goalDepth));
      final after = mesh.sideVertex(1, 2, 3);
      expect(after.x, before.x);
      expect(after.y, before.y);
      expect(after.z, before.z);
      mesh.reset();
    });
  });
  group('WHEN HE HITS THE FLOOR, GRAVITY TAKES HIM', () {
    // `penalty_physics` has tracked `keeperLand` since the dive got its
    // landing, and the RIG never read it: the hand came down and the limbs held
    // the shape the dive left them in, so he arrived as a posed figure.
    const view = Size(360, 640);
    final flying = KeeperPose(hand: Vec3(1.6, -0.2, 0.9), dive: 1, side: 1);
    final down = KeeperPose(
      hand: Vec3(1.6, -0.2, 0.9),
      dive: 1,
      side: 1,
      land: 1,
    );

    test('THE LEGS COME BACK TOGETHER', () {
      // The split is something he was holding; on the floor it is not held.
      final a = keeperRigFor(flying, view)!;
      final b = keeperRigFor(down, view)!;
      expect(
        (b.leftBoot - b.rightBoot).distance,
        lessThan((a.leftBoot - a.rightBoot).distance),
      );
    });

    test('AND THE REACHING ARM FOLDS', () {
      // The last thing to go when a body stops flying is the thing it was
      // reaching with.
      final a = keeperRigFor(flying, view)!;
      final b = keeperRigFor(down, view)!;
      expect(
        (b.glove - b.leadJoint).distance,
        lessThan((a.glove - a.leadJoint).distance),
      );
    });

    test('but NO BONE CHANGES LENGTH, which is the rig\'s own invariant', () {
      // A folded limb is a shorter limb, and that is the joint-to-joint span.
      // The bones either side of the elbow may never move.
      for (final pose in [flying, down]) {
        final rig = keeperRigFor(pose, view)!;
        final upperA = (rig.leadElbow - rig.leadJoint).distance;
        final foreA = (rig.glove - rig.leadElbow).distance;
        final upperB = (rig.trailElbow - rig.trailJoint).distance;
        final foreB = (rig.trailGlove - rig.trailElbow).distance;
        expect(upperA, closeTo(upperB, 0.5));
        expect(foreA, closeTo(foreB, 0.5));
      }
    });

    test('and a keeper still in the air is untouched', () {
      final a = keeperRigFor(flying, view)!;
      final b = keeperRigFor(
        KeeperPose(hand: Vec3(1.6, -0.2, 0.9), dive: 1, side: 1),
        view,
      )!;
      expect((a.glove - b.glove).distance, lessThan(0.001));
    });

    /// **AND THEN HE SETTLES**, which he did not.
    ///
    /// `keeperLand` saturates the instant his shoulders reach the turf, so on
    /// its own it can only ease a limb to a rest and leave it there: he landed
    /// like a mannequin being set down. Reported from the couch as the arms and
    /// legs having no physics on them. `keeperLimbSettle` is the clock that
    /// starts where that one stops, and the limbs ring on it.
    KeeperRig at(double settle) => keeperRigFor(
      KeeperPose(
        hand: Vec3(1.6, -0.2, 0.9),
        dive: 1,
        side: 1,
        land: 1,
        settle: settle,
      ),
      view,
    )!;

    test('THE LIMBS OVERSHOOT THE HANG and come back under it', () {
      final rest = (at(1).trailGlove - at(1).trailJoint);
      double angle(double settle) {
        final rig = at(settle);
        return math.atan2(
          rig.trailGlove.dy - rig.trailJoint.dy,
          rig.trailGlove.dx - rig.trailJoint.dx,
        );
      }

      expect(rest.distance, greaterThan(0), reason: 'no arm to measure');
      final settled = angle(1);
      // A sixth of the way in the spring is at full stretch past the hang; at
      // half it has come back through it the other side.
      expect(angle(1 / 6), isNot(closeTo(settled, 0.02)));
      expect(
        (angle(1 / 6) - settled).sign,
        isNot((angle(0.5) - settled).sign),
        reason: 'it eased to a stop rather than ringing',
      );
    });

    test('and it dies out — where he finishes is where he finished', () {
      // Zero at both ends of the ring, so the settled pose is untouched.
      final before = at(0);
      final after = at(1);
      for (final (a, b) in [
        (before.glove, after.glove),
        (before.trailGlove, after.trailGlove),
        (before.leftBoot, after.leftBoot),
        (before.rightBoot, after.rightBoot),
        (before.head, after.head),
      ]) {
        expect((a - b).distance, lessThan(0.001));
      }
      // And it is DAMPED: the second swing is smaller than the first.
      final settled = at(1).trailGlove;
      expect(
        (at(5 / 6).trailGlove - settled).distance,
        lessThan((at(1 / 6).trailGlove - settled).distance),
      );
    });

    test('AND THE WHOLE BODY ROCKS WITH THEM, rather than four wobbles', () {
      // One oscillator, shared — which is what makes it read as a body
      // settling instead of as independent limbs.
      expect(at(1 / 6).lean, isNot(closeTo(at(1).lean, 0.001)));
      expect(
        (at(1 / 6).head - at(1).head).distance,
        greaterThan(0.5),
        reason: 'he landed and nothing moved',
      );
    });

    test('and NO BONE CHANGES LENGTH while it rings', () {
      final bones = <String, Set<double>>{};
      for (final settle in [0.0, 1 / 6, 0.4, 0.5, 5 / 6, 1.0]) {
        final rig = at(settle);
        void bone(String name, Offset a, Offset b) => (bones[name] ??= {})
            .add(double.parse((a - b).distance.toStringAsFixed(4)));
        bone('lead upper', rig.leadJoint, rig.leadElbow);
        bone('lead fore', rig.leadElbow, rig.glove);
        bone('trail upper', rig.trailJoint, rig.trailElbow);
        bone('trail fore', rig.trailElbow, rig.trailGlove);
        bone('left leg', rig.leftHip, rig.leftBoot);
        bone('right leg', rig.rightHip, rig.rightBoot);
      }
      for (final entry in bones.entries) {
        expect(entry.value, hasLength(1), reason: '${entry.key}: ${entry.value}');
      }
    });
  });

}

/// The run-off behind the goal, mirroring the view's own `_beyondGoal`.
const double _runOff = 7.5;
