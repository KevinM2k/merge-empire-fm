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
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// The turf, its mown bands and the shading down the top.
const List<Color> _turf = [
  Color(0xFF173F22),
  Color(0xFF1B4A28),
  Color(0xFF153A20),
];

/// The LIGHT theme's grass. The dark gradient above read as a dark slab in the
/// middle of a white page, so the JS ships a second one — a proper daylit pitch
/// rather than the same green lifted a shade.
const List<Color> _turfLight = [
  Color(0xFF4A9E57),
  Color(0xFF58AC65),
  Color(0xFF479A54),
];

class SquadPitch extends StatelessWidget {
  const SquadPitch({required this.child, super.key});

  /// The slots, positioned by the caller in the pitch's own box.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final kit = Theme.of(context).extension<KitTheme>()!;

    // The pitch is a CENTRED CARD at 7:10, so on most phones there is bare page
    // either side of it. Filling that with a wash of the pitch's own colour is
    // what stops the surrounding gaps reading as holes in the screen — the JS
    // does the same thing ("fill the surrounding gaps with the pitch's...",
    // screens.css:25) and the port had left the page background showing through.
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: light
              ? [
                  Color.lerp(_turfLight.first, kit.bg, 0.55)!,
                  Color.lerp(_turfLight.last, kit.bg, 0.7)!,
                ]
              : [
                  Color.lerp(_turf.first, kit.bg, 0.5)!,
                  Color.lerp(_turf.last, kit.bg, 0.72)!,
                ],
        ),
      ),
      child: Center(
        child: AspectRatio(
          aspectRatio: 7 / 10,
          child: DecoratedBox(
            key: const ValueKey('squad-pitch-surface'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: light ? _turfLight : _turf,
                stops: const [0, 0.45, 1],
              ),
            ),
            // NOT clipped. The JS has `overflow:hidden` here, but its tokens are
            // centred on their percentage and the outermost ones overhang the
            // touchline by a few pixels — clipping shaves a slice off the wide
            // players rather than off nothing.
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _PitchPainter(light: light)),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  const _PitchPainter({required this.light});

  /// A daylit pitch takes DARKER markings and a gentler mow: white lines on
  /// bright green wash out, and the same 2.8%-white bands that read as mown
  /// stripes on near-black are invisible on it.
  final bool light;

  @override
  void paint(Canvas canvas, Size size) {
    // Mown bands, eight across the length. Painted before the markings so the
    // lines sit on top of them.
    final band = Paint()
      ..color = Colors.white.withValues(alpha: light ? 0.10 : 0.028);
    final shade = Paint()
      ..color = Colors.black.withValues(alpha: light ? 0.035 : 0.05);
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
            Colors.black.withValues(alpha: light ? 0.05 : 0.30),
            Colors.black.withValues(alpha: light ? 0.02 : 0.10),
            Colors.transparent,
          ],
          stops: const [0, 0.49, 1],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.45)),
    );

    // Markings, in the JS's own 100×140 space, stretched to the box.
    canvas.save();
    canvas.scale(size.width / 100, size.height / 140);
    final ink = light ? Colors.white.withValues(alpha: 0.85) : Colors.white;
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3;
    final thin = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.26;
    final dot = Paint()..color = ink;

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
  bool shouldRepaint(_PitchPainter oldDelegate) => oldDelegate.light != light;
}
