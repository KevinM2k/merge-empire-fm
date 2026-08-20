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
import 'package:merge_empire_fc/data/manager_art.dart';
import 'package:merge_empire_fc/data/manager_art.g.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_scene.dart';
import 'package:merge_empire_fc/ui/widgets/svg_canvas.dart';

/// The figure's own space, shared with `data/manager_art.g.dart` so a hat lands
/// on the head with no positioning of its own.
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
const double walkerFootline = 152.5;

/// The leg, in art units. **These are the lengths the rig is DRAWN at**, and
/// the IK below solves against them, so the two cannot disagree.
///
/// They used to: the constants said 30 and 27 while `_leg` drew the knee at
/// hip+30 and the ankle at hip+54 — a 24-unit shin. The stride was computed off
/// 27 and walked off 24, which is a 5% moonwalk before anything else went wrong.
const double walkerThigh = 30;
const double walkerShin = 30;

/// How much reach is held BACK from straight, in art units.
///
/// **A knee that reaches full extension locks**, and a locked knee is the thing
/// you notice: the leg goes rigid for an instant at foot-down and the figure
/// reads as a pair of scissors. Keeping a couple of units in hand means the joint
/// always has a bend in it, which is also true of a real leg — nobody walks with
/// a straight knee.
const double _kneeLock = 1.6;

/// The furthest the ankle can get from the hip.
const double _legReach = walkerThigh + walkerShin - _kneeLock;

/// Where each leg hangs from, and where the ground is, in the art's own space.
///
/// [_groundY] is the ANKLE's height on the grass — the boot hangs below it — and
/// it is what the stride is solved against, so moving it changes the step length
/// rather than lifting him off the turf.
const double _hipY = 95;
const double _groundY = 149;

/// How far the hips rise, twice a stride.
///
/// **The bob is not decoration here, it is what buys the step.** A leg of a fixed
/// length standing on flat ground can only reach so far forward and back, and the
/// hip has to come DOWN at both extremes for the foot to get there — which is
/// exactly what a real pelvis does. Take the bob out and the stride has to
/// shorten with it.
const double _bob = 4;

/// How far his planted foot travels in half a stride, in art units.
///
/// **This is the number the ground has to match**, and it is SOLVED rather than
/// picked: at the extremes of the step the hip is at its lowest and the leg is at
/// full reach, so half the step is the base of a right triangle with the leg as
/// its hypotenuse. Get it wrong and he moonwalks — forwards if the ground is
/// slow, backwards if it is fast — and no amount of looking at the walk cycle
/// will show you which, because the walk cycle is not what is wrong.
final double walkerStrideArtUnits = 2 * _halfStride;

final double _halfStride = math.sqrt(
  _legReach * _legReach - (_groundY - _hipY) * (_groundY - _hipY),
);

/// How high the swinging foot lifts off the grass at the top of its arc.
const double _footLift = 11;

/// Where the ankle should BE, at phase [t], in the art's own space.
///
/// **The foot's path is the input now, and the joints are solved from it.** The
/// rig used to work the other way round — the JS's keyframed thigh and shin
/// angles were played and the foot went wherever they put it, which was not
/// anywhere a foot goes. Two things came out of that and both are visible: over
/// the first 6% of the step the planted foot moved BACKWARDS, against a ground
/// travelling forwards, which is the judder as he puts his foot down; and the
/// travel through the rest of the stance was 8% slower then 8% faster than the
/// grass, which is the residual skate. Neither can be tuned out by retiming,
/// because the poses themselves are wrong.
///
/// Stated as a path it is simply what a walk is. On the ground: a straight line
/// at a constant rate — that IS what "planted" means, and it is the one property
/// that makes the ground and the boot agree. In the air: back to the front,
/// eased, over an arc.
({double x, double y}) walkerAnkle(double t) {
  final u = t % 1;
  // **THE ANKLE RIDES UP OVER THE BOOT.** It was pinned at ground height through
  // the whole stance while the boot rotated about it, which drives the toe
  // straight into the turf at push-off — thirty degrees of it — and leaves the
  // heel planted when it should be the first thing off the grass. The boot's own
  // corners say where the ankle has to be: rotate them and the deepest one is
  // the bit standing on the ground.
  final lift = _bootSoleDrop(0) - _bootSoleDrop(_sample(_bootWorld, u));
  final y = _groundY + walkerHipRise(u) + lift;
  if (u < 0.5) {
    // Stance. Linear, and the only linear thing in the rig.
    return (x: _halfStride - walkerStrideArtUnits * (u / 0.5), y: y);
  }
  // Swing. Eased, because the foot accelerates off the ground and decelerates
  // into the next contact rather than sliding through at one speed.
  final v = (u - 0.5) / 0.5;
  return (
    x: -_halfStride + walkerStrideArtUnits * Curves.easeInOut.transform(v),
    y: y - _footLift * math.sin(v * math.pi),
  );
}

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
/// which is the whole point of [_bootSoleDrop].
double walkerBootSoleY(double t) =>
    walkerAnkle(t).y + _bootSoleDrop(_sample(_bootWorld, t % 1));

