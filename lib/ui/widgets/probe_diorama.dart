import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Probe for the League diorama. Renders a representative slice of the scene —
/// three parallax bands, a day/night tint, and a rain system — two ways, so M3
/// can pick a technique on measured evidence rather than preference.
///
/// The real scene runs 103 concurrent CSS keyframes today. The open question is
/// whether one painter driven by a single ticker beats a tree of individually
/// animated widgets, which is the structural equivalent of the current DOM.
///
/// Throwaway: this is a measurement rig, not the beginning of the real scene.
class ProbeDiorama extends StatefulWidget {
  const ProbeDiorama({
    required this.usePainter,
    this.rainDrops = 60,
    super.key,
  });

  final bool usePainter;
  final int rainDrops;

  @override
  State<ProbeDiorama> createState() => _ProbeDioramaState();
}

class _ProbeDioramaState extends State<ProbeDiorama>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return widget.usePainter
            ? CustomPaint(
                painter: DioramaPainter(t: t, rainDrops: widget.rainDrops),
                child: const SizedBox.expand(),
              )
            : _WidgetTreeScene(t: t, rainDrops: widget.rainDrops);
      },
    );
  }
}

/// One painter, one ticker, no per-element widgets.
class DioramaPainter extends CustomPainter {
  const DioramaPainter({required this.t, required this.rainDrops});

  final double t;
  final int rainDrops;

  @override
  void paint(Canvas canvas, Size size) {
    // Day/night tint.
    final night = (math.sin(t * 2 * math.pi) + 1) / 2;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = Color.lerp(
          const Color(0xFF87CEEB),
          const Color(0xFF12203A),
          night,
        )!,
    );

    // Three parallax bands at different rates.
    for (var band = 0; band < 3; band++) {
      final rate = 0.25 * (band + 1);
      final y = size.height * (0.45 + band * 0.16);
      final offset = (t * rate * size.width) % size.width;
      final paint = Paint()
        ..color = Colors.black.withValues(alpha: 0.12 + band * 0.1);
      for (var x = -size.width; x < size.width * 2; x += 64) {
        canvas.drawRect(Rect.fromLTWH(x + offset, y, 40, 18), paint);
      }
    }

    // Rain.
    final drop = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1.5;
    for (var i = 0; i < rainDrops; i++) {
      final seed = i / rainDrops;
      final x = seed * size.width;
      final y = ((t + seed) % 1) * size.height;
      canvas.drawLine(Offset(x, y), Offset(x - 3, y + 12), drop);
    }
  }

  @override
  bool shouldRepaint(DioramaPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.rainDrops != rainDrops;
}

/// The same scene as a widget tree — one widget per rain drop, which is the
/// structural equivalent of the current DOM approach.
class _WidgetTreeScene extends StatelessWidget {
  const _WidgetTreeScene({required this.t, required this.rainDrops});

  final double t;
  final int rainDrops;

  @override
  Widget build(BuildContext context) {
    final night = (math.sin(t * 2 * math.pi) + 1) / 2;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: Color.lerp(
                  const Color(0xFF87CEEB),
                  const Color(0xFF12203A),
                  night,
                )!,
              ),
            ),
            for (var i = 0; i < rainDrops; i++)
              Positioned(
                // Keyed siblings must be unique, so index the key rather than
                // sharing one across every drop.
                key: ValueKey('rain-drop-$i'),
                left: (i / rainDrops) * w,
                top: ((t + i / rainDrops) % 1) * h,
                child: Container(
                  width: 2,
                  height: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
          ],
        );
      },
    );
  }
}
