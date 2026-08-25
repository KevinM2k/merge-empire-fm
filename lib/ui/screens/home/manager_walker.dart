/// The manager, walking. Ported from the rig in `components/PitchScene.js` and
/// its keyframes in `styles/league-scene.css`.
///
/// He is the player's AVATAR, not one of their footballers — the customiser
/// dresses him, and on the scene the ball comes TO him rather than being
/// dribbled by him, so the figure reads as the gaffer the game casts you as.
///
/// **He wears the player's own look now.** The rig is code, because limbs have to
/// turn; everything that does not move — hair, beard, headwear, glasses, the coat
/// or suit over the kit, a scarf — is the JS's OWN artwork out of
/// `data/manager_art.g.dart`, recoloured per look. It was a hand-transcribed
/// crop haircut and a flat kit before, which meant the whole look system (four
/// builds, four outfits, twelve hairstyles, hats, faces, beards, hair colours and
/// the look packs that sell them) rendered as one hardcoded man.
///
/// **Six tracks, one clock.** The JS drives the rig with six CSS keyframe
/// animations sharing a duration: two thighs, two shins, two arms, plus a
/// vertical bob. Every one of them is a rotation about a named joint, so the
/// whole thing is a handful of rotations hung off one `AnimationController`.
///
/// **Linear on the limbs, eased on the bob**, and the CSS says why: `ease-in-out`
/// zeroes velocity at each keyframe, which reads as the leg PAUSING at full
/// extension. A vertical bounce should decelerate at the top; a stride should
/// not.
///
/// Three things the JS does not have, added because the figure is the first thing
/// the game shows and it looked like a paper doll: a ground shadow that tightens
/// as he rises, an ankle that keeps the boot flatter than the shin it hangs off,
/// and a stride-long sway of the whole body. All three are cheap and none of them
/// touch the keyframes.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:merge_empire_fc/data/manager_art.dart';
import 'package:merge_empire_fc/data/manager_art.g.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/gesture_poses.dart';
import 'package:merge_empire_fc/ui/screens/home/walk_ramp.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_scene.dart';
import 'package:merge_empire_fc/ui/screens/home/walker_figure.dart';
import 'package:merge_empire_fc/ui/widgets/svg_canvas.dart';

/// The figure's own space, shared with `data/manager_art.g.dart` so a hat lands
/// on the head with no positioning of its own.
/// One layer of the head's furniture, and how much of it to draw.
///
/// [hideAbove] is a y in the art's own 120x170 space: above it, this layer is
/// not drawn. It exists for exactly one thing — a hat hiding the hair going
/// through it — and it is on the LAYER rather than on the whole head because the
/// hat itself must not be clipped by its own brow. See [hatCrownY].
///
/// [clipToSkull] keeps this layer inside the skull circle. **The brow line is
/// not enough on its own**: the hair paths deliberately bulge OUTSIDE the skull
/// so the hair reads as having thickness, and under anything snug — a beanie, a
/// cap — that bulge escaped around the sides of the hat while every part of it
/// above the brow was correctly hidden. Reported as hair popping out of the top
/// of hats. The JS reaches the same place by `clip-path="url(#psvSkull)"` on the
/// front hair, and its comment records three narrower fixes that each failed
/// before this one.
typedef HeadLayer = ({String svg, double? hideAbove, bool clipToSkull});

/// One head layer, clipped to below a hat's brow and inside the skull when it
/// is hair being worn under something solid.
class _HeadArt extends StatelessWidget {
  const _HeadArt({required this.layer});

  final HeadLayer layer;

  @override
  Widget build(BuildContext context) {
    Widget art = SvgArt(svg: layer.svg);
    if (layer.clipToSkull) {
      art = ClipPath(clipper: const _SkullClipper(), child: art);
    }
    final above = layer.hideAbove;
    if (above == null) return art;
    return ClipRect(
      clipper: _BelowClipper(above / managerArtHeight),
      child: art,
    );
  }
}

/// The skull, as the art draws it: a circle at (62, 48.5) with r 12.5 in the
/// 120x170 space — the JS's `psvSkull` clip path, to the number.
class _SkullClipper extends CustomClipper<Path> {
  const _SkullClipper();

  static const double _cx = 62;
  static const double _cy = 48.5;
  static const double _r = 12.5;

  @override
  Path getClip(Size size) => Path()
    ..addOval(
      Rect.fromLTRB(
        size.width * (_cx - _r) / managerArtWidth,
        size.height * (_cy - _r) / managerArtHeight,
        size.width * (_cx + _r) / managerArtWidth,
        size.height * (_cy + _r) / managerArtHeight,
      ),
    );

  @override
  bool shouldReclip(_SkullClipper old) => false;
}

/// Keeps the bottom [_BelowClipper.from] of a box, as a fraction of its height.
///
/// A fraction rather than pixels: every layer fills the walker's box and the box
/// is whatever the scene gives it, so an art-unit line has to be expressed
/// against the height it is drawn at.
class _BelowClipper extends CustomClipper<Rect> {
  const _BelowClipper(this.from);

  final double from;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, size.height * from, size.width, size.height);

  @override
  bool shouldReclip(_BelowClipper old) => old.from != from;
}

const double walkerWidth = managerArtWidth;
const double walkerHeight = managerArtHeight;

/// One full stride, at the NEUTRAL mood. Every other mood has its own tempo —
/// see `walkDurationFor` — and the ground is timed off whichever one is running,
/// so a cheerful stride and the grass under it speed up together.
const Duration walkCycle = Duration(milliseconds: 1800);

/// Where his boots meet the ground, in the art's own space.
///
/// NOT the bottom of the box. The figure is 170 tall and his soles are at 152.5,
/// so there are 17.5 units of empty art under him — and the shadow was pinned to
/// the box's bottom edge, which put it that far below his feet. It went
/// unnoticed only because the shadow was collapsing to a dot; the moment it
/// became an ellipse he was visibly hovering over it.
///
/// [PitchScene] stands him on it too, so the contact line the home screen
/// measures is the line his boots are actually on.
/// **DERIVED from the lowest the SOLE reaches**, so it cannot drift from the leg.
/// The lowest rather than the mean: at every other frame his boot is then a unit
/// or two ABOVE the line, which is the JS's own float, and a boot that sometimes
/// hovers is far less noticeable than one that sometimes sinks into the turf.
final double walkerFootline = () {
  var lowest = double.negativeInfinity;
  for (var i = 0; i < 720; i++) {
    final t = i / 720;
    final sole =
        math.max(walkerBootSoleY(t), walkerBootSoleY(t, near: false)) -
        walkerHipRise(t);
    if (sole > lowest) lowest = sole;
  }
  return lowest;
}();

/// The leg, in art units. **These are the lengths the rig is DRAWN at**, and
/// the IK below solves against them, so the two cannot disagree.
///
/// They used to: the constants said 30 and 27 while `_leg` drew the knee at
/// hip+30 and the ankle at hip+54 — a 24-unit shin. The stride was computed off
/// 27 and walked off 24, which is a 5% moonwalk before anything else went wrong.
const double walkerThigh = 30;

/// **TWENTY-FOUR, the JS's own.** Its shin rect runs y126→150 against a thigh of
/// y96→126, so the lower leg is SHORTER than the upper. The port had both at 30,
/// which lengthened the leg by six units and is part of why he read as
/// long-legged and small-headed.
const double walkerShin = 24;

/// y96 in the JS's markup, where both thigh rects start.
const double _hipY = 96;

/// How far the hips rise, twice a stride. The JS's `--bob`.
const double _bob = 4;

/// The bob — `psvBob`, transcribed: nothing at the extremes of the step, its full
/// height at mid-stance, twice a cycle.
///
/// **A FIXED curve, not one derived from the legs**, and that is deliberate after
/// trying it the other way. Lifting the figure by however far its supporting foot
/// is off the floor gives an exact contact at every frame — no float, no skate —
/// and it reads as BOUNCING, because the JS's joint angles were never drawn to sit
/// on a flat floor and the correction needed is seven units against a bob of four.
/// The JS accepts a foot that floats a couple of units and keeps the hips smooth.
/// That is the walk that looks right, so that is the walk.
///
/// **The one eased track on the figure**, and the CSS says why the limbs are not:
/// `ease-in-out` zeroes velocity at each keyframe, which on a LEG reads as it
/// pausing at full extension. A vertical bounce genuinely should decelerate at the
/// top.
double walkerHipRise(double t) =>
    _bob * math.sin(Curves.easeInOut.transform((t * 2) % 1) * math.pi).abs();

/// **THE WALK IS THE JS'S OWN KEYFRAMES, PLAYED.**
///
/// The port solved it the other way round for a while: the foot's PATH was the
/// input and the joints came out of it by inverse kinematics, so the planted foot
/// travelled at exactly the ground's rate and could not skate. That is measurably
/// truer and it looked worse — solving for the longest step the legs allow gives a
/// 48-unit stride, he lunged, and it kept a 40-degree bend in the leg he was
/// standing on. What the eye actually reads is a STRAIGHT leg to stand on, and
/// that is what these four tracks give.
///
/// So: `psvThighN` / `psvThighF` / `psvShinN` / `psvShinF` out of
/// `league-scene.css`, transcribed. **Linear, all four.**
///
/// **Positive is BACKWARDS.** He faces +x and a rotation is clockwise, so a limb
/// hanging from a joint swings its far end toward -x as the angle grows. The thigh
/// runs -31 (forward, heel strike) to +25 (behind him, push-off).
const _Track _thighNear = [(0, -31), (0.5, 25), (1, -31)];
const _Track _thighFar = [(0, 25), (0.5, -31), (1, 25)];

/// The shin, RELATIVE to the thigh — it is drawn inside it, so the two compose.
///
/// It stays inside 13 degrees through the whole stance, which is the straight leg
/// to stand on, and folds to 60 to swing the foot through. That is where a walk's
/// knee flexion lives.
const _Track _shinNear = [(0, 6), (0.25, 4), (0.5, 13), (0.75, 60), (1, 6)];
const _Track _shinFar = [(0, 13), (0.25, 60), (0.5, 6), (0.75, 4), (1, 13)];

double walkerThighAngle(double t, {bool near = true}) =>
    _sample(near ? _thighNear : _thighFar, t % 1);

double walkerShinAngle(double t, {bool near = true}) =>
    _sample(near ? _shinNear : _shinFar, t % 1);

/// The boot's angle in the world, positive toes-down.
///
/// **It follows the shin, which is what the JS does**: its boot is a `<path>`
/// INSIDE `.psv-shinN` with no animation of its own, so it turns with the lower
/// leg and nothing else.
///
/// The port used to solve this against the GROUND instead, holding the sole flat
/// through the stance and rolling heel-to-toe across it. That is more nearly how a
/// foot works, and it put a POINTED TOE on the end of every step — which the
/// original does not do, and which reads as a dancer rather than a manager.
double walkerBootAngle(double t, {bool near = true}) =>
    walkerThighAngle(t, near: near) + walkerShinAngle(t, near: near);

/// Where the ankle ends up given those angles — FORWARD kinematics.
///
/// [x] is forward of the hip, [y] absolute in the art's space. The bob is not
/// folded in: it is a translate on the whole figure, so the joints never see it,
/// which is how the JS has it too.
({double x, double y}) walkerAnkle(double t, {bool near = true}) {
  final thigh = _deg(walkerThighAngle(t, near: near));
  final shin = thigh + _deg(walkerShinAngle(t, near: near));
  // A limb of length L hanging from the origin and rotated by θ puts its far end
  // at (-L·sinθ, L·cosθ).
  return (
    x: -(walkerThigh * math.sin(thigh) + walkerShin * math.sin(shin)),
    y: _hipY + walkerThigh * math.cos(thigh) + walkerShin * math.cos(shin),
  );
}

