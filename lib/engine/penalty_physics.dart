/// A penalty, simulated rather than decided.
///
/// **THIS REPLACES A COIN FLIP.** The old game picked one of four corners, rolled
/// `keeperSmartChance`, and the shot was a save if the keeper's corner matched —
/// so aim was a menu of four and everything else was luck. Nothing about the
/// striking of a ball was in it, which is most of what a penalty IS.
///
/// Here the OUTCOME IS EMERGENT: a swipe sets a launch velocity and a spin, the
/// ball is integrated forward under gravity, drag and the Magnus force, and
/// whether it goes in depends on where it actually ends up. A post is a post
/// because the ball hit one.
///
/// **Everything is SI and real geometry**, because guessed numbers in a
/// simulation compound: a goal that is 7.32m by 2.44m and a spot 11m out mean a
/// ball struck at 25m/s takes about half a second to arrive, which is the number
/// the keeper's dive has to be tuned against. Invent the pitch and every other
/// constant has to be invented to match.
///
/// **It is DETERMINISTIC.** One seed and one set of inputs give one flight, every
/// time — which is what lets the whole thing be tested without a widget, and what
/// lets a replay be a replay.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

/// The goal, in metres. Regulation.
const double goalWidth = 7.32;
const double goalHeight = 2.44;
const double goalHalfWidth = goalWidth / 2;

/// Post and bar radius. A real one is about 6cm across.
const double postRadius = 0.06;

/// How deep the goal is, front frame to back net. Regulation is at least 1.5m;
/// 1.85 is a typical one.
///
/// **It is not decoration.** A goal resolves when the ball reaches the BACK NET
/// rather than when it crosses the line, which is what lets the net be struck and
/// bulge — and it is why the ball is still on screen, in the net, when the word
/// goes up.
const double goalDepth = 1.85;

/// How far the spot is from the line.
const double spotDistance = 11;

/// A size 5 ball.
const double ballRadius = 0.11;
const double ballMass = 0.43;

/// Gravity, and the two forces that make a struck ball behave like one.
const double gravity = 9.81;

/// Quadratic drag: `½ρACd / m`, which for a football comes out near 0.006 per
/// metre. It is what stops a 30m/s shot arriving at 30m/s.
const double dragCoefficient = 0.0062;

/// The Magnus constant, tuned rather than derived.
///
/// The textbook figure gives a curve so slight over 11m that a player cannot see
/// it, because a real penalty is struck from close range and the bend that reads
/// on television is mostly a much longer free kick. This is the number that makes
/// side-spin worth using from the spot — a hard-struck ball with full spin moves
/// about 0.8m across its flight, which is the difference between the keeper's
/// hand and the inside of the post. A test pins that figure, because it is the
/// only thing making side-spin a choice rather than a decoration.
const double magnusCoefficient = 0.0014;

/// How much of its speed a ball keeps off the frame, and off the turf.
const double frameRestitution = 0.55;
const double groundRestitution = 0.62;

/// A vector in the pitch's own space.
///
/// `x` is across the goal (positive right), `y` is toward it (0 is the goal line,
/// negative is out toward the spot), `z` is up.
class Vec3 {
  Vec3(this.x, this.y, this.z);
  Vec3.zero() : x = 0, y = 0, z = 0;

  double x, y, z;

  double get length => math.sqrt(x * x + y * y + z * z);

  Vec3 clone() => Vec3(x, y, z);

  void addScaled(Vec3 other, double k) {
    x += other.x * k;
    y += other.y * k;
    z += other.z * k;
  }
}

/// How a kick ended.
enum PenaltyResult {
  /// In the net.
  goal,

  /// The keeper got a hand to it.
  saved,

  /// Off the frame and out. A post or the bar — [PenaltyKick.hitFrame] says
  /// which, for the commentary.
  frame,

  /// Past the post.
  wide,

  /// Over the bar.
  over,
}

/// Which part of the frame was struck.
enum FramePart { leftPost, rightPost, crossbar }

