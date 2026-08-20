/// What the manager is DRAWN as. The rig — what turns, and when — stays in
/// `manager_walker.dart`; this is only the form hung on it.
///
/// **The motion was never the problem.** The legs are solved from the foot's
/// path, the ground speed falls out of the stride, the tempo tracks his mood and
/// sixteen gestures pose over the top of all of it. What let the figure down was
/// that every part of him was a PRIMITIVE: limbs were round-capped lines of
/// constant width, the torso a 15×32 rounded rectangle, the boot another
/// rectangle, the head a circle with an ellipse for a jaw. Constant-width
/// sausages on a rounded brick is programmer art however well it walks.
///
/// So every part is a SHAPE now:
///
/// - **Limbs taper.** A thigh is thick at the hip and narrow at the knee, a calf
///   swells and tucks into the ankle. That single change is most of the
///   difference, because a limb of constant width reads as a tube and a tube has
///   no anatomy.
/// - **The torso has shoulders and a waist.** Widest across the deltoids, tucked
///   at the ribs, out again at the hips — a silhouette rather than a box, so the
///   figure has a build before the shading gets a say.
/// - **The boot has a heel, a sole and a toe** instead of a corner radius.
/// - **Every surface is lit from the same corner** and carries a highlight down
///   its leading edge, because he faces +x and the sky is up-left. A flat fill
///   is the other half of why a rig reads as a diagram.
///
/// **Nothing here moves a pivot.** The shoulder is still (56, 62), the elbow
/// (56, 80), the hips (58±2, 95), the skull a circle at (62, 48.5) r12.5 — the
/// gesture poses rotate about those and the generated hair, hats and outfits in
/// `manager_art.g.dart` are all drawn against them. A prettier figure that moved
/// any of them would put a hat on his ear.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// He faces +x. Every highlight is on that side and every core shadow behind it.
const double facing = 1;

Color lift(Color c, double amount) => Color.lerp(c, Colors.white, amount)!;
Color deepen(Color c, double amount) => Color.lerp(c, Colors.black, amount)!;

/// A limb as a TAPERED capsule: [wFrom] wide at [from], [wTo] at [to], with a
/// semicircular cap at each joint.
///
/// The caps matter as much as the taper. A rotated rectangle swings its own
/// corners out of the socket, which is what opened a wedge of background at the
/// hip on every stride; a round end is a circle at the pivot however far the
/// joint turns, so it cannot come apart.
Path taperedLimb(Offset from, Offset to, double wFrom, double wTo) {
  final axis = to - from;
  final len = axis.distance;
  if (len < 0.01) {
    return Path()..addOval(Rect.fromCircle(center: from, radius: wFrom / 2));
  }
  final dir = axis / len;
  // The limb's own left, which is a quarter turn from its axis.
  final side = Offset(-dir.dy, dir.dx);
  // Two sides and two caps: the arcs sweep from one side's end round to the
  // other, so the far corners never need naming.
  final a = from + side * (wFrom / 2);
  final b = to + side * (wTo / 2);
  final d = from - side * (wFrom / 2);
  final angle = math.atan2(dir.dy, dir.dx);
  return Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy)
    ..arcTo(
      Rect.fromCircle(center: to, radius: wTo / 2),
      angle + math.pi / 2,
      -math.pi,
      false,
    )
    ..lineTo(d.dx, d.dy)
    ..arcTo(
      Rect.fromCircle(center: from, radius: wFrom / 2),
      angle - math.pi / 2,
      -math.pi,
      false,
    )
    ..close();
}

