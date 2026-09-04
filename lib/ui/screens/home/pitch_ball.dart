/// The stray ball on the League diorama. Ported from
/// `../merge-empire-fc/src/ui/components/PitchBallSim.js` and the `.ps-ball`
/// rules in `league-scene.css`.
///
/// **The ball comes to HIM.** He used to dribble one, which read as a *player*
/// on a screen whose whole premise is that you are the gaffer. So a stray ball
/// rolls in from up ahead and he deals with it — knocks it back, chips it,
/// boots it into the stand, picks it up and throws it, or leaves it — and then
/// the touchline is empty for a few seconds until the next one. Same physics
/// toy, opposite relationship.
///
/// What he does with one is a mood-weighted roll: `pickBallPlay` in
/// `manager_mood.dart`, ported since M1 with nothing ever rolling it.
///
/// Three things move at once, and the JS's own summary of them survives:
///
/// - **horizontal** — the ball has a ground velocity that rolling friction
///   decays toward zero, and he walks onto it at the turf's own pace. No elastic
///   snap: a settled ball closes on him because he is walking, not because
///   anything pulls it.
/// - **vertical** — gravity and a bouncing landing, for balls that arrive
///   bouncing and for a lofted return.
/// - **rotation** — spin is proportional to ground speed over the radius, so it
///   turns BACKWARDS on the way in and forwards on the way out. The roll always
///   matching the direction of travel is what sells it as a ball rather than a
///   sprite.
///
/// **THE ONE PLACE THIS DEPARTS FROM THE JS IS THE TURF'S SPEED, and it has to.**
/// The JS scrolls its ground linearly and hands the sim a constant
/// `PLAYER_SPEED`; here the world moves at the supporting boot's own varying
/// rate (see `groundEase` in `pitch_scene.dart`) and eases to a stop for a
/// gesture (see `walk_ramp.dart`). So the sim is handed how far the world
/// ACTUALLY moved this frame rather than a constant, which is what keeps a ball
/// lying on the grass lying still on it — the invariant the JS spends three
/// comments defending. It also means `setHalted` does not need porting: the beat
/// carries the ease, and the ball is already reading the beat.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart'
    show GroundShadow, walkerFootOffset, walkerThighAngle, walkerWidth;
import 'package:merge_empire_fc/ui/screens/home/pitch_scene.dart'
    show groundHalfStrideArtUnits, walkDurationFor, walkerScale;
import 'package:merge_empire_fc/ui/screens/home/walk_ramp.dart';

// ── The numbers ─────────────────────────────────────────────────────────────
//
// Art units and seconds throughout, which is walker-local: the ball is drawn in
// the figure's own box and scaled with him, so a distance here means the same
// thing to the ball as it does to his boot. The JS calls the same frame
// "walker-space px" and has to divide the turf's page-space speed by the rig's
// CSS scale to reach it; here the ground's speed is already stated in art units
// per half-stride, so there is nothing to convert.

/// Gravity.
const double _gravity = 1500;

/// How much of a bounce survives the grass.
const double _restitution = 0.52;

/// Rolling deceleration of the ball's ground speed.
const double _friction = 120;

/// Proportional drag while airborne — no rolling contact up there.
const double _airDrag = 0.15;

/// Below this landing speed it stops bouncing.
const double _restSnap = 12;

/// How high a lofted ball may get.
const double _maxY = 72;

/// Where a ball settles at his boot.
///
/// Just AHEAD of the foot, so a trapped ball reads as touching it rather than
/// as floating a stride in front of him.
const double _trapX = 5;

/// The ball never rolls behind him except when he is ignoring it.
const double _minX = -10;

/// The ball's own size, and where it sits with nothing done to it — the JS's
/// `.ps-ball { left: 68px; bottom: -2px; width: 21px }`, in the figure's units.
const double ballSize = 21;
const double ballHomeX = 68;

/// It sits a shade INTO the grass rather than balanced on top of it.
const double ballSink = 2;

/// How far the shadow reaches PAST the ball on each side, and how tall its own
/// box is, in the figure's units.
///
/// The spread is what makes it visible at all: a shadow no wider than the ball
/// is a shadow the ball is standing on top of. See the note in `build`.
const double _shadowSpread = 3.5;
const double _shadowHeight = 7;

/// Effective rolling radius, and the degrees of roll one unit of travel is
/// worth.
const double _rollRadius = 9;
final double _degPerUnit = 180 / (math.pi * _rollRadius);

/// How far past the frame's edge a ball has to get before it is retired.
const double _exitMargin = 24;

/// Where a carried ball sits, in the figure's units.
///
/// Measured against the carry pose — near arm -20, forearm -110, which the JS
/// states in `.ps-walker.is-carrying` — and raised about a ball's radius so it
/// rests ON his hands rather than level with them. At hand height exactly, the
/// palms sit across the ball's middle and read as holding it from above.
const double _handX = -4;
const double _handY = 59;

/// How fast the ball rises as he stoops and picks it up.
const double _liftRate = 190;

