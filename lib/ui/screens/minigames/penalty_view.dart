/// The penalty, seen from behind the ball.
///
/// **THE GOAL IS GEOMETRY, NOT A PICTURE**, and that is what the whole rebuild
/// turns on. The old scene was a flat photograph of a goalmouth with a keeper
/// sprite slid across it — so a ball could not hit a post, a net could not move,
/// and a dive was a translation. Posts, bar and net are drawn from the same
/// regulation numbers `engine/penalty_physics.dart` simulates in, which is the
/// only way the picture and the outcome can agree: the ball goes past the post on
/// screen because it went past the post in the maths.
///
/// **ONE SWIPE CARRIES THREE DECISIONS.** Where you finish is the aim, how far
/// you dragged is the power, and how much you HOOKED the drag is the curl. A game
/// that asks for a corner and then puts up a power meter has turned a kick into a
/// form; the hook is what makes bending one round a keeper something you do with
/// your thumb.
///
/// **The camera is a pinhole and nothing more.** Every point is
/// `screen = centre + f · (point - eye) / depth`, which is four lines and gives a
/// goal that grows as the ball approaches it for free. No 3D library, no matrices
/// to get wrong, and it means the net's vertices, the keeper's hands and the ball
/// are all projected by the same function — so nothing can drift out of the scene
/// relative to anything else.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/engine/penalty_physics.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';

/// Where the camera sits: behind and above the spot, looking at the goal.
///
/// **Solved rather than guessed, because the two shots fight each other.** The
/// ball at rest is a few metres from the lens and the goal is twenty-odd, so a
/// lens wide enough to fill the frame with the goal throws the ball off the
/// bottom of it — which is exactly what the first set of numbers did.
///
/// THREE constraints pin them, and the third is the one that was missing. The
/// goal has to fill about three quarters of the width; the ball at the spot has
/// to sit near the bottom of the frame rather than under it; and **eleven metres
/// has to LOOK like eleven metres.** The first two were solved for and gave a
/// camera 10m back at 2.6m — and the third was not asked, which is how a
/// regulation spot came to be reported from the couch as too close to the goal.
///
/// Only the height is free once the first constraint is met, and the height is
/// exactly what the third one wants: see [_eyeZ].
///
/// Move any of them and the others have to be re-solved. They are not taste.
/// How far behind the spot the camera stands.
const double _cameraBack = 10;
const double _eyeY = -spotDistance - _cameraBack;

/// How high it stands.
///
/// **RAISED, and that is what answers "the spot is too close to the goal".**
/// The spot is eleven metres out and always was — it is regulation, and moving
/// it would move every number [PenaltyKick] is balanced around. What was too
/// close was the PICTURE: from 2.62m the ball sat barely a goal's-height above
/// the line with the bottom half of the frame empty grass, so eleven metres
/// read as three.
///
/// The separation between the ball and the line is
/// `f · h · (1/back − 1/(back + spotDistance))`, so it scales with the camera's
/// HEIGHT and with nothing else that is free — the focal length and the camera's
/// distance are both pinned by the goal having to fill about three quarters of
/// the width. Going up to 3.9m opens that gap by half again, and it costs
/// nothing else in the scene: the goal is the same size, the frame is the same
/// shape, and the run-up is at the same depth. A gantry four metres up behind
/// the goal is also where the shot comes from on television.
const double _eyeZ = 3.9;

/// Focal length, as a fraction of the view's width.
///
/// Pinned by the goal filling about three quarters of the frame at
/// [spotDistance] plus [_cameraBack]. Not taste — but see [_focalFor], which is
/// allowed to open the lens when the view is too short to hold the shot.
const double _focal = 2.15;

/// How tall the scene is, per unit of focal length: the crossbar down to the
/// ball on the spot.
///
/// Every offset the projection produces is a multiple of `f · width`, so this is
/// the one number that says whether the shot FITS — and it is derived from the
/// camera rather than measured off a screenshot, so moving the camera moves it.
const double _sceneSpan =
    (_eyeZ - ballRadius) / _cameraBack -
    (_eyeZ - goalHeight) / (_cameraBack + spotDistance);

/// The most of the view's height the scene may take, and the air above it.
const double _maxSpan = 0.72;
const double _topMargin = 0.06;

/// Where the ball on the spot sits, as a fraction of the height.
const double _ballHeight = 0.70;

/// The lens this view can afford.
///
/// **A short, wide view cannot hold a long lens**, and that is not a taste
/// judgement: the scene is [_sceneSpan] · `f` · `width` tall whatever the height
/// is, so past a certain aspect the crossbar is simply above the top edge. It is
/// reachable — the view is an `Expanded` in a column of score lines, so on a
/// short screen it gets whatever is left. Opening the lens is the only answer
/// that keeps the goal and the ball in the same picture; it costs the goal some
/// width, which is the right thing to give up.
double _focalFor(Size view) =>
    math.min(_focal, _maxSpan * view.height / (_sceneSpan * view.width));

/// Where eye level lands.
///
/// **Derived from the BALL rather than fixed, because the scene has to frame
/// itself on a view whose shape it does not choose.** It used to be a constant
/// fraction of the height, and every offset in the projection is a fraction of
/// the WIDTH — so the whole picture slid up or down the frame as the aspect
/// changed, and the four camera numbers had been solved for one shape of window.
///
/// Anchoring on the ball fixes the one thing that must not move: it is what the
/// player aims from, it is the lowest thing in the scene that matters, and
/// everything else is placed relative to it by the projection anyway. The ball
/// gives way only to the CROSSBAR — it drops no lower than the point that keeps
/// the bar [_topMargin] inside the top edge, which with [_focalFor] holding the
/// span down is a limit a portrait view never reaches.
double _horizonY(Size view) {
  final f = _focalFor(view) * view.width;
  final ball = math.max(
    _ballHeight * view.height,
    _topMargin * view.height + _sceneSpan * f,
  );
  return ball - f * (_eyeZ - ballRadius) / _cameraBack;
}

/// The projection.
///
/// Returns null for anything behind the camera — a ball that has flown past the
/// lens has no screen position, and projecting it anyway puts it on the opposite
/// side of the frame at enormous size.
Offset? project(Vec3 point, Size view) {
  final depth = point.y - _eyeY;
  if (depth < 0.4) return null;
  final f = _focalFor(view) * view.width;
  return Offset(
    view.width / 2 + f * point.x / depth,
    _horizonY(view) - f * (point.z - _eyeZ) / depth,
  );
}

/// How big something of [size] metres appears at [y].
double scaleAt(double y, Size view, double size) {
  final depth = y - _eyeY;
  if (depth < 0.4) return 0;
  return _focalFor(view) * view.width * size / depth;
}

/// Where the goal line lands on screen.
///
/// **The seam between the stadium and the grass.** The photograph goes above it
/// and the turf starts on it, and they have to be the same number or there is a
/// gap — so it is one function both the widget and the painter read rather than
/// two that agree by hand.
double goalLineY(Size view) =>
    project(Vec3(0, 0, 0), view)?.dy ?? _horizonY(view);

/// How far past the goal line the pitch runs before whatever is behind it
/// starts, in metres.
///
/// **The goal line is not the horizon**, and treating it as one is what put a
/// wall of green above the crossbar. The seam used to be [goalLineY], so the
/// photograph — whose own field fills its bottom third — was cropped to the band
/// directly above the line and the pitch appeared to RISE behind the goal like a
/// hill. Ground does not stop at the line: there is the dead ball area, the
/// run-off and the hoardings before anything vertical begins, and all of that is
/// the painter's turf in the painter's perspective.
///
/// Seven and a half metres is the run-off behind a goal at this level. It is
/// small on screen — the band above the line is a couple of dozen pixels on a
/// phone — and that is the point: the goal stands on a pitch that carries on
/// past it rather than against a backdrop propped up on the line.
const double _beyondGoal = 7.5;

