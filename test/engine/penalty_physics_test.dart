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
KeeperPlan guessesWrong(PenaltyAim aim) =>
    (side: aim.across > 0 ? -0.8 : 0.8, height: 0.4, commitAt: 0.16);

const PenaltyAim _corner = (across: -0.74, lift: 0.62, power: 0.9, curl: 0.0);

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
      // The FLIGHT, not the clip: a save keeps the ball live afterwards while
      // it is parried away, and that is time on the clock rather than time in
      // the air.
      final k = kick((across: 0, lift: 0.3, power: 1, curl: 0));
      expect(k.flightTime, greaterThan(0.3));
      expect(k.flightTime, lessThan(0.55));
    });

    test('and a floated one takes twice as long', () {
      final soft = kick((across: 0, lift: 0.45, power: 0.05, curl: 0));
      final hard = kick((across: 0, lift: 0.45, power: 1, curl: 0));
      expect(soft.flightTime, greaterThan(hard.flightTime * 1.8));
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
      //
      // Aimed at the OUTSIDE half of it: the inside half sends the ball into the
      // net now, which is the whole point of reflecting rather than reversing —
      // see 'OFF THE FRAME AND IN'.
      final k = kick((across: -0.83, lift: 0.35, power: 0.9, curl: 0));
      expect(k.hitFrame, FramePart.leftPost);
      expect(k.result, PenaltyResult.frame);
    });

    test('and the bar is the BAR', () {
      final k = kick((across: 0, lift: 0.745, power: 0.9, curl: 0));
      expect(k.hitFrame, FramePart.crossbar);
    });
  });

  group('OFF THE FRAME AND IN, or off the frame and out', () {
    /// A keeper who is nowhere near it, so the frame is the only thing the ball
    /// can meet.
    const away = (side: 0.98, height: 0.0, commitAt: 0.02);

    PenaltyKick struck(PenaltyAim aim) => kick(aim, plan: away);

    test('THE UNDERSIDE OF THE BAR PUTS IT IN', () {
      // It could not, ever. Both frame contacts reversed the ball's forward
      // velocity outright and parked it back outside the line, so anything that
      // touched the frame came out — while the one thing everybody knows about a
      // crossbar is that a ball can come down off it and go in.
      //
      // A bounce is a REFLECTION about the surface it hit. A ball rising into
      // the underside of the bar meets a normal pointing down, so what reverses
      // is its climb: it keeps going forward and drops, which is in.
      final under = struck((across: 0, lift: 0.76, power: 0.85, curl: 0));
      expect(under.hitFrame, FramePart.crossbar);
      expect(under.result, PenaltyResult.goal);

      // And higher up the same bar is the top of it, where the normal points up
      // and the ball goes over. One rule, both answers.
      final over = struck((across: 0, lift: 0.82, power: 0.85, curl: 0));
      expect(over.hitFrame, FramePart.crossbar);
      expect(over.result, PenaltyResult.frame);
    });

    test('AND THE INSIDE OF A POST CAN TOO', () {
      // Inside half of the upright: the normal points into the goal, so the ball
      // carries on inward.
      final inside = struck((across: -0.78, lift: 0.3, power: 0.85, curl: 0));
      expect(inside.hitFrame, FramePart.leftPost);
      expect(inside.result, PenaltyResult.goal);

      // Outside half, and it goes away. Same rule again.
      final outside = struck((across: -0.82, lift: 0.3, power: 0.85, curl: 0));
      expect(outside.hitFrame, FramePart.leftPost);
      expect(outside.result, PenaltyResult.frame);
    });

    test('and it still ENDS — a frame cannot be struck for ever', () {
      // The reflection leaves the ball moving away from what it hit, but a ball
      // that re-crossed the line at bar height every step would hammer the same
      // upright until the clock ran out. Each part can be struck once.
      for (var lift = 0.60; lift <= 0.80; lift += 0.005) {
        final k = struck((across: 0, lift: lift, power: 1, curl: 0));
        expect(k.done, isTrue, reason: 'lift \$lift never resolved');
        expect(k.result, isNotNull, reason: 'lift \$lift ended undecided');
      }
    });

    test('a ball off the OUTSIDE of a post stays out', () {
      // The normal points away from the goal there, so the reflection sends it
      // away. Which is the same rule, not a special case.
      final k = struck((across: -0.87, lift: 0.3, power: 0.85, curl: 0));
      if (k.hitFrame == null) return;
      expect(k.result, isNot(PenaltyResult.goal));
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

  group('HE SPREADS HIMSELF BETTER FURTHER UP', () {
    test('the reach RAMPS with the division, and tops out at the documented one', () {
      // The read chance was the only ramp, so a Champions Cup keeper guessed as
      // badly as a Sunday League one and simply guessed right more often. A
      // better keeper also covers more of the goal once he gets there.
      //
      // Ramped DOWNWARD from the top rather than upward from it, deliberately:
      // `keeperReach` plus `keeperDiveSpan` is the post to the centimetre, and
      // that is the number the whole balance rests on. Growing it past the top
      // division would leave nowhere to shoot; the ramp instead makes the LOWER
      // divisions easier, which is the direction a difficulty ramp should run.
      expect(keeperReachFor(6), closeTo(keeperReach, 1e-9));
      expect(keeperReachFor(0), lessThan(keeperReach));
      for (var d = 1; d <= 6; d++) {
        expect(
          keeperReachFor(d),
          greaterThan(keeperReachFor(d - 1)),
          reason: 'division \$d is no better than the one below it',
        );
      }
      // The invariant, still true at the top: a full dive plus the arm is the
      // post.
      expect(keeperDiveSpan + keeperReachFor(6), closeTo(goalHalfWidth, 0.01));
      // And out of range either way rather than throwing.
      expect(keeperReachFor(-3), keeperReachFor(0));
      expect(keeperReachFor(99), keeperReachFor(6));
    });

    test('so the SAME shot beats a Sunday League keeper and not a top one', () {
      // Same aim, same read, same dive — only the spread differs, which is what
      // makes it a ramp on ability rather than on luck.
      // A corner into the top of the goal: inside the top division's reach and
      // 20cm outside Sunday League's.
      const aim = (across: -0.73, lift: 0.65, power: 0.86, curl: 0.0);
      PenaltyKick at(int division) {
        final k = PenaltyKick(
          aim: aim,
          plan: reads(aim),
          reach: keeperReachFor(division),
        );
        while (!k.done && k.elapsed < 6) {
          k.advance(1 / 120);
        }
        return k;
      }

      expect(at(6).result, PenaltyResult.saved);
      expect(at(0).result, PenaltyResult.goal);
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
      final always = planKeeper(readChance: 1, aim: aim, rng: math.Random(1));
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

  group('THE SAVE IS A SAVE, not the ball vanishing', () {
    /// A shot straight at a keeper who is standing still: he gets it.
    PenaltyKick saved({double power = 1}) =>
        kick((across: 0, lift: 0.25, power: power, curl: 0));

    test('the ball is PUSHED AWAY rather than stopped dead', () {
      // It used to set the result and return, which on screen is the ball
      // freezing in mid-air — the one moment of the game the player most wants
      // to watch.
      final k = saved();
      expect(k.result, PenaltyResult.saved);
      expect(k.savedAt, isNotNull);
      expect(k.held, isFalse, reason: 'a struck penalty was gathered');
      // Back out towards the taker, and still moving when the clip ends.
      expect(k.position.y, lessThan(0));
      expect(k.elapsed, greaterThan(k.flightTime));
    });

    test('and it goes OUT to the side the hand met it on', () {
      // A ball met on the outside of the glove goes wide; one met square comes
      // back down the middle. Either way it leaves the goalmouth.
      final k = kick(
        (across: 0.25, lift: 0.25, power: 1, curl: 0),
        plan: (side: 0.32, height: 0.4, commitAt: 0.05),
      );
      if (k.result != PenaltyResult.saved) return;
      expect(k.position.x.abs(), greaterThan(0));
    });

    test('A WEAK ONE IS GATHERED, and that is over sooner', () {
      final soft = saved(power: 0.02);
      expect(soft.result, PenaltyResult.saved);
      expect(soft.held, isTrue, reason: 'a dribbled penalty was parried away');
      // In his gloves: it stops.
      expect(soft.velocity.length, 0);
      final after = soft.elapsed - soft.savedAt!;
      expect(after, lessThan(PenaltyKick.saveFollowThrough));
    });

    test('THE OUTCOME IS UNCHANGED — a save is still a save', () {
      // The whole point of doing this after the result is set: nothing about
      // which way the game went depends on the animation.
      for (final power in [0.02, 0.4, 1.0]) {
        final k = saved(power: power);
        expect(k.result, PenaltyResult.saved, reason: '$power');
      }
    });

    test('and it cannot be saved twice', () {
      // The parry sends the ball back through the goalmouth, and the reach test
      // would happily catch it again on the way out.
      final k = saved();
      final at = k.savedAt;
      k.advance(0.5);
      expect(k.savedAt, at);
    });

    test('the clip ENDS, rather than running for ever', () {
      final k = saved();
      expect(k.done, isTrue);
      expect(k.elapsed, lessThan(k.flightTime + 1.2));
    });
  });

  group('AND HE COMES DOWN — the hand is not a statue', () {
    /// Past [PenaltyKick.done] and on through the hold.
    ///
    /// The screen keeps the goalmouth up for the best part of two seconds after
    /// the word goes up, and the renderer keeps advancing him through it. A kick
    /// that stops being stepped the instant it is decided is the whole defect.
    PenaltyKick settled(PenaltyAim aim, {KeeperPlan? plan}) {
      final k = kick(aim, plan: plan);
      for (var i = 0; i < 150; i++) {
        k.advance(1 / 120);
      }
      return k;
    }

    test('THE ARM WAS FROZEN FOR THE WHOLE FOLLOW-THROUGH', () {
      // `_moveKeeper` clamped its extension and that was the end of him: the ball
      // looped away from the parry while the hands that had just pushed it there
      // held their pose exactly.
      final k = settled((across: 0, lift: 0.25, power: 1, curl: 0));
      expect(k.result, PenaltyResult.saved);
      final peak = 0.55 + k.plan.height * 1.5;
      expect(k.keeperHand.z, lessThan(peak - 0.25), reason: 'he never moved');
      expect(k.keeperLand, 1);
    });

    test('and a GATHERED ball comes down with him', () {
      // Measured from the couch: catch at t=1.15, and ball and hand both sat at
      // exactly (0, 0, 1.00) until the clip ended — which is the same "ball
      // vanishing" defect the parry was written to kill, moved to the hands.
      final k = settled((across: 0, lift: 0.25, power: 0.02, curl: 0));
      expect(k.held, isTrue);
      // Pinned to the gloves, and the gloves are on the turf.
      expect(k.position.z, closeTo(k.keeperHand.z, 1e-9));
      expect(k.position.z, closeTo(keeperGroundZ, 0.01));
      // A keeper who has caught one smothers it; he does not stand there holding
      // it up.
      expect(k.position.z, lessThan(k.keeperHand.z + 1e-9));
    });

    test('HOW FAR HE FALLS IS HOW FAR HE WENT', () {
      // A keeper who dived full length is lying on the turf. One who simply put
      // his hands up is still on his feet, and dropping him to the ground would
      // be a man collapsing rather than a save.
      const aim = (across: -0.74, lift: 0.62, power: 0.95, curl: 0.0);
      final dived = settled(
        aim,
        plan: (side: 0.98, height: 0.9, commitAt: 0.05),
      );
      final stood = settled(
        aim,
        plan: (side: 0.0, height: 0.9, commitAt: 0.05),
      );
      // Never QUITE flat, because he never dives QUITE the whole way — see the
      // keeper plan.
      expect(dived.keeperHand.z, closeTo(keeperGroundZ, 0.02));
      expect(stood.keeperHand.z, closeTo(keeperStandZ, 0.01));
    });

    test('and he STAYS UP while the ball is still live', () {
      // **The landing is timed from the decision, not from full extension**, and
      // it is a deliberate trade: letting gravity have him mid-flight is truer
      // and it changes the balance the whole file is tuned around — a read keeper
      // is a third of the way to the turf when a soft corner arrives and no
      // longer reaches it. What a player watched was the follow-through.
      final k = PenaltyKick(
        aim: (across: -0.6, lift: 0.7, power: 0.1, curl: 0),
        plan: (side: -0.8, height: 0.7, commitAt: 0.03),
      );
      var checked = 0;
      while (!k.done && k.elapsed < 6) {
        k.advance(1 / 240);
        if (k.decidedAt != null) break;
        if (k.elapsed <= k.plan.commitAt) continue;
        expect(k.keeperLand, 0);
        // The extension, and nothing taken off it.
        expect(
          k.keeperHand.z,
          closeTo(0.55 + k.plan.height * 1.5 * k.keeperDive, 1e-9),
          reason: 'he sank at ${k.elapsed}s with the ball still in the air',
        );
        checked++;
      }
      expect(k.decidedAt, isNotNull);
      // A floated one: he is up there a long time, which is the cost of the
      // trade and is what the follow-through is being bought with.
      expect(checked, greaterThan(100));
    });

    test('the dive he is DRAWN at is the dive that moved his hand', () {
      // The renderer worked it out again from the clock on a straight ramp, so
      // the limbs were on a different curve from the glove they hang off — and
      // neither of them knew about the landing.
      final k = PenaltyKick(
        aim: (across: -0.74, lift: 0.62, power: 0.9, curl: 0),
        plan: (side: -0.98, height: 0.6, commitAt: 0.05),
      );
      expect(k.keeperDive, 0);
      while (k.elapsed < 0.05) {
        k.advance(1 / 240);
      }
      k.advance(keeperDiveTime);
      expect(k.keeperDive, closeTo(1, 1e-9));
      expect(
        k.keeperHand.x,
        closeTo(k.plan.side * keeperDiveSpan * k.keeperDive, 1e-9),
      );
    });

    test('and the landing STOPS, rather than sinking through the turf', () {
      final k = settled((across: 0, lift: 0.25, power: 1, curl: 0));
      final z = k.keeperHand.z;
      k.advance(2);
      expect(k.keeperHand.z, closeTo(z, 1e-9));
      expect(k.keeperLand, 1);
    });

    test('THE OUTCOME IS UNCHANGED — none of this decides anything', () {
      // The landing runs after `decidedAt` by construction, so it cannot reach
      // back into `_keeperGotIt`.
      for (final power in [0.02, 0.4, 1.0]) {
        final k = settled((across: 0, lift: 0.25, power: power, curl: 0));
        expect(k.result, PenaltyResult.saved, reason: '$power');
      }
      expect(
        settled(_corner, plan: guessesWrong(_corner)).result,
        PenaltyResult.goal,
      );
      expect(
        settled(_corner, plan: reads(_corner)).result,
        PenaltyResult.saved,
      );
    });
  });
}
