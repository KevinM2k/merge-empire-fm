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

/// How far he can spread himself, by division index.
///
/// **The read chance was the only ramp**, so a Champions Cup keeper guessed as
/// badly as a Sunday League one and simply guessed right more often. A better
/// keeper also covers more of the goal once he has gone the right way — he
/// spreads himself — so the arm grows with the division.
///
/// **It ramps DOWN from the top, not up from it.** [keeperDiveSpan] plus
/// [keeperReach] is the post to the centimetre, and that is the number the whole
/// balance rests on: longer and there is nowhere to shoot. So the top division
/// keeps the documented reach and the ones below it get less, which is the
/// direction a difficulty ramp should run anyway — it makes the early game
/// forgiving rather than the late game impossible.
double keeperReachFor(int divisionIndex) {
  final t =
      (divisionIndex < 0 ? 0 : (divisionIndex > 6 ? 6 : divisionIndex)) / 6;
  return keeperReach * (0.78 + 0.22 * t);
}

/// How far his hands travel on a full dive.
///
/// 2.6m plus the arm is 3.65 — which is the post, to the centimetre, and that is
/// the number the whole game balances on: **a perfect corner is only saved by a
/// keeper who read it AND went early.** Shorter and the corners are free; longer
/// and there is nowhere to shoot.
const double keeperDiveSpan = 2.6;

/// How long a full dive takes to extend.
const double keeperDiveTime = 0.42;

/// How long he hangs at full stretch before he comes down.
///
/// A beat, not a pause: it is the top of the jump, and without it the landing
/// starts on the same frame the ball is decided, which reads as him being pulled
/// down rather than falling.
const double keeperHangTime = 0.10;

/// How long the landing takes.
const double keeperLandTime = 0.34;

/// Where his shoulders finish, in metres — the two ends of a landing.
///
/// [keeperGroundZ] is a keeper lying on the turf; [keeperStandZ] is one who
/// never left his feet, and is the same number he starts the kick at.
const double keeperGroundZ = 0.34;
const double keeperStandZ = 0.9;

/// How much of the dive he spends settling from standing onto its curve.
///
/// **His hands used to teleport 35cm the instant he committed**: the curve's
/// own value at `dive == 0` is 0.55 and his shoulders stand at [keeperStandZ],
/// so the frame he went the whole figure dropped a third of a metre and then
/// climbed back out of it.
///
/// Small, because it is a JOIN and not a movement: the dive is eased, so this
/// is over inside the first fiftieth of a second and the ball is nowhere near.
/// Anything larger starts moving where his gloves are during the flight, which
/// is a balance change — see `_moveKeeper`.
const double keeperSettle = 0.18;

/// One penalty, stepped.
class PenaltyKick {
  PenaltyKick({
    required this.aim,
    required this.plan,
    this.reach = keeperReach,
    this.timeStep = 1 / 240,
  }) : position = Vec3(0, -spotDistance, ballRadius),
       velocity = Vec3.zero(),
       spin = Vec3.zero() {
    _launch();
  }

  final PenaltyAim aim;
  final KeeperPlan plan;

  /// How far he can get a glove, from the centre of his reach.
  ///
  /// Separate from [plan] because they are different things: the plan is his
  /// DECISION — which way and how early — and this is his ABILITY. Only the
  /// second one improves with the division; see [keeperReachFor].
  final double reach;

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
  final Vec3 keeperHand = Vec3(0, 0, keeperStandZ);

  /// How far through the dive he is, 0 standing to 1 at full stretch — EASED,
  /// which is the curve the hand is actually on.
  ///
  /// Published because the renderer needs it to pose the figure, and it used to
  /// work it out again from [elapsed] and [KeeperPlan.commitAt] with a straight
  /// ramp. Two curves for one dive is the disagreement this file keeps having to
  /// fix: the limbs were on a different clock from the glove they hang off.
  double keeperDive = 0;

  /// How far through the LANDING, 0 still up to 1 down.
  double keeperLand = 0;

  /// When the kick was decided — the ball's story is over at this instant, and
  /// it is what the landing is timed from. Null while it is still live.
  double? decidedAt;

  /// He clung on to it, rather than pushing it away.
  bool held = false;

  /// Seconds since the gloves got to it. Null until they do.
  double? savedAt;

  /// How long the ball stays live after a save.
  ///
  /// **A save that stops the ball dead is a ball vanishing.** The keeper reached
  /// it and then the simulation simply ended, which on screen is the ball
  /// freezing in mid-air — the one moment of the game the player most wants to
  /// watch. It is pushed away or clung to now, and it keeps moving while that
  /// happens.
  static const double saveFollowThrough = 0.85;

  /// A held ball is over sooner: there is nothing left to watch once it is in
  /// his gloves.
  static const double holdFollowThrough = 0.35;