/// Where the ground gives way to what is behind it.
///
/// The photograph goes above it and the turf starts on it, and they have to be
/// the same number or there is a gap — so it is one function both the widget and
/// the painter read rather than two that agree by hand.
double standBaseY(Size view) =>
    project(Vec3(0, _beyondGoal, 0), view)?.dy ?? _horizonY(view);

/// Where the backdrop art's own ground line sits, as a fraction of its height.
///
/// All four Kenney backdrops are the same square layout: sky and cloud above, a
/// treeline, then a flat field filling the bottom. That field is the part that
/// must NOT be seen — the painter draws the ground, and a second ground behind
/// it at a different perspective is the hill the couch reported.
const double _artHorizon = 0.62;

/// Where the square backdrop art is laid inside its band.
///
/// **The art is PLACED, not fitted**, and that is the difference between the
/// treeline landing on the seam and the art's own field standing up behind the
/// goal. `BoxFit.cover` shows whichever slice the alignment picks, and on a tall
/// view the band is nearly as tall as the drawing — so no alignment exists that
/// shows only the part above the ground line, and asking for one gets you a
/// clamp and the field back.
///
/// Sizing it is what solves it. The drawing goes down far enough that its own
/// ground line, at [_artHorizon], is exactly the foot of the band; if that would
/// make it narrower than the view it is scaled up to fit the width instead and
/// the surplus goes off the top, which is sky. Either way the seam is a treeline
/// standing on grass rather than a green edge.
Rect backdropRect(Size view) {
  final band = math.max(0.0, standBaseY(view));
  final drawn = math.max(view.width, band / _artHorizon);
  return Rect.fromLTWH(
    (view.width - drawn) / 2,
    band - _artHorizon * drawn,
    drawn,
    drawn,
  );
}

/// The net, as a grid that can be pushed.
///
/// **A net that does not move is a wall**, and the moment a ball hits one it is
/// the single most convincing thing in the picture. Each vertex holds a bulge
/// depth that is set by an impact and springs back — critically damped, so it
/// settles rather than wobbling like jelly, because a goal net is heavy.
class NetMesh {
  NetMesh({this.columns = 15, this.rows = 8})
    : _bulge = List.filled((columns + 1) * (rows + 1), 0),
      _rate = List.filled((columns + 1) * (rows + 1), 0);

  final int columns;
  final int rows;

  /// How far each vertex is pushed back, in metres.
  final List<double> _bulge;
  final List<double> _rate;

  int _index(int c, int r) => r * (columns + 1) + c;

  /// The point of a vertex in pitch space, bulge included.
  ///
  /// At the BACK of the goal, not on the line — a goal is a box, and hanging the
  /// net on the line made it a flat wall with the frame drawn on top of it. The
  /// bulge pushes further back from there.
  Vec3 vertex(int c, int r) => Vec3(
    -goalHalfWidth + goalWidth * c / columns,
    goalDepth + _bulge[_index(c, r)],
    goalHeight * (1 - r / rows),
  );

  /// How many cells the side and roof panels are strung across their depth.
  ///
  /// Fewer than [columns], because they run AWAY from the camera: seven and a
  /// half metres of goal mouth gets fifteen cords and one metre eighty-five of
  /// depth does not need them.
  static const int depthCells = 4;

  /// A vertex of one side panel, [side] being −1 for the left post and +1 for
  /// the right.
  ///
  /// **A goal is a box and it had only a back.** The mouth was strung and
  /// nothing else, so a ball rolled along the inside of a post passed through
  /// open air where the side netting is — and from behind the spot the side
  /// panels are most of what says the goal has DEPTH, because they are the only
  /// surface in the picture running away from the camera.
  ///
  /// Static rather than sprung, and that is honest: the panels are pulled taut
  /// between the post and the stanchion, which is why they are the part of a net
  /// that does not billow. The back plane takes the shot and the back plane is
  /// what moves — see [strike].
  Vec3 sideVertex(int side, int c, int r) => Vec3(
    side * goalHalfWidth,
    goalDepth * c / depthCells,
    goalHeight * (1 - r / rows),
  );

  /// A vertex of the roof panel, from the crossbar back to the rear stanchion.
  Vec3 roofVertex(int c, int r) => Vec3(
    -goalHalfWidth + goalWidth * c / columns,
    goalDepth * r / depthCells,
    goalHeight,
  );

  /// A ball into the net at [at], carrying [speed].
  ///
  /// The push falls off with distance from the contact, which is what makes it a
  /// dent rather than the whole net moving — and it is capped, because a net
  /// stretched a metre and a half reads as a bag.
  void strike(Vec3 at, double speed) {
    // Deeper than it looks like it should be. A net taking a shot at 30m/s moves
    // most of a metre, and at half that the dent is invisible from the camera's
    // distance — the whole point of the mesh is that the moment of the goal is
    // the one thing in the picture that MOVES.
    final depth = math.min(1.5, speed * 0.055);
    for (var r = 0; r <= rows; r++) {
      for (var c = 0; c <= columns; c++) {
        final v = vertex(c, r);
        final dx = v.x - at.x;
        final dz = v.z - at.z;
        final away = math.sqrt(dx * dx + dz * dz);
        // Two metres of influence: wide enough that the dent has shoulders and
        // the cords either side of it get dragged in, tight enough that the far
        // corner does not know about it.
        final falloff = math.max(0.0, 1 - away / 2.1);
        _bulge[_index(c, r)] += depth * falloff * falloff;
      }
    }
  }

  /// Spring the mesh back.
  ///
  /// The EDGES are pinned — a net is tied to the frame — so the boundary is held
  /// at zero rather than left to spring, which is what stops the whole sheet
  /// drifting backwards after a few shots.
  void settle(double dt) {
    // SOFTER and less damped than a first guess, so it ripples two or three
    // times before it settles rather than snapping straight back. A net is heavy
    // but it is also slack, and the recoil is most of what reads as netting.
    const stiffness = 58.0;
    const damping = 6.5;
    for (var r = 0; r <= rows; r++) {
      for (var c = 0; c <= columns; c++) {
        final i = _index(c, r);
        if (c == 0 || c == columns || r == 0 || r == rows) {
          _bulge[i] = 0;
          _rate[i] = 0;
          continue;
        }
        _rate[i] += (-stiffness * _bulge[i] - damping * _rate[i]) * dt;
        _bulge[i] += _rate[i] * dt;
      }
    }
  }

  /// Whether anything is still springing.
  ///
  /// The view uses it to decide whether to rebuild at all — see the note there.
  bool get moving {
    for (var i = 0; i < _bulge.length; i++) {
      if (_bulge[i].abs() > 1e-4 || _rate[i].abs() > 1e-4) return true;
    }
    return false;
  }

  void reset() {
    for (var i = 0; i < _bulge.length; i++) {
      _bulge[i] = 0;
      _rate[i] = 0;
    }
  }
}

/// The keeper, drawn from where his hands are.
///
/// Not a sprite slid across: [dive] is how far through a dive he is, and it
/// ROTATES him — a keeper at full stretch is horizontal, and the difference
/// between a figure that leans and one that lies down is most of what says he is
/// diving rather than side-stepping.
class KeeperPose {
  const KeeperPose({
    required this.hand,
    required this.dive,
    required this.side,
  });