/// Phases of one ball's visit. See [PitchBallSim.advance] for the transitions.
enum BallPhase {
  /// No ball on the pitch, counting down to the next arrival.
  idle,

  /// Rolling toward him from up ahead.
  incoming,

  /// At his feet, held for a beat before he plays it.
  trap,

  /// Being lifted off the grass into his hands.
  pickup,

  /// In his hands, about to be thrown back.
  hold,

  /// Played back, travelling away out of shot.
  out,

  /// Ignored — drifting behind him as he walks on.
  past,
}

/// How long a ball may spend in a phase before it is forced on, in seconds.
///
/// Generous — several times the longest legitimate stay — because these are a
/// backstop against a wedged ball rather than a pacing control: anything tight
/// enough to fire in normal play would cut a pass short. [BallPhase.idle] is
/// absent deliberately: it is a plain countdown and cannot wedge.
const Map<BallPhase, double> _phaseMax = {
  BallPhase.incoming: 12,
  BallPhase.trap: 5,
  BallPhase.pickup: 3,
  BallPhase.hold: 6,
  BallPhase.out: 12,
  BallPhase.past: 12,
};

/// What the sim tells the screen about. The sim owns the BALL; the screen owns
/// the manager, so a carry is announced rather than reached into.
enum BallCue { hold, release, ignore }

/// The stray ball, as arithmetic.
///
/// Deliberately Flutter-free: it is an integrator, and every one of its rules —
/// what stops a bounce, what stops a ball wedging at his boot, how hard he has
/// to hit it for the pass to actually clear the frame — is testable without a
/// widget binding.
class PitchBallSim {
  PitchBallSim({
    required this.getMood,
    required this.onCue,
    math.Random? random,
  }) : _rand = random ?? math.Random();

  /// Read fresh on every arrival, so a result mid-session changes what he does
  /// with the very next ball.
  final Mood Function() getMood;

  final void Function(BallCue cue) onCue;

  /// **`dart:math`, not `util/random.dart`.** This mirrors the JS's
  /// `Math.random()` and it is scenery: a draw taken here must not shift the
  /// seeded gameplay stream by so much as one number.
  final math.Random _rand;

  /// Offset from the ball's home position, and its height above the grass.
  double x = 0;
  double y = 0;

  /// Velocity relative to the MANAGER — he walks in place, so this is screen
  /// space. The ball's speed over the turf is this plus his walking pace.
  double vx = 0;
  double vy = 0;

  /// Accumulated roll, in degrees.
  double rot = 0;

  bool grounded = true;

  /// Wind push, units/s², positive blowing downfield. Applied only while the
  /// ball is airborne — see [step] for why that is the point rather than a
  /// shortcut.
  double wind = 0;

  BallPhase phase = BallPhase.idle;

  /// What he has decided to do with the ball on the pitch. Decided on ARRIVAL,
  /// because "ignore" has to be a decision he makes before it reaches him — he
  /// simply does not stop it.
  String play = 'pass';

  /// Seconds left in a phase that ends on a clock rather than on a position.
  ///
  /// **Starts empty.** The scene opens on a quiet touchline and the first ball
  /// rolls in a moment later, so the arrival is something you watch happen
  /// rather than a ball that was always there.
  double timer = 0.8;

  double _phaseAge = 0;
  bool _holding = false;
  bool _toldIgnore = false;
  double? _exitX;

  /// How wide the scene is, in the figure's units, and how far he stands into
  /// it. Both are set by the widget from the real layout.
  double _aheadOfHim = 230;
  double _behindHim = 230;

  /// **He has planted his feet for a gesture.**
  ///
  /// Not the same as the sim being paused: the ball keeps rolling, bouncing and
  /// losing speed to friction. What stops is HIS half of the interaction — a
  /// ball still rolling in still rolls in and still traps at his boot, and then
  /// waits there until he straightens up.
  ///
  /// The intent rather than the measured speed, which is the JS's own
  /// `_walkTarget === 0`: the wait has to start when he starts stopping, not
  /// 380ms later when the ease finishes.
  bool halted = false;

  bool get holding => _holding;

  /// Where the frame's edges are, for the fixture — the JS's unlaid-out
  /// fallbacks, so the trace is comparing physics rather than two different
  /// ways of measuring a viewport.
  @visibleForTesting
  void pinFrame({required double ahead, required double behind}) {
    _aheadOfHim = ahead;
    _behindHim = behind;
  }

  /// True when there is a ball on the pitch at all.
  bool get visible => phase != BallPhase.idle;

