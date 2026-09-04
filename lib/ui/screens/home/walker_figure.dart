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
  bool soft = true,
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
      ..maskFilter = soft ? const MaskFilter.blur(BlurStyle.normal, 1.4) : null,
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

/// **THE ARM, AS A CHAIN.** The three points every gesture pose is written
/// against, in the art's own space.
///
/// They were five literals scattered through `_arm` — `Offset(56, 62)` twice,
/// `Offset(56, 80)`, `Offset(56, 81)`, `Offset(56, 98.5)`, `Offset(56, 100.6)`
/// — which is fine for a painter and no use at all to anything that has to
/// REASON about where a hand ends up. A pose is a place a hand goes (see
/// `handsonhips`), and three of the sixteen were putting hands inside his own
/// skull; naming the chain is what lets a test say so instead of a playthrough.
const Offset armShoulder = Offset(56, 62);

/// The elbow, which the forearm turns about.
const Offset armElbow = Offset(56, 80);

/// The hand's centre, at rest. The arm reaches mid-thigh.
const Offset armHand = Offset(56, 100.6);

/// The hand's oval, as [paintHand] draws it.
const Size handSize = Size(7.4, 6.4);

/// **WHAT AN OUTFIT IS.** Ported from `.ps-vec[data-outfit="…"]` in
/// `../merge-empire-fc/src/ui/styles/league-scene.css`.
///
/// **An outfit is mostly a PALETTE, and the port had none.** The JS paints every
/// garment from a semantic variable — the forearm, the shin, the boot, the
/// waistband — and swaps the palette per outfit, keeping geometry for only the
/// two pieces a colour cannot express: a coat's skirt and a suit's lapels. Those
/// two are in `manager_art.g.dart` and drew fine; the tracksuit's entire
/// existence is the palette, so all that reached the screen was its collar
/// swoosh — a curve across his throat, reported exactly as "something like a
/// necklace".
///
/// Null means "leave it as it is": the kit's forearms and shins are BARE, and
/// that is the zero point everything else is measured against.
typedef ManagerOutfit = ({
  /// The body of the garment AND the upper arms — the CSS's `--top`, whose own
  /// comment names both: "shirt, jacket or training-top body + upper arms".
  ///
  /// **Null is the club's colour**, which is the kit's zero point and the
  /// tracksuit's whole point. A coat and a suit override it, and until they did
  /// the port painted a charcoal overcoat with green shoulders and a green
  /// crescent of shirt above its collar — the torso and the bicep were the two
  /// pieces still reading `--kit` directly.
  Color? top,

  /// The sleeve below the elbow. Null is bare arms.
  Color? fore,

  /// Below the knee. Null is bare legs.
  Color? shin,

  /// The waistband and the shorts. Null keeps the kit's own dark.
  Color? legs,

  Color boot,

  /// A stripe down the outside of the leg, or none.
  Color? legStripe,
});

/// The four, in the CSS's own colours. **`outfitPalettes`, not `managerOutfits`**
/// — that name is the generated ART map in `manager_art.g.dart`, which holds the
/// coat's skirt and the suit's lapels. Palette and geometry are two halves of
/// one outfit and they are keyed the same way.
const Map<String, ManagerOutfit> outfitPalettes = {
  // The playing kit: bare arms, bare shins, black boots. The zero point.
  'kit': (
    top: null,
    fore: null,
    shin: null,
    legs: null,
    boot: Color(0xFF141414),
    legStripe: null,
  ),
  // **The only outfit that keeps the club's colour on the body**, so he still
  // reads as club staff: a club-coloured training top with LONG sleeves — which
  // is why the forearm takes the kit's own paint rather than skin — over dark
  // bottoms with a side stripe, and white trainers.
  'tracksuit': (
    top: null, // the club's, and the reason this outfit exists
    fore: null, // the kit colour, resolved by the painter
    shin: Color(0xFF2C313A),
    legs: Color(0xFF2C313A),
    boot: Color(0xFFEDEDED),
    legStripe: Color(0x80FFFFFF),
  ),
  // The wet-Tuesday-night touchline look. Deliberately drab — the only colour
  // on it is the club scarf at the throat, which the overlay draws.
  'coat': (
    top: Color(0xFF2A3140),
    fore: Color(0xFF2A3140),
    shin: Color(0xFF23262C),
    legs: Color(0xFF23262C),
    boot: Color(0xFF14161A),
    legStripe: null,
  ),
  // Charcoal jacket, and trousers to the shoe.
  'suit': (
    top: Color(0xFF333846),
    fore: Color(0xFF333846),
    shin: Color(0xFF333846),
    legs: Color(0xFF333846),
    boot: Color(0xFF1B1512),
    legStripe: null,
  ),
};

