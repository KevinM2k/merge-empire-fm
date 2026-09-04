/// Hair that moves strand by strand.
///
/// **A rotating silhouette is a helmet on a hinge.** The first moving hair was
/// the generated SVG rasterised once and turned as a whole about the crown,
/// which is cheap and is exactly what it looks like: one rigid shape swinging.
/// Real hair is anchored at the scalp and free at the ends, so the roots do not
/// move, the tips move most, and the tips arrive LATE — and no two strands
/// arrive together.
///
/// So the mass is DEFORMED rather than turned. The style's own silhouette is
/// taken off the generated art, flattened to a polyline once, and every vertex
/// is sheared sideways by an amount that grows with how far it hangs below the
/// crown and lags the further down it is. Over that, strands: ribbons laid
/// along the mass's own flow, each on its own phase, drawn lighter and darker
/// than the base so the mass reads as hair rather than as a filled shape. The
/// strands take the mass's shear PLUS a ripple of their own, which is what
/// makes them slide against one another.
///
/// **Still cheap.** Parsing and flattening happen once per style string and are
/// memoised; a frame is a few hundred vertices displaced and refilled, on its
/// own raster layer so the skull, the beard and the hat never repaint for it.
///
/// Everything here is in the art's own 120x170 space, against the skull at
/// `skullInArt` — the same circle every generated head layer is drawn against.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/data/manager_art.g.dart';
import 'package:merge_empire_fc/ui/widgets/svg_canvas.dart';

/// The skull the art is drawn against. Duplicated from the walker rather than
/// imported, because the walker imports this.
const double _skullX = 62;
const double _skullY = 48.5;
const Offset _skull = Offset(_skullX, _skullY);
const double _skullR = 12.5;

/// Where hair is attached: the crown, which is the top of the skull. Nothing
/// at or above this line moves.
const double hairCrownY = _skullY - _skullR;

/// One filled shape of a mass, flattened once.
class HairShape {
  const HairShape({required this.points, required this.colour});

  /// A closed polygon, in art units.
  final List<Offset> points;

  /// The fill, alpha included — a buzz cut is a tinted scalp at 0.42.
  final Color colour;
}

/// One strand: a spine down the mass, and how wide it is at each point.
class HairStrand {
  const HairStrand({
    required this.spine,
    required this.widths,
    required this.light,
    required this.phase,
  });

  final List<Offset> spine;
  final List<double> widths;

  /// Lighter than the base, or darker.
  final bool light;

  /// Its own place in the ripple, so no two strands move together.
  final double phase;
}

/// A hair mass — one of a style's two halves — ready to be deformed and drawn.
class HairMass {
  HairMass._(this.shapes, this.strands, this.bounds, this.front);

  final List<HairShape> shapes;
  final List<HairStrand> strands;
  final Rect bounds;

  /// The fall over the brow rather than the mass behind the skull. A fringe
  /// sits ON the skull, so it can only flutter at its tips; the back mass hangs
  /// free and swings its whole length.
  final bool front;

  /// How far the mass hangs below the crown. The deformation is normalised to
  /// it, so a ponytail and a mullet's curtain both reach their full swing at
  /// their own tips.
  double get drop => math.max(6, bounds.bottom - hairCrownY);

  static final Map<String, HairMass> _memo = {};

  /// Parse [svg] once. Memoised on the string, which is what the wardrobe hands
  /// over unchanged frame after frame.
  static HairMass of(String svg, {required bool front}) {
    final key = '${front ? 'f' : 'b'}:$svg';
    final hit = _memo[key];
    if (hit != null) return hit;
    if (_memo.length > 128) _memo.clear();
    return _memo[key] = _parse(svg, front: front);
  }

