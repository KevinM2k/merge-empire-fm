/// The penalty keeper. Ported from `buildKeeperSvg` and the `.pen-keeper` rules
/// in `styles/screens.css`.
///
/// The port drew him as five flat rectangles with the arms permanently out —
/// a starfish that never changed shape, whichever way the ball went. The JS has
/// a proper illustration with **eight kit tiers taken from the division**, so
/// the keeper in the Champions Cup is visibly not the one you beat in Sunday
/// League, and it rigs him: each arm and each leg is a group with its own joint,
/// so a dive throws the lead arm across and steps the near leg over.
///
/// **The posing is Flutter's, not hand-animated.** `AnimatedRotation` about an
/// `Alignment` is exactly what the CSS transitions were doing — a rotation about
/// a named origin, interpolated over a duration — so each limb is one widget and
/// there is no clock in this file at all. The only controller here is the idle
/// sway, which is a LOOP and has nothing native to hang off.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/data/keeper_art.g.dart';
import 'package:merge_empire_fc/ui/widgets/svg_canvas.dart';

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

  /// The lead arm reaches fully; the trailing one follows at half. Both point
  /// toward the keeper's head in the art's space, which after the body turn is
  /// the direction the ball went.
  double get armLeftDegrees => switch (direction) {
    -1 => -130,
    1 => 65,
    _ => 0,
  };

  double get armRightDegrees => switch (direction) {
    -1 => -65,
    1 => 130,
    _ => 0,
  };

  /// The lead leg steps across, the push-off leg extends back.
  double get legLeftDegrees => switch (direction) {
    -1 => 14,
    1 => 24,
    _ => 0,
  };

  double get legRightDegrees => switch (direction) {
    -1 => -24,
    1 => -14,
    _ => 0,
  };
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

double _turns(double degrees) => degrees / 360;

/// An `Alignment` for a point in the art's own space, which is what lets a
/// native rotation turn a limb about its socket.
Alignment jointAlignment(String joint) {
  final (x, y) = keeperJoints[joint]!;
  return Alignment(x / keeperArtWidth * 2 - 1, y / keeperArtHeight * 2 - 1);
}

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
      _sway.repeat(reverse: true);
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
    final layers = keeperLayers[widget.tier] ?? keeperLayers[3]!;
    final pose = widget.pose;

    return AspectRatio(
      aspectRatio: keeperArtWidth / keeperArtHeight,
      child: AnimatedRotation(
        key: const ValueKey('penalty-keeper'),
        turns: _turns(pose.bodyDegrees),
        duration: keeperDiveDuration,
        curve: Curves.easeOut,
        // He turns about his feet, not his middle: a dive pivots off the ground.
        alignment: Alignment.bottomCenter,
        child: AnimatedBuilder(
          animation: _sway,
          builder: (context, child) => Transform.translate(
            // Three pixels either way, in the art's own space — horizontal only,
            // because a keeper on his line shifts his weight rather than hops.
            offset: Offset(pose.diving ? 0 : (_sway.value * 6 - 3), 0),
            child: child,
          ),
          // Leaner than the drawing, which the CSS does with a scaleX and which
          // is what makes him read as a goalkeeper rather than a snowman.
          child: Transform.scale(
            scaleX: 0.85,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The far arm and the far leg go under the body; the near ones
                // over it. Same depth trick as the walking manager.
                _Limb(
                  svg: layers.armR,
                  joint: 'armR',
                  degrees: pose.armRightDegrees,
                ),
                _Limb(
                  svg: layers.legR,
                  joint: 'legR',
                  degrees: pose.legRightDegrees,
                ),
                SvgArt(svg: layers.body),
                _Limb(
                  svg: layers.legL,
                  joint: 'legL',
                  degrees: pose.legLeftDegrees,
                ),
                _Limb(
                  svg: layers.armL,
                  joint: 'armL',
                  degrees: pose.armLeftDegrees,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One arm or leg, turned about its own joint.
class _Limb extends StatelessWidget {
  const _Limb({required this.svg, required this.joint, required this.degrees});

  final String svg;
  final String joint;
  final double degrees;

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    key: ValueKey('keeper-limb-$joint'),
    turns: _turns(degrees),
    duration: keeperDiveDuration,
    // The limbs trail the body a fraction, which is what the CSS's 40ms delay
    // on the legs is for. A single curve does the same job with no second clock.
    curve: Curves.easeOutCubic,
    alignment: jointAlignment(joint),
    child: SvgArt(svg: svg),
  );
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

/// The idle sway, as a fraction of the art's width — exported for the test that
/// pins it, because a sway that grew would walk him off his line.
const double keeperSwayPixels = 3;

/// A shadow under him, sized off the figure.
///
/// Native gradient rather than the JS's flat ellipse: it is the one thing on the
/// scene with no photograph behind it, and a hard-edged oval reads as a sticker.
Widget keeperShadow({required double width}) => IgnorePointer(
  child: Container(
    width: width,
    height: width * 0.22,
    decoration: BoxDecoration(
      shape: BoxShape.rectangle,
      borderRadius: BorderRadius.all(Radius.elliptical(width, width * 0.11)),
      gradient: RadialGradient(
        colors: [
          Colors.black.withValues(alpha: 0.38),
          Colors.black.withValues(alpha: 0),
        ],
      ),
    ),
  ),
);