/// The boot, measured from the ankle, in art units.
const double _bootToe = 11.5;
const double _bootHeel = 3.5;
const double _bootSole = 3.5;

/// How far the hips are up at phase [t].
///
/// Twice a stride, highest at mid-stance and lowest as the legs pass their
/// extremes — see [_bob]. Eased, and the CSS says why: a vertical bounce should
/// decelerate at the top.
double walkerHipRise(double t) =>
    _bob *
    math.sin(Curves.easeInOut.transform((t * 2) % 1) * math.pi).abs();

/// Where the near foot is, at rig phase [t], in art units — forward is POSITIVE.
///
/// Public because the one thing worth pinning about the gait is that the planted
/// foot and the ground agree, and that is a statement about this function rather
/// than about anything a widget renders.
double walkerFootX(double t) => walkerAnkle(t).x;

/// Solve a two-bone leg for an ankle at ([dx], [dy]) from the hip.
///
/// Returns the thigh's rotation and the shin's rotation RELATIVE TO IT, in
/// degrees, in the rig's own sense: a positive rotation swings the limb
/// backwards, because the canvas rotates clockwise and the leg hangs down.
///
/// Ordinary two-bone IK: the hip, knee and ankle make a triangle whose sides are
/// the two bone lengths and the distance to the target, so the law of cosines
/// gives the knee's interior angle, and the angle to the target less the
/// triangle's angle at the hip gives the thigh's. The knee bends BACKWARD, which
/// is the sign the JS's own keyframes carry — its shin track is positive
/// throughout.
({double thigh, double shin}) _solveLeg(double dx, double dy) {
  final reach = math.sqrt(dx * dx + dy * dy).clamp(
    (walkerThigh - walkerShin).abs() + 2,
    _legReach,
  );
  final cosKnee =
      (walkerThigh * walkerThigh + walkerShin * walkerShin - reach * reach) /
      (2 * walkerThigh * walkerShin);
  final knee = math.acos(cosKnee.clamp(-1.0, 1.0));
  final atHip = math.asin(
    (walkerShin * math.sin(knee) / reach).clamp(-1.0, 1.0),
  );
  // The target's own bearing from straight down, in the same sense as the joints.
  final bearing = math.atan2(-dx, dy);
  return (
    thigh: (bearing - atHip) * 180 / math.pi,
    shin: (math.pi - knee) * 180 / math.pi,
  );
}

/// The boot's angle to the GROUND, in degrees, positive toes-down.
///
/// Solved for rather than hung off the shin, and stated in world terms because
/// that is the only frame in which "flat on the grass" means anything: a foot
/// whose angle is a fraction of the shin's is flat at exactly one instant of the
/// stride and wrong either side of it.
///
/// Heel first, flat almost at once, then up onto the toe to push off; the toe
/// stays down as the foot leaves and comes back up for the next contact.
const _Track _bootWorld = [
  (0, -13), // heel strike
  (0.08, 0), // flat
  (0.4, 2),
  (0.5, 30), // toe-off
  (0.62, 22),
  (0.8, 2),
  (1, -13),
];

/// How far his soles sit above the bottom of his box, in art units.
const double walkerFootOffset = walkerHeight - walkerFootline;

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

/// How tall the shadow's own box is, as a fraction of his.
///
/// Raised from 0.045: at that height it was a 7px sliver under a 230px figure,
/// which is a mark on the grass rather than a shadow, and the gap between the
/// sole and the top of it was most of what read as floating. At 0.10 the top of
/// the ellipse reaches the soles, which is the point — a shadow a boot does not
/// touch is a shadow of something else.
const double _shadowBand = 0.10;