/// What the striker did: where they aimed, how hard, and how much they wrapped
/// their foot around it.
///
/// All three come out of ONE swipe, which is the whole input model — a game that
/// asks for a corner and then a power bar has turned a kick into a form.
typedef PenaltyAim = ({
  /// -1 to 1 across the goalmouth. Beyond that is off target, and it has to be
  /// possible to miss or aiming for the corner costs nothing.
  double across,

  /// -1 to 1 vertically. 0 is along the ground, 1 is over the bar.
  double lift,

  /// 0 to 1. Below about 0.3 the keeper has time to get anywhere.
  double power,

  /// -1 to 1. Positive bends the ball to the right of its line.
  double curl,
});

/// The keeper's decision, and how good it is.
///
/// Split from the dive itself so the difficulty ramp is one number in one place:
/// [readChance] is the probability he goes the right way at all, and it is the
/// division's own ramp — five per cent at Sunday League, thirty at the Champions
/// Cup. What the ramp no longer buys is a GUARANTEED save, which is what made the
/// old game a lottery: he still has to reach it.
typedef KeeperPlan = ({
  /// Which way he goes and HOW FAR, -1 full left to 1 full right.
  ///
  /// Continuous rather than three-way, and it matters: on `-1 | 0 | 1` a keeper
  /// who read a shot placed halfway to the post dived the full 2.6 metres and
  /// went straight past it, so reading a shot could make him WORSE than guessing
  /// and staying central. He goes proportionally now.
  double side,

  /// How high he goes, 0 low to 1 high.
  double height,

  /// When he commits, in seconds after the strike. A keeper who waits reads it
  /// but has less time to travel.
  double commitAt,
});

/// The arm, from his shoulders.
const double keeperReach = 1.05;

/// How far his hands travel on a full dive.
///
/// 2.6m plus the arm is 3.65 — which is the post, to the centimetre, and that is
/// the number the whole game balances on: **a perfect corner is only saved by a
/// keeper who read it AND went early.** Shorter and the corners are free; longer
/// and there is nowhere to shoot.
const double keeperDiveSpan = 2.6;

/// How long a full dive takes to extend.
const double keeperDiveTime = 0.42;

/// One penalty, stepped.
class PenaltyKick {
  PenaltyKick({required this.aim, required this.plan, this.timeStep = 1 / 240})
    : position = Vec3(0, -spotDistance, ballRadius),
      velocity = Vec3.zero(),
      spin = Vec3.zero() {
    _launch();
  }

  final PenaltyAim aim;
  final KeeperPlan plan;

  /// The integrator's own step, independent of the frame rate.
  ///
  /// A ball at 30m/s crosses its own diameter in 7ms, so a frame-length step
  /// would tunnel it straight through a post. Fixed and small; the renderer calls
  /// [advance] with however much real time passed and this subdivides it.
  final double timeStep;

  final Vec3 position;
  final Vec3 velocity;

  /// Angular velocity, rad/s. `z` is the side-spin that bends a shot; `x` is the
  /// top- or back-spin that dips or holds it up.
  final Vec3 spin;

  double elapsed = 0;

  /// How far the ball has rolled, for drawing the rotation.
  double roll = 0;

  PenaltyResult? result;
  FramePart? hitFrame;

  /// Where the keeper's hands are, so the renderer does not have to work it out
  /// twice.
  final Vec3 keeperHand = Vec3(0, 0, 0.9);

  bool get done => result != null;