/// How far his planted foot travels in half a stride, in art units.
///
/// **This is the number the ground has to match**, and with played keyframes it is
/// a MEAN rather than a rate. The JS's planted foot does not travel at a constant
/// speed, and for the first few per cent it goes backwards against a ground going
/// forwards. That is the residual skate, and it is the price of the poses that
/// look right. Matching the mean is what stops him drifting across the pitch on
/// top of it.
final double walkerStrideArtUnits = walkerAnkle(0).x - walkerAnkle(0.5).x;

/// How far the boot's lowest corner hangs below the ankle, at boot angle [deg].
///
/// The boot runs from 3.5 behind the ankle to 11.5 in front of it with its sole
/// 3.5 below — see `_WalkerPainter._leg` — so rotating it swings the toe down and
/// the heel up, or the other way about. Whichever corner ends up lowest is the
/// one in contact.
double _bootSoleDrop(double deg) {
  final a = _deg(deg);
  final toe = _bootToe * math.sin(a) + _bootSole * math.cos(a);
  final heel = -_bootHeel * math.sin(a) + _bootSole * math.cos(a);
  return math.max(toe, heel);
}

/// Where the boot's SOLE is, at phase [t] — the part actually touching grass.
///
/// Public because "his foot is on the ground" is a statement about the boot and
/// not about the ankle: the ankle rides up and down over it as the foot rolls,
/// the boot turns with the shin, so how far its lowest corner hangs below the
/// ankle changes through the step.
double walkerBootSoleY(double t, {bool near = true}) =>
    walkerAnkle(t, near: near).y +
    _bootSoleDrop(walkerBootAngle(t, near: near));

/// The boot, measured from the ankle, in art units.
const double _bootToe = 11.5;
const double _bootHeel = 3.5;
const double _bootSole = 3.5;

/// Where the near foot is, at rig phase [t], in art units — forward is POSITIVE.
///
/// Public because the one thing worth pinning about the gait is that the planted
/// foot and the ground agree, and that is a statement about this function rather
/// than about anything a widget renders.
double walkerFootX(double t) => walkerAnkle(t).x;

/// How far his soles sit above the bottom of his box, in art units.
final double walkerFootOffset = walkerHeight - walkerFootline;

double _deg(double d) => d * math.pi / 180;

/// A keyframed track: stops at 0..1 through the cycle, in degrees.
typedef _Track = List<(double at, double deg)>;

/// Read a track at [t], on a CATMULL-ROM spline through its stops.
///
/// Not straight lines between them, and not an ease either — both are wrong for
/// a walk, in opposite directions.
///
/// Straight lines is what this did, and it is what CSS `linear` does between
/// keyframes: the value is continuous but its VELOCITY is not, so the shin
/// snaps direction at each of its four stops and the leg reads as hinged rather
/// than swung. Easing each segment instead zeroes the velocity at every stop,
/// which the JS's own note warns against — that reads as the leg pausing at full
/// extension, and a stride should not dwell.
///
/// Catmull-Rom is the one that is neither: it passes through every keyframe
/// exactly, so the JS's numbers are still the JS's numbers, and it arrives at
/// each with the velocity implied by its neighbours — no corners and no
/// dwelling. The track is CYCLIC, so the tangents wrap: the last stop's
/// neighbour is the first, which is what stops the loop jolting as it comes
/// round.
double _sample(_Track track, double t) {
  // Every track repeats its first stop at 1 to close the loop; the knots are
  // the ones before that.
  final n = track.length - 1;
  if (n < 1) return track.first.$2;
  if (n < 3) {
    // Two knots is a straight there-and-back; a spline through it is the same
    // line, and the wrap-around indexing below needs three to be meaningful.
    for (var i = 0; i < track.length - 1; i++) {
      final (a, from) = track[i];
      final (b, to) = track[i + 1];
      if (t >= a && t <= b) {
        final span = b - a;
        if (span <= 0) return from;
        final u = (t - a) / span;
        // Cosine, not linear: with one stop each way there is no neighbour to
        // take a tangent from, and a sine swing is what a limb on a pendulum
        // does anyway.
        return from + (to - from) * (0.5 - 0.5 * math.cos(u * math.pi));
      }
    }
    return track.last.$2;
  }

  var seg = 0;
  for (var i = 0; i < track.length - 1; i++) {
    if (t >= track[i].$1 && t <= track[i + 1].$1) {
      seg = i;
      break;
    }
  }
  final span = track[seg + 1].$1 - track[seg].$1;
  final u = span <= 0 ? 0.0 : (t - track[seg].$1) / span;

  double knot(int i) => track[((i % n) + n) % n].$2;
  final v0 = knot(seg - 1);
  final v1 = knot(seg);
  final v2 = knot(seg + 1);
  final v3 = knot(seg + 2);

  return 0.5 *
      ((2 * v1) +
          (-v0 + v2) * u +
          (2 * v0 - 5 * v1 + 4 * v2 - v3) * u * u +
          (-v0 + 3 * v1 - 3 * v2 + v3) * u * u * u);
}

// The JS's own keyframes, verbatim.
/// The arms, still the JS's own keyframes: they swing free and there is nothing
/// for them to be solved against.
/// `psvArmN` / `psvArmF`, and **the pairing with the legs is the point.**
///
/// Positive is backwards, the same sense as the thigh. At t=0 the near thigh is
/// -31 (forward) and the near arm is +27 (back), so the arm you can see opposes
/// the leg you can see — which is what a person does, and what stops a walk
/// reading as a shuffle. The far pair mirror them, so the FORWARD arm always
/// belongs with the forward leg on the other side of him.
const _Track _armNear = [(0, 27), (0.5, -27), (1, 27)];
const _Track _armFar = [(0, -27), (0.5, 27), (1, -27)];

/// And so is the elbow. The JS hangs the forearm at a static -52, which is a
/// hinge that never hinges — the arm swings from the shoulder as one plank. It
/// closes as the arm comes forward and opens as it goes back, which is what an
/// arm does.
/// **A WALKING ARM'S ELBOW BARELY BENDS.** These were -38 to -68, which on top
/// of a shoulder swinging to -27 put the forearm at -95 from vertical — pointing
/// horizontally forwards, so the gaffer strolled the touchline holding an arm
/// out like a man checking for rain. Ten to thirty degrees is what an elbow does
/// at a walk; anything more is a jog.
const _Track _elbowNear = [
  (0, -9),
  (0.25, -20),
  (0.5, -31),
  (0.75, -20),
  (1, -9),
];
const _Track _elbowFar = [
  (0, -31),
  (0.25, -20),
  (0.5, -9),
  (0.75, -20),
  (1, -31),
];

/// The cradle: both arms forward, both forearms folded up in front of the chest.
///
/// **THE FOREARM IS NOT THE JS'S NUMBER, and it cannot be.** The JS hangs its
/// forearm at a static -52 and folds to -110 for the carry — a delta of 58. The
/// port REBASED that rest: -38/-68 put the forearm at -95 from vertical with the
/// shoulder swing on top, which is a man strolling the touchline with an arm
/// held out, so the walking elbow is -9 to -31 here. Copying -110 across on top
/// of the new rest folded the arm forty degrees too far and it read exactly as
/// reported: odd. Same DELTA off the port's own rest instead.
const double carryArm = -20;
const double carryFore = -78;

/// How tall the shadow's own box is, as a fraction of his.
///
/// Raised from 0.045: at that height it was a 7px sliver under a 230px figure,
/// which is a mark on the grass rather than a shadow, and the gap between the
/// sole and the top of it was most of what read as floating. At 0.10 the top of
/// the ellipse reaches the soles, which is the point — a shadow a boot does not
/// touch is a shadow of something else.
const double _shadowBand = 0.10;

/// How far left of the feet's midpoint the shadow sits, in art units.
///
/// Back to the JS's plain 3.5: its step is centred on the hips, so there is no
/// solved asymmetry left to correct for.
const double _shadowBias = 3.5;

/// The shadow's OWN half-width beyond the feet, in art units.
///
/// **THE SHADOW HAS TO FOLLOW THE STRIDE.** It was a fixed 34% ellipse centred on
/// his box, so at the widest point of the walk — one leg forward, one trailing —
/// the rear boot was outside it and he read as floating over a puddle that had
/// nothing to do with him. It spans the FEET now, from the rear one to the front,
/// which means it stretches and shrinks twice a stride exactly as the legs do.
/// The pad is the width of the body over them.
const double _shadowPad = 13;

/// Where that box has to sit for its centre to land on [walkerFootline].
///
/// Derived rather than typed, so it cannot go stale if either fraction moves:
/// `Align` puts a child of height fH inside a box of height H with its centre at
/// H/2 + a(H - fH)/2, and we want that centre on the footline.
final Alignment _shadowAlignment = Alignment(
  0,
  (2 * walkerFootline / walkerHeight - 1) / (1 - _shadowBand),
);

/// Where both feet are at [t], as a centre and a width in art units.
///
/// The far leg runs half a cycle behind the near one — that is the whole of what
/// makes it a walk — so the pair of them is `walkerFootX(t)` and `walkerFootX(t + 0.5)`.
({double centre, double width}) _footSpan(double t) {
  final near = walkerFootX(t);
  final far = walkerFootX((t + 0.5) % 1);
  return (centre: (near + far) / 2, width: (near - far).abs());
}

/// And where they are when he is STANDING — both legs straight down, so both
/// ankles are directly under their own hip and the pair spans nothing.
///
/// Not a typed zero: it is what [walkerAnkle] gives for the angles a planted
/// figure holds, and writing it out is how it stays true if the rig's rest
/// angles ever move.
const ({double centre, double width}) _standSpan = (centre: 0, width: 0);

/// How far the figure is SUNK into its own shadow, in art units.
///
/// The shadow's centre is at [walkerFootline] by construction, so in principle
/// the soles land on it — and on screen he still read as standing on TOP of the
/// ellipse rather than in it. The boot art carries its own sole below the
/// footline, and the shadow is tall enough now that the difference shows. Sinking
/// him a third of the shadow's own height puts the contact where the eye expects
/// it: the ground line through the middle of the shadow, not along its top edge.
final double _sink = _shadowBand * walkerHeight / 3;

/// How far the head sits BACK from where the art drew it, in art units.
///
/// The skull was centred at x 62 and the torso runs 50.5 to 65.5 — centre 58 —
/// so the head sat four units forward of the body it is on. On a figure in
/// three-quarter profile a little of that reads as the neck craning to look
/// where he is going; four units of it reads as a head stuck on at the front.
///
/// **The whole head moves, not the skull.** Hair, beard, glasses and hat are all
/// drawn in the art's own space against a skull at 62, so shifting the painted
/// head alone would slide the face out from under its own hat. Applied to the
/// group, which is why it is a `FractionalTranslation` around all of them rather
/// than a number in [_HeadPainter].
const double _headSetBack = 3;

/// How far the whole head group is lifted, in art units.
///
/// **There was nowhere for a neck to be.** The skull is a circle at (62, 48.5)
/// r12.5, so its underside is y61 and the chin reaches 61.8 — and the shirt's
/// shoulders start at y57. The head OVERLAPPED the body by four units, which is a
/// head resting straight on a collar: no throat, no gap, and the jaw reading as
/// part of the shirt.
///
/// Seven units up puts the chin three clear of the shoulder line, which is enough
/// for the neck to be a neck. **The whole group moves, exactly as [_headSetBack]
/// does** — hair, beard, glasses, hat and the painted skull together, because all
/// of that art is drawn against a skull at 48.5 and lifting one layer of it slides
/// the face out from under its own hat.
const double _headLift = 7;