  /// How long the ball was in the air on its way to the goal.
  ///
  /// Distinct from [elapsed] now that a save keeps running: the follow-through
  /// is time on the clock but it is not flight, and the keeper's dive is tuned
  /// against the flight.
  double get flightTime => savedAt ?? elapsed;

  bool get done {
    if (result == null) return false;
    final at = savedAt;
    if (at == null) return true;
    return elapsed - at >= (held ? holdFollowThrough : saveFollowThrough);
  }

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
  ///
  /// **IT KEEPS RUNNING AFTER THE BALL IS [done].** The kick being decided is not
  /// the end of the picture — the screen holds on it for the best part of two
  /// seconds — and a keeper frozen at full stretch in the middle of that is the
  /// same "ball vanishing" defect the parry was written to kill, moved from the
  /// ball to the hands. So a finished kick still settles: he comes down, and a
  /// ball in his gloves comes down with him. Only the KEEPER moves; the ball is
  /// where it finished, in the net or gathered or out of the picture.
  void advance(double dt) {
    var left = dt;
    while (left > 0) {
      final step = math.min(timeStep, left);
      if (done) {
        _settle(step);
      } else {
        _step(step);
      }
      left -= step;
    }
  }

  /// One step of a kick that is over: the landing, and nothing else.
  /// The picture after the kick is decided.
  ///
  /// **A ball that has stopped being simulated is a ball hanging in the air**,
  /// and the screen holds on the goalmouth for nearly two seconds after the word
  /// goes up — so everything that stops moving here is something the player
  /// watches not move. It was reported as no physics at all: the ball stuck in
  /// the net and the keeper stuck in the air.
  ///
  /// He was fixed first; this is the ball. Gravity, the turf and whatever the
  /// net left it with, which is what makes a goal end with the ball on the
  /// ground inside the net rather than pinned to the cords at head height.
  void _settle(double dt) {
    elapsed += dt;
    _moveKeeper();
    if (held) {
      // Pinned to his gloves, and it goes down with him.
      position
        ..x = keeperHand.x
        ..y = keeperHand.y
        ..z = keeperHand.z;
      return;
    }
    velocity.z -= gravity * dt;
    position
      ..x += velocity.x * dt
      ..y += velocity.y * dt
      ..z += velocity.z * dt;
    if (position.z < ballRadius && velocity.z < 0) {
      position.z = ballRadius;
      velocity.z = -velocity.z * groundRestitution;
      // Rolling friction. Without it a ball that has come to rest slides across
      // the goalmouth for the whole hold.
      velocity
        ..x *= 0.66
        ..y *= 0.66;
    }
    // It cannot come back out through the net it is already in, and it cannot
    // roll out through the SIDE of one either — a ball that went in at an angle
    // carries most of a metre of drift across the hold, which put it through
    // the side netting and out past the post.
    if (netContact != null) {
      if (position.y > goalDepth - ballRadius) {
        position.y = goalDepth - ballRadius;
        velocity.y = 0;
      }
      final edge = goalHalfWidth - ballRadius;
      if (position.x.abs() > edge) {
        position.x = position.x.isNegative ? -edge : edge;
        velocity.x = -velocity.x * 0.3;
      }
    }
  }

  void _step(double dt) {
    // In his gloves, and staying there. It rides the hands rather than dropping
    // out of them — a caught ball that then falls to the turf under gravity is
    // a fumble, which is a different outcome and not the one that was rolled.
    if (held) {
      elapsed += dt;
      _moveKeeper();
      position
        ..x = keeperHand.x
        ..y = keeperHand.y
        ..z = keeperHand.z;
      return;
    }

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
    if (savedAt == null && _keeperGotIt()) {
      result = PenaltyResult.saved;
      savedAt = elapsed;
      decidedAt = elapsed;
      _parry(speed);
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
      if (netContact == null) {
        netContact = position.clone();
        // **THE NET TAKES THE PACE.** It used to pin the ball against the net
        // and leave every component of its velocity untouched, which did not
        // show while the kick was being stepped and showed for the whole of the
        // hold afterwards: the ball stopped dead the instant the word went up
        // and hung there in mid-air. A ball into a net is stopped by it and then
        // DROPS. What is left is a little sideways and a little down, and
        // gravity does the rest in [_settle].
        velocity
          ..x *= 0.18
          ..y = 0
          ..z *= 0.18;
      }
      result ??= PenaltyResult.goal;
    }
    // Behind the goal, one way or the other. It used to call anything back there
    // a goal, which a reflecting bar makes wrong: a ball that came off the top
    // of it and flew on is behind the net without ever having been inside it.
    if (position.y > goalDepth + 1.5) {
      result ??= crossedInside ? PenaltyResult.goal : _missedBy();
    }
    if (hitFrame != null && position.y < -2.5) {
      result ??= PenaltyResult.frame;
    }
    if (elapsed > 4) {
      result ??= _missedBy();
    }
    if (result != null) decidedAt ??= elapsed;
  }

