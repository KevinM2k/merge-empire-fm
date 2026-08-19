/// The manager, walking. Ported from the rig in `components/PitchScene.js` and
/// its keyframes in `styles/league-scene.css`.
///
/// He is the player's AVATAR, not one of their footballers — the customiser
/// dresses him, and on the scene the ball comes TO him rather than being
/// dribbled by him, so the figure reads as the gaffer the game casts you as.
///
/// **Six tracks, one clock.** The JS drives the rig with six CSS keyframe
/// animations sharing a duration: two thighs, two shins, two arms, plus a
/// vertical bob. Every one of them is a rotation about a named joint, so the
/// whole thing is a handful of `Transform.rotate`s hung off one
/// `AnimationController`.
///
/// **Linear on the limbs, eased on the bob**, and the CSS says why: `ease-in-out`
/// zeroes velocity at each keyframe, which reads as the leg PAUSING at full
/// extension. A vertical bounce should decelerate at the top; a stride should
/// not.
///
/// The far limbs are drawn first and in a darker shade so the near ones overlap
/// them — that is the whole of the depth in the figure.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The figure's own space, shared with `data/manager_art.g.dart` so a hat lands
/// on the head with no positioning of its own.
const double walkerWidth = 120;
const double walkerHeight = 170;

/// One full stride.
const Duration walkCycle = Duration(milliseconds: 1800);

double _deg(double d) => d * math.pi / 180;

/// A keyframed track: stops at 0..1 through the cycle, in degrees.
typedef _Track = List<(double at, double deg)>;

/// Read a track at [t], interpolating linearly between its stops.
double _sample(_Track track, double t) {
  for (var i = 0; i < track.length - 1; i++) {
    final (a, from) = track[i];
    final (b, to) = track[i + 1];
    if (t >= a && t <= b) {
      final span = b - a;
      return span <= 0 ? from : from + (to - from) * ((t - a) / span);
    }
  }
  return track.last.$2;
}

// The JS's own keyframes, verbatim.
const _Track _thighNear = [(0, -31), (0.5, 25), (1, -31)];
const _Track _thighFar = [(0, 25), (0.5, -31), (1, 25)];
const _Track _shinNear = [(0, 6), (0.25, 4), (0.5, 13), (0.75, 60), (1, 6)];
const _Track _shinFar = [(0, 13), (0.25, 60), (0.5, 6), (0.75, 4), (1, 13)];
const _Track _armNear = [(0, 27), (0.5, -27), (1, 27)];
const _Track _armFar = [(0, -27), (0.5, 27), (1, -27)];

/// How far the whole figure rises, twice a stride.
const double _bob = 4;

class ManagerWalker extends StatefulWidget {
  const ManagerWalker({
    required this.kit,
    required this.skin,
    required this.hair,
    this.walking = true,
    super.key,
  });

  /// The club's colour — he wears the same kit as the side.
  final Color kit;
  final Color skin;
  final Color hair;

  /// Stopped is a real state: the scene freezes when it is not being watched.
  final bool walking;

  @override
  State<ManagerWalker> createState() => _ManagerWalkerState();
}

class _ManagerWalkerState extends State<ManagerWalker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: walkCycle,
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
  void didUpdateWidget(ManagerWalker old) {
    super.didUpdateWidget(old);
    _sync(context);
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: walkerWidth / walkerHeight,
    child: AnimatedBuilder(
      animation: _clock,
      builder: (context, _) => CustomPaint(
        key: const ValueKey('manager-walker'),
        painter: _WalkerPainter(
          t: _clock.value,
          kit: widget.kit,
          skin: widget.skin,
          hair: widget.hair,
        ),
      ),
    ),
  );
}

class _WalkerPainter extends CustomPainter {
  const _WalkerPainter({
    required this.t,
    required this.kit,
    required this.skin,
    required this.hair,
  });

  final double t;
  final Color kit;
  final Color skin;
  final Color hair;

  /// The far side of the body, darkened. This is the whole of the depth cue.
  Color _shade(Color c) => Color.lerp(c, Colors.black, 0.28)!;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / walkerWidth, size.height / walkerHeight);

    // Twice a stride, and eased — a vertical bounce should decelerate at the
    // top, unlike the limbs.
    final bobT = Curves.easeInOut.transform((t * 2) % 1);
    canvas.translate(0, -_bob * math.sin(bobT * math.pi).abs());

    // FAR limbs first, so the near ones overlap them.
    _leg(canvas, near: false);
    _arm(canvas, near: false);
    _body(canvas);
    _leg(canvas, near: true);
    _arm(canvas, near: true);
    _head(canvas);

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

  void _leg(Canvas canvas, {required bool near}) {
    final legs = near ? kit : _shade(kit);
    final flesh = near ? skin : _shade(skin);
    final boot = near ? const Color(0xFF141414) : const Color(0xFF0B0B0B);
    final thigh = _sample(near ? _thighNear : _thighFar, t);
    final shin = _sample(near ? _shinNear : _shinFar, t);

    _about(canvas, const Offset(58, 96), thigh, () {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(53.5, 96, 9, 30),
          const Radius.circular(4.5),
        ),
        Paint()..color = legs,
      );
      _about(canvas, const Offset(58, 126), shin, () {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(54.5, 126, 7, 24),
            const Radius.circular(3.5),
          ),
          Paint()..color = flesh,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(54.5, 147, 15, 5),
            const Radius.circular(3),
          ),
          Paint()..color = boot,
        );
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
        // The forearm hangs at a fixed break from the upper arm — the JS gives it
        // a static -52° rather than a track of its own.
        _about(canvas, const Offset(56, 80), -52, () {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(53, 80, 6, 17),
              const Radius.circular(3),
            ),
            Paint()..color = flesh,
          );
          canvas.drawCircle(const Offset(56, 96), 3.8, Paint()..color = flesh);
        });
      },
    );
  }

  void _body(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(50.5, 88, 15, 15),
        const Radius.circular(4),
      ),
      Paint()..color = kit,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(50.5, 58, 15, 32),
        const Radius.circular(5),
      ),
      Paint()..color = kit,
    );
  }

  void _head(Canvas canvas) {
    canvas.drawCircle(const Offset(62, 48.5), 12.5, Paint()..color = skin);
    // The hairline descends to the EAR — the head is a circle at (62, 48.5) and
    // the ear sits at its centre, so hair that stopped level across the crown
    // read as a cap perched on the skull rather than hair growing out of it.
    final cap = Path()
      ..moveTo(50.5, 56)
      ..cubicTo(46.5, 46, 50, 33.5, 62, 32.5)
      ..cubicTo(71, 32.5, 75.2, 39.5, 74.4, 45)
      ..cubicTo(71.5, 41.2, 68.5, 40.5, 66, 41.5)
      ..cubicTo(64, 44, 63, 48, 60.5, 51)
      ..cubicTo(58, 53.5, 54.5, 55, 50.5, 56)
      ..close();
    canvas.drawPath(cap, Paint()..color = hair);
  }

  @override
  bool shouldRepaint(_WalkerPainter old) =>
      old.t != t || old.kit != kit || old.skin != skin || old.hair != hair;
}