  final Vec3 hand;

  /// 0 standing, 1 at full stretch.
  final double dive;

  /// Which way, -1 to 1.
  final double side;
}

/// Everything the painter needs, so the widget can be rebuilt without it.
class PenaltyFrame {
  const PenaltyFrame({
    required this.ball,
    required this.ballVisible,
    required this.roll,
    required this.keeper,
    required this.net,
    required this.aimPreview,
    this.taker = 0,
    this.aimPhase = 0,
  });

  final Vec3 ball;
  final bool ballVisible;
  final double roll;
  final KeeperPose keeper;
  final NetMesh net;

  /// How far through the run-up he is: 0 waiting on the arc, 1 planted and
  /// through the ball. Past 1 he is following through and on his way out of
  /// shot.
  final double taker;

  /// The line the player is currently dragging, in screen space, or null.
  final ({Offset from, Offset to, Offset control})? aimPreview;

  /// How far the aim line's dashes have marched, in pixels.
  final double aimPhase;
}

/// How long his thigh-to-boot reads, and how far the torso and head sit above
/// the hip. All in metres, so the figure is a person rather than a proportion of
/// a card.
const double _keeperLeg = 0.88;
const double _keeperTorso = 0.64;
const double _keeperNeck = 0.22;

/// How far the legs open, from straight down, at rest and at full stretch.
const double _legSplitRest = 6.5 * math.pi / 180;
const double _legSplitDive = 30 * math.pi / 180;

/// Where the arms point, measured from straight up. The leading one swings out
/// past horizontal as he reaches; the trailing one tucks in.
const double _armRest = 52 * math.pi / 180;
const double _armLead = 96 * math.pi / 180;
const double _armTrail = 22 * math.pi / 180;

/// The keeper's figure, solved in SCREEN space from the one point the physics
/// actually knows.
///
/// **HIS GLOVES GO WHERE THE REACH TEST SAYS THEY ARE.** They were 1.3 to 2.4
/// METRES away: the figure was placed at `hand.x * 0.42` and the arm was then
/// drawn to a body-relative offset, so the two never had to agree. A GATHERED
/// ball — which the engine pins to `keeperHand` exactly — floated in open air
/// beside the gloves that had supposedly caught it, and a save happened at a
/// point where no glove was drawn.
///
/// So the solve runs the other way round. The glove is the projected hand, the
/// shoulder is [keeperReach] back along the arm, and the body hangs off that.
/// It is the file's own stated principle finally applied to the figure: one
/// projection for the net's vertices, the hands and the ball, so nothing can
/// drift against anything else.
///
/// **AND A LIMB KEEPS ITS LENGTH.** The leading arm used to run from 0.40 to
/// 1.35 units across the dive while the trailing one halved, and the legs
/// changed length with the stride — an arm that more than triples is not an arm
/// reaching, it is an arm growing, which is what read as the Fantastic Four.
/// Every segment here is a fixed length at an animated ANGLE, which is what a
/// joint is.
typedef KeeperRig = ({
  /// The leading glove. On the projected hand, by construction.
  Offset glove,
  Offset trailGlove,
  Offset shoulder,
  Offset hip,
  Offset head,
  Offset leftBoot,
  Offset rightBoot,

  /// Between the boots, for a shadow or a scale.
  Offset feet,

  /// Pixels per metre at his depth.
  double unit,

  /// How far over he has gone, in radians. The painter needs it for nothing but
  /// the head tilt; the joints are already solved.
  double lean,
});

KeeperRig? keeperRigFor(KeeperPose pose, Size view) {
  final hand = project(pose.hand, view);
  if (hand == null) return null;
  // Scaled at the depth he STANDS at rather than at his fingertips: he is a body
  // on the goal line, and the hand is only the end of it.
  const bodyY = -0.25;
  final unit = scaleAt(bodyY, view, 1);
  if (unit <= 0) return null;

  final dive = pose.dive.clamp(0.0, 1.0);
  final lean = dive * 1.15 * (pose.side.isNegative ? -1 : 1);
  // No lead arm until he has actually gone: at `side == 0` picking one made him
  // look like he was holding something.
  final way = pose.side.abs() < 0.05 ? 0.0 : (pose.side < 0 ? -1.0 : 1.0);
  final out = way == 0 ? 1.0 : way;

  // Local frame, hip at the origin, head up. Every length below is a constant.
  final torso = unit * _keeperTorso;
  final legLen = unit * _keeperLeg;
  // **The arm is the PHYSICS' own reach.** `keeperReach` is what the save test
  // measures with, so the drawn arm and the arm that saves it are one number.
  final armLen = unit * keeperReach;

  final localHip = Offset.zero;
  final localShoulder = Offset(0, -torso);
  final localHead = Offset(0, -torso - unit * _keeperNeck);

  final split = _legSplitRest + (_legSplitDive - _legSplitRest) * dive;
  final legOut = math.sin(split) * legLen;
  final legDown = math.cos(split) * legLen;
  final localLeft = Offset(-legOut, legDown);
  final localRight = Offset(legOut, legDown);

  final leadAngle = _armRest + (_armLead - _armRest) * dive;
  final trailAngle = _armRest + (_armTrail - _armRest) * dive;
  final localLead =
      localShoulder +
      Offset(math.sin(leadAngle) * armLen * out, -math.cos(leadAngle) * armLen);
  final localTrail =
      localShoulder +
      Offset(
        -math.sin(trailAngle) * armLen * out,
        -math.cos(trailAngle) * armLen,
      );

  // **`keeperHand` IS THE CENTRE OF HIS REACH, not a fingertip**, whatever its
  // name says — `_keeperGotIt` tests the ball against it and then allows another
  // [keeperReach] on top, and `_parry` calls it "the centre of the gloves". So
  // it is his chest, the arms go out from there, and a GATHERED ball ends up
  // pinned to it, which is exactly where a keeper holds one he has caught.
  //
  // Anchoring a glove on it instead put the whole figure a wingspan out of
  // place and left the reach circle centred on nobody.
  final anchor = localShoulder;

  final c = math.cos(lean);
  final sn = math.sin(lean);
  Offset turn(Offset p) => Offset(p.dx * c - p.dy * sn, p.dx * sn + p.dy * c);
  // The whole figure is placed so the anchor lands on the hand. Nothing here
  // stretches to reach it; he MOVES to it.
  final origin = hand - turn(anchor);
  Offset at(Offset local) => origin + turn(local);

  final leftBoot = at(localLeft);
  final rightBoot = at(localRight);
  return (
    glove: at(localLead),
    trailGlove: at(localTrail),
    shoulder: at(localShoulder),
    hip: at(localHip),
    head: at(localHead),
    leftBoot: leftBoot,
    rightBoot: rightBoot,
    feet: Offset(
      (leftBoot.dx + rightBoot.dx) / 2,
      (leftBoot.dy + rightBoot.dy) / 2,
    ),
    unit: unit,
    lean: lean,
  );
}

/// One dash and one gap of the aim line, in pixels.
const double aimDash = 9;
const double aimGap = 7;

/// How fast the dashes march, in pixels a second.
const double aimMarch = 46;

