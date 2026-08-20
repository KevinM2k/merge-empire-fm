/// The penalty, simulated.
///
/// **The old game was a coin flip** — four corners, one roll, a save if the
/// keeper's corner matched — so there was nothing to test but the roll. What is
/// worth testing about a simulation is different: that it is DETERMINISTIC, that
/// the geometry is the real geometry, that each outcome is reachable, and that
/// the balance the whole thing rests on actually holds — a corner beats a keeper
/// who guesses and does not beat one who read it and went early.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/penalty_physics.dart';

/// Take one kick to its conclusion.
PenaltyKick kick(PenaltyAim aim, {KeeperPlan? plan}) {
  final k = PenaltyKick(
    aim: aim,
    plan: plan ?? (side: 0.0, height: 0.5, commitAt: 0.14),
  );
  while (!k.done && k.elapsed < 6) {
    k.advance(1 / 120);
  }
  return k;
}

/// A keeper who read it and went early — the hardest one in the game.
KeeperPlan reads(PenaltyAim aim) => (
  side: (aim.across / 0.75).clamp(-1.0, 1.0) * 0.98,
  height: aim.lift.abs().clamp(0.0, 1.0),
  commitAt: 0.03,
);

/// A keeper who guessed the wrong way.
KeeperPlan guessesWrong(PenaltyAim aim) => (
  side: aim.across > 0 ? -0.8 : 0.8,
  height: 0.4,
  commitAt: 0.16,
);

const PenaltyAim _corner = (
  across: -0.74,
  lift: 0.62,
  power: 0.9,
  curl: 0.0,
);

