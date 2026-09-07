/// The rings a press leaves behind, and the promise that they cost nothing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/widgets/tap_ripple.dart';

Widget _app({required Widget child, bool enabled = true, bool motion = true}) =>
    MaterialApp(
      theme: buildAppTheme(kitId: 'red', light: false),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: !motion),
        child: TapRipples(enabled: enabled, child: child),
      ),
    );

void main() {
  group('the stagger', () {
    test('the first ring sets off at once and the last one last', () {
      expect(tapRippleRingProgress(0, 0), 0);
      expect(tapRippleRingProgress(0, 1), isNull);
      expect(tapRippleRingProgress(0, tapRippleRings - 1), isNull);
    });

    test('and every ring has run its whole life before the ripple is dropped', () {
      // A ring still on screen when the ripple is dropped is a ring that
      // vanishes mid-flight, so the LAST one has to land exactly on the end and
      // the ones before it earlier.
      final span = 1 - (tapRippleRings - 1) * tapRippleStagger;
      for (var i = 0; i < tapRippleRings; i++) {
        final ends = i * tapRippleStagger + span;
        expect(ends, lessThanOrEqualTo(1.0001), reason: 'ring $i outlives it');
        expect(
          tapRippleRingProgress(ends - 0.0001, i),
          closeTo(1, 0.001),
          reason: '$i',
        );
        expect(tapRippleRingProgress(ends + 0.0001, i), isNull, reason: '$i');
      }
    });

    test('a ring grows outwards and fades before it stops', () {
      expect(tapRippleRingRadius(0), tapRippleStart);
      expect(tapRippleRingRadius(1), tapRippleStart + tapRippleSpread);
      // Eased out: half the life is well past half the distance.
      expect(
        tapRippleRingRadius(0.5) - tapRippleStart,
        greaterThan(tapRippleSpread * 0.6),
      );
      expect(tapRippleOpacity(1), 0);
      expect(tapRippleOpacity(0.5), lessThan(tapRippleOpacity(0) / 2));
    });
  });

  group('the ring carries its own contrast', () {
    test('NO KIT COLOUR CAN SINK INTO WHAT IT IS DRAWN ON', () {
      // Reported on the match pitch: a green club's ring over dark green grass
      // was nearly invisible. Nothing at the top of the tree knows what is
      // under the finger, so the ring is lifted towards white and backed by a
      // dark halo rather than being tinted to suit a page.
      for (final accent in [
        const Color(0xFF4CAF50), // the default kit — and the grass
        const Color(0xFF1B5E20), // darker still
        const Color(0xFF0D47A1),
        const Color(0xFF880E4F),
        const Color(0xFF212121),
      ]) {
        expect(
          tapRippleInk(accent).computeLuminance(),
          greaterThan(0.45),
          reason: '$accent stays dark enough to lose',
        );
      }
    });
  });

  group('on screen', () {
    testWidgets('A TAP STILL REACHES THE BUTTON UNDERNEATH', (tester) async {
      // The whole reason this is a `Listener` and not a `GestureDetector`: a
      // flourish that wins the arena is a flourish that eats presses.
      var taps = 0;
      await tester.pumpWidget(
        _app(
          child: Center(
            child: ElevatedButton(
              onPressed: () => taps++,
              child: const Text('Play'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('and the overlay does not swallow a press on nothing', (
      tester,
    ) async {
      await tester.pumpWidget(_app(child: const SizedBox.expand()));
      await tester.tapAt(const Offset(40, 40));
      // One frame in, the ring is drawn; a whole life later there is nothing
      // left to draw and the ticker has stopped.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump(tapRippleLife);
      await tester.pump();
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'the ticker is still running over a still screen',
      );
    });

    testWidgets('the switch off means no ticker at all', (tester) async {
      await tester.pumpWidget(
        _app(enabled: false, child: const SizedBox.expand()),
      );
      await tester.tapAt(const Offset(40, 40));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('AND SO DOES REDUCE MOTION', (tester) async {
      // A decoration is exactly what that switch is for.
      await tester.pumpWidget(
        _app(motion: false, child: const SizedBox.expand()),
      );
      await tester.tapAt(const Offset(40, 40));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
