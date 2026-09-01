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
    this.focus = const Rect.fromLTRB(0.08, 0.08, 0.92, 0.92),
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

  /// Where the twinkles land, in fractions of the tile.
  ///
  /// **A SPARKLE IS ABOUT SOMETHING.** Scattered over the whole tile they read
  /// as dust on the glass; clustered on the pile of coins or the stack of
  /// diamonds they read as the thing catching the light, which is the point of
  /// putting them on the treasure shelves at all. Reported from the couch:
  /// closer to the diamonds, and closer to the coins.
  final Rect focus;

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
            focus: widget.focus,
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
    required this.focus,
  }) : super(repaint: t);

  /// The controller itself, as the repaint signal — so the painter is rebuilt
  /// by the ticker and the widget tree is not.
  final Animation<double> t;
  final int sparkles;
  final bool sweep;
  final int seed;
  final Color tint;
  final Rect focus;

  /// The sweep crosses the face in the first part of the cycle and the rest is
  /// the pause. A band that never stops is a strobe.
  static const double _sweepEnds = 0.42;

  /// How wide the band is, as a fraction of the tile's diagonal travel.
  static const double _bandWidth = 0.26;

  /// How much of its own cycle a sparkle is lit for. Longer than the first cut
  /// — at a third, three sparkles on a tile meant most frames had one showing
  /// and some had none, which reads as nothing happening.
  static const double _litFor = 0.45;

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
      final x =
          (focus.left + rng.nextDouble() * focus.width) * size.width;
      final y = (focus.top + rng.nextDouble() * focus.height) * size.height;
      // **BIGGER, because they were specks.** Five to eight and a half points
      // is a glint on a 180-point tile; reported from the couch as tiny.
      final span = 9.0 + rng.nextDouble() * 5.0;
      // Each on its own clock, or all of them blink together.
      final own = (phase + rng.nextDouble()) % 1;
      // Lit for part of its cycle and dark for the rest: a sparkle is an
      // event, and one that is always on is a dot.
      if (own > _litFor) continue;
      final k = math.sin(own / _litFor * math.pi);
      final r = span * (0.4 + 0.6 * k);

      // **A TWINKLE NEEDS A CORE.** The first cut was two crossed slivers at a
      // 30% waist, which on a 5-point arm is a hairline about one and a half
      // points wide — drawn, and invisible. Reported from the couch: the
      // gleam goes across but there are no sparkles. A star reads from the
      // bright point at its middle; the arms are what say it is a star and not
      // a dot.
      canvas.drawCircle(
        Offset(x, y),
        r * 0.30,
        Paint()..color = tint.withValues(alpha: 0.95 * k),
      );
      final paint = Paint()..color = tint.withValues(alpha: 0.8 * k);
      // Four points, as two crossed slivers — the shape a twinkle is, and a
      // path rather than a blur or an asset.
      const waist = 0.34;
      final star = Path()
        ..moveTo(x, y - r)
        ..quadraticBezierTo(x, y, x + r * waist, y)
        ..quadraticBezierTo(x, y, x, y + r)
        ..quadraticBezierTo(x, y, x - r * waist, y)
        ..quadraticBezierTo(x, y, x, y - r)
        ..close();
      canvas.drawPath(star, paint);
      final across = Path()
        ..moveTo(x - r, y)
        ..quadraticBezierTo(x, y, x, y - r * waist)
        ..quadraticBezierTo(x, y, x + r, y)
        ..quadraticBezierTo(x, y, x, y + r * waist)
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
      old.tint != tint ||
      old.focus != focus;
}
