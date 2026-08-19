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
const _Track _thighNear = [(0, -31), (0.5, 25), (1, -31)];
const _Track _thighFar = [(0, 25), (0.5, -31), (1, 25)];
const _Track _shinNear = [(0, 6), (0.25, 4), (0.5, 13), (0.75, 60), (1, 6)];
const _Track _shinFar = [(0, 13), (0.25, 60), (0.5, 6), (0.75, 4), (1, 13)];
const _Track _armNear = [(0, 27), (0.5, -27), (1, 27)];
const _Track _armFar = [(0, -27), (0.5, 27), (1, -27)];

/// THE ANKLE IS A JOINT, not a fraction of the shin.
///
/// It was `-shin * 0.72` — one number taking back most of whatever the shin was
/// doing — and that cannot be right at both ends of a stride, because the foot
/// is doing opposite things at them. At toe-off the rear shin is up at 60 and
/// the foot should be pointing DOWN off it at about 40 to the ground; the
/// proportional take-back put it at 14, which is a flat foot dragged along
/// behind him. At heel strike the front foot should be toe-UP and it was toed
/// down instead. The back foot never bent because nothing told it to.
///
/// These are absolute degrees relative to the shin, and they are tuned against
/// the sum: the boot's angle to the ground is thigh + shin + ankle, and it is
/// that sum which has to read.
const _Track _ankleNear = [(0, 13), (0.25, -1), (0.5, 0), (0.75, -32), (1, 13)];
const _Track _ankleFar = [(0, 0), (0.25, -32), (0.5, 13), (0.75, -1), (1, 0)];

/// And so is the elbow. The JS hangs the forearm at a static -52, which is a
/// hinge that never hinges — the arm swings from the shoulder as one plank. It
/// closes as the arm comes forward and opens as it goes back, which is what an
/// arm does.
const _Track _elbowNear = [
  (0, -38),
  (0.25, -52),
  (0.5, -68),
  (0.75, -52),
  (1, -38),
];
const _Track _elbowFar = [
  (0, -68),
  (0.25, -52),
  (0.5, -38),
  (0.75, -52),
  (1, -68),
];

/// How tall the shadow's own box is, as a fraction of his.
const double _shadowBand = 0.045;

/// Where that box has to sit for its centre to land on [walkerFootline].
///
/// Derived rather than typed, so it cannot go stale if either fraction moves:
/// `Align` puts a child of height fH inside a box of height H with its centre at
/// H/2 + a(H - fH)/2, and we want that centre on the footline.
const Alignment _shadowAlignment = Alignment(
  0,
  (2 * walkerFootline / walkerHeight - 1) / (1 - _shadowBand),
);

/// How far the whole figure rises, twice a stride.
const double _bob = 4;

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
          // Twice a stride, and eased — a vertical bounce should decelerate at
          // the top, unlike the limbs.
          final rise =
              _bob *
              math.sin(Curves.easeInOut.transform((t * 2) % 1) * math.pi).abs();

          return Stack(
            fit: StackFit.expand,
            children: [
              // The shadow does NOT bob: it is on the ground, and it tightens as
              // he leaves it, which is the whole of the depth in the figure.
              Align(
                // At his FEET, not at the bottom of his box. Derived from the
                // two fractions rather than typed, so it cannot go stale if
                // either moves: for a child of height fH inside a box of height
                // H, `Align` puts its centre at H/2 + a(H - fH)/2, and we want
                // that centre on the footline.
                alignment: _shadowAlignment,
                child: FractionallySizedBox(
                  widthFactor: 0.34 - rise / walkerHeight,
                  heightFactor: _shadowBand,
                  child: const _GroundShadow(),
                ),
              ),
              Transform.translate(
                offset: Offset(math.sin(t * 2 * math.pi) * _sway, -rise),
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
                    for (final svg in parts.behindHead) SvgArt(svg: svg),
                    CustomPaint(painter: _HeadPainter(skin: parts.skin)),
                    for (final svg in parts.overHead) SvgArt(svg: svg),
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
  static const double _hipY = 95;
  double _hipX(bool near) => near ? 60 : 56;

  void _leg(Canvas canvas, {required bool near}) {
    final legs = near ? kit : _shade(kit);
    final flesh = near ? skin : _shade(skin);
    final boot = near ? const Color(0xFF141414) : const Color(0xFF0B0B0B);
    final thigh = _sample(near ? _thighNear : _thighFar, t);
    final shin = _sample(near ? _shinNear : _shinFar, t);
    final ankle = _sample(near ? _ankleNear : _ankleFar, t);

    final x = _hipX(near);
    final hip = Offset(x, _hipY);
    final knee = Offset(x, _hipY + 30);
    final foot = Offset(x, _hipY + 54);

    // CAPSULES from the joint, not rectangles whose top edge happens to pass
    // through it. A rotated rectangle swings its own corners out of the socket,
    // which is what opened a wedge of background at the hip on every stride;
    // a round-capped stroke is a circle at the pivot however far it turns, so
    // the joint cannot come apart.
    _about(canvas, hip, thigh, () {
      canvas.drawLine(hip, knee, _limbPaint(legs, hip, knee, 10));
      _about(canvas, knee, shin, () {
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
    // Shorts a shade darker than the shirt: one flat block from collar to knee
    // read as a romper suit.
    const shorts = Rect.fromLTWH(50, 88, 16.5, 17);
    final shortsColour = Color.lerp(kit, Colors.black, 0.22)!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(shorts, const Radius.circular(4)),
      Paint()
        ..shader = ui.Gradient.linear(shorts.topLeft, shorts.bottomRight, [
          _lift(shortsColour, 0.1),
          Color.lerp(shortsColour, Colors.black, 0.2)!,
        ]),
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