  /// Where the frame's edges are, in the ball's own units.
  ///
  /// **Derived rather than estimated.** The JS approximates the near edge
  /// ("roughly 55% of the scene lies ahead of him") and then has to MEASURE the
  /// far one off the DOM, because its estimate left an ignored ball blinking out
  /// of existence while still on screen. Both are exact here: the figure's box
  /// is scaled about its own centre at a known place on a known-width scene, so
  /// the art unit that lands on either edge is just arithmetic.
  void setFrame({required double sceneWidth, required double walkerLeft}) {
    const centre = walkerWidth / 2;
    double artAt(double screenX) =>
        (screenX - walkerLeft - centre) / walkerScale + centre;
    // A pass has to genuinely clear the frame, and an ignored ball has to roll
    // all the way out of shot behind him rather than vanishing mid-pitch.
    _aheadOfHim = math.max(150, artAt(sceneWidth) - ballHomeX + _exitMargin);
    _behindHim = math.max(150, ballHomeX - artAt(0) + _exitMargin);
  }

  /// How far ahead of home a ball is out of shot.
  double get edgeX => _aheadOfHim;

  double _range(double lo, double hi) => lo + _rand.nextDouble() * (hi - lo);

  /// A stray ball rolls in from up ahead.
  ///
  /// Ground speed is NEGATIVE — toward him — and friction bleeds it off, so most
  /// balls stop short and he walks the last stretch. That is what makes him look
  /// like a man out for a walk rather than one waiting on a delivery.
  void _arrive() {
    x = edgeX;
    y = 0;
    vy = 0;
    grounded = true;
    vx = -_range(170, 265) - _walkSpeed;
    if (_rand.nextDouble() < 0.22) {
      // Bouncing in off the turf.
      vy = _range(190, 340);
      grounded = false;
    }
    play = pickBallPlay(getMood(), _rand.nextDouble);
    _toldIgnore = false;
    _exitX = null;
    _setPhase(BallPhase.incoming);
  }

  void _setPhase(BallPhase next) {
    phase = next;
    _phaseAge = 0;
  }

  /// Take the ball off the pitch and leave the touchline empty for a beat.
  ///
  /// The gap matters: a ball on screen at all times is the dribble again, just
  /// with extra steps. Drops the carry too — a ball retired out of his hands
  /// would otherwise leave him cradling nothing.
  void _retire() {
    _setPhase(BallPhase.idle);
    timer = _range(1.6, 3.8);
    if (_holding) {
      _holding = false;
      onCue(BallCue.release);
    }
  }

  /// A ball has overstayed its phase. Push it to the NEXT one rather than
  /// deleting it: every case here is "he was about to do something and the ball
  /// never got there", so doing the thing is both the correct recovery and the
  /// one that reads as normal play. Only the travelling phases — where there is
  /// nothing left to do but leave — retire.
  void _unstick() {
    switch (phase) {
      case BallPhase.trap:
        _playBack();
      case BallPhase.hold:
        _throwBack();
      case BallPhase.pickup:
        _intoHands();
      case BallPhase.incoming:
        // Never made it to his feet. Settle it there and let him play it, which
        // is what would have happened had it arrived under its own steam.
        x = _trapX;
        vx = 0;
        y = 0;
        vy = 0;
        grounded = true;
        _setPhase(BallPhase.trap);
        timer = _range(0.3, 0.7);
      case BallPhase.out || BallPhase.past || BallPhase.idle:
        _retire();
    }
  }

  void _intoHands() {
    y = _handY;
    x = _handX;
    _holding = true;
    onCue(BallCue.hold);
    _setPhase(BallPhase.hold);
    timer = _range(1.1, 2.5);
  }

  /// How hard he has to hit it.
  ///
  /// **Not simply how far the ball has to roll**, because he keeps walking after
  /// it: the gap that has to open is the ball's travel MINUS his. Over the `v/f`
  /// seconds the ball takes to stop, `gap = v²/2f - P·v/f`, and solving that for
  /// the gap gives `v = P + sqrt(P² + 2fd)`. The plain `sqrt(2fd)` under-hits by
  /// about 40% — the ball stalls in front of him and he walks back onto it,
  /// which is the dribble again. Deriving it also keeps the pass honest across
  /// screen sizes: a strength tuned on a phone would stop mid-pitch on a tablet.
  double get _need {
    final d = edgeX + 40;
    final p = _nominalWalkSpeed;
    return p + math.sqrt(p * p + 2 * _friction * d);
  }

  /// He plays it back. The strike SETS the outgoing ground speed rather than
  /// adding an impulse, so every contact is a clean, consistent one.
  ///
  /// [_nominalWalkSpeed] rather than the live one throughout: these only ever
  /// run while he is walking. A gesture that plants his feet freezes the trap
  /// before its timer can reach here, and a pickup cannot overlap a gesture at
  /// all — the carry cancels whatever was running and blocks the next one.
  void _playBack() {
    final need = _need;
    final p = _nominalWalkSpeed;
    switch (play) {
      case 'chip':
        // Chipped back — arcs up and bounces away.
        vx = need * _range(1.05, 1.25) - p;
        vy += _range(250, 440);
        grounded = false;
      case 'clear':
        // Full-blooded clearance, boot it into the stand.
        vx = need * _range(1.5, 1.9) - p;
        vy += _range(150, 310);
        grounded = false;
      default:
        // Firm ground pass back — the default, and where a stray "what now?"
        // play safely lands.
        vx = need * _range(1.12, 1.34) - p;
    }
    _setPhase(BallPhase.out);
  }

