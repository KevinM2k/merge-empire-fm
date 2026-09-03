/// Paper over a win.
///
/// **Asked for from the couch:** "on the end game screen, if it's victory we
/// should probably have some confetti or something." There was nothing — the
/// full-time screen said VICTORY in large letters and then behaved exactly like
/// the screen that says DEFEAT.
///
/// Three decisions worth keeping, because each of them is a rule this repo
/// already has and a way of getting it wrong:
///
/// **It is the CLUB'S colours, not a rainbow.** `KitTheme` is where every
/// colour in the game comes from and a hardcoded palette is a bug — so the
/// pieces are the kit's accent, its bright variant and white. A win is your
/// club's win, and paper in somebody else's colours reads as stock footage.
///
/// **It is a ONE-SHOT, and that is not a cosmetic choice.** A looping animation
/// asks for a frame for ever: `pumpAndSettle` never returns, so every widget
/// test that reaches a won match hangs, and a phone renders continuously to
/// watch paper that has already landed. It runs [_fall] once and stops.
///
/// **Reduce-motion gets nothing**, the same as the play button's shimmer —
/// falling debris across a whole screen is the first thing that setting is for.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// How long a piece takes to cross the screen and settle.
const Duration confettiFall = Duration(milliseconds: 2600);

/// How many pieces. Enough to read as a fall, few enough that a mid-range phone
/// paints them inside a frame — each is one `drawRect` on a rotated canvas.
const int confettiPieces = 48;

/// One piece's whole life, decided once at construction and then only advanced.
///
/// Deliberately a value rather than state: the painter is handed the same list
/// every frame and reads `t` off the controller, so nothing here is rebuilt and
/// a piece cannot drift between frames.
class ConfettiPiece {
  const ConfettiPiece({
    required this.x,
    required this.delay,
    required this.drift,
    required this.spin,
    required this.width,
    required this.height,
    required this.tint,
  });

  /// Where it starts across the width, 0..1.
  final double x;

  /// How far into the fall it appears, 0..1 — so the paper arrives as a burst
  /// with a tail rather than as one line crossing the screen.
  final double delay;

  /// How far it slides sideways over its fall, in fractions of the width.
  final double drift;

  /// Turns, in whole and part revolutions.
  final double spin;

  final double width;
  final double height;

  /// Which of the three colours, 0..2.
  final int tint;
}

/// Deal [confettiPieces] from [seed], so a given match always falls the same
/// way — a screenshot of full time is reproducible, and nothing re-rolls on a
/// rebuild.
List<ConfettiPiece> dealConfetti(int seed) {
  final rng = math.Random(seed);
  return [
    for (var i = 0; i < confettiPieces; i++)
      ConfettiPiece(
        x: rng.nextDouble(),
        // Squared, so most of the paper is in the first third of the fall and
        // the stragglers thin out — an even spread reads as rain.
        delay: math.pow(rng.nextDouble(), 2).toDouble() * 0.55,
        drift: (rng.nextDouble() - 0.5) * 0.28,
        spin: 1 + rng.nextDouble() * 3,
        width: 5 + rng.nextDouble() * 5,
        height: 8 + rng.nextDouble() * 6,
        tint: i % 3,
      ),
  ];
}

class VictoryConfetti extends StatefulWidget {
  const VictoryConfetti({super.key, this.seed = 0});

  /// What the fall is dealt from — the fixture key, so one match is one fall.
  final int seed;

  @override
  State<VictoryConfetti> createState() => _VictoryConfettiState();
}

class _VictoryConfettiState extends State<VictoryConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: confettiFall,
  );
  late final List<ConfettiPiece> _pieces = dealConfetti(widget.seed);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Nothing falls under reduce-motion, and nothing is scheduled either — the
    // controller is never started, so there is no frame to settle.
    if (MediaQuery.of(context).disableAnimations) return;
    if (!_c.isAnimating && _c.value == 0) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            key: const ValueKey('victory-confetti'),
            size: Size.infinite,
            painter: ConfettiPainter(
              t: _c.value,
              pieces: _pieces,
              tints: [kit.accent, kit.accentBright, Colors.white],
            ),
          ),
        ),
      ),
    );
  }
}

class ConfettiPainter extends CustomPainter {
  const ConfettiPainter({
    required this.t,
    required this.pieces,
    required this.tints,
  });

  final double t;
  final List<ConfettiPiece> pieces;
  final List<Color> tints;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final paint = Paint();
    for (final p in pieces) {
      // Its own clock, started at its delay and normalised back to 0..1 — a
      // piece that has not appeared yet is not drawn at all rather than drawn
      // at the top edge, which would read as a line of paper waiting.
      final span = 1 - p.delay;
      if (span <= 0) continue;
      final local = (t - p.delay) / span;
      if (local <= 0) continue;
      final f = local.clamp(0.0, 1.0);

      // Down the screen, out past the bottom so nothing stops mid-air, and
      // fading over the last quarter so the end is a settle rather than a cut.
      final y = -p.height + f * (size.height + p.height * 2);
      final x = (p.x + p.drift * f) * size.width;
      final alpha = f > 0.75 ? (1 - f) * 4 : 1.0;

      paint.color = tints[p.tint % tints.length]
          .withValues(alpha: alpha.clamp(0.0, 1.0));

      canvas
        ..save()
        ..translate(x, y)
        ..rotate(p.spin * f * 2 * math.pi)
        ..drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.width,
            // Squashed as it turns, which is what makes a rectangle read as a
            // piece of paper rather than as a falling brick.
            height: p.height * math.cos(p.spin * f * 2 * math.pi).abs().clamp(
              0.25,
              1.0,
            ),
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter old) =>
      old.t != t || old.pieces != pieces || old.tints != tints;
}