  /// Which parts of the frame have already been struck.
  ///
  /// Once each. The reflection leaves the ball travelling away from what it hit,
  /// but a ball that re-crossed the line at bar height every step would hammer
  /// the same upright until the clock ran out — and a real ball off the bar has
  /// finished with the bar.
  final Set<FramePart> _struck = <FramePart>{};

  /// Bounce off a surface whose outward normal is [normal].
  ///
  /// **A BOUNCE IS A REFLECTION**, and that is the whole change: both frame
  /// contacts used to flip the ball's FORWARD velocity outright and park it back
  /// outside the line, so anything that touched the frame came out. The one
  /// thing everybody knows about a crossbar is that a ball can come down off it
  /// and go in.
  ///
  /// Only the component going INTO the surface is reversed, which is what makes
  /// the same three lines give both answers: a ball rising into the underside of
  /// the bar loses its climb and keeps its forward pace, and one clipping the
  /// outer face of a post is already travelling away and is barely touched.
  void _reflect(Vec3 normal) {
    final length = normal.length;
    if (length < 1e-9) return;
    final nx = normal.x / length;
    final ny = normal.y / length;
    final nz = normal.z / length;
    final into = velocity.x * nx + velocity.y * ny + velocity.z * nz;
    // Already moving away from it: a graze, not a bounce.
    if (into >= 0) return;
    velocity
      ..x = (velocity.x - 2 * into * nx) * frameRestitution
      ..y = (velocity.y - 2 * into * ny) * frameRestitution
      ..z = (velocity.z - 2 * into * nz) * frameRestitution;
  }

