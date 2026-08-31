/// **THE SEAL A SHOPFRONT STICKS ON THE WINDOW.**
///
/// Asked for from the couch with a shelf of reference shots: every value claim
/// in a shop that sells well is a stuck-on rosette with a hard edge and a
/// number in it — not a rounded rectangle in the tile's own furniture. The port
/// had two rounded rectangles doing that job, one on the coin tiles and one on
/// the gem tiles, and a pill is what a STATUS looks like. A seal is a thing
/// somebody put there.
///
/// It is a painter rather than a widget tree because the shape is the whole
/// point: a rosette is a radius that varies with angle, which no `BoxDecoration`
/// can express. See [_SealPainter].
///
/// **It carries the text it is given and nothing else.** No new `t()` key can be
/// added from this repo, so every seal in the shop prints a string that already
/// ships — "MOST POPULAR", "BEST VALUE", the computed `shop.coin_value_badge`.
/// That is also why it wraps and scales down rather than clamping to one line:
/// the copy it holds is a translated phrase in ten languages, not a percentage.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

class ValueSeal extends StatelessWidget {
  const ValueSeal({
    super.key,
    required this.text,
    required this.ink,
    required this.onInk,
    this.size = 50,
  });

  /// Shipped copy. Uppercased here, because a seal shouts.
  final String text;

  /// The rosette's face. The deeper ring and the sheen are derived from it, so
  /// a caller passes one colour rather than a palette.
  final Color ink;

  /// What reads on [ink] — the caller's, because the two tiles that wear a seal
  /// already know their own ink pair and a third opinion here would disagree
  /// with one of them.
  final Color onInk;

  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SealPainter(ink: ink),
        // **The text is INSIDE the rosette's own radius, not its box.** The
        // points stick out past the body, so a child sized to the square runs
        // its longest line over them — which is what makes a badge read as a
        // label printed on top of a shape rather than as one object.
        child: Center(
          child: SizedBox(
            width: size * 0.74,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: size * 0.74,
                child: Text(
                  text.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                    color: onInk,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The rosette: a circle whose radius wobbles with the angle.
///
/// Twelve points, because eight reads as a cartoon star and sixteen as a gear.
/// The wobble is a cosine rather than a zig-zag of straight segments — a sticker
/// is die-cut, so its points are round at the tip and round in the valley, and
/// the difference is visible at 50pt.
///
/// Three passes: a drop shadow, the deep ring the face sits inside, and the face
/// itself, scaled in. The ring is what makes it read as printed card stock
/// rather than as a coloured shape, and it is the same trick the store buttons
/// use for their moulded edge.
class _SealPainter extends CustomPainter {
  const _SealPainter({required this.ink});

  final Color ink;

  static const int _points = 12;

  /// How far the tips stand out from the body, as a fraction of the radius.
  static const double _amplitude = 0.11;

  Path _rosette(Offset centre, double radius) {
    final path = Path();
    // 180 segments is six to a point: enough that a tip is a curve rather than
    // a corner at any size this is drawn at, and cheap enough to repaint three
    // times per seal without measuring.
    const steps = 180;
    for (var i = 0; i <= steps; i++) {
      final theta = i / steps * 2 * math.pi;
      // Rotated a half-point off vertical, so the top of the seal is a tip
      // rather than a flat — a rosette with a valley at twelve o'clock reads as
      // a dented circle.
      final r = radius * (1 - _amplitude + _amplitude * math.cos(_points * theta));
      final p = centre + Offset(math.cos(theta) * r, math.sin(theta) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final deep = Color.alphaBlend(Colors.black.withValues(alpha: 0.34), ink);

    canvas.drawPath(
      _rosette(centre + const Offset(0, 1.5), radius),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(_rosette(centre, radius), Paint()..color = deep);
    canvas.drawPath(
      _rosette(centre, radius * 0.88),
      Paint()..color = ink,
    );
    // The light source, on the top third — the same one every moulded control in
    // this game is lit by, so a seal on a tile is lit the way the tile is.
    canvas.save();
    canvas.clipPath(_rosette(centre, radius * 0.88));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.42),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.26),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.42)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SealPainter old) => old.ink != ink;
}