/// How far left of the feet's midpoint the shadow sits, in art units.
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
const Alignment _shadowAlignment = Alignment(
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

class ManagerWalker extends StatefulWidget {
  const ManagerWalker({
    required this.kit,
    required this.skin,
    required this.hair,
    this.look,
    this.mood = Mood.neutral,
    this.walking = true,
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

  @override
  State<ManagerWalker> createState() => _ManagerWalkerState();
}

class _ManagerWalkerState extends State<ManagerWalker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: walkDurationFor(widget.mood),
  );

  /// Whether he should be moving at all.
  ///
  /// Honours the platform's reduce-motion setting: he is decoration on the
  /// screen the app OPENS on, which is exactly the kind of perpetual movement
  /// that setting exists to stop. It is also what lets a widget test settle —
  /// a looping animation never does.
  bool _shouldWalk(BuildContext context) =>
      widget.walking && !MediaQuery.of(context).disableAnimations;

  void _sync(BuildContext context) {
    // His TEMPO is his mood. A retime carries the phase across so a result
    // landing mid-stride does not snap his legs back to the start of the cycle —
    // and the grass, which is timed off the same figure, retimes with him.
    // His TEMPO is his mood, and the grass is timed off the same figure — so a
    // result that cheers him up speeds both up together. The stride restarts from
    // the top rather than carrying its phase across: `repeat` cannot resume
    // mid-cycle, and a mood only changes at full time, where the scene is not
    // what anybody is looking at.
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
    _sync(context);
  }

  @override
  void didUpdateWidget(ManagerWalker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(context);
  }

  @override
  void dispose() {
    _clock.dispose();
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
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          final t = _clock.value;
          // The hips, and the same number the leg solver uses — see
          // [walkerHipRise]. It is not decoration: the bob is what lets the foot
          // reach the ends of the step, so the figure's rise and its stride are
          // one calculation and cannot drift apart.
          final rise = walkerHipRise(t);

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
                  (_footSpan(t).centre * 0.5 - _shadowBias) / (walkerWidth / 2),
                  _shadowAlignment.y,
                ),
                child: FractionallySizedBox(
                  widthFactor:
                      (_footSpan(t).width + _shadowPad * 2) / walkerWidth -
                      rise / walkerHeight,
                  heightFactor: _shadowBand,
                  child: const _GroundShadow(),
                ),
              ),
              Transform.translate(
                offset: Offset(math.sin(t * 2 * math.pi) * _sway, _sink - rise),
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
                    for (final svg in parts.behindHead)
                      _SetBack(child: SvgArt(svg: svg)),
                    _SetBack(
                      child: CustomPaint(painter: _HeadPainter(skin: parts.skin)),
                    ),
                    for (final svg in parts.overHead)
                      _SetBack(child: SvgArt(svg: svg)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One layer of the head, moved back over the body. See [_headSetBack].
class _SetBack extends StatelessWidget {
  const _SetBack({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => FractionalTranslation(
    translation: const Offset(-_headSetBack / walkerWidth, 0),
    child: child,
  );
}

/// The parts one look draws, already recoloured and in layer order.
typedef ManagerParts = ({
  Color skin,
  List<String> overTorso,
  List<String> behindHead,
  List<String> overHead,
});

/// Resolve a look into drawable, recoloured fragments.
///
/// Pure, and public, because the layering is the part worth pinning in a test:
/// hair behind the skull, the skull, hair in front of it, then beard, glasses and
/// hat over the lot.
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

  final (hairBack, hairFront) =
      managerHair['${look['style']}'] ?? managerHair['crop']!;

  return (
    skin: _colourOf(skinColour) ?? skin,
    overTorso: present([
      managerOutfits['${look['outfit']}'],
      managerNeck['${look['neck']}'],
    ]),
    behindHead: present([hairBack]),
    overHead: present([
      hairFront,
      managerBeards['${look['beard']}'],
      managerFaces['${look['face']}'],
      managerHats['${look['hat']}'],
      // The mouth is the manager's MOOD, and `manager_mood.dart` was ported with
      // nothing to draw it: how the gaffer feels about the season was a value
      // nobody could see. Last, so a beard cannot cover it.
      managerMouths[mood.name],
    ]),
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
  const _HeadPainter({required this.skin});

  final Color skin;

  /// The skull, from the art's own space.
  static const Offset _centre = Offset(62, 48.5);
  static const double _radius = 12.5;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / walkerWidth, size.height / walkerHeight);

    final shade = Color.lerp(skin, Colors.black, 0.22)!;
    final skinPaint = Paint()..color = skin;

    // The ear first, so the skull covers all but its outer edge — an ear drawn
    // on top of the head is a handle.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(51.8, 50.4),
        width: 5.4,
        height: 6.6,
      ),
      Paint()..color = shade,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(52.4, 50.4),
        width: 2.6,
        height: 3.4,
      ),
      Paint()..color = Color.lerp(skin, Colors.black, 0.38)!,
    );

    // The nose breaks the silhouette on the right rather than sitting inside
    // it: a nose that does not cross the outline is a smudge on a cheek.
    canvas.drawPath(
      Path()
        ..moveTo(72.6, 46.6)
        ..quadraticBezierTo(76.6, 50.2, 73.2, 52.4)
        ..close(),
      skinPaint,
    );

    canvas.drawCircle(_centre, _radius, skinPaint);

    // Lit from the sky, the same direction as the rest of the figure.
    canvas.drawCircle(
      _centre,
      _radius,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.13),
            Colors.black.withValues(alpha: 0.13),
          ],
        ).createShader(Rect.fromCircle(center: _centre, radius: _radius)),
    );

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
    // A brow, and it is the one feature doing any acting: without it the eye
    // reads as a bead.
    canvas.drawLine(
      const Offset(64.3, 43.4),
      const Offset(70.2, 42.9),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    // The far eye, mostly hidden round the curve of the head — a hint, not a
    // second full eye.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(59.6, 47.8), width: 2.6, height: 3),
      Paint()..color = const Color(0x66FAF7F2),
    );
    canvas.drawCircle(
      const Offset(59.9, 48),
      0.9,
      Paint()..color = const Color(0xCC2A1F18),
    );

    // The jaw, which is what stops the head reading as a ball on a stick.
    canvas.drawArc(
      Rect.fromCircle(center: _centre.translate(0.5, 1), radius: _radius - 0.8),
      _deg(20),
      _deg(120),
      false,
      Paint()
        ..color = shade.withValues(alpha: 0.5)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeadPainter old) => old.skin != skin;
}

