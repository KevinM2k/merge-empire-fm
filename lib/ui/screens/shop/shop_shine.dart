/// **THE SHELVES DO NOT MOVE, and a shop that does not move is a list.**
///
/// Asked for from the couch: some life in the boxes, and most of it on the
/// special offers. Two effects, because they say different things — a sweep of
/// light travelling across a face says the thing is polished, and a sparkle
/// says it is worth something. The offers get both; a pack shelf gets the
/// sweep alone, because eight tiles all twinkling is a fruit machine.
///
/// **ONE CONTROLLER AND ONE PAINTER PER TILE.** Impeller keeps no raster cache
/// — a `RepaintBoundary` isolates a repaint and stores no pixels — so the cost
/// here is whatever the painter does every frame, and it does a handful of
/// circles and one gradient rect. Nothing is a widget, nothing rebuilds, and
/// the boundary keeps the tile's text and art out of the repaint.
///
/// **AND IT STOPS DEAD FOR A TEST.** A `repeat()`ing controller never lets
/// `pumpAndSettle` return, and the shop suite is a hundred and thirty tests
/// that all call it. `MediaQuery.disableAnimations` is the switch — the same
/// one the match summary's harness already throws — and when it is set this
/// paints ONE still frame and never starts a ticker. See `shop_helpers.dart`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// How long one pass of the light takes, sweep and twinkles together.
const Duration shineCycle = Duration(milliseconds: 5200);

/// **THE MASTER SWITCH, and it exists for the test suite.**
///
/// `MediaQuery.disableAnimations` is the right signal for a PLAYER who has
/// asked for reduced motion, and [TileShine] honours it. It is the wrong tool
/// for the suite: a shop tile turns up in the shell's tests, the home screen's,
/// the club's and the contrast sweep as well as the shop's own, so honouring
/// it would mean finding and wrapping every harness that ever renders one —
/// and the next one written would hang without anybody knowing why.
///
/// `test/flutter_test_config.dart` clears this once for the whole package,
/// which is the one place a Dart test run has for exactly this. Nothing in
/// `lib/` writes it.
bool shopShineEnabled = true;

/// A sweep of light and an optional scatter of sparkles, over a tile's face.
///
/// Sits in a `Positioned.fill` under the tile's content or over it — over, in
/// practice, because a sheen that the art occludes is not a sheen. It never
/// takes a pointer.
class TileShine extends StatefulWidget {
  const TileShine({
    super.key,
    required this.radius,
    this.sparkles = 0,
    this.sweep = true,
    this.seed = 0,
    this.tint = Colors.white,
  });

  /// The corner it is clipped to — the tile's own, or the light spills over
  /// the rounded edge and squares it off.
  final double radius;

  /// How many twinkles. Zero is the quiet form: sweep only.
  final int sparkles;
  final bool sweep;

  /// So two tiles side by side are not in lockstep. The product id's hash does
  /// nicely; anything stable per tile does.
  final int seed;

  /// The light's colour. White on a dark tile, and the tile's own accent when
  /// white would vanish.
  final Color tint;

  @override
  State<TileShine> createState() => _TileShineState();
}

class _TileShineState extends State<TileShine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: shineCycle,
  );

  /// Whether the ticker is allowed to run. Read from `MediaQuery`, so it is
  /// settled in `didChangeDependencies` rather than `initState`.
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still =
        !shopShineEnabled || MediaQuery.of(context).disableAnimations;
    if (still == _still && (_still || _c.isAnimating)) return;
    _still = still;
    if (_still) {
      _c.stop();
      // A frame with the sweep off the face and the sparkles at their dimmest,
      // so a screenshot and a golden both get the tile's resting state.
      _c.value = 0.92;
    } else {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: CustomPaint(
          size: Size.infinite,
          painter: _ShinePainter(
            t: _c,
            sparkles: widget.sparkles,
            sweep: widget.sweep,
            seed: widget.seed,
            tint: widget.tint,
          ),
        ),
      ),
    ),
  );
}

