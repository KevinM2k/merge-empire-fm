/// Draws the subset of SVG the game's artwork is built from.
///
/// Not a general SVG renderer and not trying to be one. The artwork composes
/// everything from primitives — rects with optional corner radii, circles,
/// ellipses, polygons, lines, text and paths — so this covers exactly that and
/// nothing else. A dependency would be a lot of machinery for eight element
/// types.
///
/// **Two things it did not cover, and both were losing artwork.**
///
/// - **Cubic segments.** The path parser knew `M`, `L`, `Q` and `Z`, and `C` is
///   not in that set — so a cubic's numbers were swallowed by the command before
///   it and the curve was never drawn. Every one of the manager avatar's 66
///   paths is a cubic, which is why the walking figure hand-transcribes its hair
///   instead of drawing the part that was generated for it.
/// - **Gradients.** A `fill="url(#id)"` resolved to no colour at all, and a
///   shape with no fill and no stroke is skipped — so the club art's twenty
///   gradient fills were drawing NOTHING, not even a flat approximation.
///
/// Both are in now, along with the relative path commands and `H`/`V`/`S`/`T`,
/// which cost a dozen lines once a proper current-point is tracked.
///
/// Anything it still does not understand is SKIPPED rather than thrown on: art
/// is decoration, and a tile that fails to draw one flourish should still draw
/// the stadium.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

final RegExp _tag = RegExp(r'<(\w+)([^>]*?)/?>', multiLine: true);
final RegExp _attr = RegExp(r'([\w:-]+)\s*=\s*"([^"]*)"');
final RegExp _textTag = RegExp(r'<text([^>]*)>([^<]*)</text>', multiLine: true);
final RegExp _viewBox = RegExp(r'viewBox\s*=\s*"([^"]*)"');
/// One SVG number.
///
/// NOT `-?[\d.]+`: path data packs numbers without separators, so `1.5.35` is
/// two of them — `1.5` and `.35` — and the greedy form swallowed both and then
/// threw on the result. Every compact path in the artwork hit this.
final RegExp _number = RegExp(r'[+-]?(?:\d*\.\d+|\d+\.?)(?:[eE][+-]?\d+)?');
final RegExp _gradientTag = RegExp(
  r'<(linearGradient|radialGradient)([^>]*)>(.*?)</\1>',
  multiLine: true,
  dotAll: true,
);
final RegExp _stopTag = RegExp(r'<stop([^>]*?)/?>', multiLine: true);
final RegExp _urlRef = RegExp(r'url\(#([^)]+)\)');

/// A gradient from `<defs>`, in the only units the artwork uses:
/// `objectBoundingBox`, where 0..1 spans the shape being filled. That is why it
/// is resolved per SHAPE rather than once — the same `<defs>` entry paints a tall
/// stand and a small badge differently, which is the point of it.
typedef SvgGradient = ({
  bool radial,
  List<double> offsets,
  List<Color> colours,
  double x1,
  double y1,
  double x2,
  double y2,
  double cx,
  double cy,
  double r,
});

/// One drawable, already parsed.
typedef SvgNode = ({String type, Map<String, String> attrs, String text});

/// The gradients [svg] defines, by id.
///
/// Lifted out before the generic pass because a gradient is a PARENT with stop
/// children, and the flat tag scan cannot see that relationship.
Map<String, SvgGradient> parseGradients(String svg) {
  final out = <String, SvgGradient>{};
  for (final m in _gradientTag.allMatches(svg)) {
    final attrs = _attrsOf(m.group(2) ?? '');
    final id = attrs['id'];
    if (id == null || id.isEmpty) continue;

    final offsets = <double>[];
    final colours = <Color>[];
    for (final stop in _stopTag.allMatches(m.group(3) ?? '')) {
      final sa = _attrsOf(stop.group(1) ?? '');
      final colour = _colour(
        sa['stop-color'],
        double.tryParse(sa['stop-opacity'] ?? '') ?? 1.0,
      );
      if (colour == null) continue;
      offsets.add(_offset(sa['offset'], offsets.length));
      colours.add(colour);
    }
    // One stop is not a gradient, and Flutter needs at least two.
    if (colours.length < 2) continue;

    out[id] = (
      radial: m.group(1) == 'radialGradient',
      offsets: offsets,
      colours: colours,
      x1: double.tryParse(attrs['x1'] ?? '') ?? 0,
      y1: double.tryParse(attrs['y1'] ?? '') ?? 0,
      x2: double.tryParse(attrs['x2'] ?? '') ?? 1,
      y2: double.tryParse(attrs['y2'] ?? '') ?? 0,
      cx: double.tryParse(attrs['cx'] ?? '') ?? 0.5,
      cy: double.tryParse(attrs['cy'] ?? '') ?? 0.5,
      r: double.tryParse(attrs['r'] ?? '') ?? 0.5,
    );
  }
  return out;
}