class _WalkerPainter extends CustomPainter {
  const _WalkerPainter({
    required this.t,
    required this.kit,
    required this.skin,
  });

  final double t;
  final Color kit;
  final Color skin;

  /// The far side of the body, darkened. This is the whole of the depth cue.
  Color _shade(Color c) => Color.lerp(c, Colors.black, 0.28)!;

  Color _lift(Color c, double amount) => Color.lerp(c, Colors.white, amount)!;

  /// A limb, lit down one edge and falling into shade on the other.
  ///
  /// Flat fills read clean and plasticky — every segment the same value as every
  /// other, so the figure has no volume and nothing tells you which side the sky
  /// is on. One gradient ACROSS each limb costs nothing and is most of the
  /// difference between a rig and a drawing.
  Paint _limbPaint(Color base, Offset from, Offset to, double width) {
    // Across the limb, not along it: a sausage lit end-to-end looks like a
    // gradient, one lit edge-to-edge looks round.
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    final nx = len == 0 ? 1.0 : -dy / len;
    final ny = len == 0 ? 0.0 : dx / len;
    final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
    final r = width / 2;
    return Paint()
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(
        Offset(mid.dx - nx * r, mid.dy - ny * r),
        Offset(mid.dx + nx * r, mid.dy + ny * r),
        [_lift(base, 0.16), base, Color.lerp(base, Colors.black, 0.22)!],
        [0, 0.45, 1],
      );
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / walkerWidth, size.height / walkerHeight);

    // FAR limbs first, so the near ones overlap them.
    _leg(canvas, near: false);
    _arm(canvas, near: false);
    _body(canvas);
    _leg(canvas, near: true);
    _arm(canvas, near: true);

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

  /// Where each leg hangs from. TWO hips, not one.
  ///
  /// Both legs used to pivot on the same point and be drawn at the same x, so
  /// the figure had one leg-shaped stack with a second one hidden exactly
  /// behind it — which is why the far leg never looked attached to anything.
  /// They are 4 apart now, both well inside the shorts.
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
  Color get _shortsColour => Color.lerp(kit, Colors.black, 0.36)!;

