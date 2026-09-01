/// The keeper's-eye view: the posts, the bar, and the pitch running away.
///
/// **Goalkeeper Practice was a ball on a photograph.** The stage was the forest
/// backdrop with a football growing on top of it, and the growth was the only
/// thing in the frame that said where the camera was — so a drill that is
/// meant to be a keeper facing shots read as a target appearing on a picture
/// of some trees. Reported from the couch in as many words: it should look like
/// a view from the goalkeeper out, the posts and the pitch in front of us, and
/// then exactly what we do now.
///
/// **Exactly what we do now is the constraint, and it is why nothing here
/// moves.** The ball still appears where it appears and still grows in place;
/// this file only puts a place behind it. The drill's clock, its window jitter
/// and its bands are untouched.
///
/// **The JS could not be consulted for any of this** — `../merge-empire-fc` is
/// not cloned in a cloud container, and the training game's DOM scene is not in
/// this repo. So this is a port-side scene, in the same way the ball's growth
/// and its single face already were, and it is written against the port's own
/// `penalty_view.dart` rather than against a spec.
///
/// **It is NOT `penalty_view`'s ground, and that is a camera rather than a
/// duplication.** That scene's projection is anchored by constants which exist
/// to make a goal fill three quarters of the frame from the penalty spot —
/// `_cameraBack`, `_eyeZ`, `_focal`, and a horizon derived from the ball at
/// rest. This camera stands in the goal mouth looking the other way, where
/// there is no goal at any distance worth drawing and the box is the near thing
/// rather than the far one. What IS shared is shared: the turf colour, the
/// mown-band shades, and `backdropRectFor` — the placement that lands the
/// treeline on the seam instead of standing the art's own field up behind the
/// pitch.
///
/// **The frame is a wide lens on purpose, and the arithmetic says why.** A post
/// is 3.66m to the side of a keeper standing on his line, which is to say it is
/// beside him: at any focal length that keeps the penalty area in the picture
/// it projects several frame-widths off the edge, and a camera far enough back
/// to catch both posts is standing in the net looking at a goal, which is the
/// penalty scene. Broadcast keeper-cam solves this with a lens wide enough to
/// bend, and so does this: the posts and the bar are the FRAME of the picture,
/// held at fixed fractions of the stage, and the pitch is projected inside
/// them. Every line on the ground agrees with every other; the frame agrees
/// with the ball, which is the only thing it has to touch.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/ui/screens/minigames/penalty_view.dart'
    show backdropRectFor;
import 'package:merge_empire_fc/ui/widgets/art_image.dart';

/// The green both goal-scene drills stand on.
///
/// **There were two greens in the game and this would have been a third.** The
/// cutaway's `PitchBackdrop.turf` is a top-down pitch seen flat and lit flat;
/// the penalty scene is a camera on the grass and wanted a lighter one, which
/// it carried as a literal at its one call site. Goalkeeper Practice is the
/// other camera on the grass, so it is the penalty scene's green — named here
/// rather than typed twice, because two drills that are meant to be the same
/// stadium cannot be kept in step by hand.
const Color drillTurf = Color(0xFF3A8C41);

/// Where the pitch gives way to what is behind it, as a fraction of the stage.
///
/// The horizon is EYE LEVEL, so this is also how far down the camera looks:
/// above centre is a keeper watching the ball rather than the sky, and it
/// leaves the near half of the frame to the grass a shot is coming across.
const double keeperHorizon = 0.42;

/// How tall the window is against its width.
///
/// **A GOAL IS WIDER THAN IT IS TALL, and the frame is the goal.** The stage
/// was whatever height was left in the column — on a phone that is a portrait
/// box, so the posts ran down 700 points of a 384-point-wide picture and the
/// thing they framed was a doorway. Reported in one line: it is a soccer goal.
///
/// A real one is three to one. The frame cannot be that and still hold a ball
/// the thumb can hit, because the ball has to be about a third of the mouth's
/// height to be a 56-point target — so the mouth inside the window works out at
/// about 1.9, and what the window is NOT is taller than wide.
///
/// **But 1.85 was a slot, not a view.** One lens, fixed off the WIDTH, means
/// the goal is drawn the same size whatever height the window has — so the
/// height buys sky over the bar and grass in front of the line and nothing
/// else. At 1.85 there was barely any of either: a letterbox with a goal
/// wedged in it, and the ball arrived out of a strip. Reported from the couch
/// as wanting a lot more above and below even though the ball only ever goes
/// into the goal — it is the picture that is the point. The height it still
/// gives up goes back to the column, which centres it.
const double keeperStageAspect = 1.25;

