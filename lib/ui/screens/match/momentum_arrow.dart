/// Which way the game is going, drawn on the pitch it is going on.
///
/// **The pitch used to come and go.** It was mounted only for a chance and taken
/// away after, and what stood in its place between chances was the statistics —
/// so the band flipped between a football pitch and a table of numbers every few
/// minutes. The pitch stays now, and this is what it shows when nothing is
/// happening on it: one arrow, pointing at the goal the run of play is heading
/// for, drifting toward that goal as the pressure builds.
///
/// It is a READING, not a simulation. Nothing here decides anything — the match
/// was over before the screen opened — and the only input is the same possession
/// figure the stat board prints.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The two shades the arrow is drawn in, both taken off `PitchBackdrop.turf`
/// (`#2D6A2D`). Ours reads as a lit stripe, theirs as a shadow on the same
/// grass — one colour each, and neither of them see-through.
const Color momentumOurs = Color(0xFF4E9C4A);
const Color momentumTheirs = Color(0xFF1C4A22);

/// How much of the game is OURS, from -1 (all theirs) to 1 (all ours).
///
/// [possHome] is the stat board's own possession, home-positive and already
/// clamped to 28–72; [isHome] turns that into our share. It says nothing about
/// which way the arrow points — that is [MomentumArrow.attackingRight], because
/// which end we are shooting at is a fact about the fixture rather than about
/// who is on top.
double momentumBias({required int possHome, required bool isHome}) {
  final ourShare = isHome ? possHome : 100 - possHome;
  return ((ourShare - 50) / 22).clamp(-1.0, 1.0);
}

/// The arrow, and the glide between two readings.
///
/// Animated rather than snapped: possession moves on every chance, and an arrow
/// that jumps reads as a bug rather than as a game swinging.
class MomentumArrow extends StatelessWidget {
  const MomentumArrow({
    required this.bias,
    required this.attackingRight,
    required this.ours,
    required this.theirs,
    super.key,
  });

  /// From [momentumBias]. Positive is US on top, whichever way we are kicking.
  final double bias;

  /// Which way OUR goals go. **At home we attack right and away we attack
  /// left** — the same rule the 2D pitch follows, so the arrow and the passage
  /// of play it turns into cannot point opposite ways.
  final bool attackingRight;

  /// The colour of a move going our way, and of one going theirs.
  final Color ours;
  final Color theirs;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: attackingRight ? bias : -bias),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(
        key: const ValueKey('match-momentum'),
        size: Size.infinite,
        painter: _ArrowPainter(
          bias: t,
          // Whose move it is, which is NOT which way it is going: away from
          // home, our best spell points left.
          ours: attackingRight ? ours : theirs,
          theirs: attackingRight ? theirs : ours,
        ),
      ),
    ),
  );
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({
    required this.bias,
    required this.ours,
    required this.theirs,
  });

  final double bias;
  final Color ours;
  final Color theirs;

  @override
  void paint(Canvas canvas, Size size) {
    final right = bias >= 0;
    final strength = bias.abs();
    // Never nothing. A dead-level game is still a game being played, and an
    // empty pitch reads as a screen that has stopped working.
    final reach = 0.30 + 0.34 * strength;
    // **OPAQUE, and ONE colour.** It was the kit at 30–75% alpha, so the mown
    // stripes ran straight through it and the arrow read as a smear rather than
    // as a mark on the grass. A solid shade of the turf itself is what a pitch
    // graphic actually looks like — ours a shade lighter than the grass, theirs
    // a shade darker, so which way the game is going is legible before the
    // direction is.
    final colour = right ? ours : theirs;

    // The shaft slides toward the goal being attacked as the pressure builds —
    // pointing left and creeping left is the away side getting the better of it.
    final centre = Offset(size.width * (0.5 + bias * 0.20), size.height * 0.5);
    final half = size.width * reach / 2;
    final from = Offset(centre.dx - (right ? half : -half), centre.dy);
    final to = Offset(centre.dx + (right ? half : -half), centre.dy);

    final thickness = size.height * (0.105 + 0.05 * strength);
    final paint = Paint()
      ..color = colour
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(from, to, paint);

    // The head, as two strokes off the tip rather than a filled triangle: the
    // same cap and width as the shaft, so the whole mark is one drawn line.
    final head = thickness * 1.7;
    final back = right ? -1.0 : 1.0;
    for (final sign in [-1.0, 1.0]) {
      canvas.drawLine(
        to,
        to + Offset(back * head * math.cos(0.5), sign * head * math.sin(0.5)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.bias != bias || old.ours != ours || old.theirs != theirs;
}