  /// Throw it back from hand height. Already airborne, so it only has drag on
  /// the way out and reaches the edge easily — but it still has to survive the
  /// fall, hence the flat-ish arc rather than a lob.
  void _throwBack() {
    vx = _need * _range(1.0, 1.25) - _nominalWalkSpeed;
    vy = _range(40, 130);
    grounded = false;
    _holding = false;
    onCue(BallCue.release);
    _setPhase(BallPhase.out);
  }

  /// How fast the world is going past him this frame, and the pace he walks at
  /// on average. Both are handed in by the widget — see the note at the top of
  /// the file about why the first is not a constant.
  double _walkSpeed = 0;
  double _nominalWalkSpeed = 0;

  /// Whether a pace has been seen yet. The first frame ADOPTS the turf's speed
  /// rather than treating it as a change — there was no slower world before it
  /// for a ball to have been travelling over.
  bool _paced = false;

  /// One frame.
  ///
  /// [walkSpeed] is how fast the turf is ACTUALLY travelling past him right now
  /// — which varies across his stride and eases to nothing when he plants his
  /// feet. [nominalWalkSpeed] is his average pace, which is what a strike is
  /// solved against.
  void step(
    double dt, {
    required double walkSpeed,
    required double nominalWalkSpeed,
  }) {
    // **THE TURF CHANGING SPEED DOES NOT CHANGE HOW FAST A FREE BALL IS
    // TRAVELLING OVER IT.** Momentum is momentum — but [vx] is stored relative
    // to the MANAGER, so holding the ball's turf-relative speed constant means
    // [vx] has to absorb every change in his pace.
    //
    // The JS only needs this at the halt, where its one constant speed ramps to
    // zero, and says there exactly what is going on: what is conserved across
    // the transition is the ball's speed over the TURF. Here the turf's speed
    // changes on EVERY frame — it follows the supporting boot — so the same
    // correction is simply always on. Without it a ball lying on the grass
    // slides against the grass it is lying on by as much as the stride varies,
    // which is the one mistake on this screen the eye catches instantly.
    //
    // The carried phases are exempt: a ball at his boot or in his hands is
    // pinned to him at `vx == 0` with no momentum of its own. Its speed over the
    // turf is entirely borrowed from his walking, which is exactly why it has to
    // wind down to nothing — and stop spinning — as he stops.
    final carried =
        phase == BallPhase.trap ||
        phase == BallPhase.pickup ||
        phase == BallPhase.hold;
    if (_paced && !carried) vx -= walkSpeed - _walkSpeed;
    _paced = true;
    _walkSpeed = walkSpeed;
    _nominalWalkSpeed = nominalWalkSpeed;
    if (dt <= 0) return;
    // Clamp a tab-switch or a jank spike.
    if (dt > 0.05) dt = 0.05;

    if (phase == BallPhase.idle) {
      advance(dt);
      return;
    }

    // Vertical: gravity and the bounce.
    if (!grounded || vy != 0) {
      vy -= _gravity * dt;
      y += vy * dt;
      if (y <= 0) {
        y = 0;
        // **TWO rest tests, and the second one is the important one.** Without
        // it a decaying bounce never terminates: each step gravity removes
        // `g·dt` of upward speed, so a rebound smaller than that is already
        // falling again by the next frame, lands, rebounds smaller still — and
        // the discrete recursion has a FIXED POINT at about `0.34·g·dt` that
        // sits below [_restSnap]'s exit and never reaches it. The ball then
        // bounces forever at an apex of a hundredth of a unit: visually parked
        // on the grass, and never [grounded].
        //
        // Which is what stranded balls at his feet in the JS. The trap below is
        // gated on [grounded], so a ball that arrived bouncing reached his boot
        // and was never trapped, never played and never retired. Testing
        // against `g·dt` rather than a constant is what makes it hold at any
        // frame rate.
        final up = -vy * _restitution;
        if (vy >= -_restSnap || up <= _gravity * dt * 0.5) {
          vy = 0;
          grounded = true;
        } else {
          vy = up;
        }
      }
    }
    if (y > _maxY) {
      y = _maxY;
      if (vy > 0) vy = 0;
    }

    // Horizontal. The carried phases are scripted rather than ballistic: he is
    // holding the ball, so rolling friction is meaningless and [advance] owns
    // its position.
    if (!carried) {
      final groundV = vx + walkSpeed;
      if (grounded) {
        // Rolling friction decays the ball's speed over the TURF toward zero in
        // whichever direction it is rolling, so [vx] bottoms out at minus his
        // pace: the ball stops dead and he closes the gap by walking.
        final decel = math.min(groundV.abs(), _friction * dt);
        vx -= groundV.sign * decel;
      } else {
        vx -= groundV * _airDrag * dt;
        // **Wind, and ONLY while airborne.** Not a simplification: a grounded
        // ball has to keep closing on him at exactly his walking pace, which is
        // what makes him walk onto it instead of it drifting to meet him. Any
        // standing acceleration on a settled ball breaks that and the ball
        // slides over the grass like it is on ice. In the air there is no such
        // contract, and it is also where wind genuinely does the most to a
        // football — so a gale visibly carries a clearance or a throw and leaves
        // a rolling ball alone.
        vx += wind * dt;
      }
      x += vx * dt;
    }
    // An arriving ball never travels past the feet: a bouncing one settles at
    // the boot and is trapped once it stops, instead of rolling behind him and
    // snapping forward when it finally lands. An ignored ball is the opposite —
    // it has to be free to drift all the way out of shot behind him.
    final floor = switch (phase) {
      BallPhase.incoming => _trapX,
      BallPhase.past => double.negativeInfinity,
      _ => _minX,
    };
    if (x < floor) {
      x = floor;
      if (vx < 0) vx = 0;
    }

    advance(dt);

    // Roll follows the ball's speed over the GROUND, which is why a ball sitting
    // at `vx == 0` still turns: the turf is scrolling under it. Correct on the
    // grass and wrong in his hands, so a carried ball does not spin — and
    // because it goes through the LIVE turf speed, a ball at his boot stops
    // turning when he stops to bow. It was only ever rolling because the ground
    // was moving under it.
    final inHand = phase == BallPhase.pickup || phase == BallPhase.hold;
    // `remainder`, not `%`. Dart's modulo is always non-negative and the JS's
    // keeps the dividend's sign, so a ball rolling backwards came out at 335
    // degrees where the JS has -25. The same angle on screen, and not the same
    // number — which is exactly the sort of thing the fixtures exist to catch.
    if (!inHand) {
      rot = (rot + (vx + walkSpeed) * _degPerUnit * dt).remainder(360);
    }
  }