  static HairMass _parse(String svg, {required bool front}) {
    final shapes = <HairShape>[];
    var bounds = Rect.zero;
    final painter = const SvgPainter(nodes: [], viewBox: Size(1, 1));
    for (final node in parseSvg(svg)) {
      final a = node.attrs;
      final fill = a['fill'];
      // Only the FILLED shapes are the mass. The generator lays a rim stroke,
      // an inner line and two crown arcs over the same silhouette, all
      // `fill="none"`; the strands drawn here replace all three.
      if (fill == null || fill == 'none' || fill.contains('url(')) continue;
      final opacity =
          (double.tryParse(a['opacity'] ?? '') ?? 1) *
          (double.tryParse(a['fill-opacity'] ?? '') ?? 1);
      final colour = svgColour(fill, opacity);
      if (colour == null) continue;
      final path = switch (node.type) {
        'path' => painter.parsePath(a['d']),
        'rect' => _rect(a),
        'circle' => (Path()
          ..addOval(
            Rect.fromCircle(
              center: Offset(_num(a, 'cx'), _num(a, 'cy')),
              radius: _num(a, 'r'),
            ),
          )),
        'ellipse' => (Path()
          ..addOval(
            Rect.fromCenter(
              center: Offset(_num(a, 'cx'), _num(a, 'cy')),
              width: _num(a, 'rx') * 2,
              height: _num(a, 'ry') * 2,
            ),
          )),
        _ => null,
      };
      if (path == null) continue;
      for (final metric in path.computeMetrics()) {
        final pts = _flatten(metric);
        if (pts.length < 3) continue;
        shapes.add(HairShape(points: pts, colour: colour));
        final b = path.getBounds();
        bounds = bounds == Rect.zero ? b : bounds.expandToInclude(b);
      }
    }
    return HairMass._(shapes, _strandsFor(shapes), bounds, front);
  }

  static double _num(Map<String, String> a, String k) =>
      double.tryParse(a[k] ?? '') ?? 0;

  static Path _rect(Map<String, String> a) {
    final r = Rect.fromLTWH(
      _num(a, 'x'),
      _num(a, 'y'),
      _num(a, 'width'),
      _num(a, 'height'),
    );
    final rx = _num(a, 'rx');
    return Path()
      ..addRRect(RRect.fromRectXY(r, rx, double.tryParse(a['ry'] ?? '') ?? rx));
  }

  /// A contour as a polyline, sampled finely enough that a sheared curve stays
  /// a curve. Under a unit apart at this size.
  static List<Offset> _flatten(ui.PathMetric metric) {
    final n = math.max(8, (metric.length / 0.7).ceil());
    return [
      for (var i = 0; i < n; i++)
        metric.getTangentForOffset(metric.length * i / n)!.position,
    ];
  }

  /// Strands laid along each shape's own flow.
  ///
  /// The shape is scanned row by row and each strand keeps a fixed FRACTION
  /// of the row's width, so on a tail that curves the strands curve with it
  /// rather than running straight down through it. Deterministic — the same
  /// style always gets the same strands — because a haircut that re-rolled on
  /// every rebuild would shimmer.
  static List<HairStrand> _strandsFor(List<HairShape> shapes) {
    final out = <HairStrand>[];
    var seed = 7;
    double jitter() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    for (final shape in shapes) {
      // A tinted scalp has no strands to show.
      if (shape.colour.a < 0.6) continue;
      final b = _boundsOf(shape.points);
      if (b.width < 3 || b.height < 5) continue;
      final count = (b.width / 2.6).round().clamp(2, 9);
      for (var k = 0; k < count; k++) {
        final frac = ((k + 0.5) / count + (jitter() - 0.5) * 0.18).clamp(
          0.08,
          0.92,
        );
        final spine = <Offset>[];
        final widths = <double>[];
        // Start a little under the top so the strand grows out of the mass
        // rather than being cut off flat along its top edge.
        for (var y = b.top + 1.2; y < b.bottom - 0.6; y += 1.3) {
          final span = _spanAt(shape.points, y);
          if (span == null) {
            // A gap in the shape (between two spikes): end this strand here.
            if (spine.length >= 3) break;
            spine.clear();
            widths.clear();
            continue;
          }
          final (x0, x1) = span;
          if (x1 - x0 < 1.2) continue;
          final u = ((y - b.top) / b.height).clamp(0.0, 1.0);
          // A gentle bow along the strand, alternating sides, so the strands
          // cross and part rather than running as ruled lines.
          final bow = math.sin(u * math.pi) * 0.7 * (k.isEven ? 1 : -1);
          spine.add(Offset(x0 + (x1 - x0) * frac + bow, y));
          // Thick where it leaves the scalp, fine at the tip.
          widths.add((1.25 - 0.8 * u) * (0.8 + 0.4 * jitter()));
        }
        if (spine.length < 3) continue;
        out.add(
          HairStrand(
            spine: spine,
            widths: widths,
            light: k.isEven,
            phase: jitter() * math.pi * 2,
          ),
        );
      }
    }
    return out;
  }

  static Rect _boundsOf(List<Offset> pts) {
    var l = double.infinity, t = double.infinity;
    var r = double.negativeInfinity, bt = double.negativeInfinity;
    for (final p in pts) {
      if (p.dx < l) l = p.dx;
      if (p.dx > r) r = p.dx;
      if (p.dy < t) t = p.dy;
      if (p.dy > bt) bt = p.dy;
    }
    return Rect.fromLTRB(l, t, r, bt);
  }