/// Fill a limb so it reads as round.
///
/// Three things, in the order they matter: a gradient ACROSS the limb rather than
/// along it, so the near edge is lit and the far edge falls into shade; a
/// highlight streak a third of the way in from the leading edge, which is what
/// actually says "cylinder"; and a shadow at the top joint, because a limb that
/// meets the body with no occlusion under it reads as glued on.
void paintLimb(
  Canvas canvas,
  Offset from,
  Offset to,
  double wFrom,
  double wTo, {
  required Color base,
  bool far = false,
  bool occlude = true,
}) {
  final limb = taperedLimb(from, to, wFrom, wTo);
  final axis = to - from;
  final len = axis.distance;
  if (len < 0.01) return;
  final dir = axis / len;
  final side = Offset(-dir.dy, dir.dx);
  // Which way is "the lit side" in the limb's own frame: the one that faces +x.
  final litSign = side.dx * facing >= 0 ? 1.0 : -1.0;
  final mid = from + axis / 2;
  final half = (wFrom + wTo) / 4;

  final body = far ? deepen(base, 0.26) : base;
  canvas.drawPath(
    limb,
    Paint()
      ..shader = ui.Gradient.linear(
        mid - side * litSign * half,
        mid + side * litSign * half,
        [deepen(body, 0.34), body, lift(body, far ? 0.10 : 0.20)],
        const [0, 0.55, 1],
      ),
  );

  canvas.save();
  canvas.clipPath(limb);
  // The highlight, inset from the edge rather than on it: a specular ON the
  // outline reads as a stroke, and a stroke reads as a cartoon.
  final inset = side * litSign * half * 0.42;
  canvas.drawPath(
    taperedLimb(from + inset, to + inset, wFrom * 0.30, wTo * 0.30),
    Paint()
      ..color = Colors.white.withValues(alpha: far ? 0.06 : 0.13)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
  );
  if (occlude) {
    canvas.drawCircle(
      from,
      wFrom * 0.62,
      Paint()
        ..shader = ui.Gradient.radial(
          from,
          wFrom * 0.62,
          [
            Colors.black.withValues(alpha: 0.22),
            Colors.black.withValues(alpha: 0),
          ],
          const [0.35, 1],
        ),
    );
  }
  canvas.restore();
}

/// The torso, from the base of the neck to the waistband.
///
/// **The width is not a choice — the generated art already states it.** Every
/// outfit overlay in `manager_art.g.dart` is a full garment silhouette running
/// x 47.8 to 69.9, so the coat and the suit have always drawn a body 22 units
/// across. The hand-drawn shirt under them was 15.7, which is why he read as a
/// stick in the plain kit and as a person the moment you put a coat on him. This
/// matches the art rather than guessing at a build.
///
/// Widest across the deltoids, tucked at the ribs, out again at the hips. He
/// faces +x, so the chest is the high-x side and the shoulder blades the low one.
///
/// [build] scales it about the centre line, so the customiser's build axis has
/// something to act on: 1 is regular.
Path torsoPath({double build = 1}) {
  const centre = 58.0;
  const neckY = 57.0;
  const hemY = 91.0;
  double x(double from) => centre + (from - centre) * build;

  return Path()
    // Out of the neck and over the front deltoid, which is the widest point.
    ..moveTo(x(61.4), neckY)
    ..quadraticBezierTo(x(68.2), neckY + 1.6, x(69.4), neckY + 7)
    // Chest, and the swell of it.
    ..quadraticBezierTo(x(70.2), neckY + 14, x(68.4), neckY + 21)
    // The tuck at the ribs — the waist is the narrowest part of him.
    ..quadraticBezierTo(x(67.2), neckY + 27, x(68.0), hemY)
    // Across the waistband.
    ..lineTo(x(48.4), hemY)
    // Back up the spine side: waist, then the lats flaring to the shoulder.
    ..quadraticBezierTo(x(49.0), neckY + 27, x(47.9), neckY + 20)
    ..quadraticBezierTo(x(46.6), neckY + 13, x(48.0), neckY + 6.5)
    ..quadraticBezierTo(x(49.2), neckY + 1.4, x(54.8), neckY)
    ..close();
}