  /// The launch, from the aim.
  ///
  /// The target is a point ON the goal line and the velocity is what reaches it —
  /// so the aim is where the player is pointing rather than an angle they have to
  /// convert in their head. Gravity is then compensated for by the lift, which is
  /// why a hard shot needs less of it than a floated one: the ball has less time
  /// to fall.
  void _launch() {
    // 9 to 31 m/s. The bottom end has to be a genuinely weak penalty — a keeper
    // who has time to get anywhere — or power is not a choice; the top end is
    // about what a struck penalty actually leaves the boot at.
    final speed = 9 + aim.power * 22;
    // A little past the posts is reachable, so a wide shot is a shot the player
    // took and missed rather than one the game refused.
    final targetX = aim.across * (goalHalfWidth + 0.9);
    final targetZ = ballRadius + aim.lift * (goalHeight + 0.7);
    final flight = spotDistance / speed;
    velocity
      ..y = speed
      ..x = targetX / flight
      // Plus what gravity will take back over the flight.
      ..z = (targetZ - position.z) / flight + 0.5 * gravity * flight;
    // Side-spin about the vertical, and a touch of the top-spin that a driven
    // ball always carries.
    // NEGATED, because the Magnus cross product with a ball travelling +y puts
    // the sideways force at `-spin.z * vy` — so a positive spin about the
    // vertical bends it LEFT, and the field is documented as positive-is-right.
    spin
      ..z = -aim.curl * 95
      ..x = -aim.power * 18;
  }

  /// Push the simulation forward by [dt] of real time.
  void advance(double dt) {
    var left = dt;
    while (left > 0 && !done) {
      final step = math.min(timeStep, left);
      _step(step);
      left -= step;
    }
  }

  void _step(double dt) {
    final before = position.clone();

    // Drag opposes the flight and grows with the square of the speed.
    final speed = velocity.length;
    final acceleration = Vec3(0, 0, -gravity);
    if (speed > 0) {
      acceleration.addScaled(velocity, -dragCoefficient * speed);
      // Magnus: ω × v, which is what turns spin into a sideways force.
      final cross = Vec3(
        spin.y * velocity.z - spin.z * velocity.y,
        spin.z * velocity.x - spin.x * velocity.z,
        spin.x * velocity.y - spin.y * velocity.x,
      );
      acceleration.addScaled(cross, magnusCoefficient / ballMass);
    }
    velocity.addScaled(acceleration, dt);
    position.addScaled(velocity, dt);
    roll += speed * dt / ballRadius;
    elapsed += dt;

    _moveKeeper();
    if (_keeperGotIt()) {
      result = PenaltyResult.saved;
      return;
    }

    // The turf.
    if (position.z < ballRadius && velocity.z < 0) {
      position.z = ballRadius;
      velocity.z = -velocity.z * groundRestitution;
    }

    // The frame and the line. Checked on the CROSSING rather than per frame:
    // the ball is only ever at the goal line for one step, and testing "is it
    // past" after the fact is how a shot goes through a post.
    if (before.y < 0 && position.y >= 0) {
      _crossLine();
    }

    // Into the net. The goal resolves HERE rather than on the line, so the ball
    // is in the picture when the word goes up.
    if (crossedInside && position.y >= goalDepth - ballRadius) {
      position.y = goalDepth - ballRadius;
      netContact ??= position.clone();
      result ??= PenaltyResult.goal;
    }
    // A ball that somehow got behind without crossing inside — belt and braces.
    if (position.y > goalDepth + 1.5) {
      result ??= PenaltyResult.goal;
    }
    if (hitFrame != null && position.y < -2.5) {
      result ??= PenaltyResult.frame;
    }
    if (elapsed > 4) {
      result ??= _missedBy();
    }
  }

  /// What the ball did at the line.
  void _crossLine() {
    final x = position.x;
    final z = position.z;

    // The bar, then the posts. Order matters at the corners: a ball into the
    // angle hits the bar's underside first because it is coming down.
    if ((z - goalHeight).abs() < postRadius + ballRadius &&
        x.abs() < goalHalfWidth) {
      hitFrame = FramePart.crossbar;
      velocity.z = -velocity.z.abs() * frameRestitution;
      velocity.y = -velocity.y * frameRestitution;
      position.y = -0.01;
      return;
    }
    for (final side in [-1, 1]) {
      if ((x - side * goalHalfWidth).abs() < postRadius + ballRadius &&
          z < goalHeight) {
        hitFrame = side < 0 ? FramePart.leftPost : FramePart.rightPost;
        // AWAY from the post it hit. Signed the other way it drove the ball
        // further into the post and the rebound came out at 17 metres across.
        velocity.x = -side * velocity.x.abs() * frameRestitution;
        velocity.y = -velocity.y * frameRestitution;
        position.y = -0.01;
        return;
      }
    }

    if (x.abs() > goalHalfWidth) {
      result = PenaltyResult.wide;
      return;
    }
    if (z > goalHeight) {
      result = PenaltyResult.over;
      return;
    }
    // Inside the frame — but NOT a goal yet. It has a net to reach first, which
    // is what gives the strike something to hit and the picture its depth.
    crossedInside = true;
  }

