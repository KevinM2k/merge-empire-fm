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
import 'package:merge_empire_fc/engine/penalty_physics.dart';

/// Where the camera sits: behind and above the spot, looking at the goal.
///
/// **Solved rather than guessed, because the two shots fight each other.** The
/// ball at rest is a few metres from the lens and the goal is twenty-odd, so a
/// lens wide enough to fill the frame with the goal throws the ball off the
/// bottom of it — which is exactly what the first set of numbers did.
///
/// Two constraints pin all four values: the goal has to be about three quarters
/// of the width, and the ball at the spot has to sit near the bottom of the frame
/// rather than under it. Writing both out and solving gives a camera 10m behind
/// the spot at 2.6m — a cameraman standing behind the taker, which is where the
/// shot comes from on television — and a horizon near the top, because a 2.6m
/// camera twenty-one metres from a 2.44m crossbar genuinely does see the bar just
/// below eye level.
///
/// Move any of them and the other three have to be re-solved. They are not taste.
const double _eyeY = -spotDistance - 10;
const double _eyeZ = 2.62;

/// Focal length, as a fraction of the view's width.
const double _focal = 2.15;

/// Where eye level lands, as a fraction of the height.
const double _horizon = 0.094;

/// The projection.
///
/// Returns null for anything behind the camera — a ball that has flown past the
/// lens has no screen position, and projecting it anyway puts it on the opposite
/// side of the frame at enormous size.
Offset? project(Vec3 point, Size view) {
  final depth = point.y - _eyeY;
  if (depth < 0.4) return null;
  final f = _focal * view.width;
  return Offset(
    view.width / 2 + f * point.x / depth,
    view.height * _horizon - f * (point.z - _eyeZ) / depth,
  );
}