  /// The phase transitions. Each is a position or a timer test, evaluated AFTER
  /// the frame's integration so a ball is only ever trapped or retired once it
  /// has actually got there.
  @visibleForTesting
  void advance(double dt) {
    if (phase == BallPhase.idle) {
      timer -= dt;
      if (timer <= 0) _arrive();
      return;
    }
    // **Mid-bow: he is folded over with his feet planted**, so he cannot play
    // the ball and it waits for him to straighten up. Only HIS half of the
    // interaction is suspended — a ball still rolling in still rolls in and
    // still traps at his boot; it just sits there until the gesture ends.
    //
    // Held above the stall guard, so the wait does not age the phase: the trap
    // is waiting on purpose here, and the guard exists to catch a ball that is
    // wedged.
    if (halted && phase == BallPhase.trap) return;
    // The stall guard. Every phase below ends on a position or a timer, and a
    // ball that satisfies neither would sit there for the rest of the session —
    // at his feet, most likely, since that is where the phases with the tightest
    // position tests live. Age it out instead, before the transitions, so a
    // wedged ball cannot keep failing the same test forever.
    _phaseAge += dt;
    final cap = _phaseMax[phase];
    if (cap != null && _phaseAge > cap) {
      _unstick();
      return;
    }
    switch (phase) {
      case BallPhase.incoming:
        if (play == 'ignore') {
          // He is letting this one go: no trap, so it simply rolls to a stop and
          // he walks away from it.
          _setPhase(BallPhase.past);
          _exitX = -_behindHim;
          return;
        }
        // Trapped. It then travels WITH him — `vx = 0`, so its ground speed is
        // his pace — which is what a ball at a walking man's feet does. A ball
        // truly at rest would slide backwards out of shot as the world scrolls.
        if (grounded && x <= _trapX) {
          x = _trapX;
          vx = 0;
          _setPhase(BallPhase.trap);
          timer = _range(0.45, 1.2);
        }
      case BallPhase.past:
        // Tell the screen the moment it draws level with him rather than when it
        // entered: the decision was taken on arrival, but the beat worth
        // reacting to is the ball going past his boot untouched.
        if (!_toldIgnore && x <= _trapX) {
          _toldIgnore = true;
          onCue(BallCue.ignore);
        }
        // Never left unset: an absent exit point would mean "never retire",
        // stranding the ball off-screen forever and leaving the pitch
        // permanently empty.
        _exitX ??= -_behindHim;
        if (x < _exitX!) _retire();
      case BallPhase.trap:
        timer -= dt;
        if (timer <= 0) {
          if (play == 'pickup') {
            _setPhase(BallPhase.pickup);
          } else {
            _playBack();
          }
        }
      case BallPhase.pickup:
        // A scripted lift rather than physics: nothing about a man bending down
        // and picking a ball up is ballistic, and a spring would read as a
        // bounce.
        y = math.min(_handY, y + _liftRate * dt);
        x += (_handX - x) * math.min(1, dt * 6);
        if (y >= _handY - 0.5) _intoHands();
      case BallPhase.hold:
        timer -= dt;
        if (timer <= 0) _throwBack();
      case BallPhase.out:
        // Retire it once it is clear of the frame.
        if (x > edgeX + 30) {
          _retire();
          return;
        }
        // Safety net: a pass that somehow fails to clear the frame — a
        // mid-flight resize shrinking the scene, a long pause mangling the
        // integration — would otherwise be walked down and left dead behind him
        // forever. Treat him catching it as another touch and play it again.
        if (grounded && x <= _trapX) {
          x = _trapX;
          vx = 0;
          _setPhase(BallPhase.trap);
          timer = _range(0.3, 0.7);
        }
      case BallPhase.idle:
        break;
    }
  }
}