/// Where the eye is above the turf, in metres. A keeper's, standing.
const double keeperEyeHeight = 1.75;

/// The focal length, IN PIXELS, and one number for both axes.
///
/// **This is what makes a goal a goal.** The scene used to scale sideways by
/// the frame's width and downward by its height, which is two different
/// lenses — anamorphic, in the film sense — so every shape in the picture was
/// stretched by whatever the stage's aspect happened to be. On a portrait
/// stage that stretch is vertical and large, and the goal frame is where it
/// showed: a 3:1 object came out taller than wide. One focal length in pixels
/// costs nothing and the whole scene is honest.
///
/// Pinned by the one marking that has to be WHOLLY in the picture: the penalty
/// area's front corners, 20.16m either side and 16.5m out, land at
/// [_boxAtEdge] of the way to the frame's edge. Everything nearer is
/// angularly wider and runs off the sides, which is what a keeper sees — the
/// six-yard box is a line across the grass with no corners in it.
double keeperFocal(Size view) =>
    0.5 * _boxAtEdge * view.width * boxDepth / boxHalfWidth;
const double _boxAtEdge = 0.96;

/// The pitch, in metres. FIFA's numbers, so the markings agree with each other.
const double sixYardDepth = 5.5;
const double sixYardHalfWidth = 9.16;
const double boxDepth = 16.5;
const double boxHalfWidth = 20.16;
const double spotDepth = 11;
const double arcRadius = 9.15;
const double halfwayDepth = 52.5;
const double touchlineHalfWidth = 34;

/// The far goal line: a full pitch away, and where this one ends.
const double farGoalDepth = halfwayDepth * 2;

/// How far out the mown bands are still drawn. Past this they are inside a
/// pixel of each other, so it is where they stop rather than a place on the
/// pitch — they run over the far line because a mower does not stop at it.
const double _bandDepth = 400;

/// The nearest ground the frame holds, in metres out from the goal line.
///
/// **Derived, not chosen.** Once the lens and the horizon are fixed there is
/// only one depth the bottom edge can be, and picking a second number for it
/// would put the near grass at one perspective and everything else at another.
double keeperNearDepth(Size view) =>
    keeperFocal(view) * keeperEyeHeight / ((1 - keeperHorizon) * view.height);

/// Where a point [lateral] metres to the side and [up] metres off the turf, at
/// [depth] metres out from the goal line, lands on the stage.
///
/// Pure, so the scene's arithmetic can be pinned without a screen — the habit
/// every other non-obvious number in this port is held to.
Offset keeperProject(
  double lateral,
  double up,
  double depth,
  Size view, {
  bool clampNear = true,
}) {
  final f = keeperFocal(view);
  final d = clampNear ? math.max(depth, keeperNearDepth(view)) : depth;
  return Offset(
    view.width / 2 + f * lateral / d,
    keeperHorizon * view.height + f * (keeperEyeHeight - up) / d,
  );
}

/// The turf at [depth], which is the common case.
Offset keeperGround(double depth, Size view) =>
    keeperProject(0, 0, depth, view);

/// The goal frame. See the note on the wide lens for why it is not projected.
///
/// **All four are fractions of the WIDTH, the bar included.** A post and a bar
/// are the same piece of aluminium, and sizing one off the width and the other
/// off the height made the bar thinner than the posts by whatever the stage's
/// aspect was — the same anamorphic fault as the lens, in the one place the eye
/// checks it.
const double keeperPostInset = 0.018;
const double keeperPostWidth = 0.030;
const double keeperBarThick = 0.030;

/// How far the bar hangs below the top edge, as a fraction of the width.
///
/// **There has to be something ABOVE the bar.** At 0.02 the bar was the top
/// edge of the picture: a taller window bought grass at the bottom and no sky
/// at all, and the goal read as a slot the ball came out of rather than a goal
/// with a stand behind it. This drops it clear of the rim — the bar still sits
/// above the horizon, which is where a bar 2.44m up belongs seen from a
/// keeper's eye.
const double keeperBarDrop = 0.09;

/// Where the bar's underside sits, as a fraction of the WIDTH: the ceiling a
/// drill must stay under.
const double keeperBarBottom = keeperBarDrop + keeperBarThick;

/// Where the inside of each post is, as a fraction of the width: what a drill
/// must stay between.
const double keeperMouthLeft = keeperPostInset + keeperPostWidth;
const double keeperMouthRight = 1 - keeperPostInset - keeperPostWidth;

/// The scene: backdrop, pitch, frame. Nothing in it moves.
class KeeperView extends StatelessWidget {
  const KeeperView({super.key, this.turf = drillTurf});

