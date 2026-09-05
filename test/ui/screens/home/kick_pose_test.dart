/// The kick: the near leg alone, cued by the stray ball, contact at 0.6 — ON
/// the ball. And the flick, its little brother, before a pickup.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/gesture_poses.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';

void main() {
  test('the near leg draws back, then comes through to the ball', () {
    final windup = gesturePose('kick', 0.28);
    final contact = gesturePose('kick', 0.6);
    final start = gesturePose('kick', 0.0);
    final end = gesturePose('kick', 1.0);
    expect(windup.kickThigh, greaterThan(15), reason: 'positive is backwards');
    expect(windup.kickShin, greaterThan(40), reason: 'the knee folds first');
    expect(contact.kickShin!.abs(), lessThan(10), reason: 'leg straight');
    // **THE ENDS MEET THE WALK.** The cue fires with the near leg at the back
    // of its stride, so the track opens already wound rather than at zero;
    // and it ends out in front with the knee folding, which is where the
    // stride has the leg by then. Opening at 0 and closing at 0 was a
    // seventeen-degree lurch in three frames at each end — the "jaggidy" kick.
    expect(start.kickThigh, closeTo(windup.kickThigh!, 1e-9));
    expect(end.kickThigh, inInclusiveRange(-16, -8));
    expect(end.kickShin, greaterThan(20));
  });

  test('THE TOE IS ON THE BALL AT CONTACT', () {
    // The ball is trapped at his boot with its back face at `ballRearX`; the
    // contact frame has to put the toe into the rear half of it, not a boot's
    // length past it where the ball drawn over the leg swallowed the foot.
    final contact = gesturePose('kick', 0.6);
    final toe = kickToeX(contact.kickThigh!, contact.kickShin!);
    expect(toe, greaterThan(ballRearX), reason: 'the boot stops short');
    expect(toe, lessThan(ballCentreX), reason: 'the boot is through the ball');
    // And the flick's toe goes under the same ball.
    final scoop = gesturePose('flick', 0.55);
    final flickToe = kickToeX(scoop.kickThigh!, scoop.kickShin!);
    expect(flickToe, greaterThan(ballRearX - 1));
    expect(flickToe, lessThan(ballCentreX));
  });

  test('the follow-through is small: the ball has gone', () {
    for (var phase = 0.62; phase <= 1.0; phase += 0.02) {
      final thigh = gesturePose('kick', phase).kickThigh!;
      expect(thigh, greaterThan(-30), reason: 'a hoof at $phase');
    }
    // And by the end it has settled toward where the stride is taking it.
    expect(
      gesturePose('kick', 0.97).kickThigh!,
      closeTo(gesturePose('kick', 1.0).kickThigh!, 2),
    );
  });

  test('the kick OWNS the leg through its middle and hands it back', () {
    expect(kickBlendAt(0), 0);
    expect(kickBlendAt(0.5), 1);
    expect(kickBlendAt(1), 0);
    expect(kickBlendAt(0.06), inExclusiveRange(0, 1));
    expect(kickBlendAt(0.94), inExclusiveRange(0, 1));
  });

  test('the flick is a smaller kick', () {
    final kick = gesturePose('kick', 0.28).kickThigh!;
    final flick = gesturePose('flick', 0.28).kickThigh!;
    expect(flick, greaterThan(0));
    expect(flick, lessThan(kick / 2));
    expect(gesturePose('flick', 1).kickThigh, closeTo(0, 1e-9));
  });

  test('every other gesture leaves the kick alone', () {
    for (final g in gestures) {
      final p = gesturePose(g.id, 0.5, gestureMs: g.ms);
      expect(p.kickThigh, isNull, reason: g.id);
      expect(p.kickShin, isNull, reason: g.id);
    }
  });

  test('and neither is on the rota or in the wardrobe', () {
    expect(gestures.where((g) => g.id == 'kick' || g.id == 'flick'), isEmpty);
  });
}