/// The ball on screen: it runs the sim off the scene's [WalkBeat] and draws the
/// ball, its roll and the shadow that separates from it as it rises.
///
/// Sits in the WALKER's box and scales with him, so its units are his — see the
/// note at the top of the file.
class PitchBall extends StatefulWidget {
  const PitchBall({
    required this.mood,
    required this.wind,
    required this.onCue,
    this.frozen = false,
    this.sceneWidth = 0,
    this.walkerLeft = 0,
    this.onStrike,
    this.onWatch,
    super.key,
  });

  /// **HE LOOKS AT THE BALL.** True while there is one worth looking at — one
  /// rolling in within [ballWatchDistance] of his boot, one sitting at it, one
  /// being picked up — and false again once it has gone. Screen-side like
  /// [onStrike], so the sim's cue trace stays the JS fixture's.
  final void Function(bool watching)? onWatch;

  /// He is about to play the ball back: fired [_PitchBallState.kickLead]
  /// seconds before the sim releases it, so a kick cued on it lands its
  /// contact as the ball goes.
  ///
  /// **Screen-side, not a `BallCue`.** The sim's cues and its trace are pinned
  /// to the JS fixture frame for frame, so the kick — which the JS never drew —
  /// is read off the trap timer here rather than added to the sim.
  final VoidCallback? onStrike;

  /// He has planted his feet. The ball keeps moving; he stops dealing with it.
  final bool frozen;

  final Mood mood;

  /// The wind's push on a ball in flight, from `windAccelFor`. It had no reader
  /// in the port until this: the whole weather chain resolved a gust and nothing
  /// was ever blown by it.
  final double wind;

  /// A carry, a release, or a ball going past him untouched. The sim owns the
  /// ball and the screen owns the manager, so this is how the two meet.
  final void Function(BallCue cue) onCue;

  /// Where the frame's edges are, so a pass genuinely clears it and an ignored
  /// ball genuinely leaves shot.
  final double sceneWidth;
  final double walkerLeft;

  @override
  State<PitchBall> createState() => _PitchBallState();
}

