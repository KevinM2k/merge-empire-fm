/// The manager walks on something.
///
/// A walk cycle with nothing moving under it is a man treading air, so the
/// scene's job is the GROUND: mown lanes travelling at his stride, tufts at the
/// speed of the turf they stand in, and a stand behind them that barely moves.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_scene.dart';
import 'package:merge_empire_fc/ui/theme/sky.dart';

void main() {
  Future<void> pumpScene(
    WidgetTester tester, {
    Mood mood = Mood.neutral,
    int tier = 1,
    Brightness brightness = Brightness.dark,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(400, 800),
          disableAnimations: true,
        ),
        // An inner `Theme` rather than `MaterialApp.theme`: the app's own is
        // wrapped in an `AnimatedTheme`, which LERPS to a new one over 200ms —
        // so a re-pump with the other brightness read back as the old one and
        // "the sky follows the theme" passed while the sky had not moved.
        child: Theme(
          data: ThemeData(brightness: brightness),
          child: Scaffold(
            body: PitchScene(
              mood: mood,
              tier: tier,
              walkerBottom: 150 + walkerBottomClearance,
              walker: const SizedBox(width: 120, height: 170),
            ),
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
      expect(
        box.height,
        greaterThan(tester.getRect(find.byType(PitchScene)).height * 0.5),
      );
      expect(box.width, tester.getRect(find.byType(PitchScene)).width);
    });

    testWidgets('and the mown surface fills it', (tester) async {
      await pumpScene(tester);
      final mow = find.byKey(const ValueKey('pitch-mown'));
      expect(mow, findsOneWidget, reason: 'nothing mows the pitch');
      final turf = tester.getRect(find.byKey(const ValueKey('pitch-turf')));
      final box = tester.getRect(mow);
      expect(box.height, closeTo(turf.height, 1));
      expect(box.width, closeTo(turf.width, 1));
    });

    testWidgets('and the thing that actually PAINTS has height too', (
      tester,
    ) async {
      // A box measuring right is not the same claim as the pitch being on
      // screen, and the difference is exactly how this shipped broken: the
      // lanes were `Expanded` `ColoredBox`es under a Row whose default centre
      // alignment handed them LOOSE heights, so they came out 42x0. Every box
      // above them measured correctly and the player saw sky.
      await pumpScene(tester);
      final painters = find.descendant(
        of: find.byKey(const ValueKey('pitch-mown')),
        matching: find.byType(CustomPaint),
      );
      expect(painters, findsWidgets, reason: 'nothing paints the turf');
      for (final element in painters.evaluate()) {
        final size = (element.renderObject! as RenderBox).size;
        expect(
          size.height,
          greaterThan(8),
          reason: 'the painted surface collapsed to ${size.height}px',
        );
      }
    });

    testWidgets('and the stand is behind it, not over it', (tester) async {
      await pumpScene(tester);
      final stand = tester.getRect(find.byKey(const ValueKey('pitch-stand')));
      final turf = tester.getRect(find.byKey(const ValueKey('pitch-turf')));
      expect(stand.bottom, lessThanOrEqualTo(turf.top + 1));
    });

    testWidgets('and the crowd is a terrace, not a quarter of the page', (
      tester,
    ) async {
      // At `h * 0.24` the stand was a 200px bank with a hundred 1px dots in it,
      // which is the shape of a crowd without being one. It is the TERRACE's own
      // height now — six rows of seats and a fascia.
      await pumpScene(tester);
      final stand = tester.getRect(find.byKey(const ValueKey('pitch-stand')));
      expect(stand.height, closeTo(standHeight, 0.5));
      expect(stand.height, lessThan(120));
    });
  });

  group('the floodlights', () {
    const pylons = ValueKey('pitch-floodlights');
    const wash = ValueKey('pitch-floodlight-wash');

    testWidgets('a park ground has none, at either hour', (tester) async {
      for (final brightness in Brightness.values) {
        await pumpScene(tester, tier: 1, brightness: brightness);
        expect(find.byKey(pylons), findsNothing);
        expect(find.byKey(wash), findsNothing);
      }
    });

    testWidgets('they are BUILT by the tier, so they stand in daylight too', (
      tester,
    ) async {
      await pumpScene(tester, tier: 5, brightness: Brightness.light);
      expect(find.byKey(pylons), findsOneWidget);
      // Standing, and unlit: nothing washes the pitch in the afternoon.
      expect(find.byKey(wash), findsNothing);
    });

    testWidgets('and they are LIT by the theme', (tester) async {
      await pumpScene(tester, tier: 5, brightness: Brightness.dark);
      expect(find.byKey(pylons), findsOneWidget);
      expect(find.byKey(wash), findsOneWidget);
    });

    testWidgets('they rise clear of the roof and stay inside the frame', (
      tester,
    ) async {
      await pumpScene(tester, tier: 8, brightness: Brightness.dark);
      final scene = tester.getRect(find.byType(PitchScene));
      final pylon = tester.getRect(find.byKey(pylons));
      final stand = tester.getRect(find.byKey(const ValueKey('pitch-stand')));
      // Taller than the terrace — a floodlight that stops at the fascia is a
      // post.
      expect(pylon.height, greaterThan(stand.height * 1.5));
      // And its head is on screen. The strip is a fraction of the scene capped
      // by the sky above the horizon, so a short scene must clamp rather than
      // push the lamps out through the top.
      expect(pylon.top, greaterThanOrEqualTo(scene.top - 0.5));
      // Planted at the stand's foot — which is the BACK of the hoardings, so
      // the boards run in front of the pole exactly as they run in front of the
      // front row.
      expect(pylon.bottom, closeTo(stand.bottom, 1));
    });

    testWidgets('and they scroll with the stand, not against it', (
      tester,
    ) async {
      // A pylon is planted in the ground the terrace sits on. Same period and
      // same segment width is the only way they cannot drift apart.
      await pumpScene(tester, tier: 8, brightness: Brightness.dark);
      final pylon = tester.getRect(find.byKey(pylons));
      final stand = tester.getRect(find.byKey(const ValueKey('pitch-stand')));
      expect(pylon.width, stand.width);
    });
  });

  group('the sky', () {
    testWidgets('follows the THEME', (tester) async {
      await pumpScene(tester, brightness: Brightness.light);
      final day = _skyOf(tester);
      await pumpScene(tester, brightness: Brightness.dark);
      final night = _skyOf(tester);
      expect(day, isNot(night));
      expect(
        day.colors.first.r + day.colors.first.g + day.colors.first.b,
        greaterThan(
          night.colors.first.r + night.colors.first.g + night.colors.first.b,
        ),
      );
    });

    testWidgets('and the TIER inside it', (tester) async {
      await pumpScene(tester, tier: 1, brightness: Brightness.light);
      final park = _skyOf(tester);
      await pumpScene(tester, tier: 8, brightness: Brightness.light);
      expect(_skyOf(tester), isNot(park));
    });

    testWidgets('and the GRASS is lit by the same decision', (tester) async {
      // A sunlit pitch under a night sky was the thing that gave away that the
      // two halves of the diorama were each deciding their own light. There is
      // one answer to "is it night" now, so they can only agree.
      await pumpScene(tester, brightness: Brightness.light);
      final day = _turfOf(tester);
      await pumpScene(tester, brightness: Brightness.dark);
      final night = _turfOf(tester);
      expect(day, isNot(night));
      for (var i = 0; i < day.colors.length; i++) {
        expect(
          day.colors[i].g,
          greaterThan(night.colors[i].g),
          reason: 'stop $i is no brighter in daylight than under the lamps',
        );
      }
    });

    testWidgets('and it is the sky the sky file says it is', (tester) async {
      // One source, because the match page stands on the same one and arriving
      // at a match must not be arriving in a different world.
      await pumpScene(tester, tier: 6, brightness: Brightness.dark);
      expect(
        _skyOf(tester).colors,
        skyGradient(brightness: Brightness.dark, tier: 6).colors,
      );
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
      expect(grassDuration(Mood.elated) < grassDuration(Mood.crushed), isTrue);
    });

    test('EVERY layer on the turf travels at the fan\'s speed for its own row', () {
      // **The one thing that has to be true, and it was not.** The tuft bands used
      // to carry ratios measured against BAND 0 rather than against his contact
      // row, and the whole layer ran 17.7% slower than the stripes it grows in — a
      // moonwalk between two layers of the same grass, on every screen.
      //
      // Checked as the ratio of each layer's own speed to the fan's at that row,
      // which has to be 1 for all of them.
      const turfHeight = 320.0;
      const contact = 114.0;
      const mood = Mood.neutral;
      final ground = groundSpeedPxPerSec(mood);
      // The fan is solved at his row, so that is the reference.
      final contactDepth = 0.58 * turfHeight + contact;

      double speedOf(Duration d, double segment) =>
          segment / (d.inMicroseconds / 1e6);

      for (var band = 0; band < 3; band++) {
        final fraction = tuftBandFraction(band);
        final rowDepth = 0.58 * turfHeight + (1 - fraction) * turfHeight;
        final fanSpeed = ground * rowDepth / contactDepth;
        final tuftSpeed = speedOf(
          turfScroll(
            segmentWidth: groundSegmentWidth,
            fraction: fraction,
            turfHeight: turfHeight,
            contactBelowHorizon: contact,
            mood: mood,
          ),
          groundSegmentWidth,
        );
        expect(
          tuftSpeed / fanSpeed,
          closeTo(1, 0.001),
          reason: 'band $band slides against the stripes it grows in',
        );
      }

      // And the boards, which are planted on the horizon.
      final boardDepth = 0.58 * turfHeight;
      final boardSpeed = speedOf(
        turfScroll(
          segmentWidth: hoardingSegmentWidth,
          fraction: 1,
          turfHeight: turfHeight,
          contactBelowHorizon: contact,
          mood: mood,
        ),
        hoardingSegmentWidth,
      );
      expect(
        boardSpeed / (ground * boardDepth / contactDepth),
        closeTo(1, 0.001),
        reason: 'the advertising crawls against the grass at its feet',
      );
    });

    test('the trim is the ONE knob, and everything follows it', () {
      // It exists because the JS's poses have no single planted-foot rate to
      // derive from — see `groundSpeedTrim`. What matters is that it is not a
      // fudge on one layer: move it and every strip on the turf moves with it,
      // which is what stops someone speeding up the stripes and leaving the
      // tufts behind.
      expect(
        groundSpeedPxPerSec(Mood.neutral),
        closeTo(
          groundSpeedTrim *
              walkerStrideArtUnits *
              walkerScale /
              (walkDurationFor(Mood.neutral).inMicroseconds / 2e6),
          1e-6,
        ),
      );
      // And it is a speed-UP, not a brake: he read as dragging his feet at 1.0.
      expect(groundSpeedTrim, greaterThan(1));
    });

    test(
      'and further up the pitch is slower, which is what perspective IS',
      () {
        const turfHeight = 320.0;
        var last = Duration.zero;
        for (var band = 0; band < 3; band++) {
          final d = turfScroll(
            segmentWidth: groundSegmentWidth,
            fraction: tuftBandFraction(band),
            turfHeight: turfHeight,
            contactBelowHorizon: 114,
            mood: Mood.neutral,
          );
          expect(d, greaterThan(last), reason: 'band $band is not slower');
          last = d;
        }
      },
    );
  });
}

/// The gradient the scene actually painted its sky with — the first full-bleed
/// `DecoratedBox` in the stack.
LinearGradient _skyOf(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(PitchScene),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return (box.decoration as BoxDecoration).gradient! as LinearGradient;
}

/// The grass's own gradient — the first `DecoratedBox` inside the turf box.
LinearGradient _turfOf(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byKey(const ValueKey('pitch-turf')),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return (box.decoration as BoxDecoration).gradient! as LinearGradient;
}