/// A stop's offset, which the artwork writes both ways — `0.5` and `50%`.
///
/// Flutter needs ascending values in 0..1 and asserts on the rest, so a stop
/// with no readable offset falls back to its INDEX clamped into range rather
/// than to a number that would trip the assert.
double _offset(String? raw, int index) {
  final text = (raw ?? '').trim();
  if (text.endsWith('%')) {
    final pct = double.tryParse(text.substring(0, text.length - 1));
    if (pct != null) return (pct / 100).clamp(0.0, 1.0);
  }
  final direct = double.tryParse(text);
  if (direct != null) return direct.clamp(0.0, 1.0);
  return index == 0 ? 0.0 : 1.0;
}

/// Parse [svg] into the nodes this painter understands, in document order.
List<SvgNode> parseSvg(String svg) {
  final nodes = <SvgNode>[];
  // Text carries its content between the tags, so it is lifted out first and
  // its opening tag then skipped by the generic pass.
  final texts = <int, SvgNode>{};
  for (final m in _textTag.allMatches(svg)) {
    texts[m.start] = (
      type: 'text',
      attrs: _attrsOf(m.group(1) ?? ''),
      text: (m.group(2) ?? '').trim(),
    );
  }

  for (final m in _tag.allMatches(svg)) {
    final type = m.group(1)!;
    if (type == 'svg' || type == 'defs' || type == 'g') continue;
    // Gradients are lifted by [parseGradients]; their stops are not drawables.
    if (type == 'linearGradient' ||
        type == 'radialGradient' ||
        type == 'stop') {
      continue;
    }
    if (type == 'text') {
      final lifted = texts[m.start];
      if (lifted != null) nodes.add(lifted);
      continue;
    }
    nodes.add((type: type, attrs: _attrsOf(m.group(2) ?? ''), text: ''));
  }
  return nodes;
}

Map<String, String> _attrsOf(String raw) => {
  for (final a in _attr.allMatches(raw)) a.group(1)!: a.group(2)!,
};

/// The `viewBox` the artwork was drawn against. Defaults to the 80×80 the club
/// art uses.
Size viewBoxOf(String svg) {
  final m = _viewBox.firstMatch(svg);
  if (m == null) return const Size(80, 80);
  final parts = _number
      .allMatches(m.group(1)!)
      .map((n) => n.group(0)!)
      .toList();
  if (parts.length < 4) return const Size(80, 80);
  return Size(double.parse(parts[2]), double.parse(parts[3]));
}

final _rotate = RegExp(r'rotate\(\s*(-?[\d.]+)[,\s]+(-?[\d.]+)[,\s]+(-?[\d.]+)\s*\)');

final _rgba = RegExp(
  r'rgba?\(\s*([\d.]+)[,\s]+([\d.]+)[,\s]+([\d.]+)\s*(?:[,/]\s*([\d.]+)\s*)?\)',
);

