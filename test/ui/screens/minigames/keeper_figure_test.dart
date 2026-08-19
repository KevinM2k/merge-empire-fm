/// The penalty keeper.
///
/// He was five flat SVG layers rotated about named joints, which at the size he
/// appears on the scene came out as an orange slab with two mitts on stubs. He
/// is drawn here now, with a hinge in every limb — and the whole pose is ONE
/// interpolated value, so a dive cannot arrive limb by limb.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/minigames/keeper_figure.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

Future<void> pumpKeeper(
  WidgetTester tester, {
  int tier = 3,
  KeeperPose pose = KeeperPose.ready,
  bool reduceMotion = true,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildAppTheme(kitId: '#4caf50', light: false),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: 160,
            height: 240,
            child: KeeperFigure(tier: tier, pose: pose),
          ),
        ),
      ),
    ),
  ),
);

KeeperPainter painterOf(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((c) => c.painter)
    .whereType<KeeperPainter>()
    .single;

void main() {
  group('the kit', () {
    test('there is one for every tier the division ramp can ask for', () {
      for (var tier = 1; tier <= 8; tier++) {
        expect(keeperKits.containsKey(tier), isTrue, reason: 'tier $tier');
      }
      // And they are not the same kit twice: the opposition visibly improves.
      expect(keeperKitFor(2).shirt, isNot(keeperKitFor(8).shirt));
    });

    test('and an unknown tier falls back rather than throwing', () {
      expect(keeperKitFor(99), keeperKitFor(3));
      expect(keeperKitFor(-1), keeperKitFor(3));
    });

    test('the division picks it', () {
      expect(keeperTierForDivision(0), 2, reason: 'Sunday League');
      expect(keeperTierForDivision(3), 5);
      expect(keeperTierForDivision(6), 8, reason: 'Champions Cup');
      expect(keeperTierForDivision(99), 8);
      expect(keeperTierForDivision(-4), 2);
    });
  });

  group('the pose', () {
    test('a low dive lays him out and a high one only leans him', () {
      expect(KeeperPose.lowLeft.bodyDegrees, -75);
      expect(KeeperPose.highLeft.bodyDegrees, -22);
      expect(KeeperPose.lowRight.bodyDegrees, 75);
      expect(KeeperPose.highRight.bodyDegrees, 22);
      expect(KeeperPose.ready.bodyDegrees, 0);
      expect(KeeperPose.ready.diving, isFalse);
      expect(KeeperPose.lowRight.diving, isTrue);
    });

    test('and the tap decides which one', () {
      expect(poseFor(x: 20, y: 40, midX: 50), KeeperPose.lowLeft);
      expect(poseFor(x: 20, y: 10, midX: 50), KeeperPose.highLeft);
      expect(poseFor(x: 80, y: 40, midX: 50), KeeperPose.lowRight);
      expect(poseFor(x: 80, y: 10, midX: 50), KeeperPose.highRight);
    });
  });

  group('the rig', () {
    test('stands square, with the two sides mirrored', () {
      const ready = KeeperRig.ready;
      expect(ready.body, 0);
      expect(ready.armL, -ready.armR);
      expect(ready.legL, -ready.legR);
    });

    test('and a dive throws BOTH arms the way he went', () {
      // Up in the figure's own space, because the body has already turned: a
      // limb pointing up on a rig lying at 75 degrees points along the goal
      // line, which is where the ball is.
      final right = KeeperRig.of(KeeperPose.lowRight);
      expect(right.body, greaterThan(0));
      expect(right.armR, greaterThan(90), reason: 'the lead arm reaches');
      expect(right.armL, greaterThan(90), reason: 'the trailing arm follows');
      expect(
        right.armR.abs(),
        greaterThan(right.armL.abs()),
        reason: 'and the lead one reaches further',
      );

      final left = KeeperRig.of(KeeperPose.lowLeft);
      expect(left.armL, lessThan(-90));
      expect(left.armR, lessThan(-90));
    });

    test('and BENDS its knees rather than pointing two planks', () {
      // A straight leg on a diving keeper is a plank going sideways.
      for (final pose in [KeeperPose.lowLeft, KeeperPose.lowRight]) {
        final rig = KeeperRig.of(pose);
        expect(
          rig.kneeL.abs() + rig.kneeR.abs(),
          greaterThan(30),
          reason: '$pose',
        );
      }
    });

    test('and interpolates as ONE value, so nothing arrives early', () {
      final half = KeeperRig.lerp(
        KeeperRig.ready,
        KeeperRig.of(KeeperPose.lowRight),
        0.5,
      );
      final end = KeeperRig.of(KeeperPose.lowRight);
      // Every angle is exactly halfway, on one curve.
      expect(half.body, (KeeperRig.ready.body + end.body) / 2);
      expect(half.armR, (KeeperRig.ready.armR + end.armR) / 2);
      expect(half.legL, (KeeperRig.ready.legL + end.legL) / 2);
    });
  });

  group('the figure', () {
    testWidgets('draws, and at the pose it was given', (tester) async {
      await pumpKeeper(tester, pose: KeeperPose.lowRight);
      await tester.pumpAndSettle();
      expect(painterOf(tester).rig.body, greaterThan(0));
    });

    testWidgets('wears the tier it was given', (tester) async {
      await pumpKeeper(tester, tier: 7);
      expect(painterOf(tester).kit, keeperKitFor(7));
    });

    testWidgets('he shifts his weight while he waits', (tester) async {
      await pumpKeeper(tester, reduceMotion: false);
      expect(
        tester.state<KeeperFigureState>(find.byType(KeeperFigure)).swaying,
        isTrue,
      );
      // And stops once he has committed: the limbs are doing the moving.
      await pumpKeeper(tester, pose: KeeperPose.lowLeft, reduceMotion: false);
      expect(
        tester.state<KeeperFigureState>(find.byType(KeeperFigure)).swaying,
        isFalse,
      );
    });

    testWidgets('reduce-motion stops the sway rather than the keeper', (
      tester,
    ) async {
      await pumpKeeper(tester);
      final state = tester.state<KeeperFigureState>(find.byType(KeeperFigure));
      expect(state.swaying, isFalse);
      expect(painterOf(tester).sway, 0, reason: 'still on his line');
    });

    testWidgets('an unknown tier falls back rather than throwing', (
      tester,
    ) async {
      await pumpKeeper(tester, tier: 99);
      expect(painterOf(tester).kit, keeperKitFor(3));
    });
  });
}