/// How he CARRIES his head, by mood — degrees, positive dropping the chin.
///
/// **The cheapest bit of acting on the figure and the one that reads furthest.**
/// A manager's head is up when it is going well and down when it is not, and at
/// this size the tilt is legible when nothing else about his face is: the mouth is
/// four pixels across on a phone.
///
/// It is a BASELINE, not a pose. A gesture's own head track (`checkwatch` looks
/// down, `handsonhead` bows) is added on top, so a crushed manager checking his
/// watch looks further down than a pleased one doing the same thing — which is
/// what you would expect and what a replacement rather than a sum would lose.
///
/// Small numbers on purpose: twelve degrees is a beaten man, and much past that he
/// is inspecting his own boots.
///
/// **The UP end came down.** Seven degrees of chin-up read as a man addressing
/// the stand rather than watching a match, and the two moods it applies to are
/// the two the dugout cam and the full-time screen spend most of their time in.
/// The DOWN end is untouched: nobody has ever said a beaten manager looks too
/// beaten.
double moodHeadTilt(Mood mood) => switch (mood) {
  Mood.elated => -2,
  Mood.pleased => -1,
  Mood.neutral => 0,
  Mood.glum => 6,
  Mood.crushed => 12,
};

/// How far he sways, once a stride. A walk is not a figure on rails.
const double _sway = 1.6;

/// The look a walker draws when the save has none.
///
/// A real look is generated at boot and stored — see `game_runner.boot` — so this
/// is the shape a widget test gets rather than the shape a player does.
///
/// **Rolled ONCE.** `normalizeAvatar(null)` generates a RANDOM look, and this was
/// a getter that re-rolled on every read: a walker with no stored look changed
/// hair, beard and outfit on every rebuild, which on the home screen is every
/// tick of the clock. It also made anything comparing two reads of it compare two
/// different men.
final ManagerLook defaultManagerLook = normalizeAvatar(null);

/// One instance of "play this gesture now".
///
/// A wrapper rather than a bare [Gesture] because two consecutive fist pumps are
/// two gestures: identity is what tells the rig to start again, and a value type
/// would compare equal and be ignored.
class GestureCue {
  GestureCue(this.gesture);

  final Gesture gesture;
}

class ManagerWalker extends StatefulWidget {
  const ManagerWalker({
    required this.kit,
    required this.skin,
    required this.hair,
    this.look,
    this.mood = Mood.neutral,
    this.walking = true,
    this.standing = false,
    this.comfort = 'ok',
    this.gesture,
    this.idle,
    this.carrying = false,
    this.ballLayer,
    super.key,
  });

  /// The club's colour — he wears the same kit as the side.
  final Color kit;

  /// Fallbacks for a look that does not name its own.
  final Color skin;
  final Color hair;

  /// What he is wearing, from `club.managerAvatar`. Null takes the default.
  final ManagerLook? look;

  /// How the season is going, which is what his mouth says.
  final Mood mood;

  /// Stopped is a real state: the scene freezes when it is not being watched.
  final bool walking;

  /// He is PLANTED — his legs stop and the rest of him does not.
  ///
  /// **Not a synonym for `walking: false`, which is a different thing
  /// entirely**: that is a scene nobody is looking at, and it stops him dead,
  /// blink and all. This is a man standing on a touchline being filmed, and the
  /// dugout cam is what it is for.
  ///
  /// The legs go to their untransformed REST — both straight, together — rather
  /// than to a frame of the cycle, which is what `animation: none` on the four
  /// leg tracks leaves behind in `league-scene.css`. There is no [t] that gives
  /// that pose: the two thighs only ever meet at -3 degrees, and there with one
  /// shin folded to 60 to swing the foot through. The bob, the sway and the
  /// stride's shadow span go with them — all three are the walk.
  ///
  /// What he does INSTEAD of walking is [idle]'s business, not this flag's: a
  /// planted man with no idle is a photograph, which is the defect the
  /// stylesheet's "Standing still, not stood still" block was written to kill.
  final bool standing;

  /// How he is coping in what the player put him in: `cold`, `hot`, or `ok`.
  /// `weather_engine.dart`'s `comfortFor` decides, off the temperature and
  /// [garmentWarmth].
  ///
  /// **`ok` by default, and that is what keeps this off the customiser.** The
  /// chip previews the look you are choosing, not the weather you would be
  /// choosing it for — the JS confines these to the scene by selector, the port
  /// by simply not passing anything.
  final String comfort;

  /// A touchline gesture to play once, over the walk. Its identity is what
  /// starts it, so handing the SAME gesture again is a no-op — the caller plays
  /// a new one by handing a new instance.
  ///
  /// `manager_mood.dart` decides WHICH and how often; `gesture_poses.dart` knows
  /// what each one looks like. Both were ported with nothing calling them.
  final GestureCue? gesture;

  /// Where his joints sit when nothing else is driving them — a base pose, and
  /// a PLAYING GESTURE OUTRUNS IT JOINT BY JOINT.
  ///
  /// That is the stylesheet's own arrangement rather than a convenience: the
  /// idle loops are written with `:where()` so they weigh nothing, and every
  /// `.is-gest-*` rule beats them on the limb it drives while the others carry
  /// on. A fist pump is one arm, and the far one should still be drifting.
  ///
  /// Who decides WHAT an idle looks like is deliberately not this widget:
  /// standing on a touchline in front of a camera and standing in a shop window
  /// are different idles, and the one that exists is the cam's — see
  /// `dugout_cam.dart`. Handing a pose in keeps that where the tempo, the
  /// amplitudes and the four periods already live.
  final GesturePose? idle;

  /// He has picked the stray ball up and is carrying it — `pitch_ball.dart`
  /// says when, because the sim owns the ball and this owns the man.
  ///
  /// The JS's `.ps-walker.is-carrying`: both arms to -20 and both forearms to
  /// -110, cradled in front of the chest, eased in over a quarter of a second.
  /// It BEATS a gesture, and the screen stops offering one while it is true —
  /// his arms are visibly full.
  final bool carrying;

  /// **The stray ball, drawn INSIDE him rather than over him.**
  ///
  /// It has to be here and not a sibling because of what goes on top of it: the
  /// near arm again, so that a carried ball is CLOSED ROUND rather than balanced
  /// on. The JS has the same problem from the other direction — `.ps-ball` is a
  /// DOM sibling with a z-index, and nothing inside an SVG can be stacked
  /// against one, so it builds a whole second `.ps-hold-arm` copy to get above
  /// it. Flutter has no z-index and paint order is the answer, but the JS's own
  /// warning still applies: **the copy must share the figure's clock**, or the
  /// real arm swings and the copy sits still and the duplicate surfaces on every
  /// stride. Sharing it is the whole reason the ball is passed in here rather
  /// than stacked outside.
  final Widget? ballLayer;

  @override
  State<ManagerWalker> createState() => _ManagerWalkerState();
}