/// A shirt, with the light on the chest and the spine in shade.
void paintTorso(Canvas canvas, Color kit, {double build = 1}) {
  final path = torsoPath(build: build);
  final bounds = path.getBounds();
  canvas.drawPath(
    path,
    Paint()
      ..shader = ui.Gradient.linear(
        bounds.centerLeft,
        bounds.centerRight,
        [deepen(kit, 0.34), deepen(kit, 0.06), kit, lift(kit, 0.16)],
        const [0, 0.34, 0.72, 1],
      ),
  );

  canvas.save();
  canvas.clipPath(path);
  // The hollow under the collar, which is what gives the chest a top.
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(58.4, 62.5), width: 13, height: 7.5),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.13)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
  );
  // And a soft shadow where the shirt tucks in, so the hem is worn rather than
  // printed on.
  canvas.drawRect(
    const Rect.fromLTWH(46, 85, 26, 6.5),
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 84.5),
        const Offset(0, 90.5),
        [
          Colors.black.withValues(alpha: 0),
          Colors.black.withValues(alpha: 0.2),
        ],
      ),
  );
  canvas.restore();

  // A collar that sits ON the shoulders rather than being a line across them.
  canvas.drawPath(
    Path()
      ..moveTo(53.6, 57.8)
      ..quadraticBezierTo(58.6, 65.2, 63.4, 57.4),
    Paint()
      ..color = deepen(kit, 0.36)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round,
  );
}

/// The neck. Drawn before the torso and the head, so both overlap it.
///
/// It did not exist: the skull sat straight on the shirt, which is the other
/// reason the head read as stuck on.
void paintNeck(Canvas canvas, Color skin) {
  paintLimb(
    canvas,
    const Offset(59.4, 62),
    const Offset(60.2, 54),
    9.2,
    8,
    base: deepen(skin, 0.10),
    occlude: false,
  );
}

/// A boot: heel, sole and toe, measured forward from the ankle.
///
/// The rectangle it replaces ran from 3.5 behind the ankle to 11.5 in front of
/// it, and the footline arithmetic is derived from exactly those numbers — see
/// `_bootToe` / `_bootHeel` / `_bootSole` — so the shape changes and the extents
/// do not.
Path bootPath(
  Offset ankle, {
  double toe = 11.5,
  double heel = 3.5,
  double sole = 3.5,
}) {
  final x0 = ankle.dx - heel;
  final x1 = ankle.dx + toe;
  final top = ankle.dy - 2.2;
  final ground = ankle.dy + sole;
  return Path()
    // Up the back of the heel.
    ..moveTo(x0 + 0.6, ground)
    ..quadraticBezierTo(x0 - 0.4, ground - 1.6, x0 + 0.4, top + 0.6)
    // Over the laces, which is where the boot is highest.
    ..quadraticBezierTo(ankle.dx + 1.2, top - 1.4, ankle.dx + 4.6, top + 0.8)
    // Along the top of the foot and down to the toe.
    ..quadraticBezierTo(x1 - 2.4, top + 1.6, x1 - 0.4, ground - 2.2)
    // The toe's round, then the sole back to the heel.
    ..quadraticBezierTo(x1 + 0.5, ground, x1 - 2.2, ground)
    ..lineTo(x0 + 0.6, ground)
    ..close();
}

void paintBoot(Canvas canvas, Offset ankle, Color boot) {
  final path = bootPath(ankle);
  final bounds = path.getBounds();
  canvas.drawPath(
    path,
    Paint()
      ..shader = ui.Gradient.linear(
        bounds.topCenter,
        bounds.bottomCenter,
        [lift(boot, 0.26), boot, deepen(boot, 0.4)],
        const [0, 0.5, 1],
      ),
  );
  canvas.save();
  canvas.clipPath(path);
  // The sole, as a band rather than an outline — studs at this size are a
  // texture, not a feature.
  canvas.drawRect(
    Rect.fromLTWH(bounds.left, bounds.bottom - 1.5, bounds.width, 1.5),
    Paint()..color = lift(boot, 0.18),
  );
  canvas.restore();
}

/// A hand: a mitten, wider across the knuckles than at the wrist.
void paintHand(Canvas canvas, Offset at, Color skin, {bool far = false}) {
  final flesh = far ? deepen(skin, 0.26) : skin;
  canvas.drawPath(
    Path()..addOval(Rect.fromCenter(center: at, width: 7.4, height: 6.4)),
    Paint()
      ..shader = ui.Gradient.radial(
        at.translate(-1, -1.4),
        4.6,
        [lift(flesh, 0.16), flesh, deepen(flesh, 0.24)],
        const [0, 0.55, 1],
      ),
  );
}
