/// What says a lift is LIVE: the bands on the progress bar, the glow round the
/// figures, and the one-at-a-time caption under them.
///
/// **The bar already means time**, so a window is a segment of it — the player
/// sees when it started and when it ends in the one control that already says
/// how far in the match is. Flame for Roar, a grey wash for Bus: the visual
/// opposite, for the boost that is the tactical opposite.
///
/// **Nothing here changes SIZE while animating.** A widget that grows every
/// frame relayouts past any `RepaintBoundary` to the route and repaints the
/// whole shell — the HUD coin count-up has already cost this once. The glow
/// moves opacity and colour inside a fixed box; the pill fades; the bands are
/// positioned once per minute, not per frame.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/engine/match_boost_state.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// The fire the Roar burns in. Not kit colours and deliberately not: a flame
/// is a flame whatever the club wears, the way the level metals on the trait
/// reel are bronze, silver and gold on every kit.
const Color flameHot = Color(0xFFFFE08A);
const Color flameMid = Color(0xFFFF8A3D);
const Color flameDeep = Color(0xFFD9481C);

/// The gold Sharp Shooting burns in: the feed's own colour for a chance
/// converting, so the bar and the line under it agree.
const Color goldHot = Color(0xFFFFF3C4);
const Color goldMid = Color(0xFFFFC542);
const Color goldDeep = Color(0xFFB8860B);

/// Which whole-bar burn is on at this minute, or null for a band or nothing.
/// A Roar and a Sharp Shooting together: the Roar's fire wins the bar, the
/// gold keeps its band.
String? barBurn(List<LiveBoost> windows) {
  if (windows.any((b) => b.id == 'crowd_roar')) return 'crowd_roar';
  if (windows.any((b) => b.id == 'sharp_shooting')) return 'sharp_shooting';
  return null;
}

/// The fill and ground the clock wears under a burn.
({Color fill, Color ground}) burnColours(String burn) => burn == 'crowd_roar'
    ? (fill: flameMid, ground: flameDeep.withValues(alpha: 0.35))
    : (fill: goldMid, ground: goldDeep.withValues(alpha: 0.35));

/// Whether a Roar is live at this minute: the bar burns whole, not a band.
bool roarLive(List<LiveBoost> windows) => windows.any((b) => b.id == 'crowd_roar');

/// **THE WHOLE BAR BURNS WHILE A ROAR IS LIVE.** A band from 40' to 65' told
/// the player when the window was and not that they were IN it — reported as
/// unclear where we are in that. So the clock's own fill keeps its transition
/// and turns flame, and a looping fire-and-lightning pass runs over the full
/// width until the window closes. The Bus keeps its grey band: it is the
/// tactical opposite and should not look like the same thing.
class FlameOverlay extends StatefulWidget {
  const FlameOverlay({
    super.key,
    required this.on,
    required this.progress,
    this.burn = 'crowd_roar',
  });

  /// Animating, or a still frame for reduced motion and tests.
  final bool on;

  /// `crowd_roar` is flame with a lightning bolt; `sharp_shooting` is gold
  /// with a crosshair sweeping across — the same burn, the boost's own colour
  /// and mark. Asked for from the couch: the Roar's animation, for the other.
  final String burn;

  /// How far the match is, 0–1: the fire is bright behind the clock and
  /// embers ahead of it, so the bar's own edge is still there to watch.
  /// Reported from the couch — the whole-bar fire hid where the match was.
  final double progress;

  @override
  State<FlameOverlay> createState() => _FlameOverlayState();
}

class _FlameOverlayState extends State<FlameOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.on) _t.repeat();
  }

  @override
  void didUpdateWidget(FlameOverlay old) {
    super.didUpdateWidget(old);
    if (widget.on && !_t.isAnimating) _t.repeat();
    if (!widget.on && _t.isAnimating) _t.stop();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      key: ValueKey('match-boost-band-${widget.burn}'),
      painter: _FlamePainter(_t, widget.progress, gold: widget.burn == 'sharp_shooting'),
      child: const SizedBox.expand(),
    ),
  );
}