ManagerOutfit outfitPalette(String? id) =>
    outfitPalettes[id] ?? outfitPalettes['kit']!;

/// Whether this outfit's sleeves reach the wrist in the CLUB's colour.
///
/// The tracksuit is the one that does, and it is why its `fore` is null rather
/// than a colour: the top is club-coloured cloth, so on a striped kit the
/// stripes run down the whole arm instead of stopping at the shoulder.
bool outfitSleevesAreKit(String? id) => id == 'tracksuit';

/// **WHAT A BUILD IS.** Ported from `BUILDS` in
/// `../merge-empire-fc/src/data/managerAvatar.js`.
///
/// The build axis was in the customiser, in the wardrobe, in the randomiser and
/// in the save, and it **did nothing at all**: `buildScales`, `buildArmScale`
/// and `buildOverlay` had no port, so six choices produced one figure. The
/// renderer even carried a `build` parameter with nothing ever passing one.
///
/// The JS's own rules, worth keeping because each is a mistake it already made:
///
/// - **Keep [hip] near 1.** The shorts are already about twice the width of the
///   leg beneath them and that flare is intended, so even 1.16 pushes the block
///   visibly out in front of and behind the legs and reads as a slab. `broad`
///   predates the rule and is left alone.
/// - **Width goes in the TORSO**, taper in the torso too; the hip is fine
///   adjustment only.
/// - **Shoulder width is not legible on a figure drawn in profile; DEPTH is.**
///   So `athletic` puts its muscle in [arm] — the upper arms and forearms —
///   and leaves the legs near normal, which is also what sells the arms as the
///   thing that changed. Two attempts at a shoulder overlay both failed, and
///   the JS records why: a straight-topped yoke rendered as an angular slab,
///   and a centred ellipse bulged out the front AND the back by the same amount
///   on a figure seen side-on, so it read as a disc stuck through him.
/// - **Put each bulge where its anatomy is.** The torso spans y 59→93, so a
///   bust goes in the upper half and a gut in the lower, and the two must never
///   be confusable.
typedef ManagerBuild = ({
  double torso,
  double hip,
  double limb,

  /// Arm thickness. Defaults to [limb], so only a build that wants arms and
  /// legs to differ has to say so.
  double arm,

  /// A bulge over the shirt, in the rig's own units — a gut or a bust. Null for
  /// the scale-only builds.
  ({double cx, double cy, double rx, double ry})? bulge,
});

const Map<String, ManagerBuild> managerBuilds = {
  'regular': (torso: 1, hip: 1, limb: 1, arm: 1, bulge: null),
  'lean': (torso: 0.76, hip: 0.86, limb: 0.85, arm: 0.85, bulge: null),
  'broad': (torso: 1.28, hip: 1.16, limb: 1.18, arm: 1.18, bulge: null),
  // Gut low and forward, hanging OVER the waistband — a bulge that stops dead
  // at the shorts line reads as a barrel rather than a belly.
  //
  // **AND IT HAS TO BREAK THE SILHOUETTE.** At (62, 81) r(6, 9.5) it did not:
  // the front of it reached x68 and the shirt's own front edge is 69.9, so the
  // whole gut was inside the body — a slightly lighter ellipse on a shirt, on a
  // figure seen side-on, which is nothing. Reported from the couch as the belly
  // build not looking fat in the belly. `curvy` has always read, and the reason
  // is only that its bust clears the shirt's edge; this now does the same, and
  // hangs to the hem at y93 while it is at it. See [bellyFront] for the rule.
  'belly': (
    torso: 1.18,
    hip: 1.04,
    limb: 1.04,
    arm: 1.04,
    bulge: (cx: 64, cy: 82.5, rx: 8, ry: 11),
  ),
  'athletic': (torso: 1.14, hip: 0.92, limb: 1.04, arm: 1.44, bulge: null),
  // Chest forward over a narrow torso and a wider hip, so the waist-to-hip
  // difference does as much work as the bust.
  'curvy': (
    torso: 0.84,
    hip: 1.04,
    limb: 0.90,
    arm: 0.90,
    bulge: (cx: 63.5, cy: 69, rx: 8.5, ry: 6),
  ),
};