class _PitchBallState extends State<PitchBall>
    with SingleTickerProviderStateMixin {
  late final PitchBallSim _sim = PitchBallSim(
    getMood: () => widget.mood,
    onCue: widget.onCue,
  );
  late final Ticker _ticker = createTicker(_onTick);

  ValueNotifier<double>? _beat;

  /// The last frame's time and world position, which is all a step needs.
  double _last = 0;
  double _lastWorld = 0;

  /// The kick's wind-up: the gesture's contact is at 0.6 of 520ms.
  static const double kickLead = 0.31;

  /// How long the played ball is lifted off the turf, and how high, in pixels.
  /// A cosmetic hop — the sim's own y is the fixture's — so a pass that would
  /// otherwise slide away reads as struck.
  static const double _flickSeconds = 0.28;
  static const double _flickHeight = 7;

  bool _strikeCued = false;
  bool _wasTrap = false;
  bool _watching = false;
  double _flick = 0;

  /// The cosmetic lift, in pixels, on top of the sim's y.
  double get _hop => _flick <= 0
      ? 0
      : math.sin(math.pi * (1 - _flick / _flickSeconds)) * _flickHeight;

  /// **HE ONLY SWINGS ON A LEG THAT IS ALREADY GOING THAT WAY.** The cue used
  /// to fire the instant the trap timer reached [kickLead], whatever his legs
  /// were doing — so about half the time the kick played on the near leg at the
  /// back of its stride and the boot travelled backwards through the ball.
  /// Reported directly: he should only kick when his right leg is moving
  /// forwards.
  ///
  /// Forward is the thigh angle DECREASING, sampled a sixtieth of a stride
  /// ahead. `_beat` counts half-strides and `walkerThighAngle` takes whole
  /// ones, hence the halving.
  bool get _nearLegSwingingForward {
    final phase = (_beat?.value ?? 0) / 2;
    return walkerThighAngle(phase + 1 / 60, near: true) <
        walkerThighAngle(phase, near: true);
  }

  /// How far past [kickLead] the cue will wait for that window before giving up
  /// and playing anyway.
  ///
  /// A stride is the longest it can ever have to wait — the near leg comes
  /// forward once per stride — and the ball's own release is on the sim's clock
  /// rather than on this, so a cue that never fired would leave a ball leaving
  /// his feet with no kick at all.
  static const double _strikeWindow = 0.34;

  void _watchStrike(double dt) {
    final trap = _sim.phase == BallPhase.trap && _sim.play != 'pickup';
    if (trap && !_strikeCued && _sim.timer <= kickLead && !_sim.halted) {
      final late = _sim.timer <= kickLead - _strikeWindow;
      if (_nearLegSwingingForward || late) {
        _strikeCued = true;
        widget.onStrike?.call();
      }
    }
    // Left the trap for the turf: the ball has just been struck.
    if (_wasTrap && _sim.phase == BallPhase.out && _sim.grounded) {
      _flick = _flickSeconds;
    }
    if (!trap) _strikeCued = false;
    _wasTrap = trap;
    if (_flick > 0) _flick = math.max(0, _flick - dt);
  }

  void _onTick(Duration elapsed) {
    final now = elapsed.inMicroseconds / 1e6;
    final dt = now - _last;
    _last = now;
    // **How far the world ACTUALLY went**, rather than a constant pace. The beat
    // counts half-strides and one of those carries the world
    // [groundHalfStrideArtUnits] — so this is the ground's own travel, ease and
    // all, which is what keeps a settled ball still on the grass it is lying on.
    final world = (_beat?.value ?? 0) * groundHalfStrideArtUnits;
    final moved = world - _lastWorld;
    _lastWorld = world;
    if (dt <= 0) return;
    // **THE SIM ALWAYS STEPS; THE WIDGET DOES NOT ALWAYS REBUILD.** The stray
    // ball is on the grass for a small fraction of the time and `build` returns
    // an empty box for the rest of it — but the step has to keep running, since
    // it is what decides when the ball next appears. Stepping outside
    // `setState` and rebuilding only while something is drawn takes a
    // whole-subtree rebuild per frame off the home screen for most of its life.
    // The frame the ball VANISHES on still rebuilds, or it would stay painted.
    final wasVisible = _sim.visible;
    _sim.wind = widget.wind;
    _sim.halted = widget.frozen;
    _sim.step(dt, walkSpeed: moved / dt, nominalWalkSpeed: _nominalWalkSpeed);
    _watchStrike(dt);
    final watch = ballWatched(_sim.phase, _sim.x);
    if (watch != _watching) {
      _watching = watch;
      widget.onWatch?.call(watch);
    }
    if (_sim.visible || wasVisible) setState(() {});
  }

  /// His average pace, in the ball's units. What a strike is solved against.
  double get _nominalWalkSpeed =>
      groundHalfStrideArtUnits /
      (walkDurationFor(widget.mood).inMicroseconds / 2e6);

  void _syncFrame() {
    if (widget.sceneWidth <= 0) return;
    _sim.setFrame(sceneWidth: widget.sceneWidth, walkerLeft: widget.walkerLeft);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _beat = WalkBeat.maybeOf(context);
    _syncFrame();
    // Reduced motion: no ball at all rather than one parked at his boot, which
    // is what a stuck ball looks like. The JS's caller does not start the sim
    // there either.
    // **`isActive`, not `isTicking`.** A ticker muted by `TickerMode` — which
    // is every tab that is not the one on screen — is active and not ticking,
    // so starting on `!isTicking` starts one that is already running and
    // throws.
    final run = !MediaQuery.of(context).disableAnimations;
    if (run && !_ticker.isActive) {
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void didUpdateWidget(PitchBall old) {
    super.didUpdateWidget(old);
    if (old.sceneWidth != widget.sceneWidth ||
        old.walkerLeft != widget.walkerLeft) {
      _syncFrame();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_sim.visible) return const SizedBox.shrink();
    final height = (_sim.y + _hop) / _maxY;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The grounded shadow stays on the pitch, shrinking and fading as the
        // ball leaves it. It is the whole of the depth in a ball that is only
        // ever drawn as a circle.
        //
        // **IT WAS DRAWN ENTIRELY INSIDE THE BALL, which is why there was no
        // shadow to see.** Two separate faults, and the arithmetic is worth
        // keeping because both are invisible in a widget tree and obvious in
        // numbers. The box was `ballSize` wide with a `BoxShape.circle` in it,
        // and a circular decoration sizes itself off the box's SHORTEST side —
        // so a 21-wide ball got a 6-wide dot. And the box sat at
        // `bottom: ballShadowLine`, spanning [18.1, 24.1] while the ball spans
        // [16.1, 37.1]: the shadow STARTED two units above the bottom of the
        // ball and its widest row was 5.5 units up inside the silhouette, where
        // the disc is 8.9 wide against the ellipse's 10.5. Nothing reached open
        // grass in either axis. Reported from the couch twice.
        //
        // So it is seated and spread instead:
        //
        // - **the ground line runs through the MIDDLE of it**, not along its
        //   bottom edge — the lesson `_sink` in `manager_walker.dart` already
        //   learned for his boots. At the contact line the ball is only 6.2
        //   wide, so an ellipse centred there clears the silhouette.
        // - **it is wider than the ball** by [_shadowSpread] each side, which
        //   is what makes it read as a ring around the contact point rather
        //   than as something hiding under the ball.
        // - **it shrinks toward its own centre**, not its bottom. The JS's
        //   `transform-origin: center bottom` was right for a shadow sitting
        //   ABOVE the line; one that straddles the line has to stay on it.
        Positioned(
          left: ballHomeX + _sim.x - _shadowSpread,
          bottom: ballShadowLine - _shadowHeight / 2,
          width: ballSize + _shadowSpread * 2,
          height: _shadowHeight,
          child: Opacity(
            // **0.48 rather than the JS's 0.32.** Its number was for a shadow
            // that showed its own middle; this one is read at its RIM, where a
            // radial fade has already given most of its ink away, so the same
            // figure measured out at 3% darkening on a render of the real
            // widget. See [GroundShadow.core], which is the other half of it.
            opacity: (0.48 * (1 - height * 0.6)).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 1 - height * 0.55,
              child: const GroundShadow(alpha: 0.55, core: 0.5),
            ),
          ),
        ),
        Positioned(
          left: ballHomeX + _sim.x,
          bottom: ballGroundLine + _sim.y + _hop,
          width: ballSize,
          height: ballSize,
          // **THE PANELS TURN; THE LIGHT DOES NOT.** The art had its shading
          // baked in — a grey crescent down the right-hand side — so rotating
          // the file rotated the lighting with it, and a light source that
          // orbits a ball is what a TUMBLING ball looks like. Reported as the
          // spin being on the wrong axis, moving slightly up and down: the
          // ball's own dark mass was swinging over the top and back under.
          //
          // **The overlay below was the first answer and it was only half of
          // one.** A fixed highlight laid over the top cannot cancel a feature
          // underneath it that covers an eighth of the ball, so the crescent
          // went on orbiting under a stationary gloss and it was reported
          // again. The shading is off the ASSET now: `assets/penalty/ball.png`
          // was two flat colours over its base pair — (181,188,198) over the
          // light panels and (32,45,54) over the dark ones, 13% of the ball
          // between them — and both were remapped back to the panel colours
          // they were tinting. What is left is line art that means the same
          // thing at every angle. Git has the shaded original; nothing else in
          // `lib/` loads this file.
          //
          // **AND THE BALL WAS NOT ROUND, which is the other half of it.**
          // `Transform.rotate` turns about the box's centre and always did, so
          // the pivot was never the fault — but the art it was turning was.
          // Measured off the file: the outer edge ran from r=224.2 to r=228.9
          // about its own best-fit centre, 1.8% out of round, and that centre
          // sat (+0.47, +0.82) px away from the canvas centre the rotation
          // uses. An out-of-round silhouette swinging about a point it is not
          // concentric with is a bob once per revolution — reported exactly
          // that way, twice.
          //
          // So the asset is trued: re-centred on the fitted centre, masked to a
          // real circle at a radius the art fills the whole way round, and
          // resampled to 160×160. The size matters too — it was 453px drawn at
          // about 84 device px, a 5× reduction whose mipmap selection shifts
          // under a rotating transform, which is its own shimmer on top of the
          // wobble. 160 leaves headroom over the drawn size without it.
          //
          // So the rotation is untouched, and the fixed highlight and shade
          // below now do all of the lighting: the sun stays where the rest of
          // the scene's is and only the panels move.
          child: Stack(
            fit: StackFit.expand,
            children: [
              Transform.rotate(
                angle: _sim.rot * math.pi / 180,
                child: Image.asset(
                  'assets/penalty/ball.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      // Up and to the left, the same corner the scene's own
                      // light comes from.
                      center: Alignment(-0.45, -0.5),
                      radius: 0.95,
                      colors: [
                        Color(0x3DFFFFFF),
                        Color(0x00FFFFFF),
                        Color(0x38000000),
                      ],
                      stops: [0, 0.55, 1],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// How far ahead of his boot, in the figure's units, a ball rolling in is
/// close enough to look at. About a body length.
const double ballWatchDistance = 110;

/// Whether the ball is something he would be looking at right now: rolling in
/// close, trapped at his boot, or coming up into his hands. Not once it is IN
/// his hands — he looks where he is going with it — and not once it has been
/// played or ignored.
bool ballWatched(BallPhase phase, double x) => switch (phase) {
  BallPhase.incoming => x <= ballWatchDistance,
  BallPhase.trap || BallPhase.pickup => true,
  _ => false,
};

/// The grass, measured up from the bottom of the figure's box.
///
/// **His contact line, not the bottom of his picture.** There are art units of
/// empty space under his soles, and a ball resting on the box's edge would lie
/// below the ground everything else on the screen is measured from. The shadow
/// sits ON that line and the ball a shade INTO it, which is the JS's own
/// two-pixel offset between `.ps-ball` and `.ps-ball-shadow`.
final double ballShadowLine = walkerFootOffset;
final double ballGroundLine = walkerFootOffset - ballSink;