  final Color turf;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final view = Size(box.maxWidth, box.maxHeight);
      return Stack(
        children: [
          // **PLACED, not fitted** — see `backdropRectFor`. Fitted, the art's
          // own field stands up behind the pitch at a different perspective,
          // which is the hill the penalty screen was reported for.
          Positioned.fromRect(
            rect: backdropRectFor(keeperHorizon * view.height, view),
            child: ArtImage(
              key: const ValueKey('train-backdrop'),
              path: backdropPath(Backdrop.forest),
              fit: BoxFit.fill,
              fallback: const SizedBox.shrink(),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: KeeperViewPainter(turf: turf)),
          ),
        ],
      );
    },
  );
}

class KeeperViewPainter extends CustomPainter {
  const KeeperViewPainter({required this.turf});

  final Color turf;

  Offset _at(Size size, double lateral, double depth) =>
      keeperProject(lateral, 0, depth, size);

  @override
  void paint(Canvas canvas, Size size) {
    final ground = Rect.fromLTRB(
      0,
      keeperHorizon * size.height,
      size.width,
      size.height,
    );
    canvas.save();
    // Clipped, because a band or a chalk line laid past the far end projects
    // ABOVE the horizon — grass in the sky, over the treeline.
    canvas.clipRect(ground);
    _paintTurf(canvas, ground);
    _paintBands(canvas, size);
    _paintSurround(canvas, size);
    _paintLines(canvas, size);
    canvas.restore();
    _paintFrame(canvas, size);
  }

  /// Dark at the horizon, lit at your feet — the same three stops the penalty
  /// scene's ground uses, because it is the same grass under the same sky.
  void _paintTurf(Canvas canvas, Rect ground) {
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
  }

  /// Mown bands, 5m wide, running away from the camera.
  ///
  /// **The cheapest depth cue there is, and here it is the only one that
  /// works.** Every marking on this pitch except the box's two side lines is a
  /// line of constant depth, and a line of constant depth projects HORIZONTAL —
  /// so a scene drawn from the markings alone is a stack of parallel bars with
  /// no vanishing point in it. The bands are the lines that converge.
  ///
  /// Both shades, and every band: one wash on alternate bands is a single faint
  /// edge rather than a pattern, which is the note the penalty scene's ground
  /// carries after the same thing was reported from the couch.
  void _paintBands(Canvas canvas, Size size) {
    final light = Paint()..color = Colors.white.withValues(alpha: 0.10);
    final dark = Paint()..color = Colors.black.withValues(alpha: 0.07);
    // Wide enough to reach the frame's edge at every depth the box is drawn
    // at; past that they have converged to within a pixel of each other.
    for (var i = -8; i < 8; i++) {
      final near = _at(size, i * 5.0, keeperNearDepth(size));
      final nearOut = _at(size, (i + 1) * 5.0, keeperNearDepth(size));
      final far = _at(size, i * 5.0, _bandDepth);
      final farOut = _at(size, (i + 1) * 5.0, _bandDepth);
      canvas.drawPath(
        Path()
          ..moveTo(near.dx, near.dy)
          ..lineTo(nearOut.dx, nearOut.dy)
          ..lineTo(farOut.dx, farOut.dy)
          ..lineTo(far.dx, far.dy)
          ..close(),
        i.isEven ? light : dark,
      );
    }
  }

