/// The two striped kits' background.
///
/// turf and humbug are `repeating-linear-gradient` in the CSS; the other four
/// are smooth gradients and need no painter.
library;

import 'package:flutter/material.dart';

/// Vertical bands, dark first, repeating every `darkWidth + lightWidth`.
class StripeDecoration extends Decoration {
  const StripeDecoration({
    required this.dark,
    required this.light,
    required this.darkWidth,
    required this.lightWidth,
  });

  final Color dark;
  final Color light;
  final double darkWidth;
  final double lightWidth;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _StripePainter(this);

  @override
  bool operator ==(Object other) =>
      other is StripeDecoration &&
      other.dark == dark &&
      other.light == light &&
      other.darkWidth == darkWidth &&
      other.lightWidth == lightWidth;

  @override
  int get hashCode => Object.hash(dark, light, darkWidth, lightWidth);
}

class _StripePainter extends BoxPainter {
  _StripePainter(this.decoration);

  final StripeDecoration decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final size = cfg.size ?? Size.zero;
    final period = decoration.darkWidth + decoration.lightWidth;
    if (period <= 0 || size.isEmpty) return;
    final dark = Paint()..color = decoration.dark;
    final light = Paint()..color = decoration.light;
    canvas.save();
    canvas.clipRect(offset & size);
    for (var x = 0.0; x < size.width; x += period) {
      canvas.drawRect(
        Rect.fromLTWH(
          offset.dx + x,
          offset.dy,
          decoration.darkWidth,
          size.height,
        ),
        dark,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          offset.dx + x + decoration.darkWidth,
          offset.dy,
          decoration.lightWidth,
          size.height,
        ),
        light,
      );
    }
    canvas.restore();
  }
}
