/// The dim, the hole, the ring and the hand — ported from `Tutorial.js`'s
/// `#tutorial-hole`, `#tut-ring` and `#tut-hand`.
///
/// **A step that waits on the save has to let the player REACH the thing.**
/// That is the whole reason this exists rather than a card: the JS lays a
/// full-screen blocker over the app and forwards a tap inside the target's rect
/// to the control underneath, so the only thing on screen that can be pressed
/// is the one being taught. A modal card cannot do that — it eats every tap,
/// including the one the step is asking for.
///
/// **The hole is a HOLE, not a lighter rectangle.** It is cut with
/// `BlendMode.dstOut` so what shows through is the live control, still
/// animating, still the player's own kit colours — a redrawn copy would drift
/// from the real one the moment either changed.
///
/// **And the input hole is four rectangles, not a hit-test override.** The dim
/// is painted by one `IgnorePointer` layer and the blocking is done by four
/// `AbsorbPointer`s laid around the hole, so the gap in the middle has no
/// widget over it at all and the tap simply lands on the app. A painter that
/// lied in `hitTest` would block or pass the whole layer, never a region of it.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// How round the cut-out's corners are. The JS's own 14px.
const double spotlightRadius = 14;

/// How far outside the control the hole and the ring sit.
const double spotlightPad = 6;

/// The scrim over everything that is not the target. The JS's `rgba(0,0,0,.72)`.
const Color spotlightScrim = Color(0xB8000000);

class TutorialSpotlight extends StatelessWidget {
  const TutorialSpotlight({super.key, required this.target, this.child});

  /// Where the control is, in global coordinates — or null, which dims the
  /// whole screen and shows neither ring nor hand. That is the JS's "no target"
  /// branch and it is a normal state: the control may be on a tab still
  /// animating in, or scrolled out of view.
  final Rect? target;

  /// The tooltip, laid over the top.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final hole = target?.inflate(spotlightPad);

    return Stack(
      key: const ValueKey('tutorial-spotlight'),
      children: [
        // The dim, with the hole cut out of it. Never takes a tap — the four
        // blockers below decide what does.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _ScrimPainter(hole)),
          ),
        ),
        ..._blockersAround(hole),
        if (hole != null) ...[
          Positioned(
            key: const ValueKey('tutorial-ring'),
            left: hole.left,
            top: hole.top,
            width: hole.width,
            height: hole.height,
            child: IgnorePointer(child: _Ring(colour: kit.accentBright)),
          ),
          // Under the control, pointing up at it — the JS puts it two pixels
          // below the bottom edge, centred.
          Positioned(
            key: const ValueKey('tutorial-hand'),
            left: hole.center.dx - 17,
            top: hole.bottom + 2,
            width: 34,
            height: 40,
            child: const IgnorePointer(child: _TapHand()),
          ),
        ],
        ?child,
      ],
    );
  }

  /// The four rectangles that eat taps everywhere except the hole.
  ///
  /// With no target the whole screen is blocked, which is right: a step with
  /// nothing to point at is one the player answers on the card.
  List<Widget> _blockersAround(Rect? hole) {
    if (hole == null) {
      return const [Positioned.fill(child: AbsorbPointer())];
    }
    return [
      Positioned(left: 0, right: 0, top: 0, height: math.max(0, hole.top),
          child: const AbsorbPointer()),
      Positioned(left: 0, right: 0, top: hole.bottom, bottom: 0,
          child: const AbsorbPointer()),
      Positioned(left: 0, width: math.max(0, hole.left), top: hole.top,
          height: hole.height, child: const AbsorbPointer()),
      Positioned(left: hole.right, right: 0, top: hole.top,
          height: hole.height, child: const AbsorbPointer()),
    ];
  }
}

class _ScrimPainter extends CustomPainter {
  const _ScrimPainter(this.hole);

  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    // A layer, so `dstOut` has something of its own to punch through rather
    // than clearing whatever the app had already drawn.
    canvas.saveLayer(bounds, Paint());
    canvas.drawRect(bounds, Paint()..color = spotlightScrim);
    if (hole != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(hole!, const Radius.circular(spotlightRadius)),
        Paint()..blendMode = BlendMode.dstOut,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.hole != hole;
}

/// The ring, expanding and fading on a loop — the same nudge the floating
/// coach's head wears, at the size of whatever it is drawn around.
class _Ring extends StatefulWidget {
  const _Ring({required this.colour});

  final Color colour;

  @override
  State<_Ring> createState() => _RingState();
}

class _RingState extends State<_Ring> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    builder: (context, _) {
      final t = _pulse.value;
      return Transform.scale(
        scale: 1 + t * 0.08,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(spotlightRadius),
            border: Border.all(
              color: widget.colour.withValues(alpha: 1 - t),
              width: 2.5,
            ),
          ),
        ),
      );
    },
  );
}

/// The pointing hand, path for path off `Tutorial.js`'s inline SVG.
class _TapHand extends StatelessWidget {
  const _TapHand();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _HandPainter());
}

class _HandPainter extends CustomPainter {
  const _HandPainter();

  /// The JS's own `viewBox="0 0 40 46"`.
  static const Size _viewBox = Size(40, 46);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _viewBox.width, size.height / _viewBox.height);
    final path = Path()
      ..moveTo(13, 21)
      ..lineTo(13, 7)
      ..quadraticBezierTo(13, 3, 16.5, 3)
      ..quadraticBezierTo(20, 3, 20, 7)
      ..lineTo(20, 19)
      ..quadraticBezierTo(20, 16, 24, 16)
      ..quadraticBezierTo(27, 16, 27, 19)
      ..lineTo(27, 21)
      ..quadraticBezierTo(27, 18, 30, 18)
      ..quadraticBezierTo(33, 18, 33, 21)
      ..lineTo(33, 23)
      ..quadraticBezierTo(33, 21, 35, 21)
      ..quadraticBezierTo(37.5, 21, 37.5, 24)
      ..lineTo(37.5, 33)
      ..quadraticBezierTo(37.5, 42, 26, 42)
      ..lineTo(20, 42)
      ..quadraticBezierTo(13, 42, 9, 37)
      ..lineTo(3.5, 29)
      ..quadraticBezierTo(1.5, 26, 4, 24)
      ..quadraticBezierTo(6.5, 22, 8.5, 25)
      ..lineTo(13, 31)
      ..close();
    // White with a dark outline, which is what makes it read on a dimmed
    // screen AND on whatever colour the control underneath happens to be.
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF1A1F2E),
    );
  }

  @override
  bool shouldRepaint(_HandPainter old) => false;
}
