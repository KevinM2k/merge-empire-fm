/// The pitch the eleven stand on. Ported from `_pitchSVG` and `.squad-pitch`
/// in `ui/screens/SquadScreen.js`.
///
/// The slots were floating on the page background, which made the formation a
/// list of cards in the shape of a formation rather than a team on a pitch.
///
/// **7:10, and fitted to BOTH axes.** The JS computes the largest ratio-correct
/// box that fits rather than letting CSS pick, because its pitch layers are
/// absolutely positioned and have no intrinsic size. `AspectRatio` inside a
/// `Center` is that, and it is one widget.
///
/// The markings are drawn in a `0 0 100 140` space and stretched — the JS uses
/// `preserveAspectRatio="none"` — so the box, the D and the centre circle all
/// distort with the pitch instead of letterboxing inside it.
library;

import 'package:flutter/material.dart';

/// The turf, its mown bands and the shading down the top.
const List<Color> _turf = [
  Color(0xFF173F22),
  Color(0xFF1B4A28),
  Color(0xFF153A20),
];

class SquadPitch extends StatelessWidget {
  const SquadPitch({required this.child, super.key});

  /// The slots, positioned by the caller in the pitch's own box.
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: AspectRatio(
      aspectRatio: 7 / 10,
      child: DecoratedBox(
        key: const ValueKey('squad-pitch-surface'),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _turf,
            stops: [0, 0.45, 1],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _PitchPainter()),
            child,
          ],
        ),
      ),
    ),
  );
}

class _PitchPainter extends CustomPainter {
  const _PitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Mown bands, eight across the length. Painted before the markings so the
    // lines sit on top of them.
    final band = Paint()..color = Colors.white.withValues(alpha: 0.028);
    final shade = Paint()..color = Colors.black.withValues(alpha: 0.05);
    for (var i = 0; i < 8; i++) {
      final top = size.height * i / 8;
      canvas.drawRect(
        Rect.fromLTWH(0, top, size.width, size.height / 16),
        band,
      );
      canvas.drawRect(
        Rect.fromLTWH(0, top + size.height / 16, size.width, size.height / 16),
        shade,
      );
    }
    // A wash down from the top, so the far end reads as further away.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.45),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.30),
            Colors.black.withValues(alpha: 0.10),
            Colors.transparent,
          ],
          stops: const [0, 0.49, 1],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.45)),
    );

    // Markings, in the JS's own 100×140 space, stretched to the box.
    canvas.save();
    canvas.scale(size.width / 100, size.height / 140);
    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3;
    final thin = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.26;
    final dot = Paint()..color = Colors.white;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, 2, 96, 136),
        const Radius.circular(2),
      ),
      line,
    );
    canvas.drawLine(const Offset(2, 70), const Offset(98, 70), line);
    canvas.drawCircle(const Offset(50, 70), 13, line);
    canvas.drawCircle(const Offset(50, 70), 0.8, dot);

    // Our end.
    canvas.drawRect(const Rect.fromLTWH(22, 116, 56, 22), thin);
    canvas.drawRect(const Rect.fromLTWH(36, 130, 28, 8), thin);
    canvas.drawCircle(const Offset(50, 124), 0.8, dot);
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(50, 116), radius: 13),
      3.4557, // the D, opening away from the box
      2.3702,
      false,
      thin,
    );

    // Theirs.
    canvas.drawRect(const Rect.fromLTWH(22, 2, 56, 22), thin);
    canvas.drawRect(const Rect.fromLTWH(36, 2, 28, 8), thin);
    canvas.drawCircle(const Offset(50, 16), 0.8, dot);
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(50, 24), radius: 13),
      0.3143,
      2.3702,
      false,
      thin,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PitchPainter oldDelegate) => false;
}
