/// A card's portrait.
///
/// `data/player_art.dart` carries the variant table — skin, hair colour, hair
/// style, gender — and its header notes that the JS file's inline SVG
/// portraits are "UI work for a later milestone". This is that milestone.
///
/// A `CustomPainter` rather than an asset or an SVG dependency, for the same
/// reason the club art will be: the source draws these from primitives, and six
/// variants times every definition is a lot of files for a handful of circles.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/data/player_art.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

class PlayerPortrait extends StatelessWidget {
  const PlayerPortrait({
    super.key,
    required this.variantIndex,
    required this.kitColor,
  });

  /// Wraps, matching the JS modulo — a card from a future build with a variant
  /// this catalogue has not got must still draw something.
  final int variantIndex;

  /// The club's colour, so a squad reads as one team.
  final Color kitColor;

  @override
  Widget build(BuildContext context) {
    final variant = variants.isEmpty
        ? null
        : variants[variantIndex.abs() % variants.length];
    if (variant == null) return const SizedBox.shrink();

    return CustomPaint(
      key: const ValueKey('player-portrait'),
      painter: _PortraitPainter(variant: variant, kit: kitColor),
      size: Size.infinite,
    );
  }
}

class _PortraitPainter extends CustomPainter {
  const _PortraitPainter({required this.variant, required this.kit});

  final PlayerVariant variant;
  final Color kit;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final skin = Paint()..color = cssColor(variant.skin);
    final hair = Paint()..color = cssColor(variant.hair);
    final shirt = Paint()..color = kit;

    final headR = w * 0.24;
    final headC = Offset(w / 2, h * 0.42);

    // Shoulders first, so the head sits on top of them.
    final body = Path()
      ..moveTo(w * 0.16, h)
      ..quadraticBezierTo(w * 0.5, h * 0.58, w * 0.84, h)
      ..close();
    canvas.drawPath(body, shirt);

    // Long hair falls behind the head and the shoulders both.
    if (variant.hairStyle == 'long') {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(headC.dx, headC.dy + headR * 0.35),
          width: headR * 2.5,
          height: headR * 2.9,
        ),
        hair,
      );
    }

    canvas.drawCircle(headC, headR, skin);

    // The fringe: a cap over the top of the head, skipped when bald.
    if (variant.hairStyle != 'bald') {
      canvas.drawArc(
        Rect.fromCircle(center: headC, radius: headR),
        3.14159,
        3.14159,
        true,
        hair,
      );
    }

    // Eyes, small and dark. Enough to read as a face at 60px.
    final eye = Paint()..color = const Color(0xFF2B2B2B);
    canvas.drawCircle(
      Offset(headC.dx - headR * 0.34, headC.dy + headR * 0.1),
      headR * 0.1,
      eye,
    );
    canvas.drawCircle(
      Offset(headC.dx + headR * 0.34, headC.dy + headR * 0.1),
      headR * 0.1,
      eye,
    );
  }

  @override
  bool shouldRepaint(_PortraitPainter old) =>
      old.variant != variant || old.kit != kit;
}
