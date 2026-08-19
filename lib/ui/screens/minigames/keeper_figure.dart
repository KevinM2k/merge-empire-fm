/// The penalty keeper.
///
/// **He is drawn here, not imported.** The port rendered him from
/// `keeper_art.g.dart` — five flat SVG layers, rotated about named joints — and
/// at the size he actually appears on the scene that came out as an orange slab
/// with a white patch on it, two black mitts on stubs, no shorts, no boots, and
/// a shoulder that was simply the top of the shirt. The eight kits it carried
/// are [keeperKits] now — that was the half of it worth keeping — and the 2,000
/// lines of geometry underneath went with the generator that produced them.
///
/// **A joint is a joint.** Every limb here has two segments and a hinge —
/// shoulder→elbow→glove, hip→knee→boot — so a dive bends where a person bends
/// instead of swinging one rigid plank out of its socket. That is also what
/// makes the trailing leg read: it folds, and a straight one just points.
///
/// **The whole rig interpolates as ONE value.** [KeeperRig] carries all nine
/// angles and knows how to lerp itself, so a `TweenAnimationBuilder` animates
/// the entire pose change on one clock. Nine separate implicit animations is
/// nine curves that can drift apart mid-dive, and the arm arriving before the
/// legs is exactly what makes a rig look like paper cut-outs.
///
/// The only controller in this file is the idle sway, which is a LOOP and has
/// nothing implicit to hang off.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Which way he went, and how far down.
///
/// The JS reads the height off the contact point — a shot below the midline is a
/// LOW dive and lays him almost flat (75°), one above it is a high dive and only
/// leans him (22°). Both are ported: a keeper who threw himself full-length at a
/// shot into the top corner looked like he had fallen over.
enum KeeperPose {
  ready,
  lowLeft,
  highLeft,
  lowRight,
  highRight;

  bool get diving => this != KeeperPose.ready;

  /// -1 left, 1 right, 0 while he is still on his line.
  int get direction => switch (this) {
    KeeperPose.ready => 0,
    KeeperPose.lowLeft || KeeperPose.highLeft => -1,
    KeeperPose.lowRight || KeeperPose.highRight => 1,
  };

  bool get low => this == KeeperPose.lowLeft || this == KeeperPose.lowRight;

  /// How far the whole figure turns, in degrees. The JS's own two numbers.
  double get bodyDegrees => direction * (low ? 75 : 22);
}

/// Which kit he wears, from the division's index.
///
/// Sunday League gets a tier-two rookie and the Champions Cup a tier-eight
/// world-class one — the visual half of the smart-dive ramp the engine already
/// scales with the same index.
int keeperTierForDivision(int divisionIndex) =>
    (2 + divisionIndex.clamp(0, 6)).round();

/// How long a dive takes to strike the pose. The JS's transition.
const Duration keeperDiveDuration = Duration(milliseconds: 280);

/// One weight-shift, while he waits.
const Duration keeperSwayCycle = Duration(milliseconds: 950);

/// The idle sway, as a fraction of the art's width — exported for the test that
/// pins it, because a sway that grew would walk him off his line.
const double keeperSwayPixels = 3;

/// The kit, by tier. A goalkeeper's shirt is the one on the pitch that is
/// deliberately unlike everyone else's, so these are loud on purpose and they
/// climb: a Sunday League keeper is in a washed-out club top and the one in the
/// Champions Cup is in something with a sponsor.
typedef KeeperKit = ({
  Color shirt,
  Color shirtShade,
  Color trim,
  Color shorts,
  Color socks,
  Color glove,
  Color hair,
  Color skin,
});