  /// What is OUTSIDE the touchlines.
  ///
  /// **The pitch and the not-pitch being the same green is what makes a pitch
  /// look missing** — the cutaway's own note, learned there and true here. It
  /// is a sliver in each top corner, because a touchline only enters the frame
  /// twenty-seven metres out, and without it the grass runs to the treeline in
  /// every direction and the horizon reads as a crop rather than as the far end
  /// of a pitch.
  void _paintSurround(Canvas canvas, Size size) {
    final ground = Rect.fromLTRB(
      0,
      keeperHorizon * size.height,
      size.width,
      size.height,
    );
    // The pitch itself, and everything else on the ground is not it. Cut rather
    // than drawn as corner wedges, so the touchlines and the far goal line land
    // exactly on the seam instead of near it — the three of them are the same
    // four corners read twice.
    final a = _at(size, -touchlineHalfWidth, keeperNearDepth(size));
    final b = _at(size, touchlineHalfWidth, keeperNearDepth(size));
    final c = _at(size, touchlineHalfWidth, farGoalDepth);
    final d = _at(size, -touchlineHalfWidth, farGoalDepth);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(ground),
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(c.dx, c.dy)
          ..lineTo(d.dx, d.dy)
          ..close(),
      ),
      Paint()..color = Color.lerp(turf, Colors.black, 0.44)!,
    );
  }

  /// The chalk. Every line of it projected, so all of it agrees about where the
  /// camera is.
  void _paintLines(Canvas canvas, Size size) {
    // Thicker close up: a six-yard line and a halfway line drawn at one width
    // is the one place the eye notices chalk has no perspective in it.
    Paint chalk(double depth) => Paint()
      ..color = Colors.white.withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (5 * keeperNearDepth(size) / depth).clamp(1, 3.2)
      ..strokeCap = StrokeCap.square;

    void across(double depth, double halfWidth) => canvas.drawLine(
      _at(size, -halfWidth, depth),
      _at(size, halfWidth, depth),
      chalk(depth),
    );
    void away(double lateral, double from, double to) => canvas.drawLine(
      _at(size, lateral, from),
      _at(size, lateral, to),
      chalk(to),
    );

    // The far half first, so the near chalk is drawn over it. The touchlines
    // run the whole pitch; the stretch of them nearer than about twenty-seven
    // metres is wider than the frame and clipped away, which is the point —
    // they ENTER the picture from its sides and converge, and that convergence
    // is what makes the seam a horizon.
    for (final side in [-1.0, 1.0]) {
      away(side * touchlineHalfWidth, keeperNearDepth(size), farGoalDepth);
    }
    across(farGoalDepth, touchlineHalfWidth);
    across(halfwayDepth, touchlineHalfWidth);

    across(boxDepth, boxHalfWidth);
    for (final side in [-1.0, 1.0]) {
      away(side * boxHalfWidth, keeperNearDepth(size), boxDepth);
    }

    // The D: the part of the ten-yard arc round the spot that falls outside the
    // box, which is the only part that is chalked.
    final half = math.acos((boxDepth - spotDepth) / arcRadius);
    final arc = Path();
    for (var i = 0; i <= 24; i++) {
      final a = -half + 2 * half * i / 24;
      final p = _at(
        size,
        arcRadius * math.sin(a),
        spotDepth + arcRadius * math.cos(a),
      );
      i == 0 ? arc.moveTo(p.dx, p.dy) : arc.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(arc, chalk(boxDepth));

    across(sixYardDepth, sixYardHalfWidth);
    for (final side in [-1.0, 1.0]) {
      away(side * sixYardHalfWidth, keeperNearDepth(size), sixYardDepth);
    }

    // The spot, flattened by the ground plane it is lying on.
    final spot = _at(size, 0, spotDepth);
    final r = keeperFocal(size) * 0.22 / spotDepth;
    canvas.drawOval(
      Rect.fromCenter(center: spot, width: r * 2, height: r * 0.8),
      Paint()..color = Colors.white.withValues(alpha: 0.62),
    );
  }

  /// The posts and the bar, held at the frame's edges. See the note on the wide
  /// lens for why they are not projected with everything else.
  void _paintFrame(Canvas canvas, Size size) {
    // Every one off the WIDTH, so a post and the bar are the same aluminium
    // whatever shape the stage is.
    final postW = keeperPostWidth * size.width;
    final left = keeperPostInset * size.width;
    final right = size.width - keeperPostInset * size.width - postW;
    final barTop = keeperBarDrop * size.width;
    final barH = keeperBarThick * size.width;
    final radius = Radius.circular(postW * 0.34);

    // A post standing ON the grass rather than printed over it: the shadow it
    // throws inward is the whole of the depth in this half of the picture.
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    // Inward, both sides: a post at the right-hand edge throwing its shadow
    // further right throws it off the picture, and the pair stop being a pair.
    void bar(Rect rect, {required double lean}) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.shift(Offset(lean, 3)), radius),
        shadow,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..shader =
              LinearGradient(
                begin: lean == 0 ? Alignment.topCenter : Alignment.centerLeft,
                end: lean == 0 ? Alignment.bottomCenter : Alignment.centerRight,
                colors: const [
                  Color(0xFFB9C0BA),
                  Color(0xFFF7F9F5),
                  Color(0xFFC6CDC6),
                ],
                stops: const [0, 0.38, 1],
              ).createShader(rect),
      );
    }

    bar(Rect.fromLTWH(left, barTop, postW, size.height - barTop), lean: 3);
    bar(Rect.fromLTWH(right, barTop, postW, size.height - barTop), lean: -3);
    bar(Rect.fromLTWH(left, barTop, right + postW - left, barH), lean: 0);
  }

  @override
  bool shouldRepaint(KeeperViewPainter old) => old.turf != turf;
}