  /// The ball is past the line and inside the frame, on its way to the net.
  bool crossedInside = false;

  /// Where it hit the net, once it has. The renderer bulges the mesh here.
  Vec3? netContact;

  /// A shot that never reached the line, or came off the frame and stayed out.
  PenaltyResult _missedBy() {
    if (hitFrame != null) return PenaltyResult.frame;
    return position.x.abs() > goalHalfWidth
        ? PenaltyResult.wide
        : PenaltyResult.over;
  }

  /// The dive.
  ///
  /// He commits at [KeeperPlan.commitAt] and extends over [keeperDiveTime] — so a
  /// keeper who goes early is further across when the ball arrives and one who
  /// waits is still travelling. That trade is the whole of the difficulty: at the
  /// top divisions he reads it AND goes early.
  void _moveKeeper() {
    final since = elapsed - plan.commitAt;
    if (since <= 0) {
      keeperHand
        ..x = 0
        ..z = 0.9;
      return;
    }
    final extend = math.min(1, since / keeperDiveTime);
    // Eased, because a dive accelerates off the line and then travels.
    final travel = extend * extend * (3 - 2 * extend);
    keeperHand
      ..x = plan.side * keeperDiveSpan * travel
      // Low dives stay near the ground; a high one gets up.
      ..z = 0.55 + plan.height * 1.5 * travel;
  }

  /// Has he got a hand to it?
  ///
  /// Only ever inside the frame's own depth: a keeper cannot save a ball that is
  /// still four metres out, and testing distance alone let him pluck one out of
  /// the air on the way past.
  bool _keeperGotIt() {
    if (position.y < -0.6 || position.y > 0.35) return false;
    final dx = position.x - keeperHand.x;
    final dz = position.z - keeperHand.z;
    final reach = keeperReach + ballRadius;
    return dx * dx + dz * dz < reach * reach;
  }
}

/// The keeper's plan for one kick.
///
/// [readChance] is the division's ramp. Read or not, he still has to REACH it —
/// which is the change from the old game, where a read was an automatic save and
/// aim was therefore worth nothing.
KeeperPlan planKeeper({
  required double readChance,
  required PenaltyAim aim,
  required math.Random rng,
}) {
  final read = rng.nextDouble() < readChance;
  // **SATURATING, not proportional.** Straight proportional under-reached every
  // corner: a shot at `across = -0.74` gave a dive of 0.74, which is 1.9m of
  // travel plus a 1.05m arm and 40cm short of the ball. A keeper diving for a
  // corner dives FULLY that way — what the proportionality is for is not
  // over-committing on a shot toward the middle. So anything at three quarters
  // of the way out or beyond is a full dive, and never QUITE full, because a
  // keeper who is exactly right every time he reads it is the coin flip again.
  final side = (aim.across / 0.75).clamp(-1.0, 1.0) * 0.98;
  final guess = rng.nextDouble() * 2 - 1;
  return (
    side: read ? side : guess,
    // He reads the height less well than the side, which is why the top corners
    // stay the hardest place to save.
    height: read ? aim.lift.abs().clamp(0.0, 1.0) : rng.nextDouble(),
    // Reading it early is the other half of a good keeper. A guess commits late
    // and has further to travel.
    commitAt: read ? 0.02 + rng.nextDouble() * 0.06 : 0.10 + rng.nextDouble() * 0.1,
  );
}