/// [source] cut into dashes, offset by [phase] pixels along its own length.
///
/// **A solid line says where you are pointing; a MARCHING one says which way the
/// ball is going.** The dashes run from the ball toward the goal, which is the
/// one thing the preview was not saying — a static curve reads as a target,
/// while the same curve with movement in it reads as a shot.
///
/// Pure, and separate from the painter, because path arithmetic is exactly the
/// kind of thing that is easy to get subtly wrong and impossible to see.
Path dashedPath(
  Path source, {
  double dash = aimDash,
  double gap = aimGap,
  double phase = 0,
}) {
  final out = Path();
  final period = dash + gap;
  if (period <= 0) return out;
  for (final metric in source.computeMetrics()) {
    // The phase runs BACKWARDS along the path so the dashes travel forwards.
    var at = -(phase % period);
    while (at < metric.length) {
      final start = math.max(0.0, at);
      final end = math.min(metric.length, at + dash);
      if (end > start) out.addPath(metric.extractPath(start, end), Offset.zero);
      at += period;
    }
  }
  return out;
}

/// The taker's own proportions, in metres.
const double _takerLeg = 0.90;
const double _takerTorso = 0.64;
const double _takerNeck = 0.22;
const double _takerArm = 0.45;

/// The man taking it, solved in screen space.
///
/// **A LEG SWINGS; IT DOES NOT GROW.** The kicking leg used to run from 0.80 to
/// 1.05 units across the strike — a 31% stretch arriving exactly when the eye is
/// on it — because the boot was placed at an offset and the thigh drawn to reach
/// it. Every segment here is a fixed length at an animated angle.
///
/// **And his standing boot is the anchor**, because that is the contact: the
/// world path places the foot he is standing on and the rest of him hangs off
/// it. Anchoring the hip instead let the plant foot drift off the turf.
typedef TakerRig = ({
  Offset ground,
  Offset hip,
  Offset shoulder,
  Offset head,
  Offset plantBoot,
  Offset kickBoot,
  Offset leftHand,
  Offset rightHand,
  double unit,

  /// 1 while he is on screen, easing to 0 as he leaves it.
  double fade,
});

TakerRig? takerRigFor(double t, Size view) {
  if (t <= 0) return null;
  // Gone by the time the ball is halfway: he has struck it and the camera is
  // watching the ball, not him.
  final fade = (1 - (t - 1) / 0.9).clamp(0.0, 1.0);
  if (fade <= 0) return null;

  // Solved rather than chosen: he has to enter from the edge without filling the
  // frame (the camera is only ten metres back, so anything closer than about
  // five is taller than the view), and finish a boot's width to the side of the
  // ball rather than on top of it.
  final run = t.clamp(0.0, 1.0);
  final ease = 1 - (1 - run) * (1 - run);
  final at = Vec3(
    -3.15 + (-0.62 + 3.15) * ease,
    (-spotDistance - 5.1) + 4.75 * ease,
    0,
  );
  final ground = project(at, view);
  if (ground == null) return null;
  final unit = scaleAt(at.y, view, 1);
  if (unit <= 0) return null;

  final legLen = unit * _takerLeg;
  final armLen = unit * _takerArm;
  final torso = unit * _takerTorso;

  // The stride, and then the STRIKE. Up to the plant his legs alternate on a
  // running cycle; from the plant the kicking leg swings through and stays
  // through, which is the follow-through that says the ball has been hit.
  final striking = (t - 0.82).clamp(0.0, 1.0) / 0.18;
  final cycle = math.sin(run * 3.4 * math.pi);
  // Angles from straight down, so a swing is a rotation about the hip.
  final kickAngle = striking > 0 ? 0.36 + striking * 0.78 : cycle * 0.36;
  final plantAngle = striking > 0 ? -0.16 : -cycle * 0.34;

  Offset fromHip(Offset hip, double angle) =>
      hip + Offset(math.sin(angle) * legLen, math.cos(angle) * legLen);

  // The hip is wherever it has to be for the PLANT boot to be on the turf.
  final hip =
      ground -
      Offset(math.sin(plantAngle) * legLen, math.cos(plantAngle) * legLen);
  final shoulder = hip + Offset(0, -torso);

  // Arms counter-swing, which is most of what makes a run read as a run — by
  // angle, at a length that never moves.
  final swingArm = 0.62 + cycle * 0.22;
  final other = 0.62 - cycle * 0.22;
  return (
    ground: ground,
    hip: hip,
    shoulder: shoulder,
    head: hip + Offset(0, -torso - unit * _takerNeck),
    plantBoot: fromHip(hip, plantAngle),
    kickBoot: fromHip(hip, kickAngle),
    leftHand:
        shoulder +
        Offset(-math.sin(swingArm) * armLen, math.cos(swingArm) * armLen),
    rightHand:
        shoulder + Offset(math.sin(other) * armLen, math.cos(other) * armLen),
    unit: unit,
    fade: fade,
  );
}

class PenaltyPainter extends CustomPainter {
  const PenaltyPainter({required this.frame, required this.turf});