const Map<int, KeeperKit> keeperKits = {
  1: (
    shirt: Color(0xFF6E7B62),
    shirtShade: Color(0xFF55604B),
    trim: Color(0xFF3E463A),
    shorts: Color(0xFF3E463A),
    socks: Color(0xFF6E7B62),
    glove: Color(0xFFC9C4B4),
    hair: Color(0xFF3A2A1C),
    skin: Color(0xFFE3B183),
  ),
  2: (
    shirt: Color(0xFFE0A32B),
    shirtShade: Color(0xFFBF861B),
    trim: Color(0xFF2B2B2B),
    shorts: Color(0xFF2B2B2B),
    socks: Color(0xFFE0A32B),
    glove: Color(0xFFEDEDED),
    hair: Color(0xFF1F1B16),
    skin: Color(0xFFD99A6C),
  ),
  3: (
    shirt: Color(0xFF2AA9A0),
    shirtShade: Color(0xFF1E8078),
    trim: Color(0xFF11333F),
    shorts: Color(0xFF11333F),
    socks: Color(0xFF2AA9A0),
    glove: Color(0xFFF2F2F2),
    hair: Color(0xFF6B4423),
    skin: Color(0xFFEEBB8C),
  ),
  4: (
    shirt: Color(0xFF7E4BC4),
    shirtShade: Color(0xFF5F3599),
    trim: Color(0xFFEFE8FA),
    shorts: Color(0xFF2A1A44),
    socks: Color(0xFF7E4BC4),
    glove: Color(0xFFEFE8FA),
    hair: Color(0xFF1A1410),
    skin: Color(0xFF8D5A2B),
  ),
  5: (
    shirt: Color(0xFFF07A1F),
    shirtShade: Color(0xFFC85F10),
    trim: Color(0xFF23262B),
    shorts: Color(0xFF23262B),
    socks: Color(0xFFF07A1F),
    glove: Color(0xFFFFFFFF),
    hair: Color(0xFF3A2A1C),
    skin: Color(0xFFF7D9BD),
  ),
  6: (
    shirt: Color(0xFFB6E82F),
    shirtShade: Color(0xFF8CBB18),
    trim: Color(0xFF16181B),
    shorts: Color(0xFF16181B),
    socks: Color(0xFFB6E82F),
    glove: Color(0xFF16181B),
    hair: Color(0xFF9A9A9A),
    skin: Color(0xFFB87A49),
  ),
  7: (
    shirt: Color(0xFFC2223F),
    shirtShade: Color(0xFF941630),
    trim: Color(0xFFFFC233),
    shorts: Color(0xFF1A1013),
    socks: Color(0xFFC2223F),
    glove: Color(0xFFFFC233),
    hair: Color(0xFF1A1410),
    skin: Color(0xFF6F462A),
  ),
  8: (
    shirt: Color(0xFF2E7CE8),
    shirtShade: Color(0xFF1A56AE),
    trim: Color(0xFFC3CCD4),
    shorts: Color(0xFF0C1730),
    socks: Color(0xFF2E7CE8),
    glove: Color(0xFFC3CCD4),
    hair: Color(0xFFD9B44A),
    skin: Color(0xFFEEBB8C),
  ),
};

/// The middle kit, for a tier nobody has drawn one for.
KeeperKit keeperKitFor(int tier) => keeperKits[tier] ?? keeperKits[3]!;

double _rad(double degrees) => degrees * math.pi / 180;

/// Every angle in the rig at one instant.
///
/// All of them measure from STRAIGHT DOWN, positive turning toward the right of
/// the screen, and the fore-limb angles are relative to the limb above them —
/// so an elbow is a bend rather than an absolute direction, which is what lets
/// the arm keep its shape while the shoulder swings.
@immutable
class KeeperRig {
  const KeeperRig({
    required this.body,
    required this.armL,
    required this.elbowL,
    required this.armR,
    required this.elbowR,
    required this.legL,
    required this.kneeL,
    required this.legR,
    required this.kneeR,
  });

  final double body;
  final double armL;
  final double elbowL;
  final double armR;
  final double elbowR;
  final double legL;
  final double kneeL;
  final double legR;
  final double kneeR;