/// How far the shirt's own front edge reaches, in the rig's units.
///
/// **A bulge inside this line is not a bulge.** The figure is drawn in profile,
/// so a build is read off its outline and nothing else: an ellipse that stops
/// short of the garment's edge changes only the shading. Both bulges are
/// measured against it — see `manager_walker_test`.
const double bellyFront = 69.9;

/// The scales for a build id. An unknown one is `regular`, so a save from a
/// future build still draws a man.
ManagerBuild buildScales(String? id) =>
    managerBuilds[id] ?? managerBuilds['regular']!;

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
///
/// [bulge] is the build's own silhouette, drawn INSIDE the torso's scale — so
/// it inherits that width for free and can never leave a seam against the body
/// it belongs to, which is the JS's reason for filling it with the lit shirt
/// colour rather than a shade.
void paintTorso(
  Canvas canvas,
  Color kit, {
  double build = 1,
  ({double cx, double cy, double rx, double ry})? bulge,
  bool soft = true,
}) {
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
      ..maskFilter = soft ? const MaskFilter.blur(BlurStyle.normal, 2.2) : null,
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

  // The build's own silhouette, over the shirt and scaled with it. Drawn in the
  // LIT shirt colour, which is what stops a gut leaving a seam across a body it
  // is part of.
  if (bulge != null) {
    canvas.save();
    canvas.translate(58, 0);
    canvas.scale(build, 1);
    canvas.translate(-58, 0);
    final oval = Rect.fromCenter(
      center: Offset(bulge.cx, bulge.cy),
      width: bulge.rx * 2,
      height: bulge.ry * 2,
    );
    canvas.drawOval(oval, Paint()..color = kit);
    // **And it is shaded UNDERNEATH.** Filled with the lit shirt colour it
    // leaves no seam, which is what that fill is for — but a shape with no
    // shadow under it is a flat patch rather than something hanging. The crease
    // is inside the oval, so it cannot draw on the body around it.
    canvas.save();
    canvas.clipPath(Path()..addOval(oval));
    canvas.drawRect(
      oval,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, bulge.cy),
          Offset(0, oval.bottom),
          [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.16),
          ],
        )
        ..maskFilter = soft
            ? const MaskFilter.blur(BlurStyle.normal, 1.6)
            : null,
    );
    canvas.restore();
    canvas.restore();
  }

  // **CLOTH HAS FOLDS.** A shirt that is one smooth gradient from collar to
  // hem is a painted torso; two soft creases — one pulled in under the arm
  // where the sleeve meets the body, one across the belly where it tucks —
  // are what make it fabric with a man inside it.
  if (soft) {
    canvas.save();
    canvas.clipPath(path);
    final crease = Paint()
      ..color = Colors.black.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.1);
    canvas.drawPath(
      Path()
        ..moveTo(50.6, 68)
        ..quadraticBezierTo(53.4, 74, 51.8, 81),
      crease,
    );
    canvas.drawPath(
      Path()
        ..moveTo(52.4, 83.6)
        ..quadraticBezierTo(59, 85.4, 66.4, 82.6),
      crease,
    );
    // A pull of light on the chest, where the cloth is stretched over it.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(65, 68), width: 6, height: 11),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.09)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.restore();
  }

  // **A COLLAR, not a line across the shoulders.** A band round the base of
  // the neck with a raised top edge and a placket notch at the front — the
  // three marks that say "polo shirt" in profile at this size.
  final band = Path()
    ..moveTo(53.2, 58.4)
    ..quadraticBezierTo(58.6, 65.4, 63.8, 58.0)
    ..lineTo(63.4, 55.6)
    ..quadraticBezierTo(58.6, 61.6, 53.6, 55.8)
    ..close();
  canvas.drawPath(band, Paint()..color = deepen(kit, 0.36));
  canvas.drawPath(
    Path()
      ..moveTo(53.6, 55.8)
      ..quadraticBezierTo(58.6, 61.6, 63.4, 55.6),
    Paint()
      ..color = lift(kit, 0.22)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round,
  );
  // The placket: a short notch down from the collar's front, with a button.
  canvas.drawLine(
    const Offset(61.8, 60.6),
    const Offset(61.2, 65.4),
    Paint()
      ..color = deepen(kit, 0.3)
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawCircle(
    const Offset(61.4, 64.2),
    0.55,
    Paint()..color = lift(kit, 0.5),
  );
}

