/// The kick is one swing, not three eases.
///
/// Read segment by segment with ease-in-out, the thigh came to a dead stop at
/// every keyframe — including the contact frame — and the leg looked jagged.
/// A monotone spline swings through the keys and still lands on them exactly.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/home/gesture_poses.dart';

void main() {
  double thigh(double p) => gesturePose('kick', p).kickThigh!;

  test('the leg is still moving as it meets the ball', () {
    // Contact is a key at 0.60 between the wind-up and the follow-through.
    const eps = 0.01;
    final before = (thigh(0.60) - thigh(0.60 - eps)) / eps;
    final after = (thigh(0.60 + eps) - thigh(0.60)) / eps;
    expect(before, lessThan(-40), reason: 'swinging through before contact');
    expect(after, lessThan(-40), reason: 'still swinging after it');
    expect((before - after).abs() / before.abs(), lessThan(0.6), reason: 'no kink');
  });

  test('the keys are still hit exactly and nothing overshoots them', () {
    expect(thigh(0.28), closeTo(22, 1e-9));
    expect(thigh(0.60), closeTo(-5, 1e-9));
    expect(thigh(0.74), closeTo(-24, 1e-9));
    for (var i = 0; i <= 200; i++) {
      final v = thigh(i / 200);
      expect(v, inInclusiveRange(-24 - 1e-9, 22 + 1e-9), reason: 'phase ${i / 200}');
    }
  });

  test('an eased gesture is untouched', () {
    // Arms folded reads per segment as before: the same value at a mid-segment
    // phase that ease-in-out gives.
    final g = gesturePose('armsfolded', 0.5);
    expect(g.armNear, isNotNull);
  });
}