  /// On his line: arms a little off the body, feet apart, knees soft. Not
  /// symmetrical to the degree — a figure whose two halves are exact mirrors
  /// reads as a diagram.
  static const KeeperRig ready = KeeperRig(
    body: 0,
    armL: -20,
    elbowL: -24,
    armR: 20,
    elbowR: 24,
    legL: -7,
    kneeL: 5,
    legR: 7,
    kneeR: -5,
  );

  /// What he throws himself into.
  ///
  /// Both arms go UP in the figure's own space, because the body has already
  /// turned: a limb pointing up on a rig lying at 75° is a limb pointing along
  /// the goal line, which is where the ball is. The lead arm reaches past
  /// straight; the trailing one follows at an angle and keeps its elbow.
  factory KeeperRig.of(KeeperPose pose) {
    final d = pose.direction;
    if (d == 0) return ready;
    // Mirrored about the figure's own axis, so one description serves both ways.
    final lead = 168.0 * d;
    final trail = 128.0 * d;
    return KeeperRig(
      body: pose.bodyDegrees,
      armL: d > 0 ? trail : lead,
      elbowL: d > 0 ? -22 : -10,
      armR: d > 0 ? lead : trail,
      elbowR: d > 0 ? 10 : 22,
      // The lead leg tucks and the push-off leg extends behind him. Straight
      // legs on a diving keeper is a plank going sideways.
      legL: d > 0 ? -26 : 30,
      kneeL: d > 0 ? 10 : 42,
      legR: d > 0 ? -30 : 26,
      kneeR: d > 0 ? -42 : -10,
    );
  }

  static KeeperRig lerp(KeeperRig a, KeeperRig b, double t) => KeeperRig(
    body: _l(a.body, b.body, t),
    armL: _l(a.armL, b.armL, t),
    elbowL: _l(a.elbowL, b.elbowL, t),
    armR: _l(a.armR, b.armR, t),
    elbowR: _l(a.elbowR, b.elbowR, t),
    legL: _l(a.legL, b.legL, t),
    kneeL: _l(a.kneeL, b.kneeL, t),
    legR: _l(a.legR, b.legR, t),
    kneeR: _l(a.kneeR, b.kneeR, t),
  );

  static double _l(double a, double b, double t) => a + (b - a) * t;

  @override
  bool operator ==(Object other) =>
      other is KeeperRig &&
      other.body == body &&
      other.armL == armL &&
      other.elbowL == elbowL &&
      other.armR == armR &&
      other.elbowR == elbowR &&
      other.legL == legL &&
      other.kneeL == kneeL &&
      other.legR == legR &&
      other.kneeR == kneeR;

  @override
  int get hashCode =>
      Object.hash(body, armL, elbowL, armR, elbowR, legL, kneeL, legR, kneeR);
}

class _RigTween extends Tween<KeeperRig> {
  _RigTween({super.begin, super.end});

  @override
  KeeperRig lerp(double t) => KeeperRig.lerp(begin!, end!, t);
}

/// The space the figure is drawn in. Everything below is in these units, and
/// the painter scales once — so the drawing does not have to know how big it
/// ends up on a phone.
const Size keeperDesign = Size(100, 150);

class KeeperFigure extends StatefulWidget {
  const KeeperFigure({super.key, required this.tier, required this.pose});

  /// 1..8. Out-of-range falls back to the middle tier, as the JS does.
  final int tier;
  final KeeperPose pose;

  @override
  State<KeeperFigure> createState() => KeeperFigureState();
}