  /// The polygon's horizontal extent at row [y], or null where it has none.
  static (double, double)? _spanAt(List<Offset> pts, double y) {
    var lo = double.infinity;
    var hi = double.negativeInfinity;
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i];
      final c = pts[(i + 1) % pts.length];
      if ((a.dy <= y) == (c.dy <= y)) continue;
      final x = a.dx + (c.dx - a.dx) * (y - a.dy) / (c.dy - a.dy);
      if (x < lo) lo = x;
      if (x > hi) hi = x;
    }
    return lo <= hi ? (lo, hi) : null;
  }
}

/// How the mass hangs at one instant: everything the painter needs to place a
/// vertex.
///
/// [swing] is the drive in degrees — `hairSwayAt`'s own number, so the clamp,
/// the lag behind the bob and the settle on a posed head all still apply.
/// [phase] is the stride, for the strands' ripple. [amount] is 0 for a figure
/// that is not moving, which is when the whole thing is a static picture.
class HairMotion {
  const HairMotion({
    required this.swing,
    required this.phase,
    required this.amount,
    double? swingLate,
  }) : swingLate = swingLate ?? swing;

  final double swing;

  /// The same drive read [hairTipLag] earlier in the stride — where the TIPS
  /// are, while [swing] is where the roots are. The painter blends between the
  /// two by depth, which is the whip: the ends are still going one way as the
  /// roots start back.
  final double swingLate;

  final double phase;
  final double amount;

  static const still = HairMotion(swing: 0, phase: 0, amount: 0);

  @override
  bool operator ==(Object other) =>
      other is HairMotion &&
      other.swing == swing &&
      other.swingLate == swingLate &&
      other.phase == phase &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(swing, swingLate, phase, amount);
}

/// How far down the mass the lag reaches, as a fraction of the stride. The tip
/// of a ponytail arrives this much after its root.
const double hairTipLag = 0.07;

/// How much of the ripple a strand adds over the mass, in art units at the
/// tip.
const double hairStrandRipple = 0.55;

/// The sideways shift of a point at depth [u] (0 at the crown, 1 at the tips)
/// for a mass that [drop] units long is swinging by [swing] degrees.
///
/// Pure, and public, so the two claims worth pinning are testable without a
/// canvas: the root does not move, and the tip moves most.
double hairShearAt(
  double u,
  double drop, {
  required double swing,
  required bool front,
}) {
  if (u <= 0) return 0;
  final rad = swing * math.pi / 180;
  // A rigid turn would move a point `drop·u·tan(θ)`. Raising u makes the
  // roots stiffer and the ends freer, which is the whole difference between
  // hair and a pendulum.
  final rigid = drop * u * math.tan(rad);
  final shape = front ? u * u : math.pow(u, 1.5).toDouble();
  // A fringe sits on the skull and can only flutter; it takes a third.
  return rigid * shape * (front ? 0.35 : 1);
}

/// Where a point of the mass goes under [motion] — the shear, and for a strand
/// its own ripple on top.
Offset hairDisplace(
  Offset p,
  HairMass mass,
  HairMotion motion, {
  double strandPhase = double.nan,
}) {
  if (motion.amount <= 0) return p;
  final u = ((p.dy - hairCrownY) / mass.drop).clamp(0.0, 1.0);
  if (u <= 0) return p;
  // Points still on the skull are held by it, whatever their depth: a fringe's
  // side falls past the ear without leaving the head.
  final hold = ((p - _skull).distance - _skullR) / 5;
  final free = mass.front ? 1.0 : hold.clamp(0.0, 1.0);
  if (free <= 0) return p;
  var dx = hairShearAt(
    u,
    mass.drop,
    swing: motion.swing + (motion.swingLate - motion.swing) * u,
    front: mass.front,
  );
  if (!strandPhase.isNaN) {
    // Twice a stride, like the bob the swing follows, but on the strand's own
    // phase and growing toward the tip — so neighbours cross and uncross.
    dx +=
        math.sin(motion.phase * 4 * math.pi + strandPhase) *
        hairStrandRipple *
        u *
        u *
        motion.amount *
        (mass.front ? 0.5 : 1);
  }
  return Offset(p.dx + dx * free, p.dy);
}

/// One hair mass, drawn deformed.
class HairPainter extends CustomPainter {
  const HairPainter({
    required this.mass,
    required this.motion,
    this.hideAbove,
    this.clipToSkull = false,
    this.soft = true,
  });