Color? _colour(String? value, double opacity) {
  if (value == null || value.isEmpty || value == 'none') return null;
  var hex = value.trim();
  // The icon set rims its coins in `rgba(0,0,0,0.30)`, and hex-only parsing
  // dropped every one of those strokes.
  final rgb = _rgba.firstMatch(hex);
  if (rgb != null) {
    double c(int g) => (double.tryParse(rgb.group(g) ?? '') ?? 0).clamp(0, 255);
    final a = double.tryParse(rgb.group(4) ?? '') ?? 1.0;
    return Color.fromARGB(
      ((a * opacity).clamp(0.0, 1.0) * 255).round(),
      c(1).round(),
      c(2).round(),
      c(3).round(),
    );
  }
  if (!hex.startsWith('#')) return null;
  hex = hex.substring(1);
  if (hex.length == 3 || hex.length == 4) {
    hex = hex.split('').map((c) => '$c$c').join();
  }
  // #rrggbbaa — how the reveal writes its tier glows (`${glow}66`).
  var alpha = opacity;
  if (hex.length == 8) {
    final a = int.tryParse(hex.substring(6), radix: 16);
    if (a != null) alpha *= a / 255;
    hex = hex.substring(0, 6);
  }
  if (hex.length != 6) return null;
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return null;
  return Color(0xFF000000 | parsed).withValues(alpha: alpha.clamp(0.0, 1.0));
}

double _n(Map<String, String> a, String key, [double fallback = 0]) =>
    double.tryParse(a[key] ?? '') ?? fallback;

/// Paints parsed [nodes], scaled from their view box into the given size.
class SvgPainter extends CustomPainter {
  const SvgPainter({
    required this.nodes,
    required this.viewBox,
    this.gradients = const {},
  });

  final List<SvgNode> nodes;
  final Size viewBox;

  /// The `<defs>` gradients, by id. Empty for artwork that has none.
  final Map<String, SvgGradient> gradients;

  /// The paint for one attribute — a colour, or a gradient resolved against the
  /// shape's own [bounds], which is what `objectBoundingBox` units mean.
  ///
  /// Returns null when there is nothing to draw, which is what keeps a `none`
  /// fill from painting black.
  Paint? _paintFor(String? value, double opacity, Rect bounds) {
    if (value == null || value.isEmpty || value == 'none') return null;
    final ref = _urlRef.firstMatch(value);
    if (ref == null) {
      final colour = _colour(value, opacity);
      return colour == null ? null : (Paint()..color = colour);
    }
    final g = gradients[ref.group(1)];
    if (g == null || bounds.isEmpty) return null;

    final colours = [
      for (final c in g.colours) c.withValues(alpha: c.a * opacity),
    ];
    final shader = g.radial
        ? RadialGradient(
            center: Alignment(g.cx * 2 - 1, g.cy * 2 - 1),
            radius: g.r,
            colors: colours,
            stops: g.offsets,
          ).createShader(bounds)
        : LinearGradient(
            begin: Alignment(g.x1 * 2 - 1, g.y1 * 2 - 1),
            end: Alignment(g.x2 * 2 - 1, g.y2 * 2 - 1),
            colors: colours,
            stops: g.offsets,
          ).createShader(bounds);
    return Paint()..shader = shader;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || viewBox.isEmpty) return;
    canvas.save();
    canvas.scale(size.width / viewBox.width, size.height / viewBox.height);

