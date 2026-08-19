/// The manager walks on something.
///
/// A walk cycle with nothing moving under it is a man treading air, so the
/// scene's job is the GROUND: mown lanes travelling at his stride, tufts at the
/// speed of the turf they stand in, and a stand behind them that barely moves.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_scene.dart';

void main() {
  Future<void> pumpScene(WidgetTester tester, {Mood mood = Mood.neutral}) =>
      tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: PitchScene(
                mood: mood,
                footerHeight: 150,
                walker: const SizedBox(width: 120, height: 170),
              ),
            ),
          ),
        ),
      );

  group('the ground', () {
    testWidgets('paints, and takes real room on screen', (tester) async {
      await pumpScene(tester);
      final turf = find.byKey(const ValueKey('pitch-turf'));
      expect(turf, findsOneWidget, reason: 'no turf at all');
      final box = tester.getRect(turf);
      // Better than half the scene is ground — the horizon sits at 46%.
      expect(box.height, greaterThan(tester.getRect(find.byType(PitchScene)).height * 0.5));
      expect(box.width, tester.getRect(find.byType(PitchScene)).width);
    });

    testWidgets('and the mown lanes have height to be seen in', (tester) async {
      await pumpScene(tester);
      final lanes = find.byKey(const ValueKey('pitch-mown'));
      expect(lanes, findsWidgets);
      expect(
        tester.getRect(lanes.first).height,
        greaterThan(100),
        reason: 'a lane with no height is an invisible pitch',
      );
    });

    testWidgets('and every scrolling segment has height to be seen in', (
      tester,
    ) async {
      // The scroller's Row must STRETCH its children. Centred, a segment that
      // does not name its own height gets loose constraints and collapses to
      // zero — which is how the whole pitch went missing while the stand, which
      // does name one, kept rendering.
      await pumpScene(tester);
      // The SEGMENT, not the band it sits in — the band is positioned and always
      // reports the right height whether or not anything inside it drew.
      final lanes = find.byKey(const ValueKey('pitch-lane'));
      expect(lanes, findsWidgets, reason: 'no lanes at all');
      final lane = tester.getRect(lanes.first);
      expect(
        lane.height,
        greaterThan(8),
        reason: 'a lane collapsed to ${lane.height}px — the pitch is not there',
      );
      // And it fills the band rather than sitting as a sliver in it.
      final turf = tester.getRect(find.byKey(const ValueKey('pitch-turf')));
      expect(lane.height, closeTo(turf.height, 1));
      expect(lane.width, closeTo(84, 0.5));
    });

    testWidgets('and the stand is behind it, not over it', (tester) async {
      await pumpScene(tester);
      final stand = tester.getRect(find.byKey(const ValueKey('pitch-stand')));
      final turf = tester.getRect(find.byKey(const ValueKey('pitch-turf')));
      expect(stand.bottom, lessThanOrEqualTo(turf.top + 1));
    });
  });

  group('the speeds', () {
    test('the grass is timed off HIS STRIDE, not off a number', () {
      // A fixed ground speed could only plant his feet in one of five moods; in
      // the others he skated, forwards when cheerful and backwards when fed up.
      for (final mood in Mood.values) {
        final stride = walkDurationFor(mood).inMicroseconds;
        final grass = grassDuration(mood).inMicroseconds;
        expect(
          grass / stride,
          closeTo(2.7778, 0.001),
          reason: '$mood: the grass came loose from the stride',
        );
      }
      // A cheerful manager walks faster AND the ground moves faster with him.
      expect(
        grassDuration(Mood.elated) < grassDuration(Mood.crushed),
        isTrue,
      );
    });

    test('and band 0 runs at exactly the turf it stands in', () {
      // A tuft is a clump of the same grass the stripes are mown into. If it
      // slides against them at all, both layers stop being ground.
      expect(tuftBandRatios.first, 1.0);
      // The far bands keep the mowing fan's own proportions.
      expect(tuftBandRatios[1], closeTo(1.1515, 0.0001));
      expect(tuftBandRatios[2], closeTo(1.3737, 0.0001));
    });
  });
}