  final PenaltyFrame frame;
  final Color turf;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGround(canvas, size);
    _paintNet(canvas, size);
    _paintKeeper(canvas, size);
    _paintFrame(canvas, size);
    if (frame.ballVisible) _paintBall(canvas, size);
    // AFTER the ball, and before the aim: he is nearer the camera than
    // everything else in the scene, so he passes in front of it.
    _paintTaker(canvas, size);
    _paintAim(canvas, size);
  }

  /// The grass and the markings.
  ///
  /// **A flat green rectangle has no perspective in it**, so the ground is where
  /// most of the depth in this picture comes from: mown bands that converge, a
  /// scatter of tufts that get smaller and denser toward the line, and the real
  /// markings — the six-yard box, the penalty area, the arc and the spot. Every
  /// one of them is projected, so all of it agrees about where the camera is.
  void _paintGround(Canvas canvas, Size size) {
    // **NOTHING ABOVE THE RUN-OFF.** It used to paint a flat sky gradient across
    // the whole frame and then turf from the horizon down, which left the goal
    // standing against grass and a wash of blue — so the net had to be a sheet
    // to read as a hole at all. The band above the seam is the STADIUM's now: a
    // photograph, behind the painter, showing through wherever this does not
    // paint. See [standBaseY] for the seam, and [_beyondGoal] for why it is not
    // the goal line: the pitch runs on past the goal, and stopping it on the
    // line stood the photograph's own field up behind the crossbar.
    final ground = Rect.fromLTRB(
      0,
      standBaseY(size) - 1,
      size.width,
      size.height,
    );
    // **CLIPPED, because the markings run past the seam.** Bands and chalk are
    // projected quads, and a band laid beyond the run-off projects ABOVE it —
    // which, painted over the photograph, is grass in the sky. It did not show
    // while the stripes were at five per cent alpha; it is exactly what would
    // show now they can be seen.
    canvas.save();
    canvas.clipRect(ground);
    canvas.drawRect(
      ground,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(turf, Colors.black, 0.28)!,
            turf,
            Color.lerp(turf, Colors.white, 0.06)!,
          ],
          stops: const [0, 0.45, 1],
        ).createShader(ground),
    );

    // Mown bands, 5m wide, running away from the camera. They converge because
    // they are projected, which is the single cheapest depth cue there is.
    //
    // **BOTH shades, and every band.** Every other band got a five per cent
    // white wash and the ones between it got nothing, so the stripe was one
    // barely-there edge rather than a pattern — from the couch the pitch read as
    // flat green. A mown pitch is light against DARK, so the alternate bands are
    // cut the other way and both are strong enough to survive the turf gradient
    // over them.
    final light = Paint()..color = Colors.white.withValues(alpha: 0.10);
    final dark = Paint()..color = Colors.black.withValues(alpha: 0.07);
    for (var i = -6; i <= 6; i++) {
      final quad = _quad(
        size,
        Vec3(-30, -spotDistance - 12 + i * 5, 0),
        Vec3(30, -spotDistance - 12 + i * 5, 0),
        Vec3(30, -spotDistance - 12 + (i + 1) * 5, 0),
        Vec3(-30, -spotDistance - 12 + (i + 1) * 5, 0),
      );
      if (quad != null) canvas.drawPath(quad, i.isEven ? light : dark);
    }

    // Tufts. Seeded, so the pitch is the same pitch every kick — a lawn that
    // reshuffles reads as static rather than as grass.
    final rng = math.Random(19);
    final tuft = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    for (var i = 0; i < 260; i++) {
      final y = -spotDistance - 11 + rng.nextDouble() * 14;
      final x = (rng.nextDouble() - 0.5) * 34;
      final at = project(Vec3(x, y, 0), size);
      if (at == null) continue;
      final h = scaleAt(y, size, 0.09);
      canvas.drawLine(at, at.translate(0, -h), tuft);
    }

    final chalk = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    void line(Vec3 a, Vec3 b) {
      final pa = project(a, size);
      final pb = project(b, size);
      if (pa != null && pb != null) canvas.drawLine(pa, pb, chalk);
    }

    // The goal line, the six-yard box, the penalty area and the arc — the real
    // ones, at the real distances.
    line(Vec3(-24, 0, 0), Vec3(24, 0, 0));
    line(Vec3(-9.16, 0, 0), Vec3(-9.16, -5.5, 0));
    line(Vec3(9.16, 0, 0), Vec3(9.16, -5.5, 0));
    line(Vec3(-9.16, -5.5, 0), Vec3(9.16, -5.5, 0));
    line(Vec3(-20.16, 0, 0), Vec3(-20.16, -16.5, 0));
    line(Vec3(20.16, 0, 0), Vec3(20.16, -16.5, 0));
    line(Vec3(-20.16, -16.5, 0), Vec3(20.16, -16.5, 0));
    // The D, as a fan of chords about the spot.
    Offset? last;
    for (var i = 0; i <= 24; i++) {
      final a = math.pi * (0.12 + 0.76 * i / 24);
      final at = project(
        Vec3(math.cos(a) * 9.15, -spotDistance - math.sin(a) * 9.15, 0),
        size,
      );
      if (at != null && last != null) canvas.drawLine(last, at, chalk);
      last = at ?? last;
    }

    final spot = project(Vec3(0, -spotDistance, 0), size);
    if (spot != null) {
      canvas.drawOval(
        Rect.fromCenter(
          center: spot,
          width: scaleAt(-spotDistance, size, 0.26),
          height: scaleAt(-spotDistance, size, 0.26) * 0.4,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }
    canvas.restore();
  }

  /// A projected quad, or null if any corner is behind the camera.
  Path? _quad(Size size, Vec3 a, Vec3 b, Vec3 c, Vec3 d) {
    final pts = [a, b, c, d].map((v) => project(v, size)).toList();
    if (pts.any((p) => p == null)) return null;
    final path = Path()..moveTo(pts[0]!.dx, pts[0]!.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p!.dx, p.dy);
    }
    return path..close();
  }

  void _paintNet(Canvas canvas, Size size) {
    final mesh = frame.net;
    // Two passes: a dark cord slightly wider, then the light one over it. A
    // single white line at a third alpha disappears against a floodlit stand and
    // reads as dirt against a dark one; the pair reads as string against both.
    final shade = Paint()
      ..color = Colors.black.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final cord = Paint()
      ..color = Colors.white.withValues(alpha: 0.46)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    // **NO SHEET.** There was a dark quad behind the cords so the goalmouth read
    // as a hole rather than as a grid floating on the grass — which it had to,
    // because there was nothing behind the goal but a wash of blue. With the
    // stadium back there the cords are enough, and a net you can see the crowd
    // through is what a net looks like. The strung mesh is the only thing drawn.

    // One strand, projected. Every cord in the goal is drawn through this, so
    // the back plane, the two sides and the roof cannot end up strung in
    // different weights by hand.
    void strand(Iterable<Vec3> points, Paint under, Paint over) {
      final path = Path();
      var started = false;
      for (final v in points) {
        final p = project(v, size);
        if (p == null) continue;
        started ? path.lineTo(p.dx, p.dy) : path.moveTo(p.dx, p.dy);
        started = true;
      }
      if (!started) return;
      canvas.drawPath(path, under);
      canvas.drawPath(path, over);
    }

    // **The sides and the roof first, and DIMMER.** They are behind the mouth's
    // own cords from this camera and they run away from it, so at the back
    // plane's weight they crowd the picture instead of describing it. Knocked
    // back, they read as what they are: the depth the goal has.
    final sideShade = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final sideCord = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final side in [-1, 1]) {
      for (var r = 0; r <= mesh.rows; r++) {
        strand(
          [
            for (var c = 0; c <= NetMesh.depthCells; c++)
              mesh.sideVertex(side, c, r),
          ],
          sideShade,
          sideCord,
        );
      }
      for (var c = 0; c <= NetMesh.depthCells; c++) {
        strand(
          [for (var r = 0; r <= mesh.rows; r++) mesh.sideVertex(side, c, r)],
          sideShade,
          sideCord,
        );
      }
    }
    for (var r = 0; r <= NetMesh.depthCells; r++) {
      strand(
        [for (var c = 0; c <= mesh.columns; c++) mesh.roofVertex(c, r)],
        sideShade,
        sideCord,
      );
    }
    for (var c = 0; c <= mesh.columns; c++) {
      strand(
        [for (var r = 0; r <= NetMesh.depthCells; r++) mesh.roofVertex(c, r)],
        sideShade,
        sideCord,
      );
    }

    for (var r = 0; r <= mesh.rows; r++) {
      strand(
        [for (var c = 0; c <= mesh.columns; c++) mesh.vertex(c, r)],
        shade,
        cord,
      );
    }
    for (var c = 0; c <= mesh.columns; c++) {
      strand(
        [for (var r = 0; r <= mesh.rows; r++) mesh.vertex(c, r)],
        shade,
        cord,
      );
    }
  }

  /// The posts and the bar, drawn as the cylinders they are — the width comes
  /// from [scaleAt] at the goal line, so they thicken as the camera would show
  /// them rather than being a fixed number of pixels.
  void _paintFrame(Canvas canvas, Size size) {
    final width = math.max(2.0, scaleAt(0, size, postRadius * 2));
    final metal = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    void bar(Vec3 a, Vec3 b) {
      final pa = project(a, size);
      final pb = project(b, size);
      if (pa != null && pb != null) canvas.drawLine(pa, pb, metal);
    }

    // The back stanchions first, thinner and knocked back — they are further away
    // and they are what the side netting hangs off.
    final rear = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, scaleAt(goalDepth, size, postRadius * 1.6))
      ..strokeCap = StrokeCap.round;
    void rearBar(Vec3 a, Vec3 b) {
      final pa = project(a, size);
      final pb = project(b, size);
      if (pa != null && pb != null) canvas.drawLine(pa, pb, rear);
    }

    rearBar(
      Vec3(-goalHalfWidth, goalDepth, 0),
      Vec3(-goalHalfWidth, goalDepth, goalHeight),
    );
    rearBar(
      Vec3(goalHalfWidth, goalDepth, 0),
      Vec3(goalHalfWidth, goalDepth, goalHeight),
    );
    rearBar(
      Vec3(-goalHalfWidth, goalDepth, goalHeight),
      Vec3(goalHalfWidth, goalDepth, goalHeight),
    );

    bar(Vec3(-goalHalfWidth, 0, 0), Vec3(-goalHalfWidth, 0, goalHeight));
    bar(Vec3(goalHalfWidth, 0, 0), Vec3(goalHalfWidth, 0, goalHeight));
    bar(
      Vec3(-goalHalfWidth, 0, goalHeight),
      Vec3(goalHalfWidth, 0, goalHeight),
    );
  }

  /// The keeper, as a PERSON.
  ///
  /// He was three strokes and a circle, which reads as a bollard. A figure needs
  /// the parts a person has: two legs that split when he dives, a torso, two arms
  /// that both reach, a head with a face on it, and gloves that are a different
  /// colour from the shirt so the thing that saves it is the thing you can see.
  ///
  /// **The dive is a ROTATION, not a slide.** Everything is drawn in his own
  /// frame — head up, feet down — and the whole frame is then turned by how far
  /// he is through the dive, so at full stretch he is horizontal. That is the
  /// difference between a keeper diving and a keeper side-stepping, and it is one
  /// `canvas.rotate` rather than a second set of poses to draw.
  void _paintKeeper(Canvas canvas, Size size) {
    final rig = keeperRigFor(frame.keeper, size);
    if (rig == null) return;
    final unit = rig.unit;

    const shirtColour = Color(0xFFFFC63D);
    const shortsColour = Color(0xFF23303F);
    const gloveColour = Color(0xFF1F2A37);
    const skin = Color(0xFFE8B78E);

    Paint limb(Color c, double w) => Paint()
      ..color = c
      ..strokeWidth = unit * w
      ..strokeCap = StrokeCap.round;

    // Legs, hip to boot. They SPLIT with the dive — a keeper at full stretch has
    // one leg trailing — and they do it by ANGLE, at a length that never moves.
    canvas.drawLine(rig.hip, rig.leftBoot, limb(shortsColour, 0.17));
    canvas.drawLine(rig.hip, rig.rightBoot, limb(shortsColour, 0.17));
    // Torso.
    canvas.drawLine(rig.hip, rig.shoulder, limb(shirtColour, 0.30));
    // Both arms out, and both exactly `keeperReach` long: the leading one swings
    // out past horizontal as he reaches and the trailing one tucks in, which is
    // where the reach visibly is. Neither grows.
    canvas.drawLine(rig.shoulder, rig.glove, limb(shirtColour, 0.14));
    canvas.drawLine(rig.shoulder, rig.trailGlove, limb(shirtColour, 0.13));
    for (final glove in [rig.glove, rig.trailGlove]) {
      canvas.drawCircle(glove, unit * 0.10, Paint()..color = gloveColour);
    }
    // Head, and a face — two dots are enough at this size, and without them he
    // is a ball on a stick. The eyes turn with him.
    canvas.drawCircle(rig.head, unit * 0.13, Paint()..color = skin);
    final eye = Paint()..color = const Color(0xFF20262E);
    final c = math.cos(rig.lean);
    final sn = math.sin(rig.lean);
    for (final side in [-1.0, 1.0]) {
      final dx = side * unit * 0.045;
      canvas.drawCircle(rig.head + Offset(dx * c, dx * sn), unit * 0.02, eye);
    }
  }

  /// The man taking it.
  ///
  /// **A penalty with nobody taking it is a ball leaving the spot on its own**,
  /// and that is what this scene was. He is drawn in the same primitives as the
  /// keeper — this file's own idiom — rather than imported from a rig built for
  /// a manager in a coat.
  ///
  /// He is seen from BEHIND, because the camera stands behind the taker, which
  /// is where the shot comes from on television. So he runs up from the left of
  /// frame and across, and the last thing the player sees of him is his back as
  /// the ball goes.
  ///
  /// **The path is in WORLD space, not screen space.** He starts near the camera
  /// and finishes beside the ball ten metres away, so he has to SHRINK as he
  /// runs — and projecting the path is the only way that agrees with the pitch
  /// he is running on. Interpolating two screen points would slide a
  /// same-sized figure across a converging pitch.
  void _paintTaker(Canvas canvas, Size size) {
    final rig = takerRigFor(frame.taker, size);
    if (rig == null) return;
    final unit = rig.unit;

    const shirt = Color(0xFFE9EEF5);
    const shorts = Color(0xFF1E2A38);
    const skin = Color(0xFFD9A277);
    const boot = Color(0xFF15181D);

    Paint limb(Color c, double w) => Paint()
      ..color = c
      ..strokeWidth = unit * w
      ..strokeCap = StrokeCap.round;

    canvas.saveLayer(
      null,
      Paint()..color = Colors.white.withValues(alpha: rig.fade),
    );

    // Legs, hip to boot, both the same length however far they swing.
    for (final foot in [rig.plantBoot, rig.kickBoot]) {
      canvas.drawLine(rig.hip, foot, limb(shorts, 0.17));
      canvas.drawCircle(foot, unit * 0.075, Paint()..color = boot);
    }
    canvas.drawLine(rig.hip, rig.shoulder, limb(shirt, 0.30));
    for (final hand in [rig.leftHand, rig.rightHand]) {
      canvas.drawLine(rig.shoulder, hand, limb(shirt, 0.13));
      canvas.drawCircle(hand, unit * 0.065, Paint()..color = skin);
    }
    // The back of his head — no face, because we are behind him.
    canvas.drawCircle(rig.head, unit * 0.135, Paint()..color = skin);
    canvas.drawArc(
      Rect.fromCircle(center: rig.head, radius: unit * 0.135),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFF2B2118),
    );
    canvas.restore();
  }

  /// The ball, as a BALL.
  ///
  /// A white circle with three dots on it was a golf ball. What makes a football
  /// read at 20 pixels is three things: a SHADED sphere rather than a flat disc,
  /// the classic panel pattern (a centre pentagon with five around it), and the
  /// pattern TURNING — the roll comes from the physics, so the ball spins at the
  /// rate it is actually travelling.
  void _paintBall(Canvas canvas, Size size) {
    final at = project(frame.ball, size);
    if (at == null) return;
    final radius = math.max(2.5, scaleAt(frame.ball.y, size, ballRadius));

    // The shadow, on the ground under it. The only cue for height on a flat
    // pitch, so it stays at z = 0 and tightens as the ball climbs.
    final under = project(Vec3(frame.ball.x, frame.ball.y, 0), size);
    if (under != null) {
      final lift = (frame.ball.z / 2.6).clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: under,
          width: radius * 2 * (1 - lift * 0.45),
          height: radius * 0.75 * (1 - lift * 0.45),
        ),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.32 * (1 - lift * 0.6)),
      );
    }

    // A sphere: lit from the upper left, dark at the lower right.
    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.45),
          radius: 1.05,
          colors: [Color(0xFFFFFFFF), Color(0xFFF2F4F6), Color(0xFFB9C1C9)],
          stops: [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: at, radius: radius)),
    );

    // The panels, turned by how far it has rolled. Clipped to the sphere so the
    // pattern wraps rather than sitting on top of it.
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: at, radius: radius)),
    );
    canvas.translate(at.dx, at.dy);
    canvas.rotate(frame.roll * 0.3);
    final panel = Paint()..color = const Color(0xFF222A33);
    void pentagon(Offset centre, double r, double turn) {
      final path = Path();
      for (var i = 0; i < 5; i++) {
        final a = turn + i * 2 * math.pi / 5;
        final p = centre + Offset(math.cos(a) * r, math.sin(a) * r);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path..close(), panel);
    }

    pentagon(Offset.zero, radius * 0.30, -math.pi / 2);
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      pentagon(
        Offset(math.cos(a) * radius * 0.72, math.sin(a) * radius * 0.72),
        radius * 0.24,
        a + math.pi / 5,
      );
    }
    canvas.restore();

    // The rim last, over the panels, so the silhouette stays clean.
    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.7, radius * 0.07),
    );
  }

  /// The drag, while it is happening.
  ///
  /// Drawn as the CURVE it will produce rather than as a straight line to the
  /// finger, because the hook is the part a player cannot otherwise see they are
  /// putting on it.
  void _paintAim(Canvas canvas, Size size) {
    final aim = frame.aimPreview;
    if (aim == null) return;
    final path = Path()
      ..moveTo(aim.from.dx, aim.from.dy)
      ..quadraticBezierTo(aim.control.dx, aim.control.dy, aim.to.dx, aim.to.dy);
    canvas.drawPath(
      dashedPath(path, phase: frame.aimPhase),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      aim.to,
      6,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(PenaltyPainter old) => true;
}

/// A swipe, turned into an aim.
///
/// **The hook is the curl**, and it is measured as the drag's deviation from the
/// straight line between its ends — so a flick with a bend in it bends the ball,
/// and a straight pull does not. Signed, so which way you hook it is which way it
/// goes.
PenaltyAim aimFromSwipe({
  required Offset from,
  required Offset to,
  required Offset mid,
  required Size view,
}) {
  // Where the finger finished, mapped through the goalmouth's own screen box —
  // so pointing at the inside of the post aims at the inside of the post.
  final postLeft = project(Vec3(-goalHalfWidth, 0, goalHeight / 2), view);
  final postRight = project(Vec3(goalHalfWidth, 0, goalHeight / 2), view);
  final barTop = project(Vec3(0, 0, goalHeight), view);
  final ground = project(Vec3(0, 0, 0), view);
  if (postLeft == null ||
      postRight == null ||
      barTop == null ||
      ground == null) {
    return (across: 0, lift: 0.3, power: 0.6, curl: 0);
  }
  final halfSpan = (postRight.dx - postLeft.dx) / 2;
  // Scaled by the aim range's own headroom: `across = 1` is 0.9m outside the
  // post, so the screen edge has to reach past the frame or a miss is
  // impossible.
  final across =
      ((to.dx - view.width / 2) / halfSpan) *
      (goalHalfWidth / (goalHalfWidth + 0.9));
  final lift =
      ((ground.dy - to.dy) / (ground.dy - barTop.dy)) *
      (goalHeight / (goalHeight + 0.7));

  // Power from the drag's LENGTH against the height of the view, so the gesture
  // is the same on any screen.
  final pulled = (from - to).distance / (view.height * 0.55);

  // The hook: how far the drag's midpoint sits off the straight line.
  final line = to - from;
  final len = line.distance;
  final off = len < 1
      ? 0.0
      : ((mid.dx - from.dx) * line.dy - (mid.dy - from.dy) * line.dx) / len;
  final curl = (off / (view.width * 0.09)).clamp(-1.0, 1.0);

  return (
    across: across.clamp(-1.2, 1.2),
    lift: lift.clamp(0.0, 1.15),
    power: pulled.clamp(0.12, 1.0),
    curl: curl,
  );
}

/// The scene: a ticker, a swipe, and the physics between them.
///
/// The widget owns NOTHING about whether a shot went in — it hands the kick to
/// [PenaltyKick] and reports what came back. That split is what lets the whole
/// simulation be tested without a frame being rendered, and it is the same
/// division the match screen keeps with `match_clock`.
class PenaltyView extends StatefulWidget {
  const PenaltyView({
    super.key,
    required this.readChance,
    this.keeperSpread = keeperReach,
    this.backdrop = Backdrop.grass,
    required this.onResult,
    required this.turf,
    this.rng,
  });

  /// The division's own ramp — how often the keeper goes the right way.
  final double readChance;

  /// How far this division's keeper can spread himself. See [keeperReachFor] —
  /// his read chance is one ramp and his reach is the other.
  final double keeperSpread;

  /// What is behind the goal.
  ///
  /// **A goal standing against a wash of flat colour has nothing behind it**,
  /// which is why the net had to be a dark sheet to read as a hole at all. With a
  /// horizon back there the net can be what a net is — cords you see the world
  /// through. Green treeline by default; the mood is a knob because the
  /// customiser and the training screens want the same four.
  final Backdrop backdrop;

  /// Called once per kick, with what actually happened — and with where the ball
  /// finished, because "wide" has a side and only the flight knows which.
  final void Function(PenaltyResult result, FramePart? frame, double ballX)
  onResult;

  final Color turf;

  /// Seeded in a test; the real game uses the platform's.
  final math.Random? rng;

  @override
  State<PenaltyView> createState() => PenaltyViewState();
}

class PenaltyViewState extends State<PenaltyView>
    with SingleTickerProviderStateMixin {
  /// Created in `initState` rather than lazily.
  ///
  /// A `late final` that nothing touches until `dispose` is CREATED in dispose,
  /// and `createTicker` looks up an inherited `TickerMode` — which is not
  /// something you may do on a deactivated element. It exists from the start and
  /// is simply not running.
  Ticker? _ticker;
  late final math.Random _rng = widget.rng ?? math.Random();

  final NetMesh _net = NetMesh();

  PenaltyKick? _kick;
  Duration _last = Duration.zero;

  /// How long the ball stays where it finished before the spot is reset.
  double _hold = 0;

  /// Seconds left of the run-up, and how long one takes.
  ///
  /// **The kick exists from the moment the swipe ends; only the BALL waits.**
  /// The shot is decided, the keeper's plan is rolled, and `canShoot` is already
  /// false — what the run-up delays is `advance`, so nothing about the physics
  /// or the outcome depends on the animation in front of it.
  double _runUp = 0;
  static const double _runUpSeconds = 0.62;

  /// Test seam: true while he is still running in.
  bool get runningUp => _runUp > 0;

  /// How far the aim line's dashes have marched, in pixels.
  ///
  /// A drag is the one thing on this screen that moves without the ball moving,
  /// so the ticker has to be awake for it — see [_wake].
  double _aimPhase = 0;

  /// Test seam.
  double get aimPhase => _aimPhase;

  Offset? _dragFrom;
  Offset? _dragTo;
  Offset? _dragMid;

  /// Where the ball sits before it is struck, and after a reset.
  static final Vec3 _spot = Vec3(0, -spotDistance, ballRadius);

  /// Test seam: the shot currently in flight, or null.
  PenaltyKick? get kick => _kick;

  bool get canShoot => _kick == null && _hold <= 0;

  /// **THE TICKER ONLY RUNS WHEN SOMETHING IS MOVING**, and it is not an
  /// optimisation.
  ///
  /// A live `Ticker` keeps a frame scheduled forever, so a tree containing one
  /// never settles — which meant `pumpAndSettle` timed out in every test that so
  /// much as opened this screen, including the ones about the gate and the
  /// cooldown that have nothing to do with the ball. It also repainted the whole
  /// pitch sixty times a second to draw an identical picture.
  ///
  /// Started by a swipe, stopped when the flight, the hold and the net have all
  /// finished. The aim preview does not need it: that repaints from the drag's
  /// own `setState`.
  void _wake() {
    _last = Duration.zero;
    final ticker = _ticker;
    if (ticker != null && !ticker.isActive) ticker.start();
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_frame);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _frame(Duration now) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : ((now - _last).inMicroseconds / 1e6).clamp(0.0, 1 / 20);
    _last = now;

    if (_dragFrom != null) _aimPhase += aimMarch * dt;

    if (_runUp > 0) {
      _runUp -= dt;
      // The ball does not move while he is running at it. Everything else —
      // the net settling, a rebuild — carries on.
      if (mounted) setState(() {});
      _net.settle(dt);
      return;
    }

    final kick = _kick;
    if (kick != null && !kick.done) {
      final wasIn = kick.position.y;
      kick.advance(dt);
      // Into the net: the frame it crosses the line is the frame the mesh is
      // pushed, and the speed it was carrying is how far.
      if (wasIn < 0 && kick.position.y >= 0 && kick.result == null) {
        _net.strike(kick.position, kick.velocity.length);
      }
      if (kick.done) {
        _hold = 1.9;
        widget.onResult(kick.result!, kick.hitFrame, kick.position.x);
      }
    } else if (_hold > 0) {
      // **THE PICTURE HOLDS; THE KEEPER DOES NOT.** The word goes up and the
      // screen stays on the goalmouth for the best part of two seconds, and he
      // was suspended at full stretch for every frame of it. The kick is decided
      // and the ball is where it finished — what is still happening is that he
      // is coming down out of the dive, with anything he caught in his gloves.
      kick?.advance(dt);
      _hold -= dt;
      if (_hold <= 0) {
        _kick = null;
        _net.reset();
      }
    }
    _net.settle(dt);
    // **ONLY REBUILD WHEN SOMETHING IS MOVING.** It rebuilt every frame
    // unconditionally, which is a repaint of the whole pitch sixty times a second
    // to draw an identical picture — and, worse, a tree that never settles, so
    // `pumpAndSettle` in every test that opened this screen timed out. The
    // ticker keeps running because it is what notices the next swipe; what stops
    // is the work.
    // A drag counts as live: the dashes march while the thumb is down.
    final live = _kick != null || _hold > 0 || _net.moving || _dragFrom != null;
    if (!live) {
      _ticker?.stop();
      return;
    }
    if (mounted) setState(() {});
  }

  void _shoot(Size view) {
    final from = _dragFrom;
    final to = _dragTo;
    if (from == null || to == null || !canShoot) return;
    // A tap rather than a drag is not a shot. Without this a stray touch spent
    // one of the five attempts on a ball dribbled at the keeper.
    if ((from - to).distance < view.height * 0.08) return;
    final aim = aimFromSwipe(
      from: from,
      to: to,
      mid: _dragMid ?? Offset.lerp(from, to, 0.5)!,
      view: view,
    );
    setState(() {
      _kick = PenaltyKick(
        aim: aim,
        plan: planKeeper(readChance: widget.readChance, aim: aim, rng: _rng),
        reach: widget.keeperSpread,
      );
      _dragFrom = null;
      _dragTo = null;
      _dragMid = null;
      _runUp = _runUpSeconds;
    });
    _wake();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final view = Size(constraints.maxWidth, constraints.maxHeight);
      final kick = _kick;
      final ball = kick?.position ?? _spot;
      // 0 before the swipe, 1 at the plant, and on past it through the
      // follow-through as the ball flies.
      final taker = kick == null
          ? 0.0
          : _runUp > 0
          ? 1 - _runUp / _runUpSeconds
          : 1 + kick.elapsed * 1.4;
      final hand = kick?.keeperHand ?? Vec3(0, -0.3, keeperStandZ);
      // **HIS OWN NUMBER, not a second copy of the curve.** This was the dive
      // worked out again from the clock, on a straight ramp — so the limbs were
      // on a different curve from the glove they hang off, and neither knew about
      // the landing. `keeperDive` is what moved the hand.
      final dive = kick?.keeperDive ?? 0.0;

      final from = _dragFrom;
      final to = _dragTo;
      final mid = _dragMid;
      return GestureDetector(
        key: const ValueKey('penalty-swipe'),
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) {
          setState(() {
            _dragFrom = d.localPosition;
            _dragTo = d.localPosition;
            _dragMid = null;
          });
          // The dashes need a clock, and this is the only thing on screen that
          // moves while the ball is still on the spot.
          _wake();
        },
        onPanUpdate: (d) => setState(() {
          _dragTo = d.localPosition;
          // The midpoint is SAMPLED rather than computed, which is the whole
          // trick: the middle of the path the thumb actually took is what
          // carries the hook, and the middle of a straight line between the ends
          // carries nothing.
          final start = _dragFrom;
          if (start != null && (start - d.localPosition).distance > 24) {
            _dragMid ??= d.localPosition;
          }
        }),
        onPanEnd: (_) => _shoot(view),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // **BEHIND the painter, and only down to the run-off.** The band
            // above it is what stands behind the ground; the strip of pitch
            // beyond the goal is the PAINTER's turf, in the painter's
            // perspective — see [standBaseY], the one number the two of them
            // share so there is no seam, and [_beyondGoal] for why it is not the
            // goal line.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: standBaseY(view),
              // Laid so the art's own ground line falls on the seam, and clipped
              // to the band by the Stack. Fitted to the band instead — which is
              // what it did — the band was the art's flat green field and
              // nothing else, standing up behind the crossbar like a hill. See
              // [backdropRect].
              child: Stack(
                children: [
                  Positioned.fromRect(
                    rect: backdropRect(view),
                    child: ArtImage(
                      key: const ValueKey('penalty-backdrop'),
                      path: backdropPath(widget.backdrop),
                      fit: BoxFit.fill,
                      fallback: const ColoredBox(color: Color(0xFF6DB3E8)),
                    ),
                  ),
                ],
              ),
            ),
            CustomPaint(
              size: view,
              painter: PenaltyPainter(
                turf: widget.turf,
                frame: PenaltyFrame(
                  ball: ball,
                  ballVisible: true,
                  roll: kick?.roll ?? 0,
                  keeper: KeeperPose(
                    hand: hand,
                    dive: dive,
                    side: kick?.plan.side ?? 0,
                  ),
                  net: _net,
                  taker: taker,
                  aimPhase: _aimPhase,
                  aimPreview:
                      from == null || to == null || (from - to).distance < 8
                      ? null
                      : (
                          from: from,
                          to: to,
                          // Mirrored through the line, so the preview bends the way
                          // the ball will rather than the way the thumb went.
                          control: mid == null
                              ? Offset.lerp(from, to, 0.5)!
                              : Offset(
                                  from.dx + to.dx - mid.dx,
                                  from.dy + to.dy - mid.dy,
                                ),
                        ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// The shipped line for each outcome.
///
/// `penalty.*` has had all of these since before the port and most were
/// unreachable — a game with four corner buttons and a coin flip had no way to
/// produce a post, a crossbar or a shot dragged wide. They all happen now because
/// the ball goes where it is struck.
String penaltyCopyKey(PenaltyResult result, FramePart? frame, double x) =>
    switch (result) {
      PenaltyResult.goal => 'mg.goal',
      PenaltyResult.saved => 'mg.saved',
      PenaltyResult.over => 'penalty.over_the_bar',
      PenaltyResult.wide => x < 0 ? 'penalty.wide_left' : 'penalty.wide_right',
      PenaltyResult.frame =>
        frame == FramePart.crossbar ? 'penalty.crossbar' : 'penalty.post',
    };
