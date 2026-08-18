/// The celebration a merge lands with.
///
/// Merging is the game's core action and it landed in silence: two cards
/// became one with no acknowledgement at all.
///
/// The JS flies a ghost of the source card into the target, bursts particles
/// and flashes the cell. The FLY is not ported — the drag has already carried
/// the card there under the player's own finger, so re-flying it is a second
/// movement saying the same thing. What is ported is the payoff: the burst and
/// the pop, at the cell that just changed.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// How long the whole celebration runs.
const Duration mergeBurstDuration = Duration(milliseconds: 480);

/// Particles per burst, scaled by tier so a Legend merge is louder than a
/// bronze one — the JS scales the same way.
int particlesForTier(int tier) => 6 + (tier.clamp(1, 9) * 2);

class MergeBurst extends StatefulWidget {
  const MergeBurst({
    super.key,
    required this.child,
    required this.tier,
    required this.playing,
    this.onDone,
  });

  final Widget child;
  final int tier;

  /// Flipped true for one merge; the burst runs once and reports back.
  final bool playing;
  final VoidCallback? onDone;

  @override
  State<MergeBurst> createState() => MergeBurstState();
}

class MergeBurstState extends State<MergeBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: mergeBurstDuration,
  );

  /// Test seam.
  bool get isPlaying => _controller.isAnimating;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone?.call();
    });
    if (widget.playing) _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(MergeBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing && !oldWidget.playing) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final v = _controller.value;
        if (v == 0) return child!;
        // A quick swell and settle rather than a bounce: the card is landing,
        // not arriving.
        final pop = 1 + math.sin(v * math.pi) * 0.18;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Transform.scale(scale: pop, child: child),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _BurstPainter(
                    progress: v,
                    count: particlesForTier(widget.tier),
                    colour: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter({
    required this.progress,
    required this.count,
    required this.colour,
  });

  final double progress;
  final int count;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || progress <= 0 || progress >= 1) return;
    final centre = Offset(size.width / 2, size.height / 2);
    final reach = size.shortestSide * 0.9 * Curves.easeOut.transform(progress);
    final fade = (1 - progress).clamp(0.0, 1.0);
    final paint = Paint()..color = colour.withValues(alpha: fade);

    for (var i = 0; i < count; i++) {
      // Fixed angles rather than random ones: the burst is the same shape every
      // time, so it reads as the game's punctuation rather than as noise.
      final angle = (i / count) * math.pi * 2;
      final offset = Offset(math.cos(angle), math.sin(angle)) * reach;
      canvas.drawCircle(centre + offset, 2.2 * fade + 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.progress != progress || old.count != count;
}