/// The neck. Drawn before the torso and the head, so both overlap it.
///
/// **It existed and you could not see it**, which is a different bug from not
/// having one: the skull's underside sat four units INSIDE the shirt, so the neck
/// was entirely hidden between them and the head read as resting on the collar.
/// The head group is lifted now — see `_headLift` — and this reaches up into the
/// gap that opens.
///
/// Angled very slightly forward, because a neck that rises dead vertical out of a
/// pair of shoulders reads as a post. Darker than the face: it is the one part of
/// him in shadow from every direction at once.
void paintNeck(Canvas canvas, Color skin) {
  paintLimb(
    canvas,
    const Offset(59.0, 64),
    const Offset(60.4, 48),
    10.4,
    8.6,
    base: deepen(skin, 0.16),
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
  // **A BOOT HAS LACES AND A TOE.** Without them it is a black wedge. A pale
  // tongue over the instep with three cross-laces, a toe cap caught by the
  // light along its top, and a heel counter behind the ankle.
  final tongue = Rect.fromCenter(
    center: ankle.translate(3.0, -0.6),
    width: 4.6,
    height: 2.4,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(tongue, const Radius.circular(1)),
    Paint()..color = lift(boot, 0.34),
  );
  final lace = Paint()
    ..color = lift(boot, 0.7)
    ..strokeWidth = 0.45
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 3; i++) {
    final x = tongue.left + 0.9 + i * 1.4;
    canvas.drawLine(
      Offset(x, tongue.top + 0.4),
      Offset(x + 0.9, tongue.bottom - 0.4),
      lace,
    );
  }
  canvas.drawPath(
    Path()
      ..moveTo(ankle.dx + 6.4, ankle.dy - 0.4)
      ..quadraticBezierTo(ankle.dx + 9.6, ankle.dy - 0.2, ankle.dx + 10.8, ankle.dy + 1.6),
    Paint()
      ..color = lift(boot, 0.32)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawLine(
    Offset(ankle.dx - 1.4, ankle.dy - 1.6),
    Offset(ankle.dx - 1.0, ankle.dy + 2.4),
    Paint()
      ..color = deepen(boot, 0.35)
      ..strokeWidth = 0.6
      ..strokeCap = StrokeCap.round,
  );
  canvas.restore();
}

/// The index finger, out past the hand along the forearm's own axis.
///
/// **Hidden unless something is being pointed at.** At this size a permanent
/// finger makes the hand read as a lumpy mitten, so it fades in for the three
/// gestures that need it — see `psvFingerShow`.
///
/// **OFF-CENTRE, and it has to stay that way.** The hand spans x 52.2 to 59.8, and
/// a finger centred on that is a single digit poking out of the middle of a fist,
/// which is an entirely different gesture. Sitting forward — the side he faces —
/// where an index finger actually joins the hand, it reads as pointing.
void paintFinger(Canvas canvas, Offset hand, Color skin, double opacity) {
  if (opacity <= 0.01) return;
  final flesh = Color.lerp(skin, Colors.white, 0.04)!;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(hand.dx + 1.1, hand.dy + 1.4, 2.4, 5.4),
      const Radius.circular(1.2),
    ),
    Paint()..color = flesh.withValues(alpha: opacity),
  );
}

