/// He does not brake — he eases off.
///
/// A gesture that plants his feet has to stop the world travelling past him, and
/// the JS does that in script rather than in CSS because `animation-play-state`
/// is binary: there is nothing between running and paused. `_rampWalk` eases the
/// gait, every strip that scrolls and the stray ball down to zero over 380ms,
/// and back up again after.
///
/// Two things are asserted here that a screenshot could not tell apart from the
/// old hard stop: that the world keeps moving THROUGH the halt, and that the
/// halt ends on its own.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_scene.dart';
import 'package:merge_empire_fc/ui/screens/home/walk_ramp.dart';

void main() {
  group('the ease itself', () {
    test('runs from where it is to where it is going, and no further', () {
      const r = WalkRamp(from: 1, target: 0, since: 0, banked: 0);
      expect(r.rateAt(0), 1);
      expect(r.rateAt(-5), 1, reason: 'nothing happens before it starts');
      expect(r.rateAt(0.38), closeTo(0, 1e-12));
      expect(r.rateAt(9), 0, reason: 'and it stays stopped');
    });

    test('EASE-OUT: most of the speed goes early', () {
      // The JS's `1 - (1-k)²`, and its reason: linear reads as a machine winding
      // down rather than as somebody stopping walking. Half way through the ramp
      // he is already down to a quarter pace.
      const r = WalkRamp(from: 1, target: 0, since: 0, banked: 0);
      expect(r.rateAt(0.19), closeTo(0.25, 1e-9));
      // Which is the same as saying the first half sheds three times what the
      // second half does.
      final first = r.rateAt(0) - r.rateAt(0.19);
      final second = r.rateAt(0.19) - r.rateAt(0.38);
      expect(first, closeTo(second * 3, 1e-9));
    });

    test('the distance is the INTEGRAL of the rate, not a sum of frames', () {
      // The whole reason this is closed form: his legs, the ground and the stray
      // ball each ask independently, and two accumulations of one number drift
      // apart. Checked against a fine numerical sum of the rate.
      for (final (from, target) in const [(1.0, 0.0), (0.0, 1.0), (1.0, 1.0)]) {
        final r = WalkRamp(from: from, target: target, since: 0, banked: 0);
        const n = 20000;
        const span = 0.9; // past the end of the ramp, so the tail counts too
        var sum = 0.0;
        for (var i = 0; i < n; i++) {
          sum += r.rateAt((i + 0.5) / n * span) * span / n;
        }
        expect(
          r.walkedAt(span),
          closeTo(sum, 1e-6),
          reason: 'walking-seconds from $from to $target',
        );
      }
    });

    test('a stop still banks a third of a ramp of walking', () {
      // The mean rate across an ease-out from 1 to 0 is 1/3, so he covers 380/3
      // ms of ground while coming to a halt. It is what stops the world jumping:
      // a hard stop banks nothing and the grass simply ceases.
      const r = WalkRamp(from: 1, target: 0, since: 0, banked: 0);
      expect(r.walkedAt(0.38), closeTo(0.38 / 3, 1e-9));
      expect(r.walkedAt(5), closeTo(0.38 / 3, 1e-9), reason: 'and no more');
    });

    test('reversing mid-ramp starts from the speed he is ACTUALLY at', () {
      // A bow cut short by a tap must wind back up from where the ease had got
      // to, not snap to a stop first and then start again.
      const down = WalkRamp(from: 1, target: 0, since: 0, banked: 0);
      final up = down.aim(1, 0.19);
      expect(up.from, closeTo(0.25, 1e-9));
      expect(
        up.rateAt(0.19),
        closeTo(0.25, 1e-9),
        reason: 'no jump at the turn',
      );
      // And the distance carries across the turn rather than restarting.
      expect(up.walkedAt(0.19), closeTo(down.walkedAt(0.19), 1e-12));
    });
  });

  group('on the diorama', () {
    late ValueNotifier<double>? beat;

    /// Real frames, not one big jump. A `pump(100ms)` is ONE frame carrying a
    /// tenth of a second, and the beat clamps a frame's travel — a ticker muted
    /// by `TickerMode` still counts the time it spent muted, so a tab returned
    /// to after a minute elsewhere would otherwise leap. At sixteen milliseconds
    /// a frame that clamp never fires, which is the case worth testing.
    Future<void> pumpFrames(WidgetTester tester, int ms) async {
      for (var left = ms; left > 0; left -= 16) {
        await tester.pump(Duration(milliseconds: left < 16 ? left : 16));
      }
    }

    Future<void> pumpScene(
      WidgetTester tester, {
      required bool frozen,
      // A pylon is BUILT rather than switched on, so the floodlight strip only
      // exists from tier 4 up — a tier-1 scene has none to hold still.
      int tier = 1,
    }) => tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: Scaffold(
            body: PitchScene(
              mood: Mood.neutral,
              tier: tier,
              frozen: frozen,
              walkerBottom: 150 + walkerBottomClearance,
              // The walker is handed in from the screen above, so this is
              // also the proof that he can SEE the scene's clock — he is
              // inside its subtree.
              walker: Builder(
                builder: (context) {
                  beat = WalkBeat.maybeOf(context);
                  return const SizedBox(width: 120, height: 170);
                },
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('the walker and the ground read ONE clock', (tester) async {
      beat = null;
      await pumpScene(tester, frozen: false);
      expect(
        beat,
        isNotNull,
        reason:
            'the figure is not on the scene\'s beat, so his legs and the grass '
            'under them are two clocks again',
      );
      addTearDown(() => tester.pumpWidget(const SizedBox()));
    });

    testWidgets('THE WORLD KEEPS MOVING THROUGH THE HALT', (tester) async {
      beat = null;
      await pumpScene(tester, frozen: false);
      await pumpFrames(tester, 304);
      final walking = beat!.value;
      expect(walking, greaterThan(0), reason: 'he never set off');

      await pumpScene(tester, frozen: true);
      // One frame in, he is slower but he has NOT stopped — which is the whole
      // difference from the switch this replaced.
      await pumpFrames(tester, 96);
      final easing = beat!.value;
      expect(easing, greaterThan(walking), reason: 'the world stopped dead');

      await pumpFrames(tester, 400);
      final stopped = beat!.value;
      // And it does come to rest: a third of a ramp's worth of stride past the
      // moment he planted his feet, and then nothing.
      await pumpFrames(tester, 400);
      expect(beat!.value, stopped, reason: 'it never actually stopped');

      // The ease banked ground rather than discarding it. Against his stride:
      // 380ms at a mean third of pace, over a half-stride of ~0.725s at neutral.
      final banked = stopped - walking;
      final halfStride = walkDurationFor(Mood.neutral).inMicroseconds / 2e6;
      expect(
        banked,
        closeTo(0.38 / 3 / halfStride, 0.02),
        reason: 'the halt covered $banked half-strides',
      );
      addTearDown(() => tester.pumpWidget(const SizedBox()));
    });

    testWidgets('and it winds back up again', (tester) async {
      beat = null;
      await pumpScene(tester, frozen: false);
      await pumpFrames(tester, 304);
      await pumpScene(tester, frozen: true);
      await pumpFrames(tester, 608);
      final stopped = beat!.value;

      await pumpScene(tester, frozen: false);
      await pumpFrames(tester, 64);
      final easing = beat!.value - stopped;
      await pumpFrames(tester, 608);
      final running = beat!.value;
      expect(
        running,
        greaterThan(stopped),
        reason: 'the world never restarted',
      );
      // Eased rather than switched on: 60ms into the ramp he is at ~28% pace, so
      // the first 60ms cover well under 60ms of walking.
      final halfStride = walkDurationFor(Mood.neutral).inMicroseconds / 2e6;
      expect(
        easing,
        lessThan(0.064 / halfStride * 0.6),
        reason: 'it came back at full pace instead of easing up',
      );
      addTearDown(() => tester.pumpWidget(const SizedBox()));
    });

    testWidgets('reduced motion stops it outright rather than easing', (
      tester,
    ) async {
      beat = null;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: PitchScene(
                mood: Mood.neutral,
                tier: 1,
                walkerBottom: 150 + walkerBottomClearance,
                walker: Builder(
                  builder: (context) {
                    beat = WalkBeat.maybeOf(context);
                    return const SizedBox(width: 120, height: 170);
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await pumpFrames(tester, 496);
      expect(beat!.value, 0, reason: 'he walked with reduced motion on');
    });

    /// Where a strip has slid to, in pixels. `_Scroller` translates its `Row` of
    /// segments, so the Row's own left edge IS the offset — read off the render
    /// tree rather than off a number the scene keeps, because the whole question
    /// is whether the picture moved.
    double stripAt(WidgetTester tester, String key) => tester
        .getTopLeft(
          find
              .descendant(
                of: find.byKey(ValueKey(key)),
                matching: find.byType(Row),
              )
              .first,
        )
        .dx;

    test('and it travels at the speed the controller did', () {
      // The point of converting rather than re-timing: a strip that stops with
      // him but crawls is a second bug. One second of full-pace walking has to
      // move it exactly one period's worth of its own segment — which is what
      // `repeat()` over that duration was doing.
      const period = Duration(milliseconds: 16500);
      final halfStride = walkDurationFor(Mood.neutral).inMicroseconds / 2e6;
      final worldXPerSecond = halfStridePx() / halfStride;
      expect(
        parallaxOffset(
          worldXPerSecond,
          segmentWidth: farSegmentWidth,
          period: period,
          mood: Mood.neutral,
        ),
        closeTo(farSegmentWidth / 16.5, 1e-9),
      );
      // And nothing moves at all when the world has not, which is the halt.
      expect(
        parallaxOffset(
          0,
          segmentWidth: farSegmentWidth,
          period: period,
          mood: Mood.neutral,
        ),
        0,
      );
    });

    testWidgets('THE BACKGROUND COMES TO REST WITH HIM', (tester) async {
      // He stopped and the stand, the floodlights and the advertising kept
      // sliding past him — a man standing still on a world that is still
      // travelling, which is the one thing a parallax scene cannot get away
      // with. Only the turf was ever on his clock; everything behind the
      // horizon free-ran on a controller of its own, and a controller has no
      // rate to vary.
      beat = null;
      await pumpScene(tester, frozen: false, tier: 7);
      await pumpFrames(tester, 304);
      const strips = ['pitch-stand', 'pitch-floodlights', 'pitch-hoardings'];
      final walking = {for (final s in strips) s: stripAt(tester, s)};

      // Well past the ramp, so the world has genuinely stopped rather than
      // being mid-ease.
      await pumpScene(tester, frozen: true, tier: 7);
      await pumpFrames(tester, 800);
      expect(beat!.value, greaterThan(0), reason: 'he never set off');
      final stopped = {for (final s in strips) s: stripAt(tester, s)};
      for (final s in strips) {
        expect(
          stopped[s],
          isNot(walking[s]),
          reason: '$s never moved at all, so this proves nothing',
        );
      }

      await pumpFrames(tester, 800);
      for (final s in strips) {
        expect(
          stripAt(tester, s),
          stopped[s],
          reason: '$s kept travelling past a man standing still',
        );
      }
      addTearDown(() => tester.pumpWidget(const SizedBox()));
    });
  });

  group('a preview clock, for a walker with no diorama', () {
    Future<double> beatAfter(
      WidgetTester tester,
      int ms, {
      bool reduceMotion = false,
    }) async {
      double? seen;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: WalkClock(
              stride: walkDurationFor(Mood.pleased),
              child: Builder(
                builder: (context) {
                  final beat = WalkBeat.maybeOf(context);
                  return ValueListenableBuilder<double>(
                    valueListenable: beat!,
                    builder: (context, value, _) {
                      seen = value;
                      return const SizedBox();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
      for (var left = ms; left > 0; left -= 16) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      return seen ?? 0;
    }

    testWidgets('IT PUBLISHES A BEAT, so a preview and its backdrop agree', (
      tester,
    ) async {
      // The customiser's walker used to fall back to a clock of its own, which
      // is fine until something ELSE in the same box has to agree with him — the
      // backdrop does, because he walks in place and the world moves past him.
      expect(await beatAfter(tester, 320), greaterThan(0));
    });

    testWidgets('and reduce-motion holds it, like the diorama', (tester) async {
      expect(await beatAfter(tester, 320, reduceMotion: true), 0);
    });

    testWidgets('it advances at the STRIDE it was given', (tester) async {
      // Half-strides, so 320ms of a 725ms stride is a little under one.
      final beat = await beatAfter(tester, 320);
      final halfStride = walkDurationFor(Mood.pleased).inMicroseconds / 2e6;
      expect(beat, closeTo(0.32 / halfStride, 0.12));
    });
  });
}