  final HairMass mass;
  final HairMotion motion;

  /// A hat's brow line: nothing above it is drawn. See `HeadLayer.hideAbove`.
  final double? hideAbove;

  /// Kept inside the skull, for a fringe under something snug. See
  /// `HeadLayer.clipToSkull`.
  final bool clipToSkull;

  /// Blurred sheen. Off for a still.
  final bool soft;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || mass.shapes.isEmpty) return;
    canvas.save();
    canvas.scale(size.width / managerArtWidth, size.height / managerArtHeight);
    final above = hideAbove;
    if (above != null) {
      canvas.clipRect(
        Rect.fromLTRB(-50, above, managerArtWidth + 50, managerArtHeight),
      );
    }
    if (clipToSkull) {
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: _skull, radius: _skullR)),
      );
    }

    // The whole mass, as one silhouette, so the strands can be clipped to it
    // and the edge shaded once.
    final silhouette = Path();
    for (final shape in mass.shapes) {
      final path = _deformed(shape.points);
      silhouette.addPath(path, Offset.zero);
      final b = path.getBounds();
      // Lit from above: the crown catches the sky and the underside falls into
      // shade. A flat fill is what made the old mass a helmet.
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            b.topCenter,
            b.bottomCenter,
            [
              _lift(shape.colour, 0.14),
              shape.colour,
              _deepen(shape.colour, 0.30),
            ],
            const [0, 0.42, 1],
          ),
      );
    }

    // A tinted scalp is shading, not a mass — no strands, no rim.
    final solid = mass.shapes.any((s) => s.colour.a >= 0.6);
    if (!solid) {
      canvas.restore();
      return;
    }

    canvas.save();
    canvas.clipPath(silhouette);
    for (final strand in mass.strands) {
      _paintStrand(canvas, strand);
    }
    // Ambient occlusion where the hair meets the head: a soft dark band just
    // above the brow and round the back of the skull, which seats the mass ON
    // the head instead of in front of it.
    if (soft) {
      canvas.drawCircle(
        _skull,
        _skullR + 0.6,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
      );
    }
    // The edge, darkened INSIDE the silhouette: an outline that is shading
    // rather than a drawn line, which is the cartoon-but-not-flat look.
    canvas.drawPath(
      silhouette,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.26)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
    canvas.restore();
  }

  Path _deformed(List<Offset> pts) {
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final p = hairDisplace(pts[i], mass, motion);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  /// A strand as a ribbon: the spine displaced on its own phase, widened
  /// either side, and shaded along its length — a sheen a little below the
  /// root, fading to nothing at the tip.
  void _paintStrand(Canvas canvas, HairStrand strand) {
    final n = strand.spine.length;
    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 0; i < n; i++) {
      final p = hairDisplace(
        strand.spine[i],
        mass,
        motion,
        strandPhase: strand.phase,
      );
      final w = strand.widths[i] / 2;
      left.add(Offset(p.dx - w, p.dy));
      right.add(Offset(p.dx + w, p.dy));
    }
    final ribbon = Path()..moveTo(left.first.dx, left.first.dy);
    for (final p in left.skip(1)) {
      ribbon.lineTo(p.dx, p.dy);
    }
    for (final p in right.reversed) {
      ribbon.lineTo(p.dx, p.dy);
    }
    ribbon.close();
    final top = strand.spine.first.dy;
    final bottom = strand.spine.last.dy;
    final paint = Paint()
      ..shader = strand.light
          ? ui.Gradient.linear(
              Offset(0, top),
              Offset(0, bottom),
              [
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.30),
                Colors.white.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.03),
              ],
              const [0, 0.22, 0.55, 1],
            )
          : ui.Gradient.linear(
              Offset(0, top),
              Offset(0, bottom),
              [
                Colors.black.withValues(alpha: 0.10),
                Colors.black.withValues(alpha: 0.22),
                Colors.black.withValues(alpha: 0.30),
              ],
              const [0, 0.5, 1],
            );
    canvas.drawPath(ribbon, paint);
  }

  @override
  bool shouldRepaint(HairPainter old) =>
      old.mass != mass ||
      old.motion != motion ||
      old.hideAbove != hideAbove ||
      old.clipToSkull != clipToSkull ||
      old.soft != soft;
}

Color _lift(Color c, double amount) => Color.lerp(c, Colors.white, amount)!;
Color _deepen(Color c, double amount) => Color.lerp(c, Colors.black, amount)!;