class KeeperFigureState extends State<KeeperFigure>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: keeperSwayCycle,
  );

  /// Test seam.
  bool get swaying => _sway.isAnimating;

  void _syncSway() {
    // He only shifts his weight while he is waiting. Mid-dive the limbs are
    // doing the moving, and the JS kills the animation for the same reason.
    final wants =
        !widget.pose.diving && !MediaQuery.of(context).disableAnimations;
    if (wants && !_sway.isAnimating) {
      // Not `reverse: true`: the offset is a SINE of the value, which is
      // already zero at both ends of the cycle. A reversing controller sitting
      // at 0 would put him three pixels off his line the moment the sway
      // stopped, which is a keeper who never quite stands still.
      _sway.repeat();
    } else if (!wants && _sway.isAnimating) {
      _sway.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSway();
  }

  @override
  void didUpdateWidget(KeeperFigure oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSway();
  }

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: keeperDesign.width / keeperDesign.height,
      child: TweenAnimationBuilder<KeeperRig>(
        key: const ValueKey('penalty-keeper'),
        tween: _RigTween(
          begin: KeeperRig.of(widget.pose),
          end: KeeperRig.of(widget.pose),
        ),
        duration: keeperDiveDuration,
        curve: Curves.easeOut,
        builder: (context, rig, _) => AnimatedBuilder(
          animation: _sway,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: KeeperPainter(
              rig: rig,
              kit: keeperKitFor(widget.tier),
              // Horizontal only, and only on his line — a keeper waiting shifts
              // his weight, he does not hop.
              sway: widget.pose.diving
                  ? 0
                  : math.sin(_sway.value * 2 * math.pi) * keeperSwayPixels,
            ),
          ),
        ),
      ),
    );
  }
}

class KeeperPainter extends CustomPainter {
  const KeeperPainter({
    required this.rig,
    required this.kit,
    required this.sway,
  });

  final KeeperRig rig;
  final KeeperKit kit;
  final double sway;

  // ── Where the body is, in design units ───────────────────────────────────
  static const double _headY = 25;
  static const double _headR = 12.5;
  static const double _shoulderY = 47;
  static const double _shoulderX = 15.5;
  static const double _hipY = 86;
  static const double _hipX = 8;
  static const double _upperArm = 20;
  static const double _foreArm = 19;
  static const double _thigh = 30;
  static const double _shin = 27;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(
      size.width / keeperDesign.width,
      size.height / keeperDesign.height,
    );
    // He pivots off the GROUND: a dive is pushed off the feet, not spun about
    // the belt.
    canvas.translate(keeperDesign.width / 2 + sway, keeperDesign.height);
    canvas.rotate(_rad(rig.body));
    canvas.translate(-keeperDesign.width / 2, -keeperDesign.height);