class _ManagerWalkerState extends State<ManagerWalker>
    with TickerProviderStateMixin {
  /// His own stride clock, for when there is no diorama around him.
  ///
  /// **The scene's [WalkBeat] wins whenever there is one.** His legs and the
  /// ground he is walking on have to be warped by the same curve at the same
  /// instant the moment a gesture eases the world to a stop — see
  /// `walk_ramp.dart` — and two clocks kept together by both starting in the
  /// same frame only ever worked because a stop restarted both from zero. This
  /// one runs in the customiser's chip and in tests, where nothing on the grass
  /// is watching.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: walkDurationFor(widget.mood),
  );

  /// The scene's beat, in half-strides. Null off the diorama.
  ValueNotifier<double>? _beat;

  /// Where he is in his stride, 0 to 1.
  ///
  /// The beat counts half-strides because that is the unit the GROUND is solved
  /// in; the figure's cycle is two of them.
  double get _phase {
    final beat = _beat;
    if (beat == null) return _clock.value;
    final t = (beat.value / 2) % 1;
    return t < 0 ? t + 1 : t;
  }

  /// Whether his OWN clock should be running. Always false while the scene is
  /// driving him.
  ///
  /// Honours the platform's reduce-motion setting: he is decoration on the
  /// screen the app OPENS on, which is exactly the kind of perpetual movement
  /// that setting exists to stop. It is also what lets a widget test settle —
  /// a looping animation never does.
  bool _shouldWalk(BuildContext context) =>
      _beat == null &&
      widget.walking &&
      !widget.standing &&
      !_planted &&
      !MediaQuery.of(context).disableAnimations;

  void _sync(BuildContext context) {
    // His TEMPO is his mood. The stride restarts from the top rather than
    // carrying its phase across: `repeat` cannot resume mid-cycle, and a mood
    // only changes at full time, where the scene is not what anybody is looking
    // at. (On the diorama the beat carries it properly — a retime there changes
    // what a second is worth without moving the strides already taken.)
    final want = walkDurationFor(widget.mood);
    if (_clock.duration != want) {
      final running = _clock.isAnimating;
      _clock.stop();
      _clock.duration = want;
      if (running) _clock.repeat();
    }
    if (_shouldWalk(context)) {
      if (!_clock.isAnimating) _clock.repeat();
    } else if (_clock.isAnimating) {
      _clock.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _beat = WalkBeat.maybeOf(context);
    // A cue supplied at MOUNT plays as well. It only started from
    // `didUpdateWidget` before, so the first gesture of a session was silently
    // dropped — invisible in the app, where the rota always arrives after the
    // first frame, and it made the pose impossible to render in a test.
    _startGesture();
    _sync(context);
    _syncBlink();
    _syncCarry();
  }

  @override
  void didUpdateWidget(ManagerWalker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startGesture();
    _sync(context);
    _syncBlink();
    _syncCarry();
  }

  /// **THE BLINK.** He never did, and a face that never blinks is a mask.
  ///
  /// Its own clock, and a long one: a blink is about a fifth of a second inside
  /// five, so hanging it off the stride would have him blinking faster when he was
  /// cheerful. Two per cycle at an uneven spacing, because a metronome blink is its
  /// own kind of dead.
  late final AnimationController _blinkClock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5000),
  );

  /// How shut his eye is, 0 to 1.
  double get _blink {
    final v = _blinkClock.value;
    for (final w in const [(0.62, 0.075), (0.79, 0.05)]) {
      if (v < w.$1 || v > w.$1 + w.$2) continue;
      // Down and up again across the window — a lid closing, not a shutter.
      return 1 - (((v - w.$1) / w.$2) * 2 - 1).abs();
    }
    return 0;
  }

  /// Whether he is animating AT ALL, whatever the world's speed is doing.
  ///
  /// Distinct from [_shouldWalk], which is only about his OWN stride clock. A
  /// man who has planted his feet to bow is still a man: he blinks, and he still
  /// shivers if the player dressed him for the wrong weather.
  bool _animating(BuildContext context) =>
      (widget.walking || widget.standing) &&
      !MediaQuery.of(context).disableAnimations;

  void _syncBlink() {
    // Stops with everything else: it is a repeating animation like any other.
    //
    // Not gated on the WALK, though — his own five-second clock has nothing to
    // do with the world's speed. Only reduced motion and a scene nobody is
    // watching stop it.
    final run = _animating(context);
    if (run == _blinkClock.isAnimating) return;
    if (run) {
      _blinkClock.repeat();
    } else {
      _blinkClock.stop();
      _blinkClock.value = 0;
    }
  }

  /// The carry, eased in and out over the CSS's own `transition: transform
  /// 0.25s`. Without the ease his arms snap to the cradle the instant the ball
  /// touches his hands, which reads as a dropped frame rather than as a man
  /// picking something up.
  late final AnimationController _carryClock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  void _syncCarry() {
    if (widget.carrying) {
      if (_carryClock.status != AnimationStatus.forward &&
          _carryClock.value != 1) {
        _carryClock.forward();
      }
    } else if (_carryClock.status != AnimationStatus.reverse &&
        _carryClock.value != 0) {
      _carryClock.reverse();
    }
  }

  /// The rig with a ball in its hands, blended over whatever it was doing.
  ///
  /// Blended from the WALK rather than from the gesture's own angles, which is
  /// correct because the two never overlap: taking hold of the ball cancels the
  /// running gesture and blocks the next one, exactly as the JS does.
  GesturePose? _carryOver(GesturePose? pose, double t) {
    final k = _carryClock.value;
    if (k == 0) return pose;
    double to(double target, _Track track) =>
        _sample(track, t) + (target - _sample(track, t)) * k;
    return (
      armNear: to(carryArm, _armNear),
      armFar: to(carryArm, _armFar),
      foreNear: to(carryFore, _elbowNear),
      foreFar: to(carryFore, _elbowFar),
      head: pose?.head,
      body: pose?.body,
      bodyLift: pose?.bodyLift,
      legs: pose?.legs,
      finger: 0,
    );
  }

  /// One gesture, played once. Its duration is the gesture's own, so this is
  /// retimed rather than scaled every time a new one starts.
  late final AnimationController _gestureClock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1),
  );

  /// Which gesture the clock is running, and the cue that started it.
  Gesture? _playing;
  GestureCue? _cue;

  /// Where the gesture is, or null when none is playing.
  ///
  /// **A FINISHED gesture is no gesture, and getting that wrong froze his arms.**
  /// The clock only ever runs forward, so when it stops it stops at 1.0 — and the
  /// first cut only treated 0.0 as "nothing playing". So from the first gesture
  /// onward the pose was still being read, at progress 1.0, which is every
  /// track's REST value: the arms locked at 27 and -52 and never swung again.
  /// `isAnimating` is the whole question.
  GesturePose? get _pose {
    final g = _playing;
    final playing = g != null && _gestureClock.isAnimating
        ? gesturePose(g.id, _gestureClock.value, gestureMs: g.ms)
        : null;
    return _overIdle(playing);
  }

  GesturePose? _overIdle(GesturePose? playing) =>
      poseOverIdle(playing, _idleForNow);

  /// The idle, minus anything the STRIDE is already driving.
  ///
  /// **AN IDLE MUST NOT OWN AN ARM ON A MAN WHO IS WALKING**, and it did: the
  /// pose pins `armNear`/`armFar`, `_arm` reads `posed ?? _sample(track, t)`,
  /// and a pinned angle replaces the swing outright. So the moment the dugout
  /// cam's idle reached the diorama, his arms stopped moving and stayed
  /// stopped — reported as "the manager arm keeps getting stuck".
  ///
  /// The idle was written for a PLANTED man, where there is no stride to
  /// disagree with; on a walk it keeps the joints the walk does not drive — the
  /// head, the body, the lean — and gives the arms back. A gesture still
  /// outruns both, joint by joint, which is the arrangement the idle exists for.
  GesturePose? get _idleForNow {
    final idle = widget.idle;
    if (idle == null) return null;
    final walking = !widget.standing && widget.walking && !_planted;
    if (!walking) return idle;
    return (
      armNear: null,
      armFar: null,
      foreNear: null,
      foreFar: null,
      head: idle.head,
      body: idle.body,
      bodyLift: idle.bodyLift,
      legs: null,
      finger: idle.finger,
    );
  }

  /// The head angle the playing GESTURE is asking for, or null when the idle
  /// still owns the joint. [_pose] has already composed the two by then.
  double? get _playingHead {
    final g = _playing;
    if (g == null || !_gestureClock.isAnimating) return null;
    return gesturePose(g.id, _gestureClock.value, gestureMs: g.ms).head;
  }

  /// He plants his feet for some of them, and the world has to stop with him:
  /// he walks in place while the scene scrolls past, so a stride that stops
  /// without the scroll stopping is a man standing still on a conveyor belt.
  bool get _planted => (_playing?.stops ?? false) && _gestureClock.isAnimating;

  void _startGesture() {
    final cue = widget.gesture;
    if (cue == null || cue == _cue) return;
    _cue = cue;
    _playing = cue.gesture;
    _gestureClock.duration = Duration(milliseconds: cue.gesture.ms);
    _gestureClock.forward(from: 0);
  }

  /// Where he is carrying his head, mood and gesture together.
  ///
  /// **A LIFT ONLY EVER BRINGS HIM UP TO LEVEL.** The two compose differently
  /// depending on which way the gesture looks, and adding them blindly was wrong:
  /// a manager already looking straight ahead — or up, when it is going well —
  /// would raise his chin FURTHER to point at something and end up addressing the
  /// sky.
  ///
  /// So a gesture that looks DOWN (checking a watch, hands on head, a bow) adds to
  /// however he was carrying it, because a beaten manager checking his watch looks
  /// further down than a cheerful one and that is right. A gesture that lifts him
  /// is capped at level: it can pull a dropped head up to the horizontal and no
  /// higher, and it does nothing at all to a head that was not down.
  double _headAngle(GesturePose? pose) {
    final base = moodHeadTilt(widget.mood);
    final gesture = pose?.head ?? 0;
    if (gesture >= 0) return base + gesture;
    return math.max(base + gesture, math.min(base, 0));
  }

  /// The tremble, in art units.
  ///
  /// **Tiny and fast — a tremble, not a wobble**, so it reads at a glance
  /// without turning the walk cycle into a bounce. 130ms, off the walk clock's
  /// ELAPSED SECONDS rather than its 0→1: the stride runs 1.45s to 2.3s with his
  /// mood, and a phase taken from the fraction would have him shivering faster
  /// when he was pleased.
  ///
  /// The stride is not a whole number of shivers, so the phase steps at the wrap.
  /// At 130ms and a third of an art unit that is not a thing anybody can see, and
  /// the alternative is a second ticker for it.
  ///
  /// **Off entirely when he is not walking**, which covers both a frozen scene
  /// and reduced motion. The JS leaves `.psv-tremble` out of its reduced-motion
  /// block, so it keeps trembling there; a 130ms strobe is exactly what that
  /// setting exists to stop, and the omission reads as one rather than a
  /// decision. (Its PAUSED block does list it, which is the same conclusion
  /// reached about a scene nobody is watching.)
  Offset _shiver(BuildContext context, double t) {
    if (widget.comfort != 'cold' || !_animating(context)) return Offset.zero;
    final phase =
        (t * walkDurationFor(widget.mood).inMicroseconds / 130000) % 1;
    // translate(0.35, 0) → (-0.35, 0.2) → (0.35, 0)
    return phase < 0.5
        ? Offset(0.35 - phase * 1.4, phase * 0.4)
        : Offset(-0.35 + (phase - 0.5) * 1.4, (1 - phase) * 0.4);
  }

  @override
  void dispose() {
    _clock.dispose();
    _gestureClock.dispose();
    _blinkClock.dispose();
    _carryClock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = widget.look ?? defaultManagerLook;
    final parts = managerPartsFor(
      look,
      kit: widget.kit,
      skin: widget.skin,
      hair: widget.hair,
      mood: widget.mood,
    );

    return AspectRatio(
      aspectRatio: walkerWidth / walkerHeight,
      // **THE SIZE HE IS ACTUALLY DRAWN AT.**
      //
      // Everything inside the painter is in art units and the painter scales
      // them; everything OUTSIDE it — the sink, the bob, the sway, the shiver,
      // a gesture's body lift — was written in art units too and applied as
      // logical pixels. So the figure's vertical offsets stayed put while the
      // shadow, which is laid out in fractions, grew and shrank with the box:
      // at any size but the one they were tuned at, he floated over it. That is
      // the "floats above its shadow AGAIN" — it comes back on every device
      // with a different diorama height.
      child: LayoutBuilder(
        builder: (context, box) {
          // One art unit, in pixels. `AspectRatio` fixes the ratio, so height
          // alone is enough and the width follows.
          final unit = box.maxHeight / walkerHeight;
          return _buildFigure(context, parts, look, unit);
        },
      ),
    );
  }

  Widget _buildFigure(
    BuildContext context,
    ManagerParts parts,
    Map<String, dynamic> look,
    double unit,
  ) {
    return AnimatedBuilder(
      // EVERY clock he is on: the walk (the scene's, or his own off it), the
      // gesture, and the blink. The figure is whatever they say together.
      animation: Listenable.merge([
        _beat ?? _clock,
        _gestureClock,
        _blinkClock,
        _carryClock,
      ]),
      builder: (context, _) {
        // **STANDING IS NOT A FRAME OF THE WALK**, so the stride's own
        // quantities go to nothing rather than to a value of [t]: the bob, the
        // sway and the span the shadow is drawn across are all the walk, and
        // the legs below hold their rest angles. See [ManagerWalker.standing].
        final standing = widget.standing;
        final t = _phase;
        final pose = _carryOver(_pose, t);
        // Whether this gesture's hand belongs in FRONT of the face — see
        // [gestureHandsOverHead]. Only while it is actually playing: at rest
        // his arms are by his sides and a second pass would be two of them.
        final handsOverHead =
            pose != null &&
            gestureHandsOverHead.contains(_playing?.id);
        // **ONE angle for every head layer.** Hair, skull and hat are three
        // widgets and one head; give them separate numbers and the face slides
        // out from under its own hat.
        // **A GESTURE goes through the lift clamp; the IDLE's scan does not.**
        // That rule is about a gesture not raising a head that is already up —
        // a manager pointing at something should not end up addressing the sky
        // — and a one-degree scan is not a lift. Composed here rather than in
        // [_overIdle] because the two want different arithmetic on the same
        // field.
        final scanning = _pose == null || _playingHead == null;
        final headTilt = scanning
            ? _headAngle(null) + (widget.idle?.head ?? 0)
            : _headAngle(pose);
        // The hips, and the same number the leg solver uses — see
        // [walkerHipRise]. It is not decoration: the bob is what lets the foot
        // reach the ends of the step, so the figure's rise and its stride are
        // one calculation and cannot drift apart.
        final rise = standing ? 0.0 : walkerHipRise(t);
        final span = standing ? _standSpan : _footSpan(t);

        return Stack(
          fit: StackFit.expand,
          children: [
            // The shadow does NOT bob: it is on the ground, and it tightens as
            // he leaves it, which is the whole of the depth in the figure.
            //
            // It also SPANS THE FEET rather than sitting at a fixed width —
            // see [_shadowPad]. The near foot's track is one leg's; the far
            // one is half a cycle behind it, and the two together are the
            // stride's full extent at this instant.
            Align(
              // At his FEET, not at the bottom of his box. Derived from the
              // two fractions rather than typed, so it cannot go stale if
              // either moves: for a child of height fH inside a box of height
              // H, `Align` puts its centre at H/2 + a(H - fH)/2, and we want
              // that centre on the footline.
              alignment: Alignment(
                // Off-centre with the feet, so a trailing leg pulls the shadow
                // back with it — but HALF the offset, and biased left.
                //
                // At the full offset it slid about as far as the boots do and
                // read as a separate object being dragged along; half of it
                // reads as the shadow of a body whose weight is moving. The
                // bias is because the figure is drawn side-on facing right, so
                // its mass sits left of the box's centre while the leading boot
                // reaches right of it — centring on the feet alone put the
                // shadow ahead of him.
                (span.centre * 0.5 - _shadowBias) / (walkerWidth / 2),
                _shadowAlignment.y,
              ),
              child: FractionallySizedBox(
                widthFactor:
                    (span.width + _shadowPad * 2) / walkerWidth -
                    rise / walkerHeight,
                heightFactor: _shadowBand,
                child: const _GroundShadow(),
              ),
            ),
            // The body's own fold, about the HIP rather than the boots — a bow
            // bends at the waist, and turning about his feet would topple him.
            // Wrapped OUTSIDE the walk's offsets so the fold composes with the
            // stride instead of replacing it.
            _Fold(
              degrees: pose?.body,
              child: Transform.translate(
                // Art units × [unit]. See the note on the `LayoutBuilder`:
                // these are the offsets that were pixels while the shadow was
                // fractions, which is what put him above it.
                offset:
                    (Offset(
                          standing ? 0 : math.sin(t * 2 * math.pi) * _sway,
                          _sink - rise + (pose?.bodyLift ?? 0),
                        ) +
                        _shiver(context, t)) *
                    unit,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // The rig: everything that turns.
                    CustomPaint(
                      key: const ValueKey('manager-walker'),
                      painter: _WalkerPainter(
                        t: t,
                        kit: widget.kit,
                        skin: parts.skin,
                        // **His SHAPE.** The build axis was in the customiser,
                        // the wardrobe, the randomiser and the save, and six
                        // choices produced one figure — nothing read it.
                        build: buildScales(look['build'] as String?),
                        outfit: outfitPalette(look['outfit'] as String?),
                        sleevesAreKit: outfitSleevesAreKit(
                          look['outfit'] as String?,
                        ),
                        standing: standing,
                        // A hand that belongs in front of the face is drawn in
                        // a second pass, after the head — see [WalkerArms].
                        arms: handsOverHead
                            ? WalkerArms.skipNear
                            : WalkerArms.both,
                        pose: pose,
                      ),
                    ),
                    // Then the look, in the JS's own layering: what goes over the
                    // torso, then the head's own furniture. Hair is TWO layers
                    // with the skull between them, which is what stops a mohawk's
                    // fin coming out of the face.
                    for (final svg in parts.overTorso) SvgArt(svg: svg),
                    // The head and everything it wears, as ONE group — see
                    // [_headSetBack]. `FractionalTranslation` shifts by a
                    // fraction of the CHILD's size, and each child fills the
                    // walker's box, so an art-unit offset is that offset over
                    // [walkerWidth] at any scale.
                    // **The head is a SIBLING of the arms, not a parent**, so a
                    // tilt is its own transform — and it has to take the hair,
                    // the beard, the glasses and the hat with it, for the same
                    // reason [_headSetBack] does: the art is all drawn against a
                    // skull at 62, so turning the painted head alone slides the
                    // face out from under its own hat.
                    for (final layer in parts.behindHead)
                      _Tilt(
                        degrees: headTilt,
                        child: _SetBack(child: _HeadArt(layer: layer)),
                      ),
                    _Tilt(
                      degrees: headTilt,
                      child: _SetBack(
                        child: CustomPaint(
                          painter: _HeadPainter(
                            skin: parts.skin,
                            blink: _blink,
                          ),
                        ),
                      ),
                    ),
                    // Paint, before the fringe goes over it — see
                    // [ManagerParts.onSkin].
                    for (final layer in parts.onSkin)
                      _Tilt(
                        degrees: headTilt,
                        child: _SetBack(child: _HeadArt(layer: layer)),
                      ),
                    for (final layer in parts.overHair)
                      _Tilt(
                        degrees: headTilt,
                        child: _SetBack(child: _HeadArt(layer: layer)),
                      ),
                    // Then the eye, over the paint and the fringe both — the
                    // other half of the same JS note: paint belongs under the
                    // hair AND under the eye, or war paint blinds him. Before
                    // the glasses and the hat, which have to cover it.
                    _Tilt(
                      degrees: headTilt,
                      child: _SetBack(
                        child: CustomPaint(
                          painter: _HeadPainter(
                            skin: parts.skin,
                            blink: _blink,
                            features: true,
                          ),
                        ),
                      ),
                    ),
                    for (final layer in parts.overHead)
                      _Tilt(
                        degrees: headTilt,
                        child: _SetBack(child: _HeadArt(layer: layer)),
                      ),
                    // **AND THE NEAR ARM, if the hand belongs in front of the
                    // face.** Everything above is the head and what it wears,
                    // and the rig is under all of it — so this is the only
                    // place a hand can be over a face. See [WalkerArms].
                    if (handsOverHead)
                      CustomPaint(
                        key: const ValueKey('manager-walker-hands'),
                        painter: _WalkerPainter(
                          t: t,
                          kit: widget.kit,
                          skin: parts.skin,
                          build: buildScales(look['build'] as String?),
                          outfit: outfitPalette(look['outfit'] as String?),
                          sleevesAreKit: outfitSleevesAreKit(
                            look['outfit'] as String?,
                          ),
                          standing: standing,
                          pose: pose,
                          arms: WalkerArms.nearOnly,
                        ),
                      ),
                    // How he is coping, over the head AND over the hat — the
                    // pallor and the flush belong on the face, and a beanie must
                    // not be able to cover his breath.
                    _SetBack(child: _Comfort(comfort: widget.comfort)),
                    // **THE BALL, OVER ALL OF HIM** — which is where the JS puts
                    // it too, and right: at his boot it belongs in front of the
                    // near leg, and in his hands the cradle is in front of his
                    // chest.
                    ?widget.ballLayer,
                    // **AND THE NEAR ARM ONE MORE TIME, over the ball, while he
                    // is carrying it.** This is the JS's `.ps-hold-arm`, and its
                    // own comment says exactly what its absence looks like: the
                    // arm that should close round a carried ball was always
                    // behind it and *he looked like he was balancing it*. Which
                    // is how it was reported here.
                    //
                    // Drawn from the same painter, on the same clock, with the
                    // same pose — so there is no window in which the copy and
                    // the real arm are in different places, and nothing to
                    // crossfade. The JS needs a whole second SVG for this; here
                    // it is one more pass.
                    if (widget.carrying)
                      CustomPaint(
                        key: const ValueKey('manager-walker-carry-arm'),
                        painter: _WalkerPainter(
                          t: t,
                          kit: widget.kit,
                          skin: parts.skin,
                          build: buildScales(look['build'] as String?),
                          outfit: outfitPalette(look['outfit'] as String?),
                          sleevesAreKit: outfitSleevesAreKit(
                            look['outfit'] as String?,
                          ),
                          standing: standing,
                          pose: pose,
                          arms: WalkerArms.nearOnly,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// How he is coping with the weather in what the player put him in.
///
/// **Nothing here changes his clothes.** The player picks them and the game only
/// shows how he is getting on: shivering in shorts in February, sweating in a
/// coat and scarf in August. `weather_engine.dart` decides which, off the
/// temperature and [garmentWarmth], and the whole of that chain was ported and
/// tested with nothing reading the answer.
///
/// **Its own clock, and only while it is needed.** Two reasons it cannot ride the
/// walk clock the way the tremble does: a breath is 2.6s against a stride of
/// 1.45–2.3s, so a phase taken off the stride would cut every puff off in the
/// middle of itself — and `ok` is the common case, where this should cost nothing
/// at all.
class _Comfort extends StatefulWidget {
  const _Comfort({required this.comfort});

  final String comfort;

  @override
  State<_Comfort> createState() => _ComfortState();
}

class _ComfortState extends State<_Comfort>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _seconds = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    (elapsed) => _seconds.value = elapsed.inMicroseconds / 1e6,
  );

  bool get _showing => widget.comfort != 'ok';

  void _sync() {
    final run = _showing && !MediaQuery.of(context).disableAnimations;
    if (run == _ticker.isActive) return;
    if (run) {
      _ticker.start();
    } else {
      _ticker.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Comfort old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedOpacity(
      opacity: _showing ? 1 : 0,
      duration: const Duration(milliseconds: 1200),
      child: ValueListenableBuilder<double>(
        valueListenable: _seconds,
        builder: (context, t, _) => CustomPaint(
          size: Size.infinite,
          painter: _ComfortPainter(comfort: widget.comfort, seconds: t),
        ),
      ),
    ),
  );
}

/// One keyframe of a puff or a bead: where it is, how big, and how visible.
typedef _Puff = ({double dx, double dy, double scale, double opacity});

/// Breath on the air. One every 2.6s, which is about right for somebody standing
/// still and cold.
const List<(double, _Puff)> _breathFrames = [
  (0, (dx: 0, dy: 0, scale: 0.4, opacity: 0)),
  (0.18, (dx: 2, dy: -0.6, scale: 0.9, opacity: 0.85)),
  (0.55, (dx: 6, dy: -2, scale: 1.5, opacity: 0.4)),
  (0.80, (dx: 9, dy: -3.4, scale: 2, opacity: 0)),
  (1, (dx: 9, dy: -3.4, scale: 2, opacity: 0)),
];

/// Sweat running off. Falls, fades, repeats.
const List<(double, _Puff)> _sweatFrames = [
  (0, (dx: 0, dy: 0, scale: 0.6, opacity: 0)),
  (0.15, (dx: 0, dy: 1, scale: 1, opacity: 0.9)),
  (0.70, (dx: 0.6, dy: 11, scale: 1, opacity: 0.75)),
  (0.90, (dx: 0.8, dy: 15, scale: 0.7, opacity: 0)),
  (1, (dx: 0.8, dy: 15, scale: 0.7, opacity: 0)),
];

/// The keyframe track at [phase], eased the way CSS eases it — per SEGMENT, not
/// across the whole run.
_Puff _puffAt(List<(double, _Puff)> track, double phase, Curve curve) {
  for (var i = 0; i < track.length - 1; i++) {
    final (from, a) = track[i];
    final (to, b) = track[i + 1];
    if (phase > to) continue;
    final span = to - from;
    final f = curve.transform(span <= 0 ? 0 : (phase - from) / span);
    double at(double x, double y) => x + (y - x) * f;
    return (
      dx: at(a.dx, b.dx),
      dy: at(a.dy, b.dy),
      scale: at(a.scale, b.scale),
      opacity: at(a.opacity, b.opacity),
    );
  }
  return track.last.$2;
}

class _ComfortPainter extends CustomPainter {
  const _ComfortPainter({required this.comfort, required this.seconds});

  final String comfort;
  final double seconds;

  /// Cold pallor over the whole head — the skull's own circle, from the art's
  /// space.
  static const Offset _skull = Offset(62, 48.5);

  /// A puff, or a bead: drawn in its own place, moved and scaled about the point
  /// the CSS names as its transform origin.
  ///
  /// `translate(t) scale(s)` about an origin `o` puts a point `p` at
  /// `o + t + s·(p - o)`, which is three canvas ops in that order and NOT the
  /// order they are written in.
  void _drop(
    Canvas canvas,
    Offset origin,
    _Puff frame,
    void Function(Paint paint) draw,
    Color color,
  ) {
    if (frame.opacity <= 0.004) return;
    canvas.save();
    canvas.translate(origin.dx + frame.dx, origin.dy + frame.dy);
    canvas.scale(frame.scale);
    canvas.translate(-origin.dx, -origin.dy);
    draw(
      Paint()
        ..color = Color.fromRGBO(
          (color.r * 255).round(),
          (color.g * 255).round(),
          (color.b * 255).round(),
          frame.opacity,
        ),
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / walkerWidth, size.height / walkerHeight);

    if (comfort == 'cold') {
      // **The puffs are what actually read at this size** — a tint alone just
      // looks like a lighting change.
      canvas.drawCircle(_skull, 12.5, Paint()..color = const Color(0x4D8AB9E8));
      // Two on the same path, offset so they overlap into a rhythm rather than
      // pulsing in lockstep.
      for (final puff in const [(0.0, 3.0, 2.1), (0.42, 2.4, 1.7)]) {
        final box = Rect.fromCenter(
          center: const Offset(78, 51.5),
          width: puff.$2 * 2,
          height: puff.$3 * 2,
        );
        _drop(
          canvas,
          // `transform-box: fill-box; transform-origin: 0% 50%` — the left edge
          // of the ellipse, so a puff grows AWAY from his mouth.
          box.centerLeft,
          _puffAt(
            _breathFrames,
            ((seconds + puff.$1) / 2.6) % 1,
            Curves.easeOut,
          ),
          (paint) => canvas.drawOval(box, paint),
          const Color(0xFFEEF6FF),
        );
      }
    }

    if (comfort == 'hot') {
      // Flushed cheek and brow.
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(66.5, 52),
          width: 9.2,
          height: 5.6,
        ),
        Paint()..color = const Color(0x6BE0553F),
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(60, 43.5), width: 10, height: 4.4),
        Paint()..color = const Color(0x38E0553F),
      );
      // Then sweat off the temple, staggered so the two beads do not drop in
      // step.
      for (final bead in const [
        (0.0, Offset(72.6, 41), 1.5),
        (0.95, Offset(51.5, 45), 1.3),
      ]) {
        final centre = bead.$2;
        final r = bead.$3;
        _drop(
          canvas,
          // `transform-origin: 50% 0%` — the top of the bead, so it stretches
          // downward as it runs.
          centre.translate(0, -r),
          _puffAt(_sweatFrames, ((seconds + bead.$1) / 1.9) % 1, Curves.easeIn),
          (paint) => canvas.drawCircle(centre, r, paint),
          const Color(0xFFCFE9FF),
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ComfortPainter old) =>
      old.comfort != comfort || old.seconds != seconds;
}

/// A gesture laid OVER an idle, joint by joint — `??` per field.
///
/// **That is the stylesheet's specificity, written out.** The idle loops are
/// declared with `:where()` so they weigh nothing, and every `.is-gest-*` rule
/// beats them on the limb it names while the others carry on: a fist pump is
/// one arm, and the far one should still be drifting. Replacing the whole pose
/// would stop the other three joints dead for the length of every gesture.
///
/// [playing] wins field by field where it has an opinion — null means the
/// gesture is not this joint's business, which is what every track that does
/// not exist already means everywhere else in `gesture_poses.dart`. The FINGER
/// is the gesture's alone: it is an appearance rather than a joint, and an idle
/// has no reason to put one out.
///
/// Returns [playing] unchanged when there is no idle, which is every caller but
/// the dugout cam.
GesturePose? poseOverIdle(GesturePose? playing, GesturePose? idle) {
  if (idle == null) return playing;
  if (playing == null) return idle;
  return (
    armNear: playing.armNear ?? idle.armNear,
    armFar: playing.armFar ?? idle.armFar,
    foreNear: playing.foreNear ?? idle.foreNear,
    foreFar: playing.foreFar ?? idle.foreFar,
    head: playing.head ?? idle.head,
    body: playing.body ?? idle.body,
    bodyLift: playing.bodyLift ?? idle.bodyLift,
    legs: playing.legs ?? idle.legs,
    finger: playing.finger,
  );
}

/// A head tilt, about the base of the neck.
///
/// Positive drops the chin toward his chest, because he faces +x. Null is no
/// transform at all rather than a zero one: the head is on screen at every
/// frame and a `Transform` per layer per frame for nothing is three widgets the
/// tree does not need.
class _Tilt extends StatelessWidget {
  const _Tilt({required this.degrees, required this.child});

  final double? degrees;
  final Widget child;

  /// The base of the neck, in the art's own space.
  static const Offset _neck = Offset(58, 62);

  @override
  Widget build(BuildContext context) {
    final d = degrees;
    if (d == null || d == 0) return child;
    return Transform.rotate(
      angle: d * math.pi / 180,
      alignment: Alignment(
        _neck.dx / walkerWidth * 2 - 1,
        _neck.dy / walkerHeight * 2 - 1,
      ),
      child: child,
    );
  }
}

/// The whole figure folding, about the HIP.
///
/// Not the boots: a bow bends at the waist, and turning the figure about its feet
/// would lean the whole man over like a felled tree.
class _Fold extends StatelessWidget {
  const _Fold({required this.degrees, required this.child});

  final double? degrees;
  final Widget child;

  static const Offset _hip = Offset(58, 95);

  @override
  Widget build(BuildContext context) {
    final d = degrees;
    if (d == null || d == 0) return child;
    return Transform.rotate(
      angle: d * math.pi / 180,
      alignment: Alignment(
        _hip.dx / walkerWidth * 2 - 1,
        _hip.dy / walkerHeight * 2 - 1,
      ),
      child: child,
    );
  }
}

/// One layer of the head, moved back over the body. See [_headSetBack].
class _SetBack extends StatelessWidget {
  const _SetBack({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => FractionalTranslation(
    translation: const Offset(
      -_headSetBack / walkerWidth,
      -_headLift / walkerHeight,
    ),
    child: child,
  );
}

/// The parts one look draws, already recoloured and in layer order.
typedef ManagerParts = ({
  Color skin,
  List<String> overTorso,
  List<HeadLayer> behindHead,

  /// **On the skin, and under the fringe.** War paint, eye black and a
  /// half-and-half face are the JS's `.psv-facepaint`, drawn between the skull
  /// and the front hair — see [facesUnderHair]. The port had one face slot over
  /// the lot, so a green half-face was painted onto the hair as well.
  List<HeadLayer> onSkin,

  /// The fringe, over the paint and under the eye — the JS's `.psv-hair-front`
  /// sits at exactly that depth, which is why it is its own slot here.
  List<HeadLayer> overHair,
  List<HeadLayer> overHead,
});

/// Resolve a look into drawable, recoloured fragments.
///
/// Pure, and public, because the layering is the part worth pinning in a test:
/// hair behind the skull, the skull, PAINT ON THE SKIN, hair in front of it,
/// then beard, glasses and hat over the lot.
ManagerParts managerPartsFor(
  ManagerLook look, {
  required Color kit,
  required Color skin,
  required Color hair,
  Mood mood = Mood.neutral,
}) {
  final hairColour = '${look['hair'] ?? ''}'.isEmpty
      ? hexOf(hair.toARGB32())
      : '${look['hair']}';
  final skinColour = '${look['skin'] ?? ''}'.isEmpty
      ? hexOf(skin.toARGB32())
      : '${look['skin']}';
  final shade = '${look['skinShade'] ?? ''}'.isEmpty
      ? null
      : '${look['skinShade']}';

  String paint(String svg) => recolourManagerArt(
    svg,
    hair: hairColour,
    skin: skinColour,
    skinShade: shade,
    kit: hexOf(kit.toARGB32()),
    kitDark: hexOf(Color.lerp(kit, Colors.black, 0.32)!.toARGB32()),
    kitLight: hexOf(Color.lerp(kit, Colors.white, 0.22)!.toARGB32()),
  );

  List<String> present(Iterable<String?> raw) => [
    for (final svg in raw)
      if (svg != null && svg.trim().isNotEmpty) paint(svg),
  ];

  List<HeadLayer> layers(
    Iterable<String?> raw, {
    double? hideAbove,
    bool clipToSkull = false,
  }) => [
    for (final svg in present(raw))
      (svg: svg, hideAbove: hideAbove, clipToSkull: clipToSkull),
  ];

  // **A HAT HIDES THE HAIR GOING THROUGH IT.** The hat is drawn over the hair,
  // so whatever its own shape covers is already hidden — what came through was
  // hair ABOVE it, a mohawk's fin standing clear of a cap. Both hair layers are
  // clipped, because a fin has a back half too. Null for a headband or a pair of
  // headphones, which cover nothing above themselves — see [hatCrownY].
  final crown = hairHiddenAboveY('${look['hat']}');
  // A hat with a brow line is one with a solid crown, which is the same set the
  // JS keeps in `HAIR_COVERED_BY`.
  final crownHat = crown != null;

  final style = '${look['style']}';
  final (hairBack, hairFrontRaw) =
      managerHair[style] ?? managerHair['crop']!;
  // **A BUN IS ON TOP OF THE HEAD, not behind it.** Every other back piece — a
  // ponytail, dreads, braids, a mullet's curtain — emerges from under the brim,
  // which is what hair does under a hat and should stay. The bun sits inside a
  // beanie's dome, so it goes with the front. The JS's `BACK_HAIR_AT_CROWN`.
  final hairBackDrawn = hairAtCrown.contains(style) && crownHat ? null : hairBack;
  final hairFront = hairFrontRaw;

  return (
    skin: _colourOf(skinColour) ?? skin,
    overTorso: present([
      managerOutfits['${look['outfit']}'],
      managerNeck['${look['neck']}'],
    ]),
    behindHead: layers([hairBackDrawn], hideAbove: crown),
    onSkin: layers([
      if (faceIsUnderHair('${look['face']}')) managerFaces['${look['face']}'],
    ]),
    overHair: layers([hairFront], hideAbove: crown, clipToSkull: crownHat),
    overHead: [
      ...layers([
        managerBeards['${look['beard']}'],
        if (!faceIsUnderHair('${look['face']}'))
          managerFaces['${look['face']}'],
        managerHats['${look['hat']}'],
        // The mouth is the manager's MOOD, and `manager_mood.dart` was ported
        // with nothing to draw it: how the gaffer feels about the season was a
        // value nobody could see. Last, so a beard cannot cover it.
        managerMouths[mood.name],
      ]),
    ],
  );
}

Color? _colourOf(String hex) {
  final parsed = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return parsed == null ? null : Color(0xFF000000 | parsed);
}

/// The ground he walks on.
///
/// Painted rather than a `RadialGradient` in a `BoxDecoration`, and that is not
/// a preference: a radial gradient sizes its radius off the box's SHORTEST side,
/// and this box is 50 wide by 8 tall. The gradient came out an 8px disc lost in
/// the middle of it — a full stop under his boots rather than a shadow. Scaling
/// a circular shader into an ellipse is the only way to get one that is wide.
class _GroundShadow extends StatelessWidget {
  const _GroundShadow();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: Size.infinite, painter: _ShadowPainter());
}

class _ShadowPainter extends CustomPainter {
  const _ShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(1, size.height / size.width);
    final r = size.width / 2;
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black.withValues(alpha: 0.34),
            Colors.black.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShadowPainter old) => false;
}

/// The head: the skull the two hair layers are drawn either side of, and the
/// FACE in it.
///
/// There was no face. The skull was one skin circle and the only feature on it
/// was the mood mouth, drawn over the top out of `manager_art.g.dart` — so the
/// gaffer had a mouth, and glasses if he owned any, and otherwise a blank disc
/// where his eyes should be.
///
/// **He is in three-quarter profile facing right**, which the shipped art
/// already assumed and is worth stating: the `specs` frame is ONE lens at
/// (67.3, 47.4) with an arm running back to the left ear, and every mouth is
/// drawn around x 70. So one eye reads, the nose breaks the right-hand
/// silhouette, and the ear sits at the back on the left. Two symmetrical eyes
/// on this head would fight both of those.
///
/// The features are drawn UNDER `overHead`, which is exactly where they belong:
/// a pair of shades has to cover the eye, a beard has to cover the jaw, and a
/// hat has to sit on the hair.
class _HeadPainter extends CustomPainter {
  const _HeadPainter({
    required this.skin,
    this.blink = 0,
    this.features = false,
  });

  /// **The EYE AND BROW, drawn as their own pass.**
  ///
  /// The JS's stack is skull, paint, front hair, then the features — and the
  /// reason is the paint: war paint drawn over the top swallowed the eye, the
  /// same way it tinted the fringe. Splitting the painter is what lets the
  /// port's one-piece head obey that order; false is the skull and everything
  /// that is not a feature, true is the eye, the lid and the brow.
  final bool features;

  final Color skin;

  /// How shut his eye is, 0 to 1.
  final double blink;

  /// The skull, from the art's own space.
  static const Offset _centre = Offset(62, 48.5);
  static const double _radius = 12.5;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / walkerWidth, size.height / walkerHeight);

    final shade = Color.lerp(skin, Colors.black, 0.22)!;

    if (features) {
      _features(canvas, shade);
      canvas.restore();
      return;
    }

    // **The head is a SKULL WITH A JAW, not a circle with an arc drawn on it.**
    // The circle stays exactly where it was — the generated hair, hats and
    // glasses are all positioned against a skull at (62, 48.5) r12.5, so moving
    // it by a unit puts a hat on his ear. What changes is that the face below the
    // cheekbone now narrows to a chin, which is the whole of the difference
    // between a head and a ball on a stick.
    //
    // Drawn as one path so the skin is a single fill: the cranium as an arc, then
    // two curves down to the chin and back up under the ear.
    final skull = Path()
      ..addArc(
        Rect.fromCircle(center: _centre, radius: _radius),
        _deg(140),
        _deg(180),
      )
      // **The nose is part of the PROFILE, not a shape laid over it.** It used to
      // be its own slightly-lighter sliver drawn on top, and a two-point curve
      // closed with a straight edge — so the closing edge ran down the middle of
      // the face as a visible line. A nose is a bump in the outline; put it in
      // the outline and there is no seam to see.
      ..quadraticBezierTo(73.4, 43.4, 77.0, 48.0)
      ..quadraticBezierTo(74.6, 50.8, 71.9, 51.3)
      // The top lip, then down past the cheekbone to the point of the chin.
      ..quadraticBezierTo(73.6, 55.2, 70.2, 59.6)
      ..quadraticBezierTo(67.6, 62.4, 63.4, 61.8)
      // And back under the jaw to where the ear meets it.
      ..quadraticBezierTo(56.2, 60.8, 52.4, 55.2)
      ..close();

    canvas.drawPath(skull, Paint()..color = skin);
    // Lit from the sky, the same direction as every other surface on this screen.
    canvas.drawPath(
      skull,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.15),
            Colors.black.withValues(alpha: 0.05),
            Colors.black.withValues(alpha: 0.16),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(skull.getBounds()),
    );

    // **THE EAR IS A C, IT IS NOT FILLED, AND IT IS NOT AT THE BACK.**
    //
    // Three goes at this. A flat disc with a smaller dark disc inside it, then a
    // filled teardrop with a dark crescent inside it — and a pale blob with
    // something dark in the middle is an EYE, which is what both read as. So there
    // is no fill: just a thick stroked arc, with no interior left to mistake for an
    // eyeball. **The gap faces FORWARD**, the way he does, because that is the side
    // an ear opens on.
    //
    // And it sits in the MIDDLE of the skull. The circle spans x 49.5 to 74.5, so
    // the middle is 62 — which is where an ear is on a head seen side-on, roughly
    // level with the eye and half way back. Both earlier attempts had it out on the
    // rearmost edge of the silhouette, where it was very nearly out of sight and
    // read as something stuck to the back of his head.
    // **And it is SMALL.** The first C at this position was 5.2 by 7.6 with a
    // 2.2 stroke, so its outer extent was 7.4 by 9.8 against a skull 25 across —
    // an ear taking up a third of his face. A real one is about a quarter of the
    // head's height; this is 5 by 6.9 all in.
    // A shade further back than the skull's own middle — the middle of the SKULL
    // is 62, but the middle of the visible head is forward of that, because the
    // face and nose stick out past the circle on the front. Sitting on 62 the ear
    // read as too far forward.
    const ear = Rect.fromLTWH(58.2, 47.4, 3.6, 5.4);
    canvas.drawArc(
      ear,
      _deg(56),
      _deg(248),
      false,
      Paint()
        ..color = shade
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    // A thinner, darker arc inside the helix — the fold of the concha. It gives the
    // C a near edge and a far one, rather than reading as a bracket drawn on him.
    canvas.drawArc(
      ear.deflate(0.9),
      _deg(70),
      _deg(206),
      false,
      Paint()
        ..color = Color.lerp(skin, Colors.black, 0.26)!
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    // The lobe, hanging a little proud at the bottom of the C.
    canvas.drawCircle(const Offset(60.5, 52.4), 0.7, Paint()..color = shade);

    // A soft shadow in the crease under the nose, which is what gives it
    // relief now that it is the same fill as the face rather than a lighter
    // shape stuck on.
    canvas.save();
    canvas.clipPath(skull);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(73.4, 51.8), width: 5, height: 2.6),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.13)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );
    // The cheekbone, and the shadow under it. Two soft marks and the face has
    // structure — without them the skin is a flat disc whatever shape it is cut
    // to.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(68.4, 50.6), width: 9, height: 5),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(66.6, 56.4), width: 11, height: 5.5),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
    );
    // The neck's own shadow across the jaw, so the head sits ON the shoulders.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(60, 61.6), width: 15, height: 5),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );
    canvas.restore();


    canvas.restore();
  }

  /// The eye, the lid and the brow, in the art's own space.
  void _features(Canvas canvas, Color shade) {
    // The eye, where the glasses' lens lands.
    const eye = Offset(67.3, 47.4);
    canvas.drawOval(
      Rect.fromCenter(center: eye, width: 4.6, height: 3.6),
      Paint()..color = const Color(0xFFFAF7F2),
    );
    canvas.drawCircle(
      eye.translate(0.7, 0.25),
      1.35,
      Paint()..color = const Color(0xFF2A1F18),
    );

    // **THE LID, CLIPPED TO THE EYE.** Drawn straight it is a skin-coloured
    // rectangle sitting on a shaded face — a sticking plaster, which is what the
    // first cut looked like. Clipped to the eye's own oval it can only ever
    // appear where the eye is, so what you see is the eye being covered.
    if (blink > 0.01) {
      final socket = Rect.fromCenter(center: eye, width: 5.0, height: 4.0);
      canvas.save();
      canvas.clipPath(Path()..addOval(socket));
      final lid = socket.height * blink;
      canvas.drawRect(
        Rect.fromLTWH(socket.left, socket.top, socket.width, lid),
        Paint()..color = skin,
      );
      // The lash, along the lid's edge — curved, because an eyelid is not a
      // shutter, and it is what makes a half-blink read as a lid coming down.
      canvas.drawPath(
        Path()
          ..moveTo(socket.left, socket.top + lid)
          ..quadraticBezierTo(
            eye.dx,
            socket.top + lid + 0.9,
            socket.right,
            socket.top + lid,
          ),
        Paint()
          ..color = Color.lerp(skin, Colors.black, 0.5)!
          ..strokeWidth = 0.9
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }
    // The lid, which is what stops the eye reading as a bead: an eye with no top
    // to it is a dot on a face.
    canvas.drawArc(
      Rect.fromCenter(center: eye, width: 5.2, height: 4.6),
      _deg(190),
      _deg(160),
      false,
      Paint()
        ..color = Color.lerp(skin, Colors.black, 0.42)!
        ..strokeWidth = 0.9
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // A brow, and it is the one feature doing any acting.
    canvas.drawLine(
      const Offset(64.3, 43.4),
      const Offset(70.2, 42.9),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    // **THE FAR EYE IS GONE, and it was the "ear that looks like an eye".** It was
    // a pale oval with a dark dot at x 59.6, meant as a hint of the eye on the
    // other side of the head. On a head drawn side-on there is no other side to
    // see — and worse, x 59.6 is precisely where an EAR belongs, so what it
    // actually read as was a small second eye stuck where his ear should be.
    // Nothing replaces it; the ear goes there instead.
  }

  @override
  bool shouldRepaint(_HeadPainter old) =>
      old.skin != skin || old.blink != blink || old.features != features;
}

/// Which arms a rig pass draws.
///
/// **THE HEAD IS PAINTED OVER THE RIG**, because the head and everything it
/// wears is a stack of widgets above the painter — that is what lets a tilt
/// take the hair, the beard, the glasses and the hat with it. Which means a
/// hand that belongs in FRONT of the face ends up behind it: reported as head
/// in hands putting the hands behind the head.
///
/// So a gesture that brings a hand to the face draws the near arm TWICE over —
/// once skipped, once on its own after the head. Only the near one: the far arm
/// is behind him by construction and putting it over the face would be the same
/// bug the other way round.
enum WalkerArms {
  /// The ordinary pass: far arm, body, near arm.
  both,

  /// Everything but the near arm, which is coming later.
  skipNear,

  /// The near arm alone, over the head.
  nearOnly,
}

class _WalkerPainter extends CustomPainter {
  const _WalkerPainter({
    required this.t,
    required this.kit,
    required this.skin,
    required this.build,
    required this.outfit,
    required this.sleevesAreKit,
    this.standing = false,
    this.pose,
    this.arms = WalkerArms.both,
  });

  final double t;
  final Color kit;
  final Color skin;

  /// **HIS SHAPE.** The build axis was in the customiser, the wardrobe, the
  /// randomiser and the save, and produced one figure — nothing read it. See
  /// `managerBuilds` in `walker_figure.dart`.
  final ManagerBuild build;

  /// **WHAT HE IS WEARING, as paint.** An outfit is mostly a palette in the JS —
  /// the forearm, the shin, the boot — with geometry only for a coat's skirt and
  /// a suit's lapels. The port had the geometry and none of the paint, which is
  /// why the tracksuit arrived as a curve across his throat and nothing else.
  final ManagerOutfit outfit;

  /// The tracksuit's sleeves are club-coloured cloth rather than a fixed colour,
  /// so on a striped kit the stripes run down the whole arm.
  final bool sleevesAreKit;

  /// His legs are PLANTED — see [ManagerWalker.standing]. The four leg tracks
  /// are not read at all, and the limbs hold the rest they are drawn at.
  final bool standing;

  /// The gesture on top of the walk, if one is playing.
  ///
  /// **Every field of it is nullable and null means the walk still owns that
  /// joint.** A fist pump is one arm; the other arm swings on. See
  /// `gesture_poses.dart`.
  final GesturePose? pose;

  /// Which arms this pass draws — see [WalkerArms].
  final WalkerArms arms;

  /// The hip, which is what a body fold turns about — not the boots.
  static const Offset _hipPivot = Offset(58, 95);

  /// The far side of the body, darkened. This is the whole of the depth cue.
  Color _shade(Color c) => Color.lerp(c, Colors.black, 0.28)!;

  Color _lift(Color c, double amount) => Color.lerp(c, Colors.white, amount)!;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / walkerWidth, size.height / walkerHeight);

    if (arms == WalkerArms.nearOnly) {
      // The second pass, over the head — see [WalkerArms].
      _arm(canvas, near: true);
      canvas.restore();
      return;
    }

    // FAR limbs first, so the near ones overlap them.
    _leg(canvas, near: false);
    _arm(canvas, near: false);
    _body(canvas);
    _leg(canvas, near: true);
    if (arms == WalkerArms.both) _arm(canvas, near: true);

    canvas.restore();
  }

  /// Rotate about a joint, run [draw], and put the canvas back.
  void _about(Canvas canvas, Offset joint, double degrees, VoidCallback draw) {
    canvas.save();
    canvas.translate(joint.dx, joint.dy);
    canvas.rotate(_deg(degrees));
    canvas.translate(-joint.dx, -joint.dy);
    draw();
    canvas.restore();
  }

  /// The shorts, in the art's own space.
  ///
  /// **Only the SEAT is drawn here.** The thighs below it are drawn in the
  /// shorts' own colour, so the two capsules ARE the legs of the garment and
  /// there is nothing for a separate hem to line up with. It was a full block
  /// down to the knee, which is why it read as a brick with a radius on it: the
  /// far leg swinging through left the seat's square bottom corner hanging in
  /// the air behind him.
  static const double _shortsLeft = 49.6;
  static const double _shortsRight = 67;
  static const double _shortsTop = 86;
  static const double _shortsHem = 100;

  /// The middle of the shorts, which is also where the hips are.
  static const double _hipCentre = (_shortsLeft + _shortsRight) / 2;

  /// Both hips, straddling that middle. They used to be 60 and 56 against a
  /// garment centred on 58.25, so the pair of them sat forward of the body they
  /// hang off.
  double _hipX(bool near) => near ? _hipCentre + 2 : _hipCentre - 2;

  /// A waistband, a seat that curves under, and no corners anywhere.
  Path _shortsPath() => Path()
    ..moveTo(_shortsLeft + 1.6, _shortsTop)
    // The waistband, with a little rise over the seat.
    ..quadraticBezierTo(
      _hipCentre,
      _shortsTop - 2.4,
      _shortsRight - 1.6,
      _shortsTop,
    )
    // Down the front and round under him — one curve each side, so the bottom
    // of the garment is a belly rather than an edge.
    ..quadraticBezierTo(
      _shortsRight + 1.2,
      _shortsTop + 7,
      _shortsRight - 3.5,
      _shortsHem,
    )
    ..quadraticBezierTo(
      _hipCentre,
      _shortsHem + 3.2,
      _shortsLeft + 3.5,
      _shortsHem,
    )
    ..quadraticBezierTo(
      _shortsLeft - 1.2,
      _shortsTop + 7,
      _shortsLeft + 1.6,
      _shortsTop,
    )
    ..close();

  /// How far down the thigh the shorts reach, in art units.
  static const double _shortsLeg = 13;

  /// The shorts, and the legs of them over the thigh — a good deal darker
  /// than the shirt. At 22% the shirt, the seat and both thighs were one red
  /// mass from the collar to the knee, which is a romper suit and not a kit.
  Color get _shortsColour =>
      outfit.legs ?? Color.lerp(kit, Colors.black, 0.36)!;

  /// The body of whatever he has on. The club's colour is the zero point.
  Color get _top => outfit.top ?? kit;

  /// One leg, and the fold it may be standing inside.
  ///
  /// **The counter-rotation WRAPS the leg; it does not replace the stride.** The
  /// JS learned that the hard way — put on the thigh directly it REPLACED the
  /// walk, which made the legs snap together and then walk out of step
  /// afterwards once the stride restarted from phase zero. As a wrapper the two
  /// compose: the leg keeps doing whatever the walk is doing, inside a group
  /// leaning back by exactly what the body leans forward.
  void _leg(Canvas canvas, {required bool near}) {
    final fold = pose?.legs;
    if (fold != null && fold != 0) {
      _about(canvas, _hipPivot, fold, () => _legInner(canvas, near: near));
      return;
    }
    _legInner(canvas, near: near);
  }

  void _legInner(Canvas canvas, {required bool near}) {
    final legs = near ? _shortsColour : _shade(_shortsColour);
    // **TROUSERS REACH THE SHOE.** Bare shins are the kit's, and every other
    // outfit covers them — which, with the sleeve, is most of what makes a
    // tracksuit a tracksuit rather than a collar line.
    final shin = outfit.shin ?? skin;
    final flesh = near ? shin : _shade(shin);
    final boot = near ? outfit.boot : _shade(outfit.boot);

    // **PLAYED, not solved** — the JS's own thigh and shin tracks. The far leg is
    // the same tracks half a cycle on, which is the whole of what makes it a walk.
    final phase = t % 1;
    final x = _hipX(near);
    // A planted figure holds the angles the art is DRAWN at, which is what the
    // stylesheet's `animation: none` leaves on the four leg elements — and it
    // is nowhere on the cycle, so there is no phase to read it off.
    final solved = standing
        ? (thigh: 0.0, shin: 0.0)
        : (
            thigh: walkerThighAngle(phase, near: near),
            shin: walkerShinAngle(phase, near: near),
          );
    // **No rotation of its own.** The boot is drawn inside the shin's frame, so
    // zero is the JS's arrangement exactly: it points where the lower leg points,
    // and there is no toe left pointing at the end of the step.
    const ankle = 0.0;

    final hip = Offset(x, _hipY);
    final knee = Offset(x, _hipY + walkerThigh);
    final foot = Offset(x, _hipY + walkerThigh + walkerShin);

    // CAPSULES from the joint, not rectangles whose top edge happens to pass
    // through it. A rotated rectangle swings its own corners out of the socket,
    // which is what opened a wedge of background at the hip on every stride;
    // a round-capped stroke is a circle at the pivot however far it turns, so
    // the joint cannot come apart.
    _about(canvas, hip, solved.thigh, () {
      // **A thigh is thick at the hip and narrow at the knee.** It was 9 units
      // of constant width, which is a tube; the taper is most of what makes it
      // a leg. A BARE thigh with a short leg of the shorts over it — the whole
      // thigh used to be the garment's colour, which put a run of dark red from
      // the waistband to the knee: long trousers cut off, not a kit. Shorts stop
      // less than half way down, and it is that break which says "kit".
      // **A KIT'S THIGH IS BARE; TROUSERS COVER IT.** The break where the
      // shorts stop is exactly what says "kit", and there is no such break on a
      // tracksuit or a suit — a bare thigh under full-length bottoms is shorts
      // with long socks.
      final bare = outfit.shin == null;
      paintLimb(
        canvas,
        hip,
        knee,
        11.2 * build.limb,
        8.4 * build.limb,
        base: bare ? flesh : legs,
        far: !near,
      );
      if (bare) {
        final hem = Offset(hip.dx, hip.dy + _shortsLeg);
        paintLimb(
          canvas,
          hip,
          hem,
          12.4 * build.limb,
          11 * build.limb,
          base: legs,
          far: !near,
        );
      }
      // The stripe down the outside of the leg. One line, the length of the
      // thigh — the tracksuit is the only outfit that has one, and it is the
      // mark that tells it from a plain pair of dark trousers.
      final stripe = outfit.legStripe;
      if (stripe != null) {
        canvas.drawLine(
          Offset(hip.dx + 4.4 * build.limb, hip.dy + 3),
          Offset(knee.dx + 3.2 * build.limb, knee.dy),
          Paint()
            ..color = near ? stripe : _shade(stripe)
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round,
        );
      }
      _about(canvas, knee, solved.shin, () {
        // The calf swells above the middle and tucks into the ankle, so the
        // widest point is NOT at the knee — a shin that tapers straight down
        // reads as a chair leg.
        final belly = Offset.lerp(knee, foot, 0.34)!;
        paintLimb(
          canvas,
          knee,
          belly,
          8.2 * build.limb,
          8.8 * build.limb,
          base: flesh,
          far: !near,
        );
        paintLimb(
          canvas,
          belly,
          foot,
          8.8,
          5.4,
          base: flesh,
          far: !near,
          occlude: false,
        );
        _about(canvas, foot, ankle, () {
          // The boot runs FORWARD from the ankle, so the heel sits under the leg
          // and the toe leads — a boot centred on the ankle pivots about its own
          // middle and reads as a skate.
          paintBoot(canvas, foot, boot);
        });
      });
    });
  }

  void _arm(Canvas canvas, {required bool near}) {
    // **THE UPPER ARM IS THE GARMENT, not the shirt underneath it.** `--top`
    // paints the body and the biceps together in the CSS, so a coat sleeve that
    // only started at the elbow left a green shoulder on a charcoal overcoat.
    final sleeve = near ? _top : _shade(_top);
    // **THE SLEEVE REACHES THE WRIST** on everything but the playing kit: bare
    // arms are the kit's zero point and every other outfit covers them. The
    // tracksuit's is club-coloured CLOTH rather than a fixed colour, so on a
    // striped kit the stripes run down the whole arm.
    final cuff = sleevesAreKit ? kit : (outfit.fore ?? skin);
    final fore = near ? cuff : _shade(cuff);
    // **THE HAND STAYS SKIN, whatever he is wearing.** The JS never overrides
    // `--hand` on any outfit, and a coat that paints the hand charcoal ends the
    // arm in a stump.
    final flesh = near ? skin : _shade(skin);
    final posed = near ? pose?.armNear : pose?.armFar;
    final posedFore = near ? pose?.foreNear : pose?.foreFar;
    _about(
      canvas,
      const Offset(56, 62),
      posed ?? _sample(near ? _armNear : _armFar, t),
      () {
        // The sleeve, wide at the deltoid and narrowing to the elbow.
        //
        // **The ARM scale, not the limb one.** Shoulder width is not legible on
        // a figure drawn in profile and depth is, so `athletic` puts its muscle
        // here and leaves the legs near normal — which is also what sells the
        // arms as the thing that changed.
        paintLimb(
          canvas,
          const Offset(56, 62),
          const Offset(56, 81),
          11 * build.arm,
          7.6 * build.arm,
          base: sleeve,
          far: !near,
        );
        _about(
          canvas,
          const Offset(56, 80),
          posedFore ?? _sample(near ? _elbowNear : _elbowFar, t),
          () {
            // A forearm is widest just below the elbow and narrowest at the
            // wrist, which is the other end of the same rule the calf follows.
            // **The arm reaches mid-thigh.** It stopped at the waistband, which
            // is a child's proportion — the hand hung level with the hip and the
            // whole figure read as short-armed.
            paintLimb(
              canvas,
              const Offset(56, 81),
              const Offset(56, 98.5),
              7.4 * build.arm,
              4.8 * build.arm,
              base: fore,
              far: !near,
            );
            // The watch goes on the NEAR wrist, which is the arm every pointing
            // and watch-checking gesture uses. Under the hand, so the palm
            // overlaps the strap.
            if (near) paintWatch(canvas, const Offset(56, 95.6), kit);
            // The hand as a MITTEN rather than a circle: wider across the
            // knuckles than at the wrist, which is what stops the arm reading as
            // one tapering stick with a bead on the end.
            paintHand(canvas, const Offset(56, 100.6), flesh, far: !near);
            // And the finger, out past it, for the gestures that point.
            if (near) {
              paintFinger(
                canvas,
                const Offset(56, 100.6),
                flesh,
                pose?.finger ?? 0,
              );
            }
          },
        );
      },
    );
  }

  void _body(Canvas canvas) {
    // **SHORTS, not a rounded block.** A rectangle with a 4px radius is what was
    // there, and it read as exactly that — a brick between the shirt and the
    // legs, with the legs coming out of its side. Shorts have a waist, a hem
    // that flares, and a notch between the legs; three curves and it is a
    // garment. The hem also has to be BELOW the hip pivot (see [_hipX]), or the
    // thigh appears to grow out of the middle of the block.
    final shortsColour = _shortsColour;
    // **THE HIP SCALE STAYS NEAR 1**, and the JS's note says why: the shorts are
    // already about twice the width of the leg beneath them and that flare is
    // intended, so even 1.16 pushes the block out in front of AND behind the
    // legs and reads as a slab. A build's width belongs in the torso; this is
    // fine adjustment.
    canvas.save();
    canvas.translate(_hipCentre, 0);
    canvas.scale(build.hip, 1);
    canvas.translate(-_hipCentre, 0);
    canvas.drawPath(
      _shortsPath(),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(_shortsLeft, _shortsTop),
          const Offset(_shortsRight, _shortsHem),
          [
            _lift(shortsColour, 0.12),
            shortsColour,
            Color.lerp(shortsColour, Colors.black, 0.22)!,
          ],
          [0, 0.5, 1],
        ),
    );
    canvas.restore();

    // **The shirt is a SILHOUETTE now, not a 15×32 rounded rectangle.** A man the
    // same width at the shoulder as at the waist is a doll — the shape is where
    // his build lives, before any shading gets a say. See `walker_figure.dart`.
    //
    // The neck goes in first so the collar and the skull both overlap it: the
    // head used to sit straight on the shirt, which is the other half of why it
    // read as stuck on.
    paintNeck(canvas, skin);
    paintTorso(canvas, _top, build: build.torso, bulge: build.bulge);

    // Where the shirt meets the shorts. A garment that ends without a shadow
    // under it reads as printed on rather than worn.
    canvas.drawRect(
      const Rect.fromLTWH(48.4, 87, 19.6, 3.4),
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );

    // The seam down the front, which is the one mark that says "shirt" rather
    // than "torso". Short of the hem, because a seam that reaches the waistband
    // reads as a zip.
    canvas.drawLine(
      const Offset(60, 66),
      const Offset(59.4, 85),
      Paint()
        ..color = Color.lerp(kit, Colors.black, 0.16)!
        ..strokeWidth = 0.9,
    );
  }

  @override
  bool shouldRepaint(_WalkerPainter old) =>
      old.t != t ||
      old.kit != kit ||
      old.skin != skin ||
      old.build != build ||
      old.outfit != outfit ||
      old.sleevesAreKit != sleevesAreKit ||
      old.standing != standing ||
      old.pose != pose;
}