/// Tongues of flame along the bar and a bolt that flashes across it.
///
/// Fixed size every frame — only the paint moves. The tongues are a sum of
/// sines scrolled by time, the bolt is a zigzag drawn for a fifth of each
/// loop and gone the rest.
class _FlamePainter extends CustomPainter {
  _FlamePainter(this.t, this.progress, {required this.gold}) : super(repaint: t);

  final Animation<double> t;
  final double progress;
  final bool gold;

  Color get _deep => gold ? goldDeep : flameDeep;
  Color get _mid => gold ? goldMid : flameMid;
  Color get _hot => gold ? goldHot : flameHot;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final phase = t.value * 2 * math.pi;
    final edge = w * progress.clamp(0.0, 1.0);

    // Ahead of the clock: embers, dim enough that the burnt half reads as
    // the fill it is.
    canvas.drawRect(
      Rect.fromLTWH(edge, 0, w - edge, h),
      Paint()..color = _deep.withValues(alpha: 0.28),
    );
    // Behind it: a hot wash, breathing.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, edge, h),
      Paint()..color = _mid.withValues(alpha: 0.35 + 0.15 * math.sin(phase)),
    );

    // Tongues: a ragged top edge, scrolling right to left.
    final tongues = Path()..moveTo(0, h);
    const step = 4.0;
    for (var x = 0.0; x <= w; x += step) {
      final u = x / 18;
      final lick = 0.5 +
          0.28 * math.sin(u - phase * 2) +
          0.16 * math.sin(u * 2.3 + phase * 3) +
          0.06 * math.sin(u * 5.1 - phase * 5);
      tongues.lineTo(x, h * (1 - lick.clamp(0.0, 1.0)));
    }
    tongues
      ..lineTo(w, h)
      ..close();
    // Full flame behind the clock, a third of it ahead.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, edge, h));
    canvas.drawPath(
      tongues,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [_deep, _mid, _hot],
        ).createShader(Offset.zero & size),
    );
    canvas.restore();
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(edge, 0, w - edge, h));
    canvas.drawPath(
      tongues,
      Paint()..color = _mid.withValues(alpha: 0.3),
    );
    canvas.restore();
    // The clock's own edge, white-hot, so the minute is never lost in it.
    canvas.drawRect(
      Rect.fromLTWH(math.max(0, edge - 1.5), 0, 3, h),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );

    // The mark: a fifth of the loop, sweeping the width, white-hot. A bolt
    // for the Roar; a crosshair for Sharp Shooting.
    final bolt = t.value % 1;
    if (gold && bolt < 0.2) {
      final x0 = w * (bolt / 0.2);
      final alpha = (1 - (bolt / 0.2)).clamp(0.0, 1.0);
      final ring = Paint()
        ..color = Colors.white.withValues(alpha: 0.9 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      final r = h * 0.42;
      canvas.drawCircle(Offset(x0, h / 2), r, ring);
      canvas.drawLine(Offset(x0 - r * 1.8, h / 2), Offset(x0 + r * 1.8, h / 2), ring);
      canvas.drawLine(Offset(x0, 0), Offset(x0, h), ring);
    } else if (!gold && bolt < 0.2) {
      final x0 = w * (bolt / 0.2);
      final alpha = (1 - (bolt / 0.2)).clamp(0.0, 1.0);
      final zig = Path()..moveTo(x0 - 18, 0);
      var x = x0 - 18;
      var up = false;
      while (x < x0 + 18) {
        x += 6;
        zig.lineTo(x, up ? 0 : h);
        up = !up;
      }
      canvas.drawPath(
        zig,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_FlamePainter old) =>
      old.t != t || old.progress != progress || old.gold != gold;
}

/// The windows laid over the bar, each across its own minute range.
///
/// A Roar is not drawn here any more — see [FlameOverlay]. Only the Bus
/// keeps a band.
class BoostBands extends StatelessWidget {
  const BoostBands({
    super.key,
    required this.windows,
    required this.glow,
    this.burn,
  });

  final List<LiveBoost> windows;

  /// The window burning the whole bar — see [barBurn] — which is not a band.
  final String? burn;

  /// The shared pulse, or null when nothing should move.
  final Animation<double>? glow;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        return Stack(
          children: [
            for (final b in windows)
              if (b.id != burn)
              Positioned(
                // The bar is `minute / 90`, so the bands are too — stoppage
                // runs off the end the way the clock's own fill does.
                left: w * (b.fromMinute / 90).clamp(0.0, 1.0),
                width: w *
                    ((b.toMinute - b.fromMinute) / 90).clamp(
                      0.0,
                      1.0 - (b.fromMinute / 90).clamp(0.0, 1.0),
                    ),
                top: 0,
                bottom: 0,
                child: _Band(
                  key: ValueKey('match-boost-band-${b.id}'),
                  flame: b.id == 'crowd_roar',
                  glow: glow,
                  // A Bus is a grey wash; Sharp Shooting is gold, the colour
                  // a chance converting already wears on the feed.
                  wash: b.id == 'sharp_shooting'
                      ? const Color(0xFFFFC542)
                      : kit.textMuted,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Band extends StatelessWidget {
  const _Band({
    super.key,
    required this.flame,
    required this.glow,
    required this.wash,
  });

  final bool flame;
  final Animation<double>? glow;
  final Color wash;

  @override
  Widget build(BuildContext context) {
    if (!flame) {
      return DecoratedBox(
        decoration: BoxDecoration(color: wash.withValues(alpha: 0.7)),
      );
    }
    final anim = glow;
    if (anim == null) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [flameDeep, flameMid, flameHot]),
        ),
      );
    }
    // The shimmer slides the gradient's stops, not the box: same size every
    // frame, only the paint moves.
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final t = anim.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: const [flameDeep, flameMid, flameHot, flameMid, flameDeep],
              stops: [0, 0.25 + 0.2 * t, 0.5 + 0.2 * t, 0.75 + 0.1 * t, 1],
            ),
          ),
        );
      },
    );
  }
}