/// How big something of [size] metres appears at [y].
double scaleAt(double y, Size view, double size) {
  final depth = y - _eyeY;
  if (depth < 0.4) return 0;
  return _focal * view.width * size / depth;
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
  });

  final Vec3 ball;
  final bool ballVisible;
  final double roll;
  final KeeperPose keeper;
  final NetMesh net;

  /// The line the player is currently dragging, in screen space, or null.
  final ({Offset from, Offset to, Offset control})? aimPreview;
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
    // Sky, then turf from the horizon down.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6DB3E8), Color(0xFFB9DCF2)],
        ).createShader(Offset.zero & size),
    );
    final horizonY = size.height * _horizon;
    final ground = Rect.fromLTRB(0, horizonY - 1, size.width, size.height);
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
    final band = Paint()..color = Colors.white.withValues(alpha: 0.05);
    for (var i = -6; i <= 6; i += 2) {
      final quad = _quad(
        size,
        Vec3(-30, -spotDistance - 12 + i * 5, 0),
        Vec3(30, -spotDistance - 12 + i * 5, 0),
        Vec3(30, -spotDistance - 12 + (i + 1) * 5, 0),
        Vec3(-30, -spotDistance - 12 + (i + 1) * 5, 0),
      );
      if (quad != null) canvas.drawPath(quad, band);
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
    final cord = Paint()
      ..color = Colors.white.withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    // The sheet behind it, so the goalmouth reads as a hole rather than as a
    // grid floating on the grass.
    final back = Path();
    for (var c = 0; c <= mesh.columns; c++) {
      final p = project(mesh.vertex(c, 0), size);
      if (p == null) continue;
      c == 0 ? back.moveTo(p.dx, p.dy) : back.lineTo(p.dx, p.dy);
    }
    for (var c = mesh.columns; c >= 0; c--) {
      final p = project(mesh.vertex(c, mesh.rows), size);
      if (p != null) back.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      back..close(),
      Paint()..color = const Color(0xFF16311B).withValues(alpha: 0.55),
    );

    for (var r = 0; r <= mesh.rows; r++) {
      final path = Path();
      var started = false;
      for (var c = 0; c <= mesh.columns; c++) {
        final p = project(mesh.vertex(c, r), size);
        if (p == null) continue;
        started ? path.lineTo(p.dx, p.dy) : path.moveTo(p.dx, p.dy);
        started = true;
      }
      canvas.drawPath(path, cord);
    }
    for (var c = 0; c <= mesh.columns; c++) {
      final path = Path();
      var started = false;
      for (var r = 0; r <= mesh.rows; r++) {
        final p = project(mesh.vertex(c, r), size);
        if (p == null) continue;
        started ? path.lineTo(p.dx, p.dy) : path.moveTo(p.dx, p.dy);
        started = true;
      }
      canvas.drawPath(path, cord);
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
    final pose = frame.keeper;
    // He stands ON the line, a little in front of the net.
    final standing = Vec3(pose.hand.x * 0.42, -0.25, 0);
    final feet = project(standing, size);
    if (feet == null) return;
    final unit = scaleAt(standing.y, size, 1);
    if (unit <= 0) return;

    const shirtColour = Color(0xFFFFC63D);
    const shortsColour = Color(0xFF23303F);
    const gloveColour = Color(0xFF1F2A37);
    const skin = Color(0xFFE8B78E);

    // How far over he is: a full dive lays him flat, and which way follows the
    // side he went.
    final lean = pose.dive * 1.15 * (pose.side.isNegative ? -1 : 1);

    canvas.save();
    canvas.translate(feet.dx, feet.dy);
    canvas.rotate(lean);

    final hip = -unit * 0.88;
    final shoulder = -unit * 1.52;
    final head = -unit * 1.74;

    Paint limb(Color c, double w) => Paint()
      ..color = c
      ..strokeWidth = unit * w
      ..strokeCap = StrokeCap.round;

    // Legs. They SPLIT with the dive — a keeper at full stretch has one leg
    // trailing, and two parallel lines read as a man standing to attention.
    final split = unit * (0.10 + pose.dive * 0.34);
    canvas.drawLine(
      Offset(-split, 0),
      Offset(-unit * 0.06, hip),
      limb(shortsColour, 0.17),
    );
    canvas.drawLine(
      Offset(split, 0),
      Offset(unit * 0.06, hip),
      limb(shortsColour, 0.17),
    );
    // Torso.
    canvas.drawLine(
      Offset(0, hip),
      Offset(0, shoulder),
      limb(shirtColour, 0.30),
    );
    // Both arms UP and out, which is what a keeper does with them.
    //
    // SYMMETRIC at rest and asymmetric in the dive: standing, the two go out
    // equally, which is a keeper set; diving, the leading one extends and the
    // trailing one tucks, which is where the reach visibly is. Signed off the
    // side he went, and only once he has gone — at `side == 0` there is no lead
    // arm, and picking one made him look like he was holding something.
    final way = pose.side.abs() < 0.05 ? 0.0 : (pose.side < 0 ? -1.0 : 1.0);
    final spread = unit * 0.40;
    final leadX = spread + unit * pose.dive * 0.95;
    final trailX = spread * (1 - pose.dive * 0.55);
    for (final (x, w) in [
      (way == 0 ? spread : leadX * way, 0.14),
      (way == 0 ? -spread : -trailX * way, 0.13),
    ]) {
      canvas.drawLine(
        Offset(0, shoulder),
        Offset(x, shoulder - unit * 0.22),
        limb(shirtColour, w),
      );
      canvas.drawCircle(
        Offset(x, shoulder - unit * 0.22),
        unit * 0.10,
        Paint()..color = gloveColour,
      );
    }
    // Head, and a face — two dots and the eye line are enough at this size, and
    // without them he is a ball on a stick.
    canvas.drawCircle(Offset(0, head), unit * 0.13, Paint()..color = skin);
    final eye = Paint()..color = const Color(0xFF20262E);
    canvas.drawCircle(Offset(-unit * 0.045, head), unit * 0.02, eye);
    canvas.drawCircle(Offset(unit * 0.045, head), unit * 0.02, eye);
    // A shirt number, so he is wearing a kit rather than a colour.
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
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
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
    required this.onResult,
    required this.turf,
    this.rng,
  });

  /// The division's own ramp — how often the keeper goes the right way.
  final double readChance;

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
    final live = _kick != null || _hold > 0 || _net.moving;
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
      );
      _dragFrom = null;
      _dragTo = null;
      _dragMid = null;
    });
    _wake();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final view = Size(constraints.maxWidth, constraints.maxHeight);
      final kick = _kick;
      final ball = kick?.position ?? _spot;
      final hand = kick?.keeperHand ?? Vec3(0, -0.3, 0.9);
      final dive = kick == null
          ? 0.0
          : ((kick.elapsed - kick.plan.commitAt) / keeperDiveTime).clamp(
              0.0,
              1.0,
            );

      final from = _dragFrom;
      final to = _dragTo;
      final mid = _dragMid;
      return GestureDetector(
        key: const ValueKey('penalty-swipe'),
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => setState(() {
          _dragFrom = d.localPosition;
          _dragTo = d.localPosition;
          _dragMid = null;
        }),
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
        child: CustomPaint(
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
              aimPreview: from == null || to == null || (from - to).distance < 8
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
