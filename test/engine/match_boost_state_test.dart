import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/match_boost_state.dart';

void main() {
  group('MatchBoostState', () {
    test('starts empty and neutral', () {
      final s = MatchBoostState();
      expect(s.live, isEmpty);
      expect(s.ratingMultAt(10), 1.0);
      expect(s.goalRateMultAt(10), 1.0);
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
    test('TWO ROARS STACK, UNDER A CAP', () {
      final s = MatchBoostState()
        ..start('crowd_roar', 40, 25)
        ..start('crowd_roar', 45, 25);
      // 1.10 * 1.10 = 1.21, under the 1.25 cap.
      expect(s.ratingMultAt(50), closeTo(1.21, 1e-9));
      // Only one is live before the second starts.
      expect(s.ratingMultAt(42), closeTo(1.10, 1e-9));
      // And only the later one after the first ends.
      expect(s.ratingMultAt(66), closeTo(1.10, 1e-9));
    });

    test('the cap holds however many are stacked', () {
      final s = MatchBoostState();
      for (var i = 0; i < 6; i++) {
        s.start('crowd_roar', 40, 25);
      }
      expect(s.ratingMultAt(50), closeTo(maxCrowdRoarStack, 1e-9));
    });

    test('Roar and Bus are different axes and do not interfere', () {
      final s = MatchBoostState()
        ..start('crowd_roar', 40, 25)
        ..start('park_the_bus', 40, 25);
      expect(s.ratingMultAt(50), closeTo(crowdRoarMult, 1e-9));
      expect(s.goalRateMultAt(50), closeTo(parkTheBusGoalRate, 1e-9));
    });

    // Two buses do not make the game twice as dead: the damping is a floor,
    // not a product.
    test('a second Bus does not stack the damping', () {
      final s = MatchBoostState()
        ..start('park_the_bus', 40, 25)
        ..start('park_the_bus', 41, 25);
      expect(s.goalRateMultAt(50), closeTo(parkTheBusGoalRate, 1e-9));
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
      expect(s.endOf('crowd_roar'), 75);
      expect(s.endOf('park_the_bus'), isNull);
    });

    test('sharp shooting is OUR attack alone, on top of a bus', () {
      final s = MatchBoostState()..start('sharp_shooting', 40, 25);
      expect(s.ourAttackMultAt(50), sharpShootingAttack);
      expect(s.goalRateMultAt(50), 1.0);
      expect(s.ourAttackMultAt(70), 1.0);
      s.start('park_the_bus', 50, 25);
      expect(s.goalRateMultAt(60), parkTheBusGoalRate);
      expect(s.ourAttackMultAt(60), sharpShootingAttack);
    });
  });
}