  /// What the ball did at the line.
  void _crossLine() {
    final x = position.x;
    final z = position.z;
    // Inside the mouth AT the line, which is what decides whether a frame
    // contact leaves the ball in play or takes it out of the picture.
    final insideMouth = x.abs() < goalHalfWidth && z < goalHeight;

    // The bar, then the posts. Order matters at the corners: a ball into the
    // angle hits the bar's underside first because it is coming down.
    if (!_struck.contains(FramePart.crossbar) &&
        (z - goalHeight).abs() < postRadius + ballRadius &&
        x.abs() < goalHalfWidth) {
      hitFrame = FramePart.crossbar;
      _struck.add(FramePart.crossbar);
      // The bar runs along x, so its normal lies in the y-z plane: from the
      // bar's own axis out to the ball. Under it, that points down.
      _reflect(Vec3(0, position.y, z - goalHeight));
      if (insideMouth) crossedInside = true;
      return;
    }
    for (final side in [-1, 1]) {
      final part = side < 0 ? FramePart.leftPost : FramePart.rightPost;
      if (!_struck.contains(part) &&
          (x - side * goalHalfWidth).abs() < postRadius + ballRadius &&
          z < goalHeight) {
        hitFrame = part;
        _struck.add(part);
        // A post is vertical, so its normal lies in the x-y plane. Struck on the
        // INSIDE it points into the goal, and the ball carries on inward.
        _reflect(Vec3(x - side * goalHalfWidth, position.y, 0));
        if (insideMouth) crossedInside = true;
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

  /// The dive, and the landing.
  ///
  /// He commits at [KeeperPlan.commitAt] and extends over [keeperDiveTime] — so a
  /// keeper who goes early is further across when the ball arrives and one who
  /// waits is still travelling. That trade is the whole of the difficulty: at the
  /// top divisions he reads it AND goes early.
  ///
  /// **AND THEN HE COMES DOWN.** The extension used to be clamped and that was
  /// the end of him: for the whole follow-through the arm was a statue while the
  /// ball looped away, and a GATHERED ball hung motionless in mid-air for 0.35s,
  /// which is the ball-vanishing defect the parry exists to prevent wearing a
  /// different hat.
  ///
  /// **The landing is timed from [decidedAt], not from full extension**, and that
  /// is a deliberate trade rather than an oversight. He is airborne for as long as
  /// the ball is live. Letting gravity have him mid-flight is physically truer and
  /// it is a BALANCE CHANGE: measured, a keeper who read a corner struck at 0.28
  /// power is a third of the way to the turf when it arrives and no longer reaches
  /// it, so "a read keeper saves a soft corner" — the balance this file is tuned
  /// around — stops holding. What a player actually watched was the follow-through,
  /// and that is what this moves.
  void _moveKeeper() {
    final since = elapsed - plan.commitAt;
    if (since <= 0) {
      keeperDive = 0;
      keeperLand = 0;
      keeperHand
        ..x = 0
        ..z = keeperStandZ;
      return;
    }
    final extend = math.min(1.0, since / keeperDiveTime);
    // Eased, because a dive accelerates off the line and then travels.
    keeperDive = extend * extend * (3 - 2 * extend);
    // Low dives stay near the ground; a high one gets up.
    //
    // **AND IT STARTS WHERE HE IS STANDING.** It used to start at 0.55 — the
    // curve's own constant, evaluated at `dive == 0` — while his shoulders are
    // at [keeperStandZ], so the frame he committed the whole figure dropped a
    // third of a metre and then climbed back out of it. Reported as his hands
    // teleporting 35cm the instant he goes.
    //
    // **The defect is a DISCONTINUITY, so what is fixed is the discontinuity.**
    // Interpolating the whole curve from standing was tried and it is a balance
    // change, not a tidy-up: it lifts his gloves through the entire flight, and
    // measured it turned "a read no longer guarantees a save" — a property this
    // file is tuned around and has a test for — into a keeper who saves
    // everything he reads. So instead he SETTLES onto the curve over the first
    // fraction of the dive: continuous, and finished long before the ball is
    // anywhere near him, which leaves the flight path and therefore what he
    // saves exactly as they were.
    final curve = 0.55 + plan.height * 1.5 * keeperDive;
    final peak =
        keeperStandZ +
        (curve - keeperStandZ) * math.min(1.0, keeperDive / keeperSettle);
    keeperHand.x = plan.side * keeperDiveSpan * keeperDive;

    final at = decidedAt;
    final falling = at == null ? 0.0 : elapsed - at - keeperHangTime;
    keeperLand = falling <= 0 ? 0 : math.min(1.0, falling / keeperLandTime);
    // Gravity: the distance goes with the square of the time.
    final drop = keeperLand * keeperLand;
    keeperHand.z = peak + (_restZ - peak) * drop;
  }

  /// Where his shoulders come to rest.
  ///
  /// **How far he falls is how far he went.** A keeper who dived full length is
  /// lying on the turf; one who simply put his hands up is still on his feet, and
  /// dropping him to the ground would be a man collapsing rather than a save. A
  /// ball he GATHERED takes him down whatever he did to reach it, because a keeper
  /// who has caught one smothers it rather than standing there holding it up.
  double get _restZ {
    if (held) return keeperGroundZ;
    final committed = plan.side.abs().clamp(0.0, 1.0);
    return keeperStandZ + (keeperGroundZ - keeperStandZ) * committed;
  }

  /// Has he got a hand to it?
  ///
  /// Only ever inside the frame's own depth: a keeper cannot save a ball that is
  /// still four metres out, and testing distance alone let him pluck one out of
  /// the air on the way past.
  /// What the gloves DO to it.
  ///
  /// Two outcomes, and the difference is the pace on the shot. A weak one
  /// straight at him is gathered — the ball stops in his hands and drops with
  /// them. Anything struck is pushed AWAY: back out towards the taker and off to
  /// the side the hand met it on, at a fraction of the pace it arrived with,
  /// which is what a parry looks like.
  void _parry(double speed) {
    if (speed < _holdSpeed) {
      held = true;
      velocity
        ..x = 0
        ..y = 0
        ..z = 0;
      spin
        ..x = 0
        ..y = 0
        ..z = 0;
      return;
    }
    // Away from the centre of the gloves, so a ball met on the outside of the
    // hand goes wide and one met square comes back down the middle.
    final offset = position.x - keeperHand.x;
    final side = offset.abs() < 0.02
        ? (keeperHand.x < 0 ? -1.0 : 1.0)
        : offset.sign;
    velocity
      ..x = side * speed * _parryOut
      ..y = -speed * _parryBack
      ..z = speed * _parryUp;
    // The spin is gone: it was the boot's, and the gloves have taken it off.
    spin
      ..x = 0
      ..y = 0
      ..z = 0;
  }

  bool _keeperGotIt() {
    if (position.y < -0.6 || position.y > 0.35) return false;
    final dx = position.x - keeperHand.x;
    final dz = position.z - keeperHand.z;
    final sweep = reach + ballRadius;
    return dx * dx + dz * dz < sweep * sweep;
  }
}

/// Below this, in metres per second, he gathers it rather than pushing it away.
const double _holdSpeed = 13;

/// What is left of the shot's pace after the gloves, split three ways. They are
/// deliberately small: a parried ball loops away, it does not rocket.
const double _parryOut = 0.30;
const double _parryBack = 0.22;
const double _parryUp = 0.26;

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
    commitAt: read
        ? 0.02 + rng.nextDouble() * 0.06
        : 0.10 + rng.nextDouble() * 0.1,
  );
}
