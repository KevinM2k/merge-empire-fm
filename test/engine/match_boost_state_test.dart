import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/match_boost_state.dart';

void main() {
  group('MatchBoostState', () {
    test('starts empty and neutral', () {
      final s = MatchBoostState();
      expect(s.live, isEmpty);
      expect(s.ratingMultAt(10), 1.0);
      expect(s.ourAttackMultAt(10), 1.0);
      expect(s.oppAttackMultAt(10), 1.0);
    });

    test('a window runs from its start for its length', () {
      final s = MatchBoostState()..start('crowd_roar', 40, 25);
      expect(s.live.single.fromMinute, 40);
      expect(s.live.single.toMinute, 65);
      expect(s.ratingMultAt(40), closeTo(crowdRoarMult, 1e-9));
      expect(s.ratingMultAt(64), closeTo(crowdRoarMult, 1e-9));
      expect(s.ratingMultAt(65), 1.0);
      expect(s.ratingMultAt(39), 1.0);
    });

    // Boosts stack — they were never one-at-a-time.
    /// **A SECOND ROAR RESTARTS THE FIRST, it does not pile on top of it.**
    /// Asked for from the couch, in those terms: "if they tap it again and it's
    /// only 70% down, it just goes up to 100% again — not stacked."
    test('A SECOND ROAR RESTARTS THE WINDOW RATHER THAN STACKING', () {
      final s = MatchBoostState()
        ..start('crowd_roar', 40, 25)
        ..start('crowd_roar', 45, 25);
      // One window, not two — which is what sends the aura ring back to whole.
      expect(s.activeAt(50), hasLength(1));
      expect(s.ratingMultAt(50), closeTo(crowdRoarMult, 1e-9));
      // It runs from the SECOND tap, so the first window's tail is gone: 45+25.
      expect(s.activeAt(50).single.fromMinute, 45);
      expect(s.endOf('crowd_roar'), 70);
      // And the minute the first one would have covered alone is no longer
      // covered by anything, because the first window no longer exists.
      expect(s.ratingMultAt(42), closeTo(1.0, 1e-9));
    });

    test('however many times it is tapped, it is one window', () {
      final s = MatchBoostState();
      for (var i = 0; i < 6; i++) {
        s.start('crowd_roar', 40, 25);
      }
      expect(s.activeAt(50), hasLength(1));
      expect(s.ratingMultAt(50), closeTo(crowdRoarMult, 1e-9));
    });

    test('Roar and Bus are different axes and do not interfere', () {
      final s = MatchBoostState()
        ..start('crowd_roar', 40, 25)
        ..start('park_the_bus', 40, 25);
      expect(s.ratingMultAt(50), closeTo(crowdRoarMult, 1e-9));
      expect(s.oppAttackMultAt(50), closeTo(parkTheBusAttack, 1e-9));
      expect(s.ourAttackMultAt(50), closeTo(parkTheBusAttack, 1e-9));
    });

    // Two buses are one bus: the lift is a state, not a product.
    test('a second Bus does not stack', () {
      final s = MatchBoostState()
        ..start('park_the_bus', 40, 25)
        ..start('park_the_bus', 41, 25);
      expect(s.oppAttackMultAt(50), closeTo(parkTheBusAttack, 1e-9));
      expect(s.ourAttackMultAt(50), closeTo(parkTheBusAttack, 1e-9));
    });

    test('a retrospective boost has no window and starts nothing', () {
      final s = MatchBoostState()..start('var_review', 40, 0);
      expect(s.live, isEmpty);
    });

    test('expireThrough reports the windows that just closed, once', () {
      final s = MatchBoostState()..start('crowd_roar', 40, 25);
      expect(s.expireThrough(64), isEmpty);
      expect(s.expireThrough(65).map((b) => b.id), ['crowd_roar']);
      expect(s.live, isEmpty);
      expect(s.expireThrough(70), isEmpty);
    });

    test('activeAt lists what is live at a minute, for the bar', () {
      final s = MatchBoostState()
        ..start('crowd_roar', 40, 25)
        ..start('park_the_bus', 60, 25);
      expect(s.activeAt(50).map((b) => b.id), ['crowd_roar']);
      expect(s.activeAt(62).map((b) => b.id), ['crowd_roar', 'park_the_bus']);
      expect(s.activeAt(70).map((b) => b.id), ['park_the_bus']);
    });

    test('the end minute a boost of this id runs to, for the strip', () {
      final s = MatchBoostState()
        ..start('crowd_roar', 40, 25)
        ..start('crowd_roar', 50, 25);
      // The restart's own end, which is the only window there is.
      expect(s.endOf('crowd_roar'), 75);
      expect(s.endOf('park_the_bus'), isNull);
    });

    /// **DIFFERENT boosts still stack — it is only the same one that cannot.**
    /// Asked for in the same breath: "they can stack crowd roar and shooting
    /// target, but not the same one."
    test('A ROAR AND A SHARP SHOOTING RUN TOGETHER', () {
      final s = MatchBoostState()
        ..start('crowd_roar', 40, 25)
        ..start('sharp_shooting', 45, 25);
      expect(s.activeAt(50), hasLength(2));
      expect(s.ratingMultAt(50), closeTo(crowdRoarMult, 1e-9));
      expect(s.ourAttackMultAt(50), closeTo(sharpShootingAttack, 1e-9));
    });

    test('sharp shooting is OUR attack alone, and a bus trims it back', () {
      final s = MatchBoostState()..start('sharp_shooting', 40, 25);
      expect(s.ourAttackMultAt(50), sharpShootingAttack);
      expect(s.oppAttackMultAt(50), 1.0);
      expect(s.ourAttackMultAt(70), 1.0);
      s.start('park_the_bus', 50, 25);
      expect(s.oppAttackMultAt(60), parkTheBusAttack);
      expect(s.ourAttackMultAt(60), closeTo(sharpShootingAttack * parkTheBusAttack, 1e-9));
    });
  });
}