    for (final node in nodes) {
      final a = node.attrs;
      final opacity = double.tryParse(a['opacity'] ?? '') ?? 1.0;
      // The shape's own box, for a gradient in bounding-box units. Computed per
      // node and BEFORE the paints, because the paint depends on it.
      final bounds = _boundsOf(node);
      // Per-channel opacity. Half the icon set tints a fill under its own
      // stroke with `fill-opacity`, and ignoring it painted those solid.
      final fillO = opacity * (double.tryParse(a['fill-opacity'] ?? '') ?? 1.0);
      final strokeO =
          opacity * (double.tryParse(a['stroke-opacity'] ?? '') ?? 1.0);
      final fillP = _paintFor(a['fill'], fillO, bounds);
      final strokeP = _paintFor(a['stroke'], strokeO, bounds);
      final strokeWidth = _n(a, 'stroke-width', 1);
      // Read as booleans below, so the switch reads the way it did.
      final fill = fillP;
      final stroke = strokeP;

      Paint fillPaint() => fillP!;
      Paint strokePaint() => Paint()
        ..shader = strokeP!.shader
        ..color = strokeP.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = switch (a['stroke-linecap']) {
          'round' => StrokeCap.round,
          'square' => StrokeCap.square,
          _ => StrokeCap.butt,
        }
        ..strokeJoin = switch (a['stroke-linejoin']) {
          'round' => StrokeJoin.round,
          'bevel' => StrokeJoin.bevel,
          _ => StrokeJoin.miter,
        };

      // `transform="rotate(deg cx cy)"` — the bandage icon is a rect drawn
      // straight and then turned, and without this it lay flat.
      final xform = _rotate.firstMatch(a['transform'] ?? '');
      if (xform != null) {
        canvas.save();
        canvas.translate(
          double.tryParse(xform.group(2) ?? '') ?? 0,
          double.tryParse(xform.group(3) ?? '') ?? 0,
        );
        canvas.rotate((double.tryParse(xform.group(1)!) ?? 0) * math.pi / 180);
        canvas.translate(
          -(double.tryParse(xform.group(2) ?? '') ?? 0),
          -(double.tryParse(xform.group(3) ?? '') ?? 0),
        );
      }

      switch (node.type) {
        case 'rect':
          final rect = Rect.fromLTWH(
            _n(a, 'x'),
            _n(a, 'y'),
            _n(a, 'width'),
            _n(a, 'height'),
          );
          final r = _n(a, 'rx');
          if (fill != null) {
            r > 0
                ? canvas.drawRRect(
                    RRect.fromRectXY(rect, r, _n(a, 'ry', r)),
                    fillPaint(),
                  )
                : canvas.drawRect(rect, fillPaint());
          }
          if (stroke != null) {
            r > 0
                ? canvas.drawRRect(
                    RRect.fromRectXY(rect, r, _n(a, 'ry', r)),
                    strokePaint(),
                  )
                : canvas.drawRect(rect, strokePaint());
          }

        case 'circle':
          final c = Offset(_n(a, 'cx'), _n(a, 'cy'));
          final r = _n(a, 'r');
          if (fill != null) canvas.drawCircle(c, r, fillPaint());
          if (stroke != null) canvas.drawCircle(c, r, strokePaint());

        case 'ellipse':
          final rect = Rect.fromCenter(
            center: Offset(_n(a, 'cx'), _n(a, 'cy')),
            width: _n(a, 'rx') * 2,
            height: _n(a, 'ry') * 2,
          );
          if (fill != null) canvas.drawOval(rect, fillPaint());
          if (stroke != null) canvas.drawOval(rect, strokePaint());

        case 'line':
          if (stroke != null) {
            canvas.drawLine(
              Offset(_n(a, 'x1'), _n(a, 'y1')),
              Offset(_n(a, 'x2'), _n(a, 'y2')),
              strokePaint(),
            );
          }

        case 'polygon':
          final path = _polygon(a['points']);
          if (path == null) break;
          if (fill != null) canvas.drawPath(path, fillPaint());
          if (stroke != null) canvas.drawPath(path, strokePaint());

        case 'path':
          final path = parsePath(a['d']);
          if (path == null) break;
          if (fill != null) canvas.drawPath(path, fillPaint());
          if (stroke != null) canvas.drawPath(path, strokePaint());

        case 'text':
          _drawText(canvas, node, (fillP ?? strokeP)?.color);

        default:
          // Unknown element: skip it. A missing flourish beats a blank tile.
          break;
      }
      if (xform != null) canvas.restore();
    }
    canvas.restore();
  }

  /// The box a shape occupies, in view-box units.
  ///
  /// Only a gradient needs this, and only shapes that carry one pay for it: a
  /// path's bounds mean building the path, which the draw does again a moment
  /// later. Cheap enough for artwork of this size, and the alternative is
  /// threading the path through two places.
  Rect _boundsOf(SvgNode node) {
    final a = node.attrs;
    final wantsGradient =
        (a['fill']?.contains('url(#') ?? false) ||
        (a['stroke']?.contains('url(#') ?? false);
    if (!wantsGradient) return Rect.zero;

    switch (node.type) {
      case 'rect':
        return Rect.fromLTWH(
          _n(a, 'x'),
          _n(a, 'y'),
          _n(a, 'width'),
          _n(a, 'height'),
        );
      case 'circle':
        final r = _n(a, 'r');
        return Rect.fromCircle(
          center: Offset(_n(a, 'cx'), _n(a, 'cy')),
          radius: r,
        );
      case 'ellipse':
        return Rect.fromCenter(
          center: Offset(_n(a, 'cx'), _n(a, 'cy')),
          width: _n(a, 'rx') * 2,
          height: _n(a, 'ry') * 2,
        );
      case 'line':
        return Rect.fromPoints(
          Offset(_n(a, 'x1'), _n(a, 'y1')),
          Offset(_n(a, 'x2'), _n(a, 'y2')),
        );
      case 'polygon':
        return _polygon(a['points'])?.getBounds() ?? Rect.zero;
      case 'path':
        return parsePath(a['d'])?.getBounds() ?? Rect.zero;
      default:
        return Rect.zero;
    }
  }

  void _drawText(Canvas canvas, SvgNode node, Color? colour) {
    if (node.text.isEmpty || colour == null) return;
    final a = node.attrs;
    final size = _n(a, 'font-size', 8);
    final bold =
        (a['font-weight'] ?? '') != '' && (a['font-weight'] != 'normal');
    final painter = TextPainter(
      text: TextSpan(
        text: node.text,
        style: TextStyle(
          color: colour,
          fontSize: size,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final x = a['text-anchor'] == 'middle'
        ? _n(a, 'x') - painter.width / 2
        : _n(a, 'x');
    // SVG places text on its BASELINE; Flutter places it at the top.
    painter.paint(canvas, Offset(x, _n(a, 'y') - painter.height * 0.8));
  }

  Path? _polygon(String? points) {
    if (points == null) return null;
    final nums = _number
        .allMatches(points)
        .map((m) => double.parse(m.group(0)!))
        .toList();
    if (nums.length < 6) return null;
    final path = Path()..moveTo(nums[0], nums[1]);
    for (var i = 2; i + 1 < nums.length; i += 2) {
      path.lineTo(nums[i], nums[i + 1]);
    }
    return path..close();
  }

  /// Every command the artwork uses: `M L H V C S Q T Z`, absolute and relative.
  ///
  /// Public because it is the only way to PROVE a segment was drawn: a dropped
  /// curve leaves a path whose bounds are the start point, and nothing about
  /// painting says so out loud.
  ///
  /// **`C` was the one that mattered.** It was not in the old command class, so
  /// a cubic's six numbers were read as extra arguments to whatever came before
  /// it — usually the opening `M`, which used the first two and dropped the rest.
  /// Nothing threw and nothing drew; the manager avatar's 66 paths are all
  /// cubics.
  ///
  /// A current point and the last control point are tracked, because the
  /// relative forms and the smooth forms (`S`, `T`) are both defined in terms of
  /// them.
  ///
  /// `A` is in as well, and it was worth checking rather than assuming: the club
  /// art draws every crowd seat as a half-circle arc, so hundreds of them were
  /// being dropped. Flutter's `arcToPoint` takes exactly SVG's endpoint
  /// parameterisation, so it costs a handful of lines rather than the
  /// centre-parameterisation conversion it looks like it should.
  Path? parsePath(String? d) {
    if (d == null || d.isEmpty) return null;
    final path = Path();
    final commands = RegExp(
      r'([MLHVCSQTAZmlhvcsqtaz])([^MLHVCSQTAZmlhvcsqtaz]*)',
    ).allMatches(d);
    var started = false;
    // Where the pen is, and the reflection a smooth segment needs.
    var cx = 0.0;
    var cy = 0.0;
    var startX = 0.0;
    var startY = 0.0;
    var ctrlX = 0.0;
    var ctrlY = 0.0;
    var lastWasCurve = false;

    for (final c in commands) {
      final raw = c.group(1)!;
      final op = raw.toUpperCase();
      final rel = raw != op;
      final nums = _number
          .allMatches(c.group(2) ?? '')
          .map((m) => double.parse(m.group(0)!))
          .toList();

      double ax(double v) => rel ? cx + v : v;
      double ay(double v) => rel ? cy + v : v;

      switch (op) {
        case 'M':
          for (var i = 0; i + 1 < nums.length; i += 2) {
            final x = ax(nums[i]);
            final y = ay(nums[i + 1]);
            // A move with several pairs continues as a LINE, per the spec.
            if (i == 0) {
              path.moveTo(x, y);
              startX = x;
              startY = y;
              started = true;
            } else {
              path.lineTo(x, y);
            }
            cx = x;
            cy = y;
          }
          lastWasCurve = false;

        case 'L':
          for (var i = 0; i + 1 < nums.length; i += 2) {
            cx = ax(nums[i]);
            cy = ay(nums[i + 1]);
            path.lineTo(cx, cy);
          }
          lastWasCurve = false;

        case 'H':
          for (final v in nums) {
            cx = rel ? cx + v : v;
            path.lineTo(cx, cy);
          }
          lastWasCurve = false;

        case 'V':
          for (final v in nums) {
            cy = rel ? cy + v : v;
            path.lineTo(cx, cy);
          }
          lastWasCurve = false;

        case 'C':
          for (var i = 0; i + 5 < nums.length; i += 6) {
            final x1 = ax(nums[i]);
            final y1 = ay(nums[i + 1]);
            final x2 = ax(nums[i + 2]);
            final y2 = ay(nums[i + 3]);
            final x = ax(nums[i + 4]);
            final y = ay(nums[i + 5]);
            path.cubicTo(x1, y1, x2, y2, x, y);
            ctrlX = x2;
            ctrlY = y2;
            cx = x;
            cy = y;
          }
          lastWasCurve = true;

        case 'S':
          for (var i = 0; i + 3 < nums.length; i += 4) {
            // The first control point is the reflection of the last one.
            final x1 = lastWasCurve ? 2 * cx - ctrlX : cx;
            final y1 = lastWasCurve ? 2 * cy - ctrlY : cy;
            final x2 = ax(nums[i]);
            final y2 = ay(nums[i + 1]);
            final x = ax(nums[i + 2]);
            final y = ay(nums[i + 3]);
            path.cubicTo(x1, y1, x2, y2, x, y);
            ctrlX = x2;
            ctrlY = y2;
            cx = x;
            cy = y;
            lastWasCurve = true;
          }

        case 'Q':
          for (var i = 0; i + 3 < nums.length; i += 4) {
            final x1 = ax(nums[i]);
            final y1 = ay(nums[i + 1]);
            final x = ax(nums[i + 2]);
            final y = ay(nums[i + 3]);
            path.quadraticBezierTo(x1, y1, x, y);
            ctrlX = x1;
            ctrlY = y1;
            cx = x;
            cy = y;
            lastWasCurve = true;
          }

        case 'T':
          for (var i = 0; i + 1 < nums.length; i += 2) {
            final x1 = lastWasCurve ? 2 * cx - ctrlX : cx;
            final y1 = lastWasCurve ? 2 * cy - ctrlY : cy;
            final x = ax(nums[i]);
            final y = ay(nums[i + 1]);
            path.quadraticBezierTo(x1, y1, x, y);
            ctrlX = x1;
            ctrlY = y1;
            cx = x;
            cy = y;
            lastWasCurve = true;
          }

        case 'A':
          // rx ry x-rotation large-arc-flag sweep-flag x y
          for (var i = 0; i + 6 < nums.length; i += 7) {
            final x = ax(nums[i + 5]);
            final y = ay(nums[i + 6]);
            path.arcToPoint(
              Offset(x, y),
              radius: Radius.elliptical(nums[i].abs(), nums[i + 1].abs()),
              rotation: nums[i + 2],
              largeArc: nums[i + 3] != 0,
              clockwise: nums[i + 4] != 0,
            );
            cx = x;
            cy = y;
          }
          lastWasCurve = false;

        case 'Z':
          path.close();
          cx = startX;
          cy = startY;
          lastWasCurve = false;
      }
    }
    return started ? path : null;
  }

  @override
  bool shouldRepaint(SvgPainter old) =>
      old.nodes != nodes || old.gradients != gradients;
}

/// Draws an SVG string at whatever size it is given.
class SvgArt extends StatelessWidget {
  SvgArt({super.key, required String svg})
    : nodes = parseSvg(svg),
      viewBox = viewBoxOf(svg),
      gradients = parseGradients(svg);

  final List<SvgNode> nodes;
  final Size viewBox;
  final Map<String, SvgGradient> gradients;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: SvgPainter(nodes: nodes, viewBox: viewBox, gradients: gradients),
    size: Size.infinite,
  );
}