/// A soft pulse round the figures while anything temporary lifts the side.
///
/// Opacity only. The box the child sits in does not change size, so the
/// scoreboard's layout is untouched by the pulse.
class LiveGlow extends StatelessWidget {
  const LiveGlow({
    super.key,
    required this.on,
    required this.glow,
    required this.child,
  });

  final bool on;
  final Animation<double>? glow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!on) return child;
    final kit = Theme.of(context).extension<KitTheme>()!;
    final anim = glow;
    Widget halo(double t) => DecoratedBox(
      key: const ValueKey('match-live-glow'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: kit.accentBright.withValues(alpha: 0.18 + 0.22 * t),
            blurRadius: 14 + 6 * t,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
    if (anim == null) return halo(0.5);
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => halo(anim.value),
    );
  }
}

/// The caption naming what just changed — `🔄 Super Sub`, `📣 Crowd Roar`.
///
/// **One, transient, and only on a CHANGE.** Five lifts can hold at once and
/// five captions is not a board; the glow carries the persistent state and
/// this explains the moment, then fades. The box reserves its height whether
/// or not a caption is up, so its arrival and departure move nothing.
class LiveSourcePill extends StatelessWidget {
  const LiveSourcePill({super.key, required this.text});

  /// Null when nothing has just changed.
  final String? text;

  static const double height = 18;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return SizedBox(
      height: height,
      child: AnimatedOpacity(
        opacity: text == null ? 0 : 1,
        duration: const Duration(milliseconds: 220),
        child: text == null
            ? const SizedBox.shrink()
            : Center(
                child: Container(
                  key: const ValueKey('match-live-source-pill'),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: kit.accent.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    text!,
                    key: const ValueKey('match-live-source-pill-text'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                      color: kit.accentBright,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