/// A wristwatch, on the near arm.
///
/// **Without it, checking his watch is a man staring at his own knuckles.** The
/// gesture is in the JS's rota and the port had nothing on the wrist for him to
/// look at, so the pose read as a shrug that had gone wrong.
///
/// Drawn in the forearm's own frame just above the hand, so it turns with the arm
/// and stays on the inside of the wrist wherever the arm goes.
void paintWatch(Canvas canvas, Offset wrist, Color accent) {
  // The strap, across the wrist rather than around it: side-on, a band is a bar.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: wrist, width: 6.4, height: 3.0),
      const Radius.circular(1.1),
    ),
    Paint()..color = const Color(0xFF2A2A30),
  );
  // The face, catching the light, in the club's colour so it reads as HIS.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: wrist.translate(1.3, 0), width: 3.0, height: 2.6),
      const Radius.circular(0.8),
    ),
    Paint()..color = lift(accent, 0.42),
  );
}

/// A hand: a mitten, wider across the knuckles than at the wrist — with a
/// THUMB on the leading edge, which is the one mark that turns an oval on the
/// end of an arm into a hand.
void paintHand(Canvas canvas, Offset at, Color skin, {bool far = false}) {
  final flesh = far ? deepen(skin, 0.26) : skin;
  final palm = Path()
    ..addOval(Rect.fromCenter(center: at, width: 7.4, height: 6.4));
  canvas.drawPath(
    palm,
    Paint()
      ..shader = ui.Gradient.radial(
        at.translate(-1, -1.4),
        4.6,
        [lift(flesh, 0.16), flesh, deepen(flesh, 0.24)],
        const [0, 0.55, 1],
      ),
  );
  // The thumb, a smaller round forward and up of the knuckles, with a crease
  // where it joins.
  final thumb = at.translate(2.9 * facing, -1.9);
  canvas.drawCircle(thumb, 1.55, Paint()..color = lift(flesh, 0.06));
  canvas.drawArc(
    Rect.fromCircle(center: thumb, radius: 1.55),
    math.pi * 0.55,
    math.pi * 0.8,
    false,
    Paint()
      ..color = deepen(flesh, 0.3)
      ..strokeWidth = 0.45
      ..style = PaintingStyle.stroke,
  );
  // A knuckle line across the back of the hand.
  canvas.save();
  canvas.clipPath(palm);
  canvas.drawPath(
    Path()
      ..moveTo(at.dx - 2.2, at.dy + 0.4)
      ..quadraticBezierTo(at.dx + 0.4, at.dy - 0.6, at.dx + 2.8, at.dy + 0.6),
    Paint()
      ..color = deepen(flesh, 0.22)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round,
  );
  canvas.restore();
}

/// **KIT SOCKS.** A football kit is shorts, a shirt and socks pulled up the
/// shin; the bare-legged figure read as a man in gym shorts. Drawn over the
/// lower shin in the club's colour with a paler turnover at the top, from
/// [top] down to the [ankle], in the shin's own frame.
void paintSock(
  Canvas canvas,
  Offset top,
  Offset ankle,
  double wTop,
  double wAnkle, {
  required Color kit,
  bool far = false,
  bool soft = true,
}) {
  paintLimb(
    canvas,
    top,
    ankle,
    wTop,
    wAnkle,
    base: deepen(kit, 0.08),
    far: far,
    occlude: false,
    soft: soft,
  );
  // The turnover: a paler band across the top of the sock, INSIDE the sock's
  // own shape — a second capsule's round caps made it twice its height.
  final band = far ? deepen(lift(kit, 0.42), 0.26) : lift(kit, 0.42);
  canvas.save();
  canvas.clipPath(taperedLimb(top, ankle, wTop, wAnkle));
  canvas.drawRect(
    Rect.fromLTWH(top.dx - wTop, top.dy - wTop, wTop * 2, wTop + 2.4),
    Paint()..color = band,
  );
  canvas.drawLine(
    Offset(top.dx - wTop, top.dy + 2.4),
    Offset(top.dx + wTop, top.dy + 2.4),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..strokeWidth = 0.5,
  );
  canvas.restore();
}