void main() {
  group('the geometry is the real geometry', () {
    test('a regulation goal and a regulation spot', () {
      // Guessed numbers in a simulation compound: invent the pitch and every
      // other constant has to be invented to match it.
      expect(goalWidth, 7.32);
      expect(goalHeight, 2.44);
      expect(spotDistance, 11);
    });

    test('and a hard penalty takes about half a second', () {
      // The number the keeper's dive is tuned against. If this moves, the dive
      // times have to move with it.
      final k = kick((across: 0, lift: 0.3, power: 1, curl: 0));
      expect(k.elapsed, greaterThan(0.3));
      expect(k.elapsed, lessThan(0.55));
    });

    test('and a floated one takes twice as long', () {
      final soft = kick((across: 0, lift: 0.45, power: 0.05, curl: 0));
      final hard = kick((across: 0, lift: 0.45, power: 1, curl: 0));
      expect(soft.elapsed, greaterThan(hard.elapsed * 1.8));
    });
  });

  group('it is deterministic', () {
    test('the same aim and the same keeper give the same flight', () {
      // What lets the whole thing be tested without a widget, and what lets a
      // replay be a replay.
      final a = kick(_corner, plan: reads(_corner));
      final b = kick(_corner, plan: reads(_corner));
      expect(a.result, b.result);
      expect(a.position.x, a.position.x);
      expect(b.position.x, closeTo(a.position.x, 1e-9));
      expect(b.position.z, closeTo(a.position.z, 1e-9));
      expect(b.elapsed, closeTo(a.elapsed, 1e-9));
    });

    test('and the step size does not change the answer', () {
      // The integrator subdivides whatever the renderer hands it, so a dropped
      // frame must not change the outcome.
      PenaltyKick at(double dt) {
        final k = PenaltyKick(aim: _corner, plan: reads(_corner));
        while (!k.done && k.elapsed < 6) {
          k.advance(dt);
        }
        return k;
      }

      final smooth = at(1 / 120);
      final janky = at(1 / 12);
      expect(janky.result, smooth.result);
      expect(janky.position.x, closeTo(smooth.position.x, 0.05));
    });
  });

  group('every outcome is reachable', () {
    test('a placed corner past a guessing keeper is a GOAL', () {
      final k = kick(_corner, plan: guessesWrong(_corner));
      expect(k.result, PenaltyResult.goal);
    });

    test('down the middle is SAVED, whatever he does', () {
      // A standing keeper's hands cover the middle, which is the whole reason
      // not to shoot there.
      for (final power in [0.4, 0.7, 1.0]) {
        final aim = (across: 0.0, lift: 0.25, power: power, curl: 0.0);
        expect(kick(aim).result, PenaltyResult.saved, reason: 'at $power');
      }
    });

    test('too high is OVER', () {
      expect(
        kick((across: 0, lift: 1, power: 0.9, curl: 0)).result,
        PenaltyResult.over,
      );
    });

    test('too far across is WIDE', () {
      expect(
        kick((across: 1, lift: 0.3, power: 0.9, curl: 0)).result,
        PenaltyResult.wide,
      );
    });

    test('and the post is a POST, because the ball hit one', () {
      // The ball's centre has to be within a post-plus-ball of the upright. It
      // is a real collision rather than a band of the aim range labelled "post".
      final k = kick((across: -0.79, lift: 0.35, power: 0.9, curl: 0));
      expect(k.hitFrame, FramePart.leftPost);
      expect(k.result, PenaltyResult.frame);
    });

    test('and the bar is the BAR', () {
      final k = kick((across: 0, lift: 0.745, power: 0.9, curl: 0));
      expect(k.hitFrame, FramePart.crossbar);
    });
  });

  group('the balance the game rests on', () {
    test('a keeper who READ it and went early reaches the corner', () {
      // 2.6m of dive plus a 1.05m arm is 3.65 — the post, to the centimetre.
      // Shorter and the corners are free; longer and there is nowhere to shoot.
      final k = kick(_corner, plan: reads(_corner));
      expect(k.result, PenaltyResult.saved);
    });

    test('and the same keeper committing LATE does not', () {
      // The other half of a good keeper, and the trade that makes reading it a
      // skill rather than a switch.
      final late = (
        side: reads(_corner).side,
        height: reads(_corner).height,
        commitAt: 0.22,
      );
      expect(kick(_corner, plan: late).result, PenaltyResult.goal);
    });

    test('a read no longer GUARANTEES a save', () {
      // The old engine made it one, which is what made aim worth nothing.
      final soft = (across: -0.74, lift: 0.62, power: 0.28, curl: 0.0);
      final hard = (across: -0.74, lift: 0.62, power: 1.0, curl: 0.0);
      // Same read, and the harder one is the one that beats him.
      expect(kick(soft, plan: reads(soft)).result, PenaltyResult.saved);
      expect(
        kick(hard, plan: reads(hard)).result,
        isNot(PenaltyResult.saved),
        reason: 'a read keeper saved a corner struck at 31m/s',
      );
    });
  });

  group('spin', () {
    test('curl moves the ball most of a metre across its line', () {
      // The figure the coefficient is TUNED to, pinned here because it is the
      // only thing making side-spin a choice rather than a decoration — and
      // because the textbook constant gives a bend of a few centimetres over
      // 11m, which a player cannot see.
      final straight = kick((across: 0.3, lift: 0.3, power: 0.8, curl: 0));
      final curled = kick((across: 0.3, lift: 0.3, power: 0.8, curl: 1));
      final bend = (curled.position.x - straight.position.x).abs();
      expect(bend, greaterThan(0.5), reason: 'not worth using');
      expect(bend, lessThan(1.4), reason: 'a penalty is not a free kick');
    });

    test('and it curls the way it was told to', () {
      final right = kick((across: 0, lift: 0.3, power: 0.8, curl: 1));
      final left = kick((across: 0, lift: 0.3, power: 0.8, curl: -1));
      expect(right.position.x, greaterThan(left.position.x));
    });

    test('and the ball rolls, so it can be drawn turning', () {
      final k = kick((across: 0, lift: 0.3, power: 0.8, curl: 0));
      expect(k.roll, greaterThan(10));
    });
  });

  group('the keeper plan', () {
    test('a read follows the aim; a guess does not', () {
      final aim = (across: -0.8, lift: 0.6, power: 0.9, curl: 0.0);
      // Seeded so "reads" and "guesses" are both reachable.
      final always = planKeeper(
        readChance: 1,
        aim: aim,
        rng: math.Random(1),
      );
      expect(always.side, lessThan(-0.9), reason: 'he under-committed');
      final never = planKeeper(readChance: 0, aim: aim, rng: math.Random(1));
      expect(never.commitAt, greaterThan(always.commitAt));
    });

    test('and he never dives QUITE the whole way, even reading it', () {
      // A keeper who is exactly right every time he reads it is the coin flip
      // again.
      final plan = planKeeper(
        readChance: 1,
        aim: (across: -1, lift: 0.6, power: 1, curl: 0),
        rng: math.Random(3),
      );
      expect(plan.side.abs(), lessThan(1));
    });
  });
}
