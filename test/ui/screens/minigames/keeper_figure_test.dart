/// The penalty keeper.
///
/// He was five flat rectangles with the arms permanently out. The JS has eight
/// kit tiers and a rig; both are ported, and the posing is Flutter's own
/// animated transforms rather than a clock in the widget.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/keeper_art.g.dart';
import 'package:merge_empire_fc/ui/screens/minigames/keeper_figure.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/widgets/svg_canvas.dart';

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

double turnsOf(WidgetTester tester, Key key) =>
    tester.widget<AnimatedRotation>(find.byKey(key)).turns;

void main() {
  group('the art', () {
    test('there is a kit for every tier the palette names', () {
      expect(keeperArt.keys, containsAll([for (var t = 1; t <= 8; t++) t]));
      expect(keeperLayers.keys, keeperArt.keys);
    });

    test('every tier is cut into five pieces, each of them drawable', () {
      for (final entry in keeperLayers.entries) {
        final layers = entry.value;
        for (final svg in [
          layers.body,
          layers.armL,
          layers.armR,
          layers.legL,
          layers.legR,
        ]) {
          expect(parseSvg(svg), isNotEmpty, reason: 'tier ${entry.key}');
        }
      }
    });

    test('a limb carries the gradient its sleeve is painted with', () {
      // Cut out of the whole figure, so the `<defs>` had to come with it — a
      // layer that left the definition behind draws an unpainted arm.
      final layers = keeperLayers[3]!;
      expect(parseGradients(layers.armL), isNotEmpty);
      expect(parseGradients(layers.armR), isNotEmpty);
    });

    test('the body no longer holds the limbs it was cut from', () {
      final layers = keeperLayers[3]!;
      expect(layers.body, isNot(contains('k-arm-l')));
      expect(layers.body, isNot(contains('k-leg-r')));
      expect(layers.body, contains('<defs>'), reason: 'it keeps the palette');
    });

    test('the number on the shirt is the tier', () {
      for (final tier in keeperArt.keys) {
        final text = RegExp(
          r'<text[^>]*>\s*(\d)\s*</text>',
        ).firstMatch(keeperArt[tier]!);
        expect(text?.group(1), '$tier');
      }
    });

    test('the palette really differs by tier', () {
      // The point of eight of them: a Champions Cup keeper must not look like a
      // Sunday League one.
      expect(keeperArt[2], isNot(keeperArt[8]));
    });
  });

  group('which kit', () {
    test('rises with the division, and stops at the top', () {
      expect(keeperTierForDivision(0), 2, reason: 'Sunday League');
      expect(keeperTierForDivision(3), 5);
      expect(keeperTierForDivision(6), 8, reason: 'Champions Cup');
      expect(keeperTierForDivision(99), 8);
      expect(keeperTierForDivision(-4), 2);
    });
  });

  group('the pose', () {
    test('a low shot lays him out, a high one only leans him', () {
      // A keeper full-length at a shot into the top corner looked like he had
      // simply fallen over.
      expect(KeeperPose.lowLeft.bodyDegrees, -75);
      expect(KeeperPose.highLeft.bodyDegrees, -22);
      expect(KeeperPose.lowRight.bodyDegrees, 75);
      expect(KeeperPose.highRight.bodyDegrees, 22);
      expect(KeeperPose.ready.bodyDegrees, 0);
    });

    test('the lead arm reaches further than the trailing one', () {
      expect(
        KeeperPose.lowLeft.armLeftDegrees.abs(),
        greaterThan(KeeperPose.lowLeft.armRightDegrees.abs()),
      );
      expect(
        KeeperPose.lowRight.armRightDegrees.abs(),
        greaterThan(KeeperPose.lowRight.armLeftDegrees.abs()),
      );
    });

    test('standing still means standing still', () {
      expect(KeeperPose.ready.armLeftDegrees, 0);
      expect(KeeperPose.ready.legRightDegrees, 0);
      expect(KeeperPose.ready.diving, isFalse);
    });

    test('a dive is picked from which side of the goal the ball went', () {
      expect(poseFor(x: 20, y: 40, midX: 50), KeeperPose.lowLeft);
      expect(poseFor(x: 20, y: 10, midX: 50), KeeperPose.highLeft);
      expect(poseFor(x: 80, y: 40, midX: 50), KeeperPose.lowRight);
      expect(poseFor(x: 80, y: 10, midX: 50), KeeperPose.highRight);
    });
  });

  group('the figure', () {
    testWidgets('stands with every limb square', (tester) async {
      await pumpKeeper(tester);
      expect(turnsOf(tester, const ValueKey('penalty-keeper')), 0);
      for (final joint in ['armL', 'armR', 'legL', 'legR']) {
        expect(turnsOf(tester, ValueKey('keeper-limb-$joint')), 0);
      }
    });

    testWidgets('and a dive turns the body AND the four limbs', (tester) async {
      await pumpKeeper(tester, pose: KeeperPose.lowRight);
      expect(
        turnsOf(tester, const ValueKey('penalty-keeper')),
        greaterThan(0),
        reason: 'to his right',
      );
      expect(
        turnsOf(tester, const ValueKey('keeper-limb-armR')),
        greaterThan(0),
        reason: 'the lead arm goes with him',
      );
      expect(
        turnsOf(tester, const ValueKey('keeper-limb-legR')),
        lessThan(0),
        reason: 'the push-off leg extends back',
      );
    });

    testWidgets('a limb turns about its own joint, not the middle', (
      tester,
    ) async {
      // A shoulder rotation about the centre of the box swings the arm out of
      // its socket, which is what the CSS transform-origins are for.
      await pumpKeeper(tester, pose: KeeperPose.lowLeft);
      final arm = tester.widget<AnimatedRotation>(
        find.byKey(const ValueKey('keeper-limb-armL')),
      );
      expect(arm.alignment, jointAlignment('armL'));
      expect(arm.alignment, isNot(Alignment.center));
    });

    testWidgets('the whole figure pivots off the ground', (tester) async {
      await pumpKeeper(tester, pose: KeeperPose.lowLeft);
      expect(
        tester
            .widget<AnimatedRotation>(
              find.byKey(const ValueKey('penalty-keeper')),
            )
            .alignment,
        Alignment.bottomCenter,
      );
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
      expect(find.byType(SvgArt), findsWidgets, reason: 'still on his line');
    });

    testWidgets('an unknown tier falls back rather than throwing', (
      tester,
    ) async {
      await pumpKeeper(tester, tier: 99);
      expect(find.byType(SvgArt), findsWidgets);
    });
  });
}
