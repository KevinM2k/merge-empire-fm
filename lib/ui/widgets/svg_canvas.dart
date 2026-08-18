/// Draws the subset of SVG the game's artwork is built from.
///
/// Not a general SVG renderer and not trying to be one. `assets/clubArt.js`
/// composes everything from primitives — rects with optional corner radii,
/// circles, ellipses, polygons, lines, text, and paths of straight and
/// quadratic segments — so this covers exactly that and nothing else. A
/// dependency would be a lot of machinery for eight element types.
///
/// Anything it does not understand is SKIPPED rather than thrown on: art is
/// decoration, and a tile that fails to draw one flourish should still draw the
/// stadium.
library;

import 'package:flutter/material.dart';

final RegExp _tag = RegExp(r'<(\w+)([^>]*?)/?>', multiLine: true);
final RegExp _attr = RegExp(r'([\w:-]+)\s*=\s*"([^"]*)"');
final RegExp _textTag = RegExp(
  r'<text([^>]*)>([^<]*)</text>',
  multiLine: true,
);
final RegExp _viewBox = RegExp(r'viewBox\s*=\s*"([^"]*)"');
final RegExp _number = RegExp(r'-?[\d.]+');

/// One drawable, already parsed.
typedef SvgNode = ({String type, Map<String, String> attrs, String text});

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
  final parts = _number.allMatches(m.group(1)!).map((n) => n.group(0)!).toList();
  if (parts.length < 4) return const Size(80, 80);
  return Size(double.parse(parts[2]), double.parse(parts[3]));
}

Color? _colour(String? value, double opacity) {
  if (value == null || value.isEmpty || value == 'none') return null;
  var hex = value.trim();
  if (!hex.startsWith('#')) return null;
  hex = hex.substring(1);
  if (hex.length == 3) {
    hex = hex.split('').map((c) => '$c$c').join();
  }
  if (hex.length != 6) return null;
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return null;
  return Color(0xFF000000 | parsed).withValues(alpha: opacity.clamp(0.0, 1.0));
}

double _n(Map<String, String> a, String key, [double fallback = 0]) =>
    double.tryParse(a[key] ?? '') ?? fallback;

/// Paints parsed [nodes], scaled from their view box into the given size.
class SvgPainter extends CustomPainter {
  const SvgPainter({required this.nodes, required this.viewBox});

  final List<SvgNode> nodes;
  final Size viewBox;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || viewBox.isEmpty) return;
    canvas.save();
    canvas.scale(size.width / viewBox.width, size.height / viewBox.height);

    for (final node in nodes) {
      final a = node.attrs;
      final opacity = double.tryParse(a['opacity'] ?? '') ?? 1.0;
      final fill = _colour(a['fill'], opacity);
      final stroke = _colour(a['stroke'], opacity);
      final strokeWidth = _n(a, 'stroke-width', 1);

      Paint fillPaint() => Paint()..color = fill!;
      Paint strokePaint() => Paint()
        ..color = stroke!
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

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
          if (stroke != null) canvas.drawRect(rect, strokePaint());

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
          final path = _path(a['d']);
          if (path == null) break;
          if (fill != null) canvas.drawPath(path, fillPaint());
          if (stroke != null) canvas.drawPath(path, strokePaint());

        case 'text':
          _drawText(canvas, node, fill ?? stroke);

        default:
          // Unknown element: skip it. A missing flourish beats a blank tile.
          break;
      }
    }
    canvas.restore();
  }

  void _drawText(Canvas canvas, SvgNode node, Color? colour) {
    if (node.text.isEmpty || colour == null) return;
    final a = node.attrs;
    final size = _n(a, 'font-size', 8);
    final bold = (a['font-weight'] ?? '') != '' &&
        (a['font-weight'] != 'normal');
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

  /// M, L and Q only — straight and quadratic segments, which is all the
  /// artwork uses.
  Path? _path(String? d) {
    if (d == null || d.isEmpty) return null;
    final path = Path();
    final commands = RegExp(r'([MLQZmlqz])([^MLQZmlqz]*)').allMatches(d);
    var started = false;
    for (final c in commands) {
      final op = c.group(1)!.toUpperCase();
      final nums = _number
          .allMatches(c.group(2) ?? '')
          .map((m) => double.parse(m.group(0)!))
          .toList();
      switch (op) {
        case 'M':
          if (nums.length >= 2) {
            path.moveTo(nums[0], nums[1]);
            started = true;
          }
        case 'L':
          for (var i = 0; i + 1 < nums.length; i += 2) {
            path.lineTo(nums[i], nums[i + 1]);
          }
        case 'Q':
          for (var i = 0; i + 3 < nums.length; i += 4) {
            path.quadraticBezierTo(nums[i], nums[i + 1], nums[i + 2], nums[i + 3]);
          }
        case 'Z':
          path.close();
      }
    }
    return started ? path : null;
  }

  @override
  bool shouldRepaint(SvgPainter old) => old.nodes != nodes;
}

/// Draws an SVG string at whatever size it is given.
class SvgArt extends StatelessWidget {
  SvgArt({super.key, required String svg})
    : nodes = parseSvg(svg),
      viewBox = viewBoxOf(svg);

  final List<SvgNode> nodes;
  final Size viewBox;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: SvgPainter(nodes: nodes, viewBox: viewBox),
    size: Size.infinite,
  );
}