class _ShinePainter extends CustomPainter {
  _ShinePainter({
    required this.t,
    required this.sparkles,
    required this.sweep,
    required this.seed,
    required this.tint,
  }) : super(repaint: t);

  /// The controller itself, as the repaint signal — so the painter is rebuilt
  /// by the ticker and the widget tree is not.
  final Animation<double> t;
  final int sparkles;
  final bool sweep;
  final int seed;
  final Color tint;

  /// The sweep crosses the face in the first part of the cycle and the rest is
  /// the pause. A band that never stops is a strobe.
  static const double _sweepEnds = 0.42;

  /// How wide the band is, as a fraction of the tile's diagonal travel.
  static const double _bandWidth = 0.26;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = t.value;
    if (sweep) _paintSweep(canvas, size, phase);
    if (sparkles > 0) _paintSparkles(canvas, size, phase);
  }

  void _paintSweep(Canvas canvas, Size size, double phase) {
    if (phase > _sweepEnds) return;
    final p = phase / _sweepEnds;
    // Eased, so the light accelerates in and slows out rather than tracking at
    // a constant rate — a constant rate reads as a wipe.
    final eased = Curves.easeInOutSine.transform(p);
    // The band travels from just off the left edge to just off the right, and
    // it leans, because a vertical bar is a loading shimmer.
    final centre = -_bandWidth + eased * (1 + 2 * _bandWidth);
    final rect = Offset.zero & size;
    // Brightest in the middle of the pass and gone at both ends, so it does
    // not pop on at the edge of the tile.
    final strength = math.sin(p * math.pi);
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: const Alignment(-1, -1),
          end: const Alignment(1, 1),
          colors: [
            tint.withValues(alpha: 0),
            tint.withValues(alpha: 0.16 * strength),
            tint.withValues(alpha: 0),
          ],
          stops: [
            (centre - _bandWidth).clamp(0.0, 1.0),
            centre.clamp(0.0, 1.0),
            (centre + _bandWidth).clamp(0.0, 1.0),
          ],
        ).createShader(rect),
    );
    canvas.restore();
  }

  void _paintSparkles(Canvas canvas, Size size, double phase) {
    final rng = math.Random(seed);
    for (var i = 0; i < sparkles; i++) {
      // A fixed home for each, so a tile's twinkles do not wander between
      // frames — the RANDOM is seeded and consumed in the same order every
      // paint, which is what makes that true.
      final x = (0.10 + rng.nextDouble() * 0.80) * size.width;
      final y = (0.12 + rng.nextDouble() * 0.76) * size.height;
      final span = 3.0 + rng.nextDouble() * 2.6;
      // Each on its own clock, or all of them blink together.
      final own = (phase + rng.nextDouble()) % 1;
      // Lit for a third of its cycle and dark for the rest: a sparkle is an
      // event, and one that is always on is a dot.
      if (own > 0.34) continue;
      final k = math.sin(own / 0.34 * math.pi);
      final paint = Paint()..color = tint.withValues(alpha: 0.85 * k);
      final r = span * (0.35 + 0.65 * k);
      // A four-point star, drawn as two tapered slivers — the shape a twinkle
      // is, and four `lineTo`s rather than a blur or an asset.
      final star = Path()
        ..moveTo(x, y - r)
        ..quadraticBezierTo(x, y, x + r * 0.30, y)
        ..quadraticBezierTo(x, y, x, y + r)
        ..quadraticBezierTo(x, y, x - r * 0.30, y)
        ..quadraticBezierTo(x, y, x, y - r)
        ..close();
      canvas.drawPath(star, paint);
      final across = Path()
        ..moveTo(x - r, y)
        ..quadraticBezierTo(x, y, x, y - r * 0.30)
        ..quadraticBezierTo(x, y, x + r, y)
        ..quadraticBezierTo(x, y, x, y + r * 0.30)
        ..quadraticBezierTo(x, y, x - r, y)
        ..close();
      canvas.drawPath(across, paint);
    }
  }

  @override
  bool shouldRepaint(_ShinePainter old) =>
      old.sparkles != sparkles ||
      old.sweep != sweep ||
      old.seed != seed ||
      old.tint != tint;
}