  void _leg(Canvas canvas, {required bool near}) {
    final legs = near ? _shortsColour : _shade(_shortsColour);
    final flesh = near ? skin : _shade(skin);
    final boot = near ? const Color(0xFF141414) : const Color(0xFF0B0B0B);

    // **SOLVED, not keyframed.** The ankle's path is the input and the joints
    // come out of it — see [walkerAnkle] and [_solveLeg]. The far leg is the near
    // one half a cycle on, which is the whole of what makes it a walk.
    final phase = near ? t : (t + 0.5) % 1;
    final target = walkerAnkle(phase);
    // Both legs hang off the SAME hips, so the far leg's target is measured from
    // its own socket while the body's rise is shared.
    final x = _hipX(near);
    final solved = _solveLeg(target.x, target.y - _hipY);
    // The boot's angle to the GROUND, less whatever the leg above it is doing —
    // which is what leaves a foot flat on the grass rather than at a fraction of
    // the shin's angle. See [_bootWorld].
    final ankle = _sample(_bootWorld, phase) - solved.thigh - solved.shin;

    final hip = Offset(x, _hipY);
    final knee = Offset(x, _hipY + walkerThigh);
    final foot = Offset(x, _hipY + walkerThigh + walkerShin);

    // CAPSULES from the joint, not rectangles whose top edge happens to pass
    // through it. A rotated rectangle swings its own corners out of the socket,
    // which is what opened a wedge of background at the hip on every stride;
    // a round-capped stroke is a circle at the pivot however far it turns, so
    // the joint cannot come apart.
    _about(canvas, hip, solved.thigh, () {
      // A BARE thigh with a short leg of the shorts over it. The whole thigh
      // used to be the garment's colour, which put a run of dark red from the
      // waistband to the knee — long trousers cut off, not a kit. Shorts stop
      // less than half way down the thigh, and it is that break which says
      // "kit" rather than "outfit".
      canvas.drawLine(hip, knee, _limbPaint(flesh, hip, knee, 9));
      final hem = Offset(hip.dx, hip.dy + _shortsLeg);
      canvas.drawLine(hip, hem, _limbPaint(legs, hip, hem, 11.5));
      _about(canvas, knee, solved.shin, () {
        canvas.drawLine(knee, foot, _limbPaint(flesh, knee, foot, 8));
        _about(canvas, foot, ankle, () {
          // The boot runs FORWARD from the ankle, so the heel sits under the leg
          // and the toe leads — a boot centred on the ankle pivots about its own
          // middle and reads as a skate.
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(foot.dx - 3.5, foot.dy - 2, 15, 5.5),
              const Radius.circular(2.75),
            ),
            Paint()..color = boot,
          );
        });
      });
    });
  }

  void _arm(Canvas canvas, {required bool near}) {
    final sleeve = near ? kit : _shade(kit);
    final flesh = near ? skin : _shade(skin);
    _about(
      canvas,
      const Offset(56, 62),
      _sample(near ? _armNear : _armFar, t),
      () {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(52.5, 62, 7, 19),
            const Radius.circular(3.5),
          ),
          Paint()..color = sleeve,
        );
        _about(
          canvas,
          const Offset(56, 80),
          _sample(near ? _elbowNear : _elbowFar, t),
          () {
            canvas.drawLine(
              const Offset(56, 81),
              const Offset(56, 94),
              _limbPaint(
                flesh,
                const Offset(56, 81),
                const Offset(56, 94),
                6.5,
              ),
            );
            // The hand, a touch lighter than the forearm — which is what stops
            // the two reading as one tapering stick.
            canvas.drawCircle(
              const Offset(56, 95.5),
              3.9,
              Paint()..color = _lift(flesh, 0.06),
            );
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

    const shirt = Rect.fromLTWH(50.5, 58, 15, 32);
    canvas.drawRRect(
      RRect.fromRectAndRadius(shirt, const Radius.circular(5)),
      Paint()
        // Lit from the top-left, the same corner every other surface on this
        // screen is lit from — the turf, the crowd, the glass panels. Flat fills
        // read clean and plasticky; one gradient is most of the difference
        // between a rig and a drawing, and it costs a shader.
        ..shader = ui.Gradient.linear(
          shirt.topLeft,
          shirt.bottomRight,
          [_lift(kit, 0.2), kit, Color.lerp(kit, Colors.black, 0.2)!],
          [0, 0.5, 1],
        ),
    );

    // Where the shirt meets the shorts. A garment that ends without a shadow
    // under it reads as printed on rather than worn.
    canvas.drawRect(
      const Rect.fromLTWH(50.5, 86, 15, 3),
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );

    // A collar and a seam down the shirt. Two marks, and they are what make it a
    // top rather than a rounded rectangle.
    canvas.drawPath(
      Path()
        ..moveTo(54, 59)
        ..quadraticBezierTo(58, 64, 62, 59.5),
      Paint()
        ..color = Color.lerp(kit, Colors.black, 0.3)!
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(58, 63),
      const Offset(58, 86),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.08)
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_WalkerPainter old) =>
      old.t != t || old.kit != kit || old.skin != skin;
}
