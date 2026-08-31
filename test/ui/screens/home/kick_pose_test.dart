/// The kick: the near leg alone, cued by the stray ball, contact at 0.6.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/gesture_poses.dart';

void main() {
  test('the near leg draws back, then snaps through at the contact', () {
    final windup = gesturePose('kick', 0.3);
    final contact = gesturePose('kick', 0.6);
    final rest = gesturePose('kick', 1.0);
    expect(windup.kickThigh, greaterThan(15), reason: 'positive is backwards');
    expect(windup.kickShin, greaterThan(40), reason: 'the knee folds first');
    expect(contact.kickThigh, lessThan(-20), reason: 'through the ball');
    expect(contact.kickShin!.abs(), lessThan(10), reason: 'leg straight');
    expect(rest.kickThigh, closeTo(0, 1e-9));
    expect(rest.kickShin, closeTo(0, 1e-9));
  });

  test('AND THE CONTACT IS AS HIGH AS IT GOES', () {
    // He is playing a loose ball back, not volleying it: the boot came up past
    // his own waist on the follow-through and the swing read as a wild hoof.
    // Nothing after the contact goes any further than the contact did, and it
    // is down again well before the clip ends.
    final contact = gesturePose('kick', 0.6).kickThigh!;
    expect(contact, greaterThan(-32), reason: 'the boot stops at the ball');
    for (var phase = 0.62; phase <= 1.0; phase += 0.02) {
      final thigh = gesturePose('kick', phase).kickThigh!;
      expect(thigh, greaterThanOrEqualTo(contact - 1e-9), reason: '$phase');
    }
    expect(gesturePose('kick', 0.85).kickThigh!.abs(), lessThan(8));
  });

  test('every other gesture leaves the kick alone', () {
    for (final g in gestures) {
      final p = gesturePose(g.id, 0.5, gestureMs: g.ms);
      expect(p.kickThigh, isNull, reason: g.id);
      expect(p.kickShin, isNull, reason: g.id);
    }
  });

  test('and it is not on the rota or in the wardrobe', () {
    expect(gestures.where((g) => g.id == 'kick'), isEmpty);
  });
}