    // Far side first, then the body, then the near side over it — the same
    // depth order the walking manager uses, and the only thing that stops a
    // flat figure reading as a sticker.
    _leg(canvas, isLeft: false);
    _arm(canvas, isLeft: false);
    _shorts(canvas);
    _torso(canvas);
    _leg(canvas, isLeft: true);
    _head(canvas);
    _arm(canvas, isLeft: true);
    canvas.restore();
  }

  /// One limb: two segments and the hinge between them, with something on the
  /// end. The tip is returned so a caller can hang a boot or a glove on it.
  Offset _twoBone(
    Canvas canvas, {
    required Offset root,
    required double angle,
    required double bend,
    required double upper,
    required double lower,
    required double upperWidth,
    required double lowerWidth,
    required Color upperColour,
    required Color lowerColour,
  }) {
    final a = _rad(angle);
    final joint = root + Offset(math.sin(a) * upper, math.cos(a) * upper);
    final b = _rad(angle + bend);
    final tip = joint + Offset(math.sin(b) * lower, math.cos(b) * lower);

    canvas.drawLine(
      root,
      joint,
      Paint()
        ..color = upperColour
        ..strokeWidth = upperWidth
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      joint,
      tip,
      Paint()
        ..color = lowerColour
        ..strokeWidth = lowerWidth
        ..strokeCap = StrokeCap.round,
    );
    return tip;
  }

  void _arm(Canvas canvas, {required bool isLeft}) {
    final root = Offset(
      keeperDesign.width / 2 + (isLeft ? -_shoulderX : _shoulderX),
      _shoulderY,
    );
    // The far arm is a shade darker, which is the whole of the depth cue at
    // this size and cheaper than any of the alternatives.
    final shade = isLeft ? 0.0 : 0.18;
    final tip = _twoBone(
      canvas,
      root: root,
      angle: isLeft ? rig.armL : rig.armR,
      bend: isLeft ? rig.elbowL : rig.elbowR,
      upper: _upperArm,
      lower: _foreArm,
      upperWidth: 8.5,
      lowerWidth: 7,
      // A SLEEVE, then bare forearm. The two being one colour is what made the
      // old arms read as sticks: there was nothing to say where the shirt
      // stopped.
      upperColour: _dark(kit.shirt, shade),
      lowerColour: _dark(kit.skin, shade),
    );

    // The glove. Oversized on purpose — it is the one piece of equipment that
    // says goalkeeper from across a pitch.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: tip, width: 11, height: 13),
        const Radius.circular(4.5),
      ),
      Paint()..color = _dark(kit.glove, shade),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: tip, width: 7.5, height: 8),
        const Radius.circular(3),
      ),
      Paint()..color = _dark(kit.trim, shade).withValues(alpha: 0.45),
    );
  }

  void _leg(Canvas canvas, {required bool isLeft}) {
    final root = Offset(
      keeperDesign.width / 2 + (isLeft ? -_hipX : _hipX),
      _hipY,
    );
    final shade = isLeft ? 0.0 : 0.18;
    final tip = _twoBone(
      canvas,
      root: root,
      angle: isLeft ? rig.legL : rig.legR,
      bend: isLeft ? rig.kneeL : rig.kneeR,
      upper: _thigh,
      lower: _shin,
      upperWidth: 10,
      lowerWidth: 8,
      // Thigh is bare, shin is sock — which is what a sock line IS, and the old
      // figure had the whole leg one black stick.
      upperColour: _dark(kit.skin, shade),
      lowerColour: _dark(kit.socks, shade),
    );

    // The boot, pointing the way the shin does.
    final heading = _rad(
      (isLeft ? rig.legL + rig.kneeL : rig.legR + rig.kneeR),
    );
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(heading);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-4, -1, 13, 6),
        const Radius.circular(2.5),
      ),
      Paint()..color = _dark(const Color(0xFF1B1B1F), shade),
    );
    canvas.restore();
  }

  void _shorts(Canvas canvas) {
    final cx = keeperDesign.width / 2;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(cx - 14, _hipY - 16, cx + 14, _hipY + 6),
        bottomLeft: const Radius.circular(5),
        bottomRight: const Radius.circular(5),
      ),
      Paint()..color = kit.shorts,
    );
  }

  /// The shirt. Wider at the shoulders than at the waist, which is the whole
  /// difference between a torso and a rectangle.
  void _torso(Canvas canvas) {
    final cx = keeperDesign.width / 2;
    final top = _shoulderY - 6;
    final path = Path()
      ..moveTo(cx - _shoulderX - 3, top + 4)
      ..quadraticBezierTo(cx, top - 5, cx + _shoulderX + 3, top + 4)
      ..lineTo(cx + 13, _hipY - 12)
      ..quadraticBezierTo(cx, _hipY - 8, cx - 13, _hipY - 12)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kit.shirt, kit.shirtShade],
        ).createShader(Rect.fromLTRB(cx - 20, top, cx + 20, _hipY)),
    );

    // The collar, and a trim line down the shirt. Two strokes, and they are
    // what make it a jersey rather than a bib.
    canvas.drawPath(
      Path()
        ..moveTo(cx - 7, top + 2)
        ..quadraticBezierTo(cx, top + 9, cx + 7, top + 2),
      Paint()
        ..color = kit.trim
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(cx - _shoulderX - 1, top + 8),
      Offset(cx - 11, _hipY - 14),
      Paint()
        ..color = kit.trim.withValues(alpha: 0.5)
        ..strokeWidth = 1.6,
    );
    canvas.drawLine(
      Offset(cx + _shoulderX + 1, top + 8),
      Offset(cx + 11, _hipY - 14),
      Paint()
        ..color = kit.trim.withValues(alpha: 0.5)
        ..strokeWidth = 1.6,
    );
  }

  /// The head, with a FACE in it.
  ///
  /// Eyes, brows, a nose and ears. At 50px tall none of them is more than three
  /// pixels, and every one of them is the difference between a person and a
  /// bean — the old figure had a mouth and two dots and read as neither.
  void _head(Canvas canvas) {
    final cx = keeperDesign.width / 2;
    final c = Offset(cx, _headY);

    // Neck first, so the head sits on it rather than beside it.
    canvas.drawLine(
      Offset(cx, _headY + 6),
      Offset(cx, _shoulderY - 1),
      Paint()
        ..color = _dark(kit.skin, 0.12)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    // Ears, under the head so only their outer edge shows.
    for (final side in [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(cx + side * (_headR - 1.5), _headY + 1),
        3.2,
        Paint()..color = _dark(kit.skin, 0.1),
      );
    }
    canvas.drawCircle(c, _headR, Paint()..color = kit.skin);
    // Light from above, the same direction the shirt is lit from.
    canvas.drawCircle(
      c,
      _headR,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.14),
            Colors.black.withValues(alpha: 0.12),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: _headR)),
    );

    // Hair: a cap over the top of the skull, cut off at the brow line.
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: c, radius: _headR)),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c.translate(0, 1.5), radius: _headR + 0.5),
      math.pi,
      math.pi,
      true,
      Paint()..color = kit.hair,
    );
    canvas.restore();

    final ink = Paint()..color = const Color(0xFF2A1F18);
    // Eyes: a white, then the pupil in it. One flat dot each is what made the
    // old face read as a button.
    for (final side in [-1.0, 1.0]) {
      final eye = Offset(cx + side * 4.4, _headY + 1.2);
      canvas.drawOval(
        Rect.fromCenter(center: eye, width: 4.4, height: 3.4),
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(eye.translate(side * 0.3, 0.2), 1.25, ink);
      // Brow. Angled slightly in — a keeper on his line is concentrating.
      canvas.drawLine(
        Offset(eye.dx - side * 2.4, eye.dy - 3.4),
        Offset(eye.dx + side * 2.2, eye.dy - 2.6),
        Paint()
          ..color = kit.hair
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
    }
    // Nose: one short stroke with a shadow to its right, not a triangle.
    canvas.drawLine(
      Offset(cx, _headY + 2.6),
      Offset(cx + 0.6, _headY + 5.4),
      Paint()
        ..color = _dark(kit.skin, 0.34)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    // Mouth.
    canvas.drawLine(
      Offset(cx - 2.4, _headY + 8),
      Offset(cx + 2.4, _headY + 8),
      Paint()
        ..color = const Color(0xFF7A4038)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
  }

  static Color _dark(Color c, double amount) =>
      amount == 0 ? c : Color.lerp(c, Colors.black, amount)!;

  @override
  bool shouldRepaint(KeeperPainter old) =>
      old.rig != rig || old.kit != kit || old.sway != sway;
}

/// Where the keeper stands, in scene percent, for a given dive.
///
/// Kept next to the pose so the two cannot disagree about which way he went.
KeeperPose poseFor({
  required double x,
  required double y,
  required double midX,
}) {
  if (x < midX) return y > 30 ? KeeperPose.lowLeft : KeeperPose.highLeft;
  return y > 30 ? KeeperPose.lowRight : KeeperPose.highRight;
}

/// A shadow under him, sized off the figure.
///
/// Painted, not a `BoxDecoration` gradient: a `RadialGradient` takes its radius
/// from the box's SHORTEST side, and this box is five times wider than it is
/// tall — so the decorated version was a small disc floating in the middle of a
/// wide invisible rectangle. Scaling a circular shader is what makes it an
/// ellipse the width of his stance.
Widget keeperShadow({required double width}) => IgnorePointer(
  child: SizedBox(
    width: width,
    height: width * 0.22,
    child: const CustomPaint(size: Size.infinite, painter: _ShadowPainter()),
  ),
);

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
            Colors.black.withValues(alpha: 0.38),
            Colors.black.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShadowPainter old) => false;
}
